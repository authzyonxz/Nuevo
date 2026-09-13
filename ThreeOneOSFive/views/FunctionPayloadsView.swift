import SwiftUI

struct FunctionPayloadsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage("function.payload.server") private var serverURL = ""
    @State private var enabled: Set<Int> = []
    @State private var projectIDs: [Int: UUID] = [:]
    @State private var isWorking = Set<Int>()
    @State private var alert: String?

    private let slots = Array(1...5)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(AppTheme.accent)
                        TextField("URL do manifest.json", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    Button {
                        connectServer()
                    } label: {
                        Label("Conectar servidor de payloads", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Text("O servidor deve publicar um manifest.json com as funções 1–5 e arquivos .3105.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Payload online")
                }

                Section {
                    ForEach(slots, id: \.self) { slot in
                        functionRow(slot)
                    }
                } header: {
                    Text("Funções")
                } footer: {
                    Text("Ativar baixa o payload da função e aplica. Desativar restaura somente os arquivos dessa função.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Funções")
            .navigationBarTitleDisplayMode(.inline)
            .alert("3105", isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            )) {
                Button("OK", role: .cancel) { alert = nil }
            } message: {
                Text(alert ?? "")
            }
            .onAppear {
                if !serverURL.isEmpty, repositoryStore.sources.isEmpty {
                    _ = repositoryStore.addSource(rawURL: serverURL)
                }
            }
        }
    }

    private func functionRow(_ slot: Int) -> some View {
        let record = packageRecord(for: slot)
        let busy = isWorking.contains(slot)
        return HStack(spacing: 14) {
            Image(systemName: "function")
                .font(.title3.weight(.semibold))
                .foregroundStyle(record == nil ? .secondary : AppTheme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("FUNÇÃO - \(slot)")
                    .font(.headline)
                Text(record?.package.name ?? "Nenhum payload publicado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if busy {
                ProgressView()
            } else {
                Toggle("", isOn: Binding(
                    get: { enabled.contains(slot) },
                    set: { setEnabled($0, slot: slot) }
                ))
                .labelsHidden()
                .disabled(record == nil)
            }
        }
        .contentShape(Rectangle())
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

    private func connectServer() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alert = "Informe a URL HTTPS do manifest.json."
            return
        }
        _ = repositoryStore.addSource(rawURL: trimmed)
        repositoryStore.refreshAll()
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
            alert = "Não existe payload publicado para a FUNÇÃO - \(slot) nesta versão."
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
                projectIDs[slot] = item.id
                enabled.insert(slot)
            } catch let error as LocalizedError {
                enabled.remove(slot)
                alert = error.errorDescription ?? "Não foi possível aplicar o payload."
            } catch {
                enabled.remove(slot)
                alert = "Não foi possível aplicar o payload da função."
            }
        }
    }

    private func deactivate(slot: Int) {
        guard let projectID = projectIDs[slot],
              let item = patchStore.items.first(where: { $0.id == projectID }),
              let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
            enabled.remove(slot)
            alert = "Nenhum patch ativo encontrado para a FUNÇÃO - \(slot)."
            return
        }
        isWorking.insert(slot)
        Task { @MainActor in
            defer { isWorking.remove(slot) }
            do {
                guard await appState.ensureExploitAccess() else {
                    throw PatchPackageError.restoreFailed
                }
                _ = item
                try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                }.value
                enabled.remove(slot)
            } catch let error as LocalizedError {
                enabled.insert(slot)
                alert = error.errorDescription ?? "Não foi possível restaurar a função."
            } catch {
                enabled.insert(slot)
                alert = "Não foi possível restaurar o payload da função."
            }
        }
    }
}
