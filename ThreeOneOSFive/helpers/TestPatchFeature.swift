import Foundation

/// Feature isolada do variant Cache. As demais funções continuam usando seus
/// próprios projetos e caminhos; somente TESTE PATCH passa pelo pacote .3105.
enum TestPatchFeature {
    static let projectID = UUID(uuidString: "40F75F5F-E17F-4F24-8721-0870E7304A94")!
    private static let packageName = "FixCrashFFTH"
    private static let packagePassword = "OG"
    private static let expectedBundleID = "com.dts.freefireth"

    static func loadProject() throws -> PatchProject {
        guard let url = Bundle.main.url(forResource: packageName, withExtension: "3105") else {
            throw PatchPackageError.invalidProject
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let decoded = try PatchPackageCodec.decode(data, password: packagePassword)
        guard decoded.project.id == projectID,
              decoded.project.allBundleIdentifiers == [expectedBundleID],
              !decoded.project.rules.isEmpty else {
            throw PatchPackageError.invalidProject
        }
        return decoded.project
    }

    static func apply() throws -> PatchTransactionReceipt {
        try DevicePatchService.apply(project: loadProject())
    }

    static func latestReceipt() -> PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    static func restore() throws {
        guard let receipt = latestReceipt() else {
            throw PatchPackageError.restoreFailed
        }
        try DevicePatchService.restore(receipt: receipt)
    }
}
