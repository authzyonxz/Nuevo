import SwiftUI
import UniformTypeIdentifiers

public struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @State private var importedAssets: [URL] = OnyxImporterService.shared.getImportedAssets()
    @State private var showImporter = false
    @State private var statusMessage: String?

    public init() {}

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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Pronto para injeção no Free Fire")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let url = importedAssets[index]
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
                    case .success(let (meta, _)):
                        importedAssets = OnyxImporterService.shared.getImportedAssets()
                        statusMessage = "Importado com sucesso: \(meta.payload_filename)"
                    case .failure(let err):
                        statusMessage = "Erro ao importar: \(err.localizedDescription)"
                    }
                }
            }
        }
    }
}
