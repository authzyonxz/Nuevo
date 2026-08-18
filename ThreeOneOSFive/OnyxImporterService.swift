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
    
    private func sanitizeFilename(_ filename: String) -> String {
        var result = filename
        
        // 1. Lógica agressiva para remover parênteses e números de cópia (ex: "file (1)", "file 2", "file_3")
        // Padrões: " (1)", "(1)", " 1", "_1"
        let patterns = [
            "\\s?\\(\\d+\\)", // Remove parênteses com ou sem espaço: " (1)" ou "(1)"
            "\\s\\d+",       // Remove espaço seguido de número: " 2"
            "_\\d+"          // Remove sublinhado seguido de número: "_3"
        ]
        
        // Primeiro, tentamos limpar preservando a extensão se ela existir
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension
        var base = url.deletingPathExtension().lastPathComponent
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                base = regex.stringByReplacingMatches(in: base, options: [], range: NSRange(location: 0, length: base.utf16.count), withTemplate: "")
            }
        }
        
        base = base.trimmingCharacters(in: .whitespaces)
        
        if ext.isEmpty {
            result = base
        } else {
            result = base + "." + ext
        }
        
        return result
    }

    public func validateUnityHeader(data: Data) -> Bool {
        guard data.count >= 7 else { return false }
        let header = String(data: data.prefix(7), encoding: .ascii) ?? ""
        return header == "UnityFS" || header == "UnityWe" // UnityWeb
    }

    public func importOnyxFile(from sourceURL: URL) -> Result<(OnyxPackageMetadata, URL), Error> {
        do {
            // Acesso seguro (se necessário, embora o picker com asCopy: true já resolva)
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            
            let data = try Data(contentsOf: sourceURL)
            let sanitizedName = sanitizeFilename(sourceURL.lastPathComponent)
            let destinationURL = importedPackagesDirectory.appendingPathComponent(sanitizedName)
            
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
        guard let data = try? Data(contentsOf: onyxURL) else { 
            print("[Onyx] Erro: Não foi possível ler o arquivo em \(onyxURL.path)")
            return nil 
        }
        
        // Verificação de cabeçalho .onyx (4 bytes de tamanho do JSON + JSON + Payload)
        if data.count > 8 {
            let lengthData = data.prefix(4)
            let rawLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
            // Converter de Big Endian (usado no Python >I) para Host Endian
            let jsonLength = Int(UInt32(bigEndian: rawLength))
            
            print("[Onyx] Detectado possível cabeçalho. Tamanho JSON: \(jsonLength), Tamanho Total: \(data.count)")
            
            if jsonLength > 0 && jsonLength < (data.count - 4) {
                let jsonData = data.subdata(in: 4..<(4 + jsonLength))
                if let _ = try? JSONDecoder().decode(OnyxPackageMetadata.self, from: jsonData) {
                    let payloadData = data.subdata(in: (4 + jsonLength)..<data.count)
                    print("[Onyx] Sucesso: Payload extraído (\(payloadData.count) bytes)")
                    return payloadData
                }
            }
        }
        
        // Se não for um pacote .onyx válido, assume que o arquivo já é o asset bruto (Raw)
        print("[Onyx] Arquivo tratado como RAW (Bruto). Tamanho: \(data.count) bytes")
        return data
    }
}
