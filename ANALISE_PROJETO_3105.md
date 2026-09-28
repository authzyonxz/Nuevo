# Análise técnica do projeto 3105 — versão 1.1.1

## 1. Resumo executivo

O projeto é um aplicativo nativo para iOS escrito principalmente em **Swift 5 + SwiftUI**, com bridges em Objective-C/C para integração com APIs privadas, descoberta de containers e recursos de baixo nível. O foco funcional atual é:

- navegação por abas para Home, Files, Patches, Cleaner e Wallpapers;
- exploração de dados de containers de aplicativos;
- operações de arquivos e ZIP;
- criação, importação, exportação, aplicação e restauração de patches `.3105`;
- limpeza limitada de `Library/Caches` e `tmp`;
- importação e instalação de pacotes de wallpaper `.tendies`;
- onboarding, configurações, logs e localização em inglês, vietnamita e chinês simplificado.

A base visual é relativamente centralizada: `views/DesignSystem.swift` contém o tema, tamanhos e componentes compartilhados. Isso permite fazer uma reformulação consistente sem reescrever as regras de negócio.

## 2. Estrutura encontrada

```text
3105-1.1.1/
├── ThreeOneOSFive.xcodeproj/       # projeto e target Xcode
├── ThreeOneOSFive/
│   ├── App.swift                   # ponto de entrada e estado global
│   ├── ContentView.swift           # navegação, abas e Dashboard/Home
│   ├── Info.plist                 # bundle, documentos, URL scheme e capacidades
│   ├── Assets.xcassets/            # ícone do aplicativo
│   ├── views/                     # telas e componentes SwiftUI
│   ├── helpers/                   # modelos, serviços e utilitários Swift
│   ├── exploit/                   # bridges C/Objective-C para recursos de acesso
│   ├── kexploit/                  # código Objective-C/C de baixo nível
│   ├── *.lproj/Localizable.strings # localizações
│   └── ThreeOneOSFive-Bridging-Header.h
├── docs/                          # guias, changelog visual e screenshots
├── README.md
├── CHANGELOG.md
└── LICENSE / THIRD_PARTY_NOTICES.md
```

Inventário aproximado: **47 arquivos Swift**, **26 arquivos C/Objective-C/header** e **95 arquivos no ZIP** contando documentação, assets e configuração.

## 3. Fluxo de inicialização

### `App.swift`

`ThreeOneOSFiveApp` cria e injeta três objetos globais:

- `AppState`: compatibilidade do sistema e status do acesso de baixo nível;
- `PatchDraftCoordinator`: comunicação entre o browser de arquivos e a criação de patches;
- `FileOperationCoordinator`: clipboard/transferências entre operações de arquivos.

Também controla:

- onboarding inicial;
- idioma e `Locale` via `@AppStorage`;
- checagem de atualização;
- logs;
- abertura de URLs externas para importação de `.3105`;
- sheet de atribuição/display identity.

**Implicação para design:** alterações no shell global, onboarding, transições ou overlays devem respeitar esse `ZStack` de inicialização e os ambientes SwiftUI injetados.

### `ContentView.swift`

É o container principal da interface:

- em size class compacta, usa `TabView` inferior;
- em size class regular, usa `NavigationSplitView` com sidebar;
- controla visibilidade opcional de Cleaner e Wallpapers;
- preserva tabs e caminhos independentes do Files;
- direciona automaticamente para Patches quando existe um draft/import request.

A Home está implementada internamente como `DashboardView` no mesmo arquivo.

## 4. Mapa das telas

| Tela/arquivo | Responsabilidade | Dependências visuais principais |
| --- | --- | --- |
| `ContentView.swift` | shell, abas, sidebar e Home | `AppTheme`, `AppSection`, `FeatureVisibility` |
| `AppDataBrowserView.swift` | lista de apps/container e busca | `AppSearchField`, `AppRowIcon`, `BrowserAppIcon` |
| `FileBrowserView.swift` | navegação, busca e operações de arquivo | `AppSearchField`, rows, barras inferiores, dialogs |
| `FilesTabControls.swift` | tabs horizontais e botão de tabs | `AppTheme.accent`, `FilesTabSession` |
| `FilesTabSwitcherView.swift` | gerenciador modal de tabs | `FilesTabSession` |
| `PatchProjectsView.swift` | lista, busca, criação/importação de patches | `AppSearchField`, rows, empty states |
| `PatchProjectEditorView.swift` | formulário de projeto e regras | `Form`, `Section`, sheets, validação |
| `CleanerView.swift` | scan, seleção, ordenação e limpeza | `AppSearchField`, `List`, action button |
| `WallpaperLabView.swift` | acesso, pacotes, instalação e reset | `List`, overlays, alerts |
| `SettingsView.swift` | idioma, dispositivo, compatibilidade e créditos | `Form`, `AppLogo`, links |
| `OnboardingView.swift` | primeiro acesso e requisitos | `AppLogo`, cards/steps e ambiente de idioma |
| `LogView.swift` | apresentação de logs | console theme |
| `DesignSystem.swift` | tokens e componentes compartilhados | tema global |

## 5. Sistema visual atual

`DesignSystem.swift` é o principal ponto de extensão para o redesign.

### Tokens existentes

- `AppTheme.accent`: laranja adaptado para light/dark mode;
- `pageBackground` e `consoleBackground`;
- `pageInset`;
- tamanhos de ícones, rows, app icons e estados vazios;
- altura padrão de linha de arquivo.

### Componentes compartilhados

- `AppRowIcon`: ícone em retângulo arredondado com fundo translúcido;
- `AppSearchField`: busca persistente com ícone, clear button e material de barra;
- `AppLogo`: ícone do app com fallback para SF Symbol.

### Diagnóstico visual

A interface usa majoritariamente componentes nativos (`List`, `Form`, `Section`, `NavigationStack`, `TabView`, `NavigationSplitView`) com ajustes pontuais de cor, espaçamento e tipografia. O resultado atual favorece compatibilidade e acessibilidade, mas um redesign mais marcante exigirá decidir até onde manter o comportamento nativo de `List/Form` versus substituir trechos por `ScrollView`/cards customizados.

## 6. Fluxos funcionais por aba

### Home

Exibe modelo do dispositivo, versão iOS, compatibilidade e status do kernel em versões aplicáveis. Também permite ativar/desativar Cleaner e Wallpapers na navegação. Logs e Settings abrem por sheets.

### Files

1. carrega workspace local `On My iPhone/3105`;
2. descobre aplicativos por múltiplas fontes;
3. mescla e ordena os resultados;
4. permite buscar e abrir um container;
5. mantém caminhos separados por tab;
6. oferece seleção, copy/move, ZIP, importação, criação, rename, delete e preview;
7. pode iniciar a criação de um patch via draft coordinator.

É a tela mais complexa da UI: `FileBrowserView.swift` tem cerca de 1.760 linhas e reúne apresentação, estado, dialogs e chamadas aos serviços.

### Patches

`PatchProjectsView` usa `PatchProjectStore` para listar/importar/excluir projetos. O detalhe permite editar, aplicar, restaurar e exportar. O editor usa formulários e sheets para regras.

Há suporte a:

- workspace v2 baseado em árvore de diretórios;
- pacotes v1 legados;
- senha opcional imutável após criação;
- chaves lembradas no Keychain;
- validação de bundle ID e caminhos relativos;
- journal/recovery antes de escrita.

### Cleaner

O escopo é deliberadamente limitado: apenas `Library/Caches` e `tmp`. A tela possui busca, ordenação por tamanho, seleção múltipla, resumo e confirmação destrutiva antes da limpeza.

### Wallpapers

`WallpaperLabView` importa múltiplos `.tendies`, verifica acesso, mostra pacotes, instala somente após alerta de confirmação e registra receipts para reset direcionado.

## 7. Separação entre UI e lógica

A maior parte da lógica de negócio está fora das views:

- containers: `ContainerStore`, `ContainerBrowserLogic`, `ContainerIdentityResolver`;
- arquivos: `FileManagerService`, `FileReplacementService`, `FileOperationCoordinator`;
- patches: `PatchPackageCodec`, `PatchProjectStore`, `PatchWorkspaceService`, `PatchTransaction`, `DevicePatchService`;
- cleaner: `LimitedCleanerService`, `CleanerCatalog`;
- wallpapers: `WallpaperLabService`, `WallpaperInstaller`, `WallpaperLabModels`;
- suporte e sistema: `SupportPolicy`, `KernelExploit`, `Utils`, `MG`, `SBX`.

**Estratégia recomendada:** manter esses serviços intactos durante mudanças visuais. Alterar primeiro componentes de apresentação, tokens, composição das telas e strings; tocar nos serviços apenas se uma mudança de UX exigir novo estado ou fluxo.

## 8. Localização

Existem três catálogos com o mesmo número de entradas:

- `en.lproj/Localizable.strings`;
- `vi.lproj/Localizable.strings`;
- `zh-Hans.lproj/Localizable.strings`.

A UI atual usa `AppLanguage` e `language.text(...)`, portanto textos novos devem ser adicionados aos três arquivos. Não é recomendável inserir strings diretamente em views, exceto placeholders técnicos muito específicos.

## 9. Configuração Xcode encontrada

- bundle identifier intencional: `com.apple.mobile.MobileHouseArrest`;
- deployment target: **iOS 16.0**;
- Swift: **5.0**;
- famílias de dispositivo: **iPhone e iPad**;
- bridging header configurado;
- `Info.plist` declara abertura de documentos `.3105`, URL scheme `threeoneosfive` e suporte a arquivos no app;
- orientação portrait no iPhone e portrait/landscape no iPad.

O bundle identifier e os fluxos de container são sensíveis; não devem ser alterados durante um redesign sem uma necessidade explícita.

## 10. Pontos recomendados para futuras modificações de design

### Redesign global

Alterar primeiro:

1. `views/DesignSystem.swift` — cores, materiais, raios, tamanhos e componentes comuns;
2. `ContentView.swift` — estrutura de navegação, sidebar, tab bar e Home;
3. `AppLogo`/asset do ícone, se necessário;
4. localizações dos novos labels.

### Redesign por aba

- **Home:** `DashboardView` em `ContentView.swift`;
- **Files:** `AppDataBrowserView.swift`, `FileBrowserView.swift`, `FilesTabControls.swift`;
- **Patches:** `PatchProjectsView.swift`, `PatchProjectEditorView.swift`;
- **Cleaner:** `CleanerView.swift`;
- **Wallpapers:** `WallpaperLabView.swift`;
- **Settings/Onboarding:** arquivos correspondentes em `views/`.

### Componentização sugerida antes de uma grande mudança

Se a nova identidade visual for substancial, vale extrair componentes como:

- `AppNavigationShell`;
- `SectionHeader`/`GroupedCard`;
- `PrimaryActionButton`;
- `EmptyStateView`;
- `StatusBadge`;
- `AppListRow`;
- `SettingsRow`.

Isso reduz duplicação e torna as cinco abas coerentes.

## 11. Riscos e cuidados

- `FileBrowserView.swift` concentra muito estado; mudanças grandes devem ser feitas incrementalmente.
- `List` e `Form` têm comportamento próprio de margem, background e seleção; um redesign com cards pode exigir remover o estilo nativo em pontos específicos.
- iPhone e iPad seguem layouts diferentes; toda alteração de navegação deve ser testada nas duas size classes.
- Dynamic Type, Reduce Motion e VoiceOver já aparecem no código; não remover esses suportes.
- Os dialogs de confirmação de delete, apply, restore, install e reset são parte da segurança funcional e não devem ser escondidos por estética.
- A localização deve permanecer alinhada nos três idiomas.
- O ambiente atual é Linux e não possui `xcodebuild` nem `swift`; portanto não foi possível executar compilação iOS neste sandbox. A validação local feita aqui é estrutural/estática. A compilação final deve ser realizada no Xcode em macOS.
- O código de baixo nível foi apenas mapeado; nenhuma alteração nele é necessária para modificações de design.

## 12. Conclusão

O projeto está organizado o suficiente para evoluir visualmente sem reestruturar o núcleo. O caminho mais seguro é trabalhar em camadas:

1. definir a nova direção visual;
2. atualizar `DesignSystem.swift`;
3. aplicar o shell global em `ContentView.swift`;
4. adaptar cada aba preservando seus estados e serviços;
5. revisar sheets, dialogs, empty states e acessibilidade;
6. atualizar traduções;
7. compilar e testar no Xcode em iPhone/iPad, light/dark mode e Dynamic Type.

Estou pronto para seguir com as modificações de design a partir da aba ou referência visual que você indicar.
