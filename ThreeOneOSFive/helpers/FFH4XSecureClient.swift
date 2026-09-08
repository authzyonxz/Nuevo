import CryptoKit
import Foundation
import Security

@available(iOS 16.0, *)
public final class FFH4XSecureClient {
    public struct Configuration {
        public let baseURL: URL
        public let clientId: String
        public let sharedSecretBase64URL: String
        public let packagePublicId: String
        public let packageSlug: String
        public let packageName: String

        public static let externalIOS = Configuration(
            baseURL: URL(string: "https://keyauthv2.org")!,
            clientId: "ka_2QI_FnOHu2ILkUHs-dhOT9w0",
            sharedSecretBase64URL: "rwiddAZvOwN2cieVHRP9Ai2rfL9ZMSaz4NhjzEQR0w0",
            packagePublicId: "5d933aad-02da-4f37-a509-dfffee5600ed",
            packageSlug: "external1",
            packageName: "EXTERNAL - iOS"
        )
    }

    public struct PackageStatus: Decodable {
        public let available: Bool
        public let status: String
        public let publicId: String
        public let name: String
        public let slug: String
    }

    public struct StartSessionResult: Decodable {
        public let token: String
        public let expiresAt: Int64
        public let profileUrl: URL
        public let webUrl: URL
    }

    public struct PackageSummary: Decodable {
        public let publicId: String
        public let name: String
        public let slug: String
        public let status: String
    }

    public struct AccessStatus: Decodable {
        public let registered: Bool
        public let deviceRegistered: Bool
        public let reason: String?
        public let key: String?
        public let status: String?
        public let durationDays: Int?
        public let activatedAt: Int64?
        public let expiresAt: Int64?
        public let package: PackageSummary?
    }

    public struct SessionStatus: Decodable {
        public let status: String
        public let expiresAt: Int64
        public let captured: Bool
        public let deviceRegistered: Bool
        public let registered: Bool
        public let access: AccessStatus?
        public let package: PackageSummary
    }

    public struct ActivationResult: Decodable {
        public let valid: Bool
        public let key: String
        public let status: String
        public let package: ActivatedPackage
        public let durationDays: Int
        public let activatedAt: Int64
        public let expiresAt: Int64
        public let device: String
    }

    public struct ActivatedPackage: Decodable {
        public let publicId: String
        public let name: String
    }

    public enum ClientError: Error, LocalizedError {
        case invalidSecret
        case invalidEnvelope
        case invalidServerResponse
        case timestampExpired
        case signatureInvalid
        case http(status: Int, code: String?)
        case server(code: String)
        case packageMismatch
        case cryptoFailure

        public var errorDescription: String? {
            switch self {
            case .invalidSecret: return "Configuração segura inválida."
            case .invalidEnvelope, .invalidServerResponse: return "Resposta inválida do servidor."
            case .timestampExpired: return "O relógio do dispositivo está incorreto."
            case .signatureInvalid, .cryptoFailure: return "Falha ao autenticar a comunicação com o servidor."
            case .http(let status, let code): return "HTTP \(status)\(code.map { " [\($0)]" } ?? "")"
            case .server(let code): return code
            case .packageMismatch: return "O Package recebido não corresponde à configuração do aplicativo."
            }
        }
    }

    private struct EmptyPayload: Codable {}
    private struct SessionPayload: Encodable { let token: String }
    private struct ActivatePayload: Encodable { let token: String; let key: String }
    private struct APIResponse<T: Decodable>: Decodable {
        let ok: Bool
        let data: T?
        let error: ErrorBody?
    }
    private struct ErrorBody: Decodable { let code: String }
    private struct Envelope: Codable {
        let version: Int
        let clientId: String
        let timestamp: Int64
        let nonce: String
        let iv: String
        let ciphertext: String
        let tag: String
        let signature: String
    }

    private let baseURL: URL
    private let clientId: String
    private let expectedPackagePublicId: String
    private let expectedPackageSlug: String
    private let expectedPackageName: String
    private let aesKey: SymmetricKey
    private let hmacKey: SymmetricKey
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(configuration: Configuration = .externalIOS) throws {
        guard configuration.baseURL.scheme?.lowercased() == "https",
              configuration.clientId.hasPrefix("ka_") else {
            throw ClientError.invalidEnvelope
        }
        let secret = try Data(base64URL: configuration.sharedSecretBase64URL)
        guard secret.count == 32 else { throw ClientError.invalidSecret }
        guard UUID(uuidString: configuration.packagePublicId) != nil,
              !configuration.packageSlug.isEmpty,
              !configuration.packageName.isEmpty else {
            throw ClientError.packageMismatch
        }
        baseURL = configuration.baseURL
        clientId = configuration.clientId
        expectedPackagePublicId = configuration.packagePublicId
        expectedPackageSlug = configuration.packageSlug
        expectedPackageName = configuration.packageName
        let material = SymmetricKey(data: secret)
        let salt = Data("keyforge-secure-v1".utf8)
        aesKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: material, salt: salt, info: Data("client-payload-encryption".utf8), outputByteCount: 32)
        hmacKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: material, salt: salt, info: Data("client-request-signature".utf8), outputByteCount: 32)
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 30
        session = URLSession(configuration: sessionConfiguration)
    }

    public func packageStatus() async throws -> PackageStatus {
        let package = try await post(path: "/api/v1/package/status", payload: EmptyPayload(), response: PackageStatus.self)
        guard package.publicId == expectedPackagePublicId,
              package.slug == expectedPackageSlug,
              package.name == expectedPackageName,
              package.status == "active",
              package.available else {
            throw ClientError.packageMismatch
        }
        return package
    }

    public func startSession() async throws -> StartSessionResult {
        try await post(path: "/api/v1/device/session/start", payload: EmptyPayload(), response: StartSessionResult.self)
    }

    public func sessionStatus(token: String) async throws -> SessionStatus {
        let status = try await post(path: "/api/v1/device/session/status", payload: SessionPayload(token: token), response: SessionStatus.self)
        guard status.package.publicId == expectedPackagePublicId,
              status.package.slug == expectedPackageSlug,
              status.package.name == expectedPackageName,
              status.package.status == "active" else {
            throw ClientError.packageMismatch
        }
        return status
    }

    public func activate(token: String, key: String) async throws -> ActivationResult {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw ClientError.server(code: "KEY_INVALID") }
        let result = try await post(path: "/api/v1/device/session/activate", payload: ActivatePayload(token: token, key: normalized), response: ActivationResult.self)
        guard result.package.publicId == expectedPackagePublicId,
              result.package.name == expectedPackageName else {
            throw ClientError.packageMismatch
        }
        return result
    }

    private func post<Payload: Encodable, Response: Decodable>(path: String, payload: Payload, response: Response.Type) async throws -> Response {
        let envelope = try makeEnvelope(payload: payload, method: "POST", path: path)
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"
        request.setValue(clientId, forHTTPHeaderField: "X-KeyAuth-Client")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(envelope)

        let (data, responseObject) = try await session.data(for: request)
        guard let http = responseObject as? HTTPURLResponse else { throw ClientError.invalidServerResponse }
        guard let responseEnvelope = try? decoder.decode(Envelope.self, from: data) else {
            throw ClientError.http(status: http.statusCode, code: nil)
        }
        let decoded: APIResponse<Response>
        do {
            decoded = try decrypt(responseEnvelope, as: APIResponse<Response>.self, method: "POST", path: path)
        } catch {
            if let errorResponse = try? decrypt(responseEnvelope, as: APIResponse<EmptyPayload>.self, method: "POST", path: path),
               let code = errorResponse.error?.code {
                throw ClientError.server(code: code)
            }
            throw error
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(status: http.statusCode, code: decoded.error?.code)
        }
        guard decoded.ok, let value = decoded.data else {
            throw ClientError.server(code: decoded.error?.code ?? "REQUEST_FAILED")
        }
        return value
    }

    private func makeEnvelope<T: Encodable>(payload: T, method: String, path: String) throws -> Envelope {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let nonce = try Self.randomBytes(count: 18).base64URL
        let ivData = try Self.randomBytes(count: 12)
        let iv = ivData.base64URL
        let aad = "v1|\(clientId)|\(timestamp)|\(nonce)|\(method.uppercased())|\(path)"
        let plaintext = try encoder.encode(payload)
        let sealed = try AES.GCM.seal(plaintext, using: aesKey, nonce: AES.GCM.Nonce(data: ivData), authenticating: Data(aad.utf8))
        let ciphertext = sealed.ciphertext.base64URL
        let tag = sealed.tag.base64URL
        let signedData = Data("\(aad)|\(iv)|\(ciphertext)|\(tag)".utf8)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: signedData, using: hmacKey)).base64URL
        return Envelope(version: 1, clientId: clientId, timestamp: timestamp, nonce: nonce, iv: iv, ciphertext: ciphertext, tag: tag, signature: signature)
    }

    private func decrypt<T: Decodable>(_ envelope: Envelope, as type: T.Type, method: String, path: String) throws -> T {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard abs(now - envelope.timestamp) <= 5 * 60 * 1000 else { throw ClientError.timestampExpired }
        guard envelope.version == 1, envelope.clientId == clientId else { throw ClientError.invalidEnvelope }
        let aad = "v1|\(clientId)|\(envelope.timestamp)|\(envelope.nonce)|\(method.uppercased())|\(path)"
        let signedData = Data("\(aad)|\(envelope.iv)|\(envelope.ciphertext)|\(envelope.tag)".utf8)
        let expectedSignature = Data(HMAC<SHA256>.authenticationCode(for: signedData, using: hmacKey)).base64URL
        guard expectedSignature == envelope.signature else { throw ClientError.signatureInvalid }
        let iv = try Data(base64URL: envelope.iv)
        let ciphertext = try Data(base64URL: envelope.ciphertext)
        let tag = try Data(base64URL: envelope.tag)
        guard iv.count == 12, tag.count == 16 else { throw ClientError.invalidEnvelope }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ciphertext, tag: tag)
        let clear = try AES.GCM.open(box, using: aesKey, authenticating: Data(aad.utf8))
        return try decoder.decode(T.self, from: clear)
    }

    private static func randomBytes(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw ClientError.cryptoFailure }
        return data
    }
}

private extension Data {
    init(base64URL value: String) throws {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { throw FFH4XSecureClient.ClientError.invalidSecret }
        self = data
    }

    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
