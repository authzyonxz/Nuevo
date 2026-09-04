# Key Auth v2 no MenagerFF

O fluxo de licença anterior baseado em `FFH4XSecureClient` foi removido do target. O app agora usa `KeyAuthClient` com o contrato v2 do servidor Key Auth. A UI original foi mantida; apenas o estado interno e o conteúdo do overlay de entrada foram conectados ao fluxo v2.

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `ThreeOneOSFive/helpers/FFH4XSecureClient.swift` | Removido. |
| `ThreeOneOSFive/helpers/KeyAuthClient.swift` | Novo cliente HTTP/criptográfico v2. |
| `ThreeOneOSFive/helpers/KeyAuthAppConfiguration.swift` | Configuração pública do domínio, Package, `kid` e chave P-256. |
| `ThreeOneOSFive/helpers/LicenseManager.swift` | Reescrito para sessão v2, Keychain, enrollment e autorização. |
| `ThreeOneOSFive/App.swift` | Revalida a sessão ao voltar ao foreground. |
| `ThreeOneOSFive.xcodeproj/project.pbxproj` | Remove o cliente antigo e registra os dois novos arquivos no target. |

## Fluxo em execução

A tela original permanece visível e começa com **Checking package**. O app consulta `/api/v2/package/status` e somente continua quando `available == true` e `status == active`. Em seguida cria uma sessão v2, salva o token opaco no Keychain e abre o portal `/device/external/{token}`. O portal orienta o download e a instalação do perfil temporário; o Profile Service recebe o UDID e marca a sessão como capturada.

Ao retornar ao app, o ciclo de vida consulta `/api/v2/device/session/status`. Enquanto o UDID não foi capturado, o overlay original mostra o estado de espera. Quando `captured == true` e `registered == false`, o campo original de Key é habilitado. Depois que o usuário informa a Key, ela é enviada exclusivamente à rota `/api/v2/authorization/issue`. Em retornos futuros, a sessão e a autorização curta são revalidadas antes de liberar operações protegidas.

A resposta de emissão v2 é `{ grant, claims, kid }`. O cliente foi corrigido para decodificar esse formato; a versão anterior esperava campos inexistentes (`grantPayload`, `package` e `expiresAt`) e por isso podia apresentar “não foi possível validar essa key” mesmo após o servidor emitir o grant.

Em cada retorno ao foreground e antes de aplicar ou restaurar uma função, o app consulta o estado da sessão, verifica se o dispositivo e a Key continuam registrados e solicita uma nova autorização curta. Falhas de rede, sessão expirada, Package pausado, Key revogada ou grant inválido mantêm o app bloqueado.

## Configuração

A configuração atual aponta para:

```text
Base URL: https://keyauthv2.org
Package: external
Audience: keyauth-ios
Policy: 2
```

A chave pública e o `kid` são material público de verificação. A chave privada do servidor nunca deve ser incluída no app.

## Limite da substituição

`OnlinePayloadUpdater.swift` é uma integração independente para manifestos e downloads de payloads em `https://ffh4xcorporation.online`. Ela não é usada para autenticação de licença e não foi redirecionada para Key Auth, porque o contrato Key Auth v2 não oferece essas rotas de manifesto/download. Removê-la sem uma API substituta faria os recursos de payload remoto deixarem de funcionar.

Antes de publicar, compile e teste no Xcode em um dispositivo real. Confirme também se o Package `external` é o Package correto para este aplicativo e se o `kid` continua válido após qualquer rotação de chaves do servidor.
