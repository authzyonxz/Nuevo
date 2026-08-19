# Patch de segurança FFH4X — Menager iPA FF

## Escopo

Este pacote foi criado a partir de `IPA_FF_Project_Final_Updated.zip` e não altera o ZIP original nem a VPS. O SHA-256 do original é:

`f59d94317b185115dfb77ba0f2782f37869eb8743fcdf72c2b58062abc88aeb5`

## Alterações

O `LicenseService` deixou de usar `/api/validate-key` e passou a usar `/api/secure/validate-key` e `/api/secure/session/check`. O envelope usa AES-GCM com AAD de protocolo, HKDF-SHA256, nonce, timestamp, request ID, key ID e sessão. A KEY não é enviada em claro no JSON externo.

O Keychain da KEY e do identificador do dispositivo usa `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. A tela de Settings mostra apenas fingerprint curto da KEY, e o campo de login é limpo depois da validação.

`DevicePatchService.apply` e `DevicePatchService.restore` agora exigem uma chamada segura ao servidor antes de executar `PatchTransaction`. O ticket local é de uso único e vinculado à operação, sessão e expiração curta. O `ContentView` e o `CleanerView` foram adaptados para aguardar o gate assíncrono.

O título da tela de login é `Menager iPA FF`. O Release foi endurecido com stripping e otimização, e o logger detalhado ficou condicionado a `DEBUG`.

## Heartbeat

Não foi adicionado heartbeat. Não há timer periódico. A sessão é checada no login e antes de cada aplicação ou restauração de patch. Consequentemente, uma revogação será percebida na próxima operação protegida, não durante uma operação ociosa.

## Validação

A verificação estática passou para endpoint seguro, AES-GCM, HKDF, Keychain ThisDeviceOnly, ausência de timer, gate de operação, ticket de uso único, máscara da KEY, título da tela, stripping Release, otimização e observador de invalidação.

A compilação iOS não foi executada neste ambiente, pois depende de Xcode/macOS e SDK do iOS. O projeto deve ser compilado pelo usuário no ambiente Theos/Xcode compatível e testado contra a API segura ativa. Se o servidor ainda não aceitar o envelope seguro exatamente no formato já definido, o login recusará a conexão em vez de cair para o endpoint legado.
