# Build iOS - TODO

- [x] Substituir a árvore `source` pelo projeto enviado no ZIP
- [x] Preservar os arquivos de documentação e histórico do repositório
- [x] Configurar workflow macOS para compilar IPA não assinado
- [ ] Enviar o projeto atualizado ao GitHub
- [ ] Executar o workflow de GitHub Actions
- [ ] Verificar o status do workflow e o artefato final
- [ ] Documentar o procedimento de execução e download

## Observações

O build de IPA exige runner macOS/Xcode. O ambiente local Linux não consegue executar `xcodebuild`; a compilação será realizada pelo GitHub Actions.
