import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) async throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        let ticket = try await requestAuthorization(
            operation: "apply_patch:\(bundleIDs.sorted().joined(separator: ","))"
        )
        try LicenseService.shared.consume(ticket)

        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(receipt: PatchTransactionReceipt) async throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        let ticket = try await requestAuthorization(
            operation: "restore_patch:\(bundleIDs.sorted().joined(separator: ","))"
        )
        try LicenseService.shared.consume(ticket)

        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    private static func requestAuthorization(operation: String) async throws -> OperationAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            LicenseService.shared.authorizeOperation(operation) { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        var handles: [Int64] = []
        defer { handles.forEach(bad_query_release) }

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                log("patch: could not resolve path for \(bundleID)")
                throw NSError(domain: "Patch", code: 404, userInfo: [NSLocalizedDescriptionKey: "Não foi possível localizar a pasta do jogo \(bundleID). Certifique-se que o jogo está instalado."])
            }

            guard ContainerStore.isApplicationContainerPath(path) else {
                log("patch: invalid container path for \(bundleID)")
                throw NSError(domain: "Patch", code: 403, userInfo: [NSLocalizedDescriptionKey: "Caminho do jogo inválido ou restrito."])
            }

            let handle = ContainerStore.grantContainerAccess(path)
            if handle >= 0 {
                handles.append(handle)
            } else {
                log("patch: traversal grant returned \(handle), proceeding in standard mode")
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
