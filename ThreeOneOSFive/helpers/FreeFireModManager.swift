import Foundation
import SwiftUI

enum ModType: String, CaseIterable, Identifiable, Hashable {
    case hsAlto = "HS ALTO"
    case hsPescoco = "HS PESCOÇO"
    case hsPeito = "HS PEITO"
    case hologramaArmas = "HOLOGRAMA ARMAS"
    case texturaAlok = "Textura 1 - Alok"
    case texturaIgnis = "Textura 2 - Ignis"

    var id: String { rawValue }

    /// ID estável usado apenas para reencontrar o journal da função após
    /// encerrar e abrir novamente o IPA.
    var persistentProjectID: UUID {
        switch self {
        case .hsAlto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A01")!
        case .hsPescoco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A02")!
        case .hsPeito: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A03")!
        case .hologramaArmas: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A04")!
        case .texturaAlok: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A05")!
        case .texturaIgnis: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A06")!
        }
    }

    var folderName: String {
        switch self {
        case .hsAlto: return "HS_ALTO"
        case .hsPescoco: return "HS_PESCOCO"
        case .hsPeito: return "HS_PEITO"
        case .hologramaArmas: return "HOLOGRAMA"
        case .texturaAlok: return "TEXTURA_ALOK"
        case .texturaIgnis: return "TEXTURA_IGNIS"
        }
    }

    var subtitle: String {
        switch self {
        case .hsAlto: return "HS Acima da Cabeça do Inimigo."
        case .hsPescoco: return "HS Apenas no Pescoço do Inimigo."
        case .hsPeito: return "HS no Peito do Inimigo."
        case .hologramaArmas: return "Usar Gráfico no Padrão Para Funcionar."
        case .texturaAlok: return "Textura Alok para o arquivo optionalab_avatar_66."
        case .texturaIgnis: return "Textura Ignis para o arquivo optionalab_avatar_68."
        }
    }

    var sectionName: String {
        switch self {
        case .hsAlto, .hsPescoco, .hsPeito:
            return "FUNÇÕES DE AIMBOT"
        case .hologramaArmas:
            return "FUNÇÕES DE HOLOGRAMA"
        case .texturaAlok, .texturaIgnis:
            return "TEXTURAS"
        }
    }
}

class FreeFireModManager: ObservableObject {
    static let shared = FreeFireModManager()

    @Published private(set) var activeMods: Set<ModType> = []
    @Published var statusMessage: String = "Pronto para injetar"
    @Published var debugLogs: String = ""
    @Published private(set) var isProcessing = false

    private let operationLock = NSLock()
    private var operationInFlight = false

    private let targetFileName = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    private let targetHoloName = "shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    private let targetTextureAlokName = "optionalab_avatar_66.CoOEgYl5yYUMEbFNIb8L3onAO6o~3D"
    private let targetTextureIgnisName = "optionalab_avatar_68.mkIcgw~2FuXDgA~2Ftt4a~2FDHdRIIp7g~3D"
    private let supportedBundleIDs: Set<String> = ["com.dts.freefireth", "com.dts.freefiremax"]

    private var activeReceipts: [ModType: PatchTransactionReceipt] = [:]

    init() {
        restorePersistedState()
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
            self.applyModAfterSessionCheck(mod, bundleID: bundleID, completion: completion)
        }
    }

    private func applyModAfterSessionCheck(_ mod: ModType, bundleID: String, completion: @escaping (Bool, String) -> Void) {
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

        let isTexture = (mod == .texturaAlok || mod == .texturaIgnis)
        let isHolo = (mod == .hologramaArmas)
        let currentTarget = mod == .texturaAlok ? targetTextureAlokName : (mod == .texturaIgnis ? targetTextureIgnisName : (isHolo ? targetHoloName : targetFileName))
        let modData: Data?
        if [.hsAlto, .hsPescoco, .hsPeito, .texturaAlok, .texturaIgnis].contains(mod) {
            do {
                modData = try ProtectedModPayloadStore.decrypt(mod)
                addLog("Payload protegido descriptografado em memória: \(mod.rawValue)")
            } catch {
                addLog("ERRO: Payload protegido indisponível (\(mod.rawValue))")
                endOperation()
                complete(completion, success: false, message: "Payload protegido indisponível.")
                return
            }
        } else {
            let modPath = Bundle.main.path(forResource: currentTarget, ofType: nil, inDirectory: "Mods/\(mod.folderName)")
            modData = modPath.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
        }
        guard let modData, !modData.isEmpty else {
            addLog("ERRO: Mod não encontrado na IPA (\(currentTarget))")
            endOperation()
            complete(completion, success: false, message: "Mod não encontrado na IPA.")
            return
        }

        let modSize = modData.count
        addLog("Origem OK: \(modSize) bytes")

        prepareLegacyKernelAccessIfNeeded()

        var rules: [PatchRule] = []
        var resolvedContainers = 0
        if isTexture {
            // A textura deve substituir somente este arquivo e neste caminho.
            // Não há busca global nem fallback para evitar alterar outro asset.
            let requiredRelativePath = "Documents/contentcache/optional/ios/gameassetbundles/\(currentTarget)"
            for bid in bundleIds {
                guard let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid), !rootPath.isEmpty else {
                    addLog("DIAGNÓSTICO: container não resolvido para \(bid)")
                    continue
                }
                resolvedContainers += 1
                let exactPath = (rootPath as NSString).appendingPathComponent(requiredRelativePath)
                guard FileManager.default.fileExists(atPath: exactPath) else {
                    addLog("ERRO: textura não encontrada no caminho exato: \(requiredRelativePath)")
                    continue
                }
                addLog("Textura encontrada no caminho exato: \(requiredRelativePath)")
                rules.append(PatchRule(
                    bundleID: bid,
                    relativePath: requiredRelativePath,
                    replacementFilename: currentTarget,
                    replacementData: modData
                ))
            }
        } else if isHolo {
            // O holograma deve usar este diretório relativo. Quando o arquivo já
            // existe em uma variação do container, usamos a localização real para
            // não criar um destino paralelo que o jogo não lê.
            let requiredDirectory = "Documents/contentcache/optional/ios/gameassetbundles"
            let requiredRelativePath = "\(requiredDirectory)/\(currentTarget)"
            for bid in bundleIds {
                guard let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid),
                      !rootPath.isEmpty else {
                    addLog("DIAGNÓSTICO: container não resolvido para \(bid)")
                    continue
                }
                resolvedContainers += 1
                let candidates = findFilesWithSelectedAccess(named: currentTarget, in: rootPath)
                let normalizedDirectory = "/\(requiredDirectory)/"
                let existingTarget = candidates.first { path in
                    path.replacingOccurrences(of: "\\\\", with: "/")
                        .contains(normalizedDirectory)
                } ?? candidates.first

                guard let existingTarget,
                      existingTarget.hasPrefix(rootPath) else {
                    addLog("ERRO: Holograma não encontrado no container \(bid); nenhuma regra criada")
                    continue
                }

                let relativePath = String(existingTarget.dropFirst(rootPath.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if relativePath != requiredRelativePath {
                    addLog("AVISO: Holograma encontrado em caminho alternativo: \(relativePath)")
                } else {
                    addLog("Holograma encontrado no caminho exigido: \(relativePath)")
                }

                rules.append(PatchRule(
                    bundleID: bid,
                    relativePath: relativePath,
                    replacementFilename: currentTarget,
                    replacementData: modData
                ))
            }
        } else {
            var targetPaths: [String] = []
            for bid in bundleIds {
                if let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid), !rootPath.isEmpty {
                    resolvedContainers += 1
                    addLog("Escaneando container: \(bid)")
                    let found = findFilesWithSelectedAccess(named: currentTarget, in: rootPath)
                    targetPaths.append(contentsOf: found)
                    for p in found {
                        addLog("Alvo encontrado: ...\(p.suffix(40))")
                    }
                }
            }
            if targetPaths.isEmpty {
                addLog("AVISO: Busca global vazia, usando caminhos padrão")
                for bid in bundleIds {
                    if let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid) {
                        let subPath = isHolo ? "optional" : "compulsory"
                        let standardPaths = [
                            "Documents/contentcache/\(subPath)/ios/gameassetbundles/\(currentTarget)",
                            "Documents/ContentCache/\(subPath.capitalized)/ios/gameassetbundles/\(currentTarget)"
                        ]
                        for sp in standardPaths {
                            targetPaths.append((rootPath as NSString).appendingPathComponent(sp))
                        }
                    }
                }
            }

            for fullPath in targetPaths {
                for bid in bundleIds {
                    if let root = ContainerStore.resolveAppContainerPath(bundleID: bid), fullPath.hasPrefix(root) {
                        let relative = String(fullPath.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        rules.append(PatchRule(
                            bundleID: bid,
                            relativePath: relative,
                            replacementFilename: currentTarget,
                            replacementData: modData
                        ))
                    }
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
            name: "MenagerFF_V21_\(mod.folderName)",
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
