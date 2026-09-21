import Foundation
import SwiftUI

struct PatchFunction: Identifiable, Codable, Equatable {
    let id: Int
    var name: String
    var description: String
    var payloadURL: String
    var isPublished: Bool
    var isPaused: Bool
    var isEnabled: Bool
    var lastValidatedAt: Date?
    var projectID: UUID?

    var canToggle: Bool { isPublished && !isPaused && !payloadURL.isEmpty }
    var stateTitle: String {
        if !isPublished { return "Não publicado" }
        if isPaused { return "Pausado" }
        return isEnabled ? "Aplicado" : "Pronto para aplicar"
    }
}

@MainActor
final class PatchFunctionStore: ObservableObject {
    static let storageKey = "patch.functions.v1"

    @Published private(set) var functions: [PatchFunction]
    @Published private(set) var workingIDs = Set<Int>()
    @Published var banner: String?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([PatchFunction].self, from: data),
           saved.count == 5 {
            functions = saved
        } else {
            functions = Self.defaults
            persist()
        }
    }

    func isWorking(_ function: PatchFunction) -> Bool { workingIDs.contains(function.id) }

    func refreshFromManifest() {
        Task {
            guard let manifest = try? await PayloadManifestService.fetch() else { return }
            let remoteByID = Dictionary(uniqueKeysWithValues: manifest.functions.map { ($0.functionId, $0) })
            for index in functions.indices {
                guard let remote = remoteByID[functions[index].id] else { continue }
                functions[index].payloadURL = remote.payloadURL
                functions[index].isPublished = true
                functions[index].isPaused = false
            }
            persist()
        }
    }

    func toggle(_ function: PatchFunction, enabled: Bool) {
        guard let index = functions.firstIndex(where: { $0.id == function.id }) else { return }
        guard functions[index].canToggle else {
            banner = functions[index].isPaused ? "Esta função está pausada." : "Publique um payload .3105 válido antes de ativar."
            return
        }
        guard !workingIDs.contains(function.id) else { return }
        workingIDs.insert(function.id)
        let urlString = functions[index].payloadURL
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                if enabled {
                    let project = try await Self.downloadProject(from: urlString)
                    _ = try DevicePatchService.apply(project: project)
                    await self?.finishToggle(id: function.id, enabled: true, projectID: project.id)
                } else {
                    guard let projectID = function.projectID,
                          let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                        throw PatchPackageError.restoreFailed
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    await self?.finishToggle(id: function.id, enabled: false, projectID: nil)
                }
            } catch let error as PatchPackageError {
                await self?.failToggle(id: function.id, message: error.localizedDescription)
            } catch {
                await self?.failToggle(id: function.id, message: "Não foi possível concluir a operação do patch.")
            }
        }
    }

    func update(_ function: PatchFunction) {
        guard let index = functions.firstIndex(where: { $0.id == function.id }) else { return }
        functions[index] = function
        if !function.isPublished || function.isPaused || function.payloadURL.isEmpty {
            functions[index].isEnabled = false
        }
        persist()
    }

    func removePayload(from function: PatchFunction) {
        guard let index = functions.firstIndex(where: { $0.id == function.id }) else { return }
        functions[index].payloadURL = ""
        functions[index].isPublished = false
        functions[index].isPaused = false
        functions[index].isEnabled = false
        functions[index].lastValidatedAt = nil
        persist()
        banner = "Payload removido de \(function.name)."
    }

    func setPaused(_ paused: Bool, for function: PatchFunction) {
        guard let index = functions.firstIndex(where: { $0.id == function.id }) else { return }
        functions[index].isPaused = paused
        if paused { functions[index].isEnabled = false }
        persist()
    }

    func validatePayload(for function: PatchFunction) {
        guard let index = functions.firstIndex(where: { $0.id == function.id }),
              let url = URL(string: functions[index].payloadURL), url.scheme == "https" else {
            banner = "Use uma URL HTTPS válida para o payload."
            return
        }
        let id = function.id
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                _ = try PatchPackageCodec.inspect(data)
                guard let currentIndex = functions.firstIndex(where: { $0.id == id }) else { return }
                functions[currentIndex].isPublished = true
                functions[currentIndex].isPaused = false
                functions[currentIndex].lastValidatedAt = Date()
                persist()
                banner = "Payload .3105 validado online e publicado."
            } catch {
                banner = "O endereço não contém um pacote .3105 válido."
            }
        }
    }

    private static func downloadProject(from string: String) async throws -> PatchProject {
        guard let url = URL(string: string), url.scheme == "https" else { throw PatchPackageError.invalidImportLink }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw PatchPackageError.remoteImportFailed
        }
        _ = try PatchPackageCodec.inspect(data)
        return try PatchPackageCodec.decode(data, password: nil).project
    }

    private func finishToggle(id: Int, enabled: Bool, projectID: UUID?) {
        workingIDs.remove(id)
        if let index = functions.firstIndex(where: { $0.id == id }) {
            functions[index].isEnabled = enabled
            functions[index].projectID = projectID ?? functions[index].projectID
            if !enabled { functions[index].projectID = nil }
            persist()
        }
        banner = enabled ? "Patch aplicado e original salvo para restauração." : "Original restaurado com sucesso."
    }

    private func failToggle(id: Int, message: String) {
        workingIDs.remove(id)
        banner = message
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(functions) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static let defaults: [PatchFunction] = [
        PatchFunction(id: 1, name: "Aurora", description: "Perfil visual principal", payloadURL: "", isPublished: false, isPaused: false, isEnabled: false, lastValidatedAt: nil, projectID: nil),
        PatchFunction(id: 2, name: "Nexus", description: "Ajustes avançados do sistema", payloadURL: "", isPublished: false, isPaused: false, isEnabled: false, lastValidatedAt: nil, projectID: nil),
        PatchFunction(id: 3, name: "Pulse", description: "Otimização de desempenho", payloadURL: "", isPublished: false, isPaused: false, isEnabled: false, lastValidatedAt: nil, projectID: nil),
        PatchFunction(id: 4, name: "Orbit", description: "Configuração de interface", payloadURL: "", isPublished: false, isPaused: false, isEnabled: false, lastValidatedAt: nil, projectID: nil),
        PatchFunction(id: 5, name: "Vertex", description: "Personalização experimental", payloadURL: "", isPublished: false, isPaused: false, isEnabled: false, lastValidatedAt: nil, projectID: nil)
    ]
}
