import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS26Range = "26.0–28.0+"

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // Suporte ampliado para incluir iOS 18 (major 28 no contexto do projeto) e versões superiores.
        // O sistema agora permite a execução em qualquer versão igual ou superior a 26.0.
        return major >= 26
    }
    
    static func iOS27BetaNumber(for build: String) -> Int? { nil }
    static func iOS27PublicBetaNumber(for build: String) -> Int? { nil }
}
