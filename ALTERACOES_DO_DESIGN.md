# Alterações do design — MenagerFF unificado

A aplicação agora é distribuída como **uma única IPA**, reunindo as funções que antes eram separadas entre as variantes Aimbot/Holograma e Cache.

## Fluxo inicial

Depois que a Key é validada, o usuário vê a tela **Selecione o jogo**. Nela, deve escolher um único perfil antes de abrir as funções:

| Perfil | Bundle usado por todas as operações |
| --- | --- |
| Free Fire Normal | `com.dts.freefireth` |
| Free Fire MAX | `com.dts.freefiremax` |

A seleção é mantida durante toda a sessão. Aplicação, restauração e abertura do Lobby usam exclusivamente o bundle escolhido. O estado de uma função ativa no Free Fire Normal não é apresentado como ativo no Free Fire MAX, e vice-versa.

## Navegação principal

| Aba | Conteúdo |
| --- | --- |
| **Aims** | Controle “Selecione o Tipo de Arquivo” com as opções Avatar e Cache. |
| **ESP** | Função exclusiva AIMBOT + ESP, com a descrição “aimbot legit e esp linha, caixa, nome e vida”. |
| **Texturas** | Cards visuais para Skin Instaplayer, Skin Mandela e Skin RuokFF. |
| **Ajustes** | Função Forçar 120/144 FPS, informações do perfil e controle de aparência. |

### Funções Avatar

- HS ALTO
- HS PESCOÇO
- HS ALTO + PESCOÇO
- HOLOGRAMA ARMAS

As funções Avatar são selecionadas por switch e aplicadas pelo botão **INJETAR (40%)**. O botão **LOBBY** restaura as funções ativas do jogo escolhido antes de abri-lo.

### Funções Cache

- HS ALTO
- HS PESCOÇO
- HS PEITO
- BALA MÁGICA

As funções Cache mantêm o comportamento da IPA Cache anterior: são aplicadas diretamente ao ligar o switch e restauradas ao desligá-lo.

## Aparência

O novo design segue as referências fornecidas, com fundo suave, cards arredondados, hierarquia tipográfica forte, destaque azul e navegação inferior compacta. O botão com ícone de **sol/lua** alterna toda a interface entre os temas claro e escuro, e a preferência fica salva no aparelho.

## Build

O workflow `Build Unified Unsigned IPA` gera um único artefato:

`MenagerFF-Unified-Unsigned-IPA/MenagerFF_Unified_Unsigned.ipa`
