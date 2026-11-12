// language: Swift, file: ConfigView.swift, target: iOS 17+
//
// Aba CONFIG: mostra a rota de acesso do aparelho e concentra a conexão do
// Airlift (pareamento on-device + túnel de loopback). É a única tela onde o
// usuário do iOS 27 faz alguma configuração.

import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ConfigView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("CONFIG")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .padding(.top, 12)

                AccessRouteCard()
                AirliftAccessCard()
                DeviceInfoCard()
                AccessMatrixCard()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Rota de acesso

struct AccessRouteCard: View {
    @State private var kind: AccessKind?
    @State private var ready = false
    @State private var detail = ""

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

            if let kind {
                Text(ExploitSupportPolicy.accessRangeLabel(kind: kind))
                    .font(.system(size: 15, weight: .semibold))

                Text(ExploitSupportPolicy.accessDescription(kind: kind))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Circle()
                        .fill(ready ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(ready ? "Pronto para aplicar" : "Acesso ainda não estabelecido")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ready ? Color.green : Color.orange)
                }

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.system(size: 15, weight: .semibold))
                Text(AirliftError.unsupportedVersion(AppInfo.osVersion).errorDescription ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
        .task { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        let availability = AccessBackend.availability()
        kind = availability.policyKind
        ready = availability.isReady

        switch availability.policyKind {
        case .kernel, .badQuery:
            detail = availability.kernelActive
                ? "Kernel ativo — leitura e escrita no container do app alvo."
                : "Kernel ainda não executado. Ele roda automaticamente ao abrir o app."
        case .airlift:
            detail = availability.airliftReady
                ? "Pareamento e túnel ativos."
                : "Falta pareamento ou túnel. Resolva abaixo."
        case nil:
            detail = ""
        }
    }

    private var badgeTitle: String {
        switch kind {
        case .kernel: return "KERNEL"
        case .badQuery: return "BAD_QUERY"
        case .airlift: return "AIRLIFT"
        case nil: return "SEM ROTA"
        }
    }

    private var badgeColor: Color {
        switch kind {
        case .kernel: return .blue
        case .badQuery: return .purple
        case .airlift: return .green
        case nil: return .orange
        }
    }
}

// MARK: - Conexão Airlift

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

    func importPairing(_ url: URL) {
        do {
            let info = try AirliftPairing.importFile(from: url)
            pairing = info
            message = "Pairing carregado: \(info.deviceName)."
            refresh()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Falha ao importar pairing."
        }
    }

    func importBase64(_ text: String) {
        do {
            let info = try AirliftPairing.importBase64(text)
            pairing = info
            message = "Pairing carregado: \(info.deviceName)."
            refresh()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Código inválido."
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

    func adoptFirstCandidate() {
        guard let first = AirliftPairing.discoverCandidates().first else {
            message = "Nenhum pairing file encontrado em On My iPhone/3105."
            return
        }
        importPairing(first)
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

struct AirliftAccessCard: View {
    @StateObject private var model = AirliftAccessModel()
    @ObservedObject private var pairingHost = OnDevicePairing.shared
    @State private var importing = false
    @State private var pasting = false
    @State private var pastedText = ""

    private var testBundleID: String {
        let stored = UserDefaults.standard.string(forKey: AimFunctionConfig.bundleIDKey) ?? ""
        return stored.isEmpty ? "com.dts.freefireth" : stored
    }

    private var isAirlift: Bool { model.kind == .airlift }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("CONEXÃO AIRLIFT")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isAirlift ? "ATIVA NESTE iOS" : "SÓ iOS 27")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isAirlift ? Color.green : Color.secondary).opacity(0.16), in: Capsule())
                    .foregroundStyle(isAirlift ? Color.green : Color.secondary)
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
                detail: model.pairing.map { "\($0.deviceName) · \($0.byteCount) bytes" } ?? "nenhum pairing ativo"
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

            if isAirlift {
                HStack(spacing: 8) {
                    actionButton("Parear iPhone") { Task { await model.pairOnDevice() } }
                    actionButton("Testar") { Task { await model.testAccess(bundleID: testBundleID) } }
                    actionButton(model.tunnelUp ? "Túnel ativo" : "Abrir VPN") {
                        LoopbackTunnel.openVPNApp()
                    }
                }

                HStack(spacing: 8) {
                    actionButton("Importar pairing") { importing = true }
                    actionButton("Colar código") { pasting = true }
                    actionButton("Procurar pairing") { model.adoptFirstCandidate() }
                }

                if model.pairing != nil {
                    actionButton("Remover pairing") { model.removePairing() }
                }

                Text("O pareamento acontece no próprio iPhone: toque em Parear iPhone, veja o PIN e confirme em Ajustes › Privacidade e Segurança › Modo Desenvolvedor. Nada de cabo, nada de PC.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Sua versão não usa Airlift. O pareamento só é necessário no iOS 27.0–27.2 beta 2; aqui o acesso é pelo kernel.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
        .task {
            model.refresh()
            _ = AirliftPairing.autoAdoptIfNeeded()
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            model.importPairing(url)
        }
        .sheet(isPresented: $pasting) { pasteSheet }
    }

    private var pasteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cole o código base64 do pairing record.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                TextEditor(text: $pastedText)
                    .font(.system(size: 11, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 170)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.7)
                    )

                Button {
                    model.importBase64(pastedText)
                    pastedText = ""
                    pasting = false
                } label: {
                    Text("Importar")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Colar pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { pasting = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 32)
                .padding(.horizontal, 6)
                .background(
                    Color(uiColor: .tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.busy)
    }
}

// MARK: - Aparelho

struct DeviceInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APARELHO")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            line("iOS", "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
            line("Modelo", AppInfo.displayMachineName)
            line("LocalDevVPN", LoopbackTunnel.isUp() ? "ligado" : "desligado")
        }
        .cardStyle()
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Matriz

struct AccessMatrixCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VERSÕES SUPORTADAS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            matrixRow("17.0 – 18.7.2", "kernel", .blue)
            matrixRow("26.0 – 26.6.2", "bad_query", .purple)
            matrixRow("27.0 – 27.2 beta 3", "airlift (sem PC)", .green)
            matrixRow("27.2 beta 4+", "não testado", .orange)
        }
        .cardStyle()
    }

    private func matrixRow(_ range: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(range)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 130, alignment: .leading)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Estilo

private extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.065),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}
