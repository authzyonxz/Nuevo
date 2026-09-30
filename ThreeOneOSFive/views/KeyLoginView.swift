import SwiftUI

struct KeyLoginView: View {
    @Environment(\.appLanguage) private var language
    @State private var key = ""
    @FocusState private var keyFieldFocused: Bool
    let onValidated: (String) -> Void

    private var canContinue: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 52)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            AppLogo(size: 48)
                            Spacer()
                            Text("3105")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(language.text("login.title"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(language.text("login.subtitle"))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.text("login.key"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            Image(systemName: "key")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            TextField(language.text("login.key_placeholder"), text: $key)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($keyFieldFocused)
                                .submitLabel(.continue)
                                .onSubmit {
                                    if canContinue { onValidated(key.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .background(
                            Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    keyFieldFocused ? AppTheme.accent : Color(uiColor: .separator).opacity(0.35),
                                    lineWidth: keyFieldFocused ? 1.5 : 0.7
                                )
                        }
                    }
                    .padding(.top, 38)

                    Button {
                        keyFieldFocused = false
                        onValidated(key.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.text("login.validate"))
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .font(.headline)
                        .foregroundStyle(AppTheme.pageBackground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.45)
                    .padding(.top, 18)

                    Text(language.text("login.test_note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(nil)
    }
}

struct LoginSuccessfulView: View {
    @Environment(\.appLanguage) private var language
    let key: String
    let onEnterApp: () -> Void

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 54)

                    ZStack {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 82, height: 82)
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.pageBackground)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(language.text("login.success_title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(language.text("login.success_message"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(language.text("home.account"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.bottom, 10)

                        successDetailRow(label: language.text("login.key"), value: key)
                        Divider()
                        successDetailRow(label: language.text("home.duration"), value: language.text("login.example_duration"))
                        Divider()
                        successDetailRow(label: language.text("home.package"), value: language.text("login.example_package"))
                    }
                    .padding(18)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.7)
                    }
                    .padding(.top, 34)

                    Button(action: onEnterApp) {
                        Text(language.text("login.enter_app"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.pageBackground)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    Spacer(minLength: 42)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func successDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 13)
    }
}
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

    public struct AccessPackageSummary: Decodable {
        public let publicId: String
        public let name: String
        public let status: String?
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
        public let package: AccessPackageSummary?
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
        case responseDecodingFailed
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
            case .responseDecodingFailed: return "O servidor retornou uma resposta incompatível. Atualize o aplicativo."
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
        let validFormat = normalized.range(of: #"^(?:[A-Z0-9]+-[A-Z1-9]{8}|[A-Z1-9]{11,15})$"#, options: .regularExpression) != nil
        guard validFormat else { throw ClientError.server(code: "KEY_INVALID") }
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
        do {
            return try decoder.decode(T.self, from: clear)
        } catch {
            log("keyauth: response decoding failed for \(path): \(String(describing: error))")
            throw ClientError.responseDecodingFailed
        }
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
import Combine
import Foundation
import Security
import SwiftUI
import UIKit

struct LicenseInfo: Codable {
    let status: String
    let productName: String
    let expiresAt: String
    let message: String
    let sessionToken: String?
    let keyPreview: String?
    let durationDays: Int?
}

@available(iOS 16.0, *)
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    enum FlowState: Equatable {
        case checkingPackage
        case openingDeviceRegistration
        case waitingForDevice
        case askingForKey
        case activatingKey
        case authorized
        case failure(String)
    }

    @Published var isAuthorized = false
    @Published var hasStoredKey = false
    @Published var isLoading = false
    @Published var isValidatingActivation = false
    @Published var errorMessage: String?
    @Published var licenseInfo: LicenseInfo?
    @Published var flowState: FlowState = .checkingPackage
    @Published var pendingWebURL: URL?

    // Namespace exclusivo do Nuevo: não reutiliza sessão/key gravada por outro IPA.
    private let keychainService = "com.authzyonxz.nuevo.keyauth.v2"
    private let keychainAccount = "saved-key"
    private let sessionAccount = "device-session-token"
    private let client: FFH4XSecureClient?
    private var hasBootstrapped = false

    init() {
        client = try? FFH4XSecureClient()
        hasStoredKey = keychainRead(account: keychainAccount)?.isEmpty == false
    }

    func bootstrap(completion: ((Bool, String?) -> Void)? = nil) {
        guard !hasBootstrapped else {
            completion?(isAuthorized, isAuthorized ? nil : errorMessage)
            return
        }
        hasBootstrapped = true
        flowState = .checkingPackage
        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let client = self.client else { throw FFH4XSecureClient.ClientError.invalidSecret }
                let package = try await client.packageStatus()
                guard package.available, package.status == "active", package.slug == "external1" else {
                    throw FFH4XSecureClient.ClientError.server(code: "PACKAGE_UNAVAILABLE")
                }
                if let token = keychainRead(account: sessionAccount), !token.isEmpty {
                    try await inspectSession(token: token, client: client)
                } else {
                    let session = try await client.startSession()
                    save(value: session.token, account: sessionAccount)
                    pendingWebURL = session.webUrl
                    flowState = .openingDeviceRegistration
                    isLoading = false
                    openPendingRegistration()
                    completion?(false, "Instale o perfil do dispositivo para continuar.")
                    return
                }
                isLoading = false
                completion?(isAuthorized, isAuthorized ? nil : errorMessage)
            } catch let error as FFH4XSecureClient.ClientError {
                finishFailure(message(for: error))
                completion?(false, errorMessage)
            } catch {
                finishFailure("Não foi possível conectar ao servidor.")
                completion?(false, errorMessage)
            }
        }
    }

    func resumeAfterSafari() {
        guard flowState == .openingDeviceRegistration || flowState == .waitingForDevice else { return }
        flowState = .waitingForDevice
        isLoading = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let client = self.client, let token = self.keychainRead(account: self.sessionAccount) else {
                self.finishFailure("Sessão de dispositivo não encontrada.")
                return
            }
            do {
                try await inspectSession(token: token, client: client)
                isLoading = false
            } catch let error as FFH4XSecureClient.ClientError {
                finishFailure(message(for: error))
            } catch {
                finishFailure("Não foi possível verificar o dispositivo.")
            }
        }
    }

    func retryBootstrap() {
        hasBootstrapped = false
        bootstrap()
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        bootstrap(completion: completion)
    }

    func validateKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else {
            completion(false, "Insira uma KEY válida.")
            return
        }
        guard let client, let token = keychainRead(account: sessionAccount), !token.isEmpty else {
            completion(false, "Identifique este dispositivo antes de informar a KEY.")
            return
        }

        isLoading = true
        isValidatingActivation = true
        flowState = .activatingKey
        errorMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await client.activate(token: token, key: normalized)
                guard result.valid, result.status == "active" else {
                    throw FFH4XSecureClient.ClientError.server(code: "KEY_INVALID")
                }
                save(value: normalized, account: keychainAccount)
                hasStoredKey = true
                isAuthorized = true
                licenseInfo = LicenseInfo(
                    status: result.status,
                    productName: result.package.name,
                    expiresAt: Self.formatDate(result.expiresAt),
                    message: "Ativação concluída",
                    sessionToken: token,
                    keyPreview: normalized,
                    durationDays: result.durationDays
                )
                flowState = .authorized
                isLoading = false
                isValidatingActivation = false
                completion(true, nil)
            } catch let error as FFH4XSecureClient.ClientError {
                isLoading = false
                isValidatingActivation = false
                isAuthorized = false
                flowState = .failure(message(for: error))
                errorMessage = message(for: error)
                completion(false, errorMessage)
            } catch {
                isLoading = false
                isValidatingActivation = false
                isAuthorized = false
                flowState = .failure("Não foi possível validar a KEY agora.")
                errorMessage = "Não foi possível validar a KEY agora."
                completion(false, errorMessage)
            }
        }
    }

    func recheckSecureSession(completion: @escaping (Bool, String?) -> Void) {
        guard let client, let token = keychainRead(account: sessionAccount), !token.isEmpty else {
            isAuthorized = false
            completion(false, "Sessão de dispositivo não encontrada.")
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await inspectSession(token: token, client: client)
                completion(isAuthorized, isAuthorized ? nil : errorMessage)
            } catch let error as FFH4XSecureClient.ClientError {
                isAuthorized = false
                flowState = .failure(message(for: error))
                completion(false, message(for: error))
            } catch {
                isAuthorized = false
                completion(false, "Não foi possível verificar a sessão.")
            }
        }
    }

    private func inspectSession(token: String, client: FFH4XSecureClient) async throws {
        let status = try await client.sessionStatus(token: token)
        guard status.package.slug == "external1", status.package.status == "active" else {
            throw FFH4XSecureClient.ClientError.server(code: "PACKAGE_UNAVAILABLE")
        }
        guard status.deviceRegistered else {
            isAuthorized = false
            flowState = .waitingForDevice
            let session = try await client.startSession()
            save(value: session.token, account: sessionAccount)
            pendingWebURL = session.webUrl
            return
        }
        guard status.registered, let access = status.access, access.status == "active" else {
            isAuthorized = false
            flowState = .askingForKey
            errorMessage = nil
            return
        }
        isAuthorized = true
        flowState = .authorized
        let savedKey = keychainRead(account: keychainAccount)
        hasStoredKey = savedKey?.isEmpty == false
        licenseInfo = LicenseInfo(
            status: access.status ?? "active",
            productName: access.package?.name ?? status.package.name,
            expiresAt: Self.formatDate(access.expiresAt ?? status.expiresAt),
            message: "Acesso autorizado",
            sessionToken: token,
            keyPreview: savedKey,
            durationDays: access.durationDays
        )
    }

    func openPendingRegistration() {
        guard let pendingWebURL else { return }
        UIApplication.shared.open(pendingWebURL)
        flowState = .waitingForDevice
    }

    func clearSavedKey() {
        keychainDelete(account: keychainAccount)
        keychainDelete(account: sessionAccount)
        isAuthorized = false
        hasStoredKey = false
        licenseInfo = nil
        pendingWebURL = nil
        errorMessage = nil
        hasBootstrapped = false
        flowState = .checkingPackage
    }

    var maskedKey: String {
        // Exibir somente a KEY digitada e validada localmente após a ativação.
        let value = keychainRead(account: keychainAccount) ?? ""
        guard !value.isEmpty else { return "—" }
        let characters = Array(value)
        let visibleCount = max(1, characters.count / 2)
        return String(characters.prefix(visibleCount)) + String(repeating: "*", count: characters.count - visibleCount)
    }

    private func finishFailure(_ message: String) {
        isLoading = false
        isValidatingActivation = false
        isAuthorized = false
        errorMessage = message
        flowState = .failure(message)
    }

    private func message(for error: FFH4XSecureClient.ClientError) -> String {
        switch error {
        case .server(let code):
            switch code {
            case "PACKAGE_UNAVAILABLE": return "O Package EXTERNAL - iOS está indisponível."
            case "KEY_INVALID": return "A KEY não pertence a este Package."
            case "KEY_UNAVAILABLE": return "A KEY está pausada, banida ou removida."
            case "KEY_EXPIRED": return "A KEY expirou."
            case "DEVICE_MISMATCH": return "A KEY está vinculada a outro dispositivo."
            case "DEVICE_ALREADY_REGISTERED": return "Este dispositivo já possui outra KEY ativa."
            case "SESSION_EXPIRED", "SESSION_NOT_FOUND": return "A sessão expirou. Gere um novo perfil."
            case "RATE_LIMITED": return "Muitas tentativas. Aguarde alguns minutos."
            default: return "Não foi possível validar o acesso."
            }
        case .http(_, let code):
            if code == "RATE_LIMITED" { return "Muitas tentativas. Aguarde alguns minutos." }
            return "Não foi possível validar o acesso."
        case .packageMismatch:
            return "A configuração do Package não corresponde ao aplicativo."
        case .responseDecodingFailed:
            return "O servidor retornou uma resposta incompatível. Atualize o aplicativo."
        case .timestampExpired: return "Ajuste a data e hora do dispositivo automaticamente."
        case .invalidSecret, .invalidEnvelope, .invalidServerResponse, .signatureInvalid, .cryptoFailure:
            return "Falha ao autenticar a comunicação com o servidor."
        }
    }

    private static func formatDate(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func save(value: String, account: String) {
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

    private func keychainDelete(account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}


@available(iOS 16.0, *)
struct LicenseGateView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var inputKey = ""
    @State private var showingKey = false

    private var canSubmit: Bool {
        !inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !licenseManager.isLoading
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.03, green: 0.07, blue: 0.13), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 48)
                    VStack(spacing: 12) {
                        Text("VERIFICAÇÃO DE DISPOSITIVO")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Text(message)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    VStack(spacing: 16) {
                    if licenseManager.flowState == .askingForKey {
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(accent)
                            Group {
                                if showingKey {
                                    TextField("Digite sua KEY", text: $inputKey)
                                } else {
                                    SecureField("Digite sua KEY", text: $inputKey)
                                }
                            }
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            Button { showingKey.toggle() } label: {
                                Image(systemName: showingKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        Button {
                            licenseManager.validateKey(inputKey) { _, _ in }
                        } label: {
                            Text("ENTRAR")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 52)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.45)
                    }
                    if licenseManager.pendingWebURL != nil && (licenseManager.flowState == .openingDeviceRegistration || licenseManager.flowState == .waitingForDevice) {
                        Button {
                            licenseManager.openPendingRegistration()
                        } label: {
                            Text("REGISTRAR UDID")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .tracking(0.7)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 50)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if case .failure = licenseManager.flowState {
                        Button { licenseManager.retryBootstrap() } label: {
                            Label("TENTAR NOVAMENTE", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.bordered)
                    }
                    if let error = licenseManager.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    if licenseManager.isLoading {
                        ProgressView().tint(accent).scaleEffect(1.05)
                    }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    Spacer(minLength: 34)
                    Label("CONEXÃO PROTEGIDA · KEY SALVA NO IPHONE", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.36))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var accent: Color {
        switch licenseManager.flowState {
        case .authorized: return .green
        case .failure: return .red
        default: return AppTheme.accent
        }
    }

    private var message: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "Verificando o acesso seguro com o servidor."
        case .openingDeviceRegistration: return "Instale o perfil para identificar este iPhone."
        case .waitingForDevice: return "Após instalar o perfil em Ajustes, retorne ao aplicativo."
        case .askingForKey: return "Informe a KEY autorizada para este dispositivo."
        case .activatingKey: return "Validando a KEY e vinculando o acesso ao dispositivo."
        case .authorized: return "Acesso autorizado."
        case .failure(let value): return value
        }
    }
}
