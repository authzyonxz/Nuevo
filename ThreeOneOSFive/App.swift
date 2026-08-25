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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(licenseManager)
                .environmentObject(exploitState)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Select the access path by OS family. iOS 17/18 use the
                    // kernel/offset chain; iOS 26/27 use bad_query lazily.
                    exploitState.prepareForCurrentOS()

                }
        }
    }
}

class KernelExploitState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var exploitRunning = false

    func prepareForCurrentOS() {
        guard !exploitRunning, !exploitStatus.isSuccess else { return }

        switch KernelExploit.currentAccessPath {
        case .kfd16:
            runKernelExploitIfNeeded()

        case .badQuery:
            // bad_query is requested by ContainerStore/DevicePatchService only
            // when a concrete path needs access; do not run the kernel exploit.
            exploitStatus = .success(method: "ContainerManager/bad_query")
            log("access: iOS 26/27 selected ContainerManager bad_query path")

        case .kernelOffsets:
            runKernelExploitIfNeeded()

        case .unsupported:
            let message = "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
            exploitStatus = .unsupported(message)
            log("access: unsupported OS/build \(message)")
        }
    }

    private func runKernelExploitIfNeeded() {
        guard !exploitRunning, !exploitStatus.isSuccess else { return }
        exploitRunning = true
        log("exploit: running selected native access path for iOS \(AppInfo.osVersion)...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.exploitRunning = false
                if ok {
                    let method = KernelExploit.usesKFD16 ? "KFD16 kernel access" : "Kernel offsets"
                    self.exploitStatus = .success(method: method)
                    log("exploit: success — kernel access active")
                } else {
                    let method = KernelExploit.usesKFD16 ? "KFD16 kernel access" : "Kernel offsets"
                    self.exploitStatus = .failed(method: method, code: -1)
                    log("exploit: failed — \(method)")
                }
            }
        }
    }
}
