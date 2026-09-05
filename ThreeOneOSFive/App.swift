import SwiftUI
import UIKit
import Darwin

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
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

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(fileOperationCoordinator)
            .environmentObject(patchStore)
            .environmentObject(repositoryStore)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .preferredColorScheme(.dark)
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: true)
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
                appState.detectSupport()
                checkForUpdate()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    log("app: entered background — terminating process to drop exploit state")
                    Darwin.exit(0)
                }
                guard phase == .active else { return }
                appState.detectSupport()
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
    @Published var kernelExploitRunning = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

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
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        // Exploit execution is intentionally manual. Starting kernel work on launch
        // can leave native race threads active while iOS terminates the app.
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    @MainActor
    func preparePrivilegedSession() async throws {
        guard isSupported else {
            throw PatchPackageError.sandboxAccessUnavailable("iOS \(AppInfo.osVersion)")
        }

        switch KernelExploit.currentAccessPath {
        case .badQuery:
            exploitStatus = .success(method: "ContainerManager/bad_query")
            log("app: selected ContainerManager bad_query path; kernel exploit not started")
            return
        case .unsupported:
            throw PatchPackageError.sandboxAccessUnavailable("iOS \(AppInfo.osVersion) / \(AppInfo.osBuild)")
        case .kernelOffsets:
            break
        }

        refreshKernelExploitStatus()
        if exploitStatus.isSuccess {
            log("app: privileged session already active for requested operation")
            return
        }

        if kernelExploitRunning {
            while kernelExploitRunning {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            if exploitStatus.isSuccess { return }
        }

        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: starting privileged session on demand for patch operation")
        let ok = await Task.detached(priority: .userInitiated) {
            KernelExploit.run()
        }.value
        kernelExploitRunning = false

        guard ok else {
            exploitStatus = .failed(method: "kexploit", code: -1)
            log("app: privileged session failed — operation stopped")
            throw PatchPackageError.sandboxAccessUnavailable(AppInfo.osVersion)
        }

        exploitStatus = .success(method: "kexploit")
        log("app: privileged session ready for this foreground operation")
    }

    @MainActor
    func finishPrivilegedOperation(reason: String) {
        kernelExploitRunning = false
        KernelExploit.cleanup()
        exploitStatus = .notStarted
        log("app: privileged operation ended — \(reason); no background operation retained")
    }

    @MainActor
    func runKernelExploitIfNeeded() {
        Task {
            _ = try? await preparePrivilegedSession()
        }
    }
}
