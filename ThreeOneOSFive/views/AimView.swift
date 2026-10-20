import SwiftUI
import UIKit

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
        receipts = FunctionPatchStore.appliedReceipts()
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
            feedback = (error as? LocalizedError)?.errorDescription ?? "Falha ao consultar o site."
        }
    }

    func apply(
        _ function: AimFunctionDefinition,
        bundleID: String,
        fallbackBundleID: String?,
        baseURL: URL
    ) async {
        guard busyFunction == nil else { return }
        let typed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        // O bundle ID digitado no app vence; senão usa o que foi publicado no site.
        let target = typed.isEmpty ? (fallbackBundleID ?? "") : typed
        guard !target.isEmpty else {
            feedback = "Digite o bundle ID alvo antes de aplicar (ex: com.dts.freefireth)."
            return
        }
        busyFunction = function.id
        feedback = nil
        defer { busyFunction = nil }

        do {
            let payload = try await client.download(functionID: function.id, baseURL: baseURL)
            let receipt = try await Task.detached(priority: .userInitiated) {
                try FunctionPatchStore.apply(
                    functionID: function.id,
                    bundleID: target,
                    payloadURL: payload.fileURL,
                    filename: payload.filename,
                    relativePathHint: payload.relativePath
                )
            }.value
            receipts[function.id] = receipt
            feedback = "\(function.title) aplicado (v\(payload.version)) — "
                + "\(receipt.fileCount) arquivo(s) substituído(s) em \(receipt.bundleID)."
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch {
            feedback = "Falha inesperada ao aplicar \(function.title)."
        }
    }

    func restore(_ function: AimFunctionDefinition, force: Bool) async {
        guard let receipt = receipts[function.id], busyFunction == nil else { return }
        busyFunction = function.id
        feedback = nil
        defer { busyFunction = nil }

        do {
            try await Task.detached(priority: .userInitiated) {
                try FunctionPatchStore.restore(receipt: receipt, allowChangedTargets: force)
            }.value
            receipts.removeValue(forKey: function.id)
            feedback = "\(function.title) restaurado — o arquivo original voltou."
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch {
            feedback = "Falha inesperada ao restaurar \(function.title)."
        }
    }
}

struct AimView: View {
    @StateObject private var model = AimViewModel()
    @AppStorage(AimFunctionConfig.serverURLKey) private var serverURL = AimFunctionConfig.defaultServerURL
    @AppStorage(AimFunctionConfig.bundleIDKey) private var bundleID = ""
    @State private var showServerField = false

    private var baseURL: URL? { FunctionPatchClient.normalizedBaseURL(serverURL) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                serverCard
                bundleCard
                ForEach(AimFunctionCatalog.all) { function in
                    functionCard(function)
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .task {
            model.loadLocalState()
            if let baseURL {
                await model.refresh(baseURL: baseURL)
            }
        }
        .onChange(of: model.manifests) { manifests in
            guard bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let published = AimFunctionCatalog.all
                .compactMap { manifests[$0.id]?.bundleID }
                .first { !$0.isEmpty }
            if let published {
                bundleID = published
            }
        }
    }

    // MARK: - header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("AIM")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white)
                Text("Payloads do site aplicados direto no container")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(model.serverOnline ? Color(red: 0.44, green: 0.92, blue: 0.62) : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(model.serverOnline ? "SITE ON" : "SITE OFF")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
        .padding(.top, 6)
    }

    // MARK: - servidor

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Servidor")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(showServerField ? "endereço do site que guarda os payloads" : (baseURL?.absoluteString ?? "não configurado"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showServerField.toggle() }
                } label: {
                    Image(systemName: showServerField ? "checkmark" : "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showServerField ? "Concluir edição do servidor" : "Editar servidor")

                Button {
                    guard let baseURL else {
                        model.feedback = FunctionPatchError.invalidServerURL.errorDescription
                        return
                    }
                    Task { await model.refresh(baseURL: baseURL) }
                } label: {
                    Group {
                        if model.isRefreshing {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshing)
                .accessibilityLabel("Atualizar funções do site")
            }

            if showServerField {
                TextField("https://aim.seudominio.com", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)
                    .tint(AppTheme.accent)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        guard let baseURL else { return }
                        Task { await model.refresh(baseURL: baseURL) }
                    }
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    // MARK: - bundle id

    private var bundleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Bundle ID alvo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("aplicado no container desse app")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }
            TextField("com.dts.freefireth", text: $bundleID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .tint(AppTheme.accent)
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .padding(13)
        .background(cardBackground)
    }

    // MARK: - função

    private func functionCard(_ function: AimFunctionDefinition) -> some View {
        let manifest = model.manifests[function.id]
        let receipt = model.receipts[function.id]
        let busy = model.busyFunction == function.id

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                AppRowIcon(systemName: function.symbol, tint: AppTheme.accent, symbolSize: 17, frameSize: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(function.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(function.summary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text(function.statusLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color(red: 0.44, green: 0.92, blue: 0.62))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.44, green: 0.92, blue: 0.62).opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule().stroke(Color(red: 0.44, green: 0.92, blue: 0.62).opacity(0.28), lineWidth: 1)
                    )
            }

            HStack(spacing: 8) {
                Text(function.id)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(AppTheme.accent.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Spacer(minLength: 4)
                Text(payloadLine(manifest))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let receipt {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.44, green: 0.92, blue: 0.62))
                    Text(
                        "aplicado · \(receipt.fileCount) arquivo(s) · "
                        + receipt.appliedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button {
                    guard let baseURL else {
                        model.feedback = FunctionPatchError.invalidServerURL.errorDescription
                        return
                    }
                    Task {
                        await model.apply(
                            function,
                            bundleID: bundleID,
                            fallbackBundleID: manifest?.bundleID,
                            baseURL: baseURL
                        )
                    }
                } label: {
                    HStack(spacing: 7) {
                        if busy {
                            ProgressView().tint(.black).scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(busy ? "APLICANDO…" : "APLICAR")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.1)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(busy || manifest?.available != true)
                .opacity(manifest?.available == true ? 1 : 0.45)
                .accessibilityLabel("Aplicar \(function.title)")

                Menu {
                    Button(role: .destructive) {
                        Task { await model.restore(function, force: false) }
                    } label: {
                        Label("Restaurar original", systemImage: "arrow.uturn.backward")
                    }
                    Button {
                        Task { await model.restore(function, force: true) }
                    } label: {
                        Label("Forçar restauração", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(receipt == nil ? 0.25 : 0.85))
                        .frame(width: 40, height: 38)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .disabled(receipt == nil || busy)
                .accessibilityLabel("Restaurar \(function.title)")
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    private func payloadLine(_ manifest: FunctionPayloadManifest?) -> String {
        guard let manifest else { return "site não consultado" }
        guard manifest.available, let version = manifest.version, let filename = manifest.filename else {
            return "sem arquivo publicado"
        }
        return "v\(version) · \(filename)"
    }

    // MARK: - rodapé

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let feedback = model.feedback {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                    Text(feedback)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("O app varre o container inteiro do bundle ID atrás do arquivo publicado, guarda backup do original e só então substitui. Restaurar devolve o original.")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.32))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
