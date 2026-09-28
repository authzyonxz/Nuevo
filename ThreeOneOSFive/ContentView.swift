import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appLanguage) private var language

    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PatchProjectsView()
                .tabItem {
                    Label("Patch", systemImage: "bolt.shield.fill")
                }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
    }
}

private struct HomeDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    brandHeader
                    systemCard
                    compatibilityCard
                    exploitCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("3105")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            AppLogo(size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("3105")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Device utility")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(appState.isSupported ? Color.green : Color.red)
                .frame(width: 9, height: 9)
                .shadow(color: (appState.isSupported ? Color.green : Color.red).opacity(0.7), radius: 8)
        }
    }

    private var systemCard: some View {
        PremiumCard {
            cardHeader("Sistema", icon: "iphone", tint: AppTheme.accent)
            infoRow("Versão", value: "iOS \(AppInfo.osVersion)")
            Divider().overlay(Color.white.opacity(0.08))
            infoRow("Build", value: AppInfo.osBuild)
            Divider().overlay(Color.white.opacity(0.08))
            infoRow("Dispositivo", value: AppInfo.machineName)
        }
    }

    private var compatibilityCard: some View {
        PremiumCard {
            cardHeader(
                "Compatibilidade",
                icon: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill",
                tint: appState.isSupported ? .green : .red
            )
            HStack(spacing: 10) {
                Image(systemName: appState.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(appState.isSupported ? .green : .red)
                Text(appState.isSupported ? "Build compatível" : "Build não compatível")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            if let reason = appState.unsupportedMessage {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exploitCard: some View {
        PremiumCard {
            cardHeader("Acesso do dispositivo", icon: "bolt.shield.fill", tint: .orange)
            Text("O exploit é executado somente quando você tocar no botão. Não há execução automática ao abrir o app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                appState.runKernelExploitIfNeeded()
            } label: {
                HStack(spacing: 10) {
                    if appState.kernelExploitRunning {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: appState.exploitStatus.isSuccess ? "checkmark" : "bolt.fill")
                    }
                    Text(appState.kernelExploitRunning
                         ? "Iniciando exploit…"
                         : appState.exploitStatus.isSuccess ? "Exploit ativo" : "Iniciar exploit")
                        .font(.body.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!appState.isSupported || appState.kernelExploitRunning || appState.exploitStatus.isSuccess)
            .opacity((!appState.isSupported || appState.exploitStatus.isSuccess) ? 0.55 : 1)

            Text(appState.exploitStatus.displayText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func cardHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct PremiumCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
    }
}
