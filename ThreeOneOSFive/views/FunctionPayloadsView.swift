import SwiftUI

struct FunctionPayloadsView: View {
    private enum Game: String, CaseIterable, Identifiable {
        case normal
        case max

        var id: String { rawValue }
        var title: String {
            switch self {
            case .normal: return "Free Fire normal"
            case .max: return "Free Fire MAX"
            }
        }
        var bundleID: String {
            switch self {
            case .normal: return "com.dts.freefireth"
            case .max: return "com.dts.freefiremax"
            }
        }
        var assetName: String {
            switch self {
            case .normal: return "FreeFireNormalLogo"
            case .max: return "FreeFireMaxLogo"
            }
        }
        var manifestTag: String { "game-freefire-\(rawValue)" }
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage("function.payload.server") private var serverURL = "https://keyauthv2.org/manifest.json"
    @AppStorage("function.selectedGame") private var selectedGameRawValue = Game.normal.rawValue
    @State private var enabled: Set<Int> = []
    @State private var isWorking = Set<Int>()
    @State private var alertTitle = "3105"
    @State private var alertMessage: String?

    private var selectedGame: Game {
        Game(rawValue: selectedGameRawValue) ?? .normal
    }

    private var slots: [Int] {
        selectedGame == .max ? Array(1...3) : Array(1...5)
    }

    private var availableSlots: [Int] {
        slots.filter { packageRecord(for: $0) != nil || isActive($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    gameCards
                } header: {
                    Text("Selecione o jogo")
                } footer: {
                    Text("A ativação só é permitida quando o payload publicado contém o bundle ID configurado para o jogo selecionado.")
                }

                Section {
                    ForEach(availableSlots, id: \.self) { slot in
                        functionRow(slot)
                    }
                    if availableSlots.isEmpty {
                        Text("Nenhuma função publicada para este jogo.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Funções de \(selectedGame.title)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Funções")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                if serverURL.isEmpty {
                    serverURL = "https://keyauthv2.org/manifest.json"
                }
                if !repositoryStore.sources.contains(where: { $0.manifestURL.absoluteString == serverURL }) {
                    _ = repositoryStore.addSource(rawURL: serverURL)
                }
            }
            .onChange(of: selectedGameRawValue) { _ in
                enabled.removeAll()
            }
        }
    }

    private var gameCards: some View {
        HStack(spacing: 12) {
            gameCard(.normal)
            gameCard(.max)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }

    private func gameCard(_ game: Game) -> some View {
        let isSelected = selectedGame == game
        return Button {
            selectedGameRawValue = game.rawValue
        } label: {
            VStack(spacing: 8) {
                Text(game.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Image(game.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 3 : 1)
                    }
                Text(game.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Selecionar \(game.title)")
    }

    private func functionRow(_ slot: Int) -> some View {
        let record = packageRecord(for: slot)
        let busy = isWorking.contains(slot)
        let metadata = functionMetadata(for: slot)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(metadata.name)
                    .font(.headline)
                Text(metadata.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Bundle: \(selectedGame.bundleID)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            if busy {
                ProgressView()
            } else {
                Toggle("", isOn: Binding(
                    get: { isActive(slot) },
                    set: { setEnabled($0, slot: slot) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
                .disabled(record == nil && !isActive(slot))
            }
        }
        .contentShape(Rectangle())
    }

    private func functionMetadata(for slot: Int) -> (name: String, description: String) {
        if selectedGame == .max {
            switch slot {
            case 1: return ("HS ALTO", "HS acima da cabeça")
            case 2: return ("HS PESCOÇO", "HS no pescoço")
            default: return ("HS ALTO + PESCOÇO", "HS acima da cabeça e no pescoço")
            }
        }
        switch slot {
        case 1: return ("HS Alto", "HS acima da cabeça do inimigo")
        case 2: return ("HS Pescoço", "HS no pescoço do inimigo")
        case 3: return ("HS Alto + Pescoço", "HS acima da cabeça e no pescoço do inimigo")
        case 4: return ("ESP", "ESP: linha, caixa, vida e nome")
        default: return ("Função 5", "Payload adicional configurado no servidor")
        }
    }

    private func packageRecord(for slot: Int) -> RepositoryPackageRecord? {
        let slotKey = selectedGame == .max ? "function-max-\(slot)" : "function-\(slot)"
        return repositoryStore.packages.first {
            guard $0.package.kind == .patch else { return false }
            let identifiers = Set($0.package.tags.map { $0.lowercased() })
            let category = $0.package.category?.lowercased()
            let isSlotMatch = category == slotKey || identifiers.contains(slotKey)
            let isGameMatch = identifiers.contains(selectedGame.manifestTag) || identifiers.contains("bundle-\(selectedGame.bundleID)")
            // Existing normal payloads remain compatible until the manifest is tagged.
            let isLegacyNormal = selectedGame == .normal && !identifiers.contains("game-freefire-max") && !identifiers.contains("game-freefire-normal")
            return isSlotMatch && (isGameMatch || isLegacyNormal)
        }
    }

    private func storedProjectID(for slot: Int) -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: projectDefaultsKey(slot)) else { return nil }
        return UUID(uuidString: raw)
    }

    private func projectDefaultsKey(_ slot: Int) -> String {
        "function.\(selectedGame.rawValue).project.\(slot)"
    }

    private func isActive(_ slot: Int) -> Bool {
        if enabled.contains(slot) { return true }
        guard let projectID = storedProjectID(for: slot),
              DevicePatchService.latestReceipt(projectID: projectID) != nil else { return false }
        return true
    }

    private func setEnabled(_ value: Bool, slot: Int) {
        guard !isWorking.contains(slot) else { return }
        value ? activate(slot: slot) : deactivate(slot: slot)
    }

    private func activate(slot: Int) {
        guard let record = packageRecord(for: slot) else {
            presentFailure("Não existe payload publicado e configurado para \(selectedGame.title).")
            return
        }
        isWorking.insert(slot)
        let game = selectedGame
        Task { @MainActor in
            defer { isWorking.remove(slot) }
            do {
                let data = try await PackageRepositoryNetworkClient.download(record.package)
                let summary = try PatchPackageCodec.inspect(data)
                guard !summary.isPasswordProtected else { throw PatchPackageError.invalidPasswordOrCorruptedPackage }
                let decoded = try PatchPackageCodec.decode(data, password: nil)
                guard decoded.project.allBundleIdentifiers.contains(game.bundleID) else {
                    throw PatchPackageError.targetAppUnavailable(game.bundleID)
                }
                guard patchStore.importPackage(data: data, password: nil) else { throw PatchPackageError.remoteImportFailed }
                while patchStore.isBusy { try await Task.sleep(nanoseconds: 100_000_000) }
                patchStore.reload()
                guard let item = patchStore.items.first(where: { $0.id == summary.packageID }), let project = item.project else {
                    throw PatchPackageError.invalidProject
                }
                guard await appState.ensureExploitAccess() else { throw PatchPackageError.applyFailed }
                _ = try await Task.detached(priority: .userInitiated) { try DevicePatchService.apply(project: project) }.value
                UserDefaults.standard.set(item.id.uuidString, forKey: projectDefaultsKey(slot))
                enabled.insert(slot)
                presentSuccess("Payload de \(game.title) injetado com sucesso.")
            } catch let error as LocalizedError {
                enabled.remove(slot)
                presentFailure(error.errorDescription ?? "Não foi possível aplicar o payload.")
            } catch {
                enabled.remove(slot)
                presentFailure("O payload foi recusado: ele não está configurado para \(game.bundleID).")
            }
        }
    }

    private func deactivate(slot: Int) {
        guard let projectID = storedProjectID(for: slot), let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
            enabled.remove(slot)
            presentFailure("Nenhum patch ativo encontrado para esta função.")
            return
        }
        isWorking.insert(slot)
        Task { @MainActor in
            defer { isWorking.remove(slot) }
            do {
                guard await appState.ensureExploitAccess() else { throw PatchPackageError.restoreFailed }
                try await Task.detached(priority: .userInitiated) { try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true) }.value
                enabled.remove(slot)
                UserDefaults.standard.removeObject(forKey: projectDefaultsKey(slot))
                presentSuccess("Restaurado com sucesso")
            } catch let error as LocalizedError {
                enabled.insert(slot)
                presentFailure(error.errorDescription ?? "Não foi possível restaurar a função.")
            } catch {
                enabled.insert(slot)
                presentFailure("Não foi possível restaurar o payload da função.")
            }
        }
    }

    private func presentSuccess(_ message: String) {
        alertTitle = "Sucesso"
        alertMessage = message
    }

    private func presentFailure(_ message: String) {
        alertTitle = "Falha"
        alertMessage = message
    }
}
