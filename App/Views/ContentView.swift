import SwiftUI

struct ContentView: View {
    @State private var isExploitActive = false
    @State private var statusText = "Aguardando ativação do exploit..."
    @State private var hsPescocoActive = false
    @State private var hsAltoActive = false
    @State private var hsPeitoActive = false
    @State private var hologramActive = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)
                        Text("FreeFire External Injector")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                        Text(statusText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(isExploitActive ? .green : .orange)
                    }
                    .padding(.top, 20)

                    // Botão de Ativação do Exploit / Kernel
                    Button(action: {
                        let success = ExternalPatcherBridge.activateExploit()
                        isExploitActive = success
                        statusText = success ? "Kernel Ativo — Pronto para Injetar no Processo" : "Falha ao ativar exploit"
                    }) {
                        HStack {
                            Image(systemName: isExploitActive ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            Text(isExploitActive ? "EXPLOIT DE KERNEL ATIVO" : "ATIVAR EXPLOIT DE KERNEL")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isExploitActive ? Color.green.opacity(0.8) : Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    // Funções de Mod / Offsets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FUNÇÕES DE MEMÓRIA (OFFSET PATCH)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ModToggleRow(title: "HS PESCOÇO", subtitle: "Aplica offset 0x54F252C", isOn: $hsPescocoActive)
                            Divider().background(Color.white.opacity(0.1))
                            ModToggleRow(title: "HS ALTO", subtitle: "Aplica offset 0x54D2DF8", isOn: $hsAltoActive)
                            Divider().background(Color.white.opacity(0.1))
                            ModToggleRow(title: "HS PEITO", subtitle: "Aplica offset 0x59C4A38", isOn: $hsPeitoActive)
                            Divider().background(Color.white.opacity(0.1))
                            ModToggleRow(title: "HOLOGRAMA", subtitle: "Aplica offset 0x92CB4DC", isOn: $hologramActive)
                        }
                        .background(Color(#colorLiteral(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
        }
    }
}

struct ModToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
        }
        .padding(16)
    }
}

// Ponte Objective-C para Swift
struct ExternalPatcherBridge {
    static func activateExploit() -> Bool {
        return true
    }
}
