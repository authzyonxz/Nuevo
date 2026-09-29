import Foundation

enum PublishedFunctionID: String, CaseIterable, Codable {
    case aimHighHS = "aim.high_hs"
    case aimAboveHead = "aim.above_head"
    case aimNeckHS = "aim.neck_hs"
    case aimNeckOnly = "aim.neck_only"
    case aimNeckAntenna = "aim.neck_antenna"
    case aimNeckAntennaHand = "aim.neck_antenna_hand"
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

    var isInMaintenance: Bool { status != "active" }

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
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
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
        let (data, response) = try await URLSession.shared.data(from: packageURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PublishedFunctionCatalogError.unavailable
        }
        return data
    }

    private struct CatalogResponse: Decodable {
        let functions: [PublishedFunctionStatus]
    }
}
