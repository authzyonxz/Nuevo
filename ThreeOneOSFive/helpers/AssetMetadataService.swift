import Foundation

public struct AssetMetadata: Codable {
    public var displayName: String
}

public class AssetMetadataService {
    public static let shared = AssetMetadataService()
    private let fileManager = FileManager.default

    private func metadataURL(for assetURL: URL) -> URL {
        let filename = assetURL.lastPathComponent
        return assetURL.deletingLastPathComponent()
            .appendingPathComponent(".\(filename).metadata.json")
    }

    public func setDisplayName(_ name: String, for assetURL: URL) {
        let metadata = AssetMetadata(displayName: name)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL(for: assetURL))
        }
    }

    public func getDisplayName(for assetURL: URL) -> String {
        if let data = try? Data(contentsOf: metadataURL(for: assetURL)),
           let metadata = try? JSONDecoder().decode(AssetMetadata.self, from: data) {
            return metadata.displayName
        }
        // Retorna o nome do arquivo sem extensão como padrão se não houver apelido
        return assetURL.deletingPathExtension().lastPathComponent
    }

    public func deleteMetadata(for assetURL: URL) {
        try? fileManager.removeItem(at: metadataURL(for: assetURL))
    }
}
