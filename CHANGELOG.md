# Changelog

All notable user-facing changes are documented in this file.

## [2.3] - 2026-03-05

### Added

- **Airlift access route** — container writes over a pairing record and the loopback RSD tunnel, with no kernel exploit.
- On-device pairing: the phone pairs with itself through Settings › Developer Mode, no SideStore and no computer.
- Pairing file import from Files, base64 paste, and discovery of pairing records already in `On My iPhone/3105`.
- `originalSha256` in the remote manifest and `GET /api/v1/functions/<id>/original` for restores on the Airlift route.
- **CONFIG tab** — shows the access route for the device and holds the whole Airlift connection: loopback tunnel state, pairing record, PIN, on-device pairing, import from file, base64 paste, access test against the target bundle, and the supported-version matrix.
- Compact route strip on the Aim tab reporting which route is active and whether it is ready.

### Changed

- **Airlift is now limited to the builds where pairing happens on the iPhone itself, with no cable and no computer**: iOS 27.0, 27.0.1 and 27.2 beta 1 through beta 3.
- **iOS 27.2 beta 3 is enabled** — verified working on the Airlift path.
- iOS 17.0–18.7.2 uses the **kernel** route; iOS 26.0–26.6.2 uses **kernel + sandbox escape + bad_query**. Neither needs VPN, pairing, or a computer.
- `AccessKind` gained a dedicated `badQuery` value so the Config screen reports the real route instead of folding iOS 26 into "kernel".
- Aim / C++ / Textura download and apply exactly as before; only the write backend changes per version.

### Known limits

- Airlift is write-only: it cannot scan or read the target container. The site must publish `relativePath` for every function, and `originalSha256` for restores.
- iOS 27.2 beta 4 and later are untested. `patchedAirliftBuilds` in `SupportPolicy.swift` blocks a build once it is confirmed patched.
- Airlift requires LocalDevVPN (loopback) and Apple Books opened at least once.

## [1.0.1] - 2026-08-15

### Added

- Bundle-tree Patch workspace v2 under `On My iPhone/3105/Patches`, synchronized automatically when applying or exporting.
- Multiple independent Files tabs with preserved navigation state.
- ZIP extraction with path, symbolic-link, CRC, and available-space validation.
- Responsive iPad split-view and landscape navigation.
- Home toggles for showing or hiding Cleaner and Wallpaper features.

### Changed

- Patch creation from an app-container file or folder now captures the stable bundle identifier and editable destination tree automatically.
- Patch package imports no longer use the previous fixed payload-size or file-count ceiling; practical device storage and memory still apply.
- Files and Patch screens now use consistent grouped cards, compact icons, balanced nested rows, and stable search presentation.
- Legacy v1 `.3105` packages remain importable and usable.

### Fixed

- Patch Restore now restores files that existed before Apply, removes files introduced by the patch, and removes patch-created folders after they become empty.
- File navigation remains at the current folder when switching app sections and restores the correct folder independently for each Files tab.
- Empty Patch and Cleaner actions now share the same visual treatment.
- Corrected PosterBoard wallpaper activation guidance and the iOS 27 Collections prerequisite.
- Refined navigation icon rendering and nested file-row spacing.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 Developer Beta 1–4, including Public Beta 1–2 mappings listed in the app.
- Added iPhone and iPad interface support; device-level features still require enterprise signing.

## [1.0 beta 3] - 2026-08-14

### Added

- Bundle-based App Data Browser with MHA-C2 container discovery.
- Native file operations: search, multi-file import, rename, delete, create file/folder, and conflict handling.
- Portable `.3105` patch projects with optional password protection and file/folder rules.
- Limited per-app cleaner for `Library/Caches` and `tmp`.
- Wallpaper Lab for validated `.tendies` packages with installation receipts and targeted reset.
- English, Vietnamese, and Simplified Chinese localization.

### Changed

- Simplified the app into a five-tab, native SwiftUI layout inspired by focused iOS container tools.
- Moved the enterprise-signing notice below device information on Home.
- Refined the orange accent, empty states, actions, and navigation presentation.

### Fixed

- Stabilized persistent search presentation in app and file browsers.
- Fixed native document selection for replacement files and `.3105` package imports.
- Resolved bundle-name mapping for enumerated app containers where metadata is available.
- Limited wallpaper reset to active content installed by 3105.
- Corrected Cleaner layout when no removable app data is found.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 beta 1–4 builds listed in the app.
- Unlisted iOS 27 builds remain disabled until explicitly verified.
