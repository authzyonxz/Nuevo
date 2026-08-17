import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-inject-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-library-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-settings-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if !appState.isActivated {
                LoginView()
            } else if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.library.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.library.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
        .background(AppTheme.pageBackground)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("Zyvex")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(AppSection(rawValue: tabNavigation.selectedTab) ?? .home)
                .id(tabNavigation.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                onSelect: { section in
                    if let section { tabNavigation.select(section.rawValue) }
                }
            )
        case .inject:
            ZyvexInjectView(onOpenLibrary: { tabNavigation.select(AppSection.library.rawValue) })
        case .library:
            PatchProjectsView()
        case .cleaner:
            CleanerView()
        case .settings:
            SettingsView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility()
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .inject: return "tab.inject"
        case .library: return "tab.library"
        case .cleaner: return "tab.cleaner"
        case .settings: return "tab.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .inject: return "bolt.fill"
        case .library: return "shippingbox.fill"
        case .cleaner: return "trash.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @Binding var cleanerEnabled: Bool
    let onSelect: (AppSection?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ZyvexCard {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FREE FIRE TOOLKIT")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)
                                Text("ZYVEX")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("A focused workspace for your controlled packages, targets and device tools.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.mutedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            AppLogo(size: 76)
                        }
                    }
                    ZyvexCard {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(appState.isSupported ? AppTheme.success : AppTheme.destructive)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(appState.isSupported ? "Workspace ready" : "Compatibility needs attention")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(appState.isSupported ? "Access layer available" : "Review device support details")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer()
                        }
                    }
                    ZyvexSectionTitle(title: "Quick launch")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        quickLaunch(title: "Inject", subtitle: "Choose a test target", icon: "bolt.fill", section: .inject)
                        quickLaunch(title: "Library", subtitle: "Import packages", icon: "shippingbox.fill", section: .library)
                        quickLaunch(title: "Clean", subtitle: "Review workspace", icon: "trash.fill", section: .cleaner)
                        quickLaunch(title: "Settings", subtitle: "Device & access", icon: "gearshape.fill", section: .settings)
                    }
                    ZyvexCard {
                        Text("ZYVEX  •  SECURE WORKSPACE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.mutedText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 14)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.pageBackground)
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLogs = true } label: {
                        Image(systemName: "apple.terminal")
                    }
                    .accessibilityLabel(language.text("accessibility.open_logs"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("accessibility.open_settings"))
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    private func quickLaunch(title: String, subtitle: String, icon: String, section: AppSection?) -> some View {
        Button { onSelect(section) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Spacer(minLength: 8)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(16)
            .background(AppTheme.secondaryCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var featuresSection: some View {
        Section {
            Label(language.text("tab.cleaner"), systemImage: "sparkles")
        } header: {
            Text(language.text("dashboard.features"))
        }
    }

    private var signingSection: some View {
        Section {
            Label {
                Text(language.text("dashboard.enterprise_signing"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.vertical, 4)
        } header: {
            Text(language.text("dashboard.installation"))
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("settings.ios_version")) {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            HStack {
                Text(language.text("settings.compatibility"))
                Spacer()
                Label(
                    language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                    systemImage: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }
        } header: {
            Text(language.text("common.device"))
        } footer: {
            Text(language.text("settings.supported_range_summary"))
        }
    }
}


private struct ZyvexInjectView: View {
    @Environment(\.appLanguage) private var language
    let onOpenLibrary: () -> Void
    @State private var selectedTarget: DemoTarget?
    @State private var selectedOption: DemoOption?
    @State private var showConfirmation = false
    @State private var showResult = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var statusMessage: String?

    private let targets = [
        DemoTarget(name: "Free Fire", identifier: "com.dts.freefireth"),
        DemoTarget(name: "Free Fire MAX", identifier: "com.dts.freefiremax")
    ]

    private let options = [
        DemoOption(name: "Neck", symbol: "scope"),
        DemoOption(name: "Drag", symbol: "hand.draw"),
        DemoOption(name: "Body", symbol: "figure.stand"),
        DemoOption(name: "MagicBullet", symbol: "sparkles")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ZyvexSectionTitle(title: "Select target")
                    ZyvexCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose a controlled workspace")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("This demo flow applies only to files owned by the Zyvex workspace.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                    ForEach(targets) { target in
                        targetRow(target)
                    }
                    if let selectedTarget {
                        ZyvexSectionTitle(title: "Select patch")
                        ZyvexCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(selectedTarget.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                ForEach(options) { option in
                                    Button {
                                        selectedOption = option
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: option.symbol)
                                                .foregroundStyle(AppTheme.accent)
                                            Text(option.name)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Image(systemName: selectedOption?.id == option.id ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedOption?.id == option.id ? AppTheme.success : AppTheme.mutedText)
                                        }
                                        .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button {
                                    showConfirmation = true
                                } label: {
                                    Label("Confirm selection", systemImage: "checkmark.shield.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                                .disabled(selectedOption == nil)
                            }
                        }
                    } else {
                        ZyvexCard {
                            VStack(spacing: 8) {
                                Image(systemName: "cursorarrow.click.2")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)
                                Text("Select a target to continue")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("Import controlled packages from Library when needed.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.mutedText)
                                    .multilineTextAlignment(.center)
                                Button("Open Library", action: onOpenLibrary)
                                    .buttonStyle(.bordered)
                                    .tint(AppTheme.accent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.success)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("Inject")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedTarget == nil { selectedTarget = targets.first }
            }
            .alert("Confirm selection", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Apply to demo workspace") {
                    applySelectedOption()
                }
            } message: {
                Text("The selected patch will be copied to the controlled Zyvex workspace with a local backup.")
            }
            .alert(resultTitle, isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func applySelectedOption() {
        guard let selectedTarget, let selectedOption else {
            resultTitle = language.text("common.error")
            resultMessage = "Select a target and a patch before confirming."
            showResult = true
            return
        }

        let bodyFileName = "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        let neckFileName = "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
        
        // Map UI options to actual filenames in bundle
        let sourceFileName: String
        switch selectedOption.name {
        case "Body": sourceFileName = bodyFileName
        case "Neck", "Drag", "MagicBullet": sourceFileName = neckFileName
        default: sourceFileName = bodyFileName
        }

        guard let localPackageURL = Bundle.main.url(forResource: sourceFileName, withExtension: nil) else {
            resultTitle = language.text("common.error")
            resultMessage = "Patch file '\(sourceFileName)' not found in app bundle."
            showResult = true
            return
        }

        do {
            let patchData = try Data(contentsOf: localPackageURL)
            let relativePath = "Documents/Contentchache/Compulsory/ios/gameassetbundles/\(sourceFileName)"
            
            let rule = PatchRule(
                id: UUID(),
                bundleID: selectedTarget.identifier,
                relativePath: relativePath,
                replacementFilename: sourceFileName,
                replacementData: patchData
            )
            
            let project = PatchProject(
                id: UUID(),
                name: "Zyvex Auto-Inject",
                createdAt: Date(),
                updatedAt: Date(),
                bundleIdentifiers: [selectedTarget.identifier],
                directories: [],
                rules: [rule]
            )
            
            _ = try DevicePatchService.apply(project: project)
            
            resultTitle = language.text("common.success")
            resultMessage = "Successfully injected \(selectedOption.name) into \(selectedTarget.name).\n\nPath: \(relativePath)"
            statusMessage = "\(selectedOption.name) Active"
        } catch {
            resultTitle = language.text("common.error")
            resultMessage = "Injection failed: \(error.localizedDescription)"
            statusMessage = "Injection Error"
        }
        showResult = true
    }

    private func targetRow(_ target: DemoTarget) -> some View {
        Button {
            selectedTarget = target
            selectedOption = nil
            statusMessage = nil
        } label: {
            HStack(spacing: 14) {
                Image("FreeFireLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.accent.opacity(0.45), lineWidth: 1) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(target.identifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.mutedText)
                    Text(selectedTarget?.id == target.id ? "TARGET SELECTED" : "SELECT TARGET")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer()
                Image(systemName: selectedTarget?.id == target.id ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(selectedTarget?.id == target.id ? AppTheme.success : AppTheme.mutedText)
            }
            .padding(16)
            .background(AppTheme.secondaryCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct DemoTarget: Identifiable, Hashable {
    let name: String
    let identifier: String
    var id: String { identifier }
}

private struct DemoOption: Identifiable, Hashable {
    let name: String
    let symbol: String
    var id: String { name }
}
