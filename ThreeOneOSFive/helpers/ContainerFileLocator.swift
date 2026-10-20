import Foundation

struct ContainerFileMatch: Equatable {
    let relativePath: String
    let byteCount: Int64
}

/// Varre o container inteiro do bundle ID alvo atrás de arquivos com o nome
/// publicado. Não usa o caminho fixo do patch normal: procura por nome em toda
/// a árvore, porque o arquivo pode estar em Documents, Library, Preferences etc.
enum ContainerFileLocator {
    static let maximumDepth = 32
    static let maximumEntries = 250_000
    private static let stagingPrefix = ".3105-replacement-"

    static func matches(
        filename: String,
        relativePath: String?,
        containerRoot: URL
    ) -> [ContainerFileMatch] {
        let fileManager = FileManager.default
        let root = PatchPathValidator.canonicalFileURL(containerRoot)
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        // Caminho exato publicado pelo site: não precisa varrer nada.
        if let relativePath, !relativePath.isEmpty {
            if let target = try? PatchPathValidator.resolveContainedTargetURL(
                relativePath: relativePath,
                containerRoot: root
            ), isRegularFile(target) {
                return [ContainerFileMatch(relativePath: relativePath, byteCount: byteCount(target, fileManager))]
            }
            // Nunca usamos diretamente caminhos absolutos ou fora do container.
            // Caso a dica publicada não resolva, confirmamos pelo nome na árvore.
        }

        let wanted = filename.lowercased()
        guard !wanted.isEmpty else { return [] }

        _ = ContainerStore.grantContainerAccess(root.path)

        var results: [ContainerFileMatch] = []
        var stack: [(url: URL, relative: String, depth: Int)] = [(root, "", 0)]
        var visited = 0

        while let entry = stack.popLast() {
            if entry.depth >= maximumDepth { continue }
            let names = (try? fileManager.contentsOfDirectory(atPath: entry.url.path)) ?? []
            for name in names {
                visited += 1
                if visited > maximumEntries { return sorted(results) }
                if name.hasPrefix(stagingPrefix) { continue }

                let child = entry.url.appendingPathComponent(name, isDirectory: false)
                guard let values = try? child.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                ]) else { continue }
                if values.isSymbolicLink == true { continue }

                let relative = entry.relative.isEmpty ? name : entry.relative + "/" + name
                if values.isDirectory == true {
                    stack.append((child, relative, entry.depth + 1))
                    continue
                }
                guard name.lowercased() == wanted else { continue }
                results.append(
                    ContainerFileMatch(
                        relativePath: relative,
                        byteCount: Int64(values.fileSize ?? 0)
                    )
                )
            }
        }
        return sorted(results)
    }

    private static func sorted(_ matches: [ContainerFileMatch]) -> [ContainerFileMatch] {
        matches.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isDirectory != true && values.isSymbolicLink != true
    }

    private static func byteCount(_ url: URL, _ fileManager: FileManager) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }
}
