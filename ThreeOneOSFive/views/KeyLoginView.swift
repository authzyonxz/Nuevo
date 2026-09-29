import SwiftUI

struct KeyLoginView: View {
    @Environment(\.appLanguage) private var language
    @State private var key = ""
    let onValidated: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "key.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 82, height: 82)
                    .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 8) {
                    Text(language.text("login.title"))
                        .font(.largeTitle.weight(.bold))
                    Text(language.text("login.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("login.key"))
                        .font(.subheadline.weight(.semibold))
                    TextField(language.text("login.key_placeholder"), text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    onValidated(key)
                } label: {
                    Text(language.text("login.validate"))
                        .font(.headline)
                        .foregroundStyle(AppTheme.pageBackground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                Text(language.text("login.test_note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LoginSuccessfulView: View {
    @Environment(\.appLanguage) private var language
    let key: String
    let onEnterApp: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text(language.text("login.success_title"))
                            .font(.largeTitle.weight(.bold))
                        Text(language.text("login.success_message"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        detailRow(label: language.text("login.key"), value: key)
                        detailRow(label: language.text("home.duration"), value: language.text("login.example_duration"))
                        detailRow(label: language.text("home.package"), value: language.text("login.example_package"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button(action: onEnterApp) {
                        Text(language.text("login.enter_app"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.pageBackground)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
    }
}
