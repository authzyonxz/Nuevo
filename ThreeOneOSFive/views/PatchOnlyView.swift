import SwiftUI
import CryptoKit

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
    let channel: String
    let functions: [DKManifestFunction]
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

private enum DKPublicChannel {
    static let serverURL = URL(string: "https://update3105-n73qampn.manus.space")!
}

private enum DKOnlineError: LocalizedError {
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

    func fetchManifest() async throws -> DKManifest {
        let url = DKPublicChannel.serverURL
            .appendingPathComponent("api/public")
            .appendingPathComponent("manifest")
        var request = URLRequest(url: url)
        prepare(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let manifest = try JSONDecoder().decode(DKManifest.self, from: data)
        guard manifest.schemaVersion == 1 else { throw DKOnlineError.invalidResponse }
        return manifest
    }

    func download(bundle: DKPublishedBundle) async throws -> Data {
        guard bundle.sizeBytes > 0, bundle.sizeBytes <= maximumBytes else {
            throw DKOnlineError.packageTooLarge
        }
        guard let url = URL(string: bundle.downloadPath, relativeTo: DKPublicChannel.serverURL)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == DKPublicChannel.serverURL.host?.lowercased(),
              url.port == DKPublicChannel.serverURL.port else {
            throw DKOnlineError.invalidResponse
        }
        var request = URLRequest(url: url)
        prepare(&request)
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

    private func prepare(_ request: inout URLRequest) {
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
    @State private var manifest: DKManifest?
    @State private var localStates: [DKFunctionKey: DKLocalFunctionState] = [:]
    @State private var busyFunction: DKFunctionKey?
    @State private var isRefreshing = false
    @State private var workingMessage: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    private let client = DKOnlineClient()

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
                Task { await refreshManifest() }
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
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(.black)
                .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityLabel("Canal público")
        }
    }

    private var connectionBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: .white.opacity(0.8), radius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Canal público DK IPA")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(manifest == nil ? "Sincronizando pacotes públicos..." : "Disponível para todos · HTTPS")
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
            .disabled(isRefreshing)
            .accessibilityLabel("Atualizar pacotes publicados")
            .accessibilityHint("Consulta novamente as quatro funções no painel HTTPS")
        }
        .padding(16)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12)))
    }

    private var functionGrid: some View {
        VStack(spacing: 12) {
            ForEach(DKFunctionKey.allCases) { key in functionRow(key) }
        }
    }

    private func functionRow(_ key: DKFunctionKey) -> some View {
        let remote = manifest?.functions.first { $0.key == key }
        let bundle = remote?.bundle
        let active = localStates[key] != nil
        let busy = busyFunction == key
        let disabled = busy || busyFunction != nil || (!active && bundle == nil)
        return HStack(spacing: 16) {
            Text(key.number)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(active ? .black : .white.opacity(0.45))
                .frame(width: 34, height: 34)
                .background(active ? .white : .white.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(key.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(bundle.map { "\($0.name) · v\($0.version)" } ?? "Nenhum pacote publicado")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                if let knowledge = bundle?.knowledge.first {
                    Text(knowledge)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.34))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if busy { ProgressView().tint(.white).frame(width: 52) }
            else {
                Toggle("", isOn: Binding(
                    get: { active },
                    set: { enabled in
                        if enabled { activate(function: key, remote: remote) }
                        else { restore(function: key) }
                    }
                ))
                .labelsHidden()
                .tint(.green)
                .disabled(disabled)
                .accessibilityLabel(active ? "Desligar \(key.title)" : "Ligar \(key.title)")
                .accessibilityValue(bundle.map { "\($0.name), versão \($0.version)" } ?? "Sem pacote publicado")
                .accessibilityHint(active ? "Desliga e restaura os arquivos originais" : "Baixa, valida e aplica o pacote publicado")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(active ? 0.32 : 0.11)))
    }

    @MainActor
    private func refreshManifest() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            manifest = try await client.fetchManifest()
            reloadLocalStates()
            statusMessage = "Pacotes sincronizados e prontos para validação local."
        } catch { errorMessage = error.localizedDescription }
    }

    private func activate(function key: DKFunctionKey, remote: DKManifestFunction?) {
        guard busyFunction == nil else { return }
        guard let bundle = remote?.bundle else {
            errorMessage = DKOnlineError.noPublishedBundle.localizedDescription
            return
        }
        busyFunction = key
        workingMessage = "Baixando e validando \(key.title)..."
        statusMessage = nil
        Task {
            do {
                let data = try await client.download(bundle: bundle)
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
            } catch {
                busyFunction = nil
                workingMessage = nil
                errorMessage = error.localizedDescription
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
        busyFunction = key
        workingMessage = "Restaurando arquivos originais de \(key.title)..."
        statusMessage = nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try DevicePatchService.restore(receipt: receipt) }.value
                DKLocalStateStore.clear(key)
                localStates[key] = nil
                busyFunction = nil
                workingMessage = nil
                statusMessage = "\(key.title) desligada e arquivos originais restaurados."
            } catch {
                busyFunction = nil
                workingMessage = nil
                errorMessage = error.localizedDescription
            }
        }
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
                let animationTime = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate * 0.16
                drawMesh(context: &context, size: size, time: animationTime)
            }
        }
        .opacity(0.92)
        .mask(LinearGradient(colors: [.clear, .white, .white.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom))
    }

    private func drawMesh(context: inout GraphicsContext, size: CGSize, time: Double) {
        let points = makePoints(size: size, time: time)
        drawConnections(points: points, context: &context)
        drawNodes(points: points, context: &context)
    }

    private func makePoints(size: CGSize, time: Double) -> [CGPoint] {
        (0..<42).map { index in
            let x = seeded(index * 2 + 1) * size.width
            let baseY = size.height * (0.08 + seeded(index * 2 + 2) * 0.78)
            let phase = time + Double(index) * 0.71 + Double(x) * 0.008
            return CGPoint(x: x, y: baseY + sin(phase) * 15)
        }
    }

    private func drawConnections(points: [CGPoint], context: inout GraphicsContext) {
        for first in points.indices {
            for second in points.indices where second > first {
                let start = points[first]
                let end = points[second]
                let distance = hypot(start.x - end.x, start.y - end.y)
                guard distance < 118 else { continue }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                let opacity = (1 - distance / 118) * 0.18
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 0.55)
            }
        }
    }

    private func drawNodes(points: [CGPoint], context: inout GraphicsContext) {
        for (index, point) in points.enumerated() {
            let highlighted = index.isMultiple(of: 8)
            let radius = highlighted ? 1.7 : 0.9
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let opacity = highlighted ? 0.8 : 0.36
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private func seeded(_ value: Int) -> Double {
        let raw = sin(Double(value) * 12.9898 + 78.233) * 43_758.5453
        return raw - floor(raw)
    }
}
