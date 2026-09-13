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
    static let verifiedIOS26Range = "26.0–26.6.1 (build restricted)"

    // iOS 27 is already build-gated in the original project.
    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    // Keep this list deliberately small. Add a build only after testing the
    // complete, non-destructive resolution/diagnostic flow on that build.
    // 23G71 is the public iOS 26.6 build and 23G83 is the public iOS 26.6.1
    // build. A beta/RC build must be added separately if it is validated.
    static let verifiedIOS26Builds: Set<String> = [
        "23G71", // iOS 26.6
        "23G82", // iOS 26.6.1 RC / pre-release
        "23G83"  // iOS 26.6.1 public release
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

        // 26.0–26.5 remains version-gated because the public reference did
        // not provide a reliable complete build table for every point release.
        if minor < 6 {
            return true
        }

        // 26.6.0 and 26.6.1 are build-gated. Unknown builds are refused
        // instead of being allowed to reach the native backend silently.
        if minor == 6, patch <= 1 {
            return verifiedIOS26Builds.contains(build)
        }

        return false
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

        return iOS27BetaNumber(for: build) != nil ? .badQuery : .unsupported
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
