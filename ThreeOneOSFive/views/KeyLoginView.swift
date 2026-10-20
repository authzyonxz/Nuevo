import SwiftUI

@MainActor
final class KeyLoginViewModel: ObservableObject {
    @Published var keyInput = ""
    @Published private(set) var isLoading = false
    @Published private(set) var access: KeyAuthAccess?
    @Published var errorMessage: String?

    private let client = KeyAuthClient()
    private var didAttemptRestore = false

    func restoreSavedAccessIfNeeded() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        guard KeyAuthKeychain.hasSavedLicenseKey else { return }
        await authenticate(with: nil)
    }

    func enter() async {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Digite sua Key para continuar."
            return
        }
        await authenticate(with: trimmed)
    }

    private func authenticate(with key: String?) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            access = try await client.authorize(licenseKey: key)
            keyInput = ""
        } catch let failure as KeyAuthFailure {
            errorMessage = failure.userMessage
        } catch {
            errorMessage = "Não foi possível validar agora. Verifique sua conexão e tente novamente."
        }
    }
}

/// A tela só chama `onContinue` após validar localmente a assinatura ES256 do grant.
struct KeyLoginView: View {
    let onContinue: (KeyAuthAccess) -> Void

    @StateObject private var model = KeyLoginViewModel()
    @State private var showKey = false

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Text("EXTERNAL - iOS")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Acesse com sua licença")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                if let access = model.access {
                    accessCard(access)
                    Button { onContinue(access) } label: {
                        Text("CONTINUAR")
                            .font(.headline.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityHint("Entra no aplicativo após a validação da licença")
                } else {
                    keyEntry
                }
                Spacer()
                Text("Sua Key é validada com segurança e fica salva no Keychain deste aparelho.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 440)
        }
        .task { await model.restoreSavedAccessIfNeeded() }
        .preferredColorScheme(.dark)
    }

    private var keyEntry: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Group {
                    if showKey {
                        TextField("Digite sua Key", text: $model.keyInput)
                    } else {
                        SecureField("Digite sua Key", text: $model.keyInput)
                    }
                }
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .foregroundStyle(.white)
                .tint(.white)
                Button(showKey ? "Ocultar" : "Mostrar") { showKey.toggle() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.18), lineWidth: 1))

            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.48))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Button {
                Task { await model.enter() }
            } label: {
                HStack(spacing: 10) {
                    if model.isLoading { ProgressView().tint(.black) }
                    Text(model.isLoading ? "VALIDANDO…" : "ENTRAR")
                        .font(.headline.weight(.bold))
                        .tracking(1.2)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(model.isLoading)
            .opacity(model.isLoading ? 0.75 : 1)
        }
    }

    private func accessCard(_ access: KeyAuthAccess) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("ACESSO LIBERADO", systemImage: "checkmark.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.45, green: 0.92, blue: 0.62))
            Divider().overlay(Color.white.opacity(0.18))
            infoRow("Pacote", value: access.packageName)
            infoRow("Key", value: access.keyPreview)
            infoRow("Autorização válida até", value: access.authorizationExpiresAt.formatted(date: .abbreviated, time: .shortened))
            Text("A licença foi confirmada pelo servidor. Toque em Continuar para abrir o app.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.white.opacity(0.60))
            Spacer(minLength: 12)
            Text(value).foregroundStyle(.white).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
