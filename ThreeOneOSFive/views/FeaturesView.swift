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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    featureGroup(
                        number: "01",
                        titleKey: "feature.aim_group",
                        subtitle: "feature.group_aim_subtitle",
                        rows: [
                            ("feature.aim_neck", PublishedFunctionID.aimNeckHS, $aimNeckEnabled),
                            ("feature.aim_high", PublishedFunctionID.aimHighHS, $aimHighEnabled),
                            ("feature.aim_neck_antenna", PublishedFunctionID.aimNeckAntenna, $aimNeckAntennaEnabled)
                        ]
                    )

                    featureGroup(
                        number: "02",
                        titleKey: "feature.hologram_group",
                        subtitle: "feature.group_hologram_subtitle",
                        rows: [
                            ("feature.hologram_weapons", PublishedFunctionID.hologramWeapons, $hologramWeaponsEnabled)
                        ]
                    )

                    featureGroup(
                        number: "03",
                        titleKey: "feature.panel_group",
                        subtitle: "feature.group_panel_subtitle",
                        rows: [
                            ("feature.panel_ffh4x", PublishedFunctionID.panelFFH4X, $panelFFH4XEnabled)
                        ]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppTheme.pageBackground)
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

    private func featureGroup(
        number: String,
        titleKey: String,
        subtitle: String,
        rows: [(String, PublishedFunctionID, Binding<Bool>)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.pageBackground)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text(titleKey))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(language.text(subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.1.rawValue) { index, row in
                    featureToggleRow(row.0, id: row.1, isOn: row.2)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.28), lineWidth: 0.7)
        }
    }

    private func featureToggleRow(
        _ key: String,
        id: PublishedFunctionID,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(language.text(key))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(AppTheme.accent)
        .disabled(busyIDs.contains(id.rawValue))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityLabel(language.text(key))
        .accessibilityIdentifier(id.rawValue)
        .onChange(of: isOn.wrappedValue) { enabled in
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
