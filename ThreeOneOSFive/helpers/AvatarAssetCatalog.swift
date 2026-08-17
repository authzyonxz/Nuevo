import Foundation

struct AvatarAsset: Identifiable, Hashable {
    let id: String
    let variant: String
    let displayName: String
    let resourceFolder: String
    let sha256: String
    let targetRelativePath: String

    var sourceFilename: String { "assetindexer" }
}

enum AvatarAssetCatalog {
    static let freeFireBundleID = "com.dts.freefireth"
    static let freeFireMaxBundleID = "com.dts.freefiremax"
    static let avatarDirectory = "ContentCache/compulsory/gameassetbundle/avatar"

    static let assets: [AvatarAsset] = [
        AvatarAsset(
            id: "hs-neck",
            variant: "HSNeck",
            displayName: "HS Neck",
            resourceFolder: "HSNeck",
            sha256: "ac8a6db1096a03a2b67a2bff3b9a024553d4f3eb039ee18ba735c6989f41f3df",
            targetRelativePath: "ContentCache/compulsory/gameassetbundle/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
        ),
        AvatarAsset(
            id: "hs-alto",
            variant: "HSAlto",
            displayName: "HS Alto",
            resourceFolder: "HSAlto",
            sha256: "7917eb9c3e49d79ff6cbb9d0647573820fd4162759d78d01e63a90d5d4fcffad",
            targetRelativePath: "ContentCache/compulsory/gameassetbundle/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
        ),
        AvatarAsset(
            id: "hs-original",
            variant: "HSOriginal",
            displayName: "HS Original",
            resourceFolder: "HSOriginal",
            sha256: "05d235840319edb6978630d3eeadfe8459cbe4e7349f5963c2cf883d46574929",
            targetRelativePath: "ContentCache/compulsory/gameassetbundle/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
        )
    ]

    static func data(for asset: AvatarAsset, bundle: Bundle = .main) -> Data? {
        guard let url = bundle.url(
            forResource: asset.sourceFilename,
            withExtension: nil,
            subdirectory: "AvatarAssets/\(asset.resourceFolder)"
        ) else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func makeFreeFireDraft(selectedAssets: [AvatarAsset], bundle: Bundle = .main) -> PatchProjectDraft? {
        let rules = selectedAssets.compactMap { asset -> PatchRule? in
            guard let data = data(for: asset, bundle: bundle) else { return nil }
            return PatchRule(
                bundleID: freeFireBundleID,
                relativePath: asset.targetRelativePath,
                replacementFilename: asset.sourceFilename,
                replacementData: data
            )
        }
        guard !rules.isEmpty else { return nil }
        return PatchProjectDraft(
            name: "Free Fire — Avatares",
            bundleIdentifiers: [freeFireBundleID],
            directories: [],
            rules: rules
        )
    }
}
