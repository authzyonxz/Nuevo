import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var inputKey: String = ""
    @State private var selectedTab: Int = 0
    @State private var timeRemaining: Int = 10
    @State private var timer: Timer? = nil

    var body: some View {
        MainTabView(selectedTab: $selectedTab)
            .onAppear {
                // A key não é exigida para abrir o painel. Cada ativação
                // consulta novamente o servidor antes de iniciar o patch.
                if licenseManager.loadSavedKey() != nil {
                    licenseManager.validateKey(licenseManager.loadSavedKey() ?? "") { _, _ in }
                }
            }
    }

    private func startCountdown() {
        timeRemaining = 10
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                t.invalidate()
                if !licenseManager.isAuthorized {
                    licenseManager.errorMessage = "Tempo de autenticação expirado. Insira sua key para continuar."
                }
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
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                            .shadow(color: .blue.opacity(0.5), radius: 15)
                        
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }

                    Text("MenagerFF")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }

                // Janela preta com título em branco
                VStack(alignment: .leading, spacing: 16) {
                    Text("INSIRA SUA KEY")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    SecureField("Digite sua Key...", text: $inputKey)
                        .padding(16)
                        .background(Color.black)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.system(size: 15, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    if let err = licenseManager.errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Button(action: onLogin) {
                        HStack {
                            if licenseManager.isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("ENTRAR NO PAINEL")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, Color.blue.opacity(0.7)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(licenseManager.isLoading)
                }
                .padding(24)
                .background(Color(#colorLiteral(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Text("Tempo restante: \(timeRemaining)s")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
            }
        }
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
                } else {
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                TabButton(index: 0, icon: "square.grid.2x2.fill", title: "FUNÇÕES", selectedTab: $selectedTab)
                TabButton(index: 1, icon: "person.crop.circle", title: "CONFIG", selectedTab: $selectedTab)
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
}

struct HomeView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var selectedGame: GameChoice = .freeFire
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showLogs: Bool = false
    @State private var showKeySheet: Bool = false

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

                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showKeySheet) {
            KeyRegistrationView()
                .environmentObject(licenseManager)
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

    private func handleToggle(mod: ModType, isOn: Bool) {
        guard isOn else {
            modManager.restoreOriginal { _, msg in
                alertMessage = msg
                showAlert = true
            }
            return
        }

        guard !licenseManager.isValidatingActivation else { return }
        licenseManager.validateForActivation { success, message in
            guard success else {
                alertMessage = message ?? "Key inválida ou expirada."
                showAlert = true
                showKeySheet = true
                return
            }
            modManager.applyMod(mod) { _, msg in
                alertMessage = msg
                showAlert = true
            }
        }
    }
}

// MARK: - Mod Row
struct ModRowReference: View {
    let mod: ModType
    let isActive: Bool
    let isProcessing: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mod == .hologramaArmas ? "sparkles" : "scope")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isActive ? .white : .white.opacity(0.38))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(mod.rawValue)
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

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showKeySheet = false
    @State private var showKeyAlert = false
    @State private var keyAlertMessage = ""

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
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    Text("MEU PERFIL")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    VStack(spacing: 16) {
                        InfoRow(title: "Status da Licença", value: licenseManager.licenseInfo?.status ?? "Sem key registrada", color: licenseManager.isAuthorized ? .green : .orange)
                        InfoRow(title: "Produto", value: licenseManager.licenseInfo?.productName ?? "ruanwq", color: .blue)
                        InfoRow(title: "Expiração", value: licenseManager.licenseInfo?.expiresAt ?? "Sem key registrada", color: licenseManager.licenseInfo == nil ? .orange : .white)
                        InfoRow(title: "ID de Proteção", value: String(licenseManager.deviceID().prefix(18)) + "...", color: .cyan)
                        InfoRow(title: "Debugging Ativo", value: "Protegido / Anti-Debug OK", color: .green)
                        InfoRow(title: "Compatibilidade", value: compatibilityStatus.text, color: compatibilityStatus.color)
                        InfoRow(title: "Caminho de acesso", value: accessPathText, color: .cyan)
                        InfoRow(title: "Build do sistema", value: AppInfo.osBuild, color: .blue)
                        InfoRow(title: "Modelo do Aparelho", value: UIDevice.current.model, color: .white)
                        InfoRow(title: "Versão do iOS", value: UIDevice.current.systemVersion, color: .blue.opacity(0.8))
                    }
                    .padding(20)
                    .background(Color(#colorLiteral(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)))
                    .cornerRadius(20)
                    .padding(.horizontal, 16)

                    Button(action: {
                        licenseManager.clearSavedKey()
                        keyAlertMessage = "Key removida. Agora você pode validar outra key."
                        showKeyAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("LIMPAR / TROCAR KEY")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 16)

                    Button(action: {
                        showKeySheet = true
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("VALIDAR KEY")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, Color.blue.opacity(0.7)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showKeySheet) {
            KeyRegistrationView()
                .environmentObject(licenseManager)
        }
        .alert("Status da key", isPresented: $showKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(keyAlertMessage)
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


// MARK: - Key Registration
struct KeyRegistrationView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) private var dismiss
    @State private var inputKey = ""
    @State private var message = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Text("INSIRA SUA KEY")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    SecureField("Cole sua key aqui", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.white)
                        .tint(.white)
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .cornerRadius(10)

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        licenseManager.validateKey(inputKey.trimmingCharacters(in: .whitespacesAndNewlines)) { success, error in
                            if success {
                                message = "Key ativa e vinculada a este aparelho."
                                dismiss()
                            } else {
                                message = error ?? "Key inválida ou expirada."
                            }
                        }
                    } label: {
                        Group {
                            if licenseManager.isLoading { ProgressView() }
                            else { Text("VALIDAR KEY").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(licenseManager.isLoading || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
                .padding(24)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
