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
    @EnvironmentObject private var licenseManager: LicenseManager
    let onEnterApp: () -> Void

    private var licenseInfo: LicenseInfo? { licenseManager.licenseInfo }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.025, green: 0.04, blue: 0.075), Color(red: 0.045, green: 0.025, blue: 0.075), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("EXTERNAL  ·  AUTH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3.5)
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.top, 20)

                    Spacer(minLength: 38)

                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 94, height: 94)
                        Circle()
                            .stroke(Color.green.opacity(0.38), lineWidth: 1)
                            .frame(width: 72, height: 72)
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color.green)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(language.text("login.success_title"))
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text(language.text("login.success_message"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(language.text("home.account"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.8)
                            .padding(.bottom, 6)

                        successDetailRow(
                            label: language.text("license.authorized.status"),
                            value: statusText
                        )
                        Divider()
                        successDetailRow(label: language.text("home.key"), value: licenseManager.maskedKey)
                        Divider()
                        successDetailRow(
                            label: language.text("home.package"),
                            value: licenseInfo?.productName ?? "EXTERNAL - iOS"
                        )
                        Divider()
                        successDetailRow(
                            label: language.text("license.authorized.udid"),
                            value: licenseInfo?.deviceIdentifier ?? language.text("license.authorized.device_fallback")
                        )
                        if let activatedAt = licenseInfo?.activatedAt {
                            Divider()
                            successDetailRow(
                                label: language.text("license.authorized.activated"),
                                value: activatedAt
                            )
                        }
                        Divider()
                        successDetailRow(
                            label: language.text("license.authorized.expires"),
                            value: licenseInfo?.expiresAt ?? "—"
                        )
                        if let days = licenseInfo?.durationDays {
                            Divider()
                            successDetailRow(
                                label: language.text("home.duration"),
                                value: language.text("license.authorized.days", Int64(days))
                            )
                        }
                    }
                    .padding(18)
                    .background(
                        Color.white.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    }
                    .padding(.top, 28)

                    Button(action: onEnterApp) {
                        HStack(spacing: 10) {
                            if licenseManager.isRecheckingSession {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(
                                licenseManager.isRecheckingSession
                                    ? language.text("license.checking")
                                    : language.text("login.enter_app")
                            )
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .tracking(2.5)
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.43, green: 0.84, blue: 1), .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(licenseManager.isRecheckingSession)
                    .padding(.top, 18)

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var statusText: String {
        guard let status = licenseInfo?.status else {
            return language.text("license.authorized.active")
        }
        return status.caseInsensitiveCompare("active") == .orderedSame
            ? language.text("license.authorized.active")
            : status
    }

    private func successDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.58))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white)
                .textSelection(.enabled)
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
    let activatedAt: String?
    let deviceIdentifier: String?
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
    @Published var hasEnteredApp = false
    @Published var isLoading = false
    @Published var isValidatingActivation = false
    @Published var isRecheckingSession = false
    @Published var errorMessage: String?
    @Published var licenseInfo: LicenseInfo?
    @Published var flowState: FlowState = .checkingPackage
    @Published var pendingWebURL: URL?

    // Namespace exclusivo do Nuevo: não reutiliza sessão/key gravada por outro IPA.
    private let keychainService = "com.authzyonxz.nuevo.keyauth.v2"
    private let keychainAccount = "saved-key"
    private let sessionAccount = "device-session-token"
    private let deviceAccount = "registered-device-id"
    private let hasEnteredAppPreferenceKey = "com.authzyonxz.nuevo.keyauth.did-enter-app"
    private let client: FFH4XSecureClient?
    private var hasBootstrapped = false

    init() {
        client = try? FFH4XSecureClient()
        hasStoredKey = keychainRead(account: keychainAccount)?.isEmpty == false
        hasEnteredApp = UserDefaults.standard.bool(forKey: hasEnteredAppPreferenceKey)
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

    func clearLoginError() {
        guard flowState == .askingForKey else { return }
        errorMessage = nil
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
                if !result.device.isEmpty {
                    save(value: result.device, account: deviceAccount)
                }
                hasEnteredApp = false
                UserDefaults.standard.set(false, forKey: hasEnteredAppPreferenceKey)
                hasStoredKey = true
                isAuthorized = true
                licenseInfo = LicenseInfo(
                    status: result.status,
                    productName: result.package.name,
                    expiresAt: Self.formatDate(result.expiresAt),
                    activatedAt: Self.formatDate(result.activatedAt),
                    deviceIdentifier: result.device.isEmpty ? nil : result.device,
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
                let failureMessage = message(for: error)
                flowState = .askingForKey
                errorMessage = failureMessage
                completion(false, failureMessage)
            } catch {
                isLoading = false
                isValidatingActivation = false
                isAuthorized = false
                flowState = .askingForKey
                errorMessage = "Não foi possível validar a KEY agora."
                completion(false, errorMessage)
            }
        }
    }

    @MainActor
    func recheckSecureSession() async -> (authorized: Bool, message: String?) {
        guard !isRecheckingSession else {
            return (false, "Uma verificação da licença já está em andamento.")
        }
        guard let client, let token = keychainRead(account: sessionAccount), !token.isEmpty else {
            finishFailure("Sessão de dispositivo não encontrada.")
            return (false, errorMessage)
        }
        isRecheckingSession = true
        defer { isRecheckingSession = false }

        do {
            try await inspectSession(token: token, client: client)
            guard isAuthorized else {
                let failureMessage = errorMessage ?? "A licença não está ativa ou foi revogada."
                errorMessage = failureMessage
                return (false, failureMessage)
            }
            return (true, nil)
        } catch let error as FFH4XSecureClient.ClientError {
            let failureMessage = message(for: error)
            finishFailure(failureMessage)
            return (false, failureMessage)
        } catch {
            let failureMessage = "Não foi possível verificar a sessão."
            finishFailure(failureMessage)
            return (false, failureMessage)
        }
    }

    @MainActor
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
        guard status.registered,
              let access = status.access,
              access.status?.caseInsensitiveCompare("active") == .orderedSame else {
            isAuthorized = false
            flowState = .askingForKey
            let code = status.access?.reason ?? status.access?.status
            let mappedMessage = code.map(message(forServerCode:))
            errorMessage = mappedMessage == nil || mappedMessage == "Não foi possível validar o acesso."
                ? "A licença não está ativa ou foi revogada."
                : mappedMessage
            return
        }
        isAuthorized = true
        flowState = .authorized
        let savedKey = keychainRead(account: keychainAccount)
        let recoveredKey = savedKey ?? Self.validKey(from: access.key)
        if savedKey == nil, let recoveredKey {
            save(value: recoveredKey, account: keychainAccount)
            hasStoredKey = true
        }
        hasStoredKey = recoveredKey != nil
        licenseInfo = LicenseInfo(
            status: access.status ?? "active",
            productName: access.package?.name ?? status.package.name,
            expiresAt: Self.formatDate(access.expiresAt ?? status.expiresAt),
            activatedAt: access.activatedAt.map(Self.formatDate),
            deviceIdentifier: keychainRead(account: deviceAccount),
            message: "Acesso autorizado",
            sessionToken: token,
            keyPreview: recoveredKey,
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
        keychainDelete(account: deviceAccount)
        isAuthorized = false
        hasStoredKey = false
        hasEnteredApp = false
        UserDefaults.standard.set(false, forKey: hasEnteredAppPreferenceKey)
        licenseInfo = nil
        pendingWebURL = nil
        errorMessage = nil
        hasBootstrapped = false
        flowState = .checkingPackage
    }

    func enterApp() {
        hasEnteredApp = true
        UserDefaults.standard.set(true, forKey: hasEnteredAppPreferenceKey)
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
            return message(forServerCode: code)
        case .http(_, let code):
            guard let code else { return "Não foi possível validar o acesso." }
            return message(forServerCode: code)
        case .packageMismatch:
            return "A configuração do Package não corresponde ao aplicativo."
        case .responseDecodingFailed:
            return "O servidor retornou uma resposta incompatível. Atualize o aplicativo."
        case .timestampExpired: return "Ajuste a data e hora do dispositivo automaticamente."
        case .invalidSecret, .invalidEnvelope, .invalidServerResponse, .signatureInvalid, .cryptoFailure:
            return "Falha ao autenticar a comunicação com o servidor."
        }
    }

    private func message(forServerCode code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "KEY_INVALID", "INVALID_KEY", "KEY_NOT_FOUND": return "invalid_key"
        case "PACKAGE_UNAVAILABLE": return "O Package EXTERNAL - iOS está indisponível."
        case "KEY_UNAVAILABLE", "KEY_BANNED", "BANNED", "PAUSED", "REMOVED", "REVOKED", "SUSPENDED", "DISABLED":
            return "A KEY está pausada, banida ou removida."
        case "KEY_EXPIRED", "EXPIRED": return "A KEY expirou."
        case "DEVICE_MISMATCH": return "A KEY está vinculada a outro dispositivo."
        case "DEVICE_ALREADY_REGISTERED": return "Este dispositivo já possui outra KEY ativa."
        case "SESSION_EXPIRED", "SESSION_NOT_FOUND": return "A sessão expirou. Gere um novo perfil."
        case "RATE_LIMITED": return "Muitas tentativas. Aguarde alguns minutos."
        default: return "Não foi possível validar o acesso."
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

    private static func validKey(from value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.range(of: #"^(?:[A-Z0-9]+-[A-Z1-9]{8}|[A-Z1-9]{11,15})$"#, options: .regularExpression) != nil else {
            return nil
        }
        return normalized
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
    @FocusState private var keyFieldFocused: Bool

    private var canSubmit: Bool {
        !inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !licenseManager.isLoading
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        topBar

                        Spacer(minLength: max(58, geometry.size.height * 0.14))

                        VStack(spacing: 12) {
                            Text("TOOLKIT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(7)
                                .foregroundStyle(.white.opacity(0.48))

                            Text("EXTERNAL")
                                .font(.system(size: min(max(geometry.size.width * 0.145, 44), 68), weight: .black, design: .rounded))
                                .tracking(-1.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.39, green: 0.82, blue: 1), .white],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: Color.cyan.opacity(0.2), radius: 22, y: 4)
                                .accessibilityAddTraits(.isHeader)

                            Text("AUTH")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .tracking(8)
                                .foregroundStyle(Color(red: 1, green: 0.58, blue: 0.28))
                        }

                        Spacer(minLength: 48)

                        stateContent
                            .frame(maxWidth: 360)

                        Spacer(minLength: 42)

                        Text("SECURE ACCESS  ·  KEY STORED ON IPHONE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.34))
                            .multilineTextAlignment(.center)
                    }
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: inputKey) { _ in
            licenseManager.clearLoginError()
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.025, green: 0.035, blue: 0.065), Color(red: 0.045, green: 0.025, blue: 0.075), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 310, height: 310)
                .blur(radius: 100)
                .offset(x: 155, y: -250)

            Circle()
                .fill(Color.purple.opacity(0.13))
                .frame(width: 290, height: 290)
                .blur(radius: 105)
                .offset(x: -145, y: 360)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("EXTERNAL")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.82))

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(licenseManager.isLoading ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text("AUTH")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateContent: some View {
        VStack(spacing: 22) {
            switch licenseManager.flowState {
            case .askingForKey, .activatingKey:
                keyEntry
            case .openingDeviceRegistration, .waitingForDevice:
                deviceRegistration
            case .checkingPackage:
                VStack(spacing: 14) {
                    sectionLabel("SECURE ACCESS")
                    Text("Verificando o acesso seguro com o servidor.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                    ProgressView()
                        .tint(Color.cyan)
                        .padding(.top, 4)
                }
            case .failure(let message):
                VStack(spacing: 16) {
                    sectionLabel("CONNECTION")
                    Text(message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                    actionButton("TRY AGAIN", systemImage: "arrow.clockwise") {
                        licenseManager.retryBootstrap()
                    }
                }
            case .authorized:
                EmptyView()
            }

            if let error = licenseManager.errorMessage,
               licenseManager.flowState == .askingForKey {
                Text(error)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color(red: 1, green: 0.32, blue: 0.34))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            if licenseManager.isLoading && licenseManager.flowState != .checkingPackage {
                ProgressView()
                    .tint(Color.cyan)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.18), value: licenseManager.errorMessage)
    }

    private var keyEntry: some View {
        VStack(spacing: 0) {
            sectionLabel("LICENSE")
                .padding(.bottom, 16)

            TextField("Enter your license key", text: $inputKey)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .disabled(licenseManager.isLoading)
                .focused($keyFieldFocused)
                .submitLabel(.go)
                .onSubmit(submitKey)
                .padding(.horizontal, 8)
                .padding(.vertical, 15)
                .accessibilityLabel("License key")

            Rectangle()
                .fill(keyFieldFocused ? Color.cyan.opacity(0.9) : Color.white.opacity(0.62))
                .frame(height: keyFieldFocused ? 1.5 : 1)

            Button(action: submitKey) {
                Text(licenseManager.isLoading ? "CHECKING" : "ENTER")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .foregroundStyle(canSubmit ? .white : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.white.opacity(0.24))
                            .frame(height: 1)
                            .padding(.horizontal, 28)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.top, 14)
        }
    }

    private var deviceRegistration: some View {
        VStack(spacing: 17) {
            sectionLabel("DEVICE REGISTRATION")

            Text(deviceMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if licenseManager.pendingWebURL != nil {
                actionButton("REGISTER UDID", systemImage: "arrow.up.right") {
                    licenseManager.openPendingRegistration()
                }

                Button {
                    licenseManager.resumeAfterSafari()
                } label: {
                    Text("I INSTALLED THE PROFILE · CHECK DEVICE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deviceMessage: String {
        switch licenseManager.flowState {
        case .openingDeviceRegistration:
            return "Instale o perfil para identificar este iPhone."
        case .waitingForDevice:
            return "Depois de instalar o perfil em Ajustes, retorne ao aplicativo e verifique o registro."
        default:
            return "Identifique este iPhone para vincular a licença ao dispositivo."
        }
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(4.5)
            .foregroundStyle(Color(red: 1, green: 0.66, blue: 0.38))
            .multilineTextAlignment(.center)
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                    .tracking(2.2)
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.27), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(licenseManager.isLoading)
        .opacity(licenseManager.isLoading ? 0.55 : 1)
    }

    private func submitKey() {
        guard canSubmit else { return }
        keyFieldFocused = false
        licenseManager.validateKey(inputKey) { _, _ in }
    }
}
