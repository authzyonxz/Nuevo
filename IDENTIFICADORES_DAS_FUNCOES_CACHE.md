# Identificadores das funções Cache

Os IDs abaixo são novos e não reutilizam os IDs Avatar existentes.

| Nome exibido | ID do payload no manifesto | Bundles compatíveis |
|---|---|---|
| HS PESCOÇO | `cache_hs_pescoco_v1` | `com.dts.freefireth`, `com.dts.freefiremax` |
| HS ALTO | `cache_hs_alto_v1` | `com.dts.freefireth`, `com.dts.freefiremax` |
| HS PEITO | `cache_hs_peito_v1` | `com.dts.freefireth`, `com.dts.freefiremax` |
| BALA MÁGICA | `cache_bala_magica_v1` | `com.dts.freefireth`, `com.dts.freefiremax` |

## Observações

Os bundles acima são os identificadores reais dos aplicativos já suportados pelo IPA. Não devem ser criados bundles fictícios. Use somente o bundle para o qual o arquivo foi realmente preparado:

- `com.dts.freefireth` — Free Fire normal;
- `com.dts.freefiremax` — Free Fire MAX.

Os campos `file_name`, `target_paths`, `download_url`, `sha256`, `size`, `version` e `enabled` continuam sendo definidos no manifesto da VPS. O IPA lê esses valores do atualizador e valida a compatibilidade do payload antes de aplicar qualquer alteração.

Exemplo de entrada no manifesto:

```json
{
  "id": "cache_hs_pescoco_v1",
  "display_name": "HS PESCOÇO",
  "file_type": "bin",
  "version": 1,
  "file_name": "NOME_DO_ARQUIVO_PUBLICADO",
  "target_paths": ["CAMINHO_RELATIVO_CONFIGURADO_NA_VPS"],
  "compatible_games": ["com.dts.freefireth", "com.dts.freefiremax"],
  "sha256": "SHA256_DO_ARQUIVO",
  "size": 0,
  "download_url": "URL_RELATIVA_DO_PAYLOAD",
  "enabled": true
}
```

O mesmo formato pode ser repetido para os quatro IDs, substituindo os valores do arquivo, caminho, hash, tamanho e URL.
