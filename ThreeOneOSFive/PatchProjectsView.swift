import SwiftUI
import UniformTypeIdentifiers

public struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @State private var importedAssets: [URL] = OnyxImporterService.shared.getImportedAssets()
    @State private var showImporter = false
    @State private var statusMessage: String?
    
    // Nomes personalizados
    @State private var showNamePrompt = false
    @State private var customNameInput = ""
    @State private var pendingAssetURL: URL?

    public init() {}

    private func deleteAsset(_ url: URL) {
        AssetMetadataService.shared.deleteMetadata(for: url)
        try? FileManager.default.removeItem(at: url)
        importedAssets = OnyxImporterService.shared.getImportedAssets()
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Arquivos .onyx Importados")) {
                    if importedAssets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Nenhum arquivo .onyx importado")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Toque no botão abaixo para importar seus arquivos de patch do app Arquivos ou Filza.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(importedAssets, id: \.self) { url in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AssetMetadataService.shared.getDisplayName(for: url))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteAsset(url)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                                
                                Button {
                                    pendingAssetURL = url
                                    customNameInput = AssetMetadataService.shared.getDisplayName(for: url)
                                    showNamePrompt = true
                                } label: {
                                    Label("Renomear Identificador", systemImage: "pencil")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let url = importedAssets[index]
                                AssetMetadataService.shared.deleteMetadata(for: url)
                                try? FileManager.default.removeItem(at: url)
                            }
                            importedAssets = OnyxImporterService.shared.getImportedAssets()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("Library (.onyx)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showImporter = true
                    }) {
                        Label("Importar", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                DocumentPickerView { url in
                    let result = OnyxImporterService.shared.importOnyxFile(from: url)
                    switch result {
                    case .success(let (meta, destURL)):
                        importedAssets = OnyxImporterService.shared.getImportedAssets()
                        pendingAssetURL = destURL
                        customNameInput = url.deletingPathExtension().lastPathComponent
                        showNamePrompt = true
                    case .failure(let err):
                        statusMessage = "Erro ao importar: \(err.localizedDescription)"
                    }
                }
            }
            .alert("Identificar Pacote", isPresented: $showNamePrompt) {
                TextField("Ex: Hs Pescoço", text: $customNameInput)
                Button("Salvar") {
                    if let url = pendingAssetURL {
                        AssetMetadataService.shared.setDisplayName(customNameInput, for: url)
                        importedAssets = OnyxImporterService.shared.getImportedAssets()
                    }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Dê um nome fácil para identificar este arquivo na hora da injeção.")
            }
        }
    }
}
