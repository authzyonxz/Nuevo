import SwiftUI

struct FeaturesView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var patchStore: PatchProjectStore

    @State private var isEnabled = false
    @State private var isWorking = false
    @State private var featureAlert: FeatureAlert?

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 12) {
                    Text(language.text("feature.test_function"))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 12)
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Toggle(
                            language.text("feature.test_function"),
                            isOn: $isEnabled
                        )
                        .labelsHidden()
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(language.text("feature.test_function"))
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("tab.features"))
            .navigationBarTitleDisplayMode(.large)
            .alert(item: $featureAlert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: alert.messageKey.map { Text(language.text($0)) },
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .onChange(of: isEnabled) { enabled in
                guard !isWorking else { return }
                if enabled {
                    applyTestPatch()
                } else {
                    restoreTestPatch()
                }
            }
        }
    }

    private func applyTestPatch() {
        guard appState.isSupported else {
            isEnabled = false
            featureAlert = FeatureAlert(
                titleKey: "feature.unsupported_title",
                messageKey: "feature.unsupported_message"
            )
            return
        }

        guard let item = patchStore.items.first(where: { $0.project != nil }),
              let baseProject = item.project else {
            isEnabled = false
            featureAlert = FeatureAlert(
                titleKey: "feature.no_patch_title",
                messageKey: "feature.no_patch_message"
            )
            return
        }

        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    patchStore.reload()
                    isWorking = false
                    featureAlert = FeatureAlert(
                        titleKey: "feature.success_title",
                        messageKey: "feature.success_message"
                    )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    isEnabled = false
                    featureAlert = FeatureAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    isEnabled = false
                    featureAlert = FeatureAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.apply"
                    )
                }
            }
        }
    }

    private func restoreTestPatch() {
        guard let item = patchStore.items.first(where: { $0.project != nil }),
              let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
            isEnabled = false
            return
        }

        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    patchStore.reload()
                    isWorking = false
                    featureAlert = FeatureAlert(
                        titleKey: "feature.disabled_title",
                        messageKey: nil
                    )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    isEnabled = true
                    featureAlert = FeatureAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    isEnabled = true
                    featureAlert = FeatureAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.restore"
                    )
                }
            }
        }
    }
}

private struct FeatureAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String?
}
