import Foundation

public struct OnyxPackageMetadata: Codable {
    public let package_id: String
    public let payload_filename: String
    public let allowed_games: [String]
    public let payload_size: Int
    public let payload_sha256: String
    
    public static func raw(filename: String, size: Int) -> OnyxPackageMetadata {
        return OnyxPackageMetadata(
            package_id: "raw_\(UUID().uuidString.prefix(8))",
            payload_filename: filename,
            allowed_games: ["com.dts.freefireth", "com.dts.freefiremax"],
            payload_size: size,
            payload_sha256: ""
        )
    }
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
            // Acesso seguro (se necessário, embora o picker com asCopy: true já resolva)
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            
            let data = try Data(contentsOf: sourceURL)
            let destinationURL = importedPackagesDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            
            // Tentar detectar se é um pacote .onyx legítimo (4 bytes length + JSON)
            if data.count > 8 {
                let lengthData = data.prefix(4)
                let jsonLength = Int(lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                
                // Validação de segurança para evitar crash de memória/bounds
                if jsonLength > 0 && jsonLength < (data.count - 4) {
                    let jsonData = data.subdata(in: 4..<(4 + jsonLength))
                    if let metadata = try? JSONDecoder().decode(OnyxPackageMetadata.self, from: jsonData) {
                        // É um arquivo .onyx válido
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try? fileManager.removeItem(at: destinationURL)
                        }
                        try data.write(to: destinationURL)
                        return .success((metadata, destinationURL))
                    }
                }
            }
            
            // Se falhou no parsing do Onyx, tratar como arquivo BRUTO (Raw Asset)
            // Isso permite importar qualquer arquivo (ex: cache_res) diretamente
            let rawMetadata = OnyxPackageMetadata.raw(filename: sourceURL.lastPathComponent, size: data.count)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            try data.write(to: destinationURL)
            
            return .success((rawMetadata, destinationURL))
            
        } catch {
            return .failure(error)
        }
    }
    
    public func getImportedAssets() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: importedPackagesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        // Aceitar qualquer arquivo que esteja na pasta de pacotes
        return files.filter { !($0.lastPathComponent.hasPrefix(".")) }
    }
    
    public func extractPayload(from onyxURL: URL) -> Data? {
        guard let data = try? Data(contentsOf: onyxURL) else { return nil }
        
        if data.count > 8 {
            let lengthData = data.prefix(4)
            let jsonLength = Int(lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            
            if jsonLength > 0 && jsonLength < (data.count - 4) {
                // Se for Onyx, pula o cabeçalho e o JSON
                return data.subdata(in: (4 + jsonLength)..<data.count)
            }
        }
        
        // Se for arquivo bruto, o payload é o próprio arquivo
        return data
    }
}
