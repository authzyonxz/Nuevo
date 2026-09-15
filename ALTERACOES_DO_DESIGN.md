# Alterações do design — MenagerFF unificado

A aplicação é distribuída como **uma única IPA**, reunindo as funções que antes eram separadas entre as variantes Aimbot/Holograma e Cache.

## Fluxo inicial

Depois que a Key é validada, o usuário vê a tela **Selecione o jogo**. Nela, deve escolher um único perfil antes de abrir as funções:

A autenticação possui um cartão visual premium, campo seguro com opção de mostrar ou ocultar a Key e um indicador de três etapas: **Package**, **iPhone** e **Acesso**. O antigo texto “Checking package” foi substituído por **Verificando o pacote**, com feedback visual durante a conexão e a validação.

| Perfil | Bundle usado por todas as operações |
| --- | --- |
| Free Fire Normal | `com.dts.freefireth` |
| Free Fire MAX | `com.dts.freefiremax` |

A seleção é mantida durante toda a sessão. Aplicação, restauração e abertura do jogo usam exclusivamente o bundle escolhido. O estado de uma função ativa no Free Fire Normal não é apresentado como ativo no Free Fire MAX, e vice-versa.

## Navegação principal

O cabeçalho de cada aba exibe somente o nome da seção. As descrições abaixo de Aims, ESP, Chams, Texturas e Ajustes foram removidas, enquanto a logo do jogo selecionado, o perfil ativo, o bundle e o botão de tema permanecem no topo.

| Aba | Conteúdo |
| --- | --- |
| **Aims** | Controle “Selecione o Tipo de Arquivo” com as opções Avatar e Cache. |
| **ESP** | Função exclusiva AIMBOT + ESP e botão **ABRIR JOGO**, que preserva a função ativa. |
| **Chams** | Holograma Armas com seis opções de cor. |
| **Texturas** | Cards visuais para Skin Instaplayer, Skin Mandela e Skin RuokFF. |
| **Ajustes** | Função Forçar 120/144 FPS, informações do perfil e controle de aparência. |

### Funções Avatar

- HS ALTO
- HS PESCOÇO
- HS ALTO + PESCOÇO

As funções Avatar são selecionadas por switch e aplicadas pelo botão **INJETAR (40%)**. Holograma Armas não aparece mais em Aims.

### Funções Cache

- HS ALTO
- HS PESCOÇO
- HS PEITO
- BALA MÁGICA

As funções Cache mantêm o comportamento da IPA Cache anterior: são aplicadas diretamente ao ligar o switch e restauradas ao desligá-lo.

### Função ESP

A aba ESP contém somente **AIMBOT + ESP**, com a descrição “aimbot legit e esp linha, caixa, nome e vida” e a observação **Ative antes de entrar no jogo**. O botão **ABRIR JOGO** abre o bundle escolhido sem restaurar ou desativar o ESP.

### Funções Chams

Sob o título **HOLOGRAMA ARMAS**, a aba Chams apresenta:

- AMARELO
- VERMELHO
- ROXO
- LARANJA
- PRETO
- BRANCO

Cada opção tem um ID próprio no atualizador online e somente uma cor Chams pode permanecer ativa por vez.

## Aparência

O design segue as referências fornecidas, com fundo suave, cards arredondados, hierarquia tipográfica forte, ícones visíveis em todas as funções, destaque azul e navegação inferior compacta. O botão com ícone de **sol/lua** alterna toda a interface entre os temas claro e escuro, e a preferência fica salva no aparelho.

## Build

O workflow `Build Unified Unsigned IPA` gera um único artefato:

`MenagerFF-Unified-Unsigned-IPA/MenagerFF_Unified_Unsigned.ipa`
