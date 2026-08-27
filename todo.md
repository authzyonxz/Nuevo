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

- [ ] Restaurar o produto da API para `ruanwq`
- [ ] Ocultar o nome do produto na aba CONFIG
- [ ] Corrigir falha de restauração segura após fechar e reabrir o IPA
- [ ] Validar persistência, restauração e holograma
- [ ] Gerar e verificar nova build unsigned
