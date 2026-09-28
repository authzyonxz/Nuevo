import SwiftUI

struct ContentView: View {
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
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3105")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Device utility")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(appState.isSupported ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(appState.isSupported ? "Build compatível" : "Build não compatível")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appState.isSupported ? .green : .red)
                        }
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.white.opacity(0.055))
                }

                Section("Informações do sistema") {
                    infoRow("iOS", "\(AppInfo.osVersion)")
                    infoRow("Build", AppInfo.osBuild)
                    infoRow("Dispositivo", AppInfo.displayMachineName)
                }
                .listRowBackground(Color.white.opacity(0.055))

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Acesso do dispositivo", systemImage: "bolt.shield.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text("O exploit é executado somente ao tocar no botão. Ele não é iniciado automaticamente.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            appState.runKernelExploitIfNeeded()
                        } label: {
                            HStack {
                                if appState.kernelExploitRunning {
                                    ProgressView().tint(.black)
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
                            .frame(height: 50)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!appState.isSupported || appState.kernelExploitRunning || appState.exploitStatus.isSuccess)
                        .opacity((!appState.isSupported || appState.exploitStatus.isSuccess) ? 0.55 : 1)

                        Text(appState.exploitStatus.displayText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white.opacity(0.055))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
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
