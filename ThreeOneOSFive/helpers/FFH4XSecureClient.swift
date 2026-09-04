import CryptoKit
import Foundation
import Security

@available(iOS 15.0, *)
public final class FFH4XSecureClient {
    public struct ValidationResult: Decodable {
        public let valid: Bool
        public let product: String?
        public let productName: String?
        public let expiresAt: String?
        public let durationDays: Int?
        public let status: String?
        public let sessionExpiresAt: String?
        public let reason: String?
        public let error: String?
        public let requestId: String
    }

    public struct SessionResult: Decodable {
        public let valid: Bool
        public let product: String?
        public let expiresAt: String?
        public let sessionExpiresAt: String?
        public let reason: String?
        public let error: String?
        public let requestId: String
    }

    public enum ClientError: Error, LocalizedError {
        case invalidBaseURL
        case invalidKey
        case invalidServerResponse
        case http(status: Int, code: String?, message: String?)
        case cryptographicFailure
        case server(code: String, message: String)
        case keychain(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .invalidBaseURL: return "URL base inválida."
            case .invalidKey: return "KEY inválida."
            case .invalidServerResponse: return "Resposta inválida do servidor."
            case .http(let status, let code, let message): return "HTTP \(status)\(code.map { " [\($0)]" } ?? ""): \(message ?? "erro")"
            case .cryptographicFailure: return "Falha ao autenticar ou descriptografar a mensagem."
            case .server(let code, let message): return "\(code): \(message)"
            case .keychain(let status): return "Keychain error: \(status)"
            }
        }
    }

    private struct Payload: Codable {
        let nonce: String
        let ciphertext: String
        let tag: String
    }

    private struct Envelope: Codable {
        let v: Int
        let alg: String
        let keyId: String
        let clientNonce: String
        let timestamp: Int64
        let requestId: String
        let sessionId: String?
        let serverNonce: String?
        let payload: Payload
    }

    private struct PlainError: Decodable {
        let valid: Bool?
        let error: String?
        let code: String?
        let requestId: String?
    }

    private struct BootstrapRequest: Encodable {
        let keyId: String
        let deviceId: String
        let product: String
    }

    private struct SessionCheckRequest: Encodable {
        let action: String
    }

    private struct Context {
        let keyId: String
        let clientNonceB64: String
        let timestamp: Int64
        let requestId: String
        let sessionId: String
    }

    private struct SessionState {
        let sessionId: String
        let clientNonce: Data
        let clientNonceB64: String
        let serverNonceB64: String
        let key: SymmetricKey
    }

    private struct HTTPResult {
        let response: HTTPURLResponse
        let envelope: Envelope?
        let plainError: PlainError?
    }

    private let baseURL: URL
    private let key: String
    private let product: String
    private let keyId: String
    private let deviceId: String
    private var session: SessionState?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL = URL(string: "https://ffh4xcorporation.online")!, key: String, product: String) throws {
        guard baseURL.scheme?.lowercased() == "https", !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.invalidKey
        }
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.baseURL = baseURL
        self.key = normalizedKey
        self.product = product
        self.keyId = SHA256.hash(data: Data(normalizedKey.utf8)).base64URLString
        self.deviceId = try KeychainStore.deviceIdentifier()
    }

    public func validateKey() async throws -> ValidationResult {
        let clientNonce = try Self.randomBytes(count: 16)
        let clientNonceB64 = clientNonce.base64URLString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let requestId = UUID().uuidString.lowercased()
        let context = Context(keyId: keyId, clientNonceB64: clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: "")
        let bootstrapKey = deriveKey(salt: clientNonce, info: "ffh4x-secure-v1/bootstrap")
        let payload = try seal(BootstrapRequest(keyId: keyId, deviceId: deviceId, product: product), using: bootstrapKey, aad: makeAAD(direction: "request", path: "/api/secure/validate-key", context: context))
        let envelope = Envelope(v: 1, alg: "A256GCM", keyId: keyId, clientNonce: clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: nil, serverNonce: nil, payload: payload)
        let result = try await post(path: "/api/secure/validate-key", envelope: envelope)

        guard let responseEnvelope = result.envelope else { throw decodeHTTPError(result) }
        guard let serverNonceB64 = responseEnvelope.serverNonce,
              let sessionId = responseEnvelope.sessionId,
              let serverNonce = Data(base64URL: serverNonceB64) else {
            if let failure: ValidationResult = try? open(responseEnvelope.payload, using: bootstrapKey, aad: makeAAD(direction: "response", path: "/api/secure/validate-key", context: context)) {
                throw ClientError.server(code: failure.reason ?? "E_INVALID_KEY", message: failure.error ?? "A KEY não foi aceita.")
            }
            throw decodeHTTPError(result)
        }
        let sessionKey = deriveKey(salt: clientNonce + serverNonce, info: "ffh4x-secure-v1/session")
        let responseContext = Context(keyId: keyId, clientNonceB64: clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: sessionId)
        let validation: ValidationResult = try open(responseEnvelope.payload, using: sessionKey, aad: makeAAD(direction: "response", path: "/api/secure/validate-key", context: responseContext))
        guard validation.valid else { throw ClientError.server(code: "E_INVALID_KEY", message: "A KEY não foi aceita.") }
        session = SessionState(sessionId: sessionId, clientNonce: clientNonce, clientNonceB64: clientNonceB64, serverNonceB64: serverNonceB64, key: sessionKey)
        return validation
    }

    public func checkSession() async throws -> SessionResult {
        guard let session else { throw ClientError.server(code: "E_NO_SESSION", message: "Nenhuma sessão ativa.") }
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let requestId = UUID().uuidString.lowercased()
        let context = Context(keyId: keyId, clientNonceB64: session.clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: session.sessionId)
        let payload = try seal(SessionCheckRequest(action: "check"), using: session.key, aad: makeAAD(direction: "request", path: "/api/secure/session/check", context: context))
        let envelope = Envelope(v: 1, alg: "A256GCM", keyId: keyId, clientNonce: session.clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: session.sessionId, serverNonce: session.serverNonceB64, payload: payload)
        let result = try await post(path: "/api/secure/session/check", envelope: envelope)
        guard let responseEnvelope = result.envelope else { throw decodeHTTPError(result) }
        let responseContext = Context(keyId: keyId, clientNonceB64: session.clientNonceB64, timestamp: timestamp, requestId: requestId, sessionId: session.sessionId)
        let check: SessionResult = try open(responseEnvelope.payload, using: session.key, aad: makeAAD(direction: "response", path: "/api/secure/session/check", context: responseContext))
        if !check.valid { self.session = nil }
        return check
    }

    public func clearSession() {
        session = nil
    }

    private func post(path: String, envelope: Envelope) async throws -> HTTPResult {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw ClientError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(envelope)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidServerResponse }
        let secureEnvelope = try? decoder.decode(Envelope.self, from: data)
        let plainError = try? decoder.decode(PlainError.self, from: data)
        return HTTPResult(response: http, envelope: secureEnvelope, plainError: plainError)
    }

    private func decodeHTTPError(_ result: HTTPResult) -> ClientError {
        ClientError.http(status: result.response.statusCode, code: result.plainError?.code, message: result.plainError?.error)
    }

    private func deriveKey(salt: Data, info: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(key.utf8)), salt: salt, info: Data(info.utf8), outputByteCount: 32)
    }

    private func makeAAD(direction: String, path: String, context: Context) -> Data {
        Data([
            "ffh4x-secure-v1", direction, "POST", path, "1", context.keyId,
            context.clientNonceB64, String(context.timestamp), context.requestId, context.sessionId
        ].joined(separator: "|").utf8)
    }

    private func seal<T: Encodable>(_ value: T, using key: SymmetricKey, aad: Data) throws -> Payload {
        do {
            let sealed = try AES.GCM.seal(encoder.encode(value), using: key, nonce: AES.GCM.Nonce(), authenticating: aad)
            return Payload(nonce: Data(sealed.nonce).base64URLString, ciphertext: sealed.ciphertext.base64URLString, tag: sealed.tag.base64URLString)
        } catch {
            throw ClientError.cryptographicFailure
        }
    }

    private func open<T: Decodable>(_ payload: Payload, using key: SymmetricKey, aad: Data) throws -> T {
        do {
            guard let nonceData = Data(base64URL: payload.nonce),
                  let ciphertext = Data(base64URL: payload.ciphertext),
                  let tag = Data(base64URL: payload.tag) else { throw ClientError.cryptographicFailure }
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try decoder.decode(T.self, from: AES.GCM.open(sealed, using: key, authenticating: aad))
        } catch {
            throw ClientError.cryptographicFailure
        }
    }

    private static func randomBytes(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw ClientError.cryptographicFailure }
        return data
    }
}

@available(iOS 15.0, *)
private enum KeychainStore {
    static func deviceIdentifier() throws -> String {
        let account = "ffh4x.device-id"
        if let data = try? read(account: account), let value = String(data: data, encoding: .utf8), !value.isEmpty { return value }
        let value = UUID().uuidString.lowercased()
        try save(Data(value.utf8), account: account)
        return value
    }

    private static func save(_ data: Data, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw FFH4XSecureClient.ClientError.keychain(status) }
    }

    private static func read(account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw FFH4XSecureClient.ClientError.keychain(status) }
        return data
    }
}

private extension Data {
    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL value: String) {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }

    static func + (lhs: Data, rhs: Data) -> Data {
        var value = lhs
        value.append(rhs)
        return value
    }
}

private extension SHA256.Digest {
    var base64URLString: String {
        Data(self).base64URLString
    }
}
