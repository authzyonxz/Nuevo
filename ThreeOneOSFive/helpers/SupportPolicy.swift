import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS26Range = "Universal (iOS 15-18+)"

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // Suporte universal incondicional para todas as versões do iOS (incluindo iOS 18)
        return true
    }
    
    static func iOS27BetaNumber(for build: String) -> Int? { nil }
    static func iOS27PublicBetaNumber(for build: String) -> Int? { nil }
}
