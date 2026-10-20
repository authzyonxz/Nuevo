import Foundation

/// Uma variante de aim publicada pelo site.
///
/// O `id` é o contrato entre site e app: o site publica o arquivo em
/// `/api/v1/functions/<id>` e o app baixa exatamente esse id. O arquivo enviado
/// é um arquivo normal — não é pacote `.3105` — e o app procura esse nome em
/// todo o container do bundle ID alvo antes de substituir.
struct AimFunctionDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let symbol: String
    let statusLabel: String
}

enum AimFunctionConfig {
    static let serverURLKey = "aim.serverBaseURL"
    static let bundleIDKey = "aim.targetBundleID"

    /// Endpoint de produção do painel 3105.
    static let defaultServerURL = "https://keyauthv2.org/3105"
}

enum AimFunctionCatalog {
    static let all: [AimFunctionDefinition] = [
        AimFunctionDefinition(
            id: "hs-neck-antenna",
            title: "HS Pescoço + Antena",
            summary: "HS no pescoço do inimigo e Antena na mão",
            symbol: "scope",
            statusLabel: "Safe"
        ),
        AimFunctionDefinition(
            id: "hs-high-antenna",
            title: "HS Alto + Antena",
            summary: "HS acima da cabeça + Antena na mão",
            symbol: "scope",
            statusLabel: "Safe"
        ),
        AimFunctionDefinition(
            id: "hs-high-neck",
            title: "HS Alto + Pescoço",
            summary: "HS acima e no pescoço do inimigo",
            symbol: "scope",
            statusLabel: "Safe"
        ),
        AimFunctionDefinition(
            id: "hs-chest",
            title: "HS Peito",
            summary: "HS no peito do inimigo",
            symbol: "scope",
            statusLabel: "Safe"
        ),
    ]

    static func function(id: String) -> AimFunctionDefinition? {
        all.first { $0.id == id }
    }
}
