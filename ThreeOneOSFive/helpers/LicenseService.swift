import Foundation
import Security

struct LicenseInfo: Codable {
    let key: String
    let productName: String
    let expiresAt: String
    let durationDays: Int
}

class LicenseService {
    static let shared = LicenseService()
    
    private let apiURL = URL(string: "https://ffh4xcorporation.online/api/validate-key")!
    private let product = "ruanwq"
    private let keychainService = "com.ffh4x.ruanwq"
    private let keyAccount = "saved-key"
    private let deviceIDAccount = "device-id"
    
    func getDeviceID() -> String {
        if let savedID = loadFromKeychain(account: deviceIDAccount) {
            return savedID
        }
        let newID = UUID().uuidString
        saveToKeychain(value: newID, account: deviceIDAccount)
        return newID
    }
    
    func getSavedKey() -> String? {
        return loadFromKeychain(account: keyAccount)
    }
    
    func validateKey(_ key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        let normalized = key.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalized.isEmpty else {
            completion(.failure(NSError(domain: "License", code: 400, userInfo: [NSLocalizedDescriptionKey: "Informe a key."])))
            return
        }
        
        let deviceId = getDeviceID()
        let body: [String: Any] = [
            "key": normalized,
            "deviceId": deviceId,
            "product": product
        ]
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "License", code: 500, userInfo: [NSLocalizedDescriptionKey: "Erro de conexão."])))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let isValid = json?["valid"] as? Bool ?? false
                
                if httpResponse.statusCode == 200 && isValid {
                    let info = LicenseInfo(
                        key: normalized,
                        productName: json?["product"] as? String ?? "Painel iPA - Ruanwq",
                        expiresAt: json?["expiresAt"] as? String ?? "",
                        durationDays: json?["durationDays"] as? Int ?? 0
                    )
                    self.saveToKeychain(value: normalized, account: self.keyAccount)
                    completion(.success(info))
                } else {
                    let serverError = json?["error"] as? String ?? "Key inválida ou não autorizada."
                    completion(.failure(NSError(domain: "License", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: serverError])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func logout() {
        deleteFromKeychain(account: keyAccount)
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(value: String, account: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
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
