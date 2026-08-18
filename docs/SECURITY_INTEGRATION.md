# Integração segura FFH4X

## Modelo aplicado

O projeto usa as rotas seguras `POST /api/secure/validate-key` e `POST /api/secure/session/check` do domínio `https://ffh4xcorporation.online`. O endpoint legado `/api/validate-key` não é mais usado.

O login deriva `keyId` como Base64URL de SHA-256 da KEY, gera `clientNonce` aleatório de 16 bytes e monta um envelope versionado. O payload é protegido com AES-256-GCM. A chave bootstrap é derivada com HKDF-SHA256 usando a KEY, o nonce do cliente e o contexto `ffh4x-secure-v1/bootstrap`.

A resposta de validação fornece `serverNonce` e `sessionId`. O cliente deriva uma chave de sessão com HKDF-SHA256 usando a concatenação dos nonces e o contexto `ffh4x-secure-v1/session`. A resposta só é aceita quando a tag GCM e o AAD do protocolo são válidos.

## Sem heartbeat

Esta versão deliberadamente não executa timer, NSTimer, DispatchSource.Timer ou heartbeat em segundo plano. A sessão é validada no login e novamente quando uma operação protegida é iniciada.

Cada aplicação ou restauração de patch chama `/api/secure/session/check` com um `requestId` novo, timestamp, sessão, operação e payload AES-GCM. Em caso de falha, a operação não começa e a sessão local é invalidada.

## Gate no executor

`DevicePatchService.apply` e `DevicePatchService.restore` são assíncronos e exigem autorização antes de chamar `PatchTransaction`. O ticket local é de uso único e expira rapidamente; portanto, a UI não é a autoridade final para executar o patch.

O `ContentView` monta uma única transação com todas as regras encontradas e aguarda autorização antes da escrita. O `CleanerView` usa o mesmo executor protegido para restauração.

## Armazenamento e exposição

A KEY e a identidade do dispositivo são armazenadas com `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. O estado da sessão permanece somente em memória. A tela de configurações mostra apenas um fingerprint curto da KEY, e não o segredo completo. O campo de login é limpo após uma autenticação bem-sucedida.

## Limitação de segurança

Em um dispositivo sob controle total do usuário, nenhum gate local é impossível de instrumentar. A proteção depende da decisão server-side, da validade da sessão, da proteção do protocolo e da exigência de autorização no caminho de execução. A remoção do heartbeat reduz verificações periódicas, mas também significa que uma revogação entre operações só será percebida na próxima operação protegida.
