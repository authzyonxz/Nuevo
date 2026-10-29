import Darwin
import Foundation

struct FunctionPatchReceipt: Identifiable, Equatable {
    let id: UUID
    let functionID: String
    let bundleID: String
    let filename: String
    let journalURL: URL
    let appliedAt: Date
    let fileCount: Int
}

/// Aplica o arquivo publicado pelo site dentro do container do bundle ID alvo.
///
/// Mesma mecânica do `PatchTransaction`, adaptada para busca por nome:
///  - acha todos os arquivos com o nome publicado no container;
///  - guarda cópia do original (backup) e um journal em plist com os digests;
///  - troca o arquivo de forma atômica (staging + rename) e confere o digest;
///  - restaurar volta os originais e falha fechado se o alvo mudou desde a aplicação.
enum FunctionPatchStore {
    private static let journalFilename = "journal.plist"
    private static let backupFolderName = "Functions"
    private static let lock = NSRecursiveLock()

    // MARK: - caminhos

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

    // MARK: - journal

    private enum Status: String, Codable {
        case applied
        case restored
    }

    private struct Record: Codable {
        let relativePath: String
        let originalExisted: Bool
        let backupFilename: String?
        let originalDigest: String?
        let replacementDigest: String
    }

    private struct Journal: Codable {
        let schemaVersion: Int
        let transactionID: UUID
        let functionID: String
        let bundleID: String
        let containerPath: String
        let filename: String
        let createdAt: Date
        var status: Status
        var records: [Record]
    }

    // MARK: - apply

    @discardableResult
    static func apply(
        functionID: String,
        bundleID rawBundleID: String,
        payloadURL: URL,
        filename: String,
        relativePathHint: String?
    ) throws -> FunctionPatchReceipt {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        let bundleID = try canonicalBundleID(rawBundleID)
        let root = try resolveContainer(bundleID: bundleID)
        guard fileManager.fileExists(atPath: payloadURL.path) else {
            throw FunctionPatchError.applyFailed("payload não está em cache")
        }

        let payloadDigest = try FileDigest.sha256Hex(ofFileAt: payloadURL)
        // Trocar de variante sempre começa do original.
        if let previous = latestReceipt(functionID: functionID) {
            try restore(receipt: previous, allowChangedTargets: false)
        }

        // MOD MENU não procura nem substitui um arquivo existente. O servidor
        // publica o Bundle ID e o caminho da pasta de destino; percorremos essa
        // pasta existente e criamos dentro dela o arquivo publicado.
        if functionID == "mod-menu" {
            guard let relativePathHint, !relativePathHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FunctionPatchError.applyFailed("MOD MENU sem caminho de destino publicado")
            }
            return try applyNewFile(
                functionID: functionID,
                bundleID: bundleID,
                payloadURL: payloadURL,
                filename: filename,
                relativePath: relativePathHint,
                root: root,
                payloadDigest: payloadDigest
            )
        }

        let matches = ContainerFileLocator.matches(
            filename: filename,
            relativePath: relativePathHint,
            containerRoot: root
        )
        guard !matches.isEmpty else { throw FunctionPatchError.noTargetFile(filename) }

        let transactionID = UUID()
        let transactionDirectory = try functionDirectory(functionID: functionID)
            .appendingPathComponent(transactionID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: transactionDirectory, withIntermediateDirectories: true)

        var records: [Record] = []
        var written: [(target: URL, backup: URL)] = []

        do {
            for (index, match) in matches.enumerated() {
                let target = try PatchPathValidator.resolveContainedTargetURL(
                    relativePath: match.relativePath,
                    containerRoot: root
                )
                let backupFilename = "\(index).original"
                let backupURL = transactionDirectory.appendingPathComponent(backupFilename)
                let originalDigest = try FileDigest.sha256Hex(ofFileAt: target)
                try fileManager.copyItem(at: target, to: backupURL)

                _ = try FileReplacementService.replace(target: target, with: payloadURL)

                let replacementDigest = try FileDigest.sha256Hex(ofFileAt: target)
                guard replacementDigest == payloadDigest else {
                    try? fileManager.removeItem(at: target)
                    try? fileManager.copyItem(at: backupURL, to: target)
                    throw FunctionPatchError.digestMismatch
                }

                records.append(
                    Record(
                        relativePath: match.relativePath,
                        originalExisted: true,
                        backupFilename: backupFilename,
                        originalDigest: originalDigest,
                        replacementDigest: replacementDigest
                    )
                )
                written.append((target, backupURL))
            }
        } catch {
            for item in written.reversed() {
                try? fileManager.removeItem(at: item.target)
                try? fileManager.copyItem(at: item.backup, to: item.target)
            }
            try? fileManager.removeItem(at: transactionDirectory)
            throw error
        }

        let journal = Journal(
            schemaVersion: 1,
            transactionID: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            containerPath: root.path,
            filename: filename,
            createdAt: Date(),
            status: .applied,
            records: records
        )
        let journalURL = transactionDirectory.appendingPathComponent(journalFilename)
        do {
            try write(journal, to: journalURL)
        } catch {
            for item in written.reversed() {
                try? fileManager.removeItem(at: item.target)
                try? fileManager.copyItem(at: item.backup, to: item.target)
            }
            try? fileManager.removeItem(at: transactionDirectory)
            throw FunctionPatchError.applyFailed("não consegui gravar o journal")
        }

        log("aim: \(functionID) aplicado em \(bundleID) — \(records.count) arquivo(s)")
        return FunctionPatchReceipt(
            id: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            filename: filename,
            journalURL: journalURL,
            appliedAt: journal.createdAt,
            fileCount: records.count
        )
    }

    private static func applyNewFile(
        functionID: String,
        bundleID: String,
        payloadURL: URL,
        filename: String,
        relativePath: String,
        root: URL,
        payloadDigest: String
    ) throws -> FunctionPatchReceipt {
        let fileManager = FileManager.default
        let destinationDirectory = try PatchPathValidator.resolveContainedTargetURL(
            relativePath: relativePath,
            containerRoot: root
        )
        guard let directoryValues = try? destinationDirectory.resourceValues(forKeys: [.isDirectoryKey]),
              directoryValues.isDirectory == true else {
            throw FunctionPatchError.applyFailed("pasta de destino não existe: \(relativePath)")
        }
        let targetRelativePath = relativePath.hasSuffix("/")
            ? relativePath + filename
            : relativePath + "/" + filename
        let target = try PatchPathValidator.resolveContainedTargetURL(
            relativePath: targetRelativePath,
            containerRoot: root
        )
        guard !fileManager.fileExists(atPath: target.path) else {
            throw FunctionPatchError.targetAlreadyExists(targetRelativePath)
        }

        let transactionID = UUID()
        let transactionDirectory = try functionDirectory(functionID: functionID)
            .appendingPathComponent(transactionID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: transactionDirectory, withIntermediateDirectories: true)

        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".3105-new-\(UUID().uuidString)")
        do {
            try fileManager.copyItem(at: payloadURL, to: staging)
            guard rename(staging.path, target.path) == 0 else {
                throw FunctionPatchError.applyFailed("não consegui criar o arquivo no destino")
            }
            guard try FileDigest.sha256Hex(ofFileAt: target) == payloadDigest else {
                try? fileManager.removeItem(at: target)
                throw FunctionPatchError.digestMismatch
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            try? fileManager.removeItem(at: target)
            try? fileManager.removeItem(at: transactionDirectory)
            throw error
        }

        let journal = Journal(
            schemaVersion: 1,
            transactionID: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            containerPath: root.path,
            filename: filename,
            createdAt: Date(),
            status: .applied,
            records: [Record(
                relativePath: targetRelativePath,
                originalExisted: false,
                backupFilename: nil,
                originalDigest: nil,
                replacementDigest: payloadDigest
            )]
        )
        let journalURL = transactionDirectory.appendingPathComponent(journalFilename)
        do {
            try write(journal, to: journalURL)
        } catch {
            try? fileManager.removeItem(at: target)
            try? fileManager.removeItem(at: transactionDirectory)
            throw FunctionPatchError.applyFailed("não consegui gravar o journal")
        }

        log("aim: \(functionID) criado em \(bundleID)/\(targetRelativePath)")
        return FunctionPatchReceipt(
            id: transactionID,
            functionID: functionID,
            bundleID: bundleID,
            filename: filename,
            journalURL: journalURL,
            appliedAt: journal.createdAt,
            fileCount: 1
        )
    }

    // MARK: - restore

    static func restore(
        receipt: FunctionPatchReceipt,
        allowChangedTargets: Bool = false
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        var journal = try readJournal(receipt.journalURL)
        guard journal.status == .applied else { return }

        let root = try containerRoot(for: journal)
        let transactionDirectory = receipt.journalURL.deletingLastPathComponent()

        var pending: [(record: Record, target: URL)] = []
        for record in journal.records {
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: record.relativePath,
                containerRoot: root
            )
            let current = try? FileDigest.sha256Hex(ofFileAt: target)
            if current == nil {
                guard allowChangedTargets else {
                    throw FunctionPatchError.targetChanged(record.relativePath)
                }
                continue
            }
            if current != record.replacementDigest, !allowChangedTargets {
                throw FunctionPatchError.targetChanged(record.relativePath)
            }
            pending.append((record, target))
        }

        for item in pending {
            guard item.record.originalExisted, let backupFilename = item.record.backupFilename else {
                try? fileManager.removeItem(at: item.target)
                continue
            }
            let backupURL = transactionDirectory.appendingPathComponent(backupFilename)
            guard fileManager.fileExists(atPath: backupURL.path) else {
                throw FunctionPatchError.restoreFailed("backup ausente para \(item.record.relativePath)")
            }
            try atomicCopy(from: backupURL, to: item.target)
            if let digest = item.record.originalDigest,
               (try? FileDigest.sha256Hex(ofFileAt: item.target)) != digest {
                throw FunctionPatchError.restoreFailed("restauração não confere em \(item.record.relativePath)")
            }
        }

        journal.status = .restored
        try write(journal, to: receipt.journalURL)

        for record in journal.records {
            guard let backupFilename = record.backupFilename else { continue }
            try? fileManager.removeItem(at: transactionDirectory.appendingPathComponent(backupFilename))
        }

        log("aim: \(journal.functionID) restaurado em \(journal.bundleID) — \(pending.count) arquivo(s)")
    }

    // MARK: - estado

    static func latestReceipt(functionID: String) -> FunctionPatchReceipt? {
        guard let directory = try? functionDirectory(functionID: functionID),
              let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              ) else { return nil }

        var best: FunctionPatchReceipt?
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let journalURL = entry.appendingPathComponent(journalFilename)
            guard let journal = try? readJournal(journalURL), journal.status == .applied else { continue }
            let receipt = FunctionPatchReceipt(
                id: journal.transactionID,
                functionID: journal.functionID,
                bundleID: journal.bundleID,
                filename: journal.filename,
                journalURL: journalURL,
                appliedAt: journal.createdAt,
                fileCount: journal.records.count
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

    // MARK: - resolução de container

    private static func canonicalBundleID(_ rawValue: String) throws -> String {
        do {
            return try PatchPathValidator.canonicalBundleIdentifier(rawValue)
        } catch {
            throw FunctionPatchError.invalidBundleID
        }
    }

    private static func resolveContainer(bundleID: String) throws -> URL {
        guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
              ContainerStore.isApplicationContainerPath(path) else {
            throw FunctionPatchError.targetAppUnavailable(bundleID)
        }
        let root = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        _ = ContainerStore.grantContainerAccess(root.path)
        return root
    }

    private static func containerRoot(for journal: Journal) throws -> URL {
        let stored = PatchPathValidator.canonicalFileURL(
            URL(fileURLWithPath: journal.containerPath, isDirectory: true)
        )
        if FileManager.default.fileExists(atPath: stored.path),
           ContainerStore.isApplicationContainerPath(stored.path) {
            _ = ContainerStore.grantContainerAccess(stored.path)
            return stored
        }
        return try resolveContainer(bundleID: journal.bundleID)
    }

    // MARK: - arquivo

    private static func atomicCopy(from source: URL, to target: URL) throws {
        let fileManager = FileManager.default
        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".3105-aim-\(UUID().uuidString)")
        try? fileManager.removeItem(at: staging)
        try fileManager.copyItem(at: source, to: staging)
        if let attributes = try? fileManager.attributesOfItem(atPath: target.path) {
            var retained: [FileAttributeKey: Any] = [:]
            if let permissions = attributes[.posixPermissions] { retained[.posixPermissions] = permissions }
            if let protection = attributes[.protectionKey] { retained[.protectionKey] = protection }
            if !retained.isEmpty {
                try? fileManager.setAttributes(retained, ofItemAtPath: staging.path)
            }
        }
        guard rename(staging.path, target.path) == 0 else {
            try? fileManager.removeItem(at: staging)
            throw FunctionPatchError.restoreFailed("rename falhou em \(target.lastPathComponent)")
        }
    }

    private static func write(_ journal: Journal, to url: URL) throws {
        let data = try PropertyListEncoder().encode(journal)
        try data.write(to: url, options: .atomic)
    }

    private static func readJournal(_ url: URL) throws -> Journal {
        do {
            let data = try Data(contentsOf: url)
            return try PropertyListDecoder().decode(Journal.self, from: data)
        } catch {
            throw FunctionPatchError.applyFailed("journal ilegível")
        }
    }
}
