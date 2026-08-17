import Foundation

public struct OnyxPackageMetadata: Codable {
    public let package_id: String
    public let payload_filename: String
    public let allowed_games: [String]
    public let payload_size: Int
    public let payload_sha256: String
}

public class OnyxImporterService {
    public static let shared = OnyxImporterService()

    private let fileManager = FileManager.default

    public var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public var importedPackagesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("OnyxPackages", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    public func importOnyxFile(from sourceURL: URL) -> Result<(OnyxPackageMetadata, URL), Error> {
        do {
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: sourceURL)
            guard data.count > 4 else {
                throw NSError(domain: "OnyxImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Arquivo .onyx inválido."])
            }

            let lengthData = data.prefix(4)
            let jsonLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            let jsonData = data.subdata(in: 4..<(4 + Int(jsonLength)))
            let metadata = try JSONDecoder().decode(OnyxPackageMetadata.self, from: jsonData)

            let destinationURL = importedPackagesDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try data.write(to: destinationURL)

            return .success((metadata, destinationURL))
        } catch {
            return .failure(error)
        }
    }

    public func getImportedAssets() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: importedPackagesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "onyx" || $0.lastPathComponent.contains("onyx") || $0.pathExtension == "3105" }
    }
}
