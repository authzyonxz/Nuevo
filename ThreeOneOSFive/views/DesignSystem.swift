import SwiftUI

/// Tokens visuais compartilhados pelo app. A lógica de negócio permanece fora deste arquivo.
enum AppTheme {
    static let accent = Color(red: 0.96, green: 0.12, blue: 0.18)
    static let accentBright = Color(red: 1.00, green: 0.30, blue: 0.26)
    static let accentSoft = Color(red: 0.95, green: 0.18, blue: 0.22)
    static let accentDeep = Color(red: 0.35, green: 0.015, blue: 0.035)

    static let pageBackground = Color(red: 0.018, green: 0.018, blue: 0.024)
    static let consoleBackground = Color(red: 0.040, green: 0.040, blue: 0.050)
    static let panel = Color(red: 0.070, green: 0.068, blue: 0.080)
    static let panelElevated = Color(red: 0.105, green: 0.075, blue: 0.085)
    static let fieldBackground = Color(red: 0.095, green: 0.090, blue: 0.105)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.52)
    static let tertiaryText = Color.white.opacity(0.32)
    static let divider = Color.white.opacity(0.085)
    static let hairline = Color.white.opacity(0.12)

    static let success = Color(red: 0.37, green: 0.92, blue: 0.62)
    static let warning = Color(red: 1.00, green: 0.66, blue: 0.24)

    static let pageInset: CGFloat = 18
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let cardRadius: CGFloat = 22
    static let rowRadius: CGFloat = 16
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(tint.opacity(0.20), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(AppTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.pageBackground)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "flame.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
