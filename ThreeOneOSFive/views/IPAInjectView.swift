import SwiftUI

struct IPAInjectView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @State private var selectedGame: GameTarget?
    @State private var showMaxAlert = false
    
    enum GameTarget: String, CaseIterable, Identifiable {
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
                        .foregroundStyle(AppTheme.ipaSecondaryText)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            Text("IPA only exposes the two supported Free Fire data containers.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.ipaSecondaryText)
                .padding(.horizontal)
                .padding(.bottom, 40)
            
            // Game Selection Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    GameTargetCard(
                        name: "Free Fire",
                        bundleID: "com.dts.freefireth",
                        icon: "FreeFireLogo",
                        isSelected: selectedGame == .freeFire,
                        badge: nil
                    ) {
                        selectedGame = .freeFire
                    }
                    
                    GameTargetCard(
                        name: "Free Fire MAX",
                        bundleID: "com.dts.freefiremax",
                        icon: "FreeFireLogo",
                        isSelected: selectedGame == .freeFireMax,
                        badge: "EM BREVE"
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
                            .fill(AppTheme.ipaCardBackground)
                            .frame(width: 50, height: 50)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.ipaBackground)
        .alert("Free Fire MAX", isPresented: $showMaxAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("O suporte ao Free Fire MAX estará disponível em breve.")
        }
        .sheet(item: $selectedGame) { game in
            IPAPackageSelectionView(game: game)
        }
    }
}

struct GameTargetCard: View {
    let name: String
    let bundleID: String
    let icon: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Text(bundleID)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.ipaSecondaryText)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(badge != nil ? "EM BREVE" : "SELECT TARGET")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(badge != nil ? .orange : AppTheme.accent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background((badge != nil ? Color.orange : AppTheme.accent).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(25)
        .frame(width: 260, height: 380)
        .background(AppTheme.ipaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
    }
}

struct IPAPackageSelectionView: View {
    let game: IPAInjectView.GameTarget
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
            .background(AppTheme.ipaBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Game Profile Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTIVE GAME PROFILE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.ipaSecondaryText)
                            Text(game.rawValue)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .background(AppTheme.ipaCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Available Asset Packages
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AVAILABLE AVATAR PACKAGES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.ipaSecondaryText)
                        
                        ForEach(AvatarAssetCatalog.assets) { asset in
                            AvatarAssetRow(asset: asset)
                        }
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.ipaBackground.ignoresSafeArea())
    }
}

struct AvatarAssetRow: View {
    let asset: AvatarAsset
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @State private var isApplying = false
    
    var isSelected: Bool {
        draftCoordinator.selectedAssets.contains(asset)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.ipaCardBackground)
                    .frame(width: 50, height: 50)
                Image(systemName: "cube.box.fill")
                    .foregroundStyle(AppTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(asset.resourceFolder)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.ipaSecondaryText)
            }
            
            Spacer()
            
            Button {
                draftCoordinator.toggleAsset(asset)
            } label: {
                Text(isSelected ? "ATIVADO" : "SELECIONAR")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(isSelected ? AppTheme.accent : AppTheme.ipaCardBackground)
                    .foregroundStyle(isSelected ? .black : .white)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(AppTheme.ipaCardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
