import Foundation
import Combine
import CryptoKit
import Security
import UIKit

struct LicenseInfo: Codable {
    let status: String
    let productName: String
    let expiresAt: String
    let message: String
    let sessionToken: String?
}

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isAuthorized = false
    @Published var hasStoredKey = false
    @Published var isLoading = false
    @Published var isValidatingActivation = false
    @Published var errorMessage: String?
    @Published var licenseInfo: LicenseInfo?

    private let keychainService = "com.ffh4x.rage.license"
    private let keychainAccount = "saved-key"
    private let deviceAccount = "device-id"
    private let apiURL = URL(string: "https://ffh4xcorporation.online/api/secure/validate-key")!
    private let sessionURL = URL(string: "https://ffh4xcorporation.online/api/secure/session/check")!
    private let product = "ruanwq"
    private let protocolName = "ffh4x-secure-v1"
    private let algorithm = "A256GCM"

    private struct SessionState {
        let keyId: String
        let sessionId: String
        let clientNonce: Data
        let serverNonce: Data
        let sessionKey: SymmetricKey
        var expiresAt: Date
    }

    private var session: SessionState?
    private let stateLock = NSLock()

    private struct PayloadBox: Codable {
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
        let payload: PayloadBox
    }

    init() {
        hasStoredKey = !(loadSavedKey()?.isEmpty ?? true)
    }

    func deviceID() -> String {
        if let stored = keychainRead(account: deviceAccount), !stored.isEmpty {
            return stored
        }
        let identifier = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
        keychainSave(value: identifier, account: deviceAccount)
        return identifier
    }

    func loadSavedKey() -> String? {
        keychainRead(account: keychainAccount)
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async { self.isValidatingActivation = true }
        authorizeOperation("patch") { success, message in
            DispatchQueue.main.async {
                self.isValidatingActivation = false
                completion(success, success ? nil : (message ?? "Sessão inválida ou expirada."))
            }
        }
    }

    func authorizeOperation(_ operation: String, completion: @escaping (Bool, String?) -> Void) {
        guard !operation.isEmpty else {
            completion(false, "Operação inválida.")
            return
        }
        guard let active = currentSession(), active.expiresAt > Date() else {
            guard let savedKey = loadSavedKey(), !savedKey.isEmpty else {
                invalidateSession()
                completion(false, "Cadastre uma key ativa antes de continuar.")
                return
            }
            validateKey(savedKey) { success, message in
                guard success else {
                    completion(false, message ?? "Key inválida ou expirada.")
                    return
                }
                self.checkSession(completion: completion)
            }
            return
        }
        checkSession(completion: completion)
    }

    func validateKey(_ rawKey: String, completion: @escaping (Bool, String?) -> Void) {
        let key = normalizedKey(rawKey)
        guard !key.isEmpty, key.utf8.count <= 512 else {
            complete(false, "Insira uma KEY válida.", completion)
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        let clientNonce = randomData(count: 16)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        let requestId = UUID().uuidString.lowercased()
        let keyId = fingerprint(key)
        let requestContext = Context(
            version: 1,
            keyId: keyId,
            clientNonceB64: clientNonce.base64URL,
            timestamp: timestamp,
            requestId: requestId,
            sessionId: ""
        )

        do {
            let bootstrapKey = deriveKey(key: key, salt: clientNonce, info: "\(protocolName)/bootstrap")
            let plaintext: [String: Any] = ["deviceId": deviceID(), "product": product]
            let body = try makeEnvelope(
                plaintext: plaintext,
                key: bootstrapKey,
                context: requestContext,
                path: "/api/secure/validate-key"
            )
            post(body: body, url: apiURL) { data, response in
                self.finishValidation(
                    data: data,
                    response: response,
                    key: key,
                    keyId: keyId,
                    clientNonce: clientNonce,
                    requestContext: requestContext,
                    completion: completion
                )
            }
        } catch {
            complete(false, "Não foi possível preparar a validação.", completion)
        }
    }

    func clearSavedKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        invalidateSession()
        DispatchQueue.main.async {
            self.isAuthorized = false
            self.hasStoredKey = false
            self.licenseInfo = nil
            self.errorMessage = nil
        }
    }

    private func checkSession(completion: @escaping (Bool, String?) -> Void) {
        guard let active = currentSession(), active.expiresAt > Date(), let key = loadSavedKey(), !key.isEmpty else {
            invalidateSession()
            complete(false, "Sessão inválida ou expirada.", completion)
            return
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        let requestId = UUID().uuidString.lowercased()
        let context = Context(
            version: 1,
            keyId: active.keyId,
            clientNonceB64: active.clientNonce.base64URL,
            timestamp: timestamp,
            requestId: requestId,
            sessionId: active.sessionId
        )
        do {
            let body = try makeEnvelope(
                plaintext: ["action": "check"],
                key: active.sessionKey,
                context: context,
                path: "/api/secure/session/check"
            )
            post(body: body, url: sessionURL) { data, response in
                guard let data else {
                    self.invalidateSession()
                    self.complete(false, "Servidor indisponível.", completion)
                    return
                }
                do {
                    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
                    guard envelope.keyId == context.keyId,
                          envelope.clientNonce == context.clientNonceB64,
                          envelope.requestId == context.requestId,
                          envelope.sessionId == active.sessionId,
                          let serverNonceB64 = envelope.serverNonce,
                          let serverNonce = Data(base64URL: serverNonceB64) else {
                        throw SecureError.invalidResponse
                    }
                    let responseData = try open(envelope.payload, key: active.sessionKey, context: Context(
                        version: envelope.v,
                        keyId: envelope.keyId,
                        clientNonceB64: envelope.clientNonce,
                        timestamp: envelope.timestamp,
                        requestId: envelope.requestId,
                        sessionId: envelope.sessionId ?? ""
                    ), path: "/api/secure/session/check", direction: "response")
                    guard (responseData["valid"] as? Bool) == true else {
                        throw SecureError.sessionInvalid
                    }
                    let expiresAt = parseDate(responseData["expiresAt"] as? String) ?? active.expiresAt
                    let sessionExpiresAt = parseDate(responseData["sessionExpiresAt"] as? String) ?? active.expiresAt
                    self.stateLock.lock()
                    self.session = SessionState(keyId: active.keyId, sessionId: active.sessionId, clientNonce: active.clientNonce, serverNonce: serverNonce, sessionKey: active.sessionKey, expiresAt: sessionExpiresAt)
                    self.stateLock.unlock()
                    DispatchQueue.main.async {
                        self.isAuthorized = true
                        if var info = self.licenseInfo {
                            self.licenseInfo = LicenseInfo(status: info.status, productName: info.productName, expiresAt: ISO8601DateFormatter().string(from: expiresAt), message: info.message, sessionToken: info.sessionToken)
                        }
                        completion(true, nil)
                    }
                } catch {
                    self.invalidateSession()
                    self.complete(false, "Sessão inválida ou expirada.", completion)
                }
            }
        } catch {
            complete(false, "Não foi possível verificar a sessão.", completion)
        }
    }

    private func finishValidation(
        data: Data?,
        response: URLResponse?,
        key: String,
        keyId: String,
        clientNonce: Data,
        requestContext: Context,
        completion: @escaping (Bool, String?) -> Void
    ) {
        defer { DispatchQueue.main.async { self.isLoading = false } }
        guard let data else {
            invalidateSession()
            complete(false, "Servidor indisponível.", completion)
            return
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.v == 1,
                  envelope.alg == algorithm,
                  envelope.keyId == keyId,
                  envelope.clientNonce == requestContext.clientNonceB64,
                  envelope.requestId == requestContext.requestId else {
                throw SecureError.invalidResponse
            }
            let serverNonce: Data?
            let responseKey: SymmetricKey
            if let nonceB64 = envelope.serverNonce, let nonce = Data(base64URL: nonceB64), let sessionId = envelope.sessionId, !sessionId.isEmpty {
                serverNonce = nonce
                responseKey = deriveKey(key: key, salt: clientNonce + nonce, info: "\(protocolName)/session")
            } else {
                serverNonce = nil
                responseKey = deriveKey(key: key, salt: clientNonce, info: "\(protocolName)/bootstrap")
            }
            let responseContext = Context(version: envelope.v, keyId: envelope.keyId, clientNonceB64: envelope.clientNonce, timestamp: envelope.timestamp, requestId: envelope.requestId, sessionId: envelope.sessionId ?? "")
            let result = try open(envelope.payload, key: responseKey, context: responseContext, path: "/api/secure/validate-key", direction: "response")
            guard (result["valid"] as? Bool) == true, let serverNonce, let sessionId = envelope.sessionId, !sessionId.isEmpty else {
                invalidateSession()
                complete(false, "KEY inválida, expirada ou desativada.", completion)
                return
            }
            let sessionExpiresAt = parseDate(result["sessionExpiresAt"] as? String) ?? Date().addingTimeInterval(15 * 60)
            stateLock.lock()
            session = SessionState(keyId: keyId, sessionId: sessionId, clientNonce: clientNonce, serverNonce: serverNonce, sessionKey: responseKey, expiresAt: sessionExpiresAt)
            stateLock.unlock()
            let expiresAt = result["expiresAt"] as? String ?? "Indisponível"
            let info = LicenseInfo(status: result["status"] as? String ?? "VIP ATIVO", productName: result["productName"] as? String ?? (result["product"] as? String ?? product), expiresAt: expiresAt, message: result["message"] as? String ?? "Sucesso", sessionToken: nil)
            keychainSave(value: key, account: keychainAccount)
            DispatchQueue.main.async {
                self.licenseInfo = info
                self.isAuthorized = true
                self.hasStoredKey = true
                completion(true, nil)
            }
        } catch {
            invalidateSession()
            complete(false, "KEY inválida, expirada ou desativada.", completion)
        }
    }

    private struct Context {
        let version: Int
        let keyId: String
        let clientNonceB64: String
        let timestamp: Int64
        let requestId: String
        let sessionId: String
    }

    private enum SecureError: Error { case invalidResponse, sessionInvalid }

    private func makeEnvelope(plaintext: [String: Any], key: SymmetricKey, context: Context, path: String) throws -> Data {
        let plaintextData = try JSONSerialization.data(withJSONObject: plaintext, options: [])
        let sealed = try AES.GCM.seal(plaintextData, using: key, authenticating: aad(direction: "request", path: path, context: context))
        let payload = PayloadBox(nonce: Data(sealed.nonce).base64URL, ciphertext: sealed.ciphertext.base64URL, tag: sealed.tag.base64URL)
        let envelope: [String: Any] = [
            "v": context.version,
            "alg": algorithm,
            "keyId": context.keyId,
            "clientNonce": context.clientNonceB64,
            "timestamp": context.timestamp,
            "requestId": context.requestId,
            "sessionId": context.sessionId,
            "payload": ["nonce": payload.nonce, "ciphertext": payload.ciphertext, "tag": payload.tag]
        ]
        return try JSONSerialization.data(withJSONObject: envelope, options: [])
    }

    private func open(_ payload: PayloadBox, key: SymmetricKey, context: Context, path: String, direction: String) throws -> [String: Any] {
        guard let nonce = Data(base64URL: payload.nonce), let ciphertext = Data(base64URL: payload.ciphertext), let tag = Data(base64URL: payload.tag), nonce.count == 12, tag.count == 16 else {
            throw SecureError.invalidResponse
        }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(box, using: key, authenticating: aad(direction: direction, path: path, context: context))
        guard let object = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any] else { throw SecureError.invalidResponse }
        guard (object["requestId"] as? String) == context.requestId else { throw SecureError.invalidResponse }
        return object
    }

    private func aad(direction: String, path: String, context: Context) -> Data {
        Data([protocolName, direction, "POST", path, String(context.version), context.keyId, context.clientNonceB64, String(context.timestamp), context.requestId, context.sessionId].joined(separator: "|").utf8)
    }

    private func deriveKey(key: String, salt: Data, info: String) -> SymmetricKey {
        let material = SymmetricKey(data: Data(normalizedKey(key).utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: material, salt: salt, info: Data(info.utf8), outputByteCount: 32)
    }

    private func fingerprint(_ key: String) -> String {
        Data(SHA256.hash(data: Data(normalizedKey(key).utf8))).base64URL
    }

    private func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func currentSession() -> SessionState? {
        stateLock.lock(); defer { stateLock.unlock() }
        return session
    }

    private func invalidateSession() {
        stateLock.lock(); session = nil; stateLock.unlock()
        DispatchQueue.main.async { self.isAuthorized = false }
    }

    private func post(body: Data, url: URL, completion: @escaping (Data?, URLResponse?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, response, _ in
            completion(data, response)
        }.resume()
    }

    private func complete(_ success: Bool, _ message: String?, _ completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            self.errorMessage = success ? nil : message
            completion(success, message)
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func randomData(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return data
    }

    private func keychainSave(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func keychainRead(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL value: String) {
        let normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padded = normalized + String(repeating: "=", count: (4 - normalized.count % 4) % 4)
        self.init(base64Encoded: padded)
    }
}
