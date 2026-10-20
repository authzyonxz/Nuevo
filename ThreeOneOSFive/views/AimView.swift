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
        baseURL: URL
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
            feedback = "\(function.title) ativado."
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
            feedback = "\(function.title) desativado; arquivo original restaurado."
        } catch let error as FunctionPatchError {
            feedback = error.errorDescription
        } catch {
            feedback = "Não foi possível restaurar \(function.title)."
        }
    }
}

struct AimView: View {
    @StateObject private var model = AimViewModel()
    // Mantém a configuração atual intacta; o endereço poderá ser definido internamente depois.
    @AppStorage(AimFunctionConfig.serverURLKey) private var serverURL = AimFunctionConfig.defaultServerURL
    @State private var showActivationAlert = false
    @State private var activationAlertMessage = ""

    private var baseURL: URL? { FunctionPatchClient.normalizedBaseURL(serverURL) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                ForEach(AimFunctionCatalog.all) { function in
                    functionCard(function)
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.pageBackground)
        .task {
            model.loadLocalState()
            if let baseURL {
                await model.refresh(baseURL: baseURL)
            }
        }
        .alert("Desative a outra função", isPresented: $showActivationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(activationAlertMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("AIM")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(2.5)
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
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.green.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
                    Image(systemName: function.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isActive ? Color.green : Color.primary.opacity(0.8))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(function.title)
                        .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 13, weight: .medium))
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
            .padding(.horizontal, 16)
            .frame(minHeight: 82)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy || model.busyFunction != nil)
        .accessibilityLabel("\(function.title), \(isActive ? "ativado" : "desativado"), \(function.statusLabel)")
        .accessibilityHint(isActive ? "Toque para restaurar o arquivo original" : "Toque para ativar")
    }

    private func handleTap(_ function: AimFunctionDefinition) {
        if model.receipts[function.id] != nil {
            Task { await model.restore(function) }
            return
        }

        if let activeFunction = AimFunctionCatalog.all.first(where: {
            $0.id != function.id && model.receipts[$0.id] != nil
        }) {
            activationAlertMessage = "Desative \(activeFunction.title) antes de ativar \(function.title)."
            showActivationAlert = true
            return
        }

        guard let baseURL else {
            model.feedback = FunctionPatchError.invalidServerURL.errorDescription
            return
        }
        guard let manifest = model.manifests[function.id], manifest.available else {
            model.feedback = "Esta função ainda não está disponível."
            return
        }

        Task {
            await model.apply(
                function,
                bundleID: "",
                fallbackBundleID: manifest.bundleID,
                baseURL: baseURL
            )
        }
    }

    private var footer: some View {
        Group {
            if let feedback = model.feedback {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accent)
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.top, 4)
    }
}
