import Foundation

/// Policy de compatibilidade e rota de acesso.
///
/// Mapa fechado pelo operador:
///  - kernel    → iOS 17.0–17.7.x e 18.0–18.7.2  (kexploit_opa334, tudo no aparelho)
///  - badQuery  → iOS 26.0–26.6.2                 (kexploit + sandbox_escape + bad_query)
///  - airlift   → iOS 27.0–27.0.1 e 27.2 beta 1–3 (pareamento on-device, sem PC)
///
/// Fora dessas faixas o app abre, mas não libera acesso privilegiado.
enum ExploitSupportPolicy {

    /// Versões exibidas em Profile como "o app abre".
    static let listedIOSVersions: [String] = [
        "iOS 17.0–17.7.x (kernel)",
        "iOS 18.0–18.7.2 (kernel)",
        "iOS 26.0–26.6.2 (bad_query)",
        "iOS 27.0–27.0.1 (airlift)",
        "iOS 27.2 beta 1–3 (airlift)"
    ]

    static let kernelIOS17Range = "17.0–17.7.x"
    static let kernelIOS18Range = "18.0–18.7.2"
    static let badQueryIOS26Range = "26.0–26.6.2"
    /// iOS 27.2: beta 1, 2 e 3 verificados funcionando no Airlift.
    static let airliftIOS27Range = "27.0–27.0.1, 27.2 beta 1–3"

    /// Último build com offsets de kernel verificados.
    static let kernelOffsetsMaxNote = "26.0.x"

    // Aliases de exibição para as telas legadas (Onboarding/Settings).
    static let verifiedIOS17Range = kernelIOS17Range
    static let verifiedIOS18Range = kernelIOS18Range
    static let verifiedIOS26Range = badQueryIOS26Range
    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    // MARK: - Faixas

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 { return minor <= 7 }
        if major == 18 { return minor < 7 || (minor == 7 && patch <= 2) }
        return false
    }

    /// iOS 26 usa a mesma cadeia de kernel, mas exige o sandbox escape
    /// completo antes de conceder o container via bad_query.
    static func supportsBadQuery(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        guard major == 26 else { return false }
        return minor < 6 || (minor == 6 && patch <= 2)
    }

    /// Airlift só nas versões onde o pareamento acontece dentro do iPhone,
    /// sem cabo e sem computador.
    static func supportsAirlift(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        guard major == 27 else { return false }

        if minor == 0 { return patch <= 1 }
        if minor == 2 { return !isPatchedAirliftBuild(major: major, minor: minor, build: build) }
        return false
    }

    /// Builds onde o AirTraffic sync foi fechado pela Apple. Vazio de propósito:
    /// 27.2 beta 3 foi testado e funciona. Preencha só se um build novo quebrar.
    private static let patchedAirliftBuilds: Set<String> = []

    static func isPatchedAirliftBuild(major: Int, minor: Int, build: String) -> Bool {
        patchedAirliftBuilds.contains(build)
    }

    /// Rota de acesso privilegiado para esta versão. `nil` = não suportado.
    static func accessKind(major: Int, minor: Int, patch: Int, build: String) -> AccessKind? {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return .kernel
        }
        if supportsBadQuery(major: major, minor: minor, patch: patch) {
            return .badQuery
        }
        if supportsAirlift(major: major, minor: minor, patch: patch, build: build) {
            return .airlift
        }
        return nil
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        accessKind(major: major, minor: minor, patch: patch, build: build) != nil
    }

    /// Mantém a UI utilizável em versões listadas sem alargar a allow-list.
    static func isAppVersionListed(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }
        if isSupported(major: major, minor: minor, patch: patch, build: build) { return true }

        // iOS 16 só abre a UI (sem rota de acesso).
        if major == 16 { return minor == 6 || (minor == 7 && patch <= 10) }
        // 18.x acima de 18.7.2 e 26/27 acima das faixas abrem, mas não liberam.
        if major == 18 { return minor == 7 }
        if major == 26 { return true }
        if major == 27 { return true }
        return false
    }

    /// Texto curto para o Profile e para a aba Config.
    static func accessDescription(kind: AccessKind) -> String {
        switch kind {
        case .kernel:
            return "Kernel exploit — leitura e escrita no container, backup local do original."
        case .badQuery:
            return "Kernel + sandbox escape + bad_query — leitura e escrita no container, backup local do original."
        case .airlift:
            return "Airlift — escrita no container pelo pareamento do próprio iPhone. Sem leitura: o restore baixa o original publicado pelo site."
        }
    }

    static func accessRangeLabel(kind: AccessKind) -> String {
        switch kind {
        case .kernel: return "iOS 17.0–18.7.2"
        case .badQuery: return "iOS 26.0–26.6.2"
        case .airlift: return "iOS 27.0–27.2 b3"
        }
    }
}
