import SwiftUI

struct PatchProjectsView: View {
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchFunctionStore()
    @State private var editingFunction: PatchFunction?
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(uiColor: .systemBackground), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        HStack(spacing: 10) {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(AppTheme.accent)
                            Text("Os payloads são hospedados e validados online. Nenhum arquivo é enviado pelo app.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        LazyVStack(spacing: 12) {
                            ForEach(store.functions) { function in
                                FunctionCard(function: function, store: store) {
                                    editingFunction = function
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Patches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }
                }
            }
            .sheet(item: $editingFunction) { function in
                PayloadEditor(function: function, store: store)
            }
            .alert("Sobre os patches", isPresented: $showInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Cada switch controla uma função independente. Ativar aplica o payload validado; desativar restaura o estado original. Pausar mantém o payload cadastrado sem permitir aplicação.")
            }
            .alert("3105", isPresented: Binding(get: { store.banner != nil }, set: { if !$0 { store.banner = nil } })) {
                Button("OK", role: .cancel) { store.banner = nil }
            } message: {
                Text(store.banner ?? "")
            }
            .onAppear {
                _ = draftCoordinator
                store.refreshFromManifest()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("FUNCTIONS")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(AppTheme.accent)
            Text("Controle seus patches")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Ative somente funções publicadas e validadas. O estado é salvo neste dispositivo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FunctionCard: View {
    let function: PatchFunction
    @ObservedObject var store: PatchFunctionStore
    let edit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [AppTheme.accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text(String(function.id)).font(.title3.weight(.black)).foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(function.name).font(.headline)
                    Text(function.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.isWorking(function) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Toggle("", isOn: Binding(get: { function.isEnabled }, set: { store.toggle(function, enabled: $0) }))
                        .labelsHidden()
                        .disabled(!function.canToggle)
                }
            }
            .padding(16)
            Divider()
            HStack {
                Circle().fill(function.isEnabled ? .green : (function.isPaused ? .orange : .secondary)).frame(width: 7, height: 7)
                Text(function.stateTitle).font(.caption.weight(.semibold)).foregroundStyle(function.isEnabled ? .green : .secondary)
                Spacer()
                Button("Gerenciar", action: edit).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.18)))
    }
}

private struct PayloadEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var function: PatchFunction
    @ObservedObject var store: PatchFunctionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Payload online") {
                    TextField("URL HTTPS do .3105", text: $function.payloadURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        store.update(function)
                        store.validatePayload(for: function)
                    } label: {
                        Label("Validar e publicar", systemImage: "checkmark.seal")
                    }
                    .disabled(function.payloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Controles") {
                    Toggle("Pausar temporariamente", isOn: Binding(get: { function.isPaused }, set: { newValue in function.isPaused = newValue; store.setPaused(newValue, for: function) }))
                    Button("Excluir payload", role: .destructive) {
                        store.removePayload(from: function)
                        dismiss()
                    }
                }
                if let date = function.lastValidatedAt {
                    Section("Validação") {
                        LabeledContent("Última validação", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle(function.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { store.update(function); dismiss() } }
            }
        }
    }
}
