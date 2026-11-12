// language: Swift, file: AccessBackend.swift, target: iOS 17+
//
// Seletor de backend de acesso. Três rotas chegam ao mesmo container:
//
//   kernel    → kexploit_opa334 + sandbox_escape        (iOS 17.0–18.7.2)
//   badQuery  → kernel + escape + bad_query grants      (iOS 26.0–26.6.2)
//   airlift   → pareamento on-device + RSD + AirTraffic (iOS 27.0–27.2 b2)
//
// kernel e badQuery usam o FunctionPatchStore (leitura, backup local, restore
// verificado). Airlift usa o AirliftPatchStore (escrita, restore pelo site).
// O resto do app só conhece este ponto de entrada.

import Foundation

enum AccessKind: String, Codable {
    case kernel
    case badQuery
    case airlift

    /// Rota que lê e escreve o container pelo kernel.
    var usesKernel: Bool { self == .kernel || self == .badQuery }
}

struct AccessAvailability {
    let policyKind: AccessKind?
    let pairingReady: Bool
    let tunnelReady: Bool
    let kernelActive: Bool

    var airliftReady: Bool { pairingReady && tunnelReady }

    /// Pré-requisitos da rota satisfeitos neste instante.
    var isReady: Bool {
        switch policyKind {
        case .kernel, .badQuery: return kernelActive
        case .airlift: return airliftReady
        case nil: return false
        }
    }
}

enum AccessBackend {

    // MARK: - Estado

    static var policyKind: AccessKind? {
        let version = AppInfo.versionTuple
        return ExploitSupportPolicy.accessKind(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        )
    }

    static func availability() -> AccessAvailability {
        AccessAvailability(
            policyKind: policyKind,
            pairingReady: AirliftPairing.hasActive(),
            tunnelReady: LoopbackTunnel.isUp(),
            kernelActive: KernelExploit.hasSandboxAccess()
        )
    }

    /// Pré-voo da rota Airlift com mensagem acionável.
    static func requireAirliftReady() throws -> String {
        guard policyKind == .airlift else {
            throw AirliftError.unsupportedVersion(AppInfo.osVersion)
        }
        guard let pairingPath = AirliftPairing.activePath() else {
            throw AirliftError.pairingMissing
        }
        guard LoopbackTunnel.isUp() else {
            throw AirliftError.tunnelDown
        }
        Airlift.setTargetHost(LoopbackTunnel.host)
        return pairingPath
    }

    // MARK: - Apply

    static func apply(
        functionID: String,
        bundleID: String,
        payloadURL: URL,
        filename: String,
        relativePathHint: String?,
        version: Int,
        originalSha256: String?
    ) throws -> FunctionPatchReceipt {
        guard let kind = policyKind else {
            throw AirliftError.unsupportedVersion(AppInfo.osVersion)
        }

        switch kind {
        case .kernel, .badQuery:
            return try FunctionPatchStore.apply(
                functionID: functionID,
                bundleID: bundleID,
                payloadURL: payloadURL,
                filename: filename,
                relativePathHint: relativePathHint
            )

        case .airlift:
            _ = try requireAirliftReady()
            return try AirliftPatchStore.apply(
                functionID: functionID,
                bundleID: bundleID,
                payloadURL: payloadURL,
                filename: filename,
                relativePathHint: relativePathHint,
                version: version,
                originalSha256: originalSha256
            )
        }
    }

    // MARK: - Restore

    static func restore(
        receipt: FunctionPatchReceipt,
        baseURL: URL?,
        access: KeyAuthAccess?,
        force: Bool
    ) async throws {
        switch receipt.backend {
        case .kernel, .badQuery:
            try await Task.detached(priority: .userInitiated) {
                try FunctionPatchStore.restore(receipt: receipt, allowChangedTargets: force)
            }.value

        case .airlift:
            let journal = try AirliftPatchStore.journal(for: receipt)
            guard let record = journal.records.first, let expected = record.originalSha256 else {
                throw AirliftError.writeFailed(
                    "o site não publicou o original desta função. Reinstale o app alvo para voltar ao estado limpo."
                )
            }
            guard let baseURL, let access else {
                throw AirliftError.writeFailed("sem sessão ativa para baixar o original")
            }

            let refreshed = try await KeyAuthClient().revalidate(access)
            let original = try await FunctionPatchClient().downloadOriginal(
                functionID: receipt.functionID,
                baseURL: baseURL,
                grant: refreshed.grant,
                sessionToken: refreshed.sessionToken,
                expectedSHA256: expected
            )

            try await Task.detached(priority: .userInitiated) {
                try AirliftPatchStore.restore(
                    receipt: receipt,
                    originalPayloadURL: original.fileURL
                )
            }.value
        }
    }

    // MARK: - Receipts

    /// União das transações das duas famílias de backend, por função.
    static func appliedReceipts() -> [String: FunctionPatchReceipt] {
        var merged = FunctionPatchStore.appliedReceipts()
        for (functionID, receipt) in AirliftPatchStore.appliedReceipts() {
            if let existing = merged[functionID] {
                if receipt.appliedAt > existing.appliedAt { merged[functionID] = receipt }
            } else {
                merged[functionID] = receipt
            }
        }
        return merged
    }
}
