import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            PatchProjectsView()
                .tabItem { Label("Patches", systemImage: "bolt.shield") }
                .tag(1)
        }
        .tint(AppTheme.accent)
        .onChange(of: patchDraftCoordinator.request?.id) { _ in selectedTab = 1 }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { _ in selectedTab = 1 }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(uiColor: .systemBackground), AppTheme.accent.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("3105")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .tracking(5)
                        Text("DEVICE STATUS")
                            .font(.caption.weight(.bold))
                            .tracking(3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 22)

                    VStack(spacing: 0) {
                        StatusRow(title: "Compatível", value: appState.isSupported ? "SIM" : "NÃO", tint: appState.isSupported ? .green : .red)
                        Divider().padding(.leading, 24)
                        StatusRow(title: "Versão do iOS", value: AppInfo.osVersion, tint: AppTheme.accent)
                        Divider().padding(.leading, 24)
                        StatusRow(title: "Build do sistema", value: AppInfo.osBuild, tint: AppTheme.accent)
                    }
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.18)))
                    .padding(.horizontal, 20)

                    Text("Verificação baseada no suporte oficial do projeto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(tint.opacity(0.16)).frame(width: 12, height: 12).overlay(Circle().fill(tint).frame(width: 6, height: 6))
            Text(title).font(.body.weight(.medium))
            Spacer()
            Text(value).font(.system(.body, design: .monospaced).weight(.bold)).foregroundStyle(tint)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}
