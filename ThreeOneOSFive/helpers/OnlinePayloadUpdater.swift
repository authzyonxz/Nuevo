import Foundation
import CryptoKit

/// Baixa versões publicadas pelo servidor e entrega o payload em memória.
/// A aplicação continua responsável por descriptografar e aplicar o conteúdo
/// usando FreeFireModManager e as regras do manifesto remoto.
final class OnlinePayloadUpdater {
    static let shared = OnlinePayloadUpdater()

    struct Manifest: Decodable {
        let schema: Int
        let generatedAt: String?
        let payloads: [RemotePayload]
        let signature: String?

        enum CodingKeys: String, CodingKey { case schema, generatedAt = "generated_at", payloads, signature }
    }

    struct RemotePayload: Decodable, Identifiable {
        let id: String
        let displayName: String
        let version: Int
        let fileName: String
        let targetPaths: [String]
        let compatibleGames: [String]
        let sha256: String
        let size: Int
        let downloadURL: String
        let enabled: Bool

        enum CodingKeys: String, CodingKey {
            case id, displayName = "display_name", version, fileName = "file_name"
            case targetPaths = "target_paths", compatibleGames = "compatible_games"
            case sha256, size, downloadURL = "download_url", enabled
        }
    }

    enum UpdateError: LocalizedError {
        case invalidBaseURL, invalidDownloadURL, invalidResponse, disabled, incompatible, hashMismatch, sizeMismatch
        var errorDescription: String? {
            switch self {
            case .invalidBaseURL: return "URL do atualizador inválida."
            case .invalidDownloadURL: return "URL do payload inválida."
            case .invalidResponse: return "Resposta inválida do atualizador."
            case .disabled: return "Payload desativado no servidor."
            case .incompatible: return "Payload incompatível com este jogo."
            case .hashMismatch: return "A validação SHA-256 do payload falhou."
            case .sizeMismatch: return "O tamanho do payload não confere com o manifesto."
            }
        }
    }

    // Substitua por https://SEU-DOMINIO, sem terminar com barra.
    private let baseURL = URL(string: "https://ffh4xcorporation.online")!
    private let session: URLSession
    private var cachedManifest: Manifest?

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration)
    }

    func manifest(forceRefresh: Bool = false) async throws -> Manifest {
        if !forceRefresh, let cachedManifest { return cachedManifest }
        guard baseURL.scheme == "https" else { throw UpdateError.invalidBaseURL }
        let url = baseURL.appendingPathComponent("api/v1/manifest")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UpdateError.invalidResponse }
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)
        cachedManifest = decoded
        return decoded
    }

    func download(id: String, bundleID: String, forceRefresh: Bool = false) async throws -> (RemotePayload, Data) {
        let manifest = try await manifest(forceRefresh: forceRefresh)
        guard let item = manifest.payloads.first(where: { $0.id == id }) else { throw UpdateError.invalidResponse }
        guard item.enabled else { throw UpdateError.disabled }
        guard item.compatibleGames.contains(bundleID) else { throw UpdateError.incompatible }
        guard let url = URL(string: item.downloadURL, relativeTo: baseURL)?.absoluteURL else { throw UpdateError.invalidDownloadURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UpdateError.invalidResponse }
        guard data.count == item.size else { throw UpdateError.sizeMismatch }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(item.sha256) == .orderedSame else { throw UpdateError.hashMismatch }
        return (item, data)
    }
}
