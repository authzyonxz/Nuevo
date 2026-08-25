import Foundation
import SwiftUI

enum ModType: String, CaseIterable, Identifiable, Hashable {
    case hsAlto = "HS ALTO"
    case hsPescoco = "HS PESCOÇO"
    case hsPeito = "HS PEITO"
    case hologramaArmas = "HOLOGRAMA ARMAS"

    var id: String { rawValue }

    /// ID estável usado para localizar o journal da função depois que o IPA
    /// é encerrado e aberto novamente.
    var persistentProjectID: UUID {
        switch self {
        case .hsAlto: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A01")!
        case .hsPescoco: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A02")!
        case .hsPeito: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A03")!
        case .hologramaArmas: return UUID(uuidString: "E0C7D7B5-7B75-4F5B-8CCB-2B5E5D5F8A04")!
        }
    }

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

    @Published private(set) var activeMods: Set<ModType> = []
    @Published var statusMessage: String = "Pronto para injetar"
    @Published var debugLogs: String = ""
    @Published private(set) var isProcessing = false

    private let operationLock = NSLock()
    private var operationInFlight = false

    private let targetFileName = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    private let targetHoloName = "shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    private let bundleIds = ["com.dts.freefireth", "com.dts.freefiremax"]
    
    private var activeReceipts: [ModType: PatchTransactionReceipt] = [:]

    init() {
        restorePersistedState()
    }

    /// Reconstitui somente o estado das transações ainda aplicadas/preparadas.
    /// O patch permanece no arquivo do app alvo; fechar o IPA não deve restaurar
    /// nada automaticamente. A restauração continua exclusiva de restoreOriginal.
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

    func applyMod(_ mod: ModType, completion: @escaping (Bool, String) -> Void) {
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
            addLog("ERRO: Nenhum destino válido localizado")
            endOperation()
            complete(completion, success: false, message: "Destino não localizado.")
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
        guard !activeReceipts.isEmpty else {
            endOperation()
            complete(completion, success: false, message: "Nenhum backup encontrado.")
            return
        }
        let receipts = Array(activeReceipts.values)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
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
