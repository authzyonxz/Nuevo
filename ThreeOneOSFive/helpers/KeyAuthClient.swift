import Foundation
import Security
import CommonCrypto

// MARK: - Configuration

public struct KeyAuthConfiguration: Sendable {
    public let baseURL: URL
    public let issuer: String
    public let audience: String
    public let package: String
    public let keyID: String
    /// Base64URL of the uncompressed P-256 public key (65 bytes, prefix 0x04).
    public let serverPublicKeyX963: String
    public let policyVersion: Int

    public init(
        baseURL: URL,
        issuer: String,
        audience: String = "keyauth-ios",
        package: String,
        keyID: String,
        serverPublicKeyX963: String,
        policyVersion: Int = 2
    ) {
        self.baseURL = baseURL
        self.issuer = issuer
        self.audience = audience
        self.package = package
        self.keyID = keyID
        self.serverPublicKeyX963 = serverPublicKeyX963
        self.policyVersion = policyVersion
    }
}

// MARK: - Public models

public struct PackageStatus: Decodable, Sendable {
    public let publicId: String
    public let name: String
    public let slug: String
    public let status: String
    public let available: Bool
}

public struct PackageSummary: Decodable, Sendable {
    public let publicId: String
    public let name: String
    public let slug: String
}

public struct DeviceSessionStart: Decodable, Sendable {
    public let token: String
    public let expiresAt: Int64
    public let package: PackageSummary?

    public func profileURL(baseURL: URL, packageSlug: String) -> URL? {
        URL(string: "/api/v1/device/profile/\(token).mobileconfig?slug=\(packageSlug.urlQueryEscaped)", relativeTo: baseURL)
    }

    public func portalURL(baseURL: URL, packageSlug: String) -> URL? {
        URL(string: "/device/\(packageSlug.urlPathEscaped)/\(token.urlPathEscaped)", relativeTo: baseURL)
    }
}

public struct DeviceSessionStatus: Decodable, Sendable {
    public let status: String
    public let expiresAt: Int64
    public let captured: Bool
    public let deviceRegistered: Bool
    public let registered: Bool
    public let access: AccessState?

    init(status: String, expiresAt: Int64, captured: Bool, deviceRegistered: Bool, registered: Bool, access: AccessState? = nil) {
        self.status = status
        self.expiresAt = expiresAt
        self.captured = captured
        self.deviceRegistered = deviceRegistered
        self.registered = registered
        self.access = access
    }

    private enum CodingKeys: String, CodingKey {
        case status, expiresAt, captured, deviceRegistered, registered, access
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.expiresAt = try container.decodeIfPresent(Int64.self, forKey: .expiresAt) ?? 0
        self.captured = try container.decodeIfPresent(Bool.self, forKey: .captured) ?? false
        self.deviceRegistered = try container.decodeIfPresent(Bool.self, forKey: .deviceRegistered) ?? false
        self.registered = try container.decodeIfPresent(Bool.self, forKey: .registered) ?? false
        self.access = try container.decodeIfPresent(AccessState.self, forKey: .access)
    }

    public struct AccessState: Decodable, Sendable {
        public let registered: Bool
        public let deviceRegistered: Bool
        public let reason: String?
        public let key: String?
        public let status: String?
        public let expiresAt: Int64?
    }
}

public struct AuthorizationResult: Decodable, Sendable {
    public let grant: String
    public let claims: GrantClaims
    public let kid: String?

    private enum CodingKeys: String, CodingKey {
        case grant, claims, grantPayload, kid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.grant = try container.decode(String.self, forKey: .grant)
        let claims = try container.decodeIfPresent(GrantClaims.self, forKey: .claims)
            ?? (try container.decodeIfPresent(GrantClaims.self, forKey: .grantPayload))
        guard let claims else {
            throw DecodingError.keyNotFound(
                CodingKeys.grantPayload,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing claims/grantPayload")
            )
        }
        self.claims = claims
        self.kid = try container.decodeIfPresent(String.self, forKey: .kid)
    }
}

public struct GrantClaims: Decodable, Sendable {
    public let iss: String
    public let aud: String
    public let package: String
    public let packageId: String
    public let installationId: String
    public let sessionId: String
    public let sessionHash: String
    public let key: String
    public let keyStatus: String
    public let policyVersion: Int
    public let scope: [String]
    public let iat: Int64
    public let exp: Int64
    public let jti: String
}

public final class KeyAuthSessionStore: @unchecked Sendable {
    private let service: String

    public init(namespace: String = Bundle.main.bundleIdentifier ?? "app") {
        let safe = namespace.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        self.service = "com.keyauth.v2.session." + safe
    }

    public func load() throws -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw KeyAuthError.keychain(status) }
        return value
    }

    public func save(_ token: String) throws {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData] = Data(token.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyAuthError.keychain(status) }
    }

    public func clear() throws {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyAuthError.keychain(status) }
    }
}

public enum KeyAuthError: Error, LocalizedError {
    case invalidConfiguration(String)
    case invalidResponse
    case server(code: String)
    case network(Error)
    case keychain(OSStatus)
    case security(String)
    case invalidChallenge
    case invalidGrant
    case sessionRequired

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let value): return "Configuração inválida: \(value)"
        case .invalidResponse: return "Resposta inválida do Key Auth."
        case .server(let code): return "Key Auth. recusou a operação: \(code)"
        case .network(let error): return "Falha de rede: \(error.localizedDescription)"
        case .keychain(let status): return "Falha no Keychain (OSStatus \(status))."
        case .security(let value): return "Falha criptográfica: \(value)"
        case .invalidChallenge: return "Challenge inválido ou não vinculado à sessão."
        case .invalidGrant: return "Grant inválido ou não assinado pelo servidor configurado."
        case .sessionRequired: return "É necessário informar uma sessão de dispositivo."
        }
    }
}

// MARK: - Client

public final class KeyAuthClient: @unchecked Sendable {
    public let configuration: KeyAuthConfiguration
    private let session: URLSession
    private let installationStore: KeyAuthInstallationStore
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(configuration: KeyAuthConfiguration, urlSession: URLSession = .shared) throws {
        guard configuration.baseURL.scheme?.lowercased() == "https" else {
            throw KeyAuthError.invalidConfiguration("baseURL deve usar HTTPS")
        }
        guard !configuration.package.isEmpty else { throw KeyAuthError.invalidConfiguration("package vazio") }
        guard !configuration.keyID.isEmpty else { throw KeyAuthError.invalidConfiguration("kid vazio") }
        self.configuration = configuration
        self.session = urlSession
        self.installationStore = try KeyAuthInstallationStore(namespace: configuration.issuer)
    }

    public func packageStatus() async throws -> PackageStatus {
        try await post("/api/v2/package/status", body: PackageRequest(package: configuration.package), as: PackageStatus.self)
    }

    public func startDeviceSession() async throws -> DeviceSessionStart {
        try await post("/api/v2/device/session/start", body: PackageRequest(package: configuration.package), as: DeviceSessionStart.self)
    }

    public func deviceSessionStatus(token: String) async throws -> DeviceSessionStatus {
        guard !token.isEmpty else { throw KeyAuthError.sessionRequired }
        do {
            return try await post(
                "/api/v2/device/session/status",
                body: SessionRequest(package: configuration.package, token: token),
                as: DeviceSessionStatus.self
            )
        } catch let error as KeyAuthError {
            // The live API returns this code until the Profile Service receives the UDID.
            // It is a normal pending state, not an invalid session.
            if case .server(let code) = error, code == "DEVICE_NOT_CAPTURED" {
                return DeviceSessionStatus(status: "pending", expiresAt: 0, captured: false, deviceRegistered: false, registered: false)
            }
            throw error
        }
    }

    /// Completes v2 enrollment, proves possession of the installation key and issues a short ES256 grant.
    /// The license key is sent only to `/api/v2/authorization/issue`.
    public func activateSessionKey(token: String, licenseKey: String? = nil) async throws -> AuthorizationResult {
        guard !token.isEmpty else { throw KeyAuthError.sessionRequired }
        let installation = try installationStore.loadOrCreate()
        let sessionHash = Self.sessionHash(token)
        let publicKey = try Self.publicKeyX963(from: installation.privateKey)

        let enrollmentRequest = InstallationRequest(
            package: configuration.package,
            token: token,
            installationId: installation.id,
            publicKey: publicKey
        )
        let enrollmentChallenge = try await post(
            "/api/v2/installations/challenge", body: enrollmentRequest, as: ChallengeResponse.self
        )
        try Self.validateCanonical(
            enrollmentChallenge.canonical,
            purpose: "enrollment",
            challengeID: enrollmentChallenge.challengeId,
            package: configuration.package,
            installationID: installation.id,
            sessionHash: sessionHash
        )
        let enrollmentSignature = try Self.sign(enrollmentChallenge.canonical, with: installation.privateKey)
        let enrollmentComplete = EnrollmentCompleteRequest(
            package: configuration.package,
            token: token,
            installationId: installation.id,
            publicKey: publicKey,
            challengeId: enrollmentChallenge.challengeId,
            challenge: enrollmentChallenge.challenge,
            signature: enrollmentSignature
        )
        _ = try await post("/api/v2/installations/complete", body: enrollmentComplete, as: EnrollmentCompleteResponse.self)

        let authorizationRequest = SessionInstallationRequest(
            package: configuration.package,
            token: token,
            installationId: installation.id
        )
        let authorizationChallenge = try await post(
            "/api/v2/authorization/challenge", body: authorizationRequest, as: ChallengeResponse.self
        )
        try Self.validateCanonical(
            authorizationChallenge.canonical,
            purpose: "authorization",
            challengeID: authorizationChallenge.challengeId,
            package: configuration.package,
            installationID: installation.id,
            sessionHash: sessionHash
        )
        let authorizationSignature = try Self.sign(authorizationChallenge.canonical, with: installation.privateKey)
        let issue = AuthorizationIssueRequest(
            package: configuration.package,
            token: token,
            installationId: installation.id,
            challengeId: authorizationChallenge.challengeId,
            challenge: authorizationChallenge.challenge,
            signature: authorizationSignature,
            key: normalizedLicenseKey(licenseKey)
        )
        let result = try await post("/api/v2/authorization/issue", body: issue, as: AuthorizationResult.self)
        if let kid = result.kid, kid != configuration.keyID { throw KeyAuthError.invalidGrant }
        try Self.verifyGrant(
            result.grant,
            configuration: configuration,
            token: token,
            installationID: installation.id
        )
        return result
    }

    public func introspectGrant(_ grant: String, token: String) async throws -> GrantClaims {
        guard !token.isEmpty else { throw KeyAuthError.sessionRequired }
        let response = try await post(
            "/api/v2/grant/introspect",
            body: GrantIntrospectionRequest(package: configuration.package, token: token, grant: grant),
            as: GrantIntrospectionResponse.self
        )
        return response.claims
    }

    private func post<Body: Encodable, Output: Decodable>(_ path: String, body: Body, as: Output.Type) async throws -> Output {
        guard let url = URL(string: path, relativeTo: configuration.baseURL) else {
            throw KeyAuthError.invalidConfiguration("rota inválida: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw KeyAuthError.invalidResponse }
            let envelope: APIResponse<Output>
            do {
                envelope = try decoder.decode(APIResponse<Output>.self, from: data)
            } catch {
                // JSON/shape errors are response errors, not connectivity errors.
                throw KeyAuthError.invalidResponse
            }
            if !envelope.ok || !(200..<300).contains(http.statusCode) {
                throw KeyAuthError.server(code: envelope.error?.code ?? "REQUEST_FAILED")
            }
            guard let value = envelope.data else { throw KeyAuthError.invalidResponse }
            return value
        } catch let error as KeyAuthError {
            throw error
        } catch {
            throw KeyAuthError.network(error)
        }
    }

    private func normalizedLicenseKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.uppercased().filter { $0 != " " && $0 != "-" }
        return normalized.isEmpty ? nil : normalized
    }
}

// MARK: - Wire models

private struct APIResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIError?
    struct APIError: Decodable { let code: String }
}
private struct PackageRequest: Encodable { let package: String }
private struct SessionRequest: Encodable { let package: String; let token: String }
private struct InstallationRequest: Encodable { let package: String; let token: String; let installationId: String; let publicKey: String }
private struct SessionInstallationRequest: Encodable { let package: String; let token: String; let installationId: String }
private struct EnrollmentCompleteRequest: Encodable { let package: String; let token: String; let installationId: String; let publicKey: String; let challengeId: String; let challenge: String; let signature: String }
private struct AuthorizationIssueRequest: Encodable { let package: String; let token: String; let installationId: String; let challengeId: String; let challenge: String; let signature: String; let key: String? }
private struct GrantIntrospectionRequest: Encodable { let package: String; let token: String; let grant: String }
private struct ChallengeResponse: Decodable { let challengeId: String; let challenge: String; let canonical: String; let expiresAt: Int64 }
private struct EnrollmentCompleteResponse: Decodable { let installationId: String; let status: String }
private struct GrantIntrospectionResponse: Decodable { let claims: GrantClaims }

// MARK: - Keychain installation identity

private struct InstallationMaterial {
    let id: String
    let privateKey: SecKey
}

private final class KeyAuthInstallationStore: @unchecked Sendable {
    private let idService: String
    private let keyTag: Data

    init(namespace: String) throws {
        guard let data = namespace.data(using: .utf8) else { throw KeyAuthError.security("namespace") }
        let digest = SHA256.hash(data: data)
        let suffix = digest.base64URLEncodedString()
        self.idService = "com.keyauth.v2.installation-id." + suffix
        self.keyTag = Data(("com.keyauth.v2.installation-key.p256." + suffix).utf8)
    }

    func loadOrCreate() throws -> InstallationMaterial {
        if let id = try readString(), let key = try readPrivateKey() { return InstallationMaterial(id: id, privateKey: key) }
        let id = UUID().uuidString.lowercased()
        let key = try createPrivateKey()
        try saveString(id)
        return InstallationMaterial(id: id, privateKey: key)
    }

    private func readString() throws -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: idService, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw KeyAuthError.keychain(status) }
        return value
    }

    private func saveString(_ value: String) throws {
        let base: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: idService]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData] = Data(value.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyAuthError.keychain(status) }
    }

    private func readPrivateKey() throws -> SecKey? {
        let query: [CFString: Any] = [kSecClass: kSecClassKey, kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrApplicationTag: keyTag, kSecReturnRef: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let result else { throw KeyAuthError.keychain(status) }
        return (result as! SecKey)
    }

    private func createPrivateKey() throws -> SecKey {
        let privateAttributes: [CFString: Any] = [kSecAttrIsPermanent: true, kSecAttrApplicationTag: keyTag, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: 256, kSecPrivateKeyAttrs: privateAttributes]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let message = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "chave não criada"
            throw KeyAuthError.security(message)
        }
        return key
    }
}

// MARK: - Cryptographic helpers

private enum SHA256 {
    static func hash(data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return Data(digest)
    }
}

private extension String {
    var urlPathEscaped: String { addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self }
    var urlQueryEscaped: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL value: String) {
        guard !value.isEmpty, !value.contains("="), value.allSatisfy({ $0.isNumber || $0.isLetter || $0 == "_" || $0 == "-" }), value.count % 4 != 1 else { return nil }
        var padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        guard let data = Data(base64Encoded: padded), data.base64URLEncodedString() == value else { return nil }
        self = data
    }
}

private extension KeyAuthClient {
    static func sessionHash(_ token: String) -> String { SHA256.hash(data: Data(token.utf8)).base64URLEncodedString() }

    static func publicKeyX963(from privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw KeyAuthError.security("chave pública ausente") }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?, data.count == 65, data.first == 0x04 else { throw KeyAuthError.security("chave pública P-256 inválida") }
        return data.base64URLEncodedString()
    }

    static func sign(_ canonical: String, with privateKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, Data(canonical.utf8) as CFData, &error) as Data? else {
            throw KeyAuthError.security((error?.takeRetainedValue() as Error?)?.localizedDescription ?? "assinatura não criada")
        }
        return signature.base64URLEncodedString()
    }

    static func validateCanonical(_ canonical: String, purpose: String, challengeID: String, package: String, installationID: String, sessionHash: String) throws {
        let lines = canonical.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "KA2-PROOF-V1" else { throw KeyAuthError.invalidChallenge }
        var fields: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: "=") else { throw KeyAuthError.invalidChallenge }
            let name = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            guard !name.isEmpty, fields[name] == nil else { throw KeyAuthError.invalidChallenge }
            fields[name] = value
        }
        let expected = ["purpose": purpose, "challengeId": challengeID, "package": package, "installationId": installationID, "sessionHash": sessionHash]
        guard expected.allSatisfy({ fields[$0.key] == $0.value }) else { throw KeyAuthError.invalidChallenge }
    }

    static func verifyGrant(_ grant: String, configuration: KeyAuthConfiguration, token: String, installationID: String) throws {
        let parts = grant.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let headerData = Data(base64URL: parts[0]), let payloadData = Data(base64URL: parts[1]), let rawSignature = Data(base64URL: parts[2]), rawSignature.count == 64 else { throw KeyAuthError.invalidGrant }
        let decoder = JSONDecoder()
        let header = try decoder.decode(JWSHeader.self, from: headerData)
        let claims = try decoder.decode(GrantClaims.self, from: payloadData)
        guard header.alg == "ES256", header.typ == "KA2+jwt", header.kid == configuration.keyID,
              claims.iss == configuration.issuer, claims.aud == configuration.audience, claims.package == configuration.package,
              claims.installationId == installationID, claims.sessionHash == sessionHash(token), claims.keyStatus == "active",
              claims.policyVersion == configuration.policyVersion, claims.scope.contains("app:open") else { throw KeyAuthError.invalidGrant }
        let now = Int64(Date().timeIntervalSince1970)
        guard claims.iat <= now + 30, claims.exp > now - 30, claims.exp > claims.iat, claims.exp - claims.iat <= 300 else { throw KeyAuthError.invalidGrant }
        guard let keyData = Data(base64URL: configuration.serverPublicKeyX963), keyData.count == 65, keyData.first == 0x04 else { throw KeyAuthError.invalidGrant }
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits: 256]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else { throw KeyAuthError.invalidGrant }
        guard let der = p1363ToDER(rawSignature) else { throw KeyAuthError.invalidGrant }
        let valid = SecKeyVerifySignature(key, .ecdsaSignatureMessageX962SHA256, Data("\(parts[0]).\(parts[1])".utf8) as CFData, der as CFData, &error)
        guard valid else { throw KeyAuthError.invalidGrant }
    }

    private static func p1363ToDER(_ raw: Data) -> Data? {
        guard raw.count == 64 else { return nil }
        func integer(_ data: Data) -> Data {
            var bytes = Array(data.drop { $0 == 0 })
            if bytes.isEmpty { bytes = [0] }
            if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
            return Data([0x02, UInt8(bytes.count)]) + Data(bytes)
        }
        let body = integer(raw.subdata(in: 0..<32)) + integer(raw.subdata(in: 32..<64))
        guard body.count < 128 else { return nil }
        return Data([0x30, UInt8(body.count)]) + body
    }

    private struct JWSHeader: Decodable { let alg: String; let typ: String; let kid: String }
}

// The implementation intentionally uses the system Security framework and does not embed a server secret.
