import CryptoKit
import Foundation
import Security

enum ExternalIOSKeyAuthConfig {
    static let baseURL = URL(string: "https://keyauthv2.org")!
    static let packageName = "EXTERNAL"
    static let packageSlug = "external1"
    static let packagePublicID = "5d933aad-02da-4f37-a509-dfffee5600ed"
    static let issuer = "https://keyauthv2.org"
    static let audience = "keyauth-ios"
    static let keyID = "605JmqMJES2Jbv4b"
    static let policyVersion = 2
    static let maxGrantLifetime: TimeInterval = 300
    // JWK pública obtida de GET /api/v2/.well-known/keys; nunca é uma chave privada.
    static let signingPublicKeyX = "HdZDerHU3s-XNbstavzNU1GM2yVhacHl_iYk01NmWXY"
    static let signingPublicKeyY = "jSblrrKkR2W1UmgIb9u22zPH-k8YUSjVQJ6x1Yre-wY"
    static var keychainService: String {
        "\(Bundle.main.bundleIdentifier ?? "com.example.external-ios").keyauth.\(packageSlug)"
    }
    static var installationKeyTag: Data { Data("\(keychainService).installation-p256-v2".utf8) }
}

struct KeyAuthAccess {
    let packageName: String
    let keyPreview: String
    let authorizationExpiresAt: Date
    let licenseDurationDays: Int
    let licenseActivatedAt: Date?
    let licenseExpiresAt: Date
    let grant: String
    let sessionToken: String
}

enum KeyAuthFailure: Error {
    case server(String), network, invalidResponse, invalidChallenge, invalidGrant
    case keychain(OSStatus), cryptography

    var userMessage: String {
        if case let .server(code) = self {
            switch code {
            case "KEY_REQUIRED": return "Digite sua Key para liberar o acesso ao EXTERNAL - iOS."
            case "KEY_INVALID": return "Essa Key não foi encontrada ou não pertence ao pacote EXTERNAL - iOS. Confira e tente novamente."
            case "KEY_EXPIRED": return "Sua Key expirou. Renove a licença ou fale com o suporte."
            case "KEY_PAUSED": return "Sua Key está pausada no momento. Fale com o suporte para verificar o status."
            case "KEY_BANNED": return "Essa Key está bloqueada. Fale com o suporte para entender o motivo."
            case "KEY_DELETED": return "Essa Key foi removida e não pode mais liberar o acesso."
            case "DEVICE_MISMATCH": return "Essa Key está vinculada a outra instalação. Solicite a liberação ou redefinição ao suporte."
            case "DEVICE_ALREADY_REGISTERED": return "Há um conflito de licença vinculado a esta instalação. Fale com o suporte."
            case "SESSION_EXPIRED": return "A sessão expirou durante a validação. Toque em Entrar para tentar novamente."
            case "SESSION_NOT_FOUND": return "Não foi possível localizar a sessão. Feche e abra o app para tentar novamente."
            case "GRANT_INVALID", "GRANT_INACTIVE": return "A sessão KeyAuth ou a licença não está mais válida. Entre novamente para continuar."
            case "PACKAGE_UNAVAILABLE": return "O pacote EXTERNAL - iOS está temporariamente indisponível. Tente mais tarde."
            case "PACKAGE_NOT_FOUND": return "A configuração do pacote não foi localizada. Atualize o app ou fale com o suporte."
            case "INSTALLATION_KEY_MISMATCH": return "A identidade segura desta instalação mudou. Reinstale o app ou fale com o suporte."
            case "INSTALLATION_REQUIRED": return "Não foi possível confirmar esta instalação. Tente novamente."
            case "CHALLENGE_INVALID", "PROOF_INVALID": return "A validação de segurança falhou. Confira a data e hora do aparelho e tente novamente."
            case "RATE_LIMITED": return "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente."
            case "DATABASE_UNAVAILABLE", "KA2_PRIVATE_KEY_UNAVAILABLE": return "O serviço de validação está temporariamente indisponível. Tente mais tarde."
            default: return "Não foi possível validar a Key (\(code)). Tente novamente ou fale com o suporte."
            }
        }
        switch self {
        case .network: return "Sem conexão com o servidor. Verifique sua internet e tente novamente."
        case .invalidResponse, .invalidChallenge, .invalidGrant, .cryptography:
            return "A resposta de segurança do servidor não pôde ser validada. Atualize o app ou fale com o suporte."
        case .keychain: return "Não foi possível acessar o armazenamento seguro deste aparelho. Reinicie o app e tente novamente."
        case .server: return "Não foi possível validar a Key. Tente novamente."
        }
    }
}

private struct APIErrorBody: Decodable { let code: String }
private struct APIEnvelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIErrorBody?
}
private struct PackageStatus: Decodable {
    let publicId: String
    let name: String
    let slug: String
    let status: String
    let available: Bool
}
private struct PackageSummary: Decodable { let publicId: String; let name: String }
private struct SessionReply: Decodable { let token: String; let expiresAt: Double; let package: PackageSummary }
private struct ChallengeReply: Decodable {
    let challengeId: String
    let challenge: String
    let canonical: String
    let expiresAt: Double
}
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}
private struct EmptyReply: Decodable {
    init(from decoder: Decoder) throws { _ = try decoder.container(keyedBy: AnyCodingKey.self) }
}
private struct IssueReply: Decodable { let grant: String; let expiresAt: Double; let package: PackageSummary }
private struct GrantIntrospectionReply: Decodable {
    struct License: Decodable {
        let durationDays: Int
        let activatedAt: Double?
        let expiresAt: Double
    }
    let active: Bool
    let claims: GrantClaims
    let license: License
}
private struct GrantHeader: Decodable { let alg: String; let typ: String; let kid: String }
private struct GrantClaims: Decodable {
    let iss: String
    let aud: String
    let package: String
    let packageId: String
    let installationId: String
    let sessionId: String
    let sessionHash: String
    let key: String
    let keyStatus: String
    let policyVersion: Int
    let scope: [String]
    let iat: Double
    let exp: Double
    let jti: String
}

final class KeyAuthClient {
    private let urlSession: URLSession
    init(urlSession: URLSession = .shared) { self.urlSession = urlSession }

    /// Primeira entrada: passe a Key. Nas aberturas futuras, passe nil para revalidar o vínculo existente.
    func authorize(licenseKey: String? = nil) async throws -> KeyAuthAccess {
        let config = ExternalIOSKeyAuthConfig.self
        let package: PackageStatus = try await post("/api/v2/package/status", body: ["package": config.packageSlug], responseType: PackageStatus.self)
        guard package.name == config.packageName, package.slug == config.packageSlug,
              package.publicId == config.packagePublicID, package.available, package.status == "active" else {
            throw KeyAuthFailure.server("PACKAGE_UNAVAILABLE")
        }

        let session: SessionReply = try await post("/api/v2/device/session/start", body: ["package": config.packageSlug], responseType: SessionReply.self)
        let installationID = try KeyAuthKeychain.installationID()
        let privateKey = try installationPrivateKey()
        let publicKey = try publicKeyX963(from: privateKey).base64URLString
        let sessionHash = Data(SHA256.hash(data: Data(session.token.utf8))).base64URLString

        let installationBody = ["package": config.packageSlug, "token": session.token,
                                "installationId": installationID, "publicKey": publicKey]
        let enrollment: ChallengeReply = try await post("/api/v2/installations/challenge", body: installationBody, responseType: ChallengeReply.self)
        try validateCanonical(enrollment.canonical, purpose: "enrollment", challengeID: enrollment.challengeId,
                              challenge: enrollment.challenge, installationID: installationID, sessionHash: sessionHash)
        let enrollmentSignature = try sign(enrollment.canonical, with: privateKey)
        var completionBody = installationBody
        completionBody["challengeId"] = enrollment.challengeId
        completionBody["challenge"] = enrollment.challenge
        completionBody["signature"] = enrollmentSignature
        let _: EmptyReply = try await post("/api/v2/installations/complete", body: completionBody, responseType: EmptyReply.self)

        let authorizationBase = ["package": config.packageSlug, "token": session.token, "installationId": installationID]
        let authorizationChallenge: ChallengeReply = try await post("/api/v2/authorization/challenge", body: authorizationBase, responseType: ChallengeReply.self)
        try validateCanonical(authorizationChallenge.canonical, purpose: "authorization",
                              challengeID: authorizationChallenge.challengeId, challenge: authorizationChallenge.challenge,
                              installationID: installationID, sessionHash: sessionHash)
        let authorizationSignature = try sign(authorizationChallenge.canonical, with: privateKey)
        var issueBody = authorizationBase
        issueBody["challengeId"] = authorizationChallenge.challengeId
        issueBody["challenge"] = authorizationChallenge.challenge
        issueBody["signature"] = authorizationSignature
        let normalizedKey = licenseKey.map(normalizeKey).flatMap { $0.isEmpty ? nil : $0 }
            ?? KeyAuthKeychain.savedLicenseKey
        if let normalizedKey { issueBody["key"] = normalizedKey }

        let result: IssueReply = try await post("/api/v2/authorization/issue", body: issueBody, responseType: IssueReply.self)
        let claims = try verifyGrant(result.grant, expectedSessionToken: session.token,
                                     expectedInstallationID: installationID, expectedPackageID: package.publicId)
        let introspection = try await fetchGrantIntrospection(
            grant: result.grant,
            sessionToken: session.token,
            expectedClaims: claims
        )
        // A Key digitada só é gravada depois de o grant e sua assinatura passarem na validação.
        if let normalizedKey { try KeyAuthKeychain.saveLicenseKey(normalizedKey) }
        return KeyAuthAccess(packageName: package.name, keyPreview: Self.maskKey(claims.key),
                             authorizationExpiresAt: Date(timeIntervalSince1970: claims.exp),
                             licenseDurationDays: introspection.license.durationDays,
                             licenseActivatedAt: introspection.license.activatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                             licenseExpiresAt: Date(timeIntervalSince1970: introspection.license.expiresAt / 1000),
                             grant: result.grant,
                             sessionToken: session.token)
    }

    /// Revalida a assinatura local e consulta o estado atual da sessão/key no servidor.
    /// Quando o grant está perto de expirar, cria uma sessão e um grant novos.
    func revalidate(_ access: KeyAuthAccess) async throws -> KeyAuthAccess {
        if access.authorizationExpiresAt.timeIntervalSinceNow <= 60 {
            let refreshed = try await authorize(licenseKey: nil)
            guard refreshed.keyPreview == access.keyPreview else { throw KeyAuthFailure.invalidGrant }
            return refreshed
        }

        let config = ExternalIOSKeyAuthConfig.self
        let installationID = try KeyAuthKeychain.installationID()
        let claims = try verifyGrant(
            access.grant,
            expectedSessionToken: access.sessionToken,
            expectedInstallationID: installationID,
            expectedPackageID: config.packagePublicID
        )
        guard Self.maskKey(claims.key) == access.keyPreview else { throw KeyAuthFailure.invalidGrant }
        let introspection = try await fetchGrantIntrospection(
            grant: access.grant,
            sessionToken: access.sessionToken,
            expectedClaims: claims
        )
        return KeyAuthAccess(
            packageName: config.packageName,
            keyPreview: access.keyPreview,
            authorizationExpiresAt: Date(timeIntervalSince1970: claims.exp),
            licenseDurationDays: introspection.license.durationDays,
            licenseActivatedAt: introspection.license.activatedAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            licenseExpiresAt: Date(timeIntervalSince1970: introspection.license.expiresAt / 1000),
            grant: access.grant,
            sessionToken: access.sessionToken
        )
    }

    private func fetchGrantIntrospection(
        grant: String,
        sessionToken: String,
        expectedClaims: GrantClaims
    ) async throws -> GrantIntrospectionReply {
        let config = ExternalIOSKeyAuthConfig.self
        let reply: GrantIntrospectionReply = try await post(
            "/api/v2/grant/introspect",
            body: ["package": config.packageSlug, "token": sessionToken, "grant": grant],
            responseType: GrantIntrospectionReply.self
        )
        let nowMilliseconds = Date().timeIntervalSince1970 * 1000
        guard reply.active,
              reply.claims.iss == config.issuer,
              reply.claims.aud == config.audience,
              reply.claims.package == expectedClaims.package,
              reply.claims.packageId == expectedClaims.packageId,
              reply.claims.installationId == expectedClaims.installationId,
              reply.claims.sessionId == expectedClaims.sessionId,
              reply.claims.sessionHash == expectedClaims.sessionHash,
              reply.claims.key == expectedClaims.key,
              reply.claims.jti == expectedClaims.jti,
              reply.claims.exp == expectedClaims.exp,
              reply.license.durationDays > 0,
              reply.license.expiresAt > nowMilliseconds else {
            throw KeyAuthFailure.server("GRANT_INACTIVE")
        }
        return reply
    }

    private func post<T: Decodable>(_ path: String, body: [String: String], responseType: T.Type) async throws -> T {
        guard let url = URL(string: path, relativeTo: ExternalIOSKeyAuthConfig.baseURL)?.absoluteURL else {
            throw KeyAuthFailure.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await urlSession.data(for: request) }
        catch { throw KeyAuthFailure.network }
        guard let http = response as? HTTPURLResponse,
              let envelope = try? JSONDecoder().decode(APIEnvelope<T>.self, from: data) else {
            throw KeyAuthFailure.invalidResponse
        }
        guard (200..<300).contains(http.statusCode), envelope.ok, let value = envelope.data else {
            throw KeyAuthFailure.server(envelope.error?.code ?? "REQUEST_FAILED")
        }
        return value
    }

    private func installationPrivateKey() throws -> SecKey {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: ExternalIOSKeyAuthConfig.installationKeyTag,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                    kSecReturnRef as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let result { return result as! SecKey }
        guard status == errSecItemNotFound else { throw KeyAuthFailure.keychain(status) }
        let privateAttrs: [String: Any] = [kSecAttrIsPermanent as String: true,
                                           kSecAttrApplicationTag as String: ExternalIOSKeyAuthConfig.installationKeyTag,
                                           kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                         kSecAttrKeySizeInBits as String: 256,
                                         kSecPrivateKeyAttrs as String: privateAttrs]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error { _ = error.takeRetainedValue() }
            throw KeyAuthFailure.cryptography
        }
        return key
    }

    private func publicKeyX963(from privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw KeyAuthFailure.cryptography }
        var error: Unmanaged<CFError>?
        guard let representation = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            if let error { _ = error.takeRetainedValue() }
            throw KeyAuthFailure.cryptography
        }
        let data = representation as Data
        guard data.count == 65, data.first == 0x04 else { throw KeyAuthFailure.cryptography }
        return data
    }

    private func sign(_ canonical: String, with privateKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256,
                                                    Data(canonical.utf8) as CFData, &error) else {
            if let error { _ = error.takeRetainedValue() }
            throw KeyAuthFailure.cryptography
        }
        return (signature as Data).base64URLString
    }

    private func validateCanonical(_ canonical: String, purpose: String, challengeID: String,
                                   challenge: String, installationID: String, sessionHash: String) throws {
        guard let fields = Self.canonicalFields(canonical), fields["purpose"] == purpose,
              fields["package"] == ExternalIOSKeyAuthConfig.packageSlug,
              fields["challengeId"] == challengeID, fields["challenge"] == challenge,
              fields["installationId"] == installationID, fields["sessionHash"] == sessionHash else {
            throw KeyAuthFailure.invalidChallenge
        }
    }

    private static func canonicalFields(_ canonical: String) -> [String: String]? {
        if let data = canonical.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            var fields: [String: String] = [:]
            for (key, value) in object {
                guard let string = value as? String else { return nil }
                fields[key] = string
            }
            return fields
        }
        var fields: [String: String] = [:]
        for line in canonical.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            guard !key.isEmpty, fields[key] == nil else { return nil }
            fields[key] = value
        }
        return fields
    }

    private func verifyGrant(_ grant: String, expectedSessionToken: String,
                             expectedInstallationID: String, expectedPackageID: String) throws -> GrantClaims {
        let parts = grant.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let headerData = Data(base64URL: parts[0]),
              let payloadData = Data(base64URL: parts[1]), let rawSignature = Data(base64URL: parts[2]),
              rawSignature.count == 64,
              let header = try? JSONDecoder().decode(GrantHeader.self, from: headerData),
              let claims = try? JSONDecoder().decode(GrantClaims.self, from: payloadData) else {
            throw KeyAuthFailure.invalidGrant
        }
        let config = ExternalIOSKeyAuthConfig.self
        let sessionHash = Data(SHA256.hash(data: Data(expectedSessionToken.utf8))).base64URLString
        guard header.alg == "ES256", header.typ == "KA2+jwt", header.kid == config.keyID,
              claims.iss == config.issuer, claims.aud == config.audience,
              claims.package == config.packageSlug, claims.packageId == expectedPackageID,
              claims.installationId == expectedInstallationID, claims.sessionHash == sessionHash,
              claims.keyStatus == "active", claims.policyVersion == config.policyVersion,
              claims.scope.contains("app:open") else { throw KeyAuthFailure.invalidGrant }
        let now = Date().timeIntervalSince1970
        guard claims.iat <= now + 30, claims.exp >= now - 30, claims.exp > claims.iat,
              claims.exp - claims.iat <= config.maxGrantLifetime, !claims.key.isEmpty else {
            throw KeyAuthFailure.invalidGrant
        }
        guard let x = Data(base64URL: config.signingPublicKeyX),
              let y = Data(base64URL: config.signingPublicKeyY) else { throw KeyAuthFailure.invalidGrant }
        let x963 = Data([0x04]) + x + y
        guard x963.count == 65 else { throw KeyAuthFailure.invalidGrant }
        let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                    kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                    kSecAttrKeySizeInBits as String: 256]
        var keyError: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(x963 as CFData, attrs as CFDictionary, &keyError) else {
            if let keyError { _ = keyError.takeRetainedValue() }
            throw KeyAuthFailure.invalidGrant
        }
        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        let derSignature = try Self.derSignature(fromRawP256: rawSignature)
        var verifyError: Unmanaged<CFError>?
        let valid = SecKeyVerifySignature(publicKey, .ecdsaSignatureMessageX962SHA256,
                                          signingInput as CFData, derSignature as CFData, &verifyError)
        if let verifyError { _ = verifyError.takeRetainedValue() }
        guard valid else { throw KeyAuthFailure.invalidGrant }
        return claims
    }

    private static func derSignature(fromRawP256 raw: Data) throws -> Data {
        guard raw.count == 64 else { throw KeyAuthFailure.invalidGrant }
        func integer(_ bytes: ArraySlice<UInt8>) -> [UInt8] {
            var value = Array(bytes)
            while value.count > 1 && value[0] == 0 && value[1] & 0x80 == 0 { value.removeFirst() }
            if value[0] & 0x80 != 0 { value.insert(0, at: 0) }
            return [0x02, UInt8(value.count)] + value
        }
        let bytes = Array(raw)
        let body = integer(bytes[0..<32]) + integer(bytes[32..<64])
        guard body.count < 128 else { throw KeyAuthFailure.invalidGrant }
        return Data([0x30, UInt8(body.count)] + body)
    }

    private static func maskKey(_ key: String) -> String {
        let suffix = String(key.suffix(4))
        return suffix.isEmpty ? "••••" : "••••\(suffix)"
    }

    private func normalizeKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().filter { !$0.isWhitespace }
    }
}

enum KeyAuthKeychain {
    private static let installationAccount = "installation-id-v2"
    private static let licenseAccount = "license-key"

    static func installationID() throws -> String {
        if let existing = try readString(account: installationAccount) {
            guard UUID(uuidString: existing) != nil else { throw KeyAuthFailure.keychain(errSecDecode) }
            return existing.lowercased()
        }
        let value = UUID().uuidString.lowercased()
        try saveString(value, account: installationAccount)
        return value
    }

    static var hasSavedLicenseKey: Bool { (try? readString(account: licenseAccount)) != nil }
    static var savedLicenseKey: String? { try? readString(account: licenseAccount) }
    static func saveLicenseKey(_ key: String) throws { try saveString(key, account: licenseAccount) }

    private static func readString(account: String) throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: ExternalIOSKeyAuthConfig.keychainService,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeyAuthFailure.keychain(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeyAuthFailure.keychain(errSecDecode)
        }
        return value
    }

    private static func saveString(_ value: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: ExternalIOSKeyAuthConfig.keychainService,
                                    kSecAttrAccount as String: account]
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeyAuthFailure.keychain(updateStatus) }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeyAuthFailure.keychain(addStatus) }
    }
}

private extension Data {
    init?(base64URL value: String) {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }

    var base64URLString: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
