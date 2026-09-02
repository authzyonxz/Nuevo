import Foundation
import SwiftUI

enum ModType: String, CaseIterable, Identifiable, Hashable {
    case hsAlto = "HS ALTO"
    case hsPescoco = "HS PESCOÇO"
    case hsPeito = "HS PEITO"
    case hologramaArmas = "HOLOGRAMA ARMAS"
    case texturaAlok1 = "Skin Instaplayer"
    case texturaAlok2 = "Skin Mandela"
    case texturaAlok3 = "Skin RuokFF"
    case fps144 = "144fps"

    var id: String { rawValue }

    /// ID estável usado apenas para reencontrar o journal da função após
    /// encerrar e abrir novamente o IPA.
    var persistentProjectID: UUID {
        switch self {
        case .hsAlto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A01")!
        case .hsPescoco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A02")!
        case .hsPeito: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A03")!
        case .hologramaArmas: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A04")!
        case .texturaAlok1: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A11")!
        case .texturaAlok2: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A12")!
        case .texturaAlok3: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A13")!
        case .fps144: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A14")!
        }
    }

    var subtitle: String {
        switch self {
        case .hsAlto: return "HS Acima da Cabeça do Inimigo."
        case .hsPescoco: return "HS Apenas no Pescoço do Inimigo."
        case .hsPeito: return "HS no Peito do Inimigo."
        case .hologramaArmas: return "Usar Gráfico no Padrão Para Funcionar."
        case .texturaAlok1, .texturaAlok2, .texturaAlok3: return "Usar personagem alok despertar para funcionar a textura."
        case .fps144: return "Funciona no Free Fire normal em dispositivos iOS com tela 120Hz."
        }
    }

    var sectionName: String {
        switch self {
        case .hsAlto, .hsPescoco, .hsPeito:
            return "FUNÇÕES DE AIMBOT"
        case .hologramaArmas:
            return "FUNÇÕES DE HOLOGRAMA"
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
    private let localFPSPreferenceName = "com.dts.freefireth.plist"

    private var activeReceipts: [ModType: PatchTransactionReceipt] = [:]

    init() {
        restorePersistedState()
        refreshRemoteCatalog()
    }

    func displayName(for mod: ModType) -> String {
        remoteDisplayNames[mod] ?? mod.rawValue
    }

    private func refreshRemoteCatalog() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let manifest = try await OnlinePayloadUpdater.shared.manifest(forceRefresh: true)
                let ids: [ModType: String] = [
                    .hsAlto: "hs_alto", .hsPescoco: "hs_pescoco", .hsPeito: "hs_peito",
                    .hologramaArmas: "holograma_armas", .texturaAlok1: "textura_instaplayer",
                    .texturaAlok2: "textura_mandela", .texturaAlok3: "textura_ruokff", .fps144: "fps_144"
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
        for mod in ModType.allCases {
            if let receipt = DevicePatchService.latestReceipt(projectID: mod.persistentProjectID) {
                restored[mod] = receipt
            }
        }

        activeReceipts = restored
        activeMods = Set(restored.keys)
        statusMessage = activeMods.isEmpty
            ? "Pronto para injetar"
            : activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"

        if !activeMods.isEmpty {
            addLog("Estado restaurado: \(activeMods.map(\.rawValue).sorted().joined(separator: ", "))")
        }
    }

    private func fetchRemotePayloadIfAvailable(mod: ModType, bundleID: String, completion: @escaping ((OnlinePayloadUpdater.RemotePayload, Data)?) -> Void) {
        guard [.hsAlto, .hsPescoco, .hsPeito, .hologramaArmas].contains(mod) else {
            completion(nil)
            return
        }
        let remoteIDs: [ModType: String] = [
            .hsAlto: "hs_alto", .hsPescoco: "hs_pescoco", .hsPeito: "hs_peito",
            .hologramaArmas: "holograma_armas", .texturaAlok1: "textura_instaplayer",
            .texturaAlok2: "textura_mandela", .texturaAlok3: "textura_ruokff", .fps144: "fps_144"
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
        guard mod != .fps144 || bundleID == "com.dts.freefireth" else {
            complete(completion, success: false, message: "A função 144fps funciona somente no Free Fire normal, não no Free Fire MAX.")
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
        guard !activeMods.contains(where: { $0.sectionName == mod.sectionName }) else {
            endOperation()
            complete(completion, success: false, message: "Já existe uma função ativa neste grupo. Restaure-a antes de escolher outra.")
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
            currentTarget = mod == .fps144 ? localFPSPreferenceName : localTextureTargetName
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
                let localPaths: [String]
                if mod == .fps144 {
                    localPaths = ["Library/Preferences/\(currentTarget)"]
                } else {
                    localPaths = [
                        "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/\(currentTarget)",
                        "Documents/contentcache/Optional/ios/gameassetbundles/\(currentTarget)"
                    ]
                }
                guard let existing = localPaths.compactMap({ resolveRemoteTarget(relativePath: $0, fileName: currentTarget, rootPath: rootPath) }).first else {
                    addLog("Alvo local não encontrado nos caminhos conhecidos para \(currentTarget)")
                    continue
                }
                let relativePath = String(existing.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                addLog("Alvo local encontrado: \(relativePath)")
                rules.append(PatchRule(bundleID: bid, relativePath: relativePath, replacementFilename: (existing as NSString).lastPathComponent, replacementData: modData))
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

        let project = PatchProject(
            id: mod.persistentProjectID,
            name: "MenagerFF_Remote_\(remoteDefinition.id)_v\(remoteDefinition.version)",
            rules: rules
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let receipt = try DevicePatchService.apply(project: project)
                self.addLog("SUCESSO: Injetado em \(rules.count) locais!")
                DispatchQueue.main.async {
                    self.activeReceipts[mod] = receipt
                    self.activeMods.insert(mod)
                    self.statusMessage = self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                    self.endOperation()
                    completion(true, "Injetado com Sucesso!")
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

    func restoreMod(_ mod: ModType, completion: @escaping (Bool, String) -> Void) {
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
            guard let receipt = self.activeReceipts[mod] ?? DevicePatchService.latestReceipt(projectID: mod.persistentProjectID) else {
                self.endOperation()
                self.complete(completion, success: false, message: "Nenhum backup encontrado para essa textura.")
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
                        self.activeMods.remove(mod)
                        self.statusMessage = self.activeMods.isEmpty
                            ? "Pronto para injetar"
                            : self.activeMods.map(\.rawValue).sorted().joined(separator: " + ") + " ATIVO"
                        self.endOperation()
                        completion(true, "\(mod.rawValue) desativada e arquivo original restaurado.")
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

    private func restoreOriginalAfterSessionCheck(completion: @escaping (Bool, String) -> Void) {
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
        guard !activeReceipts.isEmpty else {
            endOperation()
            complete(completion, success: false, message: "Nenhum backup encontrado.")
            return
        }
        let receipts = Array(activeReceipts.values)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard KernelExploit.ensureAccessForRestore() else {
                    self.endOperation()
                    self.complete(completion, success: false, message: "Falha ao reativar o acesso para restauração.")
                    return
                }
                self.prepareLegacyKernelAccessIfNeeded()
                for receipt in receipts {
                    try DevicePatchService.restore(receipt: receipt)
                }
                self.addLog("SUCESSO: Original restaurado")
                DispatchQueue.main.async {
                    self.activeReceipts.removeAll()
                    self.activeMods.removeAll()
                    self.statusMessage = "Original restaurado"
                    self.endOperation()
                    completion(true, "Original restaurado!")
                }
            } catch {
                self.addLog("ERRO: \(error.localizedDescription)")
                self.endOperation()
                self.complete(completion, success: false, message: "Falha ao restaurar.")
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
