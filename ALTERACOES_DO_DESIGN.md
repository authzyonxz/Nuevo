# Alterações do design — MenagerFF

A interface foi adaptada ao estilo das imagens de referência, mantendo a estrutura funcional do projeto e os nomes das funções existentes.

| Área | Alteração aplicada |
| --- | --- |
| Tela de key | Fundo preto, campo “Digite sua key” e botão branco “ENTRAR”, mantendo a mesma validação e exibição de erros. |
| Tela de funções | Cabeçalho central, ícones de Free Fire Normal e Free Fire Max no topo, contorno no aplicativo selecionado, lista escura de funções e navegação inferior minimalista. |
| Ativação | Ligar uma chave agora apenas seleciona a função; nenhuma injeção é feita nesse momento. |
| Injeção | Após selecionar uma função, aparece o botão “INJETAR (40%)”, que chama o fluxo original de aplicação. |
| Lobby | O botão “LOBBY” abre o aplicativo correspondente ao bundle ID selecionado no topo. |
| Desativação | Desligar uma função já aplicada continua chamando a restauração original. Uma seleção ainda não injetada é apenas cancelada. |

A validação estática confirmou que o arquivo Swift modificado não contém erros sintáticos, que a ativação não chama diretamente a injeção, que a desativação continua usando `restoreMod`, que o botão de injeção usa `applyMod` e que o Lobby utiliza `openApplicationForBundleID`. A compilação final para iOS ainda deve ser executada no Xcode em macOS, pois o ambiente de preparação não possui o SDK da Apple.
