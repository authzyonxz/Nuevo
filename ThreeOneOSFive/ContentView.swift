import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedTab = 0
    @State private var didStartFlow = false

    var body: some View {
        ZStack {
            if licenseManager.isAuthorized {
                MainTabView(selectedTab: $selectedTab)
            } else {
                KeyAuthGateView().environmentObject(licenseManager)
            }
        }
        .onAppear {
            guard !didStartFlow else { return }
            didStartFlow = true
            licenseManager.bootstrap()
        }
    }
}

@available(iOS 16.0, *)
struct KeyAuthGateView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var inputKey = ""

    var body: some View {
        ZStack {
            AnimatedNetworkBackground().ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 64, height: 64)
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if licenseManager.pendingWebURL != nil,
                   licenseManager.flowState == .openingDeviceRegistration || licenseManager.flowState == .waitingForDevice {
                    Button {
                        licenseManager.openPendingRegistration()
                    } label: {
                        Label("Identificar este iPhone", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(KeyAuthPrimaryButtonStyle())
                    .accessibilityIdentifier("open-device-registration")
                }

                if licenseManager.flowState == .askingForKey {
                    keyEntry
                } else if licenseManager.flowState == .authorized {
                    successView
                } else if case .failure = licenseManager.flowState {
                    Button("TENTAR NOVAMENTE") { licenseManager.retryBootstrap() }
                        .buttonStyle(KeyAuthPrimaryButtonStyle())
                }

                if licenseManager.isLoading {
                    ProgressView().tint(.white).padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 420)
        }
        .preferredColorScheme(.dark)
    }

    private var keyEntry: some View {
        VStack(spacing: 12) {
            TextField("Digite sua Key", text: $inputKey)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.password)
                .submitLabel(.go)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onSubmit { validate() }

            Button("CONFIRMAR KEY") { validate() }
                .buttonStyle(KeyAuthPrimaryButtonStyle())
                .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseManager.isLoading)

            if let error = licenseManager.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.red.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 10) {
            Label("Ativação concluída", systemImage: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            if let info = licenseManager.licenseInfo {
                Text(info.productName).foregroundColor(.white).font(.headline)
                Text("Expira em: \(info.expiresAt)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(.top, 8)
    }

    private var title: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "Checking package"
        case .openingDeviceRegistration, .waitingForDevice: return "Identifique este iPhone"
        case .askingForKey: return "Digite sua Key"
        case .activatingKey: return "Validando acesso"
        case .authorized: return "Acesso autorizado"
        case .failure: return "Não foi possível continuar"
        }
    }

    private var message: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "Verificando o Package EXTERNAL - iOS..."
        case .openingDeviceRegistration: return "Instale o perfil temporário para registrar o UDID deste dispositivo."
        case .waitingForDevice: return "Baixe o perfil, abra Ajustes > Perfil Baixado, instale e depois retorne ao app."
        case .askingForKey: return "O dispositivo foi registrado. Informe a Key para ativar o acesso."
        case .activatingKey: return "Confirmando a Key e vinculando este dispositivo..."
        case .authorized: return "Sua Key foi confirmada pelo servidor."
        case .failure(let value): return value
        }
    }

    private var iconName: String {
        switch licenseManager.flowState {
        case .authorized: return "checkmark.shield.fill"
        case .checkingPackage, .activatingKey: return "lock.shield"
        case .openingDeviceRegistration, .waitingForDevice: return "iphone"
        case .askingForKey: return "key.fill"
        case .failure: return "exclamationmark.shield"
        }
    }

    private func validate() {
        let value = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        licenseManager.validateKey(value) { _, _ in }
    }
}

@available(iOS 16.0, *)
private struct KeyAuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@available(iOS 16.0, *)
private struct AnimatedNetworkBackground: View {
    private struct Node {
        let x: CGFloat
        let y: CGFloat
        let phase: Double
        let radius: CGFloat
    }

    private let nodes: [Node] = [
        .init(x: 0.08, y: 0.16, phase: 0.2, radius: 2.0),
        .init(x: 0.22, y: 0.35, phase: 1.4, radius: 1.7),
        .init(x: 0.37, y: 0.13, phase: 2.2, radius: 2.2),
        .init(x: 0.51, y: 0.28, phase: 0.8, radius: 1.8),
        .init(x: 0.68, y: 0.18, phase: 2.8, radius: 2.0),
        .init(x: 0.86, y: 0.34, phase: 1.1, radius: 1.6),
        .init(x: 0.14, y: 0.58, phase: 2.5, radius: 1.8),
        .init(x: 0.34, y: 0.51, phase: 0.4, radius: 2.1),
        .init(x: 0.59, y: 0.63, phase: 1.8, radius: 1.7),
        .init(x: 0.78, y: 0.52, phase: 2.9, radius: 2.0),
        .init(x: 0.28, y: 0.82, phase: 1.0, radius: 1.6),
        .init(x: 0.57, y: 0.86, phase: 2.0, radius: 2.0),
        .init(x: 0.88, y: 0.78, phase: 0.6, radius: 1.8)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let points = nodes.enumerated().map { index, node -> CGPoint in
                    let driftX = sin(time * 0.16 + node.phase + Double(index)) * 0.012
                    let driftY = cos(time * 0.13 + node.phase * 1.7) * 0.010
                    return CGPoint(x: (node.x + driftX) * size.width, y: (node.y + driftY) * size.height)
                }

                for i in points.indices {
                    for j in (i + 1)..<points.count {
                        let dx = points[i].x - points[j].x
                        let dy = points[i].y - points[j].y
                        let distance = sqrt(dx * dx + dy * dy)
                        let limit = min(size.width, size.height) * 0.30
                        guard distance < limit else { continue }
                        var path = Path()
                        path.move(to: points[i])
                        path.addLine(to: points[j])
                        let alpha = max(0.025, 0.13 * (1.0 - distance / limit))
                        context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 0.65)
                    }
                }

                for (index, point) in points.enumerated() {
                    let pulse = 0.75 + 0.25 * sin(time * 1.4 + nodes[index].phase)
                    let radius = nodes[index].radius * pulse
                    let glow = CGRect(x: point.x - radius * 3.5, y: point.y - radius * 3.5, width: radius * 7, height: radius * 7)
                    context.fill(Path(ellipseIn: glow), with: .color(.white.opacity(0.035)))
                    let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.72)))
                }
            }
            .background(Color.black)
            .overlay(Color.black.opacity(0.18))
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedNetworkBackground()
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
            .background(Color.black.opacity(0.86))
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
                    modSection(title: "FUNÇÕES DE HOLOGRAMA", mods: hologramMods)

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
        [.hsAlto, .hsPescoco, .hsPeito]
    }

    private var hologramMods: [ModType] {
        [.hologramaArmas]
    }

    private var visibleMods: [ModType] { aimbotMods + hologramMods }

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
        modManager.restoreActiveModsBeforeLobby { success, message in
            guard success else {
                alertMessage = message
                showAlert = true
                return
            }

            selectedMods.removeAll()
            let opened = openApplicationForBundleID(selectedGame.bundleID)
            guard !opened else { return }
            alertMessage = "Não foi possível abrir \(selectedGame.rawValue). Verifique se o aplicativo está instalado."
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

                        configRow(title: "Expiração", value: licenseManager.licenseInfo?.expiresAt ?? "Sem key registrada", color: licenseManager.licenseInfo == nil ? .orange : .white)
                        configRow(title: "Package", value: "EXTERNAL - iOS", color: .cyan)
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

                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
            }
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
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                textureCard(.texturaAlok1, imageName: "AlokTexturePreview1")
                textureCard(.texturaAlok2, imageName: "AlokTexturePreview2")
                textureCard(.texturaAlok3, imageName: "AlokTexturePreview3")
            }
        }
    }

    @ViewBuilder
    private func textureCard(_ mod: ModType, imageName: String) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    .clipped()
                LinearGradient(
                    colors: [.black.opacity(0.18), .clear, .black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if modManager.activeMods.contains(mod) {
                    Label("ATIVA", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(9)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(modManager.displayName(for: mod))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Usar personagem Alok despertado")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .topLeading)
                if modManager.isProcessing {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Toggle("Ativar", isOn: Binding(
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
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .toggleStyle(.switch)
                    .tint(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
