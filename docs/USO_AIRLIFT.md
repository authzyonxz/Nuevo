# Como usar a IPA com Airlift

Guia para quem vai instalar o 3105 e rodar as funções nas versões **18.7.2 em diante**.
A rota Airlift não usa kernel exploit: ela escreve no container por pareamento.
Sem os três pré-requisitos abaixo nada acontece — e o app diz qual está faltando.

## 1. Antes de instalar

| Requisito | Detalhe |
| --- | --- |
| iOS | 18.0 – 18.7.10, 26.0 – 26.6.2, 27.0 – 27.0.1, 27.2 beta 1–2 |
| LocalDevVPN | VPN de loopback que publica o serviço RSD em `10.7.0.1:49152` |
| Apple Books | instalado e aberto **pelo menos uma vez** |
| Pairing record | importado (18–26) ou gerado no próprio app (27+) |

> **iOS 27.2 beta 3 ou superior não funciona.** A Apple corrigiu o sync do AirTraffic.
> Se o aparelho já está nesse build, não há caminho por Airlift.

## 2. Instalar a IPA

Assine e instale como qualquer IPA. A rota Airlift não usa entitlement de sistema —
ela fala rede — então assinatura enterprise ou sideload comum servem igual. O que
**não** pode é mudar o bundle ID do app: ele precisa continuar
`com.apple.mobile.MobileHouseArrest`.

Se a instalação for por SideStore/AltStore, o `ALTPairingFile.mobiledevicepairing`
que o próprio SideStore criou já resolve o passo 4 sem esforço.

## 3. Ligar o túnel de loopback

1. Instale o **LocalDevVPN** (o mesmo app que o AirCard exige).
2. Abra, ative o perfil em modo **loopback** (`10.7.0.1`).
3. Confirme que o ícone de VPN aparece na barra de status e continue com o app em segundo plano.

O 3105 mostra `Túnel loopback · 10.7.0.1 ativo` no cartão de acesso quando enxerga a interface.

Qualquer solução que publique o RSD em `10.7.0.1:49152` serve — inclusive perfis
WireGuard próprios. O app só testa se existe uma interface `utun` ativa.

## 4. Parear o aparelho

### iOS 18.0 – 26.x — pairing file importado

1. Gere ou copie o pairing record:
   - **SideStore:** `On My iPhone › SideStore › ALTPairingFile.mobiledevicepairing`
   - **iLoader / Jitterbug:** exporte `<UDID>.mobiledevicepairing` para o Files
   - **PC/Mac:** `jitterbugpair` ou `pymobiledevice3`, depois AirDrop/arquivo para o iPhone
2. Abra o 3105 → aba **Aim** → cartão **ROTA DE ACESSO**.
3. Toque em **Importar pairing** e escolha o arquivo.
   Alternativa: deixe o arquivo em `On My iPhone › 3105` e toque em **Procurar pairing**.
4. O cartão passa a mostrar o nome do aparelho e o tamanho do arquivo.

### iOS 27.0 – 27.2 beta 2 — pareamento no próprio iPhone

1. No cartão de acesso, toque em **Parear iPhone**.
2. O app mostra um **PIN de 6 dígitos** e anuncia o serviço na rede local.
   Aceite o pedido de **Rede Local** se aparecer.
3. Vá em **Ajustes › Privacidade e Segurança › Modo Desenvolvedor › Pair with 3105**.
4. Digite o PIN. Ao voltar ao app, o cartão mostra `Pareado com sucesso`.

O app mantém áudio silencioso em segundo plano durante esse passo para não ser
suspenso enquanto você está nos Ajustes.

## 5. Livros

Só uma vez: abra o **Apple Books** e deixe carregar. O `airtrafficd` só aceita a
sessão de sync quando existe a âncora de livros. Sem isso o Airlift falha com
`ReadyForSync not observed`.

## 6. Testar antes de usar

No cartão **ROTA DE ACESSO**:

- `Túnel loopback` verde
- `Pairing record` verde
- Toque em **Testar** — ele resolve o container de `com.dts.freefireth` e roda um
  canário de escrita/digest dentro dele.

Se o teste passa, as funções vão aplicar. Se falha, a mensagem aponta exatamente
qual dos três pré-requisitos está fora.

## 7. Usar as funções

1. Entre no jogo e aguarde até ~40% do carregamento.
2. Saia do jogo e volte ao 3105.
3. Aba **Aim** → toque na função desejada. Ela baixa do site, confere o SHA-256 e
   grava no container.
4. Volte ao jogo e chegue ao lobby.
5. Ao entrar na partida, volte rápido ao 3105 e toque na função de novo para
   **desativar**.

Uma função ativa por vez. O card mostra `Ativado` enquanto a transação está aberta.

## 8. Desativar (restore)

No Airlift o app **não** guarda cópia do original — ele não tem permissão de leitura
no container. Desativar baixa o arquivo original publicado pelo site
(`originalSha256` no manifesto) e grava de volta.

Se o site não publicou o original, o app avisa: nesse caso só reinstalar o jogo
devolve o estado limpo.

## 9. Problemas comuns

| O que aparece | Causa | O que fazer |
| --- | --- | --- |
| `Túnel de loopback desligado` | LocalDevVPN parado ou fora do modo loopback | ativar o perfil e voltar ao app |
| `Nenhum pairing file ativo` | nada importado | importar o ALTPairingFile ou parear no iOS 27 |
| `Pairing file inválido` | arquivo truncado ou outro plist | pegar o arquivo direto do SideStore/iLoader |
| `ReadyForSync not observed` | Apple Books nunca aberto | abrir o Books uma vez |
| `AssetManifest not observed` | Books instalado mas não inicializado | abrir o Books, esperar a estante carregar |
| `Não achei o container de com.dts.freefireth` | jogo não instalado ou container renomeado | confirmar o bundle ID publicado pelo site |
| `O site não publicou o caminho relativo desta função` | manifesto sem `relativePath` | publicar o campo no painel |
| `Apple corrigiu o AirTraffic sync` | iOS 27.2 beta 3+ | sem caminho por Airlift nesse build |

## 10. O que o usuário nunca precisa fazer

- Não precisa de jailbreak.
- Não precisa de kernel exploit.
- Não precisa mexer em arquivo do sistema, nem reiniciar o aparelho.
- Não precisa manter o app aberto depois de aplicar a função.
