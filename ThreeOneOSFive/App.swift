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
        
        // Adicionar um delay de 3 segundos para evitar kernel panic/reboot imediato ao abrir o app
        // e garantir estabilidade na thread de fundo.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            print("[EXPLOIT] Iniciando estabilização de kernel em background...")
            
            // Verificar se o exploit é suportado antes de executar para evitar panics em versões incompatíveis
            offsets_init()
            
            // Tentar abrir o exploit de forma segura com tratamento de exceção simulada
            let kopenSuccess = kopen_opa334()
            if !kopenSuccess {
                DispatchQueue.main.async {
                    self?.exploitStatus = .failed(method: "OPA334 Init", code: -1)
                    print("[EXPLOIT] Kopen falhou ou não suportado nesta versão.")
                }
                return
            }
            
            let selfProc = proc_self()
            if selfProc != 0 {
                let escResult = sandbox_escape(selfProc)
                DispatchQueue.main.async {
                    if escResult == 0 {
                        self?.exploitStatus = .success(method: "Kernel OPA334 / DarkSword")
                        print("[EXPLOIT] Sandbox escape aplicado com sucesso!")
                    } else {
                        self?.exploitStatus = .failed(method: "Sandbox Escape", code: Int64(escResult))
                        print("[EXPLOIT] Sandbox escape retornou código: \(escResult)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.exploitStatus = .failed(method: "Proc Self", code: -999)
                }
            }
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
