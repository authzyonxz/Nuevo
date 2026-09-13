# Servidor de Payloads 3105

Este servidor fornece um `manifest.json` HTTPS para o app e uma área administrativa para criar, substituir e remover payloads de função separados por jogo. O app só exibe uma função quando ela está publicada no manifesto e só aplica o arquivo `.3105` quando o projeto contém o bundle ID correspondente.

## Jogos e identificadores

| Jogo | Bundle ID | Slots | Prefixo |
| --- | --- | --- | --- |
| Free Fire normal | `com.dts.freefireth` | 1–5 | `function-` |
| Free Fire MAX | `com.dts.freefiremax` | 1–3 | `function-max-` |

Os slots MAX representam: `function-max-1` = HS ALTO, `function-max-2` = HS PESCOÇO e `function-max-3` = HS ALTO + PESCOÇO.

## Executar na VPS

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export PAYLOAD_ADMIN_TOKEN='troque-por-um-token-longo'
export PORT=8080
python server.py
```

Publique o serviço atrás de HTTPS, por exemplo `https://seu-dominio.example/manifest.json`. O app aceita somente URLs HTTPS públicas.

## Publicar um payload

Para Free Fire normal:

```bash
curl -X POST 'https://seu-dominio.example/admin/functions/normal/5' \
  -H 'X-Admin-Token: troque-por-um-token-longo' \
  -F 'package=@/caminho/arquivo.3105' \
  -F 'name=Função 5' \
  -F 'version=1.0.0' \
  -F 'summary=Descrição da função'
```

Para Free Fire MAX, use `max` e um slot de 1 a 3:

```bash
curl -X POST 'https://seu-dominio.example/admin/functions/max/1' \
  -H 'X-Admin-Token: troque-por-um-token-longo' \
  -F 'package=@/caminho/hs-alto-max.3105' \
  -F 'name=HS ALTO' \
  -F 'version=1.0.0' \
  -F 'summary=HS acima da cabeça'
```

O servidor gera automaticamente a categoria e as tags de jogo. O projeto dentro do `.3105` ainda precisa conter o bundle correto; essa é a validação final feita pelo aplicativo antes da injeção.

Para remover uma função, use o mesmo caminho com `DELETE`:

```bash
curl -X DELETE 'https://seu-dominio.example/admin/functions/max/1' \
  -H 'X-Admin-Token: troque-por-um-token-longo'
```

O servidor valida o cabeçalho `3105PATCH`, a versão do envelope, calcula SHA-256, substitui o arquivo anterior da função e atualiza o manifesto. O app baixa o arquivo somente quando o switch da função é ativado. Ao desativar, ele restaura os arquivos registrados na transação daquela função.
