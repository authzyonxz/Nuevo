import Combine
import Foundation
import UIKit

enum KeyAuthStage: Equatable {
    case checkingPackage
    case packageUnavailable
    case startingSession
    case waitingForDevice
    case readyForKey
    case authorizing
    case authorized
    case failed

    var title: String {
        switch self {
        case .checkingPackage: return "Checking package"
        case .packageUnavailable: return "Package indisponível"
        case .startingSession: return "Preparando ativação"
        case .waitingForDevice: return "Aguardando dispositivo"
        case .readyForKey: return "Digite sua KEY"
        case .authorizing: return "Validando KEY"
        case .authorized: return "Acesso autorizado"
        case .failed: return "Falha na autorização"
        }
    }
}

struct LicenseInfo: Codable {
    let status: String
    let productName: String
    let expiresAt: String
    let message: String
    let sessionToken: String?
}

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isAuthorized = false
    @Published var hasStoredKey = false
    @Published var isLoading = false
    @Published var isValidatingActivation = false
    @Published var errorMessage: String?
    @Published var licenseInfo: LicenseInfo?
    @Published var activationURL: URL?
    @Published var stage: KeyAuthStage = .checkingPackage
    @Published var stageMessage = "Verificando se o Package está ativo..."
    @Published private(set) var deviceCaptured = false

    private let keyAuth: KeyAuthClient?
    private let sessionStore: KeyAuthSessionStore
    private let licenseKeyStore: KeyAuthSessionStore
    private var flowRunning = false

    init() {
        let bundleNamespace = Bundle.main.bundleIdentifier ?? "com.example.app"
        self.sessionStore = KeyAuthSessionStore(namespace: bundleNamespace + ".keyauth-session")
        self.licenseKeyStore = KeyAuthSessionStore(namespace: bundleNamespace + ".keyauth-license")
        self.keyAuth = try? KeyAuthClient(configuration: KeyAuthAppConfiguration.configuration)
        self.hasStoredKey = (try? licenseKeyStore.load())?.isEmpty == false
    }

    var canEnterKey: Bool { stage == .readyForKey || (stage == .failed && deviceCaptured) }
    var isWaitingForDevice: Bool { stage == .waitingForDevice && !deviceCaptured }
    var canObtainUDID: Bool { !deviceCaptured && !isLoading && stage != .checkingPackage && stage != .startingSession }
    var canVerifyUDID: Bool { !deviceCaptured && !isLoading && stage == .waitingForDevice }

    func refreshDeviceCapture() {
        guard !deviceCaptured, !isLoading else { return }
        guard let client = keyAuth,
              let token = try? sessionStore.load(),
              !token.isEmpty else {
            beginAuthorization()
            return
        }
        setStage(.startingSession, message: "Verificando se o UDID foi capturado...", loading: true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let status = try await client.deviceSessionStatus(token: token)
                self.deviceCaptured = status.captured || status.deviceRegistered
                if self.deviceCaptured {
                    self.setStage(.readyForKey, message: "UDID confirmado. Agora digite sua KEY.", loading: false)
                } else {
                    self.setStage(.waitingForDevice, message: "O UDID ainda não foi recebido. Instale o perfil e tente novamente.", loading: false)
                }
            } catch {
                self.finishFailure(.waitingForDevice, message: self.userMessage(for: error))
            }
        }
    }

    func obtainUDID() {
        guard !deviceCaptured else { return }
        guard let token = try? sessionStore.load(), !token.isEmpty else {
            beginAuthorization()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            await self.openActivationPortal(token: token)
            self.setStage(.waitingForDevice, message: "Instale o perfil no Ajustes e retorne ao app para confirmar o UDID.", loading: false)
        }
    }

    func loadSavedKey() -> String? { try? licenseKeyStore.load() }

    func deviceID() -> String {
        UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? "keyauth-installation"
    }

    /// Entry point used by the original UI. The first request is always Package status.
    func beginAuthorization() {
        guard !flowRunning, !isAuthorized else { return }
        flowRunning = true
        setStage(.checkingPackage, message: "Verificando se o Package está ativo...", loading: true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.flowRunning = false }
            do {
                guard let client = self.keyAuth else { throw KeyAuthError.invalidConfiguration("cliente não configurado") }
                let package = try await client.packageStatus()
                guard package.available, package.status == "active" else {
                    self.finishFailure(.packageUnavailable, message: "O Package \(package.name) não está ativo.")
                    return
                }
                try await self.continueAuthorization(using: client)
            } catch {
                self.finishFailure(.failed, message: self.userMessage(for: error))
            }
        }
    }

    /// Called when the app returns from Safari/Settings after the profile flow.
    func resumeAuthorization() {
        guard !isAuthorized, !flowRunning else { return }
        if stage == .waitingForDevice {
            refreshDeviceCapture()
            return
        }
        guard stage != .readyForKey, stage != .failed, stage != .packageUnavailable else { return }
        beginAuthorization()
    }

    func validateForActivation(completion: @escaping (Bool, String?) -> Void) {
        guard let savedKey = loadSavedKey(), !savedKey.isEmpty else {
            completion(false, "Digite uma KEY para ativar este dispositivo.")
            return
        }
        isValidatingActivation = true
        validateKey(savedKey) { [weak self] success, message in
            self?.isValidatingActivation = false
            completion(success, message)
        }
    }

    func validateKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedKey.isEmpty else {
            completion(false, "Insira uma KEY válida.")
            return
        }
        guard let client = keyAuth else {
            finishFailure(.failed, message: "A configuração do Key Auth está indisponível.", completion: completion)
            return
        }

        setStage(.authorizing, message: "Enviando a KEY para validação segura...", loading: true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let token = try await self.existingOrNewSession(using: client)
                let status = try await client.deviceSessionStatus(token: token)
                self.deviceCaptured = status.captured || status.deviceRegistered
                guard self.deviceCaptured else {
                    self.finishFailure(.waitingForDevice, message: "Toque em Obter UDID, instale o perfil e retorne ao app.", completion: completion)
                    return
                }
                let authorization = try await client.activateSessionKey(token: token, licenseKey: normalizedKey)
                try self.licenseKeyStore.save(normalizedKey)
                self.finishSuccess(authorization, token: token, completion: completion)
            } catch {
                self.finishFailure(.failed, message: self.userMessage(for: error), completion: completion)
            }
        }
    }

    func recheckSecureSession(completion: @escaping (Bool, String?) -> Void) {
        guard let client = keyAuth else {
            completion(false, "A configuração do Key Auth está indisponível.")
            return
        }
        guard let token = try? sessionStore.load(), !token.isEmpty else {
            setState(authorized: false, info: nil, loading: false)
            completion(false, "Nenhuma sessão Key Auth ativa. Faça a checagem inicial.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let status = try await client.deviceSessionStatus(token: token)
                self.deviceCaptured = status.captured || status.deviceRegistered
                guard self.deviceCaptured else {
                    self.setState(authorized: false, info: nil, loading: false)
                    self.setStage(.waitingForDevice, message: "Conclua a instalação do perfil do dispositivo.", loading: false)
                    completion(false, self.stageMessage)
                    return
                }
                guard status.registered else {
                    self.setState(authorized: false, info: nil, loading: false)
                    self.setStage(.readyForKey, message: "O dispositivo foi identificado. Digite sua KEY.", loading: false)
                    completion(false, self.stageMessage)
                    return
                }
                let authorization = try await client.activateSessionKey(token: token)
                self.finishSuccess(authorization, token: token, completion: completion)
            } catch {
                self.setState(authorized: false, info: nil, loading: false)
                completion(false, self.userMessage(for: error))
            }
        }
    }

    func clearSavedKey() {
        try? sessionStore.clear()
        try? licenseKeyStore.clear()
        activationURL = nil
        deviceCaptured = false
        setState(authorized: false, info: nil, loading: false)
        hasStoredKey = false
        setStage(.checkingPackage, message: "Pronto para iniciar uma nova ativação.", loading: false)
        errorMessage = nil
    }

    private func continueAuthorization(using client: KeyAuthClient) async throws {
        setStage(.startingSession, message: "Criando uma sessão curta de ativação...", loading: true)
        let token = try await existingOrNewSession(using: client)
        let status = try await client.deviceSessionStatus(token: token)
        deviceCaptured = status.captured || status.deviceRegistered

        if deviceCaptured {
            if status.registered {
                let authorization = try await client.activateSessionKey(token: token)
                finishSuccess(authorization, token: token, completion: nil)
            } else {
                setStage(.readyForKey, message: "Dispositivo identificado. Agora digite sua KEY.", loading: false)
            }
        } else {
            setStage(.waitingForDevice, message: "Toque em Obter UDID, instale o perfil e retorne ao app para obter o UDID.", loading: false)
        }
    }

    private func existingOrNewSession(using client: KeyAuthClient) async throws -> String {
        if let existing = try sessionStore.load(), !existing.isEmpty {
            do {
                let status = try await client.deviceSessionStatus(token: existing)
                if status.status != "expired" { return existing }
            } catch {
                try? sessionStore.clear()
            }
        }
        let started = try await client.startDeviceSession()
        try sessionStore.save(started.token)
        return started.token
    }

    private func openActivationPortal(token: String) async {
        guard let baseURL = URL(string: KeyAuthAppConfiguration.baseURLString) else { return }
        guard let url = URL(string: "/device/\(KeyAuthAppConfiguration.packageSlug)/\(token)", relativeTo: baseURL)?.absoluteURL else { return }
        await MainActor.run {
            self.activationURL = url
            UIApplication.shared.open(url)
        }
    }

    private func finishSuccess(_ result: AuthorizationResult, token: String, completion: ((Bool, String?) -> Void)?) {
        let info = LicenseInfo(
            status: result.claims.keyStatus.uppercased(),
            productName: KeyAuthAppConfiguration.packageSlug,
            expiresAt: Self.formatDate(result.claims.exp),
            message: "Autorização Key Auth v2 ativa",
            sessionToken: token
        )
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.hasStoredKey = true
            self.licenseInfo = info
            self.errorMessage = nil
            self.isLoading = false
            self.stage = .authorized
            self.stageMessage = "Acesso autorizado."
            completion?(true, nil)
        }
    }

    private func finishFailure(_ nextStage: KeyAuthStage, message: String, completion: ((Bool, String?) -> Void)? = nil) {
        DispatchQueue.main.async {
            self.isAuthorized = false
            self.licenseInfo = nil
            self.isLoading = false
            self.stage = nextStage
            self.stageMessage = message
            self.errorMessage = message
            completion?(false, message)
        }
    }

    private func setStage(_ value: KeyAuthStage, message: String, loading: Bool) {
        DispatchQueue.main.async {
            self.stage = value
            self.stageMessage = message
            self.isLoading = loading
        }
    }

    private func setState(authorized: Bool, info: LicenseInfo?, loading: Bool) {
        DispatchQueue.main.async {
            self.isAuthorized = authorized
            self.licenseInfo = info
            self.isLoading = loading
        }
    }

    private func userMessage(for error: Error) -> String {
        if let error = error as? KeyAuthError {
            switch error {
            case .server(let code): return messageForServerCode(code)
            case .network(let cause): return "Falha de rede: \(cause.localizedDescription)"
            case .invalidGrant: return "O servidor respondeu, mas o grant não pôde ser verificado. Verifique o kid/chave pública do app."
            case .invalidChallenge: return "O challenge do servidor não corresponde a esta sessão."
            case .keychain: return "Não foi possível acessar o armazenamento seguro."
            case .sessionRequired: return "Sessão de dispositivo necessária."
            case .invalidConfiguration(let value): return "Configuração Key Auth inválida: \(value)"
            case .invalidResponse: return "Resposta incompleta do servidor. Toque em Verificar novamente."
            default: return error.localizedDescription
            }
        }
        return "Falha inesperada: \(error.localizedDescription)"
    }

    private func messageForServerCode(_ code: String) -> String {
        switch code {
        case "PACKAGE_UNAVAILABLE": return "Este Package está pausado ou indisponível."
        case "PACKAGE_NOT_FOUND": return "O Package configurado não existe no Key Auth."
        case "KEY_INVALID": return "A KEY não existe ou não pertence ao Package configurado."
        case "KEY_UNAVAILABLE", "KEY_PAUSED", "KEY_BANNED", "KEY_DELETED": return "Esta KEY não pode ser usada no momento."
        case "KEY_EXPIRED": return "Esta KEY está expirada."
        case "DEVICE_MISMATCH": return "Esta KEY está vinculada a outro dispositivo."
        case "DEVICE_ALREADY_REGISTERED": return "Já existe outra KEY ativa neste dispositivo."
        case "DEVICE_NOT_CAPTURED": return "O UDID ainda não foi obtido. Instale o perfil do dispositivo primeiro."
        case "SESSION_NOT_FOUND", "SESSION_EXPIRED": return "A sessão expirou. Inicie a ativação novamente."
        case "AUTHENTICATION_FAILED": return "Cliente ou assinatura do Key Auth inválidos."
        case "REPLAY_DETECTED": return "A solicitação já foi usada ou expirou. Tente novamente."
        case "RATE_LIMITED": return "Muitas tentativas. Aguarde alguns minutos."
        default: return "Erro do Key Auth: \(code)"
        }
    }

    private static func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
