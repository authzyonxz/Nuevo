import SwiftUI

struct HomeView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    infoRow(label: language.text("home.key"), value: "EXEMPLO-KEY-0000")
                    infoRow(label: language.text("home.duration"), value: "30 dias")
                    infoRow(label: language.text("home.package"), value: "Exemplo de package")
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
}
