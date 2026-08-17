import SwiftUI

struct FreeFireTargetSelectionView: View {
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @State private var selectedGame: GameTarget = .freeFire
    @State private var selectedAssetID: String?
    @State private var showMaxAlert = false
    @State private var showMissingAssetAlert = false

    private enum GameTarget: String, CaseIterable, Identifiable {
        case freeFire = "Free Fire"
        case freeFireMax = "Free Fire MAX"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                gameSelectionSection

                if selectedGame == .freeFire {
                    Section {
                        ForEach(AvatarAssetCatalog.assets) { asset in
                            Button {
                                selectedAssetID = asset.id
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedAssetID == asset.id
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .foregroundStyle(selectedAssetID == asset.id ? .blue : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(asset.displayName)
                                            .font(.body.weight(.semibold))
                                        Text("avatar/\(asset.sourceFilename)")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                        Text("SHA-256: \(asset.sha256.prefix(12))…")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Assets de avatar")
                    } footer: {
                        Text("Escolha o arquivo que será substituído automaticamente dentro da pasta ContentCache/compulsory/gameassetbundle/avatar.")
                    }

                    Section {
                        Button {
                            prepareInjection()
                        } label: {
                            Label("Preparar injeção", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedAssetID == nil)
                    }
                } else {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Em breve")
                                .font(.headline)
                            Text("O suporte ao Free Fire MAX será adicionado em uma atualização futura.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Injetar")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Free Fire MAX", isPresented: $showMaxAlert) {
                Button("OK", role: .cancel) {
                    selectedGame = .freeFire
                }
            } message: {
                Text("Em breve. Por enquanto, selecione Free Fire.")
            }
            .alert("Asset indisponível", isPresented: $showMissingAssetAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("O arquivo de avatar não foi localizado nos recursos incluídos nesta build.")
            }
        }
    }

    private var gameSelectionSection: some View {
        Section {
            ForEach(GameTarget.allCases) { game in
                Button {
                    if game == .freeFireMax {
                        showMaxAlert = true
                    } else {
                        selectedGame = game
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image("FreeFireLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.rawValue)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if game == .freeFire {
                                Text("com.dts.freefireth")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Em breve")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Image(systemName: game == selectedGame ? "checkmark.circle.fill" : "chevron.right")
                            .foregroundStyle(game == selectedGame ? .blue : .secondary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Selecionar jogo")
        } footer: {
            Text(selectedGame == .freeFire
                 ? "Alvo: com.dts.freefireth"
                 : "A versão MAX ainda não está disponível.")
        }
    }

    private func prepareInjection() {
        guard let selectedAssetID,
              let asset = AvatarAssetCatalog.assets.first(where: { $0.id == selectedAssetID }),
              let draft = AvatarAssetCatalog.makeFreeFireDraft(selectedAssets: [asset]) else {
            showMissingAssetAlert = true
            return
        }
        draftCoordinator.present(draft)
    }
}
