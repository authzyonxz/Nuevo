# Patches defensivos aplicados — MenagerFF KeyOnly

## Escopo

Esta cópia contém apenas alterações defensivas no projeto-fonte. O ZIP original foi preservado em `MenagerFF_original.zip` com o hash SHA-256 `9bcfc34abc6f8bab154844d1df23434207eafcb8e3cda8de29cb7ec470a874b4`.

## Alterações

1. `LicenseManager.swift` foi migrado de `/api/validate-key` para `/api/secure/validate-key` e implementa o envelope observado no servidor: AES-256-GCM, HKDF-SHA256, nonce, timestamp, request ID UUID, AAD vinculada ao caminho e validação de resposta.
2. O cliente mantém uma sessão curta apenas em memória e chama `/api/secure/session/check` antes de cada operação de aplicação/restauração. KEY e device ID continuam no Keychain `WhenUnlockedThisDeviceOnly`; o token bruto legado não é armazenado nem exibido.
3. `ContentView.swift` agora mostra a tela de login até a autorização real, inicia o acesso nativo somente depois de `isAuthorized` e limpa o acesso ao perder a sessão. O status enganoso “Anti-Debug OK” foi substituído por “Sessão autorizada pelo servidor”.
4. `FreeFireModManager.swift` agora faz autorização de sessão dentro do próprio gerenciador, antes de aplicar ou restaurar. A interface não é mais o único ponto de controle.
5. `DevicePatchService.swift` e `ContainerStore.swift` receberam guards de defesa de profundidade para impedir chamadas locais sem sessão autorizada.
6. `KernelExploit.swift` recusa execução quando não existe sessão autorizada. A elevação adicional de identidade para root foi desativada no caminho de modificação por política de menor privilégio.
7. `Utils.swift` aplica redaction centralizado a KEY, token, Authorization, device ID, UDID e session ID tanto em `log()` quanto no capturador de stdout/stderr.

## Limitações importantes

O servidor atualmente possui `/api/secure/session/check`, mas não foi observado um endpoint separado de ticket assinado por operação. Assim, o check de sessão confirma a validade da licença e do dispositivo, mas não vincula cryptograficamente o nome da operação, bundle e path no servidor. Para proteção mais forte, o servidor deve emitir um ticket curto, de uso único, contendo operação, produto, device ID, bundle IDs, paths/digests e expiração; o cliente deve consumi-lo imediatamente antes da escrita.

A proteção não torna o cliente inviolável. Em um dispositivo comprometido, o atacante pode modificar o binário ou interceptar chamadas. A autoridade final precisa continuar no servidor, com rate limiting, replay protection, allowlist, expiração, auditoria e revogação.

## Verificação

Não foi executado build porque o ambiente atual não possui Xcode/macOS. O projeto deve ser compilado em Release no Xcode, mantendo o dSYM fora do IPA. Depois do build, testar login válido, KEY inválida, sessão expirada, replay, ciphertext/AAD adulterados, troca de produto, troca de device ID, operação offline, restauração sem sessão e versões iOS não suportadas.

## Correções de compilação posteriores

8. `ContentView.swift`: substituída a referência inexistente `modManager.activeMod` por `!modManager.activeMods.isEmpty`.
9. `LicenseManager.swift`: adicionados usos explícitos de `self.open(...)` e `self.parseDate(...)` dentro das closures assíncronas, conforme exigido pelo compilador Swift.

A revisão estática confirmou que `activeMod` não aparece mais no código do app e que a rota legada não aparece no código-fonte do cliente.
