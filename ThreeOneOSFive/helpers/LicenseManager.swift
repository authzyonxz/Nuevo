import Foundation
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

class LicenseManager: ObservableObject {
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
    private let apiURL = URL(string: "https://ffh4xcorporation.online/api/validate-key")!
    private let product = "revendedores"
    
    init() {
        hasStoredKey = loadSavedKey()?.isEmpty == false
    }
    
    func deviceID() -> String {
        if let stored = keychainRead(account: deviceAccount) {
            return stored
        }
        let identifier = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
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
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func loadSavedKey() -> String? {
        return keychainRead(account: keychainAccount)
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        guard let savedKey = loadSavedKey(), !savedKey.isEmpty else {
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.hasStoredKey = false
                completion(false, "Cadastre uma key ativa no Perfil para ativar funções.")
            }
            return
        }
        isValidatingActivation = true
        validateKey(savedKey) { success, message in
            self.isValidatingActivation = false
            completion(success, success ? nil : (message ?? "Key inválida, expirada ou desativada."))
        }
    }
    
    func validateKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard !key.isEmpty else {
            completion(false, "Insira uma KEY válida.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var request = URLRequest(url: apiURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "key": key,
            "deviceId": deviceID(),
            "product": product
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            isLoading = false
            completion(false, "Erro ao processar dados.")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Erro: \(error.localizedDescription)"
                    completion(false, self.errorMessage)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), let data = data else {
                    self.errorMessage = "Servidor indisponível."
                    completion(false, self.errorMessage)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let isValid = json["valid"] as? Bool ?? false
                        
                        if isValid {
                            let info = LicenseInfo(
                                status: json["status"] as? String ?? "VIP ATIVO",
                                productName: json["productName"] as? String ?? (json["product"] as? String ?? "revendedores"),
                                expiresAt: json["expiresAt"] as? String ?? (json["expiry"] as? String ?? "Vitalício"),
                                message: json["message"] as? String ?? "Sucesso",
                                sessionToken: json["sessionToken"] as? String
                            )
                            self.licenseInfo = info
                            self.isAuthorized = true
                            self.hasStoredKey = true
                            self.keychainSave(value: key, account: self.keychainAccount)
                            completion(true, nil)
                        } else {
                            let msg = json["message"] as? String ?? (json["error"] as? String ?? "Key inválida ou expirada.")
                            self.isAuthorized = false
                            self.licenseInfo = nil
                            self.errorMessage = msg
                            completion(false, msg)
                        }
                    } else {
                        self.isAuthorized = false
                        self.errorMessage = "Resposta inválida do servidor."
                        completion(false, self.errorMessage)
                    }
                } catch {
                    self.errorMessage = "Resposta inválida do servidor."
                    completion(false, self.errorMessage)
                }
            }
        }.resume()
    }
    
    func clearSavedKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        isAuthorized = false
        hasStoredKey = false
        licenseInfo = nil
        errorMessage = nil
    }
}
