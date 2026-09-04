import Foundation

enum KeyAuthAppConfiguration {
    static let baseURLString = "https://keyauthv2.org"
    static let issuer = "https://keyauthv2.org"
    static let audience = "keyauth-ios"
    static let packageSlug = "external"
    static let keyID = "605JmqMJES2Jbv4b"
    static let serverPublicKeyX963 = "BIqK3G8Ltvrq2WUUhm2bZ3FY0U5Wtg_gj3ezqFxb2T5M9AymMaxNUi2HoALXngdaZ5BypxejSMhCsyLzhe1PWV8"

    static var configuration: KeyAuthConfiguration {
        try! KeyAuthConfiguration(
            baseURL: URL(string: baseURLString)!,
            issuer: issuer,
            audience: audience,
            package: packageSlug,
            keyID: keyID,
            serverPublicKeyX963: serverPublicKeyX963,
            policyVersion: 2
        )
    }
}
