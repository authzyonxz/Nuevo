# Observação do protocolo FFH4X — somente leitura

Fonte observada: `/opt/ffh4x/secure-routes.js` na VPS `ffh4xcorporation.online`, consultada em 2026-08-21.

## Endpoints

- `POST /api/secure/validate-key`
- `POST /api/secure/session/check`
- Rota legada também presente: `POST /api/validate-key`

## Envelope observado

O servidor exige `v`, `alg`, `keyId` com 43 caracteres, `clientNonce` de 16 bytes em Base64URL, `timestamp`, `requestId` UUID e, no endpoint de sessão, `sessionId` com 32–64 caracteres. O payload contém `nonce` de 12 bytes, `ciphertext` e `tag` de 16 bytes, todos Base64URL.

A resposta criptografada repete `v`, `alg`, `keyId`, `clientNonce`, `timestamp`, `requestId`, `sessionId`, `serverNonce` e `payload`. O plaintext da resposta inclui `requestId` e `serverTimestamp`.

## Controles do servidor

O servidor usa AES-256-GCM para abrir/selar JSON, AAD vinculada ao tipo de mensagem, caminho e contexto, valida timestamp, rejeita request IDs repetidos durante a janela de replay, aplica rate limit e mantém sessões expiráveis. A validação associa a KEY ao produto e ao dispositivo. A sessão é derivada com a KEY, o nonce do cliente e o nonce do servidor.

## Observação crítica para o patch

Não foi copiado nenhum segredo, valor de ambiente, KEY de usuário ou token. As funções exatas de derivação/fingerprint/AAD devem ser alinhadas com a implementação existente do protocolo no servidor antes de qualquer build. Não é seguro substituir o cliente por uma implementação aproximada.
