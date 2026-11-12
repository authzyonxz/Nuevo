// language: Swift, file: AirliftPairing.swift, target: iOS 18+
//
// Guarda o pairing record, detecta o túnel de loopback, hospeda o pareamento
// on-device (iOS 27+) e monta o cartão de acesso da UI.
//
// Sem pairing + sem túnel o Airlift não abre sessão: os dois são pré-requisitos
// reais, não burocracia. O cartão mostra o estado cru pra não mentir ao usuário.

import AVFAudio
import Foundation
import Network
import SwiftUI
import UIKit
import AirliftFFI

// MARK: - Store do pairing record

enum AirliftPairing {
    static let pairingFilename = "airlift_pairing.plist"

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var canonicalURL: URL { documentsURL.appendingPathComponent(pairingFilename) }

    /// Extensões que o app reconhece ao varrer Documents.
    private static let candidateExtensions: Set<String> = ["plist", "mobilepair", "mobiledevicepairing"]

    static func activePath() -> String? {
        let path = canonicalURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        return size > 0 ? path : nil
    }

    static func hasActive() -> Bool { activePath() != nil }

    struct Info: Equatable {
        let deviceName: String
        let deviceUDID: String
        let byteCount: Int
        let fileURL: URL
    }

    /// Lê o pairing record ativo e devolve o que ele declara.
    static func activeInfo() -> Info? {
        guard let path = activePath(), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return parse(data: data, fileURL: URL(fileURLWithPath: path))
    }

    static func parse(data: Data, fileURL: URL) -> Info? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        let udid = (dict["UniqueDeviceID"] as? String)
            ?? (dict["UDID"] as? String)
            ?? (dict["TargetDeviceUDID"] as? String)
            ?? ""
        let name = (dict["DeviceName"] as? String)
            ?? (dict["ProductType"] as? String)
            ?? "iPhone"
        return Info(deviceName: name, deviceUDID: udid, byteCount: data.count, fileURL: fileURL)
    }

    enum ImportError: Error, LocalizedError {
        case unreadable(String)
        case notAPairingRecord

        var errorDescription: String? {
            switch self {
            case .unreadable(let detail): return "Não consegui ler o arquivo: \(detail)"
            case .notAPairingRecord: return "Esse arquivo não parece um pairing record válido (sem UDID nem certificados)."
            }
        }
    }

    /// Copia o arquivo escolhido para o caminho canônico.
    @discardableResult
    static func importFile(from source: URL) throws -> Info {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: source)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }
        guard !data.isEmpty else { throw ImportError.unreadable("arquivo vazio") }
        guard let info = parse(data: data, fileURL: canonicalURL) else {
            throw ImportError.notAPairingRecord
        }

        try data.write(to: canonicalURL, options: .atomic)
        log("airlift: pairing importado (\(data.count) bytes)")
        return info
    }

    static func deleteActive() {
        try? FileManager.default.removeItem(at: canonicalURL)
        log("airlift: pairing removido")
    }

    /// Importa um pairing record colado como base64. Serve para o caminho
    /// "PC → copiar o blob → colar no app" quando o usuário não tem como
    /// mandar arquivo por Files/iCloud.
    @discardableResult
    static func importBase64(_ text: String) throws -> Info {
        let cleaned = text.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { throw ImportError.unreadable("texto vazio") }

        // Aceita base64 padrão e base64url.
        var normalized = cleaned
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 { normalized += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: normalized), !data.isEmpty else {
            throw ImportError.unreadable("base64 inválido")
        }
        guard let info = parse(data: data, fileURL: canonicalURL) else {
            throw ImportError.notAPairingRecord
        }
        try data.write(to: canonicalURL, options: .atomic)
        log("airlift: pairing importado por base64 (\(data.count) bytes)")
        return info
    }

    /// Devolve o pairing ativo em base64 (backup/suporte).
    static func activeBase64() -> String? {
        guard let path = activePath(), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return data.base64EncodedString()
    }

    /// Adota silenciosamente o primeiro pairing file que estiver em Documents.
    /// É o que fecha o fluxo do script no PC: ele empurra o `airlift_pairing.plist`
    /// direto para a pasta do app e não existe mais botão para tocar.
    @discardableResult
    static func autoAdoptIfNeeded() -> Info? {
        if let existing = activeInfo() { return existing }
        guard let candidate = discoverCandidates().first else { return nil }
        guard let info = try? importFile(from: candidate) else { return nil }
        log("airlift: pairing adotado automaticamente de \(candidate.lastPathComponent)")
        return info
    }

    /// Varre Documents atrás de pairing files que o usuário tenha deixado lá
    /// (via Files app ou por outro sideloader).
    static func discoverCandidates() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.filter { url in
            let ext = url.pathExtension.lowercased()
            guard candidateExtensions.contains(ext) else { return false }
            if url.lastPathComponent == pairingFilename, hasActive() { return false }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return size > 0
        }
    }
}

// MARK: - Estado do túnel

enum LoopbackTunnel {
    /// O LocalDevVPN publica o RSD em 10.7.0.1:49152 pelo próprio loopback.
    static let host = Airlift.defaultTunnelHost

    struct Status: Equatable {
        let up: Bool
        let detail: String
    }

    static func status() -> Status {
        let names = interfaceNames()
        let detail = names.isEmpty ? "sem interfaces" : names.joined(separator: ", ")
        let up = names.contains { name in
            name.hasPrefix("utun") || name.hasPrefix("ipsec")
                || name.hasPrefix("tap") || name.hasPrefix("ppp")
        }
        return Status(up: up, detail: detail)
    }

    static func isUp() -> Bool { status().up }

    private static func interfaceNames() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            if !result.contains(name) { result.append(name) }
        }
        return result
    }

    static func openVPNApp() {
        guard let url = URL(string: "localdevvpn://") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - Pareamento on-device (iOS 27+)

/// Hospeda o RPPairing: anuncia por Bonjour, mantém o app vivo enquanto o
/// usuário aprova o PIN em Ajustes › Privacidade e Segurança › Modo Desenvolvedor.
@MainActor
final class OnDevicePairing: NSObject, ObservableObject, NetServiceDelegate {
    static let shared = OnDevicePairing()

    @Published private(set) var running = false
    @Published var status: String = "ocioso"
    @Published var pin: String?

    private let hostName = "3105"
    private let hostModel = "Mac17,7"
    private let bindAddress = "0.0.0.0"

    private var netService: NetService?
    private var continuation: CheckedContinuation<AirliftPairing.Info, Error>?
    private let keepAlive = PairingKeepAlive()
    private let localNetwork = LocalNetworkProbe()

    private static let altIRKKey = "airlift.pairingHostAltIRK"

    private var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: Self.altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.altIRKKey) }
    }

    enum PairingError: LocalizedError {
        case busy
        case failed(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .busy: return "Já existe um pareamento em andamento."
            case .failed(let message): return message
            case .empty: return "O pareamento gerou um arquivo vazio. Aprove a solicitação e tente de novo."
            }
        }
    }

    func startAndWait() async throws -> AirliftPairing.Info {
        guard !running else { throw PairingError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    func cancel() {
        stopAdvertising()
        keepAlive.stop()
        running = false
        pin = nil
        status = "cancelado"
        resolve(.failure(CancellationError()))
    }

    private func start() {
        stopAdvertising()
        keepAlive.stop()
        running = true
        pin = nil
        status = "subindo host local…"

        Task {
            _ = await localNetwork.request()
            guard running else { return }
            keepAlive.start()
            status = "anunciando — abra Ajustes para parear"
            runHost()
        }
    }

    private func runHost() {
        let name = hostName
        let model = hostModel
        let bind = bindAddress
        let outPath = AirliftPairing.canonicalURL.path
        let altIRK = storedAltIRK
        let ctx = Unmanaged.passUnretained(self).toOpaque()

        Task.detached(priority: .userInitiated) {
            let outcome = Self.launchHost(
                bind: bind,
                name: name,
                model: model,
                outPath: outPath,
                altIRK: altIRK,
                ctx: ctx
            )
            await MainActor.run {
                if !outcome.altIRK.isEmpty { self.storedAltIRK = outcome.altIRK }
                let finalPath = outcome.pairingPath.isEmpty ? outPath : outcome.pairingPath
                self.finish(rc: outcome.rc, failure: outcome.failure, path: finalPath)
            }
        }
    }

    struct HostOutcome {
        let rc: Int32
        let failure: String
        let pairingPath: String
        let altIRK: String
    }

    /// Bloqueia até parear ou falhar. `nonisolated`: roda fora do main actor,
    /// sem tocar em estado isolado — só recebe strings e devolve o resultado.
    nonisolated private static func launchHost(
        bind: String,
        name: String,
        model: String,
        outPath: String,
        altIRK: String,
        ctx: UnsafeMutableRawPointer
    ) -> HostOutcome {
        var result = ALPairResult()
        let rc = bind.withCString { bindC in
            name.withCString { nameC in
                model.withCString { modelC in
                    outPath.withCString { outC in
                        altIRK.withCString { irkC in
                            al_pairing_run_host(
                                bindC, 0, nameC, modelC, outC, irkC,
                                pairingReadyCallback, pairingPinCallback, ctx, &result
                            )
                        }
                    }
                }
            }
        }

        let outcome = HostOutcome(
            rc: rc,
            failure: pairingCString(result.error),
            pairingPath: pairingCString(result.pairing_file_path),
            altIRK: pairingCString(result.host_alt_irk_hex)
        )
        al_pairing_result_free(&result)
        return outcome
    }

    private func finish(rc: Int32, failure: String, path: String) {
        stopAdvertising()
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            keepAlive.stop()
        }
        running = false
        pin = nil

        guard rc == 0 else {
            status = "falhou: \(failure)"
            resolve(.failure(PairingError.failed(failure.isEmpty ? "código \(rc)" : failure)))
            return
        }

        // O core pode gravar num caminho próprio; normaliza para o canônico.
        if path != AirliftPairing.canonicalURL.path,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)), !data.isEmpty {
            try? data.write(to: AirliftPairing.canonicalURL, options: .atomic)
        }

        guard let info = AirliftPairing.activeInfo() else {
            status = "falhou: pairing vazio"
            resolve(.failure(PairingError.empty))
            return
        }
        status = "pareado: \(info.deviceName) (\(info.byteCount) bytes)"
        log("airlift: pareamento on-device concluído — \(info.deviceName)")
        resolve(.success(info))
    }

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        let instance = serviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? hostName : serviceID
        var properties = txt
        // O iOS mostra o nome do host a partir deste TXT. O service_id continua
        // sendo usado como instance técnico do protocolo RPPairing.
        properties["name"] = Data(hostName.utf8)
        if properties["identifier"] == nil { properties["identifier"] = Data(instance.utf8) }
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: instance,
            port: port
        )
        service.delegate = self
        service.setTXTRecord(NetService.data(fromTXTRecord: properties))
        service.schedule(in: .main, forMode: .common)
        service.publish()
        netService = service
        status = "anunciando 3105 — abra Ajustes › Privacidade e Segurança › Modo Desenvolvedor"
    }

    func netServiceDidPublish(_ sender: NetService) {
        status = "3105 visível — abra Ajustes › Modo Desenvolvedor"
        log("airlift: Bonjour publicado name=\(sender.name) type=\(sender.type) port=\(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let details = errorDict.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        status = "falha ao anunciar 3105: \(details)"
        log("airlift: falha ao publicar Bonjour name=\(sender.name) type=\(sender.type) \(details)")
    }

    func netServiceDidStop(_ sender: NetService) {
        log("airlift: Bonjour interrompido name=\(sender.name)")
    }

    fileprivate func presentPin(_ value: String) {
        pin = value
        status = "digite o PIN \(value) em Ajustes › Modo Desenvolvedor › Pair with 3105"
    }

    private func stopAdvertising() {
        netService?.remove(from: .main, forMode: .common)
        netService?.stop()
        netService = nil
    }

    private func resolve(_ result: Result<AirliftPairing.Info, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

private let pairingReadyCallback: ALPairReadyCb = { ctx, serviceID, port, keys, values, count in
    guard let ctx, let serviceID else { return }
    let controller = Unmanaged<OnDevicePairing>.fromOpaque(ctx).takeUnretainedValue()
    let identifier = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys, let values {
        for index in 0..<Int(count) {
            guard let key = keys[index], let value = values[index] else { continue }
            txt[String(cString: key)] = Data(String(cString: value).utf8)
        }
    }
    Task { @MainActor in
        controller.startAdvertising(serviceID: identifier, port: Int32(port), txt: txt)
    }
}

private let pairingPinCallback: ALPairPinCb = { pin, ctx in
    guard let pin, let ctx else { return }
    let controller = Unmanaged<OnDevicePairing>.fromOpaque(ctx).takeUnretainedValue()
    let value = String(cString: pin)
    Task { @MainActor in controller.presentPin(value) }
}

private func pairingCString(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
    guard let pointer else { return "" }
    return String(cString: pointer)
}

// MARK: - Keep-alive e permissão de rede local

/// Áudio silencioso em loop mantém o processo vivo enquanto o usuário sai do
/// app para aprovar o PIN nos Ajustes.
@MainActor
final class PairingKeepAlive {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var running = false

    func start() {
        guard !running else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            engine.attach(player)
            let format = engine.outputNode.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                running = true
                return
            }
            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = max(1024, AVAudioFrameCount(format.sampleRate))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                running = true
                return
            }
            buffer.frameLength = frames
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    memset(channels[channel], 0, Int(frames) * MemoryLayout<Float>.size)
                }
            }
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            running = true
        } catch {
            running = false
        }
    }

    func stop() {
        guard running else { return }
        running = false
        player.stop()
        if engine.isRunning { engine.stop() }
        engine.detach(player)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// Dispara o diálogo de Rede Local com um Bonjour descartável.
@MainActor
final class LocalNetworkProbe {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?

    private let probeType = "_3105probe._tcp"

    func request(timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            self.continuation = continuation

            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let listener = try? NWListener(using: parameters)
            listener?.service = NWListener.Service(name: "3105Probe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: parameters)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard !results.isEmpty else { return }
                MainActor.assumeIsolated { self?.finish() }
            }
            self.browser = browser

            listener?.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated { self?.finish() }
            }
        }
    }

    private func finish() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: true)
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}
