import Foundation

enum ExploitSupportPolicy {
    /// Versões exibidas como compatíveis, rotuladas pelo mecanismo de acesso
    /// real de cada faixa. Um card por acesso, sem duplicar.
    static let listedIOSVersions: [String] = [
        "iOS 17.0–17.7.x · Kernel Exploit",
        "iOS 18.0–18.7.1 · Kernel Exploit",
        "iOS 26.0–26.7.2 · worse_query",
        "iOS 27.0–27.2 · 27.3 Beta · worse_query"
    ]

    static let verifiedIOS17Range = "17.0–17.7.x · Kernel Exploit"
    static let verifiedIOS18Range = "18.0–18.7.1 · Kernel Exploit"
    static let verifiedIOS26Range = "26.0–26.7.2 · worse_query"
    static let verifiedIOS27Range = "27.0–27.2 · 27.3 Beta · worse_query"

    /// Build IDs conhecidos do iOS 27.3 Beta. Enquanto vazio, qualquer
    /// 27.3 (patch 0) é aceito — a faixa é do worse_query. Preencha com os
    /// builds beta verificados para fechar o gate em lista branca.
    static let verifiedIOS27BetaBuilds: [String] = []

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func isAppVersionListed(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        if major == 26 {
            return minor < 7 || (minor == 7 && patch <= 2)
        }

        if major == 27 {
            if minor <= 2 { return true }
            return minor == 3 && patch == 0 && ios27BetaBuildAccepted(build)
        }

        return false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        return isAppVersionListed(major: major, minor: minor, patch: patch, build: build)
    }

    private static func ios27BetaBuildAccepted(_ build: String) -> Bool {
        verifiedIOS27BetaBuilds.isEmpty || verifiedIOS27BetaBuilds.contains(build)
    }
}
