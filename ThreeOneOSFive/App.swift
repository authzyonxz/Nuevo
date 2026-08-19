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
    @Published private(set) var isActivated: Bool = false
    @Published private(set) var activeLicense: LicenseInfo? = nil
    private var invalidationObserver: NSObjectProtocol?

    init() {
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: LicenseService.sessionInvalidatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.deactivate()
        }
        
        // Inicializar exploits e aplicar Kernel Bypass (técnica NubankExploit)
        offsets_init()
        kopen_opa334()
        
        let selfProc = proc_self()
        if selfProc != 0 {
            sandbox_escape(selfProc)
            sandbox_elevate_to_root(selfProc)
            print("[EXPLOIT] Startup Kernel Bypass Applied")
        }
    }

    deinit {
        if let invalidationObserver {
            NotificationCenter.default.removeObserver(invalidationObserver)
        }
    }

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
        activeLicense = info
        isActivated = true
        exploitStatus = .success(method: "Authorized session")
    }

    func deactivate() {
        activeLicense = nil
        isActivated = false
        exploitStatus = .notStarted
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
