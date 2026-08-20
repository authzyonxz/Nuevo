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
    
    private let targetFileName = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    private let targetHoloName = "shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    private let bundleIds = ["com.dts.freefireth", "com.dts.freefiremax"]
    
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
        addLog("Injeção V21: \(mod.rawValue)")
        
        let isHolo = (mod == .hologramaArmas)
        let currentTarget = isHolo ? targetHoloName : targetFileName
        let modPath = Bundle.main.path(forResource: currentTarget, ofType: nil, inDirectory: "Mods/\(mod.folderName)")
        guard let finalModPath = modPath, let modData = try? Data(contentsOf: URL(fileURLWithPath: finalModPath)) else {
            addLog("ERRO: Mod não encontrado na IPA (\(currentTarget))")
            completion(false, "Mod não encontrado na IPA.")
            return
        }
        
        let modSize = modData.count
        addLog("Origem OK: \(modSize) bytes")

        sandbox_elevate_to_root(proc_self())
        
        var targetPaths: [String] = []
        for bid in bundleIds {
            if let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bid), !rootPath.isEmpty {
                addLog("Escaneando container: \(bid)")
                let found = findFiles(named: currentTarget, in: rootPath)
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
            completion(false, "Destino não localizado.")
            return
        }

        let project = PatchProject(name: "MenagerFF_V21_\(mod.folderName)", rules: rules)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let receipt = try DevicePatchService.apply(project: project)
                self.activeReceipt = receipt
                
                self.addLog("SUCESSO: Injetado em \(rules.count) locais!")
                DispatchQueue.main.async {
                    self.activeMod = mod
                    self.statusMessage = "\(mod.rawValue) ATIVO"
                    completion(true, "Injetado com Sucesso!")
                }
            } catch {
                self.addLog("ERRO: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Falha: \(error.localizedDescription)")
                }
            }
        }
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
        addLog("Restaurando original...")
        guard let receipt = activeReceipt else {
            completion(false, "Nenhum backup encontrado.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                sandbox_elevate_to_root(proc_self())
                try DevicePatchService.restore(receipt: receipt)
                self.activeReceipt = nil
                self.addLog("SUCESSO: Original restaurado")
                DispatchQueue.main.async {
                    self.activeMod = nil
                    self.statusMessage = "Original restaurado"
                    completion(true, "Original restaurado!")
                }
            } catch {
                self.addLog("ERRO: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Falha ao restaurar.")
                }
            }
        }
    }
}
