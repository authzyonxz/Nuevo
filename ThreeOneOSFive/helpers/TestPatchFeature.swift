import Foundation

/// TESTE PATCH usa um item remoto do manifesto. O projeto decodificado recebe
/// um ID estável para que o journal continue reconhecível entre atualizações.
enum TestPatchFeature {
    static let stableProjectID = UUID(uuidString: "40F75F5F-E17F-4F24-8721-0870E7304A94")!
    static let projectID = stableProjectID
    static let remoteID = "teste_patch"
    static let supportedBundleIDs: Set<String> = ["com.dts.freefireth", "com.dts.freefiremax"]

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

    static func loadRemoteProject(bundleID: String) async throws -> PatchProject {
        guard supportedBundleIDs.contains(bundleID) else {
            throw FeatureError.incompatiblePackage
        }
        let (metadata, data) = try await OnlinePayloadUpdater.shared.download(
            id: remoteID,
            bundleID: bundleID,
            forceRefresh: true
        )
        guard metadata.enabled, !data.isEmpty else {
            throw FeatureError.unavailable
        }
        let decoded = try PatchPackageCodec.decode(data, password: metadata.packagePassword)
        var project = decoded.project
        let sourceBundleIDs = Set(project.allBundleIdentifiers)
        guard !project.rules.isEmpty,
              sourceBundleIDs.count == 1,
              sourceBundleIDs.isSubset(of: supportedBundleIDs) else {
            throw FeatureError.incompatiblePackage
        }
        // O jogo é escolhido uma única vez após a validação da Key. Todas as
        // regras do pacote passam a apontar exclusivamente para esse bundle.
        project.bundleIdentifiers = [bundleID]
        project.directories = project.directories.map { directory in
            var selected = directory
            selected.bundleID = bundleID
            return selected
        }
        project.rules = project.rules.map { rule in
            var selected = rule
            selected.bundleID = bundleID
            return selected
        }
        // O ID do pacote pode mudar quando o servidor recebe uma nova versão.
        // O ID estável mantém o vínculo com o journal e com o switch da função.
        project.id = stableProjectID
        return project
    }

    static func apply(bundleID: String) async throws -> PatchTransactionReceipt {
        try DevicePatchService.apply(project: await loadRemoteProject(bundleID: bundleID))
    }

    static func latestReceipt() -> PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: stableProjectID)
    }

    static func restore() throws {
        // A restauração usa o backup original e o journal criado pelo Apply;
        // nunca baixa nem reaplica o pacote remoto 3105.
        guard let receipt = latestReceipt(),
              receipt.projectID == stableProjectID else {
            throw PatchPackageError.restoreFailed
        }
        try DevicePatchService.restore(receipt: receipt)
    }
}
