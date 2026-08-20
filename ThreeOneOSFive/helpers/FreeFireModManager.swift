import Foundation
import SwiftUI

enum ModType: String, CaseIterable, Identifiable {
    case hsAlto = "HS ALTO"
    case hsPescoco = "HS PESCOÇO"
    case hsPeito = "HS PEITO"
    case hologramaArmas = "HOLOGRAMA ARMAS"

    var id: String { rawValue }

    var folderName: String {
        switch self {
        case .hsAlto: return "HS_ALTO"
        case .hsPescoco: return "HS_PESCOCO"
        case .hsPeito: return "HS_PEITO"
        case .hologramaArmas: return "HOLOGRAMA"
        }
    }
    
    var subtitle: String {
        switch self {
        case .hsAlto: return "HS Acima da Cabeça do Inimigo."
        case .hsPescoco: return "HS Apenas no Pescoço do Inimigo."
        case .hsPeito: return "HS no Peito do Inimigo."
        case .hologramaArmas: return "Usar Gráfico no Padrão Para Funcionar."
        }
    }
    
    var sectionName: String {
        switch self {
        case .hsAlto, .hsPescoco, .hsPeito:
            return "FUNÇÕES DE AIMBOT"
        case .hologramaArmas:
            return "FUNÇÕES DE HOLOGRAMA"
        }
    }
}

class FreeFireModManager: ObservableObject {
    static let shared = FreeFireModManager()

    @Published var activeMod: ModType? = nil
    @Published var statusMessage: String = "Pronto para injetar"
    @Published var debugLogs: String = ""
    @Published private(set) var isProcessing = false

    private let operationLock = NSLock()
    private var operationInFlight = false

    private let targetFileName = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    private let targetHoloName = "shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    private let knownBundleIds = ["com.dts.freefireth", "com.dts.freefiremax"]
    private let resolverRevision = "bundle-resolver-2026.08.20.03"
    
    private var activeReceipt: PatchTransactionReceipt?

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: Date())
            self.debugLogs += "[\(time)] \(msg)\n"
            log(msg)
        }
    }

    func applyMod(_ mod: ModType, completion: @escaping (Bool, String) -> Void) {
        addLog("Resolver revision: \(resolverRevision)")
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
        guard activeMod == nil else {
            endOperation()
            complete(completion, success: false, message: "Restaure a função ativa antes de aplicar outra.")
            return
        }

        addLog("Injeção V21: \(mod.rawValue)")
        
        let isHolo = (mod == .hologramaArmas)
        let currentTarget = isHolo ? targetHoloName : targetFileName
        let modPath = Bundle.main.path(forResource: currentTarget, ofType: nil, inDirectory: "Mods/\(mod.folderName)")
        guard let finalModPath = modPath, let modData = try? Data(contentsOf: URL(fileURLWithPath: finalModPath)) else {
            addLog("ERRO: Mod não encontrado na IPA (\(currentTarget))")
            endOperation()
            complete(completion, success: false, message: "Mod não encontrado na IPA.")
            return
        }
        
        let modSize = modData.count
        addLog("Origem OK: \(modSize) bytes")

        prepareLegacyKernelAccessIfNeeded()

        let bundleIds = discoveredFreeFireBundleIDs()
        guard !bundleIds.isEmpty else {
            addLog("ERRO: Free Fire não localizado entre os apps instalados")
            endOperation()
            complete(completion, success: false, message: "Free Fire não localizado. Abra o jogo uma vez e tente novamente.")
            return
        }
        addLog("Bundles candidatos: \(bundleIds.joined(separator: ", "))")

        var targetPaths: [String] = []
        for bid in bundleIds {
            if let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid), !rootPath.isEmpty {
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

        var rules: [PatchRule] = []
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
        
        if rules.isEmpty {
            addLog("ERRO: Nenhum destino válido localizado nos bundles: \(bundleIds.joined(separator: ", "))")
            endOperation()
            complete(completion, success: false, message: "Arquivo-alvo não localizado no Free Fire. Abra o jogo e aguarde o download dos recursos antes de ativar.")
            return
        }

        let project = PatchProject(name: "MenagerFF_V21_\(mod.folderName)", rules: rules)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let receipt = try DevicePatchService.apply(project: project)
                self.addLog("SUCESSO: Injetado em \(rules.count) locais!")
                DispatchQueue.main.async {
                    self.activeReceipt = receipt
                    self.activeMod = mod
                    self.statusMessage = "\(mod.rawValue) ATIVO"
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

    private func discoveredFreeFireBundleIDs() -> [String] {
        var ids: [String] = []
        var apps: [InstalledApp] = []
        apps.append(contentsOf: ContainerStore.installedAppsFromAPI())
        apps.append(contentsOf: ContainerStore.installedAppsFromMCM())
        apps.append(contentsOf: ContainerStore.containersFromFilesystem())

        // Try the documented IDs directly first. They are candidates only;
        // resolveAppContainerPath must confirm an actual installed container.
        ids.append(contentsOf: knownBundleIds)

        for app in apps {
            let normalizedName = app.displayName
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: " ", with: "")
            let looksLikeFreeFire = normalizedName.contains("freefire") ||
                app.bundleID.lowercased().hasPrefix("com.dts.freefire")
            if looksLikeFreeFire {
                ids.append(app.bundleID)
            }
        }

        var unique: [String] = []
        var seen = Set<String>()
        for id in ids where seen.insert(id).inserted {
            unique.append(id)
        }
        return unique
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

    func restoreOriginal(completion: @escaping (Bool, String) -> Void) {
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
        guard let receipt = activeReceipt else {
            endOperation()
            complete(completion, success: false, message: "Nenhum backup encontrado.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.prepareLegacyKernelAccessIfNeeded()
                try DevicePatchService.restore(receipt: receipt)
                self.addLog("SUCESSO: Original restaurado")
                DispatchQueue.main.async {
                    self.activeReceipt = nil
                    self.activeMod = nil
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
