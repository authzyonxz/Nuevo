import SwiftUI

struct OnyxInjectView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @State private var selectedGame: GameTarget?
    @State private var showMaxAlert = false
    
    private enum GameTarget: String, CaseIterable, Identifiable {
        case freeFire = "Free Fire"
        case freeFireMax = "Free Fire MAX"
        var id: String { rawValue }
        var bundleID: String {
            self == .freeFire ? "com.dts.freefireth" : "com.dts.freefiremax"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SELECT TARGET")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("CHOOSE YOUR GAME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.onyxSecondaryText)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            Text("ONYX only exposes the two supported Free Fire data containers.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.onyxSecondaryText)
                .padding(.horizontal)
                .padding(.bottom, 40)
            
            // Game Selection Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    GameTargetCard(
                        name: "Free Fire",
                        bundleID: "com.dts.freefireth",
                        icon: "FreeFireLogo",
                        isSelected: selectedGame == .freeFire
                    ) {
                        selectedGame = .freeFire
                    }
                    
                    GameTargetCard(
                        name: "Free Fire MAX",
                        bundleID: "com.dts.freefiremax",
                        icon: "FreeFireLogo", // Usando o mesmo ícone por enquanto
                        isSelected: selectedGame == .freeFireMax
                    ) {
                        showMaxAlert = true
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Bottom Action Bar
            HStack {
                Spacer()
                Button {
                    // Reload logic
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.onyxCardBackground)
                            .frame(width: 50, height: 50)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.onyxBackground)
        .alert("Free Fire MAX", isPresented: $showMaxAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("O suporte ao Free Fire MAX será adicionado em breve.")
        }
        .sheet(item: $selectedGame) { game in
            OnyxPackageSelectionView(game: game)
        }
    }
}

struct GameTargetCard: View {
    let name: String
    let bundleID: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(icon)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Text(bundleID)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.onyxSecondaryText)
            }
            
            Spacer()
            
            Button(action: action) {
                Text("SELECT TARGET")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(25)
        .frame(width: 260, height: 380)
        .background(AppTheme.onyxCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
    }
}

struct OnyxPackageSelectionView: View {
    let game: OnyxInjectView.GameTarget
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("Inject")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(AppTheme.onyxBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Game Profile Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTIVE GAME PROFILE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.onyxSecondaryText)
                            Text(game.rawValue)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.onyxCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    Text("Select an ONYX Package from your imported library")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.onyxSecondaryText)
                    
                    // Package List
                    ForEach(AvatarAssetCatalog.assets) { asset in
                        Button {
                            prepareInjection(asset: asset)
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accent.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(asset.sourceFilename).onyx")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("588 KB · PROTECTED")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.onyxSecondaryText)
                                }
                                
                                Spacer()
                                
                                Circle()
                                    .stroke(AppTheme.onyxSecondaryText, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                            .padding()
                            .background(AppTheme.onyxCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(AppTheme.onyxBackground)
        }
    }
    
    private func prepareInjection(asset: AvatarAsset) {
        guard let draft = AvatarAssetCatalog.makeFreeFireDraft(selectedAssets: [asset]) else { return }
        dismiss()
        draftCoordinator.present(draft)
    }
}

