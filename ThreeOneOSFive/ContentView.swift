import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppSection = .home

    private var visibleSections: [AppSection] { [.home, .patches] }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .background(AppTheme.pageBackground.ignoresSafeArea())
    }

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                    }
                    .tag(section)
            }
        }
        .background(AppTheme.pageBackground)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(visibleSections) { section in
                    Label(language.text(section.titleKey), systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            sectionContent(selectedTab)
                .id(selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView()
        case .patches:
            PatchProjectsView()
        default:
            DashboardView()
        }
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .patches: return "tab.patches"
        default: return "tab.home"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .patches: return "shippingbox.fill"
        default: return "house.fill"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                currentSystemSection
                supportedVersionsSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("tab.home"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var currentSystemSection: some View {
        Section {
            compatibilityRow
            LabeledContent(language.text("home.system_version")) {
                Text("iOS \(AppInfo.osVersion)")
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("home.system_build")) {
                Text(AppInfo.osBuild)
                    .font(.body.monospaced())
            }
        } header: {
            Text(language.text("home.current_system"))
        }
    }

    private var compatibilityRow: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill")
                .font(.title3)
                .foregroundStyle(appState.isSupported ? .green : .red)
            VStack(alignment: .leading, spacing: 3) {
                Text(language.text("home.compatibility"))
                    .font(.body.weight(.semibold))
                Text(language.text(appState.isSupported ? "home.compatible" : "home.not_compatible"))
                    .font(.caption)
                    .foregroundStyle(appState.isSupported ? .green : .red)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var supportedVersionsSection: some View {
        Section {
            compatibilityLine(title: "iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
            compatibilityLine(title: "iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
            compatibilityLine(title: "iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
            ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                HStack {
                    Text("iOS 27.0")
                    Spacer()
                    Text(versionLabel(version))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(language.text("home.compatible_versions"))
        } footer: {
            Text(language.text("home.compatibility_footer"))
        }
    }

    private func compatibilityLine(title: String, value: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func versionLabel(_ version: (beta: Int, publicBeta: Int?, build: String)) -> String {
        let beta = version.publicBeta.map { "Beta \(version.beta) / Pública \($0)" } ?? "Beta \(version.beta)"
        return "\(beta) · \(version.build)"
    }
}
