import Foundation
import Darwin
import UIKit

// MARK: - Models

struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let containerPath: String
    let version: String
    let icon: UIImage?

    var id: String { bundleID }
    var displayName: String {
        AppDisplayNamePolicy.resolve(bundleID: bundleID, candidates: [name])
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FileEntry: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64

    var id: String { path }
    var sizeText: String {
        if isDirectory { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Store

enum ContainerStore {
    static let appDataRoot = "/var/mobile/Containers/Data/Application"
    static let systemDataRoot = "/var/mobile/Containers/Data/System"
    private static let applicationBundleRoots: [(path: String, nested: Bool)] = [
        ("/var/containers/Bundle/Application", true),
        ("/Applications", false),
        ("/System/Applications", false)
    ]
    static let researchAppIdentifiers = [
        "com.apple.mobilesafari", "com.apple.mobilenotes", "com.apple.Maps",
        "com.apple.facetime", "com.apple.iBooks", "com.apple.podcasts",
        "com.apple.PosterBoard", "com.apple.mobilemail", "com.apple.weather",
        "com.apple.camera", "com.apple.Health", "com.apple.Fitness",
        "com.apple.tips", "com.apple.Passbook", "com.apple.reminders",
        "com.apple.stocks", "com.apple.news", "com.apple.Home", "com.apple.tv",
        "com.apple.shortcuts", "com.apple.freeform", "com.apple.calculator",
        "com.apple.MobileSMS", "com.apple.InCallService", "com.apple.Preferences",
        "com.apple.springboard", "com.apple.Photos", "com.apple.AppStore",
        "com.apple.Music", "com.apple.Bridge", "com.apple.Clock",
        "com.apple.VoiceMemos", "com.apple.Translate", "com.apple.measure",
        "com.apple.compass", "com.apple.Magnifier", "com.apple.DocumentsApp"
    ]

    static func resolveAppContainerPath(bundleID: String) -> String? {
        guard (try? PatchPathValidator.canonicalBundleIdentifier(bundleID)) == bundleID else {
            return nil
        }
        
        // 1. Tentar via MCM (Método rápido e oficial via exploit)
        var lookupError: NSString?
        if let path = MCMActivateContainerPath(2, bundleID, false, &lookupError) {
            log("patch: MHA-C2 returned path for \(bundleID): \(path)")
            if isApplicationContainerPath(path) {
                log("patch: MHA-C2 resolved and validated \(bundleID)")
                return path
            }
        }
        
        // 2. Fallback: Varredura profunda do sistema de arquivos
        log("patch: MCM failed or restricted for \(bundleID), performing deep scan...")
        
        // Buscar em todos os containers de dados conhecidos
        let filesystemApps = containersFromFilesystem()
        log("patch: Filesystem scan found \(filesystemApps.count) potential containers")
        
        // Tentar identificar o app pelos metadados ou arquivos internos
        for app in filesystemApps {
            let metadata = readContainerMetadata(containerPath: app.containerPath)
            if metadata?.bundleID == bundleID {
                log("patch: Deep scan matched \(bundleID) at \(app.containerPath)")
                return app.containerPath
            }
            
            // Fallback heurístico: procurar pasta do jogo se o bundleID bater parcialmente ou via Library/Preferences
            let libPath = (app.containerPath as NSString).appendingPathComponent("Library/Preferences")
            if let prefs = try? FileManager.default.contentsOfDirectory(atPath: libPath) {
                if prefs.contains(where: { $0.contains(bundleID) }) {
                    log("patch: Heuristic match for \(bundleID) via preferences at \(app.containerPath)")
                    return app.containerPath
                }
            }
        }

        // 3. Método de Força Bruta (Técnica do NubankExploit para iOS 17/18)
        // Se o MCM falhar e a varredura não encontrar, tentamos brute-force no kernel
        // Isso resolve o erro quando o app está "escondido" do sandbox normal
        log("patch: MCM and deep scan failed for \(bundleID), trying kernel brute-force...")
        let allApps = containersFromFilesystem()
        for app in allApps {
            // Tentar ler o plist de metadados forçando o bypass de sandbox
            let handle = grantContainerAccess(app.containerPath)
            if handle >= 0 {
                let metadata = readContainerMetadata(containerPath: app.containerPath)
                bad_query_release(handle)
                if metadata?.bundleID == bundleID {
                    log("patch: Kernel brute-force matched \(bundleID) at \(app.containerPath)")
                    return app.containerPath
                }
            }
        }

        log("patch: Failed to resolve container for \(bundleID)")
        return nil
    }

    // MARK: Primary — MobileInstallation / LSApplicationWorkspace

    static func installedAppsFromAPI() -> [InstalledApp] {
        let raw = installedAppInfo() as? [String: [String: Any]] ?? [:]
        var apps: [InstalledApp] = []
        for (bundleID, info) in raw {
            apps.append(InstalledApp(
                bundleID: bundleID,
                name: info["name"] as? String ?? "",
                containerPath: info["container"] as? String ?? "",
                version: info["version"] as? String ?? "",
                icon: info["icon"] as? UIImage
            ))
        }
        return apps
    }

    static func applicationBundleMetadataCatalog() -> [String: ApplicationBundleMetadata] {
        var catalog: [String: ApplicationBundleMetadata] = [:]
        for root in applicationBundleRoots {
            for metadata in applicationBundleMetadata(at: root.path, nested: root.nested) {
                catalog[metadata.bundleID] = metadata
            }
        }
        log("browser: app-bundle metadata resolved \(catalog.count) names")
        return catalog
    }

    static func applyingBundleMetadata(
        to apps: [InstalledApp],
        catalog: [String: ApplicationBundleMetadata]
    ) -> [InstalledApp] {
        apps.map { app in
            guard let metadata = catalog[app.bundleID] else { return app }
            return InstalledApp(
                bundleID: app.bundleID,
                name: AppDisplayNamePolicy.resolve(
                    bundleID: app.bundleID,
                    candidates: [metadata.displayName, app.name]
                ),
                containerPath: app.containerPath,
                version: app.version.isEmpty ? metadata.version : app.version,
                icon: app.icon
            )
        }
    }

    static func dynamicAppIdentifiers() -> [String] {
        var enumerationError: NSString?
        let identifiers = MCMEnumerateIdentifiersForClass(2, 1_024, &enumerationError)
        let enumerationDetail = enumerationError.map { String($0) } ?? "none"
        log("browser: MCM class-2 identifiers=\(identifiers.count) detail=\(enumerationDetail)")
        return identifiers
    }

    static func installedAppsFromMCM(
        identifiers: [String]? = nil,
        bundleMetadata: [String: ApplicationBundleMetadata] = [:]
    ) -> [InstalledApp] {
        let identifiers = identifiers ?? dynamicAppIdentifiers()

        var apps: [InstalledApp] = []
        for (index, bundleID) in identifiers.enumerated() {
            var lookupError: NSString?
            guard let containerPath = MCMActivateContainerPath(2, bundleID, false, &lookupError) else {
                let lookupDetail = lookupError.map { String($0) } ?? "no path"
                if index < 3 { log("mcm[\(index)]: \(bundleID) -> \(lookupDetail)") }
                continue
            }
            if index < 3 { log("mcm[\(index)]: \(bundleID) -> \(containerPath)") }

            let rawInfo = appInfoForBundleID(bundleID) as? [String: Any] ?? [:]
            let metadata = bundleMetadata[bundleID]
            apps.append(InstalledApp(
                bundleID: bundleID,
                name: AppDisplayNamePolicy.resolve(
                    bundleID: bundleID,
                    candidates: [metadata?.displayName, rawInfo["name"] as? String]
                ),
                containerPath: containerPath,
                version: rawInfo["version"] as? String ?? metadata?.version ?? "",
                icon: rawInfo["icon"] as? UIImage
            ))
        }
        log("browser: MCM resolved \(apps.count)/\(identifiers.count) app paths")
        return apps
    }

    // MARK: LaunchServices store discovery

    static func installedAppsFromMHACandidates(
        identifiers: [String],
        bundleMetadata: [String: ApplicationBundleMetadata] = [:],
        progress: (([InstalledApp]) -> Void)? = nil
    ) -> [InstalledApp] {
        guard !identifiers.isEmpty else {
            log("browser: MHA catalog returned no bundle candidates")
            return []
        }

        var apps: [InstalledApp] = []
        for (index, bundleID) in identifiers.enumerated() {
            var lookupError: NSString?
            guard let containerPath = MCMActivateContainerPath(
                2,
                bundleID,
                false,
                &lookupError
            ),
                  isApplicationContainerPath(containerPath) else {
                if index < 3 {
                    let detail = lookupError.map { String($0) } ?? "invalid app-data path"
                    log("mha-candidate[\(index)]: \(bundleID) -> \(detail)")
                }
                continue
            }

            let rawInfo = appInfoForBundleID(bundleID) as? [String: Any] ?? [:]
            let metadata = bundleMetadata[bundleID]
            apps.append(InstalledApp(
                bundleID: bundleID,
                name: AppDisplayNamePolicy.resolve(
                    bundleID: bundleID,
                    candidates: [metadata?.displayName, rawInfo["name"] as? String]
                ),
                containerPath: containerPath,
                version: rawInfo["version"] as? String ?? metadata?.version ?? "",
                icon: rawInfo["icon"] as? UIImage
            ))
            if apps.count <= 5 {
                log("browser: MHA-C2 resolved \(bundleID) -> \(containerPath)")
            }
            if apps.count.isMultiple(of: 8) {
                progress?(apps)
            }
        }

        progress?(apps)
        log("browser: MHA-C2 resolved \(apps.count)/\(identifiers.count) bundle candidates")
        return apps
    }

    private static func applicationBundleMetadata(
        at rootPath: String,
        nested: Bool
    ) -> [ApplicationBundleMetadata] {
        let handle = grantContainerAccess(rootPath)
        defer {
            if handle >= 0 { bad_query_release(handle) }
        }

        let fileManager = FileManager.default
        guard let rootEntries = try? fileManager.contentsOfDirectory(atPath: rootPath) else {
            log("browser: app-bundle metadata unavailable root=\(rootPath) grant=\(handle)")
            return []
        }

        let bundlePaths: [String]
        if nested {
            bundlePaths = rootEntries.prefix(2_048).flatMap { entry -> [String] in
                guard UUID(uuidString: entry) != nil else { return [] }
                let containerPath = (rootPath as NSString).appendingPathComponent(entry)
                let children = (try? fileManager.contentsOfDirectory(atPath: containerPath)) ?? []
                return children.prefix(16).compactMap { child in
                    guard child.hasSuffix(".app") else { return nil }
                    return (containerPath as NSString).appendingPathComponent(child)
                }
            }
        } else {
            bundlePaths = rootEntries.prefix(2_048).compactMap { entry in
                guard entry.hasSuffix(".app") else { return nil }
                return (rootPath as NSString).appendingPathComponent(entry)
            }
        }

        return bundlePaths.compactMap { bundlePath in
            let infoPath = (bundlePath as NSString).appendingPathComponent("Info.plist")
            let infoSize = (try? fileManager.attributesOfItem(atPath: infoPath)[.size] as? NSNumber)?
                .int64Value ?? 0
            guard infoSize > 0, infoSize <= 2 * 1_024 * 1_024 else { return nil }
            guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: infoPath)) else {
                return nil
            }
            return ApplicationBundleMetadataReader.metadata(
                from: plistData,
                localizedInfo: Bundle(path: bundlePath)?.localizedInfoDictionary
            )
        }
    }

    static func launchServicesStoreIdentifiers() -> [String] {
        var cachePaths: [String] = []
        var seenCachePaths = Set<String>()

        func addCachePath(_ rawPath: String) {
            let path = ContainerDiscoveryMerger.canonicalPath(rawPath)
            guard !path.isEmpty, seenCachePaths.insert(path).inserted else { return }
            cachePaths.append(path)
        }

        var leasedCachePaths = Set<String>()
        var serviceLookupError: NSString?
        if let servicePath = MCMActivateContainerPath(
            10,
            "com.apple.lsd",
            false,
            &serviceLookupError
        ) {
            let cachePath = (servicePath as NSString).appendingPathComponent("Library/Caches")
            addCachePath(cachePath)
            leasedCachePaths.insert(ContainerDiscoveryMerger.canonicalPath(cachePath))
        } else {
            let detail = serviceLookupError.map { String($0) } ?? "no path"
            log("browser: MCM com.apple.lsd activation unavailable detail=\(detail)")
        }

        let traversedSystemDirectories = enumerateDirectoriesWithTraversalGrant(path: systemDataRoot)
        let systemDirectories = traversedSystemDirectories.isEmpty
            ? enumerateDirectories(path: systemDataRoot)
            : traversedSystemDirectories
        for directory in systemDirectories {
            let metadataHandle = grantContainerAccess(metadataPath(for: directory))
            guard metadataHandle >= 0 else { continue }
            let metadata = readContainerMetadata(containerPath: directory)
            bad_query_release(metadataHandle)
            guard metadata?.bundleID == "com.apple.lsd" else { continue }
            addCachePath((directory as NSString).appendingPathComponent("Library/Caches"))
        }

        var storeIdentifiers = Set<String>()
        for cachePath in cachePaths {
            let handle = grantContainerAccess(cachePath)
            defer { if handle >= 0 { bad_query_release(handle) } }
            
            let fm = FileManager.default
            let storePaths = (try? fm.contentsOfDirectory(atPath: cachePath)) ?? []
            for storeName in storePaths {
                guard storeName.hasPrefix("com.apple.lsd.identifiers"), storeName.hasSuffix(".plist") else { continue }
                let fullPath = (cachePath as NSString).appendingPathComponent(storeName)
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let identifiers = plist["identifiers"] as? [String] else { continue }
                identifiers.forEach { storeIdentifiers.insert($0) }
            }
        }
        log("browser: LSStore identifiers resolved \(storeIdentifiers.count) from \(cachePaths.count) caches")
        return Array(storeIdentifiers)
    }

    // MARK: Heuristic container discovery

    static func enumerateDirectories(path: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return entries.map { (path as NSString).appendingPathComponent($0) }
    }

    static func enumerateDirectoriesWithTraversalGrant(path: String) -> [String] {
        let handle = grantContainerAccess(path)
        defer { if handle >= 0 { bad_query_release(handle) } }
        return enumerateDirectories(path: path)
    }

    static func grantContainerAccess(_ path: String) -> Int64 {
        let clean = ContainerDiscoveryMerger.canonicalPath(path)
        guard !clean.isEmpty else { return -1 }
        
        var pathC = clean.utf8CString.map { Int8($0) }
        let handle = pathC.withUnsafeMutableBufferPointer { buf in
            bad_query(buf.baseAddress, true, nil, false)
        }
        
        if handle < 0 {
            let canonical = ContainerDiscoveryMerger.canonicalPath(clean)
            if canonical != clean {
                var canonicalC = canonical.utf8CString.map { Int8($0) }
                return canonicalC.withUnsafeMutableBufferPointer { buf in
                    bad_query(buf.baseAddress, true, nil, false)
                }
            }
        }
        
        return handle
    }

    static func containersFromFilesystem() -> [InstalledApp] {
        let grantedDirectories = enumerateDirectoriesWithTraversalGrant(path: appDataRoot)
        let dirs: [String]
        if grantedDirectories.isEmpty {
            dirs = enumerateDirectories(path: appDataRoot)
            log("browser: filesystem root=\(appDataRoot) inode fallback enumerated \(dirs.count) containers")
        } else {
            dirs = grantedDirectories
            log("browser: filesystem root=\(appDataRoot) traversal enumerated \(dirs.count) containers")
        }
        let apps = dirs.compactMap { dir -> InstalledApp? in
            let uuid = (dir as NSString).lastPathComponent
            guard UUID(uuidString: uuid) != nil else { return nil }
            let fallback = ContainerIdentityResolver.fallbackIdentity(containerPath: dir)
            return InstalledApp(
                bundleID: fallback.bundleID,
                name: fallback.displayName,
                containerPath: dir,
                version: "",
                icon: nil
            )
        }
        log("browser: filesystem accepted \(apps.count)/\(dirs.count) app containers")
        return apps
    }

    static func inferredApp(
        for fallback: InstalledApp,
        knownAppsByBundleID: [String: InstalledApp],
        launchServicesIdentifiers: Set<String>
    ) -> InstalledApp? {
        guard UUID(uuidString: fallback.bundleID) != nil else { return fallback }

        let directMetadataPath = metadataPath(for: fallback.containerPath)
        let metadataHandle = grantContainerAccess(directMetadataPath)
        if metadataHandle >= 0 {
            let metadata = readContainerMetadata(containerPath: fallback.containerPath)
            bad_query_release(metadataHandle)
            if let metadata {
                let bundleID = metadata.bundleID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if ContainerBundleCandidateResolver.isValidBundleIdentifier(bundleID),
                   !bundleID.hasPrefix("systemgroup.") {
                    let info = appInfoForBundleID(bundleID) as? [String: Any] ?? [:]
                    let resolvedName = metadata.displayName.isEmpty
                        ? (info["name"] as? String ?? bundleID)
                        : metadata.displayName
                    
                    let version = info["version"] as? String ?? ""
                    let icon = info["icon"] as? UIImage
                    return InstalledApp(
                        bundleID: bundleID,
                        name: resolvedName,
                        containerPath: fallback.containerPath,
                        version: version,
                        icon: icon
                    )
                }
            }
        }

        let handle = grantContainerAccess(fallback.containerPath)
        guard handle >= 0 else { return nil }
        defer { bad_query_release(handle) }

        let libraryPath = (fallback.containerPath as NSString).appendingPathComponent("Library")
        let savedStatePath = (libraryPath as NSString).appendingPathComponent("Saved Application State")
        let preferencesPath = (libraryPath as NSString).appendingPathComponent("Preferences")
        let savedStates = (try? FileManager.default.contentsOfDirectory(atPath: savedStatePath)) ?? []
        let preferences = (try? FileManager.default.contentsOfDirectory(atPath: preferencesPath)) ?? []
        let strongCandidates = ContainerBundleCandidateResolver.candidates(
            savedStateNames: savedStates,
            preferenceFileNames: []
        )
        let candidates = ContainerBundleCandidateResolver.candidates(
            savedStateNames: savedStates,
            preferenceFileNames: preferences
        )

        func resolvedApp(from candidates: [String], source: String) -> InstalledApp? {
            for bundleID in candidates {
                if let known = knownAppsByBundleID[bundleID] {
                    return InstalledApp(
                        bundleID: bundleID,
                        name: known.name,
                        containerPath: fallback.containerPath,
                        version: known.version,
                        icon: known.icon
                    )
                }

                let info = appInfoForBundleID(bundleID) as? [String: Any] ?? [:]
                guard info["found"] as? Bool == true else { continue }
                return InstalledApp(
                    bundleID: bundleID,
                    name: info["name"] as? String ?? bundleID,
                    containerPath: fallback.containerPath,
                    version: info["version"] as? String ?? "",
                    icon: info["icon"] as? UIImage
                )
            }

            guard let bundleID = ContainerBundleCandidateResolver.confirmedCandidate(
                candidates: candidates,
                launchServicesIdentifiers: launchServicesIdentifiers
            ) else {
                return nil
            }
            let uuid = (fallback.containerPath as NSString).lastPathComponent
            log("browser: content+LaunchServices confirmed \(uuid) -> \(bundleID) source=\(source)")
            return InstalledApp(
                bundleID: bundleID,
                name: bundleID,
                containerPath: fallback.containerPath,
                version: "",
                icon: nil
            )
        }

        if let app = resolvedApp(from: candidates, source: "state/preferences") {
            return app
        }
        if let bundleID = strongCandidates.first {
            return InstalledApp(
                bundleID: bundleID,
                name: bundleID,
                containerPath: fallback.containerPath,
                version: "",
                icon: nil
            )
        }

        let artifactPaths = [
            (libraryPath as NSString).appendingPathComponent("SplashBoard/Snapshots"),
            (libraryPath as NSString).appendingPathComponent("Caches/Snapshots"),
            (libraryPath as NSString).appendingPathComponent("Cookies"),
            (libraryPath as NSString).appendingPathComponent("WebKit")
        ]
        let artifactNames = artifactPaths.flatMap {
            (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? []
        }
        let artifactCandidates = ContainerBundleCandidateResolver.candidates(
            savedStateNames: [],
            preferenceFileNames: [],
            artifactNames: artifactNames
        )
        if let app = resolvedApp(from: artifactCandidates, source: "artifacts") {
            return app
        }

        let uuid = (fallback.containerPath as NSString).lastPathComponent
        let preview = (candidates + artifactCandidates).prefix(6).joined(separator: ",")
        log("browser: unresolved \(uuid) metadata=unavailable savedStates=\(savedStates.count) preferences=\(preferences.count) artifacts=\(artifactNames.count) candidates=[\(preview)]")
        return nil
    }

    static func inferUnidentifiedApps(
        in apps: [InstalledApp],
        knownApps: [InstalledApp],
        launchServicesIdentifiers: Set<String> = []
    ) -> [InstalledApp] {
        let knownByBundleID = Dictionary(knownApps.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
        var inferredCount = 0
        let result = apps.enumerated().map { index, app -> InstalledApp in
            guard UUID(uuidString: app.bundleID) != nil,
                  let inferred = autoreleasepool(invoking: {
                      inferredApp(
                        for: app,
                        knownAppsByBundleID: knownByBundleID,
                        launchServicesIdentifiers: launchServicesIdentifiers
                      )
                  }) else {
                return app
            }
            inferredCount += 1
            if inferredCount <= 5 {
                log("browser: inferred \((app.containerPath as NSString).lastPathComponent) -> \(inferred.bundleID)")
            }
            return inferred
        }
        let unresolvedCount = result.filter { UUID(uuidString: $0.bundleID) != nil }.count
        log("browser: inferred identities for \(inferredCount)/\(apps.count) merged containers; unresolved=\(unresolvedCount)")
        return result
    }

    // MARK: Heuristic helpers
    
    static func isApplicationContainerPath(_ path: String) -> Bool {
        let clean = ContainerDiscoveryMerger.canonicalPath(path)
        return clean.contains("/Containers/Data/Application/") || clean.contains("/Containers/Bundle/Application/")
    }
    
    static func metadataPath(for containerPath: String) -> String {
        return (containerPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
    }
    
    static func readContainerMetadata(containerPath: String) -> ContainerMetadata? {
        let path = metadataPath(for: containerPath)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let bundleID = plist["MCMMetadataIdentifier"] as? String else {
            return nil
        }
        return ContainerMetadata(
            bundleID: bundleID,
            displayName: (plist["MCMMetadataUserDescription"] as? String) ?? ""
        )
    }

    // MARK: File browsing

    static func listFiles(at path: String) -> [FileEntry] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else {
            log("listFiles: FAILED for \(path) errno=\(errno)")
            return []
        }
        var entries: [FileEntry] = []
        for item in items {
            if item.hasPrefix(".") { continue }
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }
            let size = isDir.boolValue ? 0 : ((try? fm.attributesOfItem(atPath: full)[.size] as? Int64) ?? 0)
            entries.append(FileEntry(name: item, path: full, isDirectory: isDir.boolValue, size: size))
        }
        return entries.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func readTextFile(at path: String, limit: Int = 200_000) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return "Unable to read file."
        }
        let truncated = data.prefix(limit)
        if let text = String(data: truncated, encoding: .utf8) {
            return data.count > limit ? text + "\n… [truncated]" : text
        }
        if let text = String(data: truncated, encoding: .utf16) {
            return data.count > limit ? text + "\n… [truncated]" : text
        }
        return "Binary data (\(data.count) bytes) — not text."
    }
}

extension ContainerStore {
    static func findFilesRecursively(at rootPath: String, filename: String) -> [String] {
        var results: [String] = []
        let fileManager = FileManager.default
        
        // Obter acesso ao diretório atual
        let handle = grantContainerAccess(rootPath)
        defer { if handle >= 0 { bad_query_release(handle) } }
        
        guard let items = try? fileManager.contentsOfDirectory(atPath: rootPath) else {
            return []
        }
        
        for item in items {
            let fullPath = (rootPath as NSString).appendingPathComponent(item)
            
            // Verificar se o nome bate (Case Insensitive)
            if item.lowercased() == filename.lowercased() {
                results.append(fullPath)
            }
            
            // Se for diretório, buscar recursivamente
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                // Evitar entrar em pastas de sistema óbvias para economizar tempo
                if item == "Library" || item == "Documents" || item == "tmp" || item == "ContentCache" || item == "Compulsory" || item == "ios" || item == "gameassetbundles" {
                    results.append(contentsOf: findFilesRecursively(at: fullPath, filename: filename))
                } else if !item.hasPrefix(".") {
                    // Buscar em outras pastas também, mas com cautela
                    results.append(contentsOf: findFilesRecursively(at: fullPath, filename: filename))
                }
            }
        }
        
        return results
    }
}
