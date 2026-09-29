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
    @State private var ignoredChanges = Set<String>()
    @State private var featureAlert: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(language.text("feature.group_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 4)

                    featureGroup(
                        titleKey: "feature.aim_group",
                        subtitle: "feature.group_aim_subtitle",
                        rows: [
                            ("feature.aim_high", "feature.desc_aim_high", PublishedFunctionID.aimHighHS, $aimHighEnabled),
                            ("feature.aim_neck_antenna", "feature.desc_aim_neck_antenna", PublishedFunctionID.aimNeckAntenna, $aimNeckAntennaEnabled),
                            ("feature.aim_neck", "feature.desc_aim_neck", PublishedFunctionID.aimNeckHS, $aimNeckEnabled)
                        ]
                    )

                    featureGroup(
                        titleKey: "feature.hologram_group",
                        subtitle: "feature.group_hologram_subtitle",
                        rows: [
                            ("feature.hologram_weapons", "feature.desc_hologram_weapons", PublishedFunctionID.hologramWeapons, $hologramWeaponsEnabled)
                        ]
                    )

                    featureGroup(
                        titleKey: "feature.panel_group",
                        subtitle: "feature.group_panel_subtitle",
                        rows: [
                            ("feature.panel_ffh4x", "feature.desc_panel_ffh4x", PublishedFunctionID.panelFFH4X, $panelFFH4XEnabled)
                        ]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationBarHidden(true)
            .alert(
                language.text("feature.alert_title"),
                isPresented: Binding(
                    get: { featureAlert != nil },
                    set: { if !$0 { featureAlert = nil } }
                )
            ) {
                Button(language.text("common.ok"), role: .cancel) { featureAlert = nil }
            } message: {
                Text(featureAlert ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func featureGroup(
        titleKey: String,
        subtitle: String,
        rows: [(String, String, PublishedFunctionID, Binding<Bool>)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text(titleKey).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Text(language.text(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 9)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.2.rawValue) { index, row in
                    featureToggleRow(row.0, descriptionKey: row.1, id: row.2, isOn: row.3)
                    if index < rows.count - 1 {
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 16)
                    }
                }
            }
            .background(Color(white: 0.075), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
            }
        }
    }

    private func featureToggleRow(
        _ key: String,
        descriptionKey: String,
        id: PublishedFunctionID,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text(key))
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                Text(language.text(descriptionKey))
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(.white)
        .disabled(busyIDs.contains(id.rawValue))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityLabel(language.text(key))
        .accessibilityIdentifier(id.rawValue)
        .onChange(of: isOn.wrappedValue) { enabled in
            if ignoredChanges.remove(id.rawValue) != nil { return }
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
                guard !status.isInMaintenance, status.available else {
                    throw FeatureRemoteError.message("feature.remote_maintenance")
                }
                guard !status.passwordProtected else {
                    throw FeatureRemoteError.message("feature.remote_password")
                }
                let data = try await PublishedFunctionCatalog.downloadPackage(for: status)
                let decoded = try PatchPackageCodec.decode(data, password: nil)
                _ = try DevicePatchService.apply(project: decoded.project)
                appliedProjectIDs[id.rawValue] = decoded.project.id
                featureAlert = language.text("feature.injected_success")
            } else {
                guard let projectID = appliedProjectIDs[id.rawValue],
                      let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                    throw FeatureRemoteError.message("feature.restore_unavailable")
                }
                try DevicePatchService.restore(receipt: receipt)
                appliedProjectIDs[id.rawValue] = nil
                featureAlert = language.text("feature.restored_success")
            }
        } catch let error as FeatureRemoteError {
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            featureAlert = language.text(error.key)
        } catch PublishedFunctionCatalogError.notConfigured,
                PublishedFunctionCatalogError.invalidResponse,
                PublishedFunctionCatalogError.unavailable {
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            featureAlert = language.text("feature.remote_maintenance")
        } catch let error as PatchPackageError {
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            featureAlert = language.text(error.localizationKey)
        } catch {
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
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
