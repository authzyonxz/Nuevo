import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @AppStorage("menagerff.prefersDarkMode") private var prefersDarkMode = false
    @State private var selectedTab = 0
    @State private var selectedGame: GameChoice?
    @State private var didStartFlow = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var pendingImportURL: URL?

    var body: some View {
        ZStack {
            if licenseManager.isAuthorized {
                if let selectedGame {
                    MainTabView(
                        selectedTab: $selectedTab,
                        game: selectedGame,
                        isDarkMode: $prefersDarkMode
                    )
                } else {
                    GameSelectionView(
                        selectedGame: $selectedGame,
                        isDarkMode: $prefersDarkMode
                    )
                }
            } else {
                KeyAuthGateView().environmentObject(licenseManager)
            }
        }
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
        .onAppear {
            guard !didStartFlow else { return }
            didStartFlow = true
            licenseManager.bootstrap()
        }
        .onOpenURL { incomingURL in
            receiveImportURL(incomingURL)
        }
        .onChange(of: licenseManager.isAuthorized) { isAuthorized in
            if !isAuthorized {
                selectedGame = nil
                selectedTab = 0
                return
            }
            guard isAuthorized, let pendingImportURL else { return }
            self.pendingImportURL = nil
            importURL(pendingImportURL)
        }
    }

    private func receiveImportURL(_ url: URL) {
        guard PatchImportRoute.resolve(url) != .invalid else { return }
        guard licenseManager.isAuthorized else {
            pendingImportURL = url
            return
        }
        importURL(url)
    }

    private func importURL(_ url: URL) {
        patchStore.importPackage(from: PatchImportRoute.resolve(url))
    }
}

@available(iOS 16.0, *)
struct KeyAuthGateView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var inputKey = ""
    @State private var showsKey = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnimatedNetworkBackground().ignoresSafeArea()
                LinearGradient(
                    colors: [Color.blue.opacity(0.16), .clear, Color.purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        brandHeader
                        authenticationCard
                        secureFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var brandHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "scope")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: Color.blue.opacity(0.34), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text("MENAGERFF")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.white)
                Text("ACESSO SEGURO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.46))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("ONLINE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
            }
            .foregroundColor(.white.opacity(0.65))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private var authenticationCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(accentColor.opacity(0.20), lineWidth: 1))
                Circle()
                    .fill(accentColor.opacity(0.09))
                    .frame(width: 68, height: 68)
                Image(systemName: iconName)
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundColor(accentColor)
                if licenseManager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.82)
                        .offset(x: 34, y: 34)
                }
            }

            VStack(spacing: 8) {
                Text(statusLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KeyAuthProgressView(state: licenseManager.flowState)

            if shouldShowRegistrationButton {
                Button {
                    licenseManager.openPendingRegistration()
                } label: {
                    Label("IDENTIFICAR ESTE IPHONE", systemImage: "safari.fill")
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
                Button {
                    licenseManager.retryBootstrap()
                } label: {
                    Label("TENTAR NOVAMENTE", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KeyAuthPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.105), Color.white.opacity(0.052)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.11), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.38), radius: 32, y: 18)
    }

    private var keyEntry: some View {
        VStack(spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)
                Group {
                    if showsKey {
                        TextField("Cole ou digite sua Key", text: $inputKey)
                    } else {
                        SecureField("Cole ou digite sua Key", text: $inputKey)
                    }
                }
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.password)
                .submitLabel(.go)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .onSubmit { validate() }

                Button { showsKey.toggle() } label: {
                    Image(systemName: showsKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.48))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsKey ? "Ocultar Key" : "Mostrar Key")
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(Color.black.opacity(0.30))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.white.opacity(0.11), lineWidth: 1))

            Button {
                validate()
            } label: {
                Label("CONFIRMAR KEY", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(KeyAuthPrimaryButtonStyle())
            .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseManager.isLoading)

            if let error = licenseManager.errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(Color.red.opacity(0.94))
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 10) {
            Label("Ativação concluída", systemImage: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(.green)
            if let info = licenseManager.licenseInfo {
                Text(info.productName)
                    .foregroundColor(.white)
                    .font(.headline)
                Text("Expira em: \(info.expiresAt)")
                    .font(.system(size: 13, design: .default))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(.top, 8)
    }

    private var secureFooter: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.fill")
            Text("CONEXÃO PROTEGIDA · CHAVE SALVA NO IPHONE")
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundColor(.white.opacity(0.36))
    }

    private var shouldShowRegistrationButton: Bool {
        guard licenseManager.pendingWebURL != nil else { return false }
        return licenseManager.flowState == .openingDeviceRegistration || licenseManager.flowState == .waitingForDevice
    }

    private var title: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "Verificando o pacote"
        case .openingDeviceRegistration, .waitingForDevice: return "Identifique este iPhone"
        case .askingForKey: return "Ative seu acesso"
        case .activatingKey: return "Validando sua Key"
        case .authorized: return "Acesso autorizado"
        case .failure: return "Não foi possível continuar"
        }
    }

    private var message: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "Conectando ao servidor e confirmando a disponibilidade do Package EXTERNAL - iOS."
        case .openingDeviceRegistration: return "Instale o perfil temporário para registrar o UDID deste dispositivo."
        case .waitingForDevice: return "Baixe o perfil, abra Ajustes > Perfil Baixado, instale e depois retorne ao app."
        case .askingForKey: return "Seu dispositivo está pronto. Informe a Key para liberar todas as funções."
        case .activatingKey: return "Confirmando a licença e vinculando o acesso seguro a este dispositivo."
        case .authorized: return "Sua Key foi confirmada pelo servidor."
        case .failure(let value): return value
        }
    }

    private var iconName: String {
        switch licenseManager.flowState {
        case .authorized: return "checkmark.shield.fill"
        case .checkingPackage, .activatingKey: return "lock.shield.fill"
        case .openingDeviceRegistration, .waitingForDevice: return "iphone"
        case .askingForKey: return "key.fill"
        case .failure: return "exclamationmark.shield.fill"
        }
    }

    private var statusLabel: String {
        switch licenseManager.flowState {
        case .checkingPackage: return "INICIALIZAÇÃO SEGURA"
        case .openingDeviceRegistration, .waitingForDevice: return "REGISTRO DO DISPOSITIVO"
        case .askingForKey: return "LICENÇA MENAGERFF"
        case .activatingKey: return "AUTENTICAÇÃO EM ANDAMENTO"
        case .authorized: return "VALIDAÇÃO CONCLUÍDA"
        case .failure: return "FALHA NA VERIFICAÇÃO"
        }
    }

    private var accentColor: Color {
        switch licenseManager.flowState {
        case .authorized: return .green
        case .failure: return .red
        default: return .cyan
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
            .font(.system(size: 13, weight: .bold, design: .default))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [Color.blue.opacity(0.72), Color.cyan.opacity(0.72)]
                        : [Color.blue, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: Color.blue.opacity(configuration.isPressed ? 0.12 : 0.30), radius: 16, y: 8)
    }
}

@available(iOS 16.0, *)
private struct KeyAuthProgressView: View {
    private enum StepState: Equatable { case completed, active, pending }
    private struct Step: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let state: StepState
    }

    let state: LicenseManager.FlowState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(color(for: step.state).opacity(step.state == .pending ? 0.08 : 0.16))
                            .frame(width: 34, height: 34)
                        Image(systemName: step.state == .completed ? "checkmark" : step.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color(for: step.state))
                    }
                    Text(step.title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(step.state == .pending ? .white.opacity(0.28) : .white.opacity(0.68))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(step.title)
                .accessibilityValue(accessibilityValue(for: step.state))

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(step.state == .completed ? Color.green.opacity(0.50) : Color.white.opacity(0.09))
                        .frame(height: 1)
                        .offset(y: -10)
                }
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var steps: [Step] {
        switch state {
        case .checkingPackage:
            return [.init(id: 0, title: "PACOTE", icon: "shippingbox.fill", state: .active), .init(id: 1, title: "IPHONE", icon: "iphone", state: .pending), .init(id: 2, title: "ACESSO", icon: "key.fill", state: .pending)]
        case .openingDeviceRegistration, .waitingForDevice:
            return [.init(id: 0, title: "PACOTE", icon: "shippingbox.fill", state: .completed), .init(id: 1, title: "IPHONE", icon: "iphone", state: .active), .init(id: 2, title: "ACESSO", icon: "key.fill", state: .pending)]
        case .askingForKey, .activatingKey:
            return [.init(id: 0, title: "PACOTE", icon: "shippingbox.fill", state: .completed), .init(id: 1, title: "IPHONE", icon: "iphone", state: .completed), .init(id: 2, title: "ACESSO", icon: "key.fill", state: .active)]
        case .authorized:
            return [.init(id: 0, title: "PACOTE", icon: "shippingbox.fill", state: .completed), .init(id: 1, title: "IPHONE", icon: "iphone", state: .completed), .init(id: 2, title: "ACESSO", icon: "key.fill", state: .completed)]
        case .failure:
            return [.init(id: 0, title: "PACOTE", icon: "shippingbox.fill", state: .pending), .init(id: 1, title: "IPHONE", icon: "iphone", state: .pending), .init(id: 2, title: "ACESSO", icon: "key.fill", state: .pending)]
        }
    }

    private func color(for state: StepState) -> Color {
        switch state {
        case .completed: return .green
        case .active: return .cyan
        case .pending: return .white
        }
    }

    private func accessibilityValue(for state: StepState) -> String {
        switch state {
        case .completed: return "Concluído"
        case .active: return "Em andamento"
        case .pending: return "Pendente"
        }
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

// MARK: - Unified app experience
private enum GameChoice: String, CaseIterable, Identifiable {
    case freeFire = "Free Fire Normal"
    case freeFireMax = "Free Fire MAX"

    var id: String { rawValue }

    var logoName: String {
        switch self {
        case .freeFire: return "FreeFireLogo"
        case .freeFireMax: return "FreeFireMaxLogo"
        }
    }

    var editionName: String {
        switch self {
        case .freeFire: return "Edição padrão"
        case .freeFireMax: return "Edição MAX"
        }
    }

    var bundleID: String {
        switch self {
        case .freeFire: return "com.dts.freefireth"
        case .freeFireMax: return "com.dts.freefiremax"
        }
    }
}

private enum AimFileType: String, CaseIterable, Identifiable {
    case avatar = "Avatar"
    case cache = "Cache"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .avatar: return "Arquivos Avatar com ativação pelo botão Injetar"
        case .cache: return "Arquivos Cache com ativação direta"
        }
    }
}

private struct AppPalette {
    let isDark: Bool

    var background: Color {
        isDark
            ? Color(red: 0.035, green: 0.043, blue: 0.065)
            : Color(red: 0.955, green: 0.965, blue: 0.995)
    }

    var surface: Color {
        isDark
            ? Color(red: 0.075, green: 0.088, blue: 0.12)
            : .white
    }

    var elevatedSurface: Color {
        isDark
            ? Color(red: 0.10, green: 0.115, blue: 0.15)
            : Color(red: 0.985, green: 0.99, blue: 1.0)
    }

    var primaryText: Color { isDark ? .white : Color(red: 0.055, green: 0.065, blue: 0.09) }
    var secondaryText: Color { isDark ? .white.opacity(0.56) : Color(red: 0.32, green: 0.36, blue: 0.44) }
    var divider: Color { isDark ? .white.opacity(0.08) : Color.black.opacity(0.07) }
    var border: Color { isDark ? .white.opacity(0.10) : Color.black.opacity(0.055) }
    var accent: Color { Color(red: 0.20, green: 0.67, blue: 0.96) }
    var accentSoft: Color { accent.opacity(isDark ? 0.18 : 0.12) }
    var shadow: Color { isDark ? .clear : Color(red: 0.13, green: 0.18, blue: 0.30).opacity(0.09) }
}

private struct GameSelectionView: View {
    @Binding var selectedGame: GameChoice?
    @Binding var isDarkMode: Bool
    @State private var candidate: GameChoice = .freeFire

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            Circle()
                .fill(palette.accent.opacity(isDarkMode ? 0.13 : 0.10))
                .frame(width: 330, height: 330)
                .blur(radius: 44)
                .offset(x: 150, y: -330)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("PERFIL")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundColor(palette.secondaryText)
                        Spacer()
                        ThemeToggleButton(isDarkMode: $isDarkMode)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selecione o jogo")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(palette.primaryText)
                        Text("Escolha um perfil antes de carregar as funções. Todas as alterações usarão somente o jogo selecionado.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        ForEach(GameChoice.allCases) { game in
                            gameCard(game)
                        }
                    }

                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            selectedGame = candidate
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("CONTINUAR")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [palette.accent, Color(red: 0.37, green: 0.78, blue: 0.98)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: palette.accent.opacity(0.25), radius: 20, y: 10)
                    }
                    .buttonStyle(.plain)

                    Text("Você poderá reiniciar o app para escolher outro perfil.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 36)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func gameCard(_ game: GameChoice) -> some View {
        let isSelected = candidate == game
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { candidate = game }
        } label: {
            HStack(spacing: 16) {
                Image(game.logoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(game.rawValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                    Text(game.editionName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(palette.secondaryText)
                    Text(game.bundleID)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? palette.accent : palette.secondaryText.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(isSelected ? palette.accent : palette.secondaryText.opacity(0.35))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(isSelected ? palette.accentSoft : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? palette.accent : palette.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: palette.shadow, radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Tab View
private struct MainTabView: View {
    @Binding var selectedTab: Int
    let game: GameChoice
    @Binding var isDarkMode: Bool

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    AimsView(game: game, isDarkMode: $isDarkMode)
                case 1:
                    ESPView(game: game, isDarkMode: $isDarkMode)
                case 2:
                    ChamsView(game: game, isDarkMode: $isDarkMode)
                case 3:
                    TexturesView(game: game, isDarkMode: $isDarkMode)
                default:
                    AdjustmentsView(game: game, isDarkMode: $isDarkMode)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 82)

            HStack(spacing: 0) {
                TabButton(index: 0, icon: "scope", title: "Aims", selectedTab: $selectedTab, palette: palette)
                TabButton(index: 1, icon: "eye.fill", title: "ESP", selectedTab: $selectedTab, palette: palette)
                TabButton(index: 2, icon: "paintpalette.fill", title: "Chams", selectedTab: $selectedTab, palette: palette)
                TabButton(index: 3, icon: "square.3.layers.3d", title: "Texturas", selectedTab: $selectedTab, palette: palette)
                TabButton(index: 4, icon: "slider.horizontal.3", title: "Ajustes", selectedTab: $selectedTab, palette: palette)
            }
            .padding(.horizontal, 5)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(palette.surface.opacity(0.97))
            .overlay(alignment: .top) {
                Rectangle().fill(palette.divider).frame(height: 1)
            }
            .shadow(color: palette.shadow, radius: 20, y: -6)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct TabButton: View {
    let index: Int
    let icon: String
    let title: String
    @Binding var selectedTab: Int
    let palette: AppPalette

    private var isSelected: Bool { selectedTab == index }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .bold : .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? palette.accent : palette.secondaryText.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? palette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared components
private struct ScreenHeader: View {
    let title: String
    let game: GameChoice
    @Binding var isDarkMode: Bool

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                Image(game.logoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundColor(palette.primaryText)

                Spacer()
                ThemeToggleButton(isDarkMode: $isDarkMode)
            }

            HStack(spacing: 7) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text(game.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("•")
                Text(game.bundleID)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundColor(palette.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(palette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(palette.border, lineWidth: 1))
        }
    }
}

private struct ThemeToggleButton: View {
    @Binding var isDarkMode: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { isDarkMode.toggle() }
        } label: {
            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isDarkMode ? .yellow : Color(red: 0.19, green: 0.24, blue: 0.34))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(isDarkMode ? 0.10 : 0.90))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDarkMode ? "Ativar tema claro" : "Ativar tema escuro")
    }
}

private struct SectionLabel: View {
    let title: String
    let palette: AppPalette

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.7)
            .foregroundColor(palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FunctionListCard: View {
    let mods: [ModType]
    let selectedMods: Set<ModType>
    let activeMods: Set<ModType>
    let isProcessing: Bool
    let palette: AppPalette
    let displayName: (ModType) -> String
    let onToggle: (ModType, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                FunctionRow(
                    mod: mod,
                    displayName: displayName(mod),
                    isActive: selectedMods.contains(mod) || activeMods.contains(mod),
                    isProcessing: isProcessing,
                    palette: palette,
                    onToggle: { onToggle(mod, $0) }
                )
                if index < mods.count - 1 {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(palette.border, lineWidth: 1))
        .shadow(color: palette.shadow, radius: 16, y: 7)
    }
}

private struct FunctionRow: View {
    let mod: ModType
    let displayName: String
    let isActive: Bool
    let isProcessing: Bool
    let palette: AppPalette
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 38, height: 38)
                .background(iconColor.opacity(isActive ? 0.18 : 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(palette.primaryText)
                Text(mod.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isProcessing {
                ProgressView().tint(palette.accent).frame(width: 48)
            } else {
                Toggle("", isOn: Binding(get: { isActive }, set: onToggle))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(palette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var iconColor: Color {
        switch mod {
        case .chamsAmarelo: return .yellow
        case .chamsVermelho: return .red
        case .chamsRoxo: return .purple
        case .chamsLaranja: return .orange
        case .chamsPreto: return palette.isDark ? .gray : .black
        case .chamsBranco: return palette.isDark ? .white : .gray
        default: return isActive ? palette.accent : palette.secondaryText.opacity(0.9)
        }
    }

    private var iconName: String {
        switch mod {
        case .testePatch: return "eye.fill"
        case .chamsAmarelo, .chamsVermelho, .chamsRoxo, .chamsLaranja, .chamsPreto, .chamsBranco:
            return "circle.fill"
        case .hologramaArmas, .cacheBalaMagica: return "scope"
        case .texturaAlok1, .texturaAlok2, .texturaAlok3: return "paintpalette.fill"
        case .fps144: return "gauge.with.dots.needle.67percent"
        default: return "scope"
        }
    }
}

private struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let disabled: Bool
    let palette: AppPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(disabled ? palette.secondaryText.opacity(0.28) : palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Aims
private struct AimsView: View {
    let game: GameChoice
    @Binding var isDarkMode: Bool
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var fileType: AimFileType = .avatar
    @State private var selectedMods: Set<ModType> = []
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showLogs = false

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }
    private let avatarMods: [ModType] = [.hsAlto, .hsPescoco, .hsPeito]
    private let cacheMods: [ModType] = [.cacheHsAlto, .cacheHsPescoco, .cacheHsPeito, .cacheBalaMagica]

    private var visibleMods: [ModType] { fileType == .avatar ? avatarMods : cacheMods }
    private var activeGameMods: Set<ModType> { modManager.activeMods(for: game.bundleID) }
    private var pendingAvatarMods: [ModType] {
        avatarMods.filter { selectedMods.contains($0) && !activeGameMods.contains($0) }
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 19) {
                    ScreenHeader(
                        title: "Aims",
                        game: game,
                        isDarkMode: $isDarkMode
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(title: "Selecione o tipo de arquivo", palette: palette)
                        Picker("Tipo de arquivo", selection: $fileType) {
                            ForEach(AimFileType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(fileType.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(palette.secondaryText)
                    }
                    .padding(16)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(palette.border, lineWidth: 1))

                    HStack {
                        SectionLabel(title: "Funções \(fileType.rawValue)", palette: palette)
                        Button { showLogs.toggle() } label: {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(palette.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }

                    if showLogs { diagnosticPanel }

                    FunctionListCard(
                        mods: visibleMods,
                        selectedMods: selectedMods,
                        activeMods: activeGameMods,
                        isProcessing: modManager.isProcessing,
                        palette: palette,
                        displayName: { modManager.displayName(for: $0) },
                        onToggle: handleToggle
                    )

                    if fileType == .avatar {
                        HStack(spacing: 12) {
                            PrimaryActionButton(
                                title: "INJETAR (40%)",
                                icon: "bolt.fill",
                                disabled: modManager.isProcessing || pendingAvatarMods.isEmpty,
                                palette: palette,
                                action: injectSelectedMods
                            )
                            PrimaryActionButton(
                                title: "LOBBY",
                                icon: "play.fill",
                                disabled: modManager.isProcessing,
                                palette: palette,
                                action: openLobby
                            )
                        }
                    } else {
                        Text("As funções Cache são aplicadas imediatamente ao ativar o switch.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(palette.secondaryText)
                        PrimaryActionButton(
                            title: "ABRIR LOBBY",
                            icon: "play.fill",
                            disabled: modManager.isProcessing,
                            palette: palette,
                            action: openLobby
                        )
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { selectedMods.formUnion(activeGameMods.filter { avatarMods.contains($0) }) }
        .alert("Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var diagnosticPanel: some View {
        ScrollView {
            Text(modManager.debugLogs.isEmpty ? "Nenhum registro ainda." : modManager.debugLogs)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isDarkMode ? .green : Color(red: 0.02, green: 0.46, blue: 0.19))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 86)
        .padding(13)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private func handleToggle(_ mod: ModType, _ isOn: Bool) {
        if fileType == .cache {
            applyDirectly(mod, isOn: isOn)
            return
        }

        if isOn {
            if let active = activeGameMods.first(where: {
                avatarMods.contains($0) && $0.sectionName == mod.sectionName && $0 != mod
            }) {
                present("Desative \(modManager.displayName(for: active)) antes de selecionar outra função deste grupo.")
                return
            }
            selectedMods = Set(selectedMods.filter {
                $0.sectionName != mod.sectionName || activeGameMods.contains($0)
            })
            selectedMods.insert(mod)
        } else if activeGameMods.contains(mod) {
            modManager.restoreMod(mod, bundleID: game.bundleID) { success, message in
                if success { selectedMods.remove(mod) }
                present(message)
            }
        } else {
            selectedMods.remove(mod)
        }
    }

    private func applyDirectly(_ mod: ModType, isOn: Bool) {
        if isOn {
            modManager.applyMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        } else {
            guard activeGameMods.contains(mod) else {
                selectedMods.remove(mod)
                return
            }
            modManager.restoreMod(mod, bundleID: game.bundleID) { success, message in
                if success { selectedMods.remove(mod) }
                present(message)
            }
        }
    }

    private func injectSelectedMods() {
        let mods = pendingAvatarMods
        guard !mods.isEmpty else { return }
        applySequentially(mods, at: 0, messages: [])
    }

    private func applySequentially(_ mods: [ModType], at index: Int, messages: [String]) {
        guard index < mods.count else {
            present(messages.joined(separator: "\n"))
            return
        }
        let mod = mods[index]
        modManager.applyMod(mod, bundleID: game.bundleID) { _, message in
            applySequentially(
                mods,
                at: index + 1,
                messages: messages + ["\(modManager.displayName(for: mod)): \(message)"]
            )
        }
    }

    private func openLobby() {
        guard fileType == .avatar else {
            openGameFromLobby()
            return
        }
        let activeAvatarMods = avatarMods.filter { activeGameMods.contains($0) }
        restoreAvatarModsAndOpen(activeAvatarMods, at: 0)
    }

    private func restoreAvatarModsAndOpen(_ mods: [ModType], at index: Int) {
        guard index < mods.count else {
            openGameFromLobby()
            return
        }
        modManager.restoreMod(mods[index], bundleID: game.bundleID) { success, message in
            guard success else {
                present(message)
                return
            }
            restoreAvatarModsAndOpen(mods, at: index + 1)
        }
    }

    private func openGameFromLobby() {
        let opened = openApplicationForBundleID(game.bundleID)
        if !opened {
            present("Não foi possível abrir \(game.rawValue). Verifique se o jogo está instalado.")
        }
    }

    private func present(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - ESP
private struct ESPView: View {
    let game: GameChoice
    @Binding var isDarkMode: Bool
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(
                        title: "ESP",
                        game: game,
                        isDarkMode: $isDarkMode
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(palette.accent)
                        Text("AIMBOT + ESP")
                            .font(.system(size: 27, weight: .bold, design: .default))
                            .foregroundColor(palette.primaryText)
                        Text("Aimbot legit com ESP de linha, caixa, nome e vida. Esta função possui uma aba exclusiva para acesso rápido.")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(palette.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [palette.accentSoft, palette.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(palette.border, lineWidth: 1))

                    SectionLabel(title: "Função ESP", palette: palette)
                    FunctionListCard(
                        mods: [.testePatch],
                        selectedMods: [],
                        activeMods: modManager.activeMods(for: game.bundleID),
                        isProcessing: modManager.isProcessing,
                        palette: palette,
                        displayName: { modManager.displayName(for: $0) },
                        onToggle: { mod, enabled in toggle(mod, enabled: enabled) }
                    )

                    Label("OBS: ATIVE ANTES DE ENTRAR NO JOGO", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundColor(palette.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    PrimaryActionButton(
                        title: "ABRIR JOGO",
                        icon: "play.fill",
                        disabled: modManager.isProcessing,
                        palette: palette,
                        action: openSelectedGame
                    )
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("ESP", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func toggle(_ mod: ModType, enabled: Bool) {
        if enabled {
            modManager.applyMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        } else {
            modManager.restoreMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        }
    }

    private func openSelectedGame() {
        let opened = openApplicationForBundleID(game.bundleID)
        if !opened {
            present("Não foi possível abrir \(game.rawValue). Verifique se o jogo está instalado.")
        }
    }

    private func present(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Chams
private struct ChamsView: View {
    let game: GameChoice
    @Binding var isDarkMode: Bool
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }
    private let chamsMods: [ModType] = [
        .chamsAmarelo,
        .chamsVermelho,
        .chamsRoxo,
        .chamsLaranja,
        .chamsPreto,
        .chamsBranco
    ]

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(
                        title: "Chams",
                        game: game,
                        isDarkMode: $isDarkMode
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        Label("HOLOGRAMA ARMAS", systemImage: "paintpalette.fill")
                            .font(.system(size: 23, weight: .bold, design: .default))
                            .foregroundColor(palette.primaryText)
                        Text("Selecione uma cor para aplicar no jogo escolhido. Mantenha apenas uma opção ativa por vez.")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(palette.secondaryText)
                            .lineSpacing(3)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [palette.accentSoft, palette.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(palette.border, lineWidth: 1))

                    SectionLabel(title: "Cores disponíveis", palette: palette)
                    FunctionListCard(
                        mods: chamsMods,
                        selectedMods: [],
                        activeMods: modManager.activeMods(for: game.bundleID),
                        isProcessing: modManager.isProcessing,
                        palette: palette,
                        displayName: { modManager.displayName(for: $0) },
                        onToggle: { mod, enabled in toggle(mod, enabled: enabled) }
                    )
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Chams", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func toggle(_ mod: ModType, enabled: Bool) {
        if enabled {
            modManager.applyMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        } else {
            modManager.restoreMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        }
    }

    private func present(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Textures
private struct TextureOption: Identifiable {
    let mod: ModType
    let imageName: String
    var id: ModType { mod }
}

private struct TexturesView: View {
    let game: GameChoice
    @Binding var isDarkMode: Bool

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(
                        title: "Texturas",
                        game: game,
                        isDarkMode: $isDarkMode
                    )
                    Text("Em breve")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Adjustments
private struct AdjustmentsView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    let game: GameChoice
    @Binding var isDarkMode: Bool
    @StateObject private var modManager = FreeFireModManager.shared
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var palette: AppPalette { AppPalette(isDark: isDarkMode) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(
                        title: "Ajustes",
                        game: game,
                        isDarkMode: $isDarkMode
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Label("AJUSTES", systemImage: "slider.horizontal.3")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(palette.primaryText)
                        Text("Controles extras para o perfil selecionado.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(palette.secondaryText)
                        Text("Perfil: \(game.rawValue)  •  \(game.editionName)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(palette.accent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(palette.border, lineWidth: 1))

                    SectionLabel(title: "Desempenho", palette: palette)
                    FunctionListCard(
                        mods: [.fps144],
                        selectedMods: [],
                        activeMods: modManager.activeMods(for: game.bundleID),
                        isProcessing: modManager.isProcessing,
                        palette: palette,
                        displayName: { _ in "FORÇAR 120/144 FPS" },
                        onToggle: { mod, enabled in toggle(mod, enabled: enabled) }
                    )

                    SectionLabel(title: "Aparência", palette: palette)
                    HStack(spacing: 14) {
                        ThemeToggleButton(isDarkMode: $isDarkMode)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isDarkMode ? "Tema escuro" : "Tema claro")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(palette.primaryText)
                            Text("Toque no ícone para alternar o visual de toda a IPA.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(palette.border, lineWidth: 1))

                    SectionLabel(title: "Licença", palette: palette)
                    HStack(spacing: 13) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(licenseManager.licenseInfo?.status ?? "Key validada")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(palette.primaryText)
                            Text("Expira em: \(licenseManager.licenseInfo?.expiresAt ?? "Não informado")")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(palette.border, lineWidth: 1))

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Ajustes", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func toggle(_ mod: ModType, enabled: Bool) {
        if enabled {
            modManager.applyMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        } else {
            modManager.restoreMod(mod, bundleID: game.bundleID) { _, message in present(message) }
        }
    }

    private func present(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

private func restoreAndOpen(
    game: GameChoice,
    modManager: FreeFireModManager,
    completion: @escaping (String) -> Void
) {
    modManager.restoreActiveModsBeforeLobby(bundleID: game.bundleID) { success, message in
        guard success else {
            completion(message)
            return
        }
        let opened = openApplicationForBundleID(game.bundleID)
        if !opened {
            completion("Não foi possível abrir \(game.rawValue). Verifique se o jogo está instalado.")
        }
    }
}
