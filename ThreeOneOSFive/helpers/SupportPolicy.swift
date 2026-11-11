import Foundation

/// Policy de compatibilidade e rota de acesso.
///
/// Três faixas, três regras:
///  - kernel exploit  → iOS 17.0–17.7.x e 18.0–18.7.1 (kexploit_opa334)
///  - airlift         → iOS 27.0–27.0.1 e 27.2 beta 1–2, com pareamento
///                      iniciado no próprio iPhone (sem computador)
///  - bloqueado       → 27.2 beta 3+ (Apple corrigiu), 18.7.11+, 26.6.3+
enum ExploitSupportPolicy {

    /// Versões exibidas em Profile como "o app abre". É mais largo que a
    /// allow-list de acesso privilegiado, por design.
    static let listedIOSVersions: [String] = [
        "iOS 16.6–16.7.10 (somente UI)",
        "iOS 17.0–17.7.x (kernel)",
        "iOS 18.0–18.7.1 (kernel)",
        "iOS 27.0–27.0.1 (airlift)",
        "iOS 27.2 beta 1–2 (airlift)"
    ]

    static let kernelIOS17Range = "17.0–17.7.x"
    static let kernelIOS18Range = "18.0–18.7.1"
    static let airliftIOS27Range = "27.0–27.0.1"

    /// Beta 3 em diante: a Apple fechou o sync exploit do AirTraffic.
    static let patchedMessage = "iOS 27.2 beta 3 ou superior — a Apple corrigiu o AirTraffic sync. Não há caminho por Airlift neste build."

    // Aliases mantidos para as telas legadas (Onboarding/Settings) que só exibem
    // a faixa; a fonte de verdade é `accessKind`.
    static let verifiedIOS17Range = kernelIOS17Range
    static let verifiedIOS18Range = kernelIOS18Range
    static let verifiedIOS26Range = "não suportado — Airlift local somente no iOS 27"
    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 { return minor <= 7 }
        if major == 18 { return minor < 7 || (minor == 7 && patch <= 1) }
        return false
    }

    static func supportsAirlift(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 27 {
            if minor == 0 { return patch <= 1 }
            // 27.2: beta 1 e 2 funcionam, beta 3+ está corrigido.
            if minor == 2 { return !isPatchedAirliftBuild(major: major, minor: minor, build: build) }
            return false
        }

        return false
    }

    /// Builds conhecidos como já corrigidos. Vazio = todos os builds listados
    /// por versão passam; o exploit falha de forma explícita se o build real
    /// já tiver o patch.
    private static let patchedAirliftBuilds: Set<String> = []

    static func isPatchedAirliftBuild(major: Int, minor: Int, build: String) -> Bool {
        patchedAirliftBuilds.contains(build)
    }

    /// Rota de acesso privilegiado para esta versão. `nil` = não suportado.
    static func accessKind(major: Int, minor: Int, patch: Int, build: String) -> AccessKind? {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return .kernel
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

        if isSupported(major: major, minor: minor, patch: patch, build: build) {
            return true
        }

        if major == 16 {
            return minor == 6 || (minor == 7 && patch <= 10)
        }

        return major == 27
    }

    /// Texto curto pro Profile.
    static func accessDescription(kind: AccessKind) -> String {
        switch kind {
        case .kernel:
            return "Kernel exploit — leitura e escrita no container, backup local do original."
        case .airlift:
            return "Airlift — escrita no container por pareamento. Backup local do original não existe: o restore baixa o original publicado pelo site."
        }
    }
}
