// language: Swift, file: AirliftPatchStore.swift, target: iOS 18+
//
// Motor de patch por Airlift: grava arquivos dentro do container de outro app
// sem kernel exploit, usando a cadeia pairing → RSD loopback → AirTraffic.
//
// Diferenças estruturais em relação ao FunctionPatchStore (kernel):
//  - não existe leitura do container alvo, então o caminho precisa vir
//    publicado pelo site (`X-Payload-Path` / `relativePath`);
//  - não existe backup local do original: a restauração depende do site
//    publicar o arquivo original (`originalSha256` no manifesto);
//  - a troca é feita por diretório de destino, um `al_exploit_write_dir`
//    por pasta, com o nome do arquivo de staging igual ao nome final.

import Foundation

struct AirliftJournalRecord: Codable, Equatable {
    let destinationDirectory: String
    let filename: String
    let replacementDigest: String
    let originalSha256: String?
}

struct AirliftJournal: Codable, Equatable {
    let schemaVersion: Int
    let transactionID: UUID
    let functionID: String
    let bundleID: String
    let filename: String
    let createdAt: Date
    var status: String
    var records: [AirliftJournalRecord]
}

enum AirliftPatchStore {
    private static let journalFilename = "journal.plist"
    private static let backupFolderName = "FunctionsAirlift"
    private static let lock = NSRecursiveLock()

    static let statusApplied = "applied"
    static let statusRestored = "restored"
    static let statusAbandoned = "abandoned"

    // MARK: - Caminhos

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try PatchProjectLibrary.backupRootURL(fileManager: fileManager)
            .appendingPathComponent(backupFolderName, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func functionDirectory(functionID: String) throws -> URL {
        let directory = try backupRootURL().appendingPathComponent(functionID, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - Apply

    /// Grava o payload no caminho publicado pelo site dentro do container alvo.
    @discardableResult
    static func apply(
        functionID: String,
        bundleID rawBundleID: String,
        payloadURL: URL,
        filename: String,
        relativePathHint: String?,
        version: Int,
        originalSha256: String?
    ) throws -> FunctionPatchReceipt {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        let bundleID = try canonicalBundleID(rawBundleID)

        guard let pairingPath = AirliftPairing.activePath() else {
            throw AirliftError.pairingMissing
        }
        guard LoopbackTunnel.isUp() else {
            throw AirliftError.tunnelDown
        }
        Airlift.setTargetHost(LoopbackTunnel.host)

        guard fileManager.fileExists(atPath: payloadURL.path) else {
            throw AirliftError.writeFailed("payload não está em cache")
        }
        let payloadDigest = try FileDigest.sha256Hex(ofFileAt: payloadURL)

        // Uma variante por função: a nova escrita sobrescreve o mesmo alvo, então
        // a transação anterior é encerrada como abandonada em vez de bloquear.
        if let previous = latestReceipt(functionID: functionID) {
            abandon(previous)
        }

        guard let relativePath = relativePathHint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !relativePath.isEmpty else {
            throw AirliftError.pathUnknown(bundleID)
        }

        let container = try Airlift.findContainer(pairingPath: pairingPath, bundleID: bundleID)
        let plan = try writePlan(container: container, relativePath: relativePath)

        // Staging: o core usa o NOME do arquivo de origem como nome final.
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("3105-airlift-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        let stagedFile = stagingDirectory.appendingPathComponent(plan.filename)
        try fileManager.copyItem(at: payloadURL, to: stagedFile)

        try Airlift.writeDirectory(
            pairingPath: pairingPath,
            sourceDir: stagingDirectory,
            targetDir: plan.destinationDirectory
        )

        let transactionID = UUID()
        let transactionDirectory = try functionDirectory(functionID: functionID)
            .appendingPathComponent(transactionID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: transactionDirectory, withIntermediateDirectories: true)

        let record = AirliftJournalRecord(
            destinationDirectory: plan.destinationDirectory,
            filename: plan.filename,
            replacementDigest: payloadDigest,
            originalSha256: originalSha256
        )
        let journal = AirliftJournal(
            schemaVersion: 1,
            transactionID: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            filename: plan.filename,
            createdAt: Date(),
            status: statusApplied,
            records: [record]
        )
        let journalURL = transactionDirectory.appendingPathComponent(journalFilename)
        do {
            try writeJournal(journal, to: journalURL)
        } catch {
            try? fileManager.removeItem(at: transactionDirectory)
            throw AirliftError.writeFailed("não consegui gravar o journal")
        }

        log("airlift: \(functionID) gravado em \(plan.destinationDirectory)/\(plan.filename) v\(version)")

        return FunctionPatchReceipt(
            id: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            filename: plan.filename,
            journalURL: journalURL,
            appliedAt: journal.createdAt,
            fileCount: 1,
            backend: .airlift
        )
    }

    // MARK: - Restore

    /// Restaura o original publicado pelo site. Sem original não há como
    /// reconstruir o arquivo — o Airlift é write-only por design.
    static func restore(receipt: FunctionPatchReceipt, originalPayloadURL: URL?) throws {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        var journal = try readJournal(receipt.journalURL)
        guard journal.status == statusApplied else { return }

        guard let pairingPath = AirliftPairing.activePath() else {
            throw AirliftError.pairingMissing
        }
        guard LoopbackTunnel.isUp() else {
            throw AirliftError.tunnelDown
        }
        Airlift.setTargetHost(LoopbackTunnel.host)

        guard let record = journal.records.first else {
            throw AirliftError.writeFailed("journal sem registros")
        }
        guard record.originalSha256 != nil else {
            throw AirliftError.writeFailed(
                "o site não publicou o arquivo original desta função; reinstale o app alvo para voltar ao estado limpo"
            )
        }
        guard let originalPayloadURL else {
            throw AirliftError.writeFailed("original indisponível no servidor")
        }

        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("3105-airlift-restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        let stagedFile = stagingDirectory.appendingPathComponent(record.filename)
        try fileManager.copyItem(at: originalPayloadURL, to: stagedFile)

        try Airlift.writeDirectory(
            pairingPath: pairingPath,
            sourceDir: stagingDirectory,
            targetDir: record.destinationDirectory
        )

        journal.status = statusRestored
        try writeJournal(journal, to: receipt.journalURL)
        log("airlift: \(journal.functionID) restaurado em \(journal.bundleID)")
    }

    // MARK: - Estado

    /// Encerra a transação sem tocar no aparelho. Usado quando outra variante
    /// vai sobrescrever o mesmo alvo.
    private static func abandon(_ receipt: FunctionPatchReceipt) {
        guard var journal = try? readJournal(receipt.journalURL) else { return }
        guard journal.status == statusApplied else { return }
        journal.status = statusAbandoned
        try? writeJournal(journal, to: receipt.journalURL)
        log("airlift: transação anterior de \(journal.functionID) marcada como abandonada")
    }

    static func latestReceipt(functionID: String) -> FunctionPatchReceipt? {
        guard let directory = try? functionDirectory(functionID: functionID),
              let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              ) else { return nil }

        var best: FunctionPatchReceipt?
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let journalURL = entry.appendingPathComponent(journalFilename)
            guard let journal = try? readJournal(journalURL), journal.status == statusApplied else { continue }
            let receipt = FunctionPatchReceipt(
                id: journal.transactionID,
                functionID: journal.functionID,
                bundleID: journal.bundleID,
                filename: journal.filename,
                journalURL: journalURL,
                appliedAt: journal.createdAt,
                fileCount: journal.records.count,
                backend: .airlift
            )
            if best == nil || journal.createdAt > (best?.appliedAt ?? .distantPast) {
                best = receipt
            }
        }
        return best
    }

    static func appliedReceipts() -> [String: FunctionPatchReceipt] {
        var receipts: [String: FunctionPatchReceipt] = [:]
        for function in AimFunctionCatalog.all {
            if let receipt = latestReceipt(functionID: function.id) {
                receipts[function.id] = receipt
            }
        }
        return receipts
    }

    /// Abre o journal de uma transação para o restore saber o que repor.
    static func journal(for receipt: FunctionPatchReceipt) throws -> AirliftJournal {
        try readJournal(receipt.journalURL)
    }

    // MARK: - Plano de escrita

    struct WritePlan: Equatable {
        let destinationDirectory: String
        let filename: String
    }

    /// Junta container + caminho relativo sem tocar no filesystem (não há
    /// permissão de leitura no alvo) e sem aceitar traversal.
    static func writePlan(container: String, relativePath: String) throws -> WritePlan {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AirliftError.pathUnknown(container)
        }
        guard !trimmed.hasPrefix("/") else {
            throw AirliftError.writeFailed("caminho absoluto não é aceito: \(trimmed)")
        }

        let components = trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard !components.isEmpty,
              !components.contains(".."),
              !components.contains(".") else {
            throw AirliftError.writeFailed("caminho inválido: \(trimmed)")
        }
        guard let filename = components.last, !filename.isEmpty else {
            throw AirliftError.writeFailed("caminho sem nome de arquivo: \(trimmed)")
        }

        var base = container
        while base.hasSuffix("/") { base.removeLast() }
        let directoryComponents = Array(components.dropLast())
        let destination = ([base] + directoryComponents).joined(separator: "/")
        return WritePlan(destinationDirectory: destination, filename: filename)
    }

    // MARK: - Internos

    private static func canonicalBundleID(_ rawValue: String) throws -> String {
        do {
            return try PatchPathValidator.canonicalBundleIdentifier(rawValue)
        } catch {
            throw AirliftError.containerNotFound(rawValue)
        }
    }

    private static func writeJournal(_ journal: AirliftJournal, to url: URL) throws {
        let data = try PropertyListEncoder().encode(journal)
        try data.write(to: url, options: .atomic)
    }

    private static func readJournal(_ url: URL) throws -> AirliftJournal {
        do {
            let data = try Data(contentsOf: url)
            return try PropertyListDecoder().decode(AirliftJournal.self, from: data)
        } catch {
            throw AirliftError.writeFailed("journal ilegível em \(url.lastPathComponent)")
        }
    }
}
