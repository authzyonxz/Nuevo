import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var inputKey: String = ""
    @State private var selectedTab: Int = 0
    @State private var timeRemaining: Int = 10
    @State private var timer: Timer? = nil

    var body: some View {
        Group {
            if licenseManager.isAuthorized {
                MainTabView(selectedTab: $selectedTab)
            } else {
                LoginView(inputKey: $inputKey, timeRemaining: timeRemaining, onLogin: {
                    timer?.invalidate()
                    licenseManager.validateKey(inputKey) { success, error in
                        if !success {
                            print("Login falhou: \(error ?? "Erro desconhecido")")
                        }
                    }
                })
                .onAppear {
                    startCountdown()
                }
                .onDisappear {
                    timer?.invalidate()
                }
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
                    exit(0)
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

// MARK: - Main Tab View (Custom Floating Bar)
struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == 0 {
                    HomeView()
                } else {
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Floating Tab Bar
            HStack(spacing: 60) {
                TabButton(index: 0, icon: "house.fill", title: "INÍCIO", selectedTab: $selectedTab)
                TabButton(index: 1, icon: "person.fill", title: "PERFIL", selectedTab: $selectedTab)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .background(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .padding(.bottom, 30)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct TabButton: View {
    let index: Int
    let icon: String
    let title: String
    @Binding var selectedTab: Int

    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(selectedTab == index ? .blue : .white.opacity(0.4))
        }
    }
}

// MARK: - Home View (Exact Reference Layout)
struct HomeView: View {
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showLogs: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Terminal Log Toggle Header
                    HStack {
                        Circle()
                            .fill(modManager.activeMod != nil ? Color.green : Color.blue)
                            .frame(width: 8, height: 8)
                        Text(modManager.statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Button(action: { showLogs.toggle() }) {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if showLogs {
                        VStack(alignment: .leading) {
                            Text("DIAGNÓSTICO EM TEMPO REAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            ScrollView {
                                Text(modManager.debugLogs)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 100)
                        }
                        .padding()
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }

                    // Seção de Aimbots (HS Alto, Pescoço, Peito)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FUNÇÕES DE AIMBOT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(aimbotMods.enumerated()), id: \.element.id) { index, mod in
                                ModRowReference(
                                    mod: mod,
                                    isActive: modManager.activeMod == mod,
                                    onToggle: { isOn in
                                        handleToggle(mod: mod, isOn: isOn)
                                    }
                                )
                                if index < aimbotMods.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(#colorLiteral(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }

                    // Seção de Holograma
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FUNÇÕES DE HOLOGRAMA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(hologramMods, id: \.id) { mod in
                                ModRowReference(
                                    mod: mod,
                                    isActive: modManager.activeMod == mod,
                                    onToggle: { isOn in
                                        handleToggle(mod: mod, isOn: isOn)
                                    }
                                )
                            }
                        }
                        .background(Color(#colorLiteral(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var aimbotMods: [ModType] {
        [.hsAlto, .hsPescoco, .hsPeito]
    }

    private var hologramMods: [ModType] {
        [.hologramaArmas]
    }

    private func handleToggle(mod: ModType, isOn: Bool) {
        if isOn {
            modManager.applyMod(mod) { success, msg in
                alertMessage = msg
                showAlert = true
            }
        } else {
            modManager.restoreOriginal { success, msg in
                alertMessage = msg
                showAlert = true
            }
        }
    }
}

// MARK: - Mod Row Reference Component (Exact Image Match)
struct ModRowReference: View {
    let mod: ModType
    let isActive: Bool
    let onToggle: (Bool) -> Void
    @State private var isProcessing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(mod.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(mod.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            if isProcessing {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { value in
                        isProcessing = true
                        onToggle(value)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isProcessing = false
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var licenseManager: LicenseManager

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
                        InfoRow(title: "Status da Licença", value: licenseManager.licenseInfo?.status ?? "VIP ATIVO", color: .green)
                        InfoRow(title: "Produto", value: licenseManager.licenseInfo?.productName ?? "ruanwq", color: .blue)
                        InfoRow(title: "Expiração", value: licenseManager.licenseInfo?.expiresAt ?? "Vitalício", color: .white)
                        InfoRow(title: "ID de Proteção", value: String(licenseManager.deviceID().prefix(18)) + "...", color: .cyan)
                        InfoRow(title: "Debugging Ativo", value: "Protegido / Anti-Debug OK", color: .green)
                        InfoRow(title: "Compatibilidade", value: "Compatível (iOS 18.2.1+)", color: .green)
                        InfoRow(title: "Modelo do Aparelho", value: UIDevice.current.model, color: .white)
                        InfoRow(title: "Versão do iOS", value: UIDevice.current.systemVersion, color: .blue.opacity(0.8))
                    }
                    .padding(20)
                    .background(Color(#colorLiteral(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)))
                    .cornerRadius(20)
                    .padding(.horizontal, 16)

                    Button(action: {
                        licenseManager.clearSavedKey()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("SAIR E LIMPAR KEY")
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
                    
                    Spacer(minLength: 100)
                }
            }
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
