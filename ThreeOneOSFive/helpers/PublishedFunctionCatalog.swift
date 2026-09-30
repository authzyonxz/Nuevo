import Foundation

enum PublishedFunctionID: String, CaseIterable, Codable {
    case aimHighHS = "aim.high_hs"
    case aimNeckHS = "aim.neck_hs"
    case aimNeckAntenna = "aim.neck_antenna"
    case hologramWeapons = "hologram.weapons"
    case panelFFH4X = "panel.ffh4x"
}

struct PublishedFunctionStatus: Decodable, Identifiable {
    let id: String
    let groupID: String
    let groupName: String
    let name: String
    let status: String
    let version: Int
    let package: String?
    let passwordProtected: Bool
    let available: Bool
    let packageURL: URL?
    let packageFormat: String?
    let targetBundleID: String?
    let targetFilename: String?

    var isInMaintenance: Bool { status != "active" }
    var isRawFile: Bool {
        packageFormat == "raw"
            || packageURL?.pathExtension.lowercased() == "raw"
            || (targetBundleID != nil && targetFilename != nil)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case groupName = "group_name"
        case name
        case status
        case version
        case package
        case passwordProtected = "password_protected"
        case available
        case packageURL = "package_url"
        case packageFormat = "package_format"
        case targetBundleID = "target_bundle_id"
        case targetFilename = "target_filename"
    }
}

enum PublishedFunctionCatalogError: Error {
    case notConfigured
    case invalidResponse
    case unavailable
}

enum PublishedFunctionCatalog {
    static var manifestURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FunctionCatalogBaseURL") as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let base = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return base.appendingPathComponent("api/functions")
    }

    static func fetchStatus(for id: PublishedFunctionID) async throws -> PublishedFunctionStatus {
        guard let manifestURL else { throw PublishedFunctionCatalogError.notConfigured }
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PublishedFunctionCatalogError.invalidResponse
        }
        let catalog = try JSONDecoder().decode(CatalogResponse.self, from: data)
        guard let status = catalog.functions.first(where: { $0.id == id.rawValue }) else {
            throw PublishedFunctionCatalogError.unavailable
        }
        return status
    }

    static func downloadPackage(for status: PublishedFunctionStatus) async throws -> Data {
        guard let packageURL = status.packageURL else {
            throw PublishedFunctionCatalogError.unavailable
        }
        var request = URLRequest(url: packageURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PublishedFunctionCatalogError.unavailable
        }
        return data
    }

    private struct CatalogResponse: Decodable {
        let functions: [PublishedFunctionStatus]
    }
}
