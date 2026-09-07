import Combine
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

    @Published var isAuthorized: Bool = false
    @Published var hasStoredKey: Bool = false
    @Published var isLoading: Bool = false
    @Published var isValidatingActivation: Bool = false
    @Published var errorMessage: String? = nil
    @Published var licenseInfo: LicenseInfo? = nil

    private let keychainService = "com.ffh4x.rage.license"
    private let keychainAccount = "saved-key"
    private let deviceAccount = "device-id"
    private let product = "granjeiro"

    // The client keeps the derived session key only in memory. The raw key is
    // persisted in the existing Keychain entry solely for a fresh bootstrap.
    private var secureClient: FFH4XSecureClient?

    init() {
        hasStoredKey = loadSavedKey()?.isEmpty == false
    }

    func deviceID() -> String {
        if let stored = keychainRead(account: deviceAccount) {
            return stored
        }
        let identifier = UIDevice.current.identifierForVendor?.uuidString.lowercased()
            ?? UUID().uuidString.lowercased()
        keychainSave(value: identifier, account: deviceAccount)
        return identifier
    }

    private func keychainSave(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    private func keychainRead(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func loadSavedKey() -> String? {
        keychainRead(account: keychainAccount)
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        guard let savedKey = loadSavedKey(), !savedKey.isEmpty else {
            isAuthorized = false
            hasStoredKey = false
            completion(false, "Cadastre uma key ativa no Perfil para ativar funções.")
            return
        }

        isValidatingActivation = true
        validateKey(savedKey) { [weak self] success, message in
            guard let self else { return }
            self.isValidatingActivation = false
            completion(success, success ? nil : (message ?? "Key inválida, expirada ou desativada."))
        }
    }

    func validateKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            completion(false, "Insira uma KEY válida.")
            return
        }

        isLoading = true
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                // FFH4XSecureClient performs the AES-256-GCM bootstrap and
                // uses a fresh nonce/request ID for every validation request.
                let client = try FFH4XSecureClient(
                    key: normalizedKey,
                    product: product
                )
                let result = try await client.validateKey()
                let info = LicenseInfo(
                    status: result.status ?? "VIP ATIVO",
                    productName: result.productName ?? result.product ?? product,
                    expiresAt: result.expiresAt ?? "Vitalício",
                    message: "Sucesso",
                    sessionToken: nil
                )

                self.secureClient = client
                self.isAuthorized = true
                self.hasStoredKey = true
                self.licenseInfo = info
                self.keychainSave(value: normalizedKey, account: self.keychainAccount)
                self.isLoading = false
                completion(true, nil)
            } catch let error as FFH4XSecureClient.ClientError {
                self.secureClient?.clearSession()
                self.secureClient = nil
                self.isAuthorized = false
                self.licenseInfo = nil
                self.isLoading = false
                self.errorMessage = self.userMessage(for: error)
                completion(false, self.errorMessage)
            } catch {
                self.secureClient?.clearSession()
                self.secureClient = nil
                self.isAuthorized = false
                self.licenseInfo = nil
                self.isLoading = false
                self.errorMessage = "Não foi possível validar a KEY agora."
                completion(false, self.errorMessage)
            }
        }
    }

    func recheckSecureSession(completion: @escaping (Bool, String?) -> Void) {
        guard let secureClient else {
            completion(false, "Nenhuma sessão segura ativa.")
            return
        }

        Task { [weak self] in
            do {
                let result = try await secureClient.checkSession()
                guard let self else { return }
                self.isAuthorized = result.valid
                if !result.valid {
                    self.secureClient = nil
                    self.licenseInfo = nil
                }
                completion(result.valid, result.valid ? nil : "Sessão expirada ou revogada.")
            } catch let error as FFH4XSecureClient.ClientError {
                guard let self else { return }
                self.isAuthorized = false
                self.secureClient = nil
                self.licenseInfo = nil
                completion(false, self.userMessage(for: error))
            } catch {
                guard let self else { return }
                self.isAuthorized = false
                self.secureClient = nil
                self.licenseInfo = nil
                completion(false, "Não foi possível verificar a sessão.")
            }
        }
    }

    private func userMessage(for error: FFH4XSecureClient.ClientError) -> String {
        switch error {
        case .invalidKey:
            return "KEY inválida."
        case .server(let code, _):
            return messageForServerCode(code)
        case .http(let status, let code, _):
            if status == 429 || code == "E_RATE_LIMITED" {
                return "Muitas tentativas. Aguarde alguns minutos."
            }
            if let code {
                return messageForServerCode(code)
            }
            return "Não foi possível validar a KEY agora."
        case .cryptographicFailure:
            return "Falha ao autenticar a comunicação com o servidor."
        case .keychain:
            return "Não foi possível acessar o armazenamento seguro."
        default:
            return "Não foi possível validar a KEY agora."
        }
    }

    private func messageForServerCode(_ code: String) -> String {
        switch code {
        case "E_INVALID_KEY":
            return "KEY inválida."
        case "E_WRONG_PRODUCT":
            return "Esta KEY pertence a outro produto."
        case "E_BANNED_KEY":
            return "Esta KEY está banida."
        case "E_EXPIRED_KEY":
            return "Esta KEY está expirada."
        case "E_DEVICE_MISMATCH":
            return "Esta KEY já está vinculada a outro dispositivo."
        case "E_KEY_INACTIVE", "E_DISABLED_KEY":
            return "Esta KEY está desativada."
        case "E_RATE_LIMITED":
            return "Muitas tentativas. Aguarde alguns minutos."
        case "E_REPLAY":
            return "A solicitação expirou. Tente novamente."
        case "E_STALE_REQUEST":
            return "A solicitação expirou. Verifique a conexão e tente novamente."
        case "E_AUTHENTICATION_FAILED":
            return "Não foi possível autenticar a comunicação com o servidor."
        case "E_INVALID_SESSION":
            return "Sua sessão expirou. Valide a KEY novamente."
        default:
            return "Não foi possível validar a KEY agora."
        }
    }

    func clearSavedKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        secureClient?.clearSession()
        secureClient = nil
        isAuthorized = false
        hasStoredKey = false
        licenseInfo = nil
        errorMessage = nil
    }
}
