import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedTab: Int = 0
    @State private var showKeyGate = false
    @State private var didCheckEntry = false

    var body: some View {
        ZStack {
            MainTabView(selectedTab: $selectedTab)

            if showKeyGate {
                KeyGateOverlay(isPresented: $showKeyGate)
                    .environmentObject(licenseManager)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            validateEntryKey()
        }
        .onChange(of: licenseManager.isAuthorized) { authorized in
            if !authorized && didCheckEntry {
                withAnimation(.easeOut(duration: 0.2)) {
                    showKeyGate = true
                }
            }
        }
    }

    private func validateEntryKey() {
        guard !didCheckEntry else { return }
        didCheckEntry = true
        showKeyGate = true

        guard let savedKey = licenseManager.loadSavedKey(), !savedKey.isEmpty else {
            return
        }

        // A API é consultada somente ao entrar no app, usando a mesma
        // rotina protegida e o mesmo payload já existente.
        licenseManager.validateKey(savedKey) { success, _ in
            withAnimation(.easeOut(duration: 0.2)) {
                showKeyGate = !success
            }
        }
    }
}

// MARK: - Shared visual pieces
private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accentBright, AppTheme.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .shadow(color: AppTheme.accent.opacity(0.28), radius: 14, y: 6)
        .accessibilityHidden(true)
    }
}

private struct SectionHeading: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(AppTheme.accentBright)
            Text(title)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

private struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.11))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 1))
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 42, height: 42)
                .background(AppTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct RedActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [AppTheme.accentBright, AppTheme.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Entry Key Gate
struct KeyGateOverlay: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @Binding var isPresented: Bool
    @State private var inputKey = ""
    @State private var message = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, AppTheme.accentDeep.opacity(0.72), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 100, y: -220)

            VStack(spacing: 0) {
                BrandMark()
                    .padding(.bottom, 18)

                Text("MENAGERFF")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white)

                Text("ATIVAÇÃO SEGURA")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.accentBright)
                    .padding(.top, 5)
                    .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 8) {
                    Text("CHAVE DE ACESSO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(AppTheme.secondaryText)

                    SecureField("Digite sua chave", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(AppTheme.accentBright)
                        .padding(.horizontal, 15)
                        .frame(height: 45)
                        .background(AppTheme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        )
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.accentBright)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }

                HStack(spacing: 9) {
                    Button(action: validate) {
                        HStack(spacing: 7) {
                            if licenseManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.72)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("ENTRAR")
                            }
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 43)
                    }
                    .buttonStyle(RedActionButtonStyle())
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                    Button {
                        guard let pasted = UIPasteboard.general.string else { return }
                        inputKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 48, height: 43)
                            .background(AppTheme.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(AppTheme.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(licenseManager.isLoading)
                    .accessibilityLabel("Colar chave")
                }
                .padding(.top, 18)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelElevated, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.75), radius: 32, x: 0, y: 18)
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }

    private func validate() {
        let key = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        message = ""
        licenseManager.validateKey(key) { success, error in
            if success {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPresented = false
                }
            } else {
                message = error ?? "Key inválida ou expirada."
            }
        }
    }
}

// MARK: - Login View (MenagerFF)
struct LoginView: View {
    @Binding var inputKey: String
    var timeRemaining: Int
    var onLogin: () -> Void
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, AppTheme.accentDeep.opacity(0.65), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    BrandMark()
                        .padding(.bottom, 18)

                    Text("MENAGERFF")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white)
                    Text("ACESSO AO PAINEL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(AppTheme.accentBright)
                        .padding(.top, 5)
                        .padding(.bottom, 22)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHAVE DE ACESSO")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(AppTheme.secondaryText)
                        SecureField("Digite sua chave", text: $inputKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.password)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .tint(AppTheme.accentBright)
                            .padding(.horizontal, 15)
                            .frame(height: 45)
                            .background(AppTheme.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(AppTheme.hairline, lineWidth: 1)
                            )
                            .onSubmit(onLogin)
                    }

                    if let err = licenseManager.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppTheme.accentBright)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }

                    HStack(spacing: 9) {
                        Button(action: onLogin) {
                            HStack(spacing: 7) {
                                if licenseManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.72)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("ENTRAR")
                                }
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 43)
                        }
                        .buttonStyle(RedActionButtonStyle())
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                        Button {
                            guard let pasted = UIPasteboard.general.string else { return }
                            inputKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        } label: {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 48, height: 43)
                                .background(AppTheme.fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(AppTheme.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(licenseManager.isLoading)
                        .accessibilityLabel("Colar chave")
                    }
                    .padding(.top, 18)

                    Text("Fechamento automático em \(timeRemaining) segundos")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .padding(.top, 15)
                }
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [AppTheme.panelElevated, AppTheme.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.75), radius: 32, x: 0, y: 18)
                .frame(maxWidth: 330)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.pageBackground
                .ignoresSafeArea()

            Group {
                if selectedTab == 0 {
                    HomeView()
                } else if selectedTab == 1 {
                    TexturesView()
                } else {
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                TabButton(index: 0, icon: "square.grid.2x2.fill", title: "FUNÇÕES", selectedTab: $selectedTab)
                TabButton(index: 1, icon: "paintpalette.fill", title: "TEXTURAS", selectedTab: $selectedTab)
                TabButton(index: 2, icon: "person.crop.circle", title: "CONFIG", selectedTab: $selectedTab)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelElevated, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.65), radius: 20, y: 8)
            .padding(.bottom, 15)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct TabButton: View {
    let index: Int
    let icon: String
    let title: String
    @Binding var selectedTab: Int

    var isSelected: Bool { selectedTab == index }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
                Capsule()
                    .fill(isSelected ? AppTheme.accentBright : Color.clear)
                    .frame(width: 18, height: 2)
            }
            .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.tertiaryText)
            .frame(width: 88, height: 52)
            .background(isSelected ? AppTheme.accent.opacity(0.15) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home View
private enum GameChoice: String, CaseIterable, Identifiable {
    case freeFire = "Free Fire"
    case freeFireMax = "Free Fire Max"

    var id: String { rawValue }
    var logoName: String {
        switch self {
        case .freeFire: return "FreeFireLogo"
        case .freeFireMax: return "FreeFireMaxLogo"
        }
    }

    var bundleID: String {
        switch self {
        case .freeFire: return "com.dts.freefireth"
        case .freeFireMax: return "com.dts.freefiremax"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var selectedGame: GameChoice = .freeFire
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showLogs: Bool = false

    private let panel = AppTheme.panel
    private let secondaryText = AppTheme.secondaryText

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.pageBackground, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 150, y: -310)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        BrandMark()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("FUNÇÕES")
                                .font(.system(size: 27, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("MENAGERFF CONTROL CENTER")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(AppTheme.accentBright)
                        }

                        Spacer()

                        HeaderIconButton(systemName: "waveform.path.ecg") {
                            showLogs.toggle()
                        }
                    }

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(!modManager.activeMods.isEmpty ? AppTheme.success.opacity(0.12) : AppTheme.accent.opacity(0.12))
                            Image(systemName: !modManager.activeMods.isEmpty ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(!modManager.activeMods.isEmpty ? AppTheme.success : AppTheme.accentBright)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("STATUS DO SISTEMA")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(modManager.statusMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 6)

                        StatusPill(
                            title: modManager.activeMods.isEmpty ? "PRONTO" : "ATIVO",
                            color: modManager.activeMods.isEmpty ? AppTheme.accentBright : AppTheme.success
                        )
                    }
                    .padding(14)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )

                    gamePicker

                    if showLogs {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("DIAGNÓSTICO")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundStyle(AppTheme.accentBright)
                                Spacer()
                                Image(systemName: "terminal.fill")
                                    .foregroundStyle(AppTheme.accentBright.opacity(0.8))
                            }
                            ScrollView {
                                Text(modManager.debugLogs.isEmpty ? "Nenhum registro ainda." : modManager.debugLogs)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.success.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 105)
                        }
                        .padding(15)
                        .background(AppTheme.consoleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                .stroke(AppTheme.success.opacity(0.16), lineWidth: 1)
                        )
                    }

                    modSection(title: "FUNÇÕES CACHE", subtitle: "Ajustes de precisão e resposta", mods: cacheMods)
                    modSection(title: "FUNÇÕES AVATAR", subtitle: "Configurações avançadas do avatar", mods: avatarMods)
                    modSection(title: "FUNÇÕES DE HOLOGRAMA", subtitle: "Personalização visual de armas", mods: hologramMods)
                    modSection(title: "DESEMPENHO", subtitle: "Performance e fluidez do jogo", mods: performanceMods)

                    Spacer(minLength: 94)
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 21)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var gamePicker: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ALVO DE APLICAÇÃO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(AppTheme.accentBright)
                    Text("Escolha a versão do jogo")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBright)
            }

            HStack(spacing: 10) {
                ForEach(GameChoice.allCases) { game in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedGame = game }
                    } label: {
                        HStack(spacing: 10) {
                            Image(game.logoName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(game == .freeFire ? "FREE FIRE" : "FREE FIRE MAX")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(selectedGame == game ? "Selecionado" : "Toque para selecionar")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(selectedGame == game ? AppTheme.accentBright : secondaryText)
                            }
                            Spacer(minLength: 0)
                            if selectedGame == game {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedGame == game
                                ? AppTheme.accent.opacity(0.16)
                                : AppTheme.panel
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.rowRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.rowRadius, style: .continuous)
                                .stroke(selectedGame == game ? AppTheme.accent.opacity(0.62) : AppTheme.hairline, lineWidth: selectedGame == game ? 1.2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func modSection(title: String, subtitle: String, mods: [ModType]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Text("\(mods.count) OPÇÕES")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            VStack(spacing: 0) {
                ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                    ModRowReference(
                        mod: mod,
                        displayName: modManager.displayName(for: mod),
                        isActive: modManager.activeMods.contains(mod),
                        isProcessing: modManager.isProcessing,
                        onToggle: { isOn in handleToggle(mod: mod, isOn: isOn) }
                    )
                    if index < mods.count - 1 {
                        Divider()
                            .overlay(AppTheme.divider)
                            .padding(.leading, 68)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [AppTheme.panelElevated.opacity(0.95), AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
        }
    }

    private var cacheMods: [ModType] { [.hsAltoCache, .hsPescocoCache, .hsPeitoCache] }
    private var avatarMods: [ModType] { [.hsAltoAvatarPescoco, .hsPescocoAvatarAntena, .hsPeitoAvatarAntena] }
    private var hologramMods: [ModType] { [.hologramaArmas] }
    private var performanceMods: [ModType] { [.fps144] }

    private func handleToggle(mod: ModType, isOn: Bool) {
        guard isOn else {
            modManager.restoreMod(mod) { _, msg in
                alertMessage = msg
                showAlert = true
            }
            return
        }

        modManager.applyMod(mod, bundleID: selectedGame.bundleID) { _, msg in
            alertMessage = msg
            showAlert = true
        }
    }
}

// MARK: - Mod Row
struct ModRowReference: View {
    let mod: ModType
    let displayName: String
    let isActive: Bool
    let isProcessing: Bool
    let onToggle: (Bool) -> Void

    private var iconName: String {
        mod == .hologramaArmas ? "sparkles" : (mod == .fps144 ? "speedometer" : "scope")
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isActive ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.05))
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isActive ? AppTheme.accentBright : AppTheme.tertiaryText)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(mod.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isProcessing {
                ProgressView()
                    .tint(AppTheme.accentBright)
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { value in
                        guard !isProcessing else { return }
                        onToggle(value)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppTheme.accent)
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(isActive ? AppTheme.accent.opacity(0.045) : Color.clear)
    }
}

// MARK: - Config View
struct ProfileView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showKeyAlert = false
    @State private var keyAlertMessage = ""

    private let panel = AppTheme.panel

    private var compatibilityStatus: (text: String, color: Color) {
        switch KernelExploit.currentAccessPath {
        case .kfd16: return ("Compatível — KFD16 experimental", AppTheme.warning)
        case .kernelOffsets: return ("Compatível — offsets", AppTheme.success)
        case .badQuery: return ("Compatível — bad_query", AppTheme.success)
        case .unsupported: return ("Não compatível", AppTheme.accentBright)
        }
    }

    private var accessPathText: String {
        switch KernelExploit.currentAccessPath {
        case .kfd16: return "KFD iOS 16"
        case .kernelOffsets: return "Kernel/offsets iOS 17–18"
        case .badQuery: return "ContainerManager iOS 26–27"
        case .unsupported: return "Indisponível"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.pageBackground, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        BrandMark()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONFIG")
                                .font(.system(size: 27, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("SEGURANÇA E DISPOSITIVO")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        Spacer()
                    }
                    .padding(.top, 21)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill((licenseManager.isAuthorized ? AppTheme.success : AppTheme.warning).opacity(0.13))
                            Image(systemName: licenseManager.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(licenseManager.isAuthorized ? AppTheme.success : AppTheme.warning)
                        }
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("STATUS DA LICENÇA")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(licenseManager.licenseInfo?.status ?? "Sem key registrada")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(licenseManager.isAuthorized ? AppTheme.success : AppTheme.warning)
                        }
                        Spacer(minLength: 8)
                        StatusPill(
                            title: licenseManager.isAuthorized ? "VALIDADA" : "PENDENTE",
                            color: licenseManager.isAuthorized ? AppTheme.success : AppTheme.warning
                        )
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.panelElevated, AppTheme.panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke((licenseManager.isAuthorized ? AppTheme.success : AppTheme.warning).opacity(0.22), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DETALHES DO SISTEMA")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.9)
                                    .foregroundStyle(AppTheme.accentBright)
                                Text("Informações do ambiente atual")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)

                        configRow(title: "Revendedor", value: "", color: .clear)
                        configRow(title: "Expiração", value: licenseManager.licenseInfo?.expiresAt ?? "Sem key registrada", color: licenseManager.licenseInfo == nil ? AppTheme.warning : .white)
                        configRow(title: "ID de Proteção", value: String(licenseManager.deviceID().prefix(18)) + "...", color: .cyan)
                        configRow(title: "Debugging Ativo", value: "Protegido / Anti-Debug OK", color: AppTheme.success)
                        configRow(title: "Compatibilidade", value: compatibilityStatus.text, color: compatibilityStatus.color)
                        configRow(title: "Caminho de acesso", value: accessPathText, color: .cyan)
                        configRow(title: "Build do sistema", value: AppInfo.osBuild, color: .blue)
                        configRow(title: "Modelo do Aparelho", value: UIDevice.current.model, color: .white)
                        configRow(title: "Versão do iOS", value: UIDevice.current.systemVersion, color: .blue.opacity(0.8))
                    }
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )

                    Button(action: {
                        licenseManager.clearSavedKey()
                        keyAlertMessage = "Key removida. A janela de key aparecerá novamente na próxima entrada."
                        showKeyAlert = true
                    }) {
                        HStack(spacing: 9) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("LIMPAR / TROCAR KEY")
                        }
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 49)
                        .background(AppTheme.accent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 94)
                }
                .padding(.horizontal, AppTheme.pageInset)
            }
        }
        .alert("Status da key", isPresented: $showKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(keyAlertMessage)
        }
    }

    private func configRow(title: String, value: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 10)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)
                .padding(.leading, 16)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Textures View
struct TexturesView: View {
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var selectedGame: GameChoice = .freeFire
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let panel = AppTheme.panel
    private let secondaryText = AppTheme.secondaryText

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.pageBackground, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        BrandMark()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TEXTURAS")
                                .font(.system(size: 27, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("VISUAIS PARA O FREE FIRE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        Spacer()
                    }
                    .padding(.top, 21)

                    HStack(spacing: 8) {
                        ForEach(GameChoice.allCases) { game in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) { selectedGame = game }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: selectedGame == game ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(game == .freeFire ? "FREE FIRE" : "FREE FIRE MAX")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .tracking(0.3)
                                }
                                .foregroundStyle(selectedGame == game ? AppTheme.accentBright : AppTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 39)
                                .background(selectedGame == game ? AppTheme.accent.opacity(0.15) : AppTheme.panel)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedGame == game ? AppTheme.accent.opacity(0.55) : AppTheme.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TEXTURAS DISPONÍVEIS")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.9)
                                    .foregroundStyle(AppTheme.accentBright)
                                Text("Escolha um visual para ativar")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(secondaryText)
                            }
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.accentBright)
                        }

                        textureCard(.texturaAlok1, imageName: "AlokTexturePreview1")
                        textureCard(.texturaAlok2, imageName: "AlokTexturePreview2")
                        textureCard(.texturaAlok3, imageName: "AlokTexturePreview3")
                    }

                    Spacer(minLength: 94)
                }
                .padding(.horizontal, AppTheme.pageInset)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("TEXTURAS"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private func textureCard(_ mod: ModType, imageName: String) -> some View {
        let isActive = modManager.activeMods.contains(mod)

        HStack(spacing: 13) {
            ZStack(alignment: .bottomLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 86)
                    .clipped()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 104, height: 86)
                if isActive {
                    Text("ATIVA")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                        .padding(7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? AppTheme.accent.opacity(0.62) : AppTheme.hairline, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(modManager.displayName(for: mod))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(isActive ? "TEXTURA ATIVA" : "Pronta para ativar")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(isActive ? AppTheme.success : AppTheme.accentBright)
                Text("Usar personagem alok despertar para funcionar a textura")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            if modManager.isProcessing {
                ProgressView()
                    .tint(AppTheme.accentBright)
                    .frame(width: 40, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { modManager.activeMods.contains(mod) },
                    set: { enabled in
                        if enabled {
                            modManager.applyMod(mod, bundleID: selectedGame.bundleID) { _, message in
                                alertMessage = message
                                showAlert = true
                            }
                        } else {
                            modManager.restoreMod(mod) { _, message in
                                alertMessage = message
                                showAlert = true
                            }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppTheme.accent)
            }
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: isActive ? [AppTheme.accent.opacity(0.16), AppTheme.panelElevated] : [AppTheme.panelElevated, AppTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(isActive ? AppTheme.accent.opacity(0.50) : AppTheme.hairline, lineWidth: 1)
        )
    }
}
