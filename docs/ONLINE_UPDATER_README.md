# MenagerFF Online Updater

Este pacote fornece uma **API de atualização de payloads** e um painel administrativo em `/configurar`. O servidor publica um manifesto versionado, mantém os arquivos fora do bundle do aplicativo, calcula SHA-256 e permite ativar ou desativar cada função sem uma nova IPA.

> O servidor deve ser usado somente para arquivos e aplicações que você está autorizado a distribuir. Não coloque credenciais, chaves privadas ou payloads reais no GitHub.

## Arquitetura

| Componente | Função |
|---|---|
| `server/index.mjs` | API Express, upload, catálogo e download |
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
  -F id=hs_pescoco \
  -F display_name='HS PESCOÇO' \
  -F version=2 \
  -F file_name='cache_res.exemplo' \
  -F $'target_paths=Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles\\nDocuments/contentcache/Optional/ios/gameassetbundles' \
  -F compatible_games='com.dts.freefireth,com.dts.freefiremax' \
  -F payload=@./cache_res.exemplo
```

O manifesto público está em `/api/v1/manifest`. O download de cada payload ocorre em `/api/v1/payloads/:id`. Os logs administrativos podem ser consultados em `/api/v1/admin/logs?limit=200` com `Authorization: Bearer <ADMIN_TOKEN>`. O servidor rejeita nomes com separadores de diretório, limita uploads a 250 MB e não expõe a listagem do armazenamento.

## Integração no iOS

Adicione `OnlinePayloadUpdater.swift` ao target principal no Xcode e troque `https://ffh4xcorporation.online` pelo domínio HTTPS definitivo. O método `download(id:bundleID:)` somente retorna dados quando o item está habilitado, é compatível com o bundle ID, possui o tamanho esperado e bate com o SHA-256 do manifesto.

A integração com `FreeFireModManager` deve ocorrer **antes da aplicação**: buscar o item remoto, receber `Data`, descriptografar ou reencapsular em memória e então usar as mesmas regras de caminho e o mesmo `PatchTransactionReceipt` já existentes. Não salve o payload em `Documents`, `Library` ou no bundle. Para o 144fps, mantenha a validação exclusiva para `com.dts.freefireth` e `Library/Preferences`; para texturas, aceite somente os dois caminhos exatos já definidos no projeto.

Exemplo de uso assíncrono:

```swift
Task {
    do {
        let (_, data) = try await OnlinePayloadUpdater.shared.download(
            id: "hs_pescoco",
            bundleID: "com.dts.freefireth",
            forceRefresh: true
        )
        // Entregar `data` diretamente ao fluxo de aplicação em memória.
    } catch {
        await MainActor.run { statusMessage = error.localizedDescription }
    }
}
```

## Monitoramento e logs

Os eventos são armazenados em `storage/events.ndjson`, um registro JSON por linha. O painel mostra os 200 eventos mais recentes e registra health-checks, consultas ao manifesto, downloads de payloads, publicações, alterações de status e tentativas de autenticação inválidas. O botão **Atualizar monitoramento** executa um novo teste contra `/api/v1/health` e recarrega os logs sem exigir refresh da página.

## Atualizações e rollback

Para atualizar, publique novamente o mesmo `id` com uma versão maior. Para rollback, publique o artefato anterior com versão posterior ou desative o item no painel e distribua uma versão corrigida. Faça backup periódico de `storage/manifest.json` e `storage/payloads/`.

## Diagnóstico

```bash
sudo systemctl status menagerff-updater
sudo journalctl -u menagerff-updater -n 100 --no-pager
curl -fsS https://ffh4xcorporation.online/api/v1/health
curl -fsS https://ffh4xcorporation.online/api/v1/manifest | jq
```

Se o iOS não baixar um arquivo, confira primeiro HTTPS, `compatible_games`, `enabled`, `size` e `sha256`. Não desative a validação de hash para contornar erro de publicação.
