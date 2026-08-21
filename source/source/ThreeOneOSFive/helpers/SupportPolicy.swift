import Foundation

enum ExploitSupportPolicy {
    enum AccessPath: Equatable {
        case kfd16
        case kernelOffsets
        case badQuery
        case unsupported
    }

    static let verifiedIOS16Range = "16.0–16.6.1 (KFD; device/build restricted)"
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

    static func supportsKFD16(major: Int, minor: Int, patch: Int) -> Bool {
        // The Objective-C backend performs the device/build check. This method
        // only describes the supported OS family and prevents iOS 15/17 from
        // entering the KFD path.
        return major == 16 && minor >= 0 && minor <= 6 && patch >= 0
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

    static func supportsBadQuery(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 26 {
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }

    static func accessPath(major: Int, minor: Int, patch: Int, build: String) -> AccessPath {
        if supportsKFD16(major: major, minor: minor, patch: patch) {
            // Device/build validation happens in KFDBackend before kopen().
            // Keep the OS family visible to the state machine; the native
            // backend still refuses unknown combinations at runtime.
            return .kfd16
        }
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return .kernelOffsets
        }
        if supportsBadQuery(major: major, minor: minor, patch: patch, build: build) {
            return .badQuery
        }
        return .unsupported
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        accessPath(major: major, minor: minor, patch: patch, build: build) != .unsupported
    }
}
