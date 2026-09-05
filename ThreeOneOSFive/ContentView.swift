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

            VStack(spacing: 14) {
                SecureField("Digite sua key", text: $inputKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .submitLabel(.go)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .tint(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onSubmit(validate)

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                Button(action: validate) {
                    Group {
                        if licenseManager.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("ENTRAR")
                        }
                    }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.72 : 1)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 390)
            .offset(y: -28)
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
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 14) {
                SecureField("Digite sua key", text: $inputKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .tint(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onSubmit(onLogin)

                if let err = licenseManager.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                Button(action: onLogin) {
                    Group {
                        if licenseManager.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("ENTRAR")
                        }
                    }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.72 : 1)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 390)
            .offset(y: -28)
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
            .padding(.bottom, 76)

            HStack(spacing: 0) {
                TabButton(index: 0, icon: "square.grid.2x2", title: "Funções", selectedTab: $selectedTab)
                TabButton(index: 1, icon: "paintbrush.pointed", title: "Texturas", selectedTab: $selectedTab)
                TabButton(index: 2, icon: "person.crop.circle", title: "Config", selectedTab: $selectedTab)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color.black)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
            }
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
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.34))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
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
    @State private var selectedMods: Set<ModType> = []
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showLogs: Bool = false

    private let secondaryText = Color.white.opacity(0.42)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    gamePicker

                    if showLogs {
                        diagnosticPanel
                    }

                    modSection(title: "FUNÇÕES DE AIMBOT", mods: aimbotMods)

                    if shouldShowActions {
                        actionButtons
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .onAppear {
            selectedMods.formUnion(modManager.activeMods)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        HStack {
            Color.clear.frame(width: 32, height: 32)
            Spacer()
            Text("FUNÇÕES")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button { showLogs.toggle() } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.48))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var gamePicker: some View {
        HStack(spacing: 28) {
            ForEach(GameChoice.allCases) { game in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedGame = game
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(game.logoName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                        Text(game == .freeFire ? "Free Fire Normal" : "Free Fire Max")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(selectedGame == game ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIAGNÓSTICO")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.48))
            ScrollView {
                Text(modManager.debugLogs.isEmpty ? "Nenhum registro ainda." : modManager.debugLogs)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 82)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func modSection(title: String, mods: [ModType]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(secondaryText)

            VStack(spacing: 0) {
                ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                    ModRowReference(
                        mod: mod,
                        displayName: modManager.displayName(for: mod),
                        isActive: selectedMods.contains(mod) || modManager.activeMods.contains(mod),
                        isProcessing: modManager.isProcessing,
                        onToggle: { isOn in handleToggle(mod: mod, isOn: isOn) }
                    )
                    if index < mods.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var aimbotMods: [ModType] {
        [.hsAltoAvatarPescoco, .hsPescocoAvatarAntena, .hsPeitoAvatarAntena, .hsAltoCache]
    }

    private var visibleMods: [ModType] { aimbotMods }

    private var pendingMods: [ModType] {
        visibleMods.filter { selectedMods.contains($0) && !modManager.activeMods.contains($0) }
    }

    private var shouldShowActions: Bool {
        !selectedMods.isEmpty || !modManager.activeMods.isEmpty
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(action: injectSelectedMods) {
                Group {
                    if modManager.isProcessing {
                        ProgressView().tint(.black)
                    } else {
                        Text("INJETAR (40%)")
                    }
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(modManager.isProcessing || pendingMods.isEmpty)
            .opacity(pendingMods.isEmpty ? 0.56 : 1)

            Button(action: openLobby) {
                Text("LOBBY")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(modManager.isProcessing)
        }
        .padding(.top, 4)
    }

    private func handleToggle(mod: ModType, isOn: Bool) {
        if isOn {
            if let activeInSection = modManager.activeMods.first(where: { $0.sectionName == mod.sectionName && $0 != mod }) {
                alertMessage = "Desative \(modManager.displayName(for: activeInSection)) antes de selecionar outra função deste grupo."
                showAlert = true
                return
            }

            selectedMods = Set(selectedMods.filter {
                $0.sectionName != mod.sectionName || modManager.activeMods.contains($0)
            })
            selectedMods.insert(mod)
            return
        }

        guard modManager.activeMods.contains(mod) else {
            selectedMods.remove(mod)
            return
        }

        modManager.restoreMod(mod) { success, msg in
            if success {
                selectedMods.remove(mod)
            }
            alertMessage = msg
            showAlert = true
        }
    }

    private func injectSelectedMods() {
        let mods = pendingMods
        guard !mods.isEmpty else { return }
        applySequentially(mods, at: 0, messages: [])
    }

    private func applySequentially(_ mods: [ModType], at index: Int, messages: [String]) {
        guard index < mods.count else {
            alertMessage = messages.joined(separator: "\n")
            showAlert = true
            return
        }

        let mod = mods[index]
        modManager.applyMod(mod, bundleID: selectedGame.bundleID) { _, message in
            let line = "\(modManager.displayName(for: mod)): \(message)"
            applySequentially(mods, at: index + 1, messages: messages + [line])
        }
    }

    private func openLobby() {
        let opened = openApplicationForBundleID(selectedGame.bundleID)
        guard !opened else { return }
        alertMessage = "Não foi possível abrir \(selectedGame.rawValue). Verifique se o aplicativo está instalado."
        showAlert = true
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(mod.subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            if isProcessing {
                ProgressView()
                    .tint(.white)
                    .frame(width: 50, height: 31)
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
        .padding(.vertical, 11)
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
