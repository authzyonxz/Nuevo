import Foundation
import SwiftUI

enum ModType: String, CaseIterable, Identifiable, Hashable {
    case testePatch = "AIMBOT + ESP"
    case hsAlto = "HS ALTO"
    case hsPescoco = "HS PESCOÇO"
    case hsPescocoAntena = "HS PESCOÇO + ANTENA"
    case hsPeito = "HS ALTO + PESCOÇO"
    case hologramaArmas = "HOLOGRAMA ARMAS"
    case cacheHsAlto = "CACHE HS ALTO"
    case cacheHsPescoco = "CACHE HS PESCOÇO"
    case cacheHsPeito = "CACHE HS PEITO"
    case cacheBalaMagica = "CACHE BALA MÁGICA"
    case chamsAmarelo = "AMARELO"
    case chamsVermelho = "VERMELHO"
    case chamsRoxo = "ROXO"
    case chamsLaranja = "LARANJA"
    case chamsPreto = "PRETO"
    case chamsBranco = "BRANCO"
    case texturaAlok1 = "Skin Instaplayer"
    case texturaAlok2 = "Skin Mandela"
    case texturaAlok3 = "Skin RuokFF"
    case fps144 = "144fps"

    var id: String { rawValue }

    /// Funções Avatar são restauradas automaticamente antes de abrir o jogo.
    /// As funções Cache não fazem parte deste grupo e mantêm seu comportamento atual.
    var isAvatar: Bool {
        switch self {
        case .hsAlto, .hsPescoco, .hsPescocoAntena, .hsPeito:
            return true
        default:
            return false
        }
    }

    /// ID estável usado apenas para reencontrar o journal da função após
    /// encerrar e abrir novamente o IPA.
    var persistentProjectID: UUID {
        switch self {
        case .testePatch: return TestPatchFeature.projectID
        case .hsAlto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A01")!
        case .hsPescoco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A02")!
        case .hsPescocoAntena: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A05")!
        case .hsPeito: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A03")!
        case .hologramaArmas: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A04")!
        case .cacheHsAlto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A21")!
        case .cacheHsPescoco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A22")!
        case .cacheHsPeito: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A23")!
        case .cacheBalaMagica: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A24")!
        case .chamsAmarelo: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A31")!
        case .chamsVermelho: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A32")!
        case .chamsRoxo: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A33")!
        case .chamsLaranja: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A34")!
        case .chamsPreto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A35")!
        case .chamsBranco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A36")!
        case .texturaAlok1: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A11")!
        case .texturaAlok2: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A12")!
        case .texturaAlok3: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A13")!
        case .fps144: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A14")!
        }
    }

    var subtitle: String {
        switch self {
        case .testePatch: return "aimbot legit e esp linha, caixa, nome e vida"
        case .hsAlto: return "HS acima da cabeça do inimigo."
        case .hsPescoco: return "HS no pescoço do inimigo."
        case .hsPescocoAntena: return "HS NO PESCOÇO DO INIMIGO E ANTENA NA MÃO"
        case .hsPeito: return "HS acima da cabeça e no pescoço."
        case .hologramaArmas: return "Usar Gráfico no Padrão Para Funcionar."
        case .cacheHsAlto: return "HS acima da cabeça do inimigo usando arquivo Cache."
        case .cacheHsPescoco: return "HS no pescoço do inimigo usando arquivo Cache."
        case .cacheHsPeito: return "HS no peito do inimigo usando arquivo Cache."
        case .cacheBalaMagica: return "Acerta tiros a distância mesmo quando a mira não gruda."
        case .chamsAmarelo: return "Aplica o holograma de armas na cor amarela."
        case .chamsVermelho: return "Aplica o holograma de armas na cor vermelha."
        case .chamsRoxo: return "Aplica o holograma de armas na cor roxa."
        case .chamsLaranja: return "Aplica o holograma de armas na cor laranja."
        case .chamsPreto: return "Aplica o holograma de armas na cor preta."
        case .chamsBranco: return "Aplica o holograma de armas na cor branca."
        case .texturaAlok1, .texturaAlok2, .texturaAlok3: return "Usar personagem alok despertar para funcionar a textura."
        case .fps144: return "Força 120/144 FPS no jogo selecionado em dispositivos compatíveis."
        }
    }

    var sectionName: String {
        switch self {
        case .testePatch:
            return "FUNÇÕES AIMBOT LEGIT + ESP"
        case .hsAlto, .hsPescoco, .hsPescocoAntena, .hsPeito:
            return "FUNÇÕES DE AIMBOT"
        case .hologramaArmas:
            return "FUNÇÕES DE HOLOGRAMA"
        case .cacheHsAlto, .cacheHsPescoco, .cacheHsPeito, .cacheBalaMagica:
            return "FUNÇÕES CACHE"
        case .chamsAmarelo, .chamsVermelho, .chamsRoxo, .chamsLaranja, .chamsPreto, .chamsBranco:
            return "CHAMS"
        case .texturaAlok1, .texturaAlok2, .texturaAlok3:
            return "TEXTURAS"
        case .fps144:
            return "DESEMPENHO"
        }
    }
}

class FreeFireModManager: ObservableObject {
    static let shared = FreeFireModManager()

    @Published private(set) var activeMods: Set<ModType> = []
    @Published private(set) var remoteDisplayNames: [ModType: String] = [:]
    @Published var statusMessage: String = "Pronto para injetar"
    @Published var debugLogs: String = ""
    @Published private(set) var isProcessing = false

    private let operationLock = NSLock()
    private var operationInFlight = false

    private let supportedBundleIDs: Set<String> = ["com.dts.freefireth", "com.dts.freefiremax"]
    private let localTextureTargetName = "optionalab_avatar_66.DfUs7MzeaoXWJ4jWN8zRBmYoY7Q~3D"

    private var activeReceipts: [ModType: PatchTransactionReceipt] = [:]
    private var activeBundleIDs: [ModType: Set<String>] = [:]

    init() {
        restorePersistedState()
        refreshRemoteCatalog()
    }

    func displayName(for mod: ModType) -> String {
        switch mod {
        case .hsAlto, .hsPescoco, .hsPescocoAntena, .hsPeito:
            return mod.rawValue
        case .cacheHsAlto: return "HS ALTO"
        case .cacheHsPescoco: return "HS PESCOÇO"
        case .cacheHsPeito: return "HS PEITO"
        case .cacheBalaMagica: return "BALA MÁGICA"
        case .chamsAmarelo, .chamsVermelho, .chamsRoxo, .chamsLaranja, .chamsPreto, .chamsBranco:
            return mod.rawValue
        default:
            return remoteDisplayNames[mod] ?? mod.rawValue
        }
    }

    private func refreshRemoteCatalog() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let manifest = try await OnlinePayloadUpdater.shared.manifest(forceRefresh: true)
                let ids: [ModType: String] = [
                    .hsAlto: "aimbot_hs_alto", .hsPescoco: "aimbot_hs_pescoco",
                    .hsPescocoAntena: "aimbot_hs_pescoco_antena", .hsPeito: "aimbot_hs_alto_pescoco",
                    .hologramaArmas: "holograma_armas", .texturaAlok1: "textura_instaplayer",
                    .texturaAlok2: "textura_mandela", .texturaAlok3: "textura_ruokff", .fps144: "fps_144",
                    .cacheHsAlto: "cache_hs_alto", .cacheHsPescoco: "cache_hs_pescoco",
                    .cacheHsPeito: "cache_hs_peito", .cacheBalaMagica: "cache_bala_magica",
                    .chamsAmarelo: "chams_amarelo", .chamsVermelho: "chams_vermelho",
                    .chamsRoxo: "chams_roxo", .chamsLaranja: "chams_laranja",
                    .chamsPreto: "chams_preto", .chamsBranco: "chams_branco"
                ]
                let names: [ModType: String] = Dictionary(uniqueKeysWithValues: ids.compactMap { (mod: ModType, id: String) -> (ModType, String)? in
                    guard let item = manifest.payloads.first(where: { $0.id == id }) else { return nil }
                    return (mod, item.displayName)
                })
                await MainActor.run { self.remoteDisplayNames = names }
            } catch {
                self.addLog("Catálogo remoto ainda não configurado: \(error.localizedDescription)")
            }
        }
    }

    /// Reconstitui a indicação das funções cujo patch continua aplicado.
    /// Nenhuma restauração é executada aqui; isso só acontece em restoreOriginal.
    private func restorePersistedState() {
        var restored: [ModType: PatchTransactionReceipt] = [:]
        var restoredBundles: [ModType: Set<String>] = [:]
        for mod in ModType.allCases {
            if let receipt = DevicePatchService.latestReceipt(projectID: mod.persistentProjectID) {
                restored[mod] = receipt
                let bundles = (try? DevicePatchService.requiredBundleIdentifiers(for: receipt)) ?? []
                restoredBundles[mod] = Set(bundles)
            }
        }

        activeReceipts = restored
        activeBundleIDs = restoredBundles
        activeMods = Set(restored.keys)
        statusMessage = activeMods.isEmpty
            ? "Pronto para injetar"
            : activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"

        if !activeMods.isEmpty {
            addLog("Estado restaurado: \(activeMods.map(\.rawValue).sorted().joined(separator: ", "))")
        }
    }

    func activeMods(for bundleID: String) -> Set<ModType> {
        Set(activeMods.filter { activeBundleIDs[$0]?.contains(bundleID) == true })
    }

    func isActive(_ mod: ModType, bundleID: String) -> Bool {
        activeMods.contains(mod) && activeBundleIDs[mod]?.contains(bundleID) == true
    }

    private func fetchRemotePayloadIfAvailable(mod: ModType, bundleID: String, completion: @escaping ((OnlinePayloadUpdater.RemotePayload, Data)?) -> Void) {
        guard [.hsAlto, .hsPescoco, .hsPescocoAntena, .hsPeito, .hologramaArmas,
               .cacheHsAlto, .cacheHsPescoco, .cacheHsPeito, .cacheBalaMagica,
               .chamsAmarelo, .chamsVermelho, .chamsRoxo, .chamsLaranja,
               .chamsPreto, .chamsBranco].contains(mod) else {
            completion(nil)
            return
        }
        let remoteIDs: [ModType: String] = [
            .hsAlto: "aimbot_hs_alto", .hsPescoco: "aimbot_hs_pescoco",
            .hsPescocoAntena: "aimbot_hs_pescoco_antena", .hsPeito: "aimbot_hs_alto_pescoco",
            .hologramaArmas: "holograma_armas", .cacheHsAlto: "cache_hs_alto",
            .cacheHsPescoco: "cache_hs_pescoco", .cacheHsPeito: "cache_hs_peito",
            .cacheBalaMagica: "cache_bala_magica", .chamsAmarelo: "chams_amarelo",
            .chamsVermelho: "chams_vermelho", .chamsRoxo: "chams_roxo",
            .chamsLaranja: "chams_laranja", .chamsPreto: "chams_preto",
            .chamsBranco: "chams_branco"
        ]
        guard let id = remoteIDs[mod] else { completion(nil); return }
        Task {
            do {
                let result = try await OnlinePayloadUpdater.shared.download(id: id, bundleID: bundleID, forceRefresh: true)
                completion(result)
            } catch {
                addLog("Payload remoto indisponível para \(mod.rawValue): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: Date())
            self.debugLogs += "[\(time)] \(msg)\n"
            log(msg)
        }
    }

    func applyMod(_ mod: ModType, bundleID: String, completion: @escaping (Bool, String) -> Void) {
        guard supportedBundleIDs.contains(bundleID) else {
            complete(completion, success: false, message: "Jogo selecionado não suportado.")
            return
        }
        LicenseManager.shared.recheckSecureSession { [weak self] valid, message in
            guard let self else { return }
            guard valid else {
                self.complete(completion, success: false, message: message ?? "Sessão expirada. Valide a key novamente.")
                return
            }
            self.fetchRemotePayloadIfAvailable(mod: mod, bundleID: bundleID) { [weak self] remotePayload in
                guard let self else { return }
                self.applyModAfterSessionCheck(mod, bundleID: bundleID, remotePayload: remotePayload, completion: completion)
            }
        }
    }

    private func applyModAfterSessionCheck(_ mod: ModType, bundleID: String, remotePayload: (OnlinePayloadUpdater.RemotePayload, Data)? = nil, completion: @escaping (Bool, String) -> Void) {
        let bundleIds = [bundleID]
        guard LicenseManager.shared.isAuthorized else {
            complete(completion, success: false, message: "Key ativa necessária. Valide a key antes de ativar uma função.")
            return
        }
        guard beginOperation() else {
            complete(completion, success: false, message: "Outra operação já está em andamento.")
            return
        }
        guard KernelExploit.currentAccessPath != .unsupported else {
            endOperation()
            complete(completion, success: false, message: "Esta versão/build do iOS não é suportada.")
            return
        }
        if activeMods.contains(mod), !isActive(mod, bundleID: bundleID) {
            endOperation()
            complete(completion, success: false, message: "Esta função está ativa no outro jogo. Restaure-a antes de continuar.")
            return
        }
        guard !activeMods(for: bundleID).contains(where: { $0.sectionName == mod.sectionName }) else {
            endOperation()
            complete(completion, success: false, message: "Já existe uma função ativa neste grupo. Restaure-a antes de escolher outra.")
            return
        }

        if mod == .testePatch {
            addLog("TESTE PATCH: consultando pacote remoto teste_patch")
            prepareLegacyKernelAccessIfNeeded()
            Task.detached(priority: .userInitiated) {
                do {
                    let receipt = try await TestPatchFeature.apply(bundleID: bundleID)
                    self.addLog("TESTE PATCH remoto aplicado: journal criado e arquivos verificados")
                    DispatchQueue.main.async {
                        self.activeReceipts[mod] = receipt
                        self.activeBundleIDs[mod] = [bundleID]
                        self.activeMods.insert(mod)
                        self.statusMessage = self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                        self.endOperation()
                        completion(true, "TESTE PATCH ativado com sucesso.")
                    }
                } catch {
                    self.addLog("TESTE PATCH remoto falhou: \(error.localizedDescription)")
                    self.endOperation()
                    self.complete(completion, success: false, message: "Falha ao ativar TESTE PATCH: \(error.localizedDescription)")
                }
            }
            return
        }

        addLog("Injeção V21: \(mod.rawValue)")

        let localPayload = [.texturaAlok1, .texturaAlok2, .texturaAlok3, .fps144].contains(mod)
        let remoteDefinition: OnlinePayloadUpdater.RemotePayload?
        let modData: Data
        let currentTarget: String
        if localPayload {
            do {
                modData = try ProtectedModPayloadStore.decrypt(mod)
            } catch {
                addLog("ERRO: payload local protegido indisponível: \(mod.rawValue)")
                endOperation()
                complete(completion, success: false, message: "Payload local protegido indisponível.")
                return
            }
            remoteDefinition = nil
            currentTarget = mod == .fps144 ? "\(bundleID).plist" : localTextureTargetName
            addLog("Payload local AES-GCM aberto somente em memória: \(mod.rawValue)")
        } else {
            guard let remotePayload, !remotePayload.1.isEmpty else {
                addLog("ERRO: nenhum payload remoto publicado para \(mod.rawValue)")
                endOperation()
                complete(completion, success: false, message: "Nenhum payload publicado no site para esta função.")
                return
            }
            remoteDefinition = remotePayload.0
            modData = remotePayload.1
            currentTarget = remotePayload.0.fileName
            addLog("Payload remoto validado em memória: \(mod.rawValue) v\(remotePayload.0.version)")
        }
        let modSize = modData.count
        addLog("Origem OK: \(modSize) bytes")

        prepareLegacyKernelAccessIfNeeded()

        var rules: [PatchRule] = []
        var resolvedContainers = 0
        let configuredPaths = remoteDefinition?.targetPaths ?? []
        if !localPayload && configuredPaths.isEmpty {
            addLog("ERRO: o payload remoto não possui caminhos configurados")
            endOperation()
            complete(completion, success: false, message: "Configure pelo menos um caminho no site.")
            return
        }

        for bid in bundleIds {
            guard let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid), !rootPath.isEmpty else {
                addLog("DIAGNÓSTICO: container não resolvido para \(bid)")
                continue
            }
            resolvedContainers += 1
            if localPayload {
                if mod == .fps144 {
                    let requiredRelativePath = "Library/Preferences/\(currentTarget)"
                    guard resolveRemoteTarget(relativePath: requiredRelativePath, fileName: currentTarget, rootPath: rootPath) != nil else {
                        addLog("ERRO: 144fps não encontrado no caminho exato: \(requiredRelativePath)")
                        continue
                    }
                    addLog("144fps encontrado no caminho exato: \(requiredRelativePath)")
                    rules.append(PatchRule(bundleID: bid, relativePath: requiredRelativePath, replacementFilename: currentTarget, replacementData: modData))
                } else {
                    let textureNames = [
                        currentTarget,
                        "optionalab_avatar_66.CoOEgYl5yYUMEbFNIb8L3onAO6o~3D"
                    ]
                    let allowedDirectories = [
                        "/Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/",
                        "/Documents/contentcache/Optional/ios/gameassetbundles/",
                        "/Documents/contentcache/optional/ios/optionalavatarres/gameassetbundles/",
                        "/Documents/contentcache/optional/ios/gameassetbundles/"
                    ]
                    let normalizedRoot = rootPath.replacingOccurrences(of: "\\\\", with: "/")
                    let searchDirectories = [
                        "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles",
                        "Documents/contentcache/Optional/ios/gameassetbundles",
                        "Documents/contentcache/optional/ios/optionalavatarres/gameassetbundles",
                        "Documents/contentcache/optional/ios/gameassetbundles"
                    ]
                    addLog("TEXTURA DIAG: bundle=\(bid)")
                    addLog("TEXTURA DIAG: container=\(normalizedRoot)")
                    addLog("TEXTURA DIAG: diretórios permitidos=\(allowedDirectories.joined(separator: ","))")
                    var matches: [String] = []
                    for textureName in textureNames {
                        addLog("TEXTURA DIAG: pesquisando nome exato=\(textureName)")
                        for directory in searchDirectories {
                            let directoryPath = (rootPath as NSString).appendingPathComponent(directory)
                            addLog("TEXTURA DIAG: concedendo acesso e pesquisando diretório=\(directory)")
                            let found = findFilesWithSelectedAccess(named: textureName, in: directoryPath)
                            addLog("TEXTURA DIAG: resultados em \(directory)=\(found.count)")
                            for path in found.prefix(10) {
                                addLog("TEXTURA DIAG: resultado=\(path.replacingOccurrences(of: "\\\\", with: "/"))")
                            }
                            matches.append(contentsOf: found.filter { path in
                                let normalized = path.replacingOccurrences(of: "\\\\", with: "/")
                                return normalized.hasPrefix(normalizedRoot) && allowedDirectories.contains(where: { normalized.contains($0) })
                            })
                        }
                    }
                    if matches.isEmpty {
                        addLog("TEXTURA DIAG: nenhum nome exato; iniciando fallback pelo prefixo optionalab_avatar_")
                        for directory in searchDirectories {
                            let directoryPath = (rootPath as NSString).appendingPathComponent(directory)
                            let prefixed = findFilesStarting(with: "optionalab_avatar_", in: directoryPath)
                            addLog("TEXTURA DIAG: candidatos por prefixo em \(directory)=\(prefixed.count)")
                            for path in prefixed.prefix(20) {
                                addLog("TEXTURA DIAG: candidato prefixo=\(path.replacingOccurrences(of: "\\\\", with: "/"))")
                            }
                            matches.append(contentsOf: prefixed)
                        }
                    }
                    addLog("TEXTURA DIAG: resultados aceitos=\(matches.count)")
                    guard let existing = matches.first else {
                        addLog("Alvo local não encontrado após busca compatível nos diretórios de textura")
                        continue
                    }
                    let relativePath = String(existing.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    addLog("Textura encontrada pela busca antiga compatível: \(relativePath)")
                    rules.append(PatchRule(bundleID: bid, relativePath: relativePath, replacementFilename: (existing as NSString).lastPathComponent, replacementData: modData))
                }
            } else {
                for configuredPath in configuredPaths {
                    let relativeInput = configuredPath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                    guard !relativeInput.isEmpty, !relativeInput.contains("..") else {
                        addLog("ERRO: caminho remoto rejeitado por segurança: \(configuredPath)")
                        continue
                    }
                    guard let targetFullPath = resolveRemoteTarget(relativePath: relativeInput, fileName: currentTarget, rootPath: rootPath) else {
                        addLog("Alvo não encontrado no caminho publicado: \(relativeInput) | arquivo exato: \(currentTarget)")
                        continue
                    }
                    let relativePath = String(targetFullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    addLog("Alvo remoto encontrado: \(relativePath)")
                    rules.append(PatchRule(bundleID: bid, relativePath: relativePath, replacementFilename: (targetFullPath as NSString).lastPathComponent, replacementData: modData))
                }
            }
        }

        if rules.isEmpty {
            if resolvedContainers == 0 {
                addLog("ERRO: nenhum container foi resolvido; verificar build, bundle ID e acesso")
                endOperation()
                complete(completion, success: false, message: "Container do aplicativo não localizado.")
            } else {
                addLog("ERRO: \(resolvedContainers) container(es) resolvido(s), mas nenhum arquivo-alvo foi localizado")
                endOperation()
                complete(completion, success: false, message: "Arquivo-alvo não localizado no container.")
            }
            return
        }

        let projectName = remoteDefinition.map { "MenagerFF_Remote_\($0.id)_v\($0.version)" } ?? "MenagerFF_Local_\(mod.rawValue)"
        let project = PatchProject(
            id: mod.persistentProjectID,
            name: projectName,
            rules: rules
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let receipt = try DevicePatchService.apply(project: project)
                self.addLog("SUCESSO: Injetado em \(rules.count) locais!")
                DispatchQueue.main.async {
                    self.activeReceipts[mod] = receipt
                    self.activeBundleIDs[mod] = [bundleID]
                    self.activeMods.insert(mod)
                    self.statusMessage = self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                    self.endOperation()
                    completion(true, "Injetado com sucesso")
                }
            } catch {
                self.addLog("ERRO: \(error.localizedDescription)")
                self.endOperation()
                self.complete(completion, success: false, message: "Falha: \(error.localizedDescription)")
            }
        }
    }

    private func prepareLegacyKernelAccessIfNeeded() {
        guard KernelExploit.currentAccessPath == .kernelOffsets else {
            log("access: mod operation uses ContainerManager bad_query; kernel elevation skipped")
            return
        }
        guard KernelExploit.kernelAccessActive else {
            log("access: kernel elevation skipped because kernel access is not active")
            return
        }

        let selfProc = proc_self()
        guard selfProc != 0 else {
            log("access: kernel elevation skipped because proc_self returned 0")
            return
        }

        let result = sandbox_elevate_to_root(selfProc)
        guard result == 0 else {
            log("access: kernel elevation failed with result=\(result)")
            return
        }
        log("access: legacy kernel elevation active")
    }

    private func resolveRemoteTarget(relativePath: String, fileName: String, rootPath: String) -> String? {
        var accessHandle: Int64 = -1
        if KernelExploit.currentAccessPath == .badQuery {
            accessHandle = ContainerStore.grantContainerAccess(rootPath)
            guard accessHandle >= 0 else {
                addLog("DIAGNÓSTICO: acesso ao container falhou antes da resolução: \(accessHandle)")
                return nil
            }
            defer { bad_query_release(accessHandle) }
        }
        guard let configured = resolveCaseInsensitivePath(relativePath, from: rootPath) else {
            addLog("DIAGNÓSTICO: caminho publicado não existe com nenhuma capitalização: \(relativePath)")
            return nil
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: configured, isDirectory: &isDirectory), isDirectory.boolValue {
            let exact = (configured as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: exact) { return exact }
            let matches = findFilesWithSelectedAccess(named: fileName, in: configured)
            return matches.first
        }
        if FileManager.default.fileExists(atPath: configured) { return configured }
        let parent = (configured as NSString).deletingLastPathComponent
        return findFilesWithSelectedAccess(named: fileName, in: parent).first
    }

    private func resolveCaseInsensitivePath(_ relativePath: String, from rootPath: String) -> String? {
        var current = rootPath
        for component in relativePath.split(separator: "/").map(String.init) {
            let direct = (current as NSString).appendingPathComponent(component)
            if FileManager.default.fileExists(atPath: direct) {
                current = direct
                continue
            }
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: current),
                  let match = entries.first(where: { $0.caseInsensitiveCompare(component) == .orderedSame }) else { return nil }
            current = (current as NSString).appendingPathComponent(match)
        }
        return current
    }

    private func findFilesWithSelectedAccess(named name: String, in directory: String) -> [String] {
        if KernelExploit.currentAccessPath == .badQuery {
            let handle = ContainerStore.grantContainerAccess(directory)
            guard handle >= 0 else {
                log("access: bad_query grant failed for search result=\(handle)")
                return []
            }
            defer { bad_query_release(handle) }
        }
        return findFiles(named: name, in: directory)
    }

    private func findFilesStarting(with prefix: String, in directory: String) -> [String] {
        var results: [String] = []
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.hasPrefix(prefix) { results.append(fileURL.path) }
            }
        }
        return results
    }

    private func findFiles(named name: String, in directory: String) -> [String] {
        var results: [String] = []
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)

        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == name {
                    results.append(fileURL.path)
                }
            }
        }
        return results
    }

    func restoreMod(_ mod: ModType, bundleID: String, completion: @escaping (Bool, String) -> Void) {
        LicenseManager.shared.recheckSecureSession { [weak self] valid, message in
            guard let self else { return }
            guard valid else {
                self.complete(completion, success: false, message: message ?? "Sessão expirada. Valide a key novamente.")
                return
            }
            guard self.beginOperation() else {
                self.complete(completion, success: false, message: "Outra operação já está em andamento.")
                return
            }
            guard KernelExploit.currentAccessPath != .unsupported else {
                self.endOperation()
                self.complete(completion, success: false, message: "Esta versão/build do iOS não é suportada.")
                return
            }
            guard self.isActive(mod, bundleID: bundleID),
                  let receipt = self.activeReceipts[mod] ?? DevicePatchService.latestReceipt(projectID: mod.persistentProjectID) else {
                self.endOperation()
                self.complete(completion, success: false, message: "Nenhum backup desta função foi encontrado para o jogo selecionado.")
                return
            }

            self.addLog("Restaurando somente: \(mod.rawValue)")
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard KernelExploit.ensureAccessForRestore() else { throw PatchPackageError.restoreFailed }
                    self.prepareLegacyKernelAccessIfNeeded()
                    try DevicePatchService.restore(receipt: receipt)
                    DispatchQueue.main.async {
                        self.activeReceipts.removeValue(forKey: mod)
                        self.activeBundleIDs.removeValue(forKey: mod)
                        self.activeMods.remove(mod)
                        self.statusMessage = self.activeMods.isEmpty
                            ? "Pronto para injetar"
                            : self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                        self.endOperation()
                        completion(true, "Função \(mod.rawValue) restaurada com sucesso")
                    }
                } catch {
                    self.endOperation()
                    self.complete(completion, success: false, message: "Falha ao restaurar \(mod.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }

    func restoreOriginal(completion: @escaping (Bool, String) -> Void) {
        LicenseManager.shared.recheckSecureSession { [weak self] valid, message in
            guard let self else { return }
            guard valid else {
                self.complete(completion, success: false, message: message ?? "Sessão expirada. Valide a key novamente.")
                return
            }
            self.restoreOriginalAfterSessionCheck(completion: completion)
        }
    }

    /// Usado pelo Lobby: restaura cada transação válida antes de permitir a abertura do jogo.
    /// Somente funções Avatar são restauradas aqui; funções Cache permanecem ativas.
    /// Se uma transação falhar, as que já foram restauradas são removidas do estado ativo e as restantes permanecem marcadas.
    func restoreActiveModsBeforeLobby(bundleID: String, completion: @escaping (Bool, String) -> Void) {
        let activeAvatarMods = activeMods(for: bundleID).filter(\.isAvatar)
        guard !activeAvatarMods.isEmpty else {
            completion(true, "Nenhuma função Avatar ativa; funções Cache permanecem inalteradas.")
            return
        }
        LicenseManager.shared.recheckSecureSession { [weak self] valid, message in
            guard let self else { return }
            guard valid else {
                self.complete(completion, success: false, message: message ?? "Sessão expirada. Valide a key novamente.")
                return
            }
            self.restoreOriginalAfterSessionCheck(
                bundleID: bundleID,
                allowedMods: activeAvatarMods,
                completion: completion
            )
        }
    }

    private func restoreOriginalAfterSessionCheck(
        bundleID: String? = nil,
        allowedMods: Set<ModType>? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard beginOperation() else {
            complete(completion, success: false, message: "Outra operação já está em andamento.")
            return
        }
        guard KernelExploit.currentAccessPath != .unsupported else {
            endOperation()
            complete(completion, success: false, message: "Esta versão/build do iOS não é suportada.")
            return
        }

        addLog("Restaurando original...")
        let receiptEntries = activeReceipts.filter { mod, _ in
            if let allowedMods, !allowedMods.contains(mod) {
                return false
            }
            guard let bundleID else { return true }
            return activeBundleIDs[mod]?.contains(bundleID) == true
        }
        guard !receiptEntries.isEmpty else {
            endOperation()
            let message = allowedMods == nil
                ? "Nenhuma função ativa; original já está restaurado."
                : "Nenhuma função Avatar ativa; funções Cache permanecem inalteradas."
            complete(completion, success: true, message: message)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var restoredMods: [ModType] = []
            do {
                guard KernelExploit.ensureAccessForRestore() else {
                    throw PatchPackageError.restoreFailed
                }
                self.prepareLegacyKernelAccessIfNeeded()
                for (mod, receipt) in receiptEntries {
                    try DevicePatchService.restore(receipt: receipt)
                    restoredMods.append(mod)
                    self.addLog("Restaurado: \(mod.rawValue)")
                }
                self.addLog("SUCESSO: Original restaurado e verificado por hash")
                DispatchQueue.main.async {
                    for mod in restoredMods {
                        self.activeReceipts.removeValue(forKey: mod)
                        self.activeBundleIDs.removeValue(forKey: mod)
                        self.activeMods.remove(mod)
                    }
                    self.statusMessage = self.activeMods.isEmpty
                        ? "Original restaurado"
                        : self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                    self.endOperation()
                    completion(true, "Função restaurada com sucesso")
                }
            } catch {
                self.addLog("ERRO: restauração interrompida após \(restoredMods.count)/\(receiptEntries.count): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    for mod in restoredMods {
                        self.activeReceipts.removeValue(forKey: mod)
                        self.activeBundleIDs.removeValue(forKey: mod)
                        self.activeMods.remove(mod)
                    }
                    self.statusMessage = self.activeMods.isEmpty
                        ? "Original restaurado"
                        : self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                    self.endOperation()
                    completion(false, "Restauração interrompida. As funções concluídas foram restauradas; verifique as restantes antes de abrir o jogo.")
                }
            }
        }
    }

    private func beginOperation() -> Bool {
        operationLock.lock()
        defer { operationLock.unlock() }
        guard !operationInFlight else { return false }
        operationInFlight = true
        DispatchQueue.main.async { self.isProcessing = true }
        return true
    }

    private func endOperation() {
        operationLock.lock()
        operationInFlight = false
        operationLock.unlock()
        DispatchQueue.main.async { self.isProcessing = false }
    }

    private func complete(
        _ completion: @escaping (Bool, String) -> Void,
        success: Bool,
        message: String
    ) {
        DispatchQueue.main.async {
            completion(success, message)
        }
    }
}
