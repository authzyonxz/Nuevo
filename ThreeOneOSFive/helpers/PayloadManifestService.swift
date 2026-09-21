import Foundation

struct PayloadManifestService {
    static let manifestURL = URL(string: "https://3000-ip9j4fvzk6ohtbw6ixi8o-bddbb8fd.us1.manus.computer/api/payload-manifest.json")!

    struct Manifest: Decodable {
        let schemaVersion: Int
        let generatedAt: String?
        let functions: [RemoteFunction]
    }

    struct RemoteFunction: Decodable {
        let functionId: Int
        let functionName: String
        let description: String
        let payloadURL: String
        let updatedAt: Date?
    }

    enum ManifestError: LocalizedError {
        case invalidResponse
        case unavailable

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "O manifesto remoto é inválido."
            case .unavailable: return "O publicador de payloads está indisponível."
            }
        }
    }

    static func fetch() async throws -> Manifest {
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ManifestError.unavailable
        }
        do {
            return try JSONDecoder().decode(Manifest.self, from: data)
        } catch {
            throw ManifestError.invalidResponse
        }
    }
}
