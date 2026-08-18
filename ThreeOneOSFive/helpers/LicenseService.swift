import Foundation
import Security
import CryptoKit

struct LicenseInfo: Codable {
    let keyFingerprint: String
    let productName: String
    let expiresAt: String
    let durationDays: Int
    let sessionExpiresAt: String
}

enum LicenseServiceError: LocalizedError {
    case invalidKey
    case keychainUnavailable
    case network
    case protocolFailure
    case unauthorized
    case expired
    case serverRejected

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Informe uma KEY válida."
        case .keychainUnavailable: return "Não foi possível acessar o armazenamento seguro."
        case .network: return "Não foi possível conectar ao servidor."
        case .protocolFailure: return "Falha de autenticação segura."
        case .unauthorized: return "A sessão não autorizou esta operação."
        case .expired: return "A sessão expirou. Faça login novamente."
        case .serverRejected: return "A KEY não foi aceita pelo servidor."
        }
    }
}

struct OperationAuthorization {
    fileprivate let id: UUID
    fileprivate let sessionID: String
    fileprivate let operation: String
    fileprivate let expiresAt: Date
}

final class LicenseService {
    static let shared = LicenseService()
    static let sessionInvalidatedNotification = Notification.Name("FFH4XLicenseSessionInvalidated")

    private let baseURL = URL(string: "https://ffh4xcorporation.online")!
    private let validatePath = "/api/secure/validate-key"
    private let checkPath = "/api/secure/session/check"
    private let product = "ruanwq"
    private let protocolName = "ffh4x-secure-v1"
    private let algorithm = "A256GCM"
    private let keychainService = "com.ffh4x.ruanwq"
    private let keyAccount = "saved-key"
    private let deviceIDAccount = "device-id"
    private let stateLock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var sessionID: String?
    private var sessionKey: SymmetricKey?
    private var sessionExpiresAt: Date?
    private var sessionKeyID: String?
    private var clientNonceB64: String?
    private var serverNonceB64: String?
    private var issuedTickets: [UUID: Date] = [:]
    private var ticketOperations: [UUID: String] = [:]
    private var validationGeneration = UUID()

    private init() {}

    func getDeviceID() -> String {
        if let saved = loadData(account: deviceIDAccount), !saved.isEmpty {
            if let legacyUUID = String(data: saved, encoding: .utf8),
               UUID(uuidString: legacyUUID) != nil {
                _ = saveData(Data(legacyUUID.utf8), account: deviceIDAccount)
                return legacyUUID
            }
            return base64URL(saved)
        }

        let bytes = randomData(count: 32)
        _ = saveData(bytes, account: deviceIDAccount)
        return base64URL(bytes)
    }

    func getSavedKey() -> String? {
        guard let data = loadData(account: keyAccount),
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    func validateKey(_ key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        let normalized = normalize(key)
        guard !normalized.isEmpty else {
            complete(completion, .failure(LicenseServiceError.invalidKey))
            return
        }

        clearSession()
        let validationID = UUID()
        stateLock.lock()
        validationGeneration = validationID
        stateLock.unlock()
        let keyData = Data(normalized.utf8)
        let keyID = base64URL(Data(SHA256.hash(data: keyData)))
        let clientNonce = randomData(count: 16)
        let clientNonceB64 = base64URL(clientNonce)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        let requestID = UUID().uuidString.lowercased()
        let context = RequestContext(
            keyID: keyID,
            clientNonceB64: clientNonceB64,
            timestamp: timestamp,
            requestID: requestID,
            sessionID: ""
        )
        let bootstrapKey = deriveKey(
            input: keyData,
            salt: clientNonce,
            info: Data("\(protocolName)/bootstrap".utf8)
        )

        do {
            let payload = try seal(
                BootstrapRequest(keyId: keyID, deviceId: getDeviceID(), product: product),
                key: bootstrapKey,
                aad: aad(direction: "request", path: validatePath, context: context)
            )
            let envelope = Envelope(
                v: 1,
                alg: algorithm,
                keyId: keyID,
                clientNonce: clientNonceB64,
                timestamp: timestamp,
                requestId: requestID,
                sessionId: nil,
                serverNonce: nil,
                payload: payload
            )
            post(path: validatePath, envelope: envelope) { [weak self] result in
                guard let self,
                      self.isCurrentValidation(validationID) else { return }
                switch result {
                case .failure:
                    self.complete(completion, .failure(LicenseServiceError.network))
                case .success(let httpResult):
                    do {
                        guard let responseEnvelope = httpResult.envelope else {
                            throw LicenseServiceError.serverRejected
                        }
                        guard let serverNonceB64 = responseEnvelope.serverNonce,
                              let serverNonce = self.dataFromBase64URL(serverNonceB64),
                              serverNonce.count == 16,
                              let returnedSessionID = responseEnvelope.sessionId,
                              !returnedSessionID.isEmpty else {
                            if let failure: ServerPayload = try? self.open(
                                responseEnvelope.payload,
                                key: bootstrapKey,
                                aad: self.aad(direction: "response", path: self.validatePath, context: context)
                            ), !failure.valid {
                                throw LicenseServiceError.serverRejected
                            }
                            throw LicenseServiceError.protocolFailure
                        }

                        let sessionKey = self.deriveKey(
                            input: keyData,
                            salt: clientNonce + serverNonce,
                            info: Data("\(self.protocolName)/session".utf8)
                        )
                        let responseContext = RequestContext(
                            keyID: keyID,
                            clientNonceB64: clientNonceB64,
                            timestamp: timestamp,
                            requestID: requestID,
                            sessionID: returnedSessionID
                        )
                        let validation: ServerPayload = try self.open(
                            responseEnvelope.payload,
                            key: sessionKey,
                            aad: self.aad(direction: "response", path: self.validatePath, context: responseContext)
                        )
                        guard validation.valid else {
                            throw LicenseServiceError.serverRejected
                        }

                        let sessionExpiresAt = validation.sessionExpiresAt
                            ?? ISO8601DateFormatter().string(from: Date().addingTimeInterval(15 * 60))
                        guard self.saveData(Data(normalized.utf8), account: self.keyAccount) else {
                            throw LicenseServiceError.keychainUnavailable
                        }
                        self.setSession(
                            id: returnedSessionID,
                            keyID: keyID,
                            clientNonceB64: clientNonceB64,
                            serverNonceB64: serverNonceB64,
                            key: sessionKey,
                            expiresAt: ISO8601DateFormatter().date(from: sessionExpiresAt)
                                ?? Date().addingTimeInterval(15 * 60)
                        )
                        let info = LicenseInfo(
                            keyFingerprint: String(keyID.prefix(12)),
                            productName: validation.productName ?? validation.product ?? "Painel iPA - Ruanwq",
                            expiresAt: validation.expiresAt ?? "",
                            durationDays: validation.durationDays ?? 0,
                            sessionExpiresAt: sessionExpiresAt
                        )
                        self.complete(completion, .success(info))
                    } catch let error as LicenseServiceError {
                        self.complete(completion, .failure(error))
                    } catch {
                        self.complete(completion, .failure(LicenseServiceError.protocolFailure))
                    }
                }
            }
        } catch {
            complete(completion, .failure(LicenseServiceError.protocolFailure))
        }
    }

    func authorizeOperation(
        _ operation: String,
        completion: @escaping (Result<OperationAuthorization, Error>) -> Void
    ) {
        guard let snapshot = sessionSnapshot() else {
            complete(completion, .failure(LicenseServiceError.unauthorized))
            return
        }
        guard snapshot.expiresAt > Date() else {
            clearSession()
            complete(completion, .failure(LicenseServiceError.expired))
            return
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        let requestID = UUID().uuidString.lowercased()
        let context = RequestContext(
            keyID: snapshot.keyID,
            clientNonceB64: snapshot.clientNonceB64,
            timestamp: timestamp,
            requestID: requestID,
            sessionID: snapshot.sessionID
        )

        do {
            let payload = try seal(
                SessionCheckRequest(action: "check", operation: operation),
                key: snapshot.key,
                aad: aad(direction: "request", path: checkPath, context: context)
            )
            let envelope = Envelope(
                v: 1,
                alg: algorithm,
                keyId: snapshot.keyID,
                clientNonce: snapshot.clientNonceB64,
                timestamp: timestamp,
                requestId: requestID,
                sessionId: snapshot.sessionID,
                serverNonce: snapshot.serverNonceB64,
                payload: payload
            )
            post(path: checkPath, envelope: envelope) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure:
                    self.clearSession()
                    self.complete(completion, .failure(LicenseServiceError.network))
                case .success(let httpResult):
                    do {
                        guard let responseEnvelope = httpResult.envelope else {
                            self.clearSession()
                            throw LicenseServiceError.expired
                        }
                        let checkContext = RequestContext(
                            keyID: snapshot.keyID,
                            clientNonceB64: snapshot.clientNonceB64,
                            timestamp: timestamp,
                            requestID: requestID,
                            sessionID: snapshot.sessionID
                        )
                        let check: ServerPayload = try self.open(
                            responseEnvelope.payload,
                            key: snapshot.key,
                            aad: self.aad(direction: "response", path: self.checkPath, context: checkContext)
                        )
                        guard httpResult.statusCode == 200, check.valid else {
                            self.clearSession()
                            throw LicenseServiceError.expired
                        }

                        let ticket = OperationAuthorization(
                            id: UUID(),
                            sessionID: snapshot.sessionID,
                            operation: operation,
                            expiresAt: min(snapshot.expiresAt, Date().addingTimeInterval(60))
                        )
                        self.stateLock.lock()
                        self.issuedTickets[ticket.id] = ticket.expiresAt
                        self.ticketOperations[ticket.id] = operation
                        self.stateLock.unlock()
                        self.complete(completion, .success(ticket))
                    } catch let error as LicenseServiceError {
                        self.complete(completion, .failure(error))
                    } catch {
                        self.clearSession()
                        self.complete(completion, .failure(LicenseServiceError.protocolFailure))
                    }
                }
            }
        } catch {
            complete(completion, .failure(LicenseServiceError.protocolFailure))
        }
    }

    func consume(_ ticket: OperationAuthorization, for operation: String) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let currentSessionID = sessionID,
              currentSessionID == ticket.sessionID,
              ticket.operation == operation,
              let expiry = issuedTickets.removeValue(forKey: ticket.id),
              ticketOperations.removeValue(forKey: ticket.id) == operation,
              expiry > Date(),
              let currentExpiry = sessionExpiresAt,
              currentExpiry > Date() else {
            throw LicenseServiceError.unauthorized
        }
    }

    func logout() {
        clearSession()
        deleteFromKeychain(account: keyAccount)
    }

    // MARK: - Protocol types

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

    private struct BootstrapRequest: Encodable {
        let keyId: String
        let deviceId: String
        let product: String
    }

    private struct SessionCheckRequest: Encodable {
        let action: String
        let operation: String
    }

    private struct ServerPayload: Decodable {
        let valid: Bool
        let product: String?
        let productName: String?
        let expiresAt: String?
        let durationDays: Int?
        let sessionExpiresAt: String?
        let reason: String?
        let error: String?
    }

    private struct PlainError: Decodable {
        let error: String?
        let code: String?
    }

    private struct RequestContext {
        let keyID: String
        let clientNonceB64: String
        let timestamp: Int64
        let requestID: String
        let sessionID: String
    }

    private struct SessionSnapshot {
        let keyID: String
        let sessionID: String
        let clientNonceB64: String
        let serverNonceB64: String
        let key: SymmetricKey
        let expiresAt: Date
    }

    private struct HTTPResult {
        let statusCode: Int
        let envelope: Envelope?
        let plainError: PlainError?
    }

    // MARK: - Crypto and HTTP

    private func isCurrentValidation(_ validationID: UUID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return validationGeneration == validationID
    }

    private func sessionSnapshot() -> SessionSnapshot? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let sessionID,
              let sessionKey,
              let sessionExpiresAt,
              let sessionKeyID,
              let clientNonceB64,
              let serverNonceB64 else {
            return nil
        }
        return SessionSnapshot(
            keyID: sessionKeyID,
            sessionID: sessionID,
            clientNonceB64: clientNonceB64,
            serverNonceB64: serverNonceB64,
            key: sessionKey,
            expiresAt: sessionExpiresAt
        )
    }

    private func setSession(
        id: String,
        keyID: String,
        clientNonceB64: String,
        serverNonceB64: String,
        key: SymmetricKey,
        expiresAt: Date
    ) {
        stateLock.lock()
        sessionID = id
        sessionKeyID = keyID
        self.clientNonceB64 = clientNonceB64
        self.serverNonceB64 = serverNonceB64
        sessionKey = key
        sessionExpiresAt = expiresAt
        issuedTickets.removeAll()
        ticketOperations.removeAll()
        stateLock.unlock()
    }

    private func clearSession() {
        stateLock.lock()
        sessionID = nil
        sessionKey = nil
        sessionExpiresAt = nil
        sessionKeyID = nil
        clientNonceB64 = nil
        serverNonceB64 = nil
        issuedTickets.removeAll()
        ticketOperations.removeAll()
        validationGeneration = UUID()
        stateLock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: LicenseService.sessionInvalidatedNotification,
                object: nil
            )
        }
    }

    private func deriveKey(input: Data, salt: Data, info: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: input),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private func aad(direction: String, path: String, context: RequestContext) -> Data {
        Data([
            protocolName,
            direction,
            "POST",
            path,
            "1",
            context.keyID,
            context.clientNonceB64,
            String(context.timestamp),
            context.requestID,
            context.sessionID
        ].joined(separator: "|").utf8)
    }

    private func seal<T: Encodable>(_ value: T, key: SymmetricKey, aad: Data) throws -> Payload {
        let plaintext = try encoder.encode(value)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: AES.GCM.Nonce(),
            authenticating: aad
        )
        return Payload(
            nonce: base64URL(Data(sealed.nonce)),
            ciphertext: base64URL(sealed.ciphertext),
            tag: base64URL(sealed.tag)
        )
    }

    private func open<T: Decodable>(_ payload: Payload, key: SymmetricKey, aad: Data) throws -> T {
        guard let nonceData = dataFromBase64URL(payload.nonce),
              let ciphertext = dataFromBase64URL(payload.ciphertext),
              let tag = dataFromBase64URL(payload.tag),
              nonceData.count == 12,
              tag.count == 16 else {
            throw LicenseServiceError.protocolFailure
        }
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try decoder.decode(T.self, from: AES.GCM.open(sealed, using: key, authenticating: aad))
    }

    private func post(
        path: String,
        envelope: Envelope,
        completion: @escaping (Result<HTTPResult, Error>) -> Void
    ) {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            complete(completion, .failure(LicenseServiceError.protocolFailure))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try encoder.encode(envelope)
        } catch {
            complete(completion, .failure(LicenseServiceError.protocolFailure))
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            guard error == nil,
                  let data,
                  let http = response as? HTTPURLResponse else {
                self.complete(completion, .failure(LicenseServiceError.network))
                return
            }
            let secureEnvelope = try? self.decoder.decode(Envelope.self, from: data)
            let plainError = try? self.decoder.decode(PlainError.self, from: data)
            self.complete(
                completion,
                .success(HTTPResult(statusCode: http.statusCode, envelope: secureEnvelope, plainError: plainError))
            )
        }.resume()
    }

    private func complete<T>(_ completion: @escaping (T) -> Void, _ value: T) {
        DispatchQueue.main.async {
            completion(value)
        }
    }

    // MARK: - Normalization and encoding

    private func normalize(_ key: String) -> String {
        key.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func randomData(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        return data
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func dataFromBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64, options: [])
    }

    // MARK: - Keychain

    private func saveData(_ data: Data, account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func loadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private extension Data {
    static func + (lhs: Data, rhs: Data) -> Data {
        var value = lhs
        value.append(rhs)
        return value
    }
}
