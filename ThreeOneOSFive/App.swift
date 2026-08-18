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
            return
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }
        
        // Inicialização automática do exploit baseado na versão
        runExploitIfNeeded()
    }

    func runExploitIfNeeded() {
        let v = AppInfo.versionTuple
        
        // Se já foi ativado, não faz nada
        if case .success = exploitStatus { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Int32
            let method: String
            
            if v.major >= 26 {
                // iOS 26/27+: Usa o exploit atual (opa334/A18+)
                log("app: Running modern exploit for iOS \(v.major)")
                result = kexploit_opa334()
                method = "Modern Kernel RW"
            } else {
                // iOS 17/18 (< 26): Usa a lógica do FilzaJailed
                log("app: Running FilzaJailed exploit for iOS \(v.major)")
                result = kexploit_opa334() // Mesma base, mas o mestre quer a lógica do FilzaJailed integrada
                _ = sandbox_escape(0) // Tenta escapar do sandbox imediatamente
                _ = sandbox_elevate_to_root(0) // Tenta elevar privilégios
                method = "FilzaJailed Escape"
            }
            
            DispatchQueue.main.async {
                if result == 0 {
                    self.exploitStatus = .success(method: method)
                    log("app: Exploit successful via \(method)")
                } else {
                    self.exploitStatus = .failed("Exploit failed (code \(result))")
                    log("app: Exploit failed")
                }
            }
        }
    }
}
