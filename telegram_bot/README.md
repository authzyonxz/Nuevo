# Bot Telegram do 3105

O bot administra os arquivos publicados para cada função e gera pacotes `.3105` compatíveis com o `PatchPackageCodec` do aplicativo.

## Identificadores estáveis

| Grupo | Função | Identificador |
|---|---|---|
| FUNÇÕES AIM | HS PESCOÇO | `aim.neck_hs` |
| FUNÇÕES AIM | HS ALTO | `aim.high_hs` |
| FUNÇÕES AIM | HS PESCOÇO + ANTENA | `aim.neck_antenna` |
| FUNÇÕES HOLOGRAMAS | HOLOGRAMA ARMAS | `hologram.weapons` |
| PAINEL | PAINEL FFH4X | `panel.ffh4x` |

Esses IDs não mudam quando o nome exibido for traduzido ou alterado.

## Fluxo administrativo

1. `/start` abre os grupos.
2. O administrador escolhe o grupo e a função.
3. `Publicar/substituir .3105` recebe o arquivo.
4. O bot pergunta somente: Bundle ID, caminho relativo e se deseja senha.
5. O pacote é criado usando magic `3105PATCH`, plist binário, AES-GCM e PBKDF2-HMAC-SHA256.
6. A nova versão substitui a anterior e o manifesto é atualizado.
7. O administrador pode ativar, colocar em manutenção ou excluir o arquivo.

Quando uma função está em manutenção, a API bloqueia a entrega do `.3105` com HTTP 423.

## Configuração local

```bash
cd telegram_bot
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edite TELEGRAM_BOT_TOKEN e TELEGRAM_ADMIN_IDS
python run.py
```

A API fica em `http://localhost:8080` por padrão. Em produção, use HTTPS e defina `PUBLIC_BASE_URL` com a URL pública. O aplicativo iOS deverá consumir `/api/functions` e `/packages/<id>.3105`; o bot Telegram não deve ser usado como armazenamento direto pelo aplicativo.

## Segurança

- Nunca coloque o token do BotFather no repositório.
- Use somente IDs numéricos confiáveis em `TELEGRAM_ADMIN_IDS`.
- O arquivo `bot_data` contém os pacotes publicados e o manifesto; faça backup desse diretório.
- Se um pacote tiver senha, o aplicativo precisará receber essa senha em um fluxo separado para decodificá-lo.
