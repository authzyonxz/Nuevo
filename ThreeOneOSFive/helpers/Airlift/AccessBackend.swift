// language: Swift, file: AccessBackend.swift, target: iOS 18+
//
// Seletor de backend de acesso. Duas rotas chegam ao mesmo container:
//
//   kernel   → kexploit_opa334 + sandbox_escape + bad_query  (iOS 17.0–18.7.1)
//   airlift  → pairing + RSD loopback + AirTraffic ATAirlock (iOS 18.7.2+)
//
// A política de versão decide a rota; o Airlift também serve de fallback
// quando o kernel exploit perde a corrida. O resto do app só conhece este
// ponto de entrada.

import Foundation

enum AccessKind: String, Codable {
    case kernel
    case airlift
}

struct AccessAvailability {
    let policyKind: AccessKind?
    let pairingReady: Bool
    let tunnelReady: Bool
    let kernelActive: Bool

    var airliftReady: Bool { pairingReady && tunnelReady }

    /// Rota que será usada de fato.
    var effectiveKind: AccessKind? {
        if let policyKind {
            if policyKind == .kernel { return kernelActive ? .kernel : (airliftReady ? .airlift : .kernel) }
            return .airlift
        }
        return airliftReady ? .airlift : nil
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
        let paired = AirliftPairing.hasActive()
        let tunnel = LoopbackTunnel.isUp()
        let kernel = KernelExploit.hasSandboxAccess()
        return AccessAvailability(
            policyKind: policyKind,
            pairingReady: paired,
            tunnelReady: tunnel,
            kernelActive: kernel
        )
    }

    /// Pré-voo da rota Airlift com mensagem acionável.
    static func requireAirliftReady() throws -> String {
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
        let state = availability()

        if state.policyKind == .kernel {
            do {
                return try FunctionPatchStore.apply(
                    functionID: functionID,
                    bundleID: bundleID,
                    payloadURL: payloadURL,
                    filename: filename,
                    relativePathHint: relativePathHint
                )
            } catch {
                guard state.airliftReady else { throw error }
                log("access: kernel falhou (\(error)); caindo para Airlift")
            }
        }

        guard state.airliftReady else {
            throw AirliftError.pairingMissing
        }

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

    // MARK: - Restore

    static func restore(
        receipt: FunctionPatchReceipt,
        baseURL: URL?,
        access: KeyAuthAccess?,
        force: Bool
    ) async throws {
        switch receipt.backend {
        case .kernel:
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

            // Reconvalida a licença antes de baixar bytes protegidos.
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

    /// União das transações dos dois backends, por função.
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
