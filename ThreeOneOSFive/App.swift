import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var licenseManager = LicenseManager.shared
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var showAttribution = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    @ViewBuilder
    private var rootContent: some View {
        if licenseManager.isAuthorized {
            if licenseManager.hasEnteredApp {
                ContentView()
            } else {
                LoginSuccessfulView {
                    Task {
                        let session = await licenseManager.recheckSecureSession()
                        guard session.authorized else { return }
                        licenseManager.enterApp()
                        appState.detectSupport()
                        checkForUpdate()
                    }
                }
            }
        } else {
            LicenseGateView()
        }
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(appState)
                .environmentObject(licenseManager)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environmentObject(patchStore)
                .environmentObject(repositoryStore)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .displayIdentityAttribution(
                    isPresented: $showAttribution,
                    enabled: licenseManager.isAuthorized
                )
                .sheet(isPresented: $showAttribution) {
                    DisplayAttributionSheet()
                }
                .alert(item: $updateOffer) { offer in
                    Alert(
                        title: Text(language.text("update.title")),
                        message: Text(language.text("update.message", offer.version)),
                        primaryButton: .default(Text(language.text("update.agree"))) {
                            UIApplication.shared.open(offer.url)
                        },
                        secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                            AppUpdateChecker.dismiss(version: offer.version)
                        }
                    )
                }
                .onAppear {
                    licenseManager.bootstrap()
                    if licenseManager.isAuthorized {
                        appState.markForegroundActive()
                        appState.detectSupport()
                        checkForUpdate()
                    }
                }
                .onChange(of: licenseManager.isAuthorized) { authorized in
                    guard authorized else { return }
                    appState.markForegroundActive()
                    appState.detectSupport()
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        appState.markForegroundActive()
                        if licenseManager.isAuthorized {
                            Task {
                                let session = await licenseManager.recheckSecureSession()
                                guard session.authorized else { return }
                                // Keep the explicit session and applied patches
                                // across background. Never restart automatically.
                                appState.detectSupport()
                                checkForUpdate()
                            }
                        } else {
                            licenseManager.resumeAfterSafari()
                        }
                    case .background, .inactive:
                        appState.markBackgrounded()
                    @unknown default:
                        appState.markBackgrounded()
                    }
                }
                .onOpenURL { url in
                    guard licenseManager.isAuthorized else { return }
                    patchDraftCoordinator.presentImport(url)
                }
        }
    }
}

final class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false
    @Published var isCheckingAuthorization = false
    @Published var exploitProgress = 0

    private var isForegroundActive = true
    private var exploitGeneration = UUID()
    private var progressTask: Task<Void, Never>?

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    var isSystemReady: Bool {
        isForegroundActive && exploitStatus.isSuccess && !kernelExploitRunning
    }

    var canUseFeatures: Bool {
        isSupported && isSystemReady
    }

    var exploitStatusText: String {
        switch exploitStatus {
        case .success:
            return "Sistema pronto"
        case .failed:
            return "Falha ao iniciar exploit"
        case .unsupported:
            return "Sistema não suportado"
        case .notStarted:
            return isForegroundActive ? "Exploit não iniciado" : "Aguardando o app ficar ativo"
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
            exploitProgress = 100
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            exploitProgress = 0
        }
        // The exploit remains explicit. Session entitlement is checked before
        // protected actions and whenever the app returns to the foreground.
    }

    func markForegroundActive() {
        isForegroundActive = true
        if !kernelExploitRunning && !exploitStatus.isSuccess && unsupportedMessage == nil {
            exploitProgress = 0
            exploitStatus = .notStarted
        }
    }

    func markBackgrounded() {
        // Applied patches remain active until the user disables/restores them.
        // The exploit is not started again when the app returns to foreground.
        log("app: backgrounded — preserving exploit session and applied features")
    }

    @MainActor
    func startExploit(licenseManager: LicenseManager) async {
        guard isForegroundActive,
              isSupported,
              !kernelExploitRunning,
              !isCheckingAuthorization else { return }
        guard !exploitStatus.isSuccess else { return }

        isCheckingAuthorization = true
        defer { isCheckingAuthorization = false }

        let session = await licenseManager.recheckSecureSession()
        guard session.authorized,
              isForegroundActive,
              isSupported,
              !kernelExploitRunning,
              !exploitStatus.isSuccess else {
            log("app: blocked exploit start because the license session is not active")
            return
        }

        beginExploit()
    }

    @MainActor
    private func beginExploit() {
        guard isForegroundActive, isSupported, !kernelExploitRunning else { return }
        guard !exploitStatus.isSuccess else { return }

        let generation = UUID()
        exploitGeneration = generation
        kernelExploitRunning = true
        exploitProgress = 1
        exploitStatus = .notStarted
        log("app: manual exploit start")

        progressTask?.cancel()
        progressTask = Task { @MainActor [weak self] in
            while let self,
                  self.kernelExploitRunning,
                  self.exploitGeneration == generation {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                self.exploitProgress = min(95, self.exploitProgress + 1)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.progressTask?.cancel()
                self.kernelExploitRunning = false
                guard self.exploitGeneration == generation else {
                    self.exploitProgress = 0
                    self.exploitStatus = .notStarted
                    log("app: discarded exploit result because the app left the foreground")
                    return
                }
                guard self.isForegroundActive else {
                    self.exploitProgress = 0
                    self.exploitStatus = .notStarted
                    return
                }
                if ok {
                    self.exploitProgress = 100
                    self.exploitStatus = .success(method: "kexploit")
                    log("app: manual exploit success — system ready")
                } else {
                    self.exploitProgress = 0
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: manual exploit failed — system is not ready")
                }
            }
        }
    }

    // Compatibility entry point also performs the same online license check.
    @MainActor
    func runKernelExploitIfNeeded(licenseManager: LicenseManager) async {
        await startExploit(licenseManager: licenseManager)
    }
}
