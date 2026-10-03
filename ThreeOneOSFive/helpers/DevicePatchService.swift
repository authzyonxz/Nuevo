import Foundation

enum DevicePatchService {
    static func apply(
        project: PatchProject,
        requireExistingTargets: Bool = false
    ) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            for rule in project.rules {
                if let root = roots[rule.bundleID] {
                    let target = root.appendingPathComponent(rule.relativePath, isDirectory: false)
                    log("patch: resolved bundle=\(rule.bundleID) root=\(root.path) target=\(target.path) exists=\(FileManager.default.fileExists(atPath: target.path)) strict=\(requireExistingTargets)")
                }
            }
            return try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                },
                requireExistingTargets: requireExistingTargets
            )
        }
    }

    static func inspectRestore(receipt: PatchTransactionReceipt) throws -> PatchRestoreInspection {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.inspectRestore(
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

    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        project: PatchProject
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.resetToAppliedState(
                receipt: receipt,
                fallbackProject: project,
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

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}


/// Applies a normal published file to the existing file with the same exact name
/// inside the target app-data container. PatchTransaction keeps the original in
/// its journal so the existing restore flow can restore it.
enum PublishedRawFileService {
    static func applyMany(
        files: [(data: Data, bundleID: String, filename: String)]
    ) throws -> PatchTransactionReceipt {
        guard files.count == 2, let first = files.first else { throw PatchPackageError.invalidProject }
        var rules: [PatchRule] = []
        for file in files {
            let filename = file.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidFilePath(filename),
                  let relativePath = try? PatchPathValidator.canonicalRelativePath(filename) else {
                throw PatchPackageError.targetPathMissing("\(file.bundleID)/\(file.filename) — informe o caminho completo incluindo o nome do arquivo")
            }
            guard file.bundleID == first.bundleID else {
                throw PatchPackageError.targetPathMissing("\(file.bundleID)/\(file.filename)")
            }
            rules.append(PatchRule(bundleID: file.bundleID, relativePath: relativePath, replacementFilename: URL(fileURLWithPath: relativePath).lastPathComponent, replacementData: file.data))
        }
        return try DevicePatchService.apply(project: PatchProject(name: "Published multi-file", author: "Published Function", bundleIdentifiers: [first.bundleID], rules: rules), requireExistingTargets: false)
    }

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

    private static func resolveTargetPath(_ filename: String, under bundleID: String) -> String? {
        guard isValidFilePath(filename),
              let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else { return nil }
        let root = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: rootPath, isDirectory: true))
        if filename.contains("/") {
            let url = PatchPathValidator.canonicalFileURL(root.appendingPathComponent(filename))
            guard url.path.hasPrefix(root.path + "/"), !url.path.hasSuffix("/") else { return nil }
            if FileManager.default.fileExists(atPath: url.path) {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isDirectory != true, values.isSymbolicLink != true else { return nil }
            }
            return String(url.path.dropFirst(root.path.count + 1))
        }
        return findExactFile(named: filename, under: root)
    }

    private static func isValidFilePath(_ filename: String) -> Bool {
        guard !filename.isEmpty, !filename.hasSuffix("/"), !filename.contains("\\"),
              !filename.hasPrefix("/"), !filename.split(separator: "/").contains(".."),
              let last = filename.split(separator: "/").last, !last.isEmpty else { return false }
        return true
    }
}
