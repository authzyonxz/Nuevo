import SwiftUI

struct HomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    infoRow(label: language.text("home.key"), value: licenseManager.maskedKey)
                    infoRow(label: language.text("home.duration"), value: durationText)
                    infoRow(label: language.text("home.package"), value: licenseManager.licenseInfo?.productName ?? "—")
                } header: {
                    Text(language.text("home.account"))
                } footer: {
                    Text(language.text("home.example_footer"))
                }

                Section {
                    infoRow(label: language.text("home.ios_version"), value: AppInfo.osVersion)
                    infoRow(label: language.text("home.device"), value: AppInfo.displayMachineName)
                    infoRow(label: language.text("home.build"), value: AppInfo.osBuild)
                } header: {
                    Text(language.text("home.device_information"))
                }

                Section {
                    HStack {
                        Label(
                            appState.exploitStatusText,
                            systemImage: appState.isSystemReady
                                ? "checkmark.shield.fill"
                                : "exclamationmark.shield.fill"
                        )
                        .foregroundStyle(appState.isSystemReady ? .green : .orange)
                        Spacer()
                        Text("\(appState.exploitProgress)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(appState.exploitProgress), total: 100)
                        .tint(appState.isSystemReady ? .green : AppTheme.accent)
                    Button {
                        appState.startExploit()
                    } label: {
                        HStack {
                            if appState.kernelExploitRunning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isSystemReady
                                ? language.text("home.system_ready")
                                : language.text("home.start_exploit"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        appState.kernelExploitRunning
                            || appState.isSystemReady
                            || !appState.isSupported
                    )
                } header: {
                    Text(language.text("home.exploit"))
                } footer: {
                    Text(language.text("home.exploit_footer"))
                }

                Section {
                    Picker(language.text("home.language"), selection: $languageCode) {
                        ForEach([AppLanguage.portuguese, AppLanguage.english]) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text(language.text("home.language"))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("tab.home"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 5)
    }

    private var durationText: String {
        if let days = licenseManager.licenseInfo?.durationDays {
            return "\(days) dias"
        }
        return "—"
    }
}
