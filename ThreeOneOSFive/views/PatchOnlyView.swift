import SwiftUI
import CryptoKit
import Security

private enum DKFunctionKey: String, Codable, CaseIterable, Identifiable {
    case function1 = "function_1"
    case function2 = "function_2"
    case function3 = "function_3"
    case function4 = "function_4"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .function1: return "FUNÇÃO 1"
        case .function2: return "FUNÇÃO 2"
        case .function3: return "FUNÇÃO 3"
        case .function4: return "FUNÇÃO 4"
        }
    }

    var number: String {
        switch self {
        case .function1: return "01"
        case .function2: return "02"
        case .function3: return "03"
        case .function4: return "04"
        }
    }
}

private struct DKManifest: Decodable {
    let schemaVersion: Int
    let target: DKManifestTarget
    let functions: [DKManifestFunction]
}

private struct DKManifestTarget: Decodable {
    let id: Int
    let name: String
    let host: String
    let port: Int?
}

private struct DKManifestFunction: Decodable, Identifiable {
    var id: DKFunctionKey { key }
    let key: DKFunctionKey
    let bundle: DKPublishedBundle?
}

private struct DKPublishedBundle: Decodable {
    let id: Int
    let name: String
    let version: String
    let description: String
    let knowledge: [String]
    let restoreNotes: String?
    let fileName: String
    let sizeBytes: Int
    let sha256: String
    let downloadPath: String
}

private struct DKClientConfiguration {
    let serverURL: URL
    let targetID: Int
    let token: String

    static func make(server: String, targetID: String, token: String) throws -> Self {
        let cleanServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanServer),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              let id = Int(targetID),
              id > 0,
              !cleanToken.isEmpty else {
            throw DKOnlineError.invalidConfiguration
        }
        return Self(serverURL: url, targetID: id, token: cleanToken)
    }
}

private enum DKOnlineError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case insecureResponse
    case noPublishedBundle
    case packageTooLarge
    case sizeMismatch
    case checksumMismatch
    case protectedPackage
    case localProjectUnavailable
    case noRestoreReceipt

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Informe uma URL HTTPS, o ID do alvo e o token do dispositivo."
        case .invalidResponse:
            return "O painel retornou uma resposta inválida."
        case .insecureResponse:
            return "A conexão deixou de ser HTTPS e foi bloqueada."
        case .noPublishedBundle:
            return "Nenhum bundle foi publicado para esta função."
        case .packageTooLarge:
            return "O pacote excede o limite local de 24 MB."
        case .sizeMismatch:
            return "O tamanho do pacote não corresponde ao manifesto."
        case .checksumMismatch:
            return "A validação SHA-256 falhou. O pacote não foi aplicado."
        case .protectedPackage:
            return "Bundles online protegidos por senha não podem ser aplicados automaticamente."
        case .localProjectUnavailable:
            return "O pacote foi importado, mas o projeto local não ficou disponível."
        case .noRestoreReceipt:
            return "Não existe recibo local válido para restaurar esta função."
        }
    }
}

private actor DKOnlineClient {
    private let maximumBytes = 24 * 1024 * 1024

    func fetchManifest(configuration: DKClientConfiguration) async throws -> DKManifest {
        let url = configuration.serverURL
            .appendingPathComponent("api/device")
            .appendingPathComponent(String(configuration.targetID))
            .appendingPathComponent("manifest")
        var request = URLRequest(url: url)
        authorize(&request, configuration: configuration)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let manifest = try JSONDecoder().decode(DKManifest.self, from: data)
        guard manifest.schemaVersion == 1 else { throw DKOnlineError.invalidResponse }
        return manifest
    }

    func download(bundle: DKPublishedBundle, configuration: DKClientConfiguration) async throws -> Data {
        guard bundle.sizeBytes > 0, bundle.sizeBytes <= maximumBytes else {
            throw DKOnlineError.packageTooLarge
        }
        guard let url = URL(string: bundle.downloadPath, relativeTo: configuration.serverURL)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == configuration.serverURL.host?.lowercased(),
              url.port == configuration.serverURL.port else {
            throw DKOnlineError.invalidResponse
        }
        var request = URLRequest(url: url)
        authorize(&request, configuration: configuration)
        request.timeoutInterval = 120
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        guard data.count == bundle.sizeBytes else { throw DKOnlineError.sizeMismatch }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(bundle.sha256) == .orderedSame else {
            throw DKOnlineError.checksumMismatch
        }
        return data
    }

    func report(
        action: String,
        function: DKFunctionKey,
        bundleID: Int?,
        message: String?,
        configuration: DKClientConfiguration
    ) async {
        let url = configuration.serverURL
            .appendingPathComponent("api/device")
            .appendingPathComponent(String(configuration.targetID))
            .appendingPathComponent("events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authorize(&request, configuration: configuration)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "functionKey": function.rawValue,
            "action": action
        ]
        if let bundleID { payload["bundleId"] = bundleID }
        if let message { payload["message"] = String(message.prefix(2_000)) }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: request)
    }

    private func authorize(_ request: inout URLRequest, configuration: DKClientConfiguration) {
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("DK-IPA/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              http.url?.scheme?.lowercased() == "https" else {
            throw DKOnlineError.insecureResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DKOnlineError.invalidResponse
        }
    }
}

private enum DKDeviceTokenStore {
    private static let service = "com.apple.mobile.MobileHouseArrest.dkipa"
    private static let account = "device-token"

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = data
            insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else {
                throw PatchPackageError.keychainFailed
            }
        } else if status != errSecSuccess {
            throw PatchPackageError.keychainFailed
        }
    }
}

private struct DKLocalFunctionState {
    let bundleID: Int
    let projectID: UUID
}

private enum DKLocalStateStore {
    static func load(_ function: DKFunctionKey) -> DKLocalFunctionState? {
        let defaults = UserDefaults.standard
        let bundleID = defaults.integer(forKey: "dkipa.\(function.rawValue).bundle")
        guard bundleID > 0,
              let rawProjectID = defaults.string(forKey: "dkipa.\(function.rawValue).project"),
              let projectID = UUID(uuidString: rawProjectID),
              DevicePatchService.latestReceipt(projectID: projectID) != nil else { return nil }
        return DKLocalFunctionState(bundleID: bundleID, projectID: projectID)
    }

    static func save(_ state: DKLocalFunctionState, for function: DKFunctionKey) {
        let defaults = UserDefaults.standard
        defaults.set(state.bundleID, forKey: "dkipa.\(function.rawValue).bundle")
        defaults.set(state.projectID.uuidString, forKey: "dkipa.\(function.rawValue).project")
    }

    static func clear(_ function: DKFunctionKey) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "dkipa.\(function.rawValue).bundle")
        defaults.removeObject(forKey: "dkipa.\(function.rawValue).project")
    }
}

struct PatchOnlyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: PatchProjectStore
    @AppStorage("dkipa.serverURL") private var serverURL = ""
    @AppStorage("dkipa.targetID") private var targetID = ""
    @State private var deviceToken = DKDeviceTokenStore.load()
    @State private var manifest: DKManifest?
    @State private var localStates: [DKFunctionKey: DKLocalFunctionState] = [:]
    @State private var busyFunction: DKFunctionKey?
    @State private var isRefreshing = false
    @State private var showConfiguration = false
    @State private var workingMessage: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    private let client = DKOnlineClient()

    private var configuration: DKClientConfiguration? {
        try? DKClientConfiguration.make(server: serverURL, targetID: targetID, token: deviceToken)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                DKMeshBackground(reduceMotion: reduceMotion)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        connectionBar
                        functionGrid
                        if let workingMessage { progressCard(workingMessage) }
                        if let statusMessage { statusCard(statusMessage) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .refreshable { await refreshManifest() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showConfiguration) { configurationSheet }
            .alert("Não foi possível concluir", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Falha desconhecida.")
            }
            .onAppear {
                reloadLocalStates()
                if configuration != nil { Task { await refreshManifest() } }
            }
            .patchStorePresentation(store)
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DK IPA / 3105")
                    .font(.caption2.monospaced().weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.48))
                Text("Funções online")
                    .font(.largeTitle.bold())
                    .tracking(-1.1)
                    .foregroundStyle(.white)
                Text("Baixe, valide e aplique bundles no próprio dispositivo.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer(minLength: 12)
            Button { showConfiguration = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.black)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .accessibilityLabel("Configurar conexão")
        }
    }

    private var connectionBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(configuration != nil ? Color.white : Color.white.opacity(0.2))
                .frame(width: 8, height: 8)
                .shadow(color: .white.opacity(configuration != nil ? 0.8 : 0), radius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(manifest?.target.name ?? (configuration == nil ? "Conexão não configurada" : "Alvo configurado"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(connectionSubtitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
            }
            Spacer()
            Button { Task { await refreshManifest() } } label: {
                Group {
                    if isRefreshing { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .frame(width: 38, height: 38)
                .foregroundStyle(.white)
                .background(.white.opacity(0.08), in: Circle())
            }
            .disabled(configuration == nil || isRefreshing)
            .accessibilityLabel("Atualizar pacotes publicados")
            .accessibilityHint("Consulta novamente as quatro funções no painel HTTPS")
        }
        .padding(16)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12)))
    }

    private var connectionSubtitle: String {
        guard let target = manifest?.target else {
            return configuration == nil ? "Toque nos ajustes para conectar" : "Puxe para sincronizar"
        }
        return target.port.map { "\(target.host):\($0)" } ?? target.host
    }

    private var functionGrid: some View {
        LazyVGrid(columns: functionColumns, spacing: 12) {
            ForEach(DKFunctionKey.allCases) { key in functionCard(key) }
        }
    }

    private var functionColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: 155), spacing: 12)]
    }

    private func functionCard(_ key: DKFunctionKey) -> some View {
        let remote = manifest?.functions.first { $0.key == key }
        let bundle = remote?.bundle
        let active = localStates[key] != nil
        let busy = busyFunction == key
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(key.number)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(active ? .black : .white.opacity(0.45))
                    .frame(width: 34, height: 34)
                    .background(active ? .white : .white.opacity(0.07), in: Circle())
                Spacer()
                Circle()
                    .fill(active ? .white : .white.opacity(0.16))
                    .frame(width: 7, height: 7)
                    .shadow(color: .white.opacity(active ? 0.9 : 0), radius: 7)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(key.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(bundle.map { "\($0.name) · v\($0.version)" } ?? "Sem pacote publicado")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)
            }
            Text(bundle?.knowledge.first ?? "Aguardando publicação")
                .font(.caption2)
                .foregroundStyle(.white.opacity(bundle == nil ? 0.26 : 0.38))
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)
            Button {
                if active { restore(function: key) }
                else { activate(function: key, remote: remote) }
            } label: {
                HStack(spacing: 7) {
                    if busy { ProgressView().tint(active ? .black : .white) }
                    else { Image(systemName: active ? "power" : "arrow.down.circle.fill") }
                    Text(active ? "DESLIGAR" : "LIGAR")
                        .font(.caption.monospaced().weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .foregroundStyle(active ? .black : .white)
                .background(active ? .white : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(active ? 0 : 0.14)))
            }
            .disabled(busy || busyFunction != nil || (!active && bundle == nil))
            .accessibilityLabel(active ? "Desligar \(key.title)" : "Ligar \(key.title)")
            .accessibilityValue(bundle.map { "\($0.name), versão \($0.version)" } ?? "Sem pacote publicado")
            .accessibilityHint(active ? "Restaura os arquivos originais desta função" : "Baixa, valida e aplica o pacote publicado")
        }
        .padding(16)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(active ? 0.32 : 0.11)))
    }

    private var configurationSheet: some View {
        NavigationStack {
            Form {
                Section("Painel HTTPS") {
                    TextField("https://seu-painel.exemplo", text: $serverURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                Section("Alvo autorizado") {
                    TextField("ID do alvo", text: $targetID).keyboardType(.numberPad)
                    SecureField("Token do dispositivo", text: $deviceToken)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Button("Salvar e conectar") { saveConfiguration() }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("O token fica no Keychain. O IP do painel é apenas inventário; aplicar e restaurar acontece neste aparelho.")
                }
            }
            .scrollContentBackground(.hidden).background(Color.black)
            .navigationTitle("Conexão DK IPA").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { showConfiguration = false } } }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func refreshManifest() async {
        guard let configuration else { showConfiguration = true; return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            manifest = try await client.fetchManifest(configuration: configuration)
            reloadLocalStates()
            statusMessage = "Pacotes sincronizados e prontos para validação local."
        } catch { errorMessage = error.localizedDescription }
    }

    private func activate(function key: DKFunctionKey, remote: DKManifestFunction?) {
        guard busyFunction == nil else { return }
        guard let configuration else { showConfiguration = true; return }
        guard let bundle = remote?.bundle else {
            errorMessage = DKOnlineError.noPublishedBundle.localizedDescription
            return
        }
        busyFunction = key
        workingMessage = "Baixando e validando \(key.title)..."
        statusMessage = nil
        Task {
            await client.report(action: "apply_started", function: key, bundleID: bundle.id, message: "Validação local iniciada.", configuration: configuration)
            do {
                let data = try await client.download(bundle: bundle, configuration: configuration)
                let summary = try PatchPackageCodec.inspect(data)
                guard !summary.isPasswordProtected else { throw DKOnlineError.protectedPackage }
                let projectID = try await store.importOnlinePackage(data: data)
                guard let item = store.items.first(where: { $0.id == projectID }),
                      let baseProject = item.project else { throw DKOnlineError.localProjectUnavailable }
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try await Task.detached(priority: .userInitiated) {
                    try DevicePatchService.apply(project: project)
                }.value
                let state = DKLocalFunctionState(bundleID: bundle.id, projectID: projectID)
                DKLocalStateStore.save(state, for: key)
                localStates[key] = state
                busyFunction = nil
                workingMessage = nil
                statusMessage = "\(key.title) ativada com o bundle v\(bundle.version)."
                await client.report(action: "applied", function: key, bundleID: bundle.id, message: "Pacote validado e aplicado localmente.", configuration: configuration)
            } catch {
                busyFunction = nil
                workingMessage = nil
                errorMessage = error.localizedDescription
                await client.report(action: "failed", function: key, bundleID: bundle.id, message: error.localizedDescription, configuration: configuration)
            }
        }
    }

    private func restore(function key: DKFunctionKey) {
        guard busyFunction == nil, let state = localStates[key] else { return }
        guard let receipt = DevicePatchService.latestReceipt(projectID: state.projectID) else {
            DKLocalStateStore.clear(key)
            reloadLocalStates()
            errorMessage = DKOnlineError.noRestoreReceipt.localizedDescription
            return
        }
        let currentConfiguration = configuration
        busyFunction = key
        workingMessage = "Restaurando arquivos originais de \(key.title)..."
        statusMessage = nil
        Task {
            if let currentConfiguration {
                await client.report(action: "restore_started", function: key, bundleID: state.bundleID, message: "Restauração local iniciada.", configuration: currentConfiguration)
            }
            do {
                try await Task.detached(priority: .userInitiated) { try DevicePatchService.restore(receipt: receipt) }.value
                DKLocalStateStore.clear(key)
                localStates[key] = nil
                busyFunction = nil
                workingMessage = nil
                statusMessage = "\(key.title) desligada e arquivos originais restaurados."
                if let currentConfiguration {
                    await client.report(action: "restored", function: key, bundleID: state.bundleID, message: "Arquivos originais restaurados localmente.", configuration: currentConfiguration)
                }
            } catch {
                busyFunction = nil
                workingMessage = nil
                errorMessage = error.localizedDescription
                if let currentConfiguration {
                    await client.report(action: "failed", function: key, bundleID: state.bundleID, message: error.localizedDescription, configuration: currentConfiguration)
                }
            }
        }
    }

    private func saveConfiguration() {
        do {
            _ = try DKClientConfiguration.make(server: serverURL, targetID: targetID, token: deviceToken)
            try DKDeviceTokenStore.save(deviceToken)
            showConfiguration = false
            Task { await refreshManifest() }
        } catch { errorMessage = error.localizedDescription }
    }

    private func reloadLocalStates() {
        localStates = Dictionary(uniqueKeysWithValues: DKFunctionKey.allCases.compactMap { key in
            DKLocalStateStore.load(key).map { (key, $0) }
        })
    }

    private func progressCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView().tint(.white)
            Text(message).font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding(15)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
    }

    private func statusCard(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DKMeshBackground: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.16
                let points = (0..<42).map { index -> CGPoint in
                    let x = seeded(index * 2 + 1) * size.width
                    let baseY = size.height * (0.08 + seeded(index * 2 + 2) * 0.78)
                    let wave = sin(time + Double(index) * 0.71 + Double(x) * 0.008) * 15
                    return CGPoint(x: x, y: baseY + wave)
                }
                for first in points.indices {
                    for second in points.indices where second > first {
                        let a = points[first]
                        let b = points[second]
                        let distance = hypot(a.x - b.x, a.y - b.y)
                        guard distance < 118 else { continue }
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        context.stroke(path, with: .color(.white.opacity((1 - distance / 118) * 0.18)), lineWidth: 0.55)
                    }
                }
                for (index, point) in points.enumerated() {
                    let radius = index.isMultiple(of: 8) ? 1.7 : 0.9
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(index.isMultiple(of: 8) ? 0.8 : 0.36)))
                }
            }
        }
        .opacity(0.92)
        .mask(LinearGradient(colors: [.clear, .white, .white.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom))
    }

    private func seeded(_ value: Int) -> Double {
        let raw = sin(Double(value) * 12.9898 + 78.233) * 43_758.5453
        return raw - floor(raw)
    }
}
