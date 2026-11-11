import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class AimViewModel: ObservableObject {
    @Published private(set) var manifests: [String: FunctionPayloadManifest] = [:]
    @Published private(set) var receipts: [String: FunctionPatchReceipt] = [:]
    @Published private(set) var busyFunction: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var serverOnline = false
    @Published var feedback: String?

    private let client = FunctionPatchClient()

    func loadLocalState() {
        receipts = AccessBackend.appliedReceipts()
    }

    func refresh(baseURL: URL) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let items = try await client.catalog(baseURL: baseURL)
            manifests = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            serverOnline = true
            feedback = nil
        } catch {
            serverOnline = false
        }
    }

    func apply(
        _ function: AimFunctionDefinition,
        bundleID: String,
        fallbackBundleID: String?,
        baseURL: URL,
        expectedSHA256: String,
        expectedVersion: Int?,
        originalSha256: String?,
        access: KeyAuthAccess,
        onAccessUpdated: @escaping (KeyAuthAccess) -> Void
    ) async {
        guard busyFunction == nil else { return }
        let typed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = typed.isEmpty ? (fallbackBundleID ?? "") : typed
        guard !target.isEmpty else {
            feedback = "O site ainda não publicou o bundle ID desta função."
            return
        }
        busyFunction = function.id
        feedback = nil
        defer { busyFunction = nil }

        do {
            let validatedAccess = try await KeyAuthClient().revalidate(access)
            guard validatedAccess.keyPreview == access.keyPreview else { throw KeyAuthFailure.invalidGrant }
            onAccessUpdated(validatedAccess)
            let payload = try await client.download(
                functionID: function.id,
                baseURL: baseURL,
                grant: validatedAccess.grant,
                sessionToken: validatedAccess.sessionToken,
                expectedSHA256: expectedSHA256,
                version: expectedVersion
            )
            let receipt = try await Task.detached(priority: .userInitiated) {
                try AccessBackend.apply(
                    functionID: function.id,
                    bundleID: target,
                    payloadURL: payload.fileURL,
                    filename: payload.filename,
                    relativePathHint: payload.relativePath,
                    version: payload.version,
                    originalSha256: originalSha256
                )
            }.value
            receipts[function.id] = receipt
            let route = receipt.backend == .airlift ? "Airlift" : "Kernel"
            feedback = "\(function.title) ativada com sucesso (\(route))."
        } catch let error as KeyAuthFailure {
            feedback = error.userMessage
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch let error as AirliftError {
            feedback = error.errorDescription
        } catch {
            feedback = "Não foi possível ativar \(function.title)."
        }
    }

    func restore(
        _ function: AimFunctionDefinition,
        baseURL: URL?,
        access: KeyAuthAccess,
        force: Bool = false
    ) async {
        guard let receipt = receipts[function.id], busyFunction == nil else { return }
        busyFunction = function.id
        feedback = nil
        defer { busyFunction = nil }

        do {
            try await AccessBackend.restore(
                receipt: receipt,
                baseURL: baseURL,
                access: access,
                force: force
            )
            receipts.removeValue(forKey: function.id)
            feedback = "\(function.title) desativada com sucesso."
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch let error as AirliftError {
            feedback = error.errorDescription
        } catch {
            feedback = "Não foi possível restaurar \(function.title)."
        }
    }
}

struct AimView: View {
    let access: KeyAuthAccess
    let onAccessUpdated: (KeyAuthAccess) -> Void
    let functions: [AimFunctionDefinition]
    let tutorialText: String

    @StateObject private var model = AimViewModel()
    // Mantém a configuração atual intacta; o endereço poderá ser definido internamente depois.
    @AppStorage(AimFunctionConfig.serverURLKey) private var serverURL = AimFunctionConfig.defaultServerURL
    @State private var isNoticePresented = false
    @State private var noticeTitle = ""
    @State private var noticeMessage = ""

    init(
        access: KeyAuthAccess,
        onAccessUpdated: @escaping (KeyAuthAccess) -> Void,
        functions: [AimFunctionDefinition] = AimFunctionCatalog.all.filter { $0.id != "mod-menu" },
        tutorialText: String = "Entre no jogo e aguarde carregar até 40%. Saia do jogo e volte ao External. Ative a função desejada; depois, volte ao jogo e aguarde chegar ao lobby. Assim que entrar, volte rapidamente à IPA e desative a função. Feito isso, é só jogar normalmente."
    ) {
        self.access = access
        self.onAccessUpdated = onAccessUpdated
        self.functions = functions
        self.tutorialText = tutorialText
    }

    private var baseURL: URL? { FunctionPatchClient.normalizedBaseURL(serverURL) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                tutorial
                ForEach(functions) { function in
                    functionCard(function)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .task {
            model.loadLocalState()
            if let baseURL {
                await model.refresh(baseURL: baseURL)
            }
        }
        .overlay {
            if isNoticePresented {
                noticePopup
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isNoticePresented)
        .onChange(of: model.feedback) { feedback in
            guard let feedback else { return }
            let isSuccess = feedback.localizedCaseInsensitiveContains("com sucesso")
            presentNotice(title: isSuccess ? "Concluído" : "Aviso", message: feedback)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("FUNÇÕES")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(model.serverOnline ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 7, height: 7)
                Text(model.serverOnline ? "ONLINE" : "OFFLINE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
        .padding(.bottom, 3)
    }

    private func functionCard(_ function: AimFunctionDefinition) -> some View {
        let receipt = model.receipts[function.id]
        let isActive = receipt != nil
        let busy = model.busyFunction == function.id

        return Button {
            handleTap(function)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: function.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isActive ? Color.green : Color.primary.opacity(0.8))
                    .frame(width: 22, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(function.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(isActive ? "Ativado" : "Desativado")
                            .foregroundStyle(isActive ? Color.green : Color.secondary)
                        Text("·")
                            .foregroundStyle(Color.secondary.opacity(0.75))
                        Text(function.statusLabel)
                            .foregroundStyle(Color.green.opacity(0.8))
                    }
                    .font(.system(size: 12, weight: .medium))
                }

                Spacer(minLength: 4)

                if busy {
                    ProgressView()
                        .tint(AppTheme.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy || model.busyFunction != nil)
        .accessibilityLabel("\(function.title), \(isActive ? "ativado" : "desativado"), \(function.statusLabel)")
        .accessibilityHint(isActive ? "Toque para restaurar o arquivo original" : "Toque para ativar")
    }

    private var tutorial: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TUTORIAL")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.primary)
            Text(tutorialText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func handleTap(_ function: AimFunctionDefinition) {
        model.feedback = nil
        if model.receipts[function.id] != nil {
            Task { await model.restore(function, baseURL: baseURL, access: access) }
            return
        }

        if let activeFunction = functions.first(where: {
            $0.id != function.id && model.receipts[$0.id] != nil
        }) {
            presentNotice(
                title: "Desative a outra função",
                message: "Desative \(activeFunction.title) antes de ativar \(function.title)."
            )
            return
        }

        guard let baseURL else {
            model.feedback = FunctionPatchError.invalidServerURL.errorDescription
            return
        }
        guard let manifest = model.manifests[function.id], manifest.available else {
            presentNotice(
                title: "Arquivo ainda não publicado",
                message: "Ainda não há arquivo publicado para \(function.title). Tente novamente quando estiver disponível."
            )
            return
        }
        // O alvo é sempre resolvido pelo Bundle ID publicado no manifesto.
        // Não use appName/displayName para localizar o container, especialmente
        // no MOD MENU, pois nomes podem mudar ou não ser únicos.
        guard let targetBundleID = manifest.bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !targetBundleID.isEmpty else {
            model.feedback = "O site ainda não publicou o bundle ID de \(function.title)."
            return
        }
        guard let expectedSHA256 = manifest.sha256, expectedSHA256.count == 64 else {
            model.feedback = FunctionPatchError.digestMismatch.errorDescription
            return
        }

        Task {
            await model.apply(
                function,
                bundleID: targetBundleID,
                fallbackBundleID: nil,
                baseURL: baseURL,
                expectedSHA256: expectedSHA256,
                expectedVersion: manifest.version,
                originalSha256: manifest.originalSha256,
                access: access,
                onAccessUpdated: onAccessUpdated
            )
        }
    }

    private var noticePopup: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { dismissNotice() }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(noticeTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(noticeMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: dismissNotice) {
                    Text("Entendi")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
            .padding(.horizontal, 28)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func presentNotice(title: String, message: String) {
        noticeTitle = title
        noticeMessage = message
        isNoticePresented = true
    }

    private func dismissNotice() {
        isNoticePresented = false
    }
}

// MARK: - Cartão de acesso (kernel vs airlift)

@MainActor
final class AirliftAccessModel: ObservableObject {
    @Published private(set) var kind: AccessKind?
    @Published private(set) var pairing: AirliftPairing.Info?
    @Published private(set) var tunnelUp = false
    @Published private(set) var busy = false
    @Published var message: String?

    func refresh() {
        kind = AccessBackend.policyKind
        pairing = AirliftPairing.activeInfo()
        tunnelUp = LoopbackTunnel.isUp()
    }

    @discardableResult
    func importPairing(_ url: URL) -> AirliftPairing.Info? {
        do {
            let info = try AirliftPairing.importFile(from: url)
            pairing = info
            message = "Pairing carregado: \(info.deviceName)."
            refresh()
            return info
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Falha ao importar pairing."
            return nil
        }
    }

    func pairOnDevice() async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            let info = try await OnDevicePairing.shared.startAndWait()
            pairing = info
            message = "Pareado com sucesso: \(info.deviceName)."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Pareamento falhou."
        }
        refresh()
    }

    func removePairing() {
        AirliftPairing.deleteActive()
        pairing = nil
        message = "Pairing removido."
        refresh()
    }

    @discardableResult
    func adoptFirstCandidate() -> AirliftPairing.Info? {
        guard let first = AirliftPairing.discoverCandidates().first else {
            message = "Nenhum pairing file encontrado em On My iPhone/3105."
            return nil
        }
        return importPairing(first)
    }

    func testAccess(bundleID: String) async {
        guard !busy else { return }
        busy = true
        message = "Testando Airlift em \(bundleID)…"
        defer { busy = false }

        do {
            let pairingPath = try AccessBackend.requireAirliftReady()
            let container = try await Task.detached(priority: .userInitiated) {
                try Airlift.findContainer(pairingPath: pairingPath, bundleID: bundleID)
            }.value
            _ = try await Task.detached(priority: .userInitiated) {
                try Airlift.runCanary(pairingPath: pairingPath, target: container)
            }.value
            message = "Airlift OK — escrita confirmada em \(bundleID)."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Airlift falhou."
        }
    }
}

@MainActor
final class ComputerPairingModel: ObservableObject {
    @Published private(set) var pin: String?
    @Published private(set) var status = "Nenhuma sessão iniciada"
    @Published private(set) var connectedInfo: AirliftPairing.Info?

    func start() {
        let value = Int.random(in: 100_000...999_999)
        pin = String(format: "%06d", value)
        connectedInfo = nil
        status = "Aguardando o helper do computador…"
    }

    func confirmConnection(_ info: AirliftPairing.Info) {
        connectedInfo = info
        status = "Conexão confirmada. Pairing pronto para o Airlift."
    }

    func reset() {
        pin = nil
        connectedInfo = nil
        status = "Nenhuma sessão iniciada"
    }
}

struct AirliftAccessCard: View {
    @StateObject private var model = AirliftAccessModel()
    @ObservedObject private var pairingHost = OnDevicePairing.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("ROTA DE ACESSO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(badgeTitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(badgeColor)
            }

            row(
                symbol: model.tunnelUp ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: model.tunnelUp ? .green : .orange,
                title: "Túnel loopback",
                detail: model.tunnelUp ? "10.7.0.1 ativo" : "LocalDevVPN desligado"
            )

            row(
                symbol: model.pairing == nil ? "xmark.circle.fill" : "checkmark.circle.fill",
                tint: model.pairing == nil ? .orange : .green,
                title: "Pairing record",
                detail: model.pairing.map { "\($0.deviceName) · \($0.byteCount) bytes" } ?? "nenhum pairing importado"
            )

            if let pin = pairingHost.pin {
                Text("PIN \(pin) — Ajustes › Modo Desenvolvedor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            if pairingHost.running {
                Text(pairingHost.status)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = model.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.kind == .airlift, model.pairing != nil {
                Label("Airlift conectado com sucesso", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                actionButton(
                    model.kind == .airlift
                        ? (model.tunnelUp ? "Conectar Airlift" : "Ativar conexão local")
                        : "Conectar Airlift",
                    symbol: model.tunnelUp ? "iphone" : "network"
                ) {
                    guard model.kind == .airlift else {
                        model.message = "A conexão Airlift local só está disponível nas versões iOS 27 compatíveis."
                        return
                    }
                    if model.tunnelUp {
                        Task { await model.pairOnDevice() }
                    } else {
                        LoopbackTunnel.openVPNApp()
                    }
                }
            }

            if model.kind != .kernel {
                Text("Airlift grava sem ler: o restore baixa o arquivo original publicado pelo site. Mantenha o Apple Books instalado e aberto ao menos uma vez.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemBackground).opacity(0.7),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 0.7)
        )
        .task { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }

    private var badgeTitle: String {
        switch model.kind {
        case .kernel: return "KERNEL"
        case .airlift: return "AIRLIFT"
        case nil: return "SEM ROTA"
        }
    }

    private var badgeColor: Color {
        switch model.kind {
        case .kernel: return .blue
        case .airlift: return .green
        case nil: return .orange
        }
    }

    private func row(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(.secondary)
            .padding(.top, 3)
    }

    private func actionButton(
        _ title: String,
        symbol: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.busy)
    }
}

private struct ComputerPairingSheet: View {
    @ObservedObject var model: ComputerPairingModel
    let onCheckConnection: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("PAREAR COM COMPUTADOR", systemImage: "desktopcomputer")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Use o código abaixo no helper 3105 Pairing. O arquivo será enviado para o app por USB e o Airlift poderá usar a conexão.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let pin = model.pin {
                        let statusColor: Color = model.connectedInfo == nil ? .secondary : .green
                        VStack(spacing: 8) {
                            Text("CÓDIGO DE PAREAMENTO")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(.secondary)
                            Text(pin)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .tracking(4)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                            Text(model.status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(statusColor)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.28), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        pairingStep("1", "Conecte o iPhone ao computador por USB e desbloqueie-o.")
                        pairingStep("2", "Aceite “Confiar neste computador” no iPhone, se aparecer.")
                        pairingStep("3", "Execute o helper com o código mostrado: python tools/3105-pairing-helper/3105_pairing_helper.py --pin \(model.pin ?? "000000").")
                        pairingStep("4", "Depois toque em “Verificar conexão” para importar o pairing e confirmar o Airlift.")
                    }

                    if let info = model.connectedInfo {
                        Label {
                            Text("Conectado: \(info.deviceName) · \(info.byteCount) bytes")
                                .font(.system(size: 13, weight: .semibold))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundStyle(.green)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: onCheckConnection) {
                        Label(model.connectedInfo == nil ? "Verificar conexão" : "Atualizar confirmação", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(20)
            }
            .navigationTitle("Pareamento")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pairingStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange, in: Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
