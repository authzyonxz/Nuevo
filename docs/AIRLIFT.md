# Airlift — acesso a container sem kernel exploit

Port do mecanismo do [AirCard-iOS](https://github.com/Mak5er/AirCard-iOS) para o 3105.
Estende o alcance do app para **27.0 – 27.0.1 e 27.2 beta 1–2**
sem depender de offsets de kernel.

## Por que isso funciona onde o kexploit não vai

O Airlift não toca no kernel. Ele faz o aparelho conversar consigo mesmo como se fosse
um computador com iTunes:

```
pairing record  →  túnel RSD no loopback (10.7.0.1:49152)
                →  AFC + streaming_zip_conduit  (staging em /var/mobile/Media)
                →  com.apple.atc: Books.plist com AirFileIdentifier
                →  ATAirlock move o asset e segue o symlink
                →  o arquivo cai fora da sandbox, no caminho absoluto que pedimos
```

O `airtrafficd` carrega uma sandbox extension que segue o symlink; é ela que entrega a
escrita em qualquer diretório absoluto. Não há leitura correspondente — essa é a
assimetria central e ela define o desenho do patch.

## Roteamento por versão

| iOS | Rota | Consequência prática |
| --- | --- | --- |
| 17.0 – 17.7.x | kernel | ler + escrever + backup local do original |
| 18.0 – 18.7.1 | kernel | idem, sem fallback Airlift |
| 27.0 – 27.0.1 | airlift | pareamento on-device disponível |
| 27.2 beta 1–2 | airlift | pareamento on-device disponível |
| 27.2 beta 3+ | bloqueado | Apple fechou o sync do AirTraffic |

A decisão vive em `ExploitSupportPolicy.accessKind(major:minor:patch:build:)`.
`KernelExploit.isApplicable` agora responde `false` fora da faixa de kernel, então o app
nunca dispara o `kexploit_opa334` em builds onde os offsets param em 26.0.x.

## Pré-requisitos reais

1. **LocalDevVPN** (ou WireGuard) em modo loopback, publicando o RSD em `10.7.0.1`.
2. **Pareamento local**: em iOS 27.0–27.0.1 e 27.2 beta 1–2, o próprio app anuncia
   o host e mostra o PIN para Ajustes › Privacidade e Segurança › Modo Desenvolvedor.
3. **Apple Books instalado e aberto pelo menos uma vez** — o sync do `airtrafficd`
   só aceita `ReadyForSync` quando existe âncora de livros.

## Contrato com o site

O Airlift é write-only. Duas coisas passam a ser obrigatórias no manifesto de cada função:

```json
{
  "id": "hs-neck-antenna",
  "bundleID": "com.dts.freefireth",
  "relativePath": "Library/Application Support/com.dts.freefireth/config.bin",
  "sha256": "<digest do arquivo alterado>",
  "originalSha256": "<digest do arquivo original>"
}
```

- `relativePath` (ou `destinationPath`, o nome antigo) — caminho relativo ao Data container.
  Sem ele não há como descobrir o alvo: o app não tem permissão de varredura no container.
  O mesmo valor continua vindo em `X-Payload-Path` no download.
- `originalSha256` — habilita o restore. Sem esse campo, desativar a função exige
  reinstalar o jogo, e o app diz isso na cara.

Endpoint novo:

```
GET /api/v1/functions/<id>/original
Authorization: Bearer <grant>
X-KeyAuth-Session: <token>

200 OK
X-Payload-Filename: config.bin
X-Payload-Sha256: <64 hex>
X-Payload-Version: <int>
<bytes do arquivo original>
```

Mesmas regras do `/payload`: `sha256` do header tem de bater com o `originalSha256`
do manifesto, senão o download é descartado.

## Arquivos

| arquivo | papel |
| --- | --- |
| `helpers/Airlift/AirliftFFI.swift` | ponte Swift sobre `airlift.h`; log, container, escrita, canário, respring |
| `helpers/Airlift/AirliftPairing.swift` | pairing record, detecção do túnel, pareamento on-device, cartão de UI |
| `helpers/Airlift/AirliftPatchStore.swift` | transação Airlift: plano de escrita, journal plist, restore |
| `helpers/Airlift/AccessBackend.swift` | seletor de rota + apply/restore unificado |
| `helpers/SupportPolicy.swift` | matriz de versões e `accessKind` |
| `views/AimView.swift` | cartão de acesso + roteamento do apply/restore |

Backups ficam em:

```
Application Support/PatchProjects/Backups/FunctionsAirlift/<functionID>/<txnID>/journal.plist
```

## Build

- `AirliftFFI.xcframework` na raiz do projeto, linkado no target (não embutido — é lib estática).
- `OTHER_LDFLAGS` ganhou `-lc++` (símbolos C++ do aws-lc dentro do core Rust).
- `EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64` — a lib é arm64-only.
- `IPHONEOS_DEPLOYMENT_TARGET = 18.0` — alinhado com o mínimo da lib, sem aviso de linker.
  Consequência: iOS 17.x deixa de instalar. Para recuperar 17.x basta voltar o target
  para 16.0 e aceitar o aviso `object file was built for newer iOS version`.
- `SWIFT_STRICT_CONCURRENCY = minimal` — mantém os avisos de ator como aviso, não erro.
- `FRAMEWORK_SEARCH_PATHS` inclui `$(SRCROOT)` para o módulo `AirliftFFI` ser encontrado.
- `Info.plist` ganhou `NSBonjourServices`, `UIBackgroundModes: audio` e o scheme
  `localdevvpn` em `LSApplicationQueriesSchemes`.

Passo a passo para quem instala a IPA: [USO_AIRLIFT.md](USO_AIRLIFT.md).

## Limites conhecidos

- **Sem leitura do container.** Nada de varredura de arquivos por nome no caminho Airlift.
- **O diretório de destino precisa existir.** O Airlift grava o arquivo dentro de uma pasta
  já presente no container; não cria a árvore intermediária. `relativePath` tem de apontar
  para um caminho real do app alvo.
- **IOS 27.2 beta 3+ está corrigido.** `patchedAirliftBuilds` em `SupportPolicy.swift`
  existe para bloquear por build assim que os IDs forem conhecidos; hoje o app tenta e
  devolve o erro do próprio exploit.
- O caminho iOS 18–26 exige pairing file externo: sem SideStore/iLoader não há pareamento.
- Cada `al_exploit_write_dir` abre um túnel novo (~2–5 s). Não é fluxo para many-small-files.
- O teto prático é um arquivo por função, com caminho publicado. É exatamente o formato
  que o Aim já usa.

## Créditos

- [AirCard-iOS](https://github.com/Mak5er/AirCard-iOS) (MIT) — implementação de referência.
- [airlift](https://github.com/0xjohnnydev/airlift) por 0xjohnny — pesquisa do AirTraffic.
- [idevice](https://github.com/jkcoxson/idevice) — cliente Rust de usbmuxd/lockdown/AFC.
