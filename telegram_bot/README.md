# Bot Telegram do 3105

O bot administra os arquivos publicados para cada função. O fluxo atual publica arquivos normais (`.raw`) para substituição exata dentro do container do aplicativo; publicações `.3105` antigas continuam reconhecidas pelo manifesto.

## Identificadores estáveis

| Grupo | Função | Identificador |
|---|---|---|
| FUNÇÕES AIM | HS PESCOÇO | `aim.neck_hs` |
| FUNÇÕES AIM | HS ALTO | `aim.high_hs` |
| FUNÇÕES AIM | HS PESCOÇO + ANTENA | `aim.neck_antenna` |
| FUNÇÕES AIM | HS PEITO | `aim.chest_hs` |
| FUNÇÕES AIM · Cache_res | HS ALTO | `aim.cache_high_hs` |
| FUNÇÕES AIM · Cache_res | HS PESCOÇO | `aim.cache_neck_hs` |
| FUNÇÕES AIM · Cache_res | HS PEITO | `aim.cache_chest_hs` |
| FUNÇÕES AIM · Cache_res | BALA MAGICA | `aim.cache_magic_bullet` |
| FUNÇÕES HOLOGRAMAS | HOLOGRAMA ARMAS | `hologram.weapons` |
| ESP | ESP 3D + AIM SILIENT | `panel.ffh4x` |
| CONFIG DO JOGO | RESET GUEST | `game.reset_guest` |

Esses IDs não mudam quando o nome exibido for traduzido ou alterado.

Os grupos também exibem uma descrição no painel do Telegram. O grupo `panel` continua usando o ID interno antigo para preservar compatibilidade com publicações existentes; apenas o nome visível foi alterado para **ESP**.

## Fluxo administrativo

1. `/start` abre os grupos.
2. O administrador escolhe o grupo e a função.
3. `Publicar/substituir arquivo normal` recebe o arquivo.
4. O bot pergunta o Bundle ID; o nome original do arquivo é preservado.
5. O arquivo normal é publicado como `.raw`; o aplicativo procura o mesmo nome exato dentro do container do app.
6. A nova versão substitui a anterior e o manifesto é atualizado.
7. O administrador pode ativar, colocar em manutenção ou excluir o arquivo.

Quando uma função está em manutenção, a API bloqueia a entrega do pacote com HTTP 423.

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

A API fica em `http://localhost:8080` por padrão. Em produção, use HTTPS e defina `PUBLIC_BASE_URL` com a URL pública. O aplicativo iOS deverá consumir `/api/functions` e o `package_url` retornado; o bot Telegram não deve ser usado como armazenamento direto pelo aplicativo.

## Segurança

- Nunca coloque o token do BotFather no repositório.
- Use somente IDs numéricos confiáveis em `TELEGRAM_ADMIN_IDS`.
- O arquivo `bot_data` contém os pacotes publicados e o manifesto; faça backup desse diretório.
- Publicações raw não usam senha; publicações `.3105` antigas continuam identificadas pelo manifesto para compatibilidade.
