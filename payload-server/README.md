# Servidor de Payloads 3105

Este servidor fornece um `manifest.json` HTTPS para o app e uma área administrativa para criar, substituir e remover os cinco payloads de função. O app procura a categoria `function-1` até `function-5`; se uma função não estiver publicada, o switch permanece desativado e informa que não há payload disponível.

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

```bash
curl -X POST 'https://seu-dominio.example/admin/functions/5' \
  -H 'X-Admin-Token: troque-por-um-token-longo' \
  -F 'package=@/caminho/arquivo.3105' \
  -F 'name=Função 5' \
  -F 'version=1.0.0' \
  -F 'summary=Descrição da função'
```

O servidor valida o cabeçalho `3105PATCH`, a versão do envelope, calcula SHA-256, substitui o arquivo anterior da função e atualiza o manifest. Para remover uma função:

```bash
curl -X DELETE 'https://seu-dominio.example/admin/functions/5' \
  -H 'X-Admin-Token: troque-por-um-token-longo'
```

O app baixa o arquivo somente quando o switch da função é ativado. Ao desativar, ele restaura os arquivos registrados na transação daquela função, sem importar manualmente arquivos pela interface.
