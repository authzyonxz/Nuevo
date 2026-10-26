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
        }
    }

    func apply(
        _ function: AimFunctionDefinition,
        bundleID: String,
        fallbackBundleID: String?,
        baseURL: URL,
        expectedSHA256: String,
        expectedVersion: Int?,
        access: KeyAuthAccess,
        onAccessUpdated: @escaping (KeyAuthAccess) -> Void
    ) async {
        guard busyFunction == nil else { return }
        guard ExploitSupportPolicy.isSupported(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        ) else {
            feedback = FunctionPatchError.incompatibleIOS(
                version: AppInfo.osVersion,
                build: AppInfo.osBuild
            ).errorDescription
            return
        }
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
                try FunctionPatchStore.apply(
                    functionID: function.id,
                    bundleID: target,
                    payloadURL: payload.fileURL,
                    filename: payload.filename,
                    relativePathHint: payload.relativePath
                )
            }.value
            receipts[function.id] = receipt
            feedback = "\(function.title) ativada com sucesso."
        } catch let error as KeyAuthFailure {
            feedback = error.userMessage
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch {
            feedback = "Não foi possível ativar \(function.title)."
        }
    }

    func restore(_ function: AimFunctionDefinition, force: Bool = false) async {
        guard let receipt = receipts[function.id], busyFunction == nil else { return }
        busyFunction = function.id
        feedback = nil
        defer { busyFunction = nil }

        do {
            try await Task.detached(priority: .userInitiated) {
                try FunctionPatchStore.restore(receipt: receipt, allowChangedTargets: force)
            }.value
            receipts.removeValue(forKey: function.id)
            feedback = "\(function.title) desativada com sucesso."
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch {
            feedback = "Não foi possível restaurar \(function.title)."
        }
    }
}

struct AimView: View {
    let access: KeyAuthAccess
    let onAccessUpdated: (KeyAuthAccess) -> Void

    @StateObject private var model = AimViewModel()
    // Mantém a configuração atual intacta; o endereço poderá ser definido internamente depois.
    @AppStorage(AimFunctionConfig.serverURLKey) private var serverURL = AimFunctionConfig.defaultServerURL
    @State private var isNoticePresented = false
    @State private var noticeTitle = ""
    @State private var noticeMessage = ""

    private var baseURL: URL? { FunctionPatchClient.normalizedBaseURL(serverURL) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                tutorial
                ForEach(AimFunctionCatalog.all) { function in
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
            Text("Entre no jogo e aguarde carregar até 40%. Saia do jogo e volte ao External. Ative a função desejada; depois, volte ao jogo e aguarde chegar ao lobby. Assim que entrar, volte rapidamente à IPA e desative a função. Feito isso, é só jogar normalmente.")
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
            Task { await model.restore(function) }
            return
        }

        if let activeFunction = AimFunctionCatalog.all.first(where: {
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
        guard let expectedSHA256 = manifest.sha256, expectedSHA256.count == 64 else {
            model.feedback = FunctionPatchError.digestMismatch.errorDescription
            return
        }

        Task {
            await model.apply(
                function,
                bundleID: "",
                fallbackBundleID: manifest.bundleID,
                baseURL: baseURL,
                expectedSHA256: expectedSHA256,
                expectedVersion: manifest.version,
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
