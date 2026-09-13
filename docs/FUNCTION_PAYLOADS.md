# Function payloads

A tela **Funções** separa os payloads por jogo e valida o bundle ID dentro do pacote `.3105` antes de permitir a aplicação.

| Jogo | Bundle ID | Tags recomendadas |
| --- | --- | --- |
| Free Fire normal | `com.dts.freefireth` | `game-freefire-normal`, `bundle-com.dts.freefireth` |
| Free Fire MAX | `com.dts.freefiremax` | `game-freefire-max`, `bundle-com.dts.freefiremax` |

## Identificadores dos slots

Para o Free Fire normal, os slots existentes continuam usando `function-1` até `function-5`. Para o Free Fire MAX, use `function-max-1` até `function-max-3`:

| Slot MAX | Nome exibido | Categoria ou tag |
| --- | --- | --- |
| 1 | HS ALTO | `function-max-1` |
| 2 | HS PESCOÇO | `function-max-2` |
| 3 | HS ALTO + PESCOÇO | `function-max-3` |

Cada pacote MAX deve conter a tag de jogo `game-freefire-max` (ou a tag `bundle-com.dts.freefiremax`) e um projeto `.3105` cujo campo `bundleIdentifiers` contenha exatamente `com.dts.freefiremax`. O aplicativo rejeita o pacote se essa condição não for atendida.

Os pacotes normais existentes sem tag de jogo continuam sendo aceitos por compatibilidade. Novos pacotes normais devem usar `game-freefire-normal` e `bundle-com.dts.freefireth` e conter `com.dts.freefireth` no projeto `.3105`.

O manifesto continua sendo servido pela URL configurada no aplicativo. A publicação no servidor precisa apenas acrescentar as categorias/tags acima e disponibilizar os arquivos `.3105` correspondentes; não é seguro identificar o jogo somente pelo nome do pacote.
