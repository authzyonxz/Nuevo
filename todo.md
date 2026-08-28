# Build iOS - TODO

- [x] Limpar o conteúdo anterior do repositório
- [x] Subir somente o projeto `MenagerFF_Updated_Source(4).zip`
- [x] Gerar a build sem modificar o projeto
- [x] Verificar e entregar o IPA gerado

## Escopo

A árvore `ThreeOneOSFive` e o projeto Xcode devem permanecer idênticos ao ZIP fornecido. O workflow original do ZIP será mantido; nenhum arquivo do aplicativo será editado.

- [x] Aplicar persistência mínima das funções ativas ao reabrir o IPA
- [x] Confirmar que injeção e restauração manual permanecem iguais
- [x] Gerar e verificar build persistente de teste

- [x] Remover a restauração automática ao fechar o IPA
- [x] Manter a função aplicada até restauração manual
- [x] Gerar e verificar nova build corrigida

- [x] Conferir o destino atual do Holograma de Armas
- [x] Corrigir o destino para `Documents/contentcache/optional/ios/gameassetbundles`
- [x] Gerar e verificar nova build sem alterar as outras funções

- [x] Restaurar `KernelExploit.cleanup()` ao entrar em background/fechar o IPA
- [x] Confirmar que `restoreOriginal()` continua somente manual
- [x] Gerar e verificar nova build

- [x] Redesenhar abas em estilo preto inspirado na referência, sem mudar as opções existentes
- [x] Adicionar seletor visual de Free Fire e Free Fire Max usando as logos fornecidas
- [x] Usar o Toggle padrão do iOS para ligar/desligar cada função
- [x] Validar que cada switch continua chamando a mesma lógica atual
- [x] Gerar e verificar nova build unsigned

- [x] Validar a key ao entrar no IPA com janela flutuante preta
- [x] Remover a validação de API do acionamento dos switches sem alterar a proteção da API
- [x] Modernizar visualmente a aba CONFIG mantendo seus dados e ações existentes
- [x] Remover o botão VALIDAR KEY da aba CONFIG
- [x] Gerar e verificar nova build unsigned

- [x] Alterar o rótulo “Produto” para “Revendedor” na aba CONFIG
- [x] Gerar e verificar nova build unsigned

- [x] Alterar o produto enviado à API para `granjeiro`
- [x] Exibir `GRANJEIRO - FF` como produto na aba CONFIG
- [x] Gerar e verificar nova build unsigned

- [x] Corrigir falha ao restaurar função ativa após fechar e reabrir o IPA
- [x] Validar reabertura do exploit e restauração manual sem alterar cleanup ao fechar
- [x] Gerar e verificar nova build unsigned

- [x] Alterar o identificador do produto da API de `ruanwq` para `revendedores`
- [x] Verificar que endpoint, proteção e funcionamento permanecem inalterados

- [x] Restaurar o identificador do produto da API para `ruanwq`
- [x] Verificar que endpoint, proteção e funcionamento permanecem inalterados
- [x] Gerar e verificar nova build unsigned

- [x] Exibir “Produtos - Ruanwq” na aba CONFIG
- [x] Verificar e gerar nova build unsigned

- [x] Ocultar visualmente o nome do produto na aba CONFIG sem alterar a API
- [x] Corrigir a injeção do HOLOGRAMA ARMAS
- [x] Validar holograma e preservar as demais funções
- [x] Gerar e verificar nova build unsigned

- [x] Investigar por que o holograma reporta 1 local, mas não tem efeito no jogo
- [x] Validar nome, conteúdo, caminho e bundle do asset do holograma
- [x] Corrigir somente a confirmação/aplicação efetiva do holograma
- [x] Gerar e verificar nova build unsigned

- [x] Alterar o produto da API de `ruanwq` para `granjeiro`
- [x] Exibir `GRANJEIRO - FF` na aba CONFIG
- [x] Confirmar que a correção do holograma permanece intacta
- [x] Gerar e verificar nova build unsigned

- [x] Restaurar o produto da API para `ruanwq`
- [x] Ocultar o nome do produto na aba CONFIG
- [x] Corrigir falha de restauração segura após fechar e reabrir o IPA
- [x] Validar persistência, restauração e holograma
- [x] Gerar e verificar nova build unsigned

- [x] Alterar novamente o produto da API para `granjeiro`
- [x] Verificar que as correções de restauração e holograma permanecem intactas
- [x] Compactar e validar o ZIP do projeto atualizado

- [x] Gerar build unsigned do projeto com produto `granjeiro`
- [x] Baixar e validar o IPA gerado
- [x] Entregar o IPA ao usuário

- [x] Processar `MenagerFF_visual_animado_corrigido.zip`
- [x] Aplicar o mesmo padrão Release/hardening do guia anterior
- [x] Corrigir referências de arquivos necessárias para a compilação
- [x] Gerar e verificar a nova IPA unsigned
- [x] Alterar somente o design da tela de login conforme a referência
- [x] Substituir a teia por partículas alongadas animadas sem conexões
- [x] Confirmar que proteção, endpoints e demais funções não foram alterados
- [x] Gerar e verificar a IPA unsigned do design atualizado

- [x] Corrigir o design do `KeyGateOverlay`, que é a tela de entrada realmente exibida
- [x] Trocar o fundo atual por bolinhas roxas maiores e animadas, sem teia nem linhas
- [x] Preservar integralmente a proteção, a validação e os demais fluxos
- [x] Gerar e verificar nova IPA unsigned após a correção

- [ ] Remover os bastões/pauzinhos retos das partículas
- [ ] Adicionar conexões elásticas orgânicas entre algumas bolinhas
- [ ] Manter login, proteção e demais funções inalterados
- [ ] Gerar e verificar nova IPA unsigned

- [ ] Alterar o produto enviado à API de `granjeiro` para `ruanwq`
- [ ] Preservar proteção, endpoint e demais fluxos
- [ ] Gerar e verificar nova IPA unsigned
