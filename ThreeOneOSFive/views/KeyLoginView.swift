import SwiftUI

struct KeyLoginView: View {
    @Environment(\.appLanguage) private var language
    @State private var key = ""
    @FocusState private var keyFieldFocused: Bool
    let onValidated: (String) -> Void

    private var canContinue: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 52)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            AppLogo(size: 48)
                            Spacer()
                            Text("3105")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(language.text("login.title"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(language.text("login.subtitle"))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.text("login.key"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            Image(systemName: "key")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            TextField(language.text("login.key_placeholder"), text: $key)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($keyFieldFocused)
                                .submitLabel(.continue)
                                .onSubmit {
                                    if canContinue { onValidated(key.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .background(
                            Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    keyFieldFocused ? AppTheme.accent : Color(uiColor: .separator).opacity(0.35),
                                    lineWidth: keyFieldFocused ? 1.5 : 0.7
                                )
                        }
                    }
                    .padding(.top, 38)

                    Button {
                        keyFieldFocused = false
                        onValidated(key.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.text("login.validate"))
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .font(.headline)
                        .foregroundStyle(AppTheme.pageBackground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.45)
                    .padding(.top, 18)

                    Text(language.text("login.test_note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(nil)
    }
}

struct LoginSuccessfulView: View {
    @Environment(\.appLanguage) private var language
    let key: String
    let onEnterApp: () -> Void

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 54)

                    ZStack {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 82, height: 82)
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.pageBackground)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(language.text("login.success_title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(language.text("login.success_message"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(language.text("home.account"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.bottom, 10)

                        successDetailRow(label: language.text("login.key"), value: key)
                        Divider()
                        successDetailRow(label: language.text("home.duration"), value: language.text("login.example_duration"))
                        Divider()
                        successDetailRow(label: language.text("home.package"), value: language.text("login.example_package"))
                    }
                    .padding(18)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.7)
                    }
                    .padding(.top, 34)

                    Button(action: onEnterApp) {
                        Text(language.text("login.enter_app"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.pageBackground)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    Spacer(minLength: 42)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func successDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 13)
    }
}
