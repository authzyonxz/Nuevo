import SwiftUI

struct PatchProjectsView: View {
    @StateObject private var store = PatchFunctionStore()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.functions) { function in
                    HStack(spacing: 16) {
                        Text(function.name)
                            .font(.body.weight(.medium))
                        Spacer(minLength: 12)
                        Toggle("", isOn: Binding(
                            get: { function.isEnabled },
                            set: { store.toggle(function, enabled: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!function.canToggle || store.isWorking(function))
                    }
                    .contentShape(Rectangle())
                    .listRowSeparator(.visible)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Patches")
            .navigationBarTitleDisplayMode(.inline)
            .alert("3105", isPresented: Binding(
                get: { store.banner != nil },
                set: { if !$0 { store.banner = nil } }
            )) {
                Button("OK", role: .cancel) { store.banner = nil }
            } message: {
                Text(store.banner ?? "")
            }
            .onAppear {
                store.refreshFromManifest()
            }
        }
    }
}
