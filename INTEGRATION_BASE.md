# Base integrada final

Esta cópia usa `34306/FilzaJailedDS` como referência do núcleo e integra o sistema funcional do usuário: autenticação, painel, três assets, substituição do arquivo, heartbeat de cinco minutos, logs visíveis, trava contra cliques repetidos e hooks desativados.

Também foram aplicadas as correções de estabilidade da cópia testada: falhas do exploit encerram somente a thread de trabalho, não o processo do Filza, e offsets inválidos retornam falha segura.

O ambiente sandbox não possui Theos nem SDK iOS; a compilação deve ser feita no ambiente Theos do usuário.
