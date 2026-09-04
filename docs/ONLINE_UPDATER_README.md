# MenagerFF Online Updater

Este pacote fornece uma **API de atualização de payloads** e um painel administrativo em `/configurar`. O servidor publica um manifesto versionado, mantém os arquivos remotos fora do bundle do aplicativo, calcula SHA-256 e permite ativar, desativar, substituir ou excluir HS/Aimbot e Holograma sem uma nova IPA. Nesta versão híbrida, texturas e 144fps permanecem protegidos dentro da IPA e HS/Aimbot e Holograma são configuráveis online.

> O servidor deve ser usado somente para arquivos e aplicações que você está autorizado a distribuir. Não coloque credenciais, chaves privadas ou payloads reais no GitHub.

## Arquitetura

| Componente | Função |
|---|---|
| `server/index.mjs` | API Express, upload, catálogo, download, substituição e exclusão |
| `public/index.html` | Painel administrativo acessível em `/configurar` |
| `storage/manifest.json` | Catálogo atual, criado automaticamente |
| `storage/payloads/` | Arquivos publicados, fora da IPA |
| `tools/generate-keys.mjs` | Gera um par Ed25519 para assinar manifestos |
| `../nuevo/.../OnlinePayloadUpdater.swift` | Cliente iOS que baixa e valida payloads |

## Requisitos da VPS

Use Ubuntu ou Debian atualizado, Node.js 20 ou superior, um domínio apontando para a VPS e um proxy HTTPS como Nginx ou Caddy. O exemplo abaixo usa um usuário de serviço sem privilégios e mantém o token administrativo apenas no arquivo `.env`.

```bash
sudo apt update && sudo apt install -y git nginx certbot python3-certbot-nginx
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
sudo useradd --system --home /opt/menagerff-updater --shell /usr/sbin/nologin menagerff || true
sudo mkdir -p /opt/menagerff-updater
sudo chown -R menagerff:menagerff /opt/menagerff-updater
```

Copie o diretório deste projeto para `/opt/menagerff-updater` por um canal seguro e execute:

```bash
cd /opt/menagerff-updater
npm ci --omit=dev
cp .env.example .env
chmod 600 .env
npm run generate-keys
```

Cole no `.env` um token administrativo longo e aleatório. A chave privada deve ser mantida somente na VPS. A variável `UPDATER_PUBLIC_KEY_BASE64` é documentada para o cliente, mas o fluxo de validação mínimo do arquivo Swift usa HTTPS, tamanho e SHA-256; a assinatura Ed25519 pode ser habilitada no próximo endurecimento com a chave pública fixada no app.

## Arquivo `.env`

```env
PORT=8080
ADMIN_TOKEN=troque-por-um-token-com-mais-de-32-caracteres
# Opcional: conteúdo PEM PKCS8 da chave privada Ed25519, com quebras de linha reais.
UPDATER_PRIVATE_KEY=
```

Gere um token sem colocá-lo no histórico do shell:

```bash
openssl rand -base64 48
```

## Serviço systemd

Crie `/etc/systemd/system/menagerff-updater.service`:

```ini
[Unit]
Description=MenagerFF online updater
After=network.target

[Service]
Type=simple
User=menagerff
Group=menagerff
WorkingDirectory=/opt/menagerff-updater
EnvironmentFile=/opt/menagerff-updater/.env
ExecStart=/usr/bin/node /opt/menagerff-updater/server/index.mjs
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/opt/menagerff-updater/storage

[Install]
WantedBy=multi-user.target
```

Ative o serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now menagerff-updater
curl http://127.0.0.1:8080/api/v1/health
```

## HTTPS com Nginx

Crie um bloco para o seu domínio em `/etc/nginx/sites-available/menagerff-updater`:

```nginx
server {
    listen 80;
    server_name ffh4xcorporation.online;

    client_max_body_size 250M;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Depois habilite e emita o certificado:

```bash
sudo ln -s /etc/nginx/sites-available/menagerff-updater /etc/nginx/sites-enabled/menagerff-updater
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d ffh4xcorporation.online
```

Acesse `https://ffh4xcorporation.online/configurar`, informe o token administrativo e publique cada payload. A aba **Monitoramento** permite testar a saúde da API e atualizar manualmente a lista de eventos.

## Publicação pela API

O painel é o caminho recomendado. Para automação, publique um arquivo com `multipart/form-data`:

```bash
curl -X POST https://ffh4xcorporation.online/api/v1/admin/payloads \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F id=hs_pescoco_cache \
  -F display_name='HS Pescoço — cache_res' \
  -F file_type=cache_res \
  -F version=2 \
  -F file_name='cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D' \
  -F target_paths='Documents/contentcache/Compulsory/ios/gameassetbundles' \
  -F compatible_games='com.dts.freefireth,com.dts.freefiremax' \
  -F payload=@./cache_res.exemplo
```

O manifesto público está em `/api/v1/manifest`. O download de cada payload ocorre em `/api/v1/payloads/:id`. As opções do painel ficam em `/api/v1/admin/options`. Os logs administrativos podem ser consultados em `/api/v1/admin/logs?limit=200` com `Authorization: Bearer <ADMIN_TOKEN>`. O servidor rejeita nomes com separadores de diretório, limita uploads a 250 MB e não expõe a listagem do armazenamento.

## Integração no iOS

O `OnlinePayloadUpdater.swift` já está incluído no target principal e usa `https://ffh4xcorporation.online`. O método `download(id:bundleID:)` somente retorna dados quando o item está habilitado, é compatível com o bundle ID, possui o tamanho esperado e bate com o SHA-256 do manifesto.

O `FreeFireModManager` usa o manifesto remoto para as três funções cache_res, as três funções Avatar e Holograma. Para texturas e 144fps, usa o armazenamento AES-GCM local e abre o payload apenas durante a operação. Os itens remotos trazem um ou mais `target_paths`; cada entrada pode ser o caminho completo do arquivo ou o caminho de um diretório, ao qual o app acrescenta o `file_name`. O aplicativo só aplica destinos já existentes e rejeita caminhos com `..`. O 144fps permanece limitado ao `com.dts.freefireth`.

Exemplo de uso assíncrono:

```swift
Task {
    do {
        let (_, data) = try await OnlinePayloadUpdater.shared.download(
            id: "hs_pescoco_cache",
            bundleID: "com.dts.freefireth",
            forceRefresh: true
        )
        // Entregar `data` diretamente ao fluxo de aplicação em memória.
    } catch {
        await MainActor.run { statusMessage = error.localizedDescription }
    }
}
```

## Variantes HS: cache_res e Avatar

O painel e a IPA oferecem seis funções HS remotas, três do tipo `cache_res` e três do tipo `Avatar`:

| Tipo | ID estável | Nome exibido | Caminho padrão | Bundle permitido |
|---|---|---|---|---|
| cache_res | `hs_alto_cache` | HS Alto — cache_res | `Documents/contentcache/Compulsory/ios/gameassetbundles` | normal e MAX |
| cache_res | `hs_pescoco_cache` | HS Pescoço — cache_res | `Documents/contentcache/Compulsory/ios/gameassetbundles` | normal e MAX |
| cache_res | `hs_peito_cache` | HS Peito — cache_res | `Documents/contentcache/Compulsory/ios/gameassetbundles` | normal e MAX |
| Avatar | `hs_alto_avatar_pescoco` | HS Alto + Pescoço — Avatar | `Documents/contentcache/Compulsory/ios/gameassetbundles/avatar` | somente normal |
| Avatar | `hs_pescoco_avatar_antena` | HS Pescoço + Antena — Avatar | `Documents/contentcache/Compulsory/ios/gameassetbundles/avatar` | somente normal |
| Avatar | `hs_peito_avatar_antena` | HS Peito + Antena — Avatar | `Documents/contentcache/Compulsory/ios/gameassetbundles/avatar` | somente normal |

O nome padrão do arquivo Avatar é `assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D`. O nome padrão do `cache_res` é `cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D`. A IPA exibe os dois grupos separadamente: **Funções cache_res** e **Funções Avatar**. O Avatar é rejeitado para `com.dts.freefiremax` tanto no painel quanto no cliente.

## Monitoramento e logs

Os eventos são armazenados em `storage/events.ndjson`, um registro JSON por linha. O painel mostra os 200 eventos mais recentes e registra health-checks, consultas ao manifesto, downloads de payloads, publicações, alterações de status e tentativas de autenticação inválidas. O botão **Atualizar monitoramento** executa um novo teste contra `/api/v1/health` e recarrega os logs sem exigir refresh da página.

## Atualizações, desativação e exclusão

No painel, selecione o **ID estável** e o **nome exibido** nas listas, marque `Free Fire normal`, `Free Fire MAX` ou ambos, informe a versão, o nome exato do arquivo e os caminhos. Um caminho pode ser um diretório ou um arquivo completo. Ao publicar novamente o mesmo ID, o artefato anterior é removido e substituído. O botão **Desativar** mantém o arquivo no histórico, mas impede downloads; o botão **Excluir** remove o item do manifesto e apaga o arquivo do armazenamento. Faça backup periódico de `storage/manifest.json`, `storage/payloads/` e `storage/events.ndjson`.

## Diagnóstico

```bash
sudo systemctl status menagerff-updater
sudo journalctl -u menagerff-updater -n 100 --no-pager
curl -fsS https://ffh4xcorporation.online/api/v1/health
curl -fsS https://ffh4xcorporation.online/api/v1/manifest | jq
```

Se o iOS não baixar um arquivo, confira primeiro HTTPS, `compatible_games`, `enabled`, `size` e `sha256`. Não desative a validação de hash para contornar erro de publicação.
