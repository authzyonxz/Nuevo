// language: Swift, file: AirliftFFI.swift, target: iOS 18+, dep: AirliftFFI.xcframework
//
// Ponte Swift sobre o core Rust do Airlift (airlift.h).
// O core abre um túnel RSD pelo loopback (LocalDevVPN), fala AFC +
// streaming_zip_conduit + com.apple.atc e escreve arquivos fora da sandbox
// através do symlink do ATAirlock. Não precisa de kernel exploit.
//
// Toda chamada é BLOQUEANTE. Sempre invocar de uma fila de fundo.

import Foundation
import AirliftFFI

enum AirliftError: Error, LocalizedError, Equatable {
    case pairingMissing
    case pairingInvalid(String)
    case tunnelDown
    case containerNotFound(String)
    case exploitFailed(String)
    case writeFailed(String)
    case pathUnknown(String)
    case respringFailed(String)

    var errorDescription: String? {
        switch self {
        case .pairingMissing:
            return "Nenhum pairing file ativo. Importe o ALTPairingFile do SideStore ou pareie este iPhone na aba CONFIG."
        case .pairingInvalid(let detail):
            return "Pairing file inválido: \(detail)"
        case .tunnelDown:
            return "Túnel de loopback desligado. Abra o LocalDevVPN, ative o modo loopback (10.7.0.1) e volte."
        case .containerNotFound(let bundleID):
            return "Não achei o container de \(bundleID) via InstallationProxy. O app alvo está instalado?"
        case .exploitFailed(let detail):
            return "Airlift falhou: \(detail)"
        case .writeFailed(let detail):
            return "Falha ao gravar no container: \(detail)"
        case .pathUnknown(let bundleID):
            return "O site não publicou o caminho relativo desta função. Sem isso o Airlift não sabe onde gravar em \(bundleID)."
        case .respringFailed(let detail):
            return "Respring falhou: \(detail)"
        }
    }
}

/// Dono do ciclo de vida do core. `setup()` uma vez no launch.
enum Airlift {
    private static var didSetup = false
    private static let lock = NSLock()

    /// Host do túnel loopback do LocalDevVPN.
    static let defaultTunnelHost = "10.7.0.1"

    /// Instala o subscriber de log do Rust e aponta o host alvo.
    /// Idempotente.
    static func setup() {
        lock.lock()
        defer { lock.unlock() }
        guard !didSetup else { return }
        didSetup = true

        _ = al_log_init(airliftLogSink, nil)
        setTargetHost(defaultTunnelHost)
    }

    static func setTargetHost(_ host: String?) {
        guard let host, !host.isEmpty else {
            al_clear_target_hosts()
            return
        }
        host.withCString { _ = al_set_target_host($0) }
    }

    // MARK: - Container

    /// Resolve o Data container de qualquer bundle ID instalado.
    /// Usa InstallationProxy por cima do túnel: funciona para apps de terceiros
    /// (Free Fire incluso) sem kernel R/W.
    static func findContainer(pairingPath: String, bundleID: String) throws -> String {
        var outContainer: UnsafeMutablePointer<CChar>?
        var outError: UnsafeMutablePointer<CChar>?

        let rc = pairingPath.withCString { pairC in
            bundleID.withCString { bundleC in
                al_find_app_container(pairC, bundleC, airliftLogSink, nil, &outContainer, &outError)
            }
        }

        let failure = outError.flatMap { ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }

        guard rc == 0 else {
            let message = failure ?? "InstallationProxy retornou código \(rc)"
            if message.lowercased().contains("not found") || message.lowercased().contains("notfound") {
                throw AirliftError.containerNotFound(bundleID)
            }
            throw AirliftError.exploitFailed(message)
        }

        guard let container = outContainer.flatMap({ ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }), !container.isEmpty else {
            throw AirliftError.containerNotFound(bundleID)
        }
        return container
    }

    // MARK: - Escrita

    /// Grava todos os arquivos regulares de `sourceDir` (flat, sem subpastas)
    /// em `targetDir`, que é um caminho absoluto no aparelho.
    /// O nome do arquivo de origem é o nome final no destino.
    static func writeDirectory(pairingPath: String, sourceDir: URL, targetDir: String) throws {
        var outError: UnsafeMutablePointer<CChar>?

        let rc = pairingPath.withCString { pairC in
            sourceDir.path.withCString { srcC in
                targetDir.withCString { tgtC in
                    al_exploit_write_dir(pairC, srcC, tgtC, airliftLogSink, nil, &outError)
                }
            }
        }

        let failure = outError.flatMap { ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }
        guard rc == 0 else {
            throw AirliftError.writeFailed(failure ?? "al_exploit_write_dir retornou \(rc)")
        }
    }

    /// Injeta a pasta inteira em `targetParentDir/destName`, preservando a árvore.
    static func injectFolder(pairingPath: String, folder: URL, targetParentDir: String, destName: String) throws {
        var outError: UnsafeMutablePointer<CChar>?
        let rc = pairingPath.withCString { pairC in
            folder.path.withCString { fC in
                targetParentDir.withCString { pC in
                    destName.withCString { dC in
                        al_exploit_inject_folder(pairC, fC, pC, dC, airliftLogSink, nil, &outError)
                    }
                }
            }
        }
        if let error = outError.flatMap({ ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }), rc != 0 {
            throw AirliftError.writeFailed(error)
        }
        guard rc == 0 else {
            throw AirliftError.writeFailed("al_exploit_inject_folder retornou \(rc)")
        }
    }

    // MARK: - Canário (diagnóstico)

    /// Roda a cadeia completa contra um diretório alvo e devolve o JSON de
    /// diagnóstico. Usado pelo botão "Testar acesso" na UI.
    static func runCanary(pairingPath: String, target: String) throws -> String {
        var outJSON: UnsafeMutablePointer<CChar>?
        var outError: UnsafeMutablePointer<CChar>?
        let rc = pairingPath.withCString { pairC in
            target.withCString { tgtC in
                al_exploit_run(pairC, tgtC, airliftLogSink, nil, &outJSON, &outError)
            }
        }
        let failure = outError.flatMap { ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }
        let json = outJSON.flatMap { ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }
        guard rc == 0 else { throw AirliftError.exploitFailed(failure ?? "código \(rc)") }
        return json ?? "{}"
    }

    // MARK: - Respring

    static func respring(pairingPath: String) throws {
        var outError: UnsafeMutablePointer<CChar>?
        let rc = pairingPath.withCString { pairC in
            al_device_respring(pairC, airliftLogSink, nil, &outError)
        }
        if let error = outError.flatMap({ ptr -> String? in
            defer { al_string_free(ptr) }
            return String(cString: ptr)
        }), rc != 0 {
            throw AirliftError.respringFailed(error)
        }
    }
}

// MARK: - Sink de log

// Não pode capturar contexto: chamado de threads arbitrárias do Rust.
private let airliftLogSink: ALLogCallback = { _, message in
    guard let message else { return }
    let line = String(cString: message)
    guard !line.isEmpty else { return }
    DispatchQueue.main.async {
        AppLog.shared.append("[airlift] " + line)
    }
}
