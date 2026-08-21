import Combine
import CryptoKit
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

    @Published var isAuthorized = true
    @Published var hasStoredKey = true
    @Published var isLoading = false
    @Published var isValidatingActivation = false
    @Published var errorMessage: String?
    @Published var licenseInfo: LicenseInfo?

    private let keychainService = "com.ffh4x.rage.license"
    private let keychainAccount = "saved-key"
    private let deviceAccount = "device-id"
    private let apiURL = URL(string: "https://ffh4xcorporation.online/api/validate-key")!
    private let sessionURL = URL(string: "https://ffh4xcorporation.online/api/session/check")!
    private let product = "ruanwq"
    private let protocolName = "ffh4x-secure-v1"
    private let algorithm = "A256GCM"

    init() {
        isAuthorized = true
        hasStoredKey = true
        licenseInfo = LicenseInfo(
            status: "VIP BYPASSED ATIVO",
            productName: "MenagerFF - Full Access",
            expiresAt: "2099-12-31 23:59:59",
            message: "Acesso liberado sem key",
            sessionToken: "bypass-token-active"
        )
    }

    func deviceID() -> String {
        return "bypassed-device-id"
    }

    func loadSavedKey() -> String? {
        return "BYPASSED-KEY-12345"
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.hasStoredKey = true
            self.isValidatingActivation = false
            self.licenseInfo = LicenseInfo(
                status: "VIP BYPASSED ATIVO",
                productName: "MenagerFF - Full Access",
                expiresAt: "2099-12-31 23:59:59",
                message: "Acesso liberado sem key",
                sessionToken: "bypass-token-active"
            )
            completion(true, nil)
        }
    }

    func authorizeOperation(_ operation: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.hasStoredKey = true
            completion(true, nil)
        }
    }

    func validateKey(_ rawKey: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.isAuthorized = true
            self.hasStoredKey = true
            self.licenseInfo = LicenseInfo(
                status: "VIP BYPASSED ATIVO",
                productName: "MenagerFF - Full Access",
                expiresAt: "2099-12-31 23:59:59",
                message: "Acesso liberado sem key",
                sessionToken: "bypass-token-active"
            )
            completion(true, nil)
        }
    }

    func clearSavedKey() {
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.hasStoredKey = true
        }
    }
}
