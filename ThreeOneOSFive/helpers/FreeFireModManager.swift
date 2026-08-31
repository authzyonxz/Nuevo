import SwiftUI

struct ImportedFunction: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let filename: String
    let data: Data
    let targetRelativePath: String

    var isCacheResource: Bool { filename == "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D" }
    var isAvatarResource: Bool { filename == "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D" }
}

final class FreeFireModManager: ObservableObject {
    static let shared = FreeFireModManager()

    @Published private(set) var importedFunctions: [ImportedFunction] = []
    @Published private(set) var activeFunctionIDs: Set<UUID> = []
    @Published var statusMessage: String = "Nenhuma função importada"
    @Published var debugLogs: String = ""
    @Published private(set) var isProcessing = false

    static let maximumImportedFunctions = 8
    static let cacheFilename = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    static let avatarFilename = "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
    static let compulsoryDirectory = "Documents/contentcache/compulsory/ios/gameassetbundles"
    static let avatarDirectory = compulsoryDirectory + "/avatar"

    private let supportedBundleIDs: Set<String> = ["com.dts.freefireth", "com.dts.freefiremax"]
    private let operationLock = NSLock()
    private var operationInFlight = false
    private var activeReceipts: [UUID: PatchTransactionReceipt] = [:]
    private let persistenceKey = "MenagerFF.importedFunctions.v1"

    init() {
        loadImportedFunctions()
        restorePersistedState()
    }

    var canImportMore: Bool { importedFunctions.count < Self.maximumImportedFunctions }

    func importFunction(name: String, filename: String, data: Data) -> (Bool, String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return (false, "Dê um nome para a função.") }
        guard data.isEmpty == false else { return (false, "O arquivo importado está vazio.") }
        guard canImportMore else { return (false, "Você já atingiu o limite de 8 funções importadas.") }
        guard let target = targetPath(for: filename) else {
            return (false, "Arquivo não suportado. Importe cache_res ou assetindexer com o nome original.")
        }
        guard !importedFunctions.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else {
            return (false, "Já existe uma função com esse nome.")
        }

        let function = ImportedFunction(
            id: UUID(),
            name: cleanName,
            filename: filename,
            data: data,
            targetRelativePath: target
        )
        importedFunctions.append(function)
        saveImportedFunctions()
        addLog("Função importada: \(cleanName) → \(target)")
        updateStatus()
        return (true, "Função importada com sucesso.")
    }

    func removeFunction(_ function: ImportedFunction) -> (Bool, String) {
        guard !activeFunctionIDs.contains(function.id) else {
            return (false, "Desative a função antes de removê-la.")
        }
        importedFunctions.removeAll { $0.id == function.id }
        saveImportedFunctions()
        updateStatus()
        return (true, "Função removida.")
    }

    func isActive(_ function: ImportedFunction) -> Bool {
        activeFunctionIDs.contains(function.id)
    }

    func activate(_ function: ImportedFunction, bundleID: String, completion: @escaping (Bool, String) -> Void) {
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
            self.activateAfterSessionCheck(function, bundleID: bundleID, completion: completion)
        }
    }

    func deactivate(_ function: ImportedFunction, completion: @escaping (Bool, String) -> Void) {
        LicenseManager.shared.recheckSecureSession { [weak self] valid, message in
            guard let self else { return }
            guard valid else {
                self.complete(completion, success: false, message: message ?? "Sessão expirada. Valide a key novamente.")
                return
            }
            self.restore(function, completion: completion)
        }
    }

    private func activateAfterSessionCheck(_ function: ImportedFunction, bundleID: String, completion: @escaping (Bool, String) -> Void) {
        guard LicenseManager.shared.isAuthorized else {
            complete(completion, success: false, message: "Key ativa necessária.")
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
        guard !activeFunctionIDs.contains(function.id) else {
            endOperation()
            complete(completion, success: false, message: "Essa função já está ativa.")
            return
        }
        guard !activeFunctionIDs.contains(where: { id in
            importedFunctions.first(where: { $0.id == id })?.targetRelativePath == function.targetRelativePath
        }) else {
            endOperation()
            complete(completion, success: false, message: "Já existe uma função ativa para esse caminho. Desative-a antes de continuar.")
            return
        }

        prepareLegacyKernelAccessIfNeeded()
        guard let rootPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID), !rootPath.isEmpty else {
            endOperation()
            complete(completion, success: false, message: "Container do aplicativo não localizado.")
            return
        }

        let targetPaths = resolveTargetPaths(function, in: rootPath)
        guard !targetPaths.isEmpty else {
            addLog("ERRO: caminho não encontrado para \(function.filename)")
            endOperation()
            complete(completion, success: false, message: "Caminho-alvo não localizado no container.")
            return
        }

        let rules = targetPaths.map { path in
            PatchRule(bundleID: bundleID, relativePath: path, replacementFilename: function.filename, replacementData: function.data)
        }
        let project = PatchProject(id: function.id, name: "MenagerFF_\(function.name)", rules: rules)
        addLog("Ativando \(function.name) em \(rules.count) caminho(s)")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let receipt = try DevicePatchService.apply(project: project)
                DispatchQueue.main.async {
                    self.activeReceipts[function.id] = receipt
                    self.activeFunctionIDs.insert(function.id)
                    self.updateStatus()
                    self.endOperation()
                    self.addLog("SUCESSO: \(function.name) ativada")
                    completion(true, "Função ativada com sucesso.")
                }
            } catch {
                self.addLog("ERRO: \(error.localizedDescription)")
                self.endOperation()
                self.complete(completion, success: false, message: "Falha ao ativar: \(error.localizedDescription)")
            }
        }
    }

    private func restore(_ function: ImportedFunction, completion: @escaping (Bool, String) -> Void) {
        guard beginOperation() else {
            complete(completion, success: false, message: "Outra operação já está em andamento.")
            return
        }
        guard KernelExploit.currentAccessPath != .unsupported else {
            endOperation()
            complete(completion, success: false, message: "Esta versão/build do iOS não é suportada.")
            return
        }
        guard let receipt = activeReceipts[function.id] ?? DevicePatchService.latestReceipt(projectID: function.id) else {
            endOperation()
            complete(completion, success: false, message: "Nenhum backup encontrado para essa função.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard KernelExploit.ensureAccessForRestore() else { throw PatchPackageError.restoreFailed }
                self.prepareLegacyKernelAccessIfNeeded()
                try DevicePatchService.restore(receipt: receipt)
                DispatchQueue.main.async {
                    self.activeReceipts.removeValue(forKey: function.id)
                    self.activeFunctionIDs.remove(function.id)
                    self.updateStatus()
                    self.endOperation()
                    self.addLog("SUCESSO: \(function.name) desativada e original restaurado")
                    completion(true, "Função desativada e original restaurado.")
                }
            } catch {
                self.endOperation()
                self.complete(completion, success: false, message: "Falha ao restaurar o original.")
            }
        }
    }

    private func targetPath(for filename: String) -> String? {
        switch filename {
        case Self.cacheFilename: return Self.compulsoryDirectory + "/" + Self.cacheFilename
        case Self.avatarFilename: return Self.avatarDirectory + "/" + Self.avatarFilename
        default: return nil
        }
    }

    private func resolveTargetPaths(_ function: ImportedFunction, in rootPath: String) -> [String] {
        let fm = FileManager.default
        let exact = (rootPath as NSString).appendingPathComponent(function.targetRelativePath)
        if fm.fileExists(atPath: exact) { return [function.targetRelativePath] }

        let found = findFilesWithSelectedAccess(named: function.filename, in: rootPath)
            .filter { $0.hasPrefix(rootPath) }
            .map { String($0.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        if !found.isEmpty { return found }

        // Mantém o destino canônico para containers que ainda não materializaram o arquivo.
        return [function.targetRelativePath]
    }

    private func findFilesWithSelectedAccess(named name: String, in directory: String) -> [String] {
        if KernelExploit.currentAccessPath == .badQuery {
            let handle = ContainerStore.grantContainerAccess(directory)
            guard handle >= 0 else { return [] }
            defer { bad_query_release(handle) }
        }
        var results: [String] = []
        let url = URL(fileURLWithPath: directory)
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent == name {
                results.append(fileURL.path)
            }
        }
        return results
    }

    private func loadImportedFunctions() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([ImportedFunction].self, from: data) else { return }
        importedFunctions = Array(decoded.prefix(Self.maximumImportedFunctions))
    }

    private func saveImportedFunctions() {
        guard let data = try? JSONEncoder().encode(importedFunctions) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func restorePersistedState() {
        for function in importedFunctions {
            if let receipt = DevicePatchService.latestReceipt(projectID: function.id) {
                activeReceipts[function.id] = receipt
                activeFunctionIDs.insert(function.id)
            }
        }
        updateStatus()
    }

    private func updateStatus() {
        if importedFunctions.isEmpty {
            statusMessage = "Nenhuma função importada"
        } else if activeFunctionIDs.isEmpty {
            statusMessage = "\(importedFunctions.count) função(ões) pronta(s)"
        } else {
            statusMessage = "\(activeFunctionIDs.count) função(ões) ativa(s)"
        }
    }

    func addLog(_ msg: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
            self.debugLogs += "[\(formatter.string(from: Date()))] \(msg)\n"
            log(msg)
        }
    }

    private func beginOperation() -> Bool {
        operationLock.lock(); defer { operationLock.unlock() }
        guard !operationInFlight else { return false }
        operationInFlight = true
        DispatchQueue.main.async { self.isProcessing = true }
        return true
    }

    private func endOperation() {
        operationLock.lock(); operationInFlight = false; operationLock.unlock()
        DispatchQueue.main.async { self.isProcessing = false }
    }

    private func complete(_ completion: @escaping (Bool, String) -> Void, success: Bool, message: String) {
        DispatchQueue.main.async { completion(success, message) }
    }

    private func prepareLegacyKernelAccessIfNeeded() {
        guard KernelExploit.currentAccessPath == .kernelOffsets, KernelExploit.kernelAccessActive else { return }
        let selfProc = proc_self(); guard selfProc != 0 else { return }
        _ = sandbox_elevate_to_root(selfProc)
    }
}
