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
        
        // Disparar exploit com um pequeno atraso para garantir estabilidade da UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.triggerKernelExploit()
        }
    }
    
    private func triggerKernelExploit() {
        // Evitar rodar se já estiver com sucesso ou não suportado
        if case .success = exploitStatus { return }
        
        // Usar background queue com prioridade mínima para não afetar a UI
        DispatchQueue.global(qos: .background).async {
            log("exploit: Iniciando tentativa de estabilização...")
            
            // Tentar o exploit dentro de um ambiente controlado (sem abortar o app em caso de erro interno)
            // Nota: kexploit_opa334 original pode chamar exit() internamente se falhar feio.
            // Vamos tentar rodar apenas o essencial.
            
            let result = kexploit_opa334()
            if result == 0 {
                log("exploit: Kernel R/W estabelecido.")
                
                // Atraso maior para garantir que o kernel não entre em pânico
                Thread.sleep(forTimeInterval: 1.0)
                
                let selfProc = proc_self()
                if selfProc != 0 {
                    let escapeResult = sandbox_escape(selfProc)
                    if escapeResult == 0 {
                        log("exploit: Sandbox Escape concluído.")
                        DispatchQueue.main.async {
                            self.exploitStatus = .success(method: "OPA334 + SBX")
                        }
                    } else {
                        log("exploit: SBX ignorado (\(escapeResult))")
                    }
                }
            } else {
                log("exploit: Kernel bypass indisponível (\(result))")
                DispatchQueue.main.async {
                    self.exploitStatus = .failed(method: "Kernel", code: Int64(result))
                }
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
