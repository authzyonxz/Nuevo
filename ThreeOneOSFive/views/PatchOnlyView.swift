import SwiftUI
import UniformTypeIdentifiers

private enum PatchOnlyPickerPolicy {
    static let allowedContentTypes: [UTType] = [
        UTType(filenameExtension: "3105") ?? .data,
        .data
    ]
}

struct PatchOnlyView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @State private var showImporter = false
    @State private var activeProjectID: UUID?
    @State private var workingMessage: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isApplying = false
    @State private var isRestoring = false
    @State private var lastAutoAppliedImportID: UUID?

    private var activeItem: PatchLibraryItem? {
        guard let activeProjectID else { return nil }
        return store.items.first { $0.id == activeProjectID }
    }

    private var activeReceipt: PatchTransactionReceipt? {
        guard let activeProjectID else { return nil }
        return DevicePatchService.latestReceipt(projectID: activeProjectID)
    }

    private var canRestore: Bool {
        activeReceipt != nil && !isApplying && !isRestoring
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    importCard
                    if let activeItem {
                        projectCard(activeItem)
                    }
                    if let workingMessage {
                        ProgressView(workingMessage)
                            .frame(maxWidth: .infinity)
                    }
                    if let statusMessage {
                        messageCard(statusMessage, color: AppTheme.accent)
                    }
                    if let errorMessage {
                        messageCard(errorMessage, color: .red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("3105")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.isBusy || isApplying || isRestoring {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchOnlyPickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: true,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        guard case .success(let urls) = result, let url = urls.first else {
                            return
                        }
                        errorMessage = nil
                        guard url.pathExtension.lowercased() == "3105" else {
                            errorMessage = "Selecione o arquivo de patch com extensão .3105. Uma IPA não é um pacote de patch."
                            return
                        }
                        statusMessage = "Arquivo recebido. Preparando o patch..."
                        store.importPackage(at: url)
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .alert("Falha", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Não foi possível concluir a operação.")
            }
            .onAppear {
                selectInitialProjectIfNeeded()
                consumeExternalImport()
            }
            .onChange(of: draftCoordinator.importRequest?.id) { _ in
                consumeExternalImport()
            }
            .onChange(of: store.lastImportedProjectID) { projectID in
                guard let projectID,
                      projectID != lastAutoAppliedImportID else { return }
                lastAutoAppliedImportID = projectID
                activeProjectID = projectID
                apply(projectID: projectID)
            }
            .patchStorePresentation(store)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox.and.arrow.down.fill")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text("Aplicar patch")
                .font(.title2.weight(.bold))
            Text("Envie um arquivo .3105 para aplicar as alterações. Depois, restaure o original quando quiser desfazer o patch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var importCard: some View {
        VStack(spacing: 12) {
            Button {
                showImporter = true
            } label: {
                Label("Escolher arquivo de patch", systemImage: "arrow.up.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isBusy || isApplying || isRestoring)

            Text("O apply começa automaticamente depois que o arquivo for importado.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func projectCard(_ item: PatchLibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(item.project?.name ?? "Patch selecionado", systemImage: "doc.badge.gearshape")
                .font(.headline)

            if let project = item.project {
                if !project.allBundleIdentifiers.isEmpty {
                    Text(project.allBundleIdentifiers.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(project.rules.count) arquivo(s) e \(project.directories.count) pasta(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if activeReceipt != nil {
                Label("Patch aplicado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Patch pronto para aplicar", systemImage: "circle.dotted")
                    .foregroundStyle(.secondary)
            }

            Button {
                restore()
            } label: {
                Label("Restaurar original", systemImage: "arrow.uturn.backward.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!canRestore)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func messageCard(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func consumeExternalImport() {
        guard let request = draftCoordinator.importRequest else { return }
        draftCoordinator.clearImport()
        store.importPackage(from: request.source)
    }

    private func selectInitialProjectIfNeeded() {
        guard activeProjectID == nil else { return }
        activeProjectID = store.items.first?.id
    }

    private func apply(projectID: UUID) {
        guard !isApplying,
              !isRestoring,
              let item = store.items.first(where: { $0.id == projectID }),
              let baseProject = item.project else { return }

        isApplying = true
        workingMessage = "Aplicando patch..."
        statusMessage = nil
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    isApplying = false
                    workingMessage = nil
                    activeProjectID = projectID
                    statusMessage = "Patch aplicado com sucesso."
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    workingMessage = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restore() {
        guard !isRestoring, let receipt = activeReceipt else { return }
        isRestoring = true
        workingMessage = "Restaurando arquivos originais..."
        statusMessage = nil
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    isRestoring = false
                    workingMessage = nil
                    statusMessage = "Arquivos originais restaurados."
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    workingMessage = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
