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

    private let keychainService = "com.ffh4x.rage.keyauth"
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
                    keyPreview: result.key,
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
            keyPreview: access.key,
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
