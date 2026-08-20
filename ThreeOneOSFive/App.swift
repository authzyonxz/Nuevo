import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var licenseManager = LicenseManager.shared
    @StateObject private var exploitState = KernelExploitState()

    init() {
        setupLogCapture()
        log("app: MenagerFF launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
    }

    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(licenseManager)
                .environmentObject(exploitState)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Ativar exploit de Kernel para permissões de container
                    exploitState.runExploitIfNeeded()
                    
                    // Auto-validar se já existe key salva no Keychain
                    if let savedKey = licenseManager.loadSavedKey(), !savedKey.isEmpty {
                        licenseManager.validateKey(savedKey) { _, _ in }
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                KernelExploit.cleanup()
            }
        }
    }
}

class KernelExploitState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var exploitRunning = false

    func runExploitIfNeeded() {
        guard !exploitRunning, !exploitStatus.isSuccess else { return }
        exploitRunning = true
        log("exploit: running kernel exploit...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.exploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "DarkSword/Root")
                    log("exploit: success — root elevation active")
                } else {
                    self.exploitStatus = .failed(method: "DarkSword/Root", code: -1)
                    log("exploit: failed")
                }
            }
        }
    }
}
