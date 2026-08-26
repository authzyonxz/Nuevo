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
