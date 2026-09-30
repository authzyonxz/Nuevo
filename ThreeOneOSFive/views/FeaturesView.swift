import SwiftUI

struct FeaturesView: View {
    @Environment(\.appLanguage) private var language

    @State private var aimHighEnabled = false
    @State private var aimNeckEnabled = false
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
                        rows: [
                            ("feature.aim_high", "feature.desc_aim_high", PublishedFunctionID.aimHighHS, $aimHighEnabled),
                            ("feature.aim_neck", "feature.desc_aim_neck", PublishedFunctionID.aimNeckHS, $aimNeckEnabled),
                            ("feature.aim_neck_antenna", "feature.desc_aim_neck_antenna", PublishedFunctionID.aimNeckAntenna, $aimNeckAntennaEnabled)
                        ]
                    )

                    featureGroup(
                        titleKey: "feature.hologram_group",
                        rows: [
                            ("feature.hologram_weapons", "feature.desc_hologram_weapons", PublishedFunctionID.hologramWeapons, $hologramWeaponsEnabled)
                        ]
                    )

                    featureGroup(
                        titleKey: "feature.panel_group",
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
        rows: [(String, String, PublishedFunctionID, Binding<Bool>)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.text(titleKey).uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 9)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
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
        var destinationDescription: String?
        log("feature: toggle id=\(id.rawValue) enabled=\(enabled)")

        do {
            if enabled {
                let status = try await PublishedFunctionCatalog.fetchStatus(for: id)
                log("feature: status id=\(id.rawValue) available=\(status.available) maintenance=\(status.isInMaintenance) protected=\(status.passwordProtected)")
                guard !status.isInMaintenance, status.available else {
                    throw FeatureRemoteError.message("feature.remote_maintenance")
                }
                guard !status.passwordProtected else {
                    throw FeatureRemoteError.message("feature.remote_password")
                }
                let data = try await PublishedFunctionCatalog.downloadPackage(for: status)
                log("feature: package downloaded id=\(id.rawValue) bytes=\(data.count)")
                if status.isRawFile {
                    guard let bundleID = status.targetBundleID,
                          let filename = status.targetFilename,
                          !bundleID.isEmpty,
                          !filename.isEmpty else {
                        throw PublishedFunctionCatalogError.invalidResponse
                    }
                    destinationDescription = "\(bundleID)/\(filename) (busca exata)"
                    let receipt = try PublishedRawFileService.apply(
                        data: data,
                        bundleID: bundleID,
                        filename: filename
                    )
                    appliedProjectIDs[id.rawValue] = receipt.projectID
                    log("feature: raw file applied project=\(receipt.projectID.uuidString) destination=\(destinationDescription ?? "none")")
                } else {
                    let decoded = try PatchPackageCodec.decode(data, password: nil)
                    destinationDescription = decoded.project.rules
                        .map { "\($0.bundleID)/\($0.relativePath)" }
                        .joined(separator: ", ")
                    log("feature: decoded project=\(decoded.project.id.uuidString) destination=\(destinationDescription ?? "none")")
                    _ = try DevicePatchService.apply(
                        project: decoded.project,
                        requireExistingTargets: true
                    )
                    appliedProjectIDs[id.rawValue] = decoded.project.id
                    log("feature: apply succeeded project=\(decoded.project.id.uuidString)")
                }
                featureAlert = language.text("feature.injected_success")
                    + "\nDestino: " + (destinationDescription ?? "desconhecido")
            } else {
                guard let projectID = appliedProjectIDs[id.rawValue],
                      let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                    throw FeatureRemoteError.message("feature.restore_unavailable")
                }
                log("feature: restore requested project=\(projectID.uuidString)")
                try DevicePatchService.restore(receipt: receipt)
                appliedProjectIDs[id.rawValue] = nil
                log("feature: restore succeeded project=\(projectID.uuidString)")
                featureAlert = language.text("feature.restored_success")
            }
        } catch let error as FeatureRemoteError {
            log("feature: remote error id=\(id.rawValue) key=\(error.key)")
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            featureAlert = language.text(error.key)
        } catch PublishedFunctionCatalogError.notConfigured,
                PublishedFunctionCatalogError.invalidResponse,
                PublishedFunctionCatalogError.unavailable {
            log("feature: catalog unavailable id=\(id.rawValue)")
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            featureAlert = language.text("feature.remote_maintenance")
        } catch let error as PatchPackageError {
            log("feature: patch error id=\(id.rawValue) key=\(error.localizationKey) destination=\(destinationDescription ?? "unknown")")
            ignoredChanges.insert(id.rawValue)
            binding.wrappedValue = false
            let detail = destinationDescription.map { "\nDestino: \($0)" } ?? ""
            featureAlert = language.text(error.localizationKey) + detail
        } catch {
            log("feature: unexpected error id=\(id.rawValue) error=\(error.localizedDescription)")
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
