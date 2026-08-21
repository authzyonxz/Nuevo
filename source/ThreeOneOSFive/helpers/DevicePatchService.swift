import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        guard LicenseManager.shared.isAuthorized else {
            throw PatchPackageError.applyFailed
        }
        let bundleIDs = orderedBundleIdentifiers(in: project)
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

    static func restore(receipt: PatchTransactionReceipt) throws {
        guard LicenseManager.shared.isAuthorized else {
            throw PatchPackageError.restoreFailed
        }
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
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            if ExploitSupportPolicy.accessPath(
                major: AppInfo.versionTuple.major,
                minor: AppInfo.versionTuple.minor,
                patch: AppInfo.versionTuple.patch,
                build: AppInfo.osBuild
            ) == .badQuery {
                let handle = ContainerStore.grantContainerAccess(path)
                guard handle >= 0 else {
                    log("patch: bad_query grant failed for \(bundleID), result=\(handle)")
                    throw PatchPackageError.targetAppUnavailable(bundleID)
                }
                handles.append(handle)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
