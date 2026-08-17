import SwiftUI
import UIKit

enum AppTheme {
    static let accent = Color(red: 0.20, green: 0.63, blue: 1.00)
    static let accentSoft = Color(red: 0.10, green: 0.25, blue: 0.42)
    static let success = Color(red: 0.22, green: 0.86, blue: 0.64)
    static let warning = Color(red: 1.00, green: 0.68, blue: 0.28)
    static let destructive = Color(red: 1.00, green: 0.32, blue: 0.40)
    static let pageBackground = Color(red: 0.015, green: 0.02, blue: 0.035)
    static let cardBackground = Color(red: 0.075, green: 0.085, blue: 0.11)
    static let secondaryCard = Color(red: 0.045, green: 0.055, blue: 0.075)
    static let border = Color(red: 0.18, green: 0.23, blue: 0.30)
    static let mutedText = Color(red: 0.48, green: 0.55, blue: 0.68)
    static let consoleBackground = Color(red: 0.02, green: 0.025, blue: 0.04)
    static let pageInset: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let rowIconSize: CGFloat = 18
    static let rowIconFrame: CGFloat = 32
    static let fileRowIconSize: CGFloat = 18
    static let fileRowIconFrame: CGFloat = 32
    static let fileRowHeight: CGFloat = 64
    static let appIconSize: CGFloat = 40
    static let emptyIconSize: CGFloat = 34
    static let selectionIconSize: CGFloat = 18
}

struct ZyvexCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 18

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.9), lineWidth: 1)
            }
    }
}

struct ZyvexSectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(AppTheme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.16))
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
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
            TextField(prompt, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 44)
        .background(AppTheme.secondaryCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.pageBackground)
    }
}

struct AppLogo: View {
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon).resizable().scaledToFill()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.42), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

extension View {
    func zyvexScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .tint(AppTheme.accent)
            .preferredColorScheme(.dark)
    }
}
