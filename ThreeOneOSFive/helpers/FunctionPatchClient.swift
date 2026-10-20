import CryptoKit
import Foundation

/// O que o site responde em `/api/v1/functions`.
struct FunctionPayloadManifest: Decodable, Equatable {
    let id: String
    let title: String
    let summary: String
    let status: String
    let available: Bool
    let version: Int?
    let filename: String?
    let bundleID: String?
    let relativePath: String?
    let byteSize: Int?
    let sha256: String?
    let notes: String?
    let publishedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, summary, status, available, version, filename
        case bundleID, relativePath, byteSize, sha256, notes, publishedAt
    }
}

/// Arquivo já baixado e verificado, pronto para substituir no container.
struct FunctionPayload: Equatable {
    let functionID: String
    let fileURL: URL
    let filename: String
    let sha256: String
    let byteSize: Int64
    let version: Int
    let relativePath: String?
}

enum FunctionPatchError: Error, LocalizedError, Equatable {
    case invalidServerURL
    case invalidBundleID
    case offline
    case server(String)
    case payloadUnavailable(String)
    case digestMismatch
    case targetAppUnavailable(String)
    case noTargetFile(String)
    case targetChanged(String)
    case applyFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Endereço do servidor inválido. Use algo como https://aim.seudominio.com"
        case .invalidBundleID:
            return "Bundle ID inválido. Exemplo válido: com.dts.freefireth"
        case .offline:
            return "Sem conexão com o servidor. Confira a internet e o endereço do site."
        case .server(let message):
            return "Servidor respondeu: \(message)"
        case .payloadUnavailable(let title):
            return "Ainda não há arquivo publicado para \(title) no site."
        case .digestMismatch:
            return "O arquivo gravado não confere com o que foi baixado. Nada foi mantido."
        case .targetAppUnavailable(let bundleID):
            return "Não achei o container de \(bundleID). O app alvo está instalado?"
        case .noTargetFile(let filename):
            return "O arquivo \(filename) não existe em nenhum lugar do container alvo."
        case .targetChanged(let path):
            return "O arquivo \(path) mudou depois da aplicação. Restaure mesmo assim para forçar."
        case .applyFailed(let detail):
            return "Falha ao aplicar: \(detail)"
        case .restoreFailed(let detail):
            return "Falha ao restaurar: \(detail)"
        }
    }
}

enum FileDigest {
    static func sha256Hex(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

final class FunctionPatchClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - URL

    /// Aceita "aim.seudominio.com", "https://aim.seudominio.com/" e devolve URL limpa.
    static func normalizedBaseURL(_ rawValue: String) -> URL? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.lowercased().hasPrefix("http://"), !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }
        while value.hasSuffix("/") { value.removeLast() }
        guard let url = URL(string: value), let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func cacheDirectory(functionID: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("AimPayloads", isDirectory: true)
            .appendingPathComponent(functionID, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - API

    private struct Envelope<T: Decodable>: Decodable {
        struct Failure: Decodable {
            let code: String
            let message: String
        }
        let ok: Bool
        let data: T?
        let error: Failure?
    }

    func catalog(baseURL: URL) async throws -> [FunctionPayloadManifest] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/functions"))
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw FunctionPatchError.offline }
            guard (200..<300).contains(http.statusCode) else {
                throw FunctionPatchError.server("HTTP \(http.statusCode)")
            }
            let envelope = try decoder.decode(Envelope<[FunctionPayloadManifest]>.self, from: data)
            guard let items = envelope.data else {
                throw FunctionPatchError.server(envelope.error?.message ?? "resposta vazia")
            }
            return items
        } catch let error as FunctionPatchError {
            throw error
        } catch is DecodingError {
            throw FunctionPatchError.server("manifesto inválido")
        } catch {
            throw FunctionPatchError.offline
        }
    }

    func download(
        functionID: String,
        baseURL: URL,
        version: Int? = nil
    ) async throws -> FunctionPayload {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/functions/\(functionID)/payload"),
            resolvingAgainstBaseURL: false
        )
        if let version {
            components?.queryItems = [URLQueryItem(name: "version", value: String(version))]
        }
        guard let url = components?.url else { throw FunctionPatchError.invalidServerURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let temporaryURL: URL
        let response: URLResponse
        do {
            (temporaryURL, response) = try await session.download(for: request)
        } catch {
            throw FunctionPatchError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw FunctionPatchError.offline }
        guard (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw FunctionPatchError.payloadUnavailable(
                AimFunctionCatalog.function(id: functionID)?.title ?? functionID
            )
        }

        let filename = header(http, "X-Payload-Filename").flatMap { $0.isEmpty ? nil : $0 } ?? "payload.bin"
        let expectedDigest = header(http, "X-Payload-Sha256") ?? ""
        let versionValue = Int(header(http, "X-Payload-Version") ?? "") ?? 0
        let relativePath = header(http, "X-Payload-Path").flatMap { $0.isEmpty ? nil : $0 }

        let directory = try Self.cacheDirectory(functionID: functionID)
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let destination = directory.appendingPathComponent("v\(versionValue)_\(safeName)")
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: destination)
        do {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw FunctionPatchError.applyFailed("não consegui gravar o payload em cache")
        }

        let actualDigest = (try? FileDigest.sha256Hex(ofFileAt: destination)) ?? ""
        guard expectedDigest.isEmpty || actualDigest == expectedDigest else {
            try? fileManager.removeItem(at: destination)
            throw FunctionPatchError.digestMismatch
        }
        let writtenSize: Int64
        if let attributes = try? fileManager.attributesOfItem(atPath: destination.path),
           let size = attributes[.size] as? NSNumber {
            writtenSize = size.int64Value
        } else {
            writtenSize = 0
        }

        return FunctionPayload(
            functionID: functionID,
            fileURL: destination,
            filename: filename,
            sha256: actualDigest,
            byteSize: writtenSize,
            version: versionValue,
            relativePath: relativePath
        )
    }

    private func header(_ response: HTTPURLResponse, _ name: String) -> String? {
        response.value(forHTTPHeaderField: name)
    }
}
