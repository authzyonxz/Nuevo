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
        licenseManager.beginAuthorization()
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
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 15) {
                Text("EXPLOIT iOS")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(0.1)
                    .foregroundStyle(.white)

                Text(licenseManager.stage.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(licenseManager.stageMessage)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                if licenseManager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }

                if licenseManager.deviceCaptured {
                    SecureField("Digite sua chave", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                if licenseManager.deviceCaptured {
                    HStack(spacing: 8) {
                    Button(action: validate) {
                        HStack(spacing: 6) {
                            if licenseManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.72)
                            } else {
                                Text("Enviar")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color(red: 0.29, green: 0.55, blue: 0.92))
                        .clipShape(Capsule())
                    }
                    .disabled(licenseManager.isLoading || !licenseManager.canEnterKey || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !licenseManager.canEnterKey ? 0.55 : 1)

                    Button {
                        guard let pasted = UIPasteboard.general.string else { return }
                        inputKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        Text("Paste")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color(red: 0.23, green: 0.23, blue: 0.24))
                            .clipShape(Capsule())
                    }
                    .disabled(licenseManager.isLoading || !licenseManager.canEnterKey)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button(action: licenseManager.obtainUDID) {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Obter UDID")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color(red: 0.29, green: 0.55, blue: 0.92))
                            .clipShape(Capsule())
                        }
                        .disabled(!licenseManager.canObtainUDID)
                        .opacity(licenseManager.canObtainUDID ? 1 : 0.55)

                        Button(action: licenseManager.refreshDeviceCapture) {
                            Text("Verificar")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Capsule())
                        }
                        .disabled(!licenseManager.canVerifyUDID)
                        .opacity(licenseManager.canVerifyUDID ? 1 : 0.55)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 300)
            .background(Color(red: 0.025, green: 0.025, blue: 0.03).opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.65), radius: 28, x: 0, y: 14)
        }
        .preferredColorScheme(.dark)
    }

    private func validate() {
        let key = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        guard licenseManager.canEnterKey else {
            message = licenseManager.stageMessage
            return
        }
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
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 15) {
                    Text("EXPLOIT iOS")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(0.1)
                        .foregroundStyle(.white)

                    SecureField("Digite sua chave", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        .onSubmit(onLogin)

                    if let err = licenseManager.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                    }

                    HStack(spacing: 8) {
                        Button(action: onLogin) {
                            HStack(spacing: 6) {
                                if licenseManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.72)
                                } else {
                                    Text("Enviar")
                                }
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color(red: 0.29, green: 0.55, blue: 0.92))
                            .clipShape(Capsule())
                        }
                        .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                        Button {
                            guard let pasted = UIPasteboard.general.string else { return }
                            inputKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        } label: {
                            Text("Paste")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(Color(red: 0.23, green: 0.23, blue: 0.24))
                                .clipShape(Capsule())
                        }
                        .disabled(licenseManager.isLoading)
                    }

                    Text("Auto close in \(timeRemaining) seconds")
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(Color(red: 0.025, green: 0.025, blue: 0.03).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.13), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.65), radius: 28, x: 0, y: 14)
                .frame(maxWidth: 300)

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
            Color.black
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.055, green: 0.055, blue: 0.065))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
            .padding(.bottom, 18)
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
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.42))
            .frame(width: 92, height: 48)
            .background(isSelected ? Color.white.opacity(0.12) : .clear)
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

    private let panel = Color(red: 0.055, green: 0.055, blue: 0.065)
    private let secondaryText = Color.white.opacity(0.48)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("FUNÇÕES")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("MenagerFF")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryText)
                        }

                        Spacer()

                        Button { showLogs.toggle() } label: {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(!modManager.activeMods.isEmpty ? Color.green : Color.white.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(modManager.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryText)
                        Spacer()
                    }

                    gamePicker

                    if showLogs {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("DIAGNÓSTICO")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                            ScrollView {
                                Text(modManager.debugLogs.isEmpty ? "Nenhum registro ainda." : modManager.debugLogs)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 100)
                        }
                        .padding(14)
                        .background(panel)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    modSection(title: "FUNÇÕES DE AIMBOT", mods: aimbotMods)
                    modSection(title: "FUNÇÕES DE HOLOGRAMA", mods: hologramMods)
                    modSection(title: "DESEMPENHO", mods: performanceMods)

                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var gamePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SELECIONE O JOGO")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)

            HStack(spacing: 10) {
                ForEach(GameChoice.allCases) { game in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedGame = game }
                    } label: {
                        HStack(spacing: 10) {
                            Image(game.logoName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game == .freeFire ? "FREE FIRE" : "FREE FIRE MAX")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(selectedGame == game ? "Selecionado" : "Toque para selecionar")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(selectedGame == game ? .white.opacity(0.7) : secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedGame == game ? Color.white.opacity(0.14) : Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedGame == game ? Color.white.opacity(0.85) : Color.white.opacity(0.1), lineWidth: selectedGame == game ? 1.2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func modSection(title: String, mods: [ModType]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)

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
                        Divider().overlay(Color.white.opacity(0.1)).padding(.leading, 16)
                    }
                }
            }
            .background(panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var aimbotMods: [ModType] { [.hsAlto, .hsPescoco, .hsPeito] }
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mod == .hologramaArmas ? "sparkles" : (mod == .fps144 ? "speedometer" : "scope"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isActive ? .white : .white.opacity(0.38))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(mod.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isProcessing {
                ProgressView()
                    .tint(.white)
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
                .tint(.green)
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}

// MARK: - Config View
struct ProfileView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showKeyAlert = false
    @State private var keyAlertMessage = ""

    private let panel = Color(red: 0.055, green: 0.055, blue: 0.065)

    private var compatibilityStatus: (text: String, color: Color) {
        switch KernelExploit.currentAccessPath {
        case .kfd16: return ("Compatível — KFD16 experimental", .orange)
        case .kernelOffsets: return ("Compatível — offsets", .green)
        case .badQuery: return ("Compatível — bad_query", .green)
        case .unsupported: return ("Não compatível", .red)
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
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONFIG")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Informações e proteção do dispositivo")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(.top, 24)

                    HStack(spacing: 14) {
                        Image(systemName: licenseManager.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(licenseManager.isAuthorized ? .green : .orange)
                            .frame(width: 52, height: 52)
                            .background((licenseManager.isAuthorized ? Color.green : Color.orange).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("STATUS DA LICENÇA")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                            Text(licenseManager.licenseInfo?.status ?? "Sem key registrada")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(licenseManager.isAuthorized ? .green : .orange)
                        }
                        Spacer()
                        Circle()
                            .fill(licenseManager.isAuthorized ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    .padding(16)
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("DETALHES DO SISTEMA")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        configRow(title: "Revendedor", value: "", color: .clear)
                        configRow(title: "Expiração", value: licenseManager.licenseInfo?.expiresAt ?? "Sem key registrada", color: licenseManager.licenseInfo == nil ? .orange : .white)
                        configRow(title: "ID de Proteção", value: String(licenseManager.deviceID().prefix(18)) + "...", color: .cyan)
                        configRow(title: "Debugging Ativo", value: "Protegido / Anti-Debug OK", color: .green)
                        configRow(title: "Compatibilidade", value: compatibilityStatus.text, color: compatibilityStatus.color)
                        configRow(title: "Caminho de acesso", value: accessPathText, color: .cyan)
                        configRow(title: "Build do sistema", value: AppInfo.osBuild, color: .blue)
                        configRow(title: "Modelo do Aparelho", value: UIDevice.current.model, color: .white)
                        configRow(title: "Versão do iOS", value: UIDevice.current.systemVersion, color: .blue.opacity(0.8))
                    }
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    Button(action: {
                        licenseManager.clearSavedKey()
                        keyAlertMessage = "Key removida. A janela de key aparecerá novamente na próxima entrada."
                        showKeyAlert = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("LIMPAR / TROCAR KEY")
                        }
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.red.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
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
                .foregroundColor(.white.opacity(0.48))
            Spacer(minLength: 10)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
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
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }
}


// MARK: - Textures View
struct TexturesView: View {
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var selectedGame: GameChoice = .freeFire
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let panel = Color(red: 0.055, green: 0.055, blue: 0.065)
    private let secondaryText = Color.white.opacity(0.48)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TEXTURAS")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Personalize o visual do Free Fire")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.top, 24)

                    gamePicker
                    textureSection
                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("TEXTURAS"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var gamePicker: some View {
        HStack(spacing: 10) {
            ForEach(GameChoice.allCases) { game in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selectedGame = game }
                } label: {
                    Text(game == .freeFire ? "FREE FIRE" : "FREE FIRE MAX")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selectedGame == game ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedGame == game ? Color.white.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TEXTURAS DISPONÍVEIS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)
            textureCard(.texturaAlok1, imageName: "AlokTexturePreview1")
            textureCard(.texturaAlok2, imageName: "AlokTexturePreview2")
            textureCard(.texturaAlok3, imageName: "AlokTexturePreview3")
        }
    }

    @ViewBuilder
    private func textureCard(_ mod: ModType, imageName: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                VStack(alignment: .leading, spacing: 5) {
                    Text(modManager.displayName(for: mod))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(modManager.activeMods.contains(mod) ? "ATIVA" : "Pronta para ativar")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(modManager.activeMods.contains(mod) ? .green : secondaryText)
                    Text("Usar personagem alok despertar para funcionar a textura")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if modManager.isProcessing {
                    ProgressView().tint(.white).frame(width: 51, height: 31)
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
                    .tint(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            VStack(alignment: .leading, spacing: 4) {
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 15)
        }
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
