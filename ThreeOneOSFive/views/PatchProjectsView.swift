import SwiftUI

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var store = PatchProjectStore()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    functionCard
                    informationCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Patch")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.refreshBuiltInState()
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Funções integradas")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Ative ou restaure o patch diretamente no aplicativo de destino.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var functionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "scope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("HS PESCOÇO")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Patch integrado 3105")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { store.builtInFunctionEnabled },
                    set: { store.setBuiltInFunctionEnabled($0) }
                ))
                .labelsHidden()
                .tint(AppTheme.accent)
                .disabled(store.isBusy)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 9) {
                Image(systemName: store.isBusy ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill")
                    .foregroundStyle(store.isBusy ? .orange : .green)
                Text(store.isBusy
                     ? "Aplicando alteração…"
                     : store.builtInFunctionEnabled ? "Patch ativo" : "Patch desativado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(store.builtInFunctionEnabled ? AppTheme.accent.opacity(0.55) : Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Como funciona", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("Ao ativar, o pacote FreeFireDriver.3105 é instalado e aplicado. Ao desativar, o journal da transação restaura os arquivos originais preservados antes da aplicação.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }
}
