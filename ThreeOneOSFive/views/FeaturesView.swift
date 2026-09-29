import SwiftUI

struct FeaturesView: View {
    @Environment(\.appLanguage) private var language

    @State private var aimNeckEnabled = false
    @State private var aimHighEnabled = false
    @State private var aimNeckAntennaEnabled = false
    @State private var hologramWeaponsEnabled = false
    @State private var panelFFH4XEnabled = false
    @State private var appliedProjectIDs: [String: UUID] = [:]
    @State private var busyIDs = Set<String>()
    @State private var featureAlert: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    featureToggleRow("feature.aim_neck", id: .aimNeckHS, icon: "scope", isOn: $aimNeckEnabled)
                    featureToggleRow("feature.aim_high", id: .aimHighHS, icon: "scope", isOn: $aimHighEnabled)
                    featureToggleRow("feature.aim_neck_antenna", id: .aimNeckAntenna, icon: "scope", isOn: $aimNeckAntennaEnabled)
                } header: {
                    groupHeader("feature.aim_group")
                }

                Section {
                    featureToggleRow("feature.hologram_weapons", id: .hologramWeapons, icon: "cube.transparent", isOn: $hologramWeaponsEnabled)
                } header: {
                    groupHeader("feature.hologram_group")
                }

                Section {
                    featureToggleRow("feature.panel_ffh4x", id: .panelFFH4X, icon: "rectangle.3.group", isOn: $panelFFH4XEnabled)
                } header: {
                    groupHeader("feature.panel_group")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("tab.features"))
            .navigationBarTitleDisplayMode(.large)
            .alert(
                language.text("common.failed"),
                isPresented: Binding(
                    get: { featureAlert != nil },
                    set: { if !$0 { featureAlert = nil } }
                )
            ) {
                Button(language.text("common.ok"), role: .cancel) { featureAlert = nil }
            } message: {
                Text(featureAlert.map { language.text($0) } ?? "")
            }
        }
    }

    private func groupHeader(_ key: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white)
                .frame(width: 26, height: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.16), lineWidth: 0.5)
                }
            Text(language.text(key))
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func featureToggleRow(
        _ key: String,
        id: PublishedFunctionID,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(language.text(key))
                    .foregroundStyle(.primary)
            }
        }
        .tint(AppTheme.accent)
        .disabled(busyIDs.contains(id.rawValue))
        .padding(.vertical, 5)
        .accessibilityLabel(language.text(key))
        .accessibilityIdentifier(id.rawValue)
        .onChange(of: isOn.wrappedValue) { _, enabled in
            Task { await handleToggle(id, enabled: enabled, binding: isOn) }
        }
    }

    @MainActor
    private func handleToggle(
        _ id: PublishedFunctionID,
        enabled: Bool,
        binding: Binding<Bool>
    ) async {
        guard !busyIDs.contains(id.rawValue) else { return }
        busyIDs.insert(id.rawValue)
        defer { busyIDs.remove(id.rawValue) }

        do {
            if enabled {
                let status = try await PublishedFunctionCatalog.fetchStatus(for: id)
                guard !status.isInMaintenance else {
                    throw FeatureRemoteError.message("feature.remote_maintenance")
                }
                guard status.available else {
                    throw FeatureRemoteError.message("feature.remote_unavailable")
                }
                guard !status.passwordProtected else {
                    throw FeatureRemoteError.message("feature.remote_password")
                }
                let data = try await PublishedFunctionCatalog.downloadPackage(for: status)
                let decoded = try PatchPackageCodec.decode(data, password: nil)
                _ = try DevicePatchService.apply(project: decoded.project)
                appliedProjectIDs[id.rawValue] = decoded.project.id
            } else {
                guard let projectID = appliedProjectIDs[id.rawValue],
                      let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                    throw FeatureRemoteError.message("feature.remote_unavailable")
                }
                try DevicePatchService.restore(receipt: receipt)
                appliedProjectIDs[id.rawValue] = nil
            }
        } catch let error as FeatureRemoteError {
            binding.wrappedValue = !enabled
            featureAlert = language.text(error.key)
        } catch PublishedFunctionCatalogError.notConfigured {
            binding.wrappedValue = false
            featureAlert = language.text("feature.remote_not_configured")
        } catch PublishedFunctionCatalogError.invalidResponse {
            binding.wrappedValue = false
            featureAlert = language.text("feature.remote_unavailable")
        } catch PublishedFunctionCatalogError.unavailable {
            binding.wrappedValue = false
            featureAlert = language.text("feature.remote_unavailable")
        } catch let error as PatchPackageError {
            binding.wrappedValue = !enabled
            featureAlert = language.text(error.localizationKey)
        } catch {
            binding.wrappedValue = !enabled
            featureAlert = language.text(enabled ? "patch.error.apply" : "patch.error.restore")
        }
    }
}

private enum FeatureRemoteError: Error {
    case message(String)

    var key: String {
        switch self {
        case .message(let key): return key
        }
    }
}
