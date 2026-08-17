import SwiftUI

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(language.text("settings.app_version"), value: "1.0.1 (5)")
                    LabeledContent("iOS", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                } header: {
                    Text(language.text("settings.device_info"))
                }

                Section {
                    HStack {
                        Text(language.text("settings.current_version"))
                        Spacer()
                        Label(
                            language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                            systemImage: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(appState.isSupported ? Color.green : Color.red)
                    }
                    LabeledContent("iOS 15 - 18+", value: "Universal Support")
                } header: {
                    Text(language.text("settings.verified_versions"))
                } footer: {
                    Text("O aplicativo agora possui suporte ampliado para iOS 18 e versões superiores.")
                }
            }
            .tint(AppTheme.accent)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
