import Foundation
import Combine
import Security
import UIKit
import CryptoKit

struct LicenseInfo: Codable {
    let status: String
    let productName: String
    let expiresAt: String
    let message: String
    let sessionExpiresAt: String?
}

private struct SecurePayload: Codable {
    let nonce: String
    let ciphertext: String
    let tag: String
}

private struct SecureEnvelope: Codable {
    let v: Int
    let alg: String
    let keyId: String
    let clientNonce: String
    let timestamp: Int64
    let requestId: String
    let sessionId: String?
    let serverNonce: String?
    let payload: SecurePayload
}

private struct ValidationPayload: Codable {
    let keyId: String
    let deviceId: String
    let product: String
}

private struct OperationPayload: Codable {
    let action: String
}

private struct ValidationResponse: Codable {
    let valid: Bool
    let status: String?
    let product: String?
    let productName: String?
    let expiresAt: String?
    let sessionId: String?
    let sessionExpiresAt: String?
    let message: String?
}

private struct SessionResponse: Codable {
    let valid: Bool
    let sessionExpiresAt: String?
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
    private let validateURL = URL(string: "https://ffh4xcorporation.online/api/secure/validate-key")!
    private let sessionCheckURL = URL(string: "https://ffh4xcorporation.online/api/secure/session/check")!
    private let product = "ruanwq"
    private let protocolName = "ffh4x-secure-v1"
    private let algorithm = "A256GCM"
    private var sessionKey: SymmetricKey?
    private var sessionId: String?
    private var sessionClientNonce: Data?
    private var sessionExpiresAt: Date?
    private let stateLock = NSLock()

    init() {
        hasStoredKey = loadSavedKey()?.isEmpty == false
    }

    func deviceID() -> String {
        if let stored = keychainRead(account: deviceAccount) { return stored }
        let identifier = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
        keychainSave(value: identifier, account: deviceAccount)
        return identifier
    }

    private func keychainSave(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        let item: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        SecItemAdd(item as CFDictionary, nil)
    }

    private func keychainRead(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func loadSavedKey() -> String? { keychainRead(account: keychainAccount) }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        authorizeOperation("activation", completion: completion)
    }

    func authorizeOperation(_ operation: String, completion: @escaping (Bool, String?) -> Void) {
        stateLock.lock()
        let ready = isAuthorized && sessionKey != nil && sessionId != nil && (sessionExpiresAt ?? .distantPast) > Date()
        stateLock.unlock()
        guard ready else {
            guard let key = loadSavedKey(), !key.isEmpty else {
                invalidateSession()
                completion(false, "Cadastre uma key ativa no Perfil para ativar funções.")
                return
            }
            validateKey(key) { success, message in
                guard success else { completion(false, message ?? "Sessão inválida ou expirada."); return }
                self.performSessionCheck(operation: operation, completion: completion)
            }
            return
        }
        performSessionCheck(operation: operation, completion: completion)
    }

    func validateKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { completion(false, "Insira uma KEY válida."); return }
        setLoading(true)
        do {
            let clientNonce = randomData(count: 16)
            let requestId = UUID().uuidString.lowercased()
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let keyId = base64URL(Data(SHA256.hash(data: Data(normalized.utf8))))
            let bootstrapKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(normalized.utf8)), salt: clientNonce, info: Data("\(protocolName)/bootstrap".utf8), outputByteCount: 32)
            let body = try encryptedEnvelope(payload: ValidationPayload(keyId: keyId, deviceId: deviceID(), product: product), key: bootstrapKey, keyId: keyId, clientNonce: clientNonce, timestamp: timestamp, requestId: requestId, sessionId: nil, serverNonce: nil, path: validateURL.path, direction: "request")
            send(body, to: validateURL) { data, response, networkError in
                do {
                    if let networkError { throw networkError }
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else { throw SecureLicenseError.invalidResponse }
                    let envelope = try self.decodeEnvelope(data)
                    guard self.isFresh(envelope.timestamp) else { throw SecureLicenseError.unauthorized }
                    guard envelope.v == 1, envelope.alg == self.algorithm, envelope.keyId == keyId, envelope.clientNonce == self.base64URL(clientNonce), envelope.requestId == requestId, let sid = envelope.sessionId, let serverNonceText = envelope.serverNonce, let serverNonce = self.decodeBase64URL(serverNonceText), serverNonce.count == 16 else { throw SecureLicenseError.invalidResponse }
                    let sessionKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(normalized.utf8)), salt: clientNonce + serverNonce, info: Data("\(self.protocolName)/session".utf8), outputByteCount: 32)
                    let decoded: ValidationResponse = try self.decryptPayload(envelope, key: sessionKey, path: self.validateURL.path, direction: "response", keyId: keyId, sessionId: sid)
                    guard decoded.valid else { throw SecureLicenseError.unauthorized }
                    self.stateLock.lock(); self.sessionKey = sessionKey; self.sessionId = sid; self.sessionClientNonce = clientNonce; self.sessionExpiresAt = self.parseDate(decoded.sessionExpiresAt) ?? Date().addingTimeInterval(900); self.stateLock.unlock()
                    let info = LicenseInfo(status: decoded.status ?? "VIP ATIVO", productName: decoded.productName ?? decoded.product ?? self.product, expiresAt: decoded.expiresAt ?? "Não informado", message: decoded.message ?? "Sucesso", sessionExpiresAt: decoded.sessionExpiresAt)
                    DispatchQueue.main.async { self.isAuthorized = true; self.hasStoredKey = true; self.licenseInfo = info; self.errorMessage = nil; self.setLoading(false); self.keychainSave(value: normalized, account: self.keychainAccount); completion(true, nil) }
                } catch { self.failSecurely(completion, message: self.genericMessage(for: error)) }
            }
        } catch { setLoading(false); completion(false, "Resposta inválida do servidor.") }
    }

    private func performSessionCheck(operation: String, completion: @escaping (Bool, String?) -> Void) {
        stateLock.lock(); guard let key = sessionKey, let sid = sessionId, let clientNonce = sessionClientNonce, let expiry = sessionExpiresAt, expiry > Date() else { stateLock.unlock(); invalidateSession(); completion(false, "Sessão inválida ou expirada."); return }; stateLock.unlock()
        do {
            let requestId = UUID().uuidString.lowercased(); let timestamp = Int64(Date().timeIntervalSince1970 * 1000); let keyId = try currentKeyId()
            let body = try encryptedEnvelope(payload: OperationPayload(action: "check"), key: key, keyId: keyId, clientNonce: clientNonce, timestamp: timestamp, requestId: requestId, sessionId: sid, serverNonce: nil, path: sessionCheckURL.path, direction: "request")
            send(body, to: sessionCheckURL) { data, response, networkError in
                do {
                    if let networkError { throw networkError }
 guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else { throw SecureLicenseError.invalidResponse }; let envelope = try self.decodeEnvelope(data); guard envelope.v == 1, envelope.alg == self.algorithm, envelope.keyId == keyId, envelope.clientNonce == self.base64URL(clientNonce), envelope.requestId == requestId, envelope.sessionId == sid else { throw SecureLicenseError.unauthorized }; guard self.isFresh(envelope.timestamp) else { throw SecureLicenseError.unauthorized }; let decoded: SessionResponse = try self.decryptPayload(envelope, key: key, path: self.sessionCheckURL.path, direction: "response", keyId: keyId, sessionId: sid); guard decoded.valid else { throw SecureLicenseError.unauthorized }; self.stateLock.lock(); self.sessionExpiresAt = self.parseDate(decoded.sessionExpiresAt) ?? expiry; self.stateLock.unlock(); completion(true, nil) } catch { self.failSecurely(completion, message: self.genericMessage(for: error)) }
            }
        } catch { failSecurely(completion, message: "Sessão inválida ou expirada.") }
    }

    func clearSavedKey() { let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: keychainAccount]; SecItemDelete(query as CFDictionary); invalidateSession(); DispatchQueue.main.async { self.hasStoredKey = false; self.licenseInfo = nil; self.errorMessage = nil } }

    private func invalidateSession() { stateLock.lock(); sessionKey = nil; sessionId = nil; sessionClientNonce = nil; sessionExpiresAt = nil; stateLock.unlock(); DispatchQueue.main.async { self.isAuthorized = false; self.isValidatingActivation = false } }
    private func setLoading(_ value: Bool) { DispatchQueue.main.async { self.isLoading = value } }
    private func currentKeyId() throws -> String { guard let key = loadSavedKey(), !key.isEmpty else { throw SecureLicenseError.unauthorized }; return base64URL(Data(SHA256.hash(data: Data(key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().utf8)))) }

    private func encryptedEnvelope<T: Encodable>(payload: T, key: SymmetricKey, keyId: String, clientNonce: Data, timestamp: Int64, requestId: String, sessionId: String?, serverNonce: String?, path: String, direction: String) throws -> Data { let plain = try JSONEncoder().encode(payload); let nonce = AES.GCM.Nonce(); let aad = Data("\(protocolName)|\(direction)|POST|\(path)|1|\(keyId)|\(base64URL(clientNonce))|\(timestamp)|\(requestId)|\(sessionId ?? "")".utf8); let sealed = try AES.GCM.seal(plain, using: key, nonce: nonce, authenticating: aad); let envelope = SecureEnvelope(v: 1, alg: algorithm, keyId: keyId, clientNonce: base64URL(clientNonce), timestamp: timestamp, requestId: requestId, sessionId: sessionId, serverNonce: serverNonce, payload: SecurePayload(nonce: base64URL(Data(sealed.nonce)), ciphertext: base64URL(sealed.ciphertext), tag: base64URL(sealed.tag))); return try JSONEncoder().encode(envelope) }

    private func decryptPayload<T: Decodable>(_ envelope: SecureEnvelope, key: SymmetricKey, path: String, direction: String, keyId: String, sessionId: String) throws -> T { guard let nonceData = decodeBase64URL(envelope.payload.nonce), nonceData.count == 12, let ciphertext = decodeBase64URL(envelope.payload.ciphertext), let tag = decodeBase64URL(envelope.payload.tag), tag.count == 16 else { throw SecureLicenseError.invalidResponse }; let aad = Data("\(protocolName)|\(direction)|POST|\(path)|1|\(keyId)|\(envelope.clientNonce)|\(envelope.timestamp)|\(envelope.requestId)|\(sessionId)".utf8); let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonceData), ciphertext: ciphertext, tag: tag); return try JSONDecoder().decode(T.self, from: AES.GCM.open(box, using: key, authenticating: aad)) }

    private func decodeEnvelope(_ data: Data) throws -> SecureEnvelope { try JSONDecoder().decode(SecureEnvelope.self, from: data) }
    private func send(_ body: Data, to url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) { var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("application/json", forHTTPHeaderField: "Accept"); request.httpBody = body; URLSession.shared.dataTask(with: request, completionHandler: completion).resume() }
    private func failSecurely(_ completion: @escaping (Bool, String?) -> Void, message: String) { invalidateSession(); setLoading(false); DispatchQueue.main.async { completion(false, message) } }
    private func genericMessage(for error: Error) -> String { error is URLError ? "Servidor indisponível." : (error is SecureLicenseError ? "Key inválida, expirada ou desativada." : "Resposta inválida do servidor.") }
    private func isFresh(_ timestamp: Int64) -> Bool { abs(Date().timeIntervalSince1970 * 1000 - Double(timestamp)) <= 120_000 }
    private func parseDate(_ value: String?) -> Date? { guard let value else { return nil }; let f = ISO8601DateFormatter(); return f.date(from: value) }
    private func randomData(count: Int) -> Data { var data = Data(count: count); _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }; return data }
    private func base64URL<D: DataProtocol>(_ data: D) -> String { Data(data).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    private func decodeBase64URL(_ value: String) -> Data? { var s = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"); s += String(repeating: "=", count: (4 - s.count % 4) % 4); return Data(base64Encoded: s) }
}

private enum SecureLicenseError: Error { case invalidResponse, unauthorized }

private func + (lhs: Data, rhs: Data) -> Data { var result = lhs; result.append(rhs); return result }
