import Foundation

/// Applies a normal published file to the existing file with the same exact name
/// inside the target app-data container. The regular PatchTransaction journal is
/// used so the original can be restored through the existing restore flow.
enum PublishedRawFileService {
    static func apply(
        data: Data,
        bundleID: String,
        filename: String
    ) throws -> PatchTransactionReceipt {
        guard filename.split(separator: "/").count == 1,
              !filename.isEmpty,
              !filename.contains("\\") else {
            throw PatchPackageError.unsafeTargetPath
        }
        guard let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
              ContainerStore.isApplicationContainerPath(rootPath) else {
            throw PatchPackageError.targetAppUnavailable(bundleID)
        }
        let root = PatchPathValidator.canonicalFileURL(
            URL(fileURLWithPath: rootPath, isDirectory: true)
        )
        guard let relativePath = findExactFile(named: filename, under: root) else {
            log("published-raw: exact file not found bundle=\(bundleID) filename=\(filename) root=\(root.path)")
            throw PatchPackageError.targetPathMissing("\(bundleID)/\(filename)")
        }
        log("published-raw: exact file found bundle=\(bundleID) relativePath=\(relativePath) root=\(root.path)")
        let project = PatchProject(
            name: "Published \(filename)",
            author: "Published Function",
            bundleIdentifiers: [bundleID],
            rules: [PatchRule(
                bundleID: bundleID,
                relativePath: relativePath,
                replacementFilename: filename,
                replacementData: data
            )]
        )
        let receipt = try DevicePatchService.apply(
            project: project,
            requireExistingTargets: true
        )
        log("published-raw: backup created and replacement applied project=\(project.id.uuidString) bytes=\(data.count)")
        return receipt
    }

    private static func findExactFile(named filename: String, under root: URL) -> String? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var matches: [String] = []
        for case let url as URL in enumerator {
            guard url.lastPathComponent == filename else { continue }
            guard let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            ), values.isSymbolicLink != true, values.isRegularFile == true else {
                continue
            }
            let canonical = PatchPathValidator.canonicalFileURL(url)
            guard canonical.path.hasPrefix(root.path + "/") else { continue }
            matches.append(String(canonical.path.dropFirst(root.path.count + 1)))
            if matches.count > 1 { return nil }
        }
        return matches.first
    }
}
