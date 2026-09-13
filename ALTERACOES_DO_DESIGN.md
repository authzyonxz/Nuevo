# Alterações do design — MenagerFF

A interface permanece no estilo das imagens de referência, e a tela principal agora exibe exatamente quatro funções Avatar, nesta ordem: **HS ALTO + PESCOÇO**, **HS PESCOÇO**, **AIMBOT** e **HS ALTO**.

| Área | Comportamento mantido |
| --- | --- |
| Tela de key | Campo “Digite sua key”, botão “ENTRAR” e mesma validação existente. |
| Ativação | Ligar uma chave somente seleciona a função. |
| Injeção | O botão “INJETAR (40%)” chama o fluxo original `applyMod`. |
| Lobby | O botão “LOBBY” abre o jogo selecionado pelo bundle ID. |
| Desativação | Desligar uma função aplicada chama a restauração original `restoreMod`. |

Os quatro IDs Avatar necessários para publicação estão no arquivo `IDENTIFICADORES_DOS_PAYLOADS.md`; todos usam o bundle ID `com.dts.freefireth`. A validação estática confirmou a sintaxe Swift, a ordem das quatro funções e a preservação dos fluxos de seleção, injeção, restauração e Lobby. A compilação iOS final deve ser executada no Xcode em macOS.
