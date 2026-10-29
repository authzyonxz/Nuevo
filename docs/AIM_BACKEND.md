# Aim payloads — site + app

Sistema novo, separado do patch `.3105`, para a aba **Aim**.

## Como o patch normal funciona (para comparação)

1. `PatchProject` guarda regras (`PatchRule`) com `bundleID` + `relativePath` + bytes do arquivo novo.
2. `DevicePatchService.apply` resolve o container pelo `bundleIdentifier` (`ContainerStore.resolveAppContainerPath`).
3. `PatchTransaction.apply` valida cada caminho, copia o original para `Backups/<projectID>/<txnID>/<ruleID>.original`, grava o substituto de forma atômica (`.3105-replacement-*` + `rename`), calcula SHA-256 e escreve um journal em plist.
4. `PatchTransaction.restore` relê o journal, confere se o alvo ainda é o que foi aplicado (fail-closed), devolve o original e apaga arquivos introduzidos.
5. `PatchTransaction.latestReceipt` / `inspectRestore` dão o estado atual de um projeto.

Ou seja: caminho fixo, backup obrigatório, journal com digest, restore verificado.

## Como o Aim funciona

Diferença: o arquivo é **normal** (não é pacote) e o caminho **não é fixo** — o app varre o container
inteiro atrás do nome publicado.

```
site (backend)                app (3105)
---------------               -----------------------------------------------
publica arquivo        ->     GET /api/v1/functions           (manifestos)
por função + bundle id        GET /api/v1/functions/<id>/payload   (arquivo + sha256)
                              verifica sha256
                              ContainerFileLocator.matches(...)  varre o container
                              FunctionPatchStore.apply(...)      backup + troca + journal
                              FunctionPatchStore.restore(...)    devolve original
```

### Arquivos do app

| arquivo | papel |
| --- | --- |
| `helpers/AimFunctions.swift` | catálogo das 6 funções (id, nome, descrição, ícone, status Safe) |
| `helpers/FunctionPatchClient.swift` | URL do site, manifestos, download do payload, sha256 |
| `helpers/ContainerFileLocator.swift` | varredura do container por nome de arquivo (sem symlink, sem staging) |
| `helpers/FunctionPatchStore.swift` | transação: backup, troca atômica, journal plist, restore fail-closed |
| `views/AimView.swift` | aba Aim: servidor, bundle ID, cards das funções, aplicar/restaurar |

### Onde ficam os backups no aparelho

```
Application Support/PatchProjects/Backups/Functions/<function-id>/<txn-id>/
├── journal.plist
├── 0.original
├── 1.original
└── ...
```

Mesma pasta base do `PatchProjectLibrary.backupRootURL()`, então backup e limpeza continuam num lugar só.
Ao restaurar com sucesso os `.original` são removidos e o journal fica marcado como `restored`.

### Fluxo de troca de variante

Aplicar `hs-chest` quando `hs-neck-antenna` está aplicado: o `apply` primeiro restaura a transação
anterior da mesma função (volta ao original) e só então aplica a nova. Sem arquivo pela metade.

### Restore fail-closed

`restore` compara o digest atual do alvo com o digest gravado na aplicação. Se o jogo reescreveu o
arquivo, a restauração normal para e o app oferece **Forçar restauração** (menu `…` do card).

## Backend

Código em `3105-aim/backend` (repo separado, Python stdlib, sem dependência).
Sobe em qualquer VPS, roda bem em 128 MB:

```bash
python server.py --host 127.0.0.1 --port 8080
```

- admin: `http://127.0.0.1:8080/admin` (token em `data/admin_token.txt`)
- API pública usada pelo app: `/api/v1/functions`, `/api/v1/functions/<id>/payload`
- cada publish gera uma versão; a ativa é a última; versões antigas ficam baixáveis

iOS só fala HTTPS com servidor remoto. Para teste em rede local o `Info.plist` já tem
`NSAllowsLocalNetworking`.

## Build

Nada de novo em dependências. Os 5 arquivos novos já estão no target do
`ThreeOneOSFive.xcodeproj`. Abra no Xcode 15+, assine com o certificado enterprise e rode.

No app: aba **Aim → Servidor** → cole `https://aim.seudominio.com` → `Atualizar` →
confirme o bundle ID → `Aplicar`.
