import Foundation

enum ExploitSupportPolicy {
    /// Versions displayed in Profile as app-compatible. This is intentionally
    /// broader than the exploit allow-list: opening the app must not imply
    /// that privileged access has been verified on that OS build.
    static let listedIOSVersions: [String] = [
        "iOS 16.6–16.7.10",
        "iOS 17.0–17.7.x",
        "iOS 18.0–18.7.1",
        "iOS 26.0–26.6.2",
        "iOS 27.0 Developer Beta 4"
    ]

    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0–26.6.1"

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    /// Keeps the UI/profile usable on listed versions without widening the
    /// exploit execution allow-list above.
    static func isAppVersionListed(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 16 {
            return minor == 6 || (minor == 7 && patch <= 10)
        }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        if major == 26 {
            return minor < 6 || (minor == 6 && patch <= 2)
        }

        return major == 27 && minor == 0 && patch == 0 && build == "24A5390f"
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }
}
