import Foundation

enum ExploitSupportPolicy {
    enum AccessPath: Equatable {
        case kfd16
        case kernelOffsets
        case badQuery
        case unsupported
    }

    static let verifiedIOS16Range = "16.0–16.6.1 (KFD; device/build restricted)"
    static let verifiedIOS17Range = "17.0–17.7.x (offsets; build restricted)"
    static let verifiedIOS18Range = "18.0–18.7.1 (offsets; build restricted)"
    static let verifiedIOS26Range = "26.0–26.6.1"

    // Known iOS 27 builds are listed for diagnostics; the bad_query path is
    // runtime-probed so later 27.0 builds are not rejected by an old table.
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
        guard major == 16, minor >= 0, patch >= 0 else { return false }
        // Exact upper bound: 16.6.1. This prevents 16.6.2+ from being
        // reported as supported merely because the minor version is 6.
        return minor < 6 || (minor == 6 && patch <= 1)
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

    static func supportsBadQuery(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        guard major == 26, minor >= 0, patch >= 0 else {
            return false
        }

        // iOS 26/27 use the ContainerManager bad_query path. The native
        // backend is version-gated here, while build-specific validation is
        // intentionally left to the runtime diagnostic/access probe. This
        // matches the reference 3105 behavior and avoids rejecting valid
        // release, beta, or regional builds that share the same version.
        return minor < 6 || (minor == 6 && patch <= 1)
    }

    static func accessPath(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> AccessPath {
        if supportsKFD16(major: major, minor: minor, patch: patch) {
            return .kfd16
        }

        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return .kernelOffsets
        }

        if supportsBadQuery(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        ) {
            return .badQuery
        }

        guard major == 27, minor == 0, patch == 0 else {
            return .unsupported
        }

        return .badQuery
    }

    static func isSupported(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        accessPath(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        ) != .unsupported
    }
}
