import UIKit
import SwiftUI

private struct DemoTarget: Identifiable {
    let id = UUID()
    let name: String
    let identifier: String
}

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
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
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("IPA")
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
                                Text("IPA")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Importe seus arquivos .onyx na Library e realize injeções atômicas no Free Fire.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.mutedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            AppLogo(size: 76)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 16)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ZyvexInjectView: View {
    @Environment(\.appLanguage) private var language
    let onOpenLibrary: () -> Void
    @State private var selectedTarget: DemoTarget?
    @State private var importedAssets: [URL] = OnyxImporterService.shared.getImportedAssets()
    @State private var selectedAsset: URL?
    @State private var showResult = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""

    @State private var detectedTargets: [DemoTarget] = []
    
    private let targetTemplates = [
        DemoTarget(name: "Free Fire (Global/TH)", identifier: "com.dts.freefireth"),
        DemoTarget(name: "Free Fire MAX", identifier: "com.dts.freefiremax"),
        DemoTarget(name: "Free Fire (Vietnam)", identifier: "com.garena.game.fcm"),
        DemoTarget(name: "Free Fire (Taiwan)", identifier: "com.garena.game.kgtw")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ZyvexSectionTitle(title: "1. Selecionar Jogo Alvo")
                    
                    if detectedTargets.isEmpty {
                        Text("Nenhum jogo detectado automaticamente. Tente selecionar manualmente:")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                    
                    ForEach(targetTemplates) { target in
                        Button {
                            selectedTarget = target
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(target.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(target.identifier)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if selectedTarget?.identifier == target.identifier {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    ZyvexSectionTitle(title: "2. Selecionar Arquivo .onyx")
                    if importedAssets.isEmpty {
                        ZyvexCard {
                            VStack(spacing: 12) {
                                Text("Nenhum arquivo .onyx encontrado na Library.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Button("Ir para Library", action: onOpenLibrary)
                                    .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(importedAssets, id: \.self) { url in
                            Button {
                                selectedAsset = url
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.blue)
                                    Text(url.lastPathComponent)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedAsset == url {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedTarget != nil && selectedAsset != nil {
                        VStack(spacing: 12) {
                            Button(action: applyPatch) {
                                Text("INJETAR AGORA")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.blue)
                                    .cornerRadius(14)
                            }
                            
                            Button(action: restoreOriginal) {
                                Text("RESTAURAR ORIGINAL")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 16)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Inject")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                importedAssets = OnyxImporterService.shared.getImportedAssets()
                
                // Tentar detectar qual jogo está instalado
                let installed = ContainerStore.installedAppsFromAPI()
                detectedTargets = targetTemplates.filter { template in
                    installed.contains(where: { $0.bundleID == template.identifier })
                }
                
                if selectedTarget == nil {
                    selectedTarget = detectedTargets.first ?? targetTemplates.first
                }
                if selectedAsset == nil { selectedAsset = importedAssets.first }
            }
            .alert(resultTitle, isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func applyPatch() {
        guard let selectedTarget, let selectedAsset else { return }

        let sourceFileName = selectedAsset.lastPathComponent
        
        do {
            // 1. Extrair payload (Asset Puro)
            guard let patchData = OnyxImporterService.shared.extractPayload(from: selectedAsset) else {
                throw NSError(domain: "Onyx", code: 2, userInfo: [NSLocalizedDescriptionKey: "Falha ao ler dados do arquivo."])
            }
            
            // 2. Determinar nome do arquivo alvo
            var targetFileName = sourceFileName
            if sourceFileName.hasSuffix(".onyx") || sourceFileName.hasSuffix(".3105") {
                if let (meta, _) = try? OnyxImporterService.shared.importOnyxFile(from: selectedAsset).get() {
                    targetFileName = meta.payload_filename
                }
            }
            
            // 3. Localizar container do jogo
            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: selectedTarget.identifier) else {
                throw NSError(domain: "Patch", code: 404, userInfo: [NSLocalizedDescriptionKey: "Não foi possível localizar a pasta do jogo."])
            }
            
            // 4. Varredura Profunda (Deep Scan) para encontrar o arquivo original
            log("patch: Iniciando varredura profunda por '\(targetFileName)' em \(selectedTarget.identifier)")
            let foundPaths = ContainerStore.findFilesRecursively(at: containerPath, filename: targetFileName)
            
            if foundPaths.isEmpty {
                // Fallback: Se não achou na varredura, tenta o caminho padrão
                log("patch: Arquivo não encontrado na varredura, tentando caminho padrão...")
                let defaultRelPath = "Documents/ContentCache/Compulsory/ios/gameassetbundles/\(targetFileName)"
                let rule = PatchRule(id: UUID(), bundleID: selectedTarget.identifier, relativePath: defaultRelPath, replacementFilename: targetFileName, replacementData: patchData)
                let project = PatchProject(id: UUID(), name: "Fallback Inject", createdAt: Date(), updatedAt: Date(), bundleIdentifiers: [selectedTarget.identifier], directories: [], rules: [rule])
                _ = try DevicePatchService.apply(project: project)
            } else {
                // Injetar em TODOS os locais encontrados (as vezes o jogo tem duplicatas)
                log("patch: Encontrado \(foundPaths.count) locais para substituição.")
                for fullPath in foundPaths {
                    // Converter caminho absoluto para relativo ao container
                    let relPath = String(fullPath.dropFirst(containerPath.count + (containerPath.hasSuffix("/") ? 0 : 1)))
                    log("patch: Injetando em \(relPath)")
                    
                    let rule = PatchRule(id: UUID(), bundleID: selectedTarget.identifier, relativePath: relPath, replacementFilename: targetFileName, replacementData: patchData)
                    let project = PatchProject(id: UUID(), name: "Deep Inject", createdAt: Date(), updatedAt: Date(), bundleIdentifiers: [selectedTarget.identifier], directories: [], rules: [rule])
                    _ = try DevicePatchService.apply(project: project)
                }
            }
            
            resultTitle = "Sucesso!"
            resultMessage = "Substituição concluída em \(foundPaths.count > 0 ? "\(foundPaths.count) locais" : "caminho padrão")!"
            showResult = true
        } catch {
            resultTitle = "Erro"
            resultMessage = "Falha na injeção: \(error.localizedDescription)"
            showResult = true
        }
    }

    private func restoreOriginal() {
        do {
            let backupRoot = try PatchProjectLibrary.backupRootURL()
            let fileManager = FileManager.default
            if let items = try? fileManager.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil) {
                for item in items {
                    if let receipt = PatchTransaction.latestReceipt(projectID: UUID(uuidString: item.lastPathComponent) ?? UUID(), backupRoot: backupRoot) {
                        try DevicePatchService.restore(receipt: receipt)
                    }
                }
            }
            resultTitle = "Restauração"
            resultMessage = "Arquivos originais restaurados com sucesso!"
            showResult = true
        } catch {
            resultTitle = "Restauração"
            resultMessage = "Restauração concluída ou nenhum backup encontrado."
            showResult = true
        }
    }
}
