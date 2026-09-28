import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case portuguese = "pt-BR"
    case english = "en"
    case vietnamese = "vi"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .portuguese: return "Português"
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .simplifiedChinese: return "简体中文"
        }
    }

    func text(_ key: String) -> String {
        if self == .portuguese, let value = PortugueseText.values[key] {
            return value
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private var localizedBundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

private enum PortugueseText {
    static let values: [String: String] = [
        "common.close": "Fechar",
        "common.done": "Concluído",
        "common.ok": "OK",
        "common.cancel": "Cancelar",
        "common.clear": "Limpar busca",
        "common.failed": "Falha",
        "tab.home": "Início",
        "tab.patches": "Funções",
        "home.current_system": "Sistema atual",
        "home.system_version": "Versão do sistema",
        "home.system_build": "Build do sistema",
        "home.compatibility": "Compatibilidade",
        "home.compatible": "Dispositivo compatível",
        "home.not_compatible": "Dispositivo não compatível",
        "home.compatible_versions": "Versões e builds compatíveis",
        "home.compatibility_footer": "Somente as versões e builds listados são considerados compatíveis.",
        "update.title": "Atualização disponível",
        "update.message": "A versão %@ do 3105 está disponível no GitHub.",
        "update.agree": "Abrir",
        "update.dismiss": "Não mostrar novamente",
        "patch.title": "Funções",
        "patch.add": "Adicionar função",
        "patch.new": "Nova função",
        "patch.import": "Importar pacote",
        "patch.export": "Exportar pacote",
        "patch.edit": "Editar",
        "patch.empty_title": "Nenhuma função disponível",
        "patch.empty_message": "As funções serão incluídas junto com a build do aplicativo.",
        "patch.locked_project": "Função protegida",
        "patch.tap_to_unlock": "Toque para informar a senha",
        "patch.password_protected": "Protegida por senha",
        "patch.rules_count": "%lld regras de substituição",
        "patch.workspace_items_count": "%lld itens no workspace",
        "patch.search": "Buscar funções",
        "patch.search_empty": "Nenhuma função encontrada",
        "patch.search_empty_message": "Tente buscar pelo nome, identificador ou caminho.",
        "patch.project": "Função",
        "patch.project_name": "Nome da função",
        "patch.target_bundle": "Aplicativo de destino",
        "patch.workspace_bundle_footer": "O pacote interno usa o identificador estável do aplicativo.",
        "patch.captured_content": "Conteúdo definido",
        "patch.workspace_edit_footer": "O conteúdo da função é fornecido pela build do aplicativo.",
        "patch.workspace": "Pacote interno",
        "patch.open_workspace": "Abrir conteúdo",
        "patch.workspace_detail_footer": "Este pacote foi incluído junto com a build do aplicativo.",
        "patch.legacy_footer": "Pacote legado compatível com esta versão.",
        "patch.files": "Arquivos",
        "patch.folders": "Pastas",
        "patch.rules": "Regras",
        "patch.add_rule": "Adicionar regra",
        "patch.edit_rule": "Editar regra",
        "patch.destination": "Destino",
        "patch.bundle_path_footer": "Cada regra usa o identificador do aplicativo e um caminho relativo.",
        "patch.bundle_not_uuid_footer": "Use o identificador do aplicativo, nunca um UUID de container.",
        "patch.replacement_file": "Arquivo de substituição",
        "patch.choose_file": "Escolher arquivo",
        "patch.file_size": "Tamanho",
        "patch.replacement_required": "Arquivo de substituição obrigatório",
        "patch.change_replacement": "Toque para escolher outro arquivo",
        "patch.importing_replacement": "Importando substituição…",
        "patch.edit_rule_hint": "Abre esta regra para edição",
        "patch.password": "Senha",
        "patch.password_optional": "Senha opcional",
        "patch.password_locked": "Definida permanentemente",
        "patch.no_password": "Sem senha",
        "patch.password_immutable_footer": "A senha não pode ser alterada depois da criação.",
        "patch.password_existing_footer": "Esta configuração não pode ser alterada.",
        "patch.password_once_message": "Depois de desbloquear, este dispositivo memoriza a chave do pacote.",
        "patch.unlock": "Desbloquear",
        "patch.apply": "Aplicar função",
        "patch.restore": "Restaurar original",
        "patch.export": "Exportar",
        "patch.apply_footer": "Os arquivos originais são preservados antes da aplicação.",
        "patch.apply_confirm_title": "Aplicar esta função?",
        "patch.apply_confirm_message": "Os destinos serão validados antes da aplicação.",
        "patch.restore_confirm_title": "Restaurar arquivos originais?",
        "patch.created_message": "A função foi criada.",
        "patch.updated_message": "A função foi atualizada.",
        "patch.imported_message": "O pacote foi importado.",
        "patch.unlocked_message": "Desbloqueado.",
        "patch.workspace_synced_message": "O conteúdo foi sincronizado.",
        "patch.applied_message": "A função foi aplicada.",
        "patch.restored_message": "Os arquivos originais foram restaurados.",
        "patch.error.unsupported_format": "Este não é um pacote válido.",
        "patch.error.unsupported_version": "Este pacote exige uma versão mais nova do aplicativo.",
        "patch.error.password_or_corrupt": "A senha está incorreta ou o pacote foi alterado.",
        "patch.error.invalid_bundle": "Informe um identificador de aplicativo válido.",
        "patch.error.unsafe_path": "O destino precisa ser um caminho relativo seguro.",
        "patch.error.size_limit": "O pacote ou arquivo excede o tamanho permitido.",
        "patch.error.duplicate_target": "Existem duas regras para o mesmo destino.",
        "patch.error.invalid_project": "Verifique o nome, destino e conteúdo da função.",
        "patch.error.replacement_required": "Escolha um arquivo para cada destino.",
        "patch.error.keychain": "Não foi possível acessar a chave armazenada com segurança.",
        "patch.error.app_unavailable": "O aplicativo de destino não está disponível.",
        "patch.error.symlink": "Links simbólicos não são aceitos.",
        "patch.error.apply": "A função não pôde ser aplicada.",
        "patch.error.restore": "Os arquivos originais não puderam ser restaurados.",
        "patch.error.invalid_import_link": "O link de importação é inválido.",
        "patch.error.remote_import": "O pacote remoto não pôde ser baixado.",
        "browser.create_patch": "Criar função",
        "browser.open_new_tab": "Abrir em nova aba",
        "accessibility.open_logs": "Abrir logs",
        "accessibility.open_settings": "Abrir ajustes",
        "status.not_attempted": "Não iniciado",
        "status.ok_via": "Ativo via %@",
        "status.failed_via": "Falhou %@ (%lld)",
        "status.unsupported_reason": "Não compatível: %@",
        "method.simulator_preview": "Prévia do simulador"
    ]
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.portuguese
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

extension ExploitStatus {
    func displayText(language: AppLanguage) -> String {
        switch self {
        case .notStarted:
            return language.text("status.not_attempted")
        case .success(let method):
            let localizedMethod = method == "Simulator preview"
                ? language.text("method.simulator_preview")
                : method
            return language.text("status.ok_via", localizedMethod)
        case .failed(let method, let code):
            return language.text("status.failed_via", method, code)
        case .unsupported(let message):
            return language.text("status.unsupported_reason", message)
        }
    }
}
