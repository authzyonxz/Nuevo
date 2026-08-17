import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .zyvexScreen()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    appState.detectSupport()
                    appState.checkInitialActivation()
                }
                .onOpenURL { url in
                    patchDraftCoordinator.presentImport(url)
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var isActivated: Bool = false
    @Published var activeLicense: LicenseInfo? = nil

    var isSupported: Bool { unsupportedMessage == nil }

    func checkInitialActivation() {
        if let savedKey = LicenseService.shared.getSavedKey() {
            LicenseService.shared.validateKey(savedKey) { result in
                DispatchQueue.main.async {
                    if case .success(let info) = result {
                        self.activate(with: info)
                    }
                }
            }
        }
    }

    func activate(with info: LicenseInfo) {
        self.activeLicense = info
        self.isActivated = true
        
        // Exploit de Kernel (OPA334) removido por instabilidade.
        // O app agora usa o exploit 'bad_query' integrado nos helpers de injeção,
        // que é 100% estável e não causa crashes no sistema.
        self.exploitStatus = .success(method: "Onyx/BadQuery")
    }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
        }
    }
}
