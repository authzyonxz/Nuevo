# Bot Telegram do 3105

O bot administra os arquivos publicados para cada função. O fluxo atual publica arquivos normais (`.raw`) para substituição exata dentro do container do aplicativo; publicações `.3105` antigas continuam reconhecidas pelo manifesto.

## Identificadores estáveis

| Grupo | Função | Identificador |
|---|---|---|
| AIM · AVATAR | HS PESCOÇO | `aim.neck_hs` |
| AIM · AVATAR | HS ALTO | `aim.high_hs` |
| AIM · AVATAR | HS PESCOÇO + ANTENA | `aim.neck_antenna` |
| AIM · AVATAR | HS PEITO | `aim.chest_hs` |
| AIM · CACHE_RES | HS ALTO | `aim.cache_high_hs` |
| AIM · CACHE_RES | HS PESCOÇO | `aim.cache_neck_hs` |
| AIM · CACHE_RES | HS PEITO | `aim.cache_chest_hs` |
| FUNÇÕES HOLOGRAMAS | HOLOGRAMA ARMAS | `hologram.weapons` |
| ESP | ESP 3D + AIM SILIENT | `panel.ffh4x` |
| TEXTURA | TEXTURA - BOLSONARO | `textura.bolsonaro` |
| TEXTURA | TEXTURA - INSTAPLAYER 1 | `textura.instaplayer1` |
| TEXTURA | TEXTURA - INSTAPLAYER 2 | `textura.instaplayer2` |
| TEXTURA | TEXTURA - MANDELA | `textura.mandela` |

Esses IDs não mudam quando o nome exibido for traduzido ou alterado.

Os grupos também exibem uma descrição no painel do Telegram. O grupo `panel` continua usando o ID interno antigo para preservar compatibilidade com publicações existentes; apenas o nome visível foi alterado para **ESP**.

## Fluxo administrativo

1. `/start` abre os grupos.
2. O administrador escolhe o grupo e a função.
3. Para ESP, escolha `Publicar vários arquivos` e envie um ou mais arquivos, um por vez. Depois do último, toque em **Finalizar envio**; somente os arquivos recebidos nessa sessão serão publicados.
4. O bot pergunta o Bundle ID e, para cada arquivo, a pasta relativa de destino; o nome original de cada arquivo é preservado.
5. Os arquivos são publicados como `.raw`; o aplicativo baixa e aplica a quantidade informada no catálogo.
6. A nova versão substitui a anterior e o manifesto é atualizado, removendo arquivos antigos que não fazem parte da nova publicação.
7. O administrador pode ativar, colocar em manutenção ou excluir a publicação.

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
