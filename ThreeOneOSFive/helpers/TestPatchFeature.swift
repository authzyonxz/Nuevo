import Foundation

/// TESTE PATCH usa um item remoto do manifesto. O projeto decodificado recebe
/// um ID estável para que o journal continue reconhecível entre atualizações.
enum TestPatchFeature {
    static let stableProjectID = UUID(uuidString: "40F75F5F-E17F-4F24-8721-0870E7304A94")!
    static let projectID = stableProjectID
    static let remoteID = "teste_patch"
    static let expectedBundleID = "com.dts.freefireth"

    enum FeatureError: LocalizedError {
        case unavailable
        case incompatiblePackage

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "TESTE PATCH não está disponível no servidor."
            case .incompatiblePackage:
                return "O pacote remoto TESTE PATCH não é compatível com esta função."
            }
        }
    }

    static func loadRemoteProject() async throws -> PatchProject {
        let (metadata, data) = try await OnlinePayloadUpdater.shared.download(
            id: remoteID,
            bundleID: expectedBundleID,
            forceRefresh: true
        )
        guard metadata.enabled, !data.isEmpty else {
            throw FeatureError.unavailable
        }
        let decoded = try PatchPackageCodec.decode(data, password: metadata.packagePassword)
        var project = decoded.project
        guard project.allBundleIdentifiers == [expectedBundleID],
              !project.rules.isEmpty else {
            throw FeatureError.incompatiblePackage
        }
        // O ID do pacote pode mudar quando o servidor recebe uma nova versão.
        // O ID estável mantém o vínculo com o journal e com o switch da função.
        project.id = stableProjectID
        return project
    }

    static func apply() async throws -> PatchTransactionReceipt {
        try DevicePatchService.apply(project: await loadRemoteProject())
    }

    static func latestReceipt() -> PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: stableProjectID)
    }

    static func restore() throws {
        guard let receipt = latestReceipt() else {
            throw PatchPackageError.restoreFailed
        }
        try DevicePatchService.restore(receipt: receipt)
    }
}
