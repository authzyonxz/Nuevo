import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ZyvexSectionTitle(title: "Device & Access")
                    ZyvexCard {
                        HStack(spacing: 14) {
                            AppLogo(size: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Zyvex")
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                                Text("Private device workspace")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer()
                        }
                    }

                    ZyvexCard {
                        VStack(spacing: 0) {
                            settingsRow(icon: "checkmark.shield.fill", title: "Product", value: "Zyvex")
                            Divider().overlay(AppTheme.border)
                            settingsRow(icon: "info.circle.fill", title: "Version", value: appVersion)
                        }
                    }

                    ZyvexSectionTitle(title: "License")
                    ZyvexCard {
                        VStack(spacing: 0) {
                            licenseRow(icon: "checkmark.seal.fill", title: "Status", value: "Activated", valueColor: AppTheme.success)
                            Divider().overlay(AppTheme.border)
                            licenseRow(icon: "calendar.badge.clock", title: "Expiry", value: appState.activeLicense?.expiresAt ?? "N/A")
                            Divider().overlay(AppTheme.border)
                            licenseRow(icon: "person.2.fill", title: "Product", value: appState.activeLicense?.productName ?? "Painel iPA")
                            Divider().overlay(AppTheme.border)
                            licenseRow(icon: "number", title: "Key fingerprint", value: appState.activeLicense?.keyFingerprint ?? "N/A", monospaced: true)
                            
                            Button("Deactivate", role: .destructive) {
                                LicenseService.shared.logout()
                                withAnimation {
                                    appState.deactivate()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .tint(AppTheme.destructive)
                            .padding(.top, 16)
                        }
                    }

                    ZyvexSectionTitle(title: "Device Information")
                    ZyvexCard {
                        VStack(spacing: 0) {
                            settingsRow(icon: "iphone", title: "Device model", value: AppInfo.displayMachineName)
                            Divider().overlay(AppTheme.border)
                            settingsRow(icon: "gearshape.2.fill", title: "iOS version", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                            Divider().overlay(AppTheme.border)
                            licenseRow(
                                icon: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill",
                                title: "Compatibility",
                                value: appState.isSupported ? "Supported" : "Review required",
                                valueColor: appState.isSupported ? AppTheme.success : AppTheme.destructive
                            )
                        }
                    }

                    ZyvexSectionTitle(title: "Language")
                    ZyvexCard {
                        Picker("Language", selection: $languageCode) {
                            ForEach(AppLanguage.allCases) { option in
                                Text(option.displayName).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    ZyvexCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Zyvex workspace")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Use Clean to restore files managed by this app. Original third-party application bundles are not modified by the safe workspace flow.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private var installationID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Text(value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    private func licenseRow(
        icon: String,
        title: String,
        value: String,
        valueColor: Color = .white,
        monospaced: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Text(value)
                    .font(monospaced ? .caption.monospaced() : .body.weight(.semibold))
                    .foregroundStyle(valueColor)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}
