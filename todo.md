# Build iOS - TODO

- [x] Substituir a árvore `source` pelo projeto enviado no ZIP
- [x] Preservar os arquivos de documentação e histórico do repositório
- [x] Configurar workflow macOS para compilar IPA não assinado
- [x] Enviar o projeto atualizado ao GitHub
- [x] Executar o workflow de GitHub Actions
- [x] Verificar o status do workflow e o artefato final
- [x] Documentar o procedimento de execução e download

## Observações

O build de IPA exige runner macOS/Xcode. O ambiente local Linux não consegue executar `xcodebuild`; a compilação será realizada pelo GitHub Actions.

- [x] Corrigir o erro "Two rules point to the same app file" ao ativar uma função
- [x] Gerar e verificar nova build após a correção
