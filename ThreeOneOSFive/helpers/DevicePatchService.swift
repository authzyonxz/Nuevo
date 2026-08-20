import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try applyTransaction(project: project, roots: roots)
        }
    }

    /// Applies a patch using roots already resolved by the caller. This avoids
    /// resolving the same MCM object a second time on iOS 26.6, where the
    /// first path/grant can be valid but a subsequent activation can fail.
    static func apply(
        project: PatchProject,
        preResolvedRoots: [String: URL]
    ) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        var roots: [String: URL] = [:]
        for bundleID in bundleIDs {
            guard let root = preResolvedRoots[bundleID],
                  ContainerStore.isApplicationContainerPath(root.path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = root
        }
        return try withGrantedRoots(roots) {
            try applyTransaction(project: project, roots: roots)
        }
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
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

    private static func applyTransaction(
        project: PatchProject,
        roots: [String: URL]
    ) throws -> PatchTransactionReceipt {
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

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(
                URL(fileURLWithPath: path, isDirectory: true)
            )
        }
        return try withGrantedRoots(roots) {
            try operation(roots)
        }
    }

    private static func withGrantedRoots<T>(
        _ roots: [String: URL],
        operation: () throws -> T
    ) throws -> T {
        var handles: [Int64] = []
        defer { handles.forEach(bad_query_release) }

        let version = AppInfo.versionTuple
        let accessPath = ExploitSupportPolicy.accessPath(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        )
        if accessPath == .badQuery {
            for (bundleID, root) in roots {
                let handle = ContainerStore.grantContainerAccess(root.path)
                guard handle >= 0 else {
                    log("patch: bad_query grant failed for \(bundleID), result=\(handle)")
                    throw PatchPackageError.targetAppUnavailable(bundleID)
                }
                handles.append(handle)
            }
        }
        return try operation()
    }
}
