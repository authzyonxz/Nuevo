# Como usar a IPA

Guia para quem vai instalar o 3105. O app escolhe a rota de acesso sozinho pela
versão do iOS — o usuário só configura algo no **iOS 27**, e é na aba **CONFIG**.

## 1. Rota por versão

| iOS | Rota | Precisa configurar algo? |
| --- | --- | --- |
| 17.0 – 18.7.2 | kernel | **Não.** Abre e funciona. |
| 26.0 – 26.6.2 | bad_query (kernel + sandbox escape) | **Não.** Abre e funciona. |
| 27.0 – 27.0.1 | Airlift | **Sim**, na aba CONFIG: parear + VPN. |
| 27.2 beta 1–3 | Airlift | **Sim**, na aba CONFIG. |
| 27.2 beta 4+ | não testado | tentar em CONFIG; o app avisa se falhar. |

Fora dessas faixas o app abre, mas mostra `SEM ROTA DE ACESSO` na aba CONFIG.

## 2. Instalar a IPA

Assine e instale como qualquer IPA. A rota Airlift não usa entitlement de sistema —
é só rede — então assinatura enterprise ou sideload comum servem. **Não mude o
bundle ID** (`com.apple.mobile.MobileHouseArrest`).

## 3. iOS 17 – 18.7.2 e 26.x — nada a fazer

Abra o app, entre com a key e use as abas Aim / C++ / Textura.

- Em 17–18.7.2 o kernel exploit roda na abertura.
- Em 26.x o app roda o kernel, faz o sandbox escape e concede o container via
  `bad_query`.
- A faixa de status no topo da aba Aim mostra `PRONTO` quando o acesso está de pé.

Não precisa de VPN, não precisa de pareamento, não precisa de computador.

## 4. iOS 27.0 – 27.2 beta 2 — configurar o Airlift

Nessas versões o acesso é por pareamento do **próprio iPhone**, sem cabo e sem PC.

### 4.1 Ligar o túnel de loopback

1. Instale o **LocalDevVPN** (App Store).
2. Abra, ative o perfil em modo **loopback** (`10.7.0.1`).
3. Confirme que o ícone de VPN aparece na barra de status.

Sem o túnel o app não alcança o serviço RSD do próprio aparelho.

### 4.2 Parear

Na aba **CONFIG** → **CONEXÃO AIRLIFT**:

1. Toque em **Parear iPhone**.
2. O app mostra um **PIN de 6 dígitos**. Aceite o pedido de **Rede Local** se aparecer.
3. Vá em **Ajustes › Privacidade e Segurança › Modo Desenvolvedor › Pair with 3105**.
4. Digite o PIN. Ao voltar ao app, o cartão mostra `Pareado com sucesso`.

O app mantém áudio silencioso em segundo plano durante esse passo para não ser
suspenso enquanto você está nos Ajustes.

### 4.3 Livros

Uma vez: abra o **Apple Books** e deixe a estante carregar. O `airtrafficd` só aceita
a sessão de sync quando existe a âncora de livros. Sem isso o Airlift falha com
`ReadyForSync not observed`.

### 4.4 Testar

No cartão **CONEXÃO AIRLIFT**, com túnel e pareamento verdes, toque em **Testar**.
Ele resolve o container de `com.dts.freefireth` e roda um canário de escrita/digest.
Se passa, as funções vão aplicar.

### 4.5 Plano B — só se o pareamento on-device não aparecer

Em alguns builds o menu Modo Desenvolvedor pode não mostrar a opção. Aí existe o
caminho antigo, com um computador:

1. iPhone no cabo, desbloqueado, com passcode ativo.
2. Duplo clique em **`tools/PAREAR-3105.bat`** (PC com Python e iTunes/Apple Devices).
3. O script gera o pairing record e empurra direto para o Documents do 3105.
4. Abra o app — ele adota o arquivo sozinho.

Também funciona importar um `ALTPairingFile.mobiledevicepairing` de SideStore/iLoader,
ou colar o conteúdo em base64 no botão **Colar código**.

## 5. Usar as funções

Igual nas três rotas:

1. Entre no jogo e aguarde até ~40% do carregamento.
2. Saia do jogo e volte ao 3105.
3. Aba **Aim** → toque na função. Ela baixa do site, confere o SHA-256 e grava no
   container do jogo.
4. Volte ao jogo, chegue ao lobby.
5. Ao entrar na partida, volte rápido e toque de novo para **desativar**.

Uma função ativa por vez.

## 6. Desativar

- **Kernel / bad_query:** o app guarda o original e devolve. Restore verificado.
- **Airlift:** não há leitura do container, então o app baixa o arquivo original
  publicado pelo site (`originalSha256`) e grava de volta. Se o site não publicou o
  original, só reinstalar o jogo devolve o estado limpo.

## 7. Problemas comuns

| O que aparece | Causa | O que fazer |
| --- | --- | --- |
| `SEM ROTA DE ACESSO` | iOS fora das faixas | conferir a tabela do item 1 |
| `Túnel de loopback desligado` | LocalDevVPN parado | ativar o perfil e voltar |
| `Nenhum pairing file ativo` | não pareou ainda | CONFIG → Parear iPhone |
| `ReadyForSync not observed` | Apple Books nunca aberto | abrir o Books uma vez |
| `AssetManifest not observed` | Books aberto mas não inicializado | esperar a estante carregar |
| `Não achei o container` | jogo não instalado | conferir o bundle ID do site |
| `caminho relativo não publicado` | manifesto sem `relativePath` | publicar no painel |
| `Apple corrigiu o AirTraffic sync` | build não verificado | reportar o build; o app avisa antes de tentar |

## 8. O que o usuário nunca precisa fazer

- jailbreak
- mexer em arquivo de sistema
- reiniciar o aparelho
- manter o app aberto depois de aplicar a função
