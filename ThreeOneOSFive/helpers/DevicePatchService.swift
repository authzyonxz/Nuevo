import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) async throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        let ticket = try await requestAuthorization(
            operation: "apply_patch:\(bundleIDs.sorted().joined(separator: ","))"
        )
        try LicenseService.shared.consume(ticket, for: "apply_patch:\(bundleIDs.sorted().joined(separator: ","))")

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
        try LicenseService.shared.consume(ticket, for: "restore_patch:\(bundleIDs.sorted().joined(separator: ","))")

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
            if let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID) {
                log("patch: container resolved at \(path)")
                let handle = ContainerStore.grantContainerAccess(path)
                if handle >= 0 { handles.append(handle) }
                roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
            } else {
                log("patch: could not resolve \(bundleID), using BLIND MODE fallback")
                // No Blind Mode, tentamos o caminho mais provável. 
                // No iOS, /var/mobile/Containers/Data/Application/ é o padrão.
                // Usamos uma URL simbólica que o PatchTransaction tentará resolver via exploit.
                let blindPath = "/var/mobile/Containers/Data/Application/FIXED_FALLBACK"
                roots[bundleID] = URL(fileURLWithPath: blindPath, isDirectory: true)
            }
        }
        return try operation(roots)
    }
}
