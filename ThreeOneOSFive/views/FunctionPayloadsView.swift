import SwiftUI

struct FunctionPayloadsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage("function.payload.server") private var serverURL = "https://keyauthv2.org/manifest.json"
    @State private var enabled: Set<Int> = []
    @State private var isWorking = Set<Int>()
    @State private var alertTitle = "3105"
    @State private var alertMessage: String?

    private let slots = Array(1...5)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(slots, id: \.self) { slot in
                        functionRow(slot)
                    }
                } header: {
                    Text("Funções")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Funções")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                if serverURL.isEmpty {
                    serverURL = "https://keyauthv2.org/manifest.json"
                }
                if !repositoryStore.sources.contains(where: { $0.manifestURL.absoluteString == serverURL }) {
                    _ = repositoryStore.addSource(rawURL: serverURL)
                }
            }
        }
    }

    private func functionRow(_ slot: Int) -> some View {
        let record = packageRecord(for: slot)
        let busy = isWorking.contains(slot)
        let metadata = functionMetadata(for: slot)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(metadata.name)
                    .font(.headline)
                Text(metadata.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if busy {
                ProgressView()
            } else {
                Toggle("", isOn: Binding(
                    get: { isActive(slot) },
                    set: { setEnabled($0, slot: slot) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
                .disabled(record == nil && !isActive(slot))
            }
        }
        .contentShape(Rectangle())
    }

    private func functionMetadata(for slot: Int) -> (name: String, description: String) {
        switch slot {
        case 1:
            return ("HS Alto", "HS acima da cabeça do inimigo")
        case 2:
            return ("HS Pescoço", "HS no pescoço do inimigo")
        case 3:
            return ("HS Alto + Pescoço", "HS acima da cabeça e no pescoço do inimigo")
        case 4:
            return ("ESP", "ESP: linha, caixa, vida e nome")
        default:
            return ("Função 5", "Payload adicional configurado no servidor")
        }
    }

    private func packageRecord(for slot: Int) -> RepositoryPackageRecord? {
        let key = "function-\(slot)"
        return repositoryStore.packages.first {
            $0.package.kind == .patch && (
                $0.package.category?.lowercased() == key
                    || $0.package.tags.contains(where: { $0.lowercased() == key })
            )
        }
    }

    private func storedProjectID(for slot: Int) -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: "function.project.\(slot)") else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    private func isActive(_ slot: Int) -> Bool {
        if enabled.contains(slot) { return true }
        guard let projectID = storedProjectID(for: slot),
              DevicePatchService.latestReceipt(projectID: projectID) != nil else {
            return false
        }
        return true
    }

    private func setEnabled(_ value: Bool, slot: Int) {
        guard !isWorking.contains(slot) else { return }
        if value {
            activate(slot: slot)
        } else {
            deactivate(slot: slot)
        }
    }

    private func activate(slot: Int) {
        guard let record = packageRecord(for: slot) else {
            presentFailure("Não existe payload publicado para esta função nesta versão.")
            return
        }
        isWorking.insert(slot)
        Task { @MainActor in
            defer { isWorking.remove(slot) }
            do {
                let data = try await PackageRepositoryNetworkClient.download(record.package)
                let summary = try PatchPackageCodec.inspect(data)
                guard !summary.isPasswordProtected else {
                    throw PatchPackageError.invalidPasswordOrCorruptedPackage
                }
                guard patchStore.importPackage(data: data, password: nil) else {
                    throw PatchPackageError.remoteImportFailed
                }
                while patchStore.isBusy {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                patchStore.reload()
                guard let item = patchStore.items.first(where: { $0.id == summary.packageID }) else {
                    throw PatchPackageError.invalidProject
                }
                guard await appState.ensureExploitAccess() else {
                    throw PatchPackageError.applyFailed
                }
                guard let project = item.project else {
                    throw PatchPackageError.invalidProject
                }
                _ = try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.apply(project: project)
                }.value
                UserDefaults.standard.set(item.id.uuidString, forKey: "function.project.\(slot)")
                enabled.insert(slot)
                presentSuccess("Injetado com sucesso")
            } catch let error as LocalizedError {
                enabled.remove(slot)
                presentFailure(error.errorDescription ?? "Não foi possível aplicar o payload.")
            } catch {
                enabled.remove(slot)
                presentFailure("Não foi possível aplicar o payload da função.")
            }
        }
    }

    private func deactivate(slot: Int) {
        guard let projectID = storedProjectID(for: slot),
              let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
            enabled.remove(slot)
            presentFailure("Nenhum patch ativo encontrado para esta função.")
            return
        }
        isWorking.insert(slot)
        Task { @MainActor in
            defer { isWorking.remove(slot) }
            do {
                guard await appState.ensureExploitAccess() else {
                    throw PatchPackageError.restoreFailed
                }
                try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                }.value
                enabled.remove(slot)
                UserDefaults.standard.removeObject(forKey: "function.project.\(slot)")
                presentSuccess("Restaurado com sucesso")
            } catch let error as LocalizedError {
                enabled.insert(slot)
                presentFailure(error.errorDescription ?? "Não foi possível restaurar a função.")
            } catch {
                enabled.insert(slot)
                presentFailure("Não foi possível restaurar o payload da função.")
            }
        }
    }

    private func presentSuccess(_ message: String) {
        alertTitle = "Sucesso"
        alertMessage = message
    }

    private func presentFailure(_ message: String) {
        alertTitle = "Falha"
        alertMessage = message
    }
}
