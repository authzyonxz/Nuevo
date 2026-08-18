# Sistema de Injeção Dinâmica IPA

Este projeto agora suporta a importação de arquivos de assets de forma dinâmica, sem a necessidade de recompilar o IPA para cada mudança.

## Como importar arquivos
1. Abra o app **IPA**.
2. Vá na aba **Library**.
3. Toque no botão **+ (Importar)**.
4. Selecione o arquivo do seu iPhone (Arquivos/Files ou Filza).

## Formatos Suportados
O app aceita dois tipos de arquivos:
1. **Arquivos Brutos (Raw)**: Você pode importar diretamente arquivos como `cache_res`, `main.bundle`, etc. O app irá injetá-los automaticamente no caminho padrão: `Documents/Contentchache/Compulsory/ios/gameassetbundles/`.
2. **Pacotes .onyx**: Arquivos compactados com metadados que permitem definir nomes específicos e verificações de integridade.

## Como criar seu próprio arquivo .onyx
Use o script `create_onyx.py` incluído no repositório:
```bash
python3 create_onyx.py meu_asset_customizado
```
Isso gerará um arquivo `meu_asset_customizado.onyx` pronto para ser enviado ao iPhone e importado no app.

## Correções Recentes
- Corrigido crash ao tentar ler arquivos com formato incorreto.
- Adicionado suporte a "Safe Access" para arquivos vindos do iCloud/Files.
- Otimização da lista de assets importados.
