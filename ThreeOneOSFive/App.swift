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
            // Tentativa de validação automática em background
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
        
        // Disparar exploit de kernel e escape de sandbox após ativação bem-sucedida
        triggerKernelExploit()
    }
    
    private func triggerKernelExploit() {
        DispatchQueue.global(qos: .userInitiated).async {
            log("exploit: Iniciando OPA334...")
            let result = kexploit_opa334()
            if result == 0 {
                log("exploit: Kernel R/W estabelecido!")
                let selfProc = proc_self()
                log("exploit: Escapando da Sandbox...")
                let escapeResult = sandbox_escape(selfProc)
                if escapeResult == 0 {
                    log("exploit: Sandbox escape concluído com sucesso!")
                    DispatchQueue.main.async {
                        self.exploitStatus = .success(method: "Kernel + Sandbox Escape")
                    }
                } else {
                    log("exploit: Falha no sandbox escape (\(escapeResult))")
                }
            } else {
                log("exploit: Falha no kernel exploit (\(result))")
            }
        }
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
