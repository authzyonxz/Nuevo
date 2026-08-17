import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.portugueseBrazil.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .portugueseBrazil
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isLoggedIn {
                    ContentView()
                        .transition(.opacity)
                } else {
                    LoginViewWrapper(isLoggedIn: $appState.isLoggedIn)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(fileOperationCoordinator)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .onAppear {
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
    @Published var isLoggedIn: Bool = r7x_IsValid_2v()

    var isSupported: Bool { unsupportedMessage == nil }

    init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(r7x_Notify_92), object: nil, queue: .main) { [weak self] _ in
            withAnimation {
                self?.isLoggedIn = false
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

struct LoginViewWrapper: UIViewRepresentable {
    @Binding var isLoggedIn: Bool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = container.window {
                RageLoginView.present(in: window) { _ in
                    withAnimation {
                        isLoggedIn = true
                    }
                }
            }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
