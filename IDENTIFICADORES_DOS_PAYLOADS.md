# Identificadores dos payloads — IPA unificada

A IPA unificada usa o bundle escolhido na tela inicial em todas as operações. Para disponibilizar uma função aos dois jogos, o item correspondente no manifesto remoto deve declarar `com.dts.freefireth` e `com.dts.freefiremax` em `compatible_games` e possuir caminhos válidos para ambos.

| Área | Nome exibido | ID do payload no site |
| --- | --- | --- |
| ESP | AIMBOT + ESP | `teste_patch` |
| Aims · Avatar | HS ALTO | `aimbot_hs_alto` |
| Aims · Avatar | HS PESCOÇO | `aimbot_hs_pescoco` |
| Aims · Avatar | HS ALTO + PESCOÇO | `aimbot_hs_alto_pescoco` |
| Aims · Cache | HS ALTO | `cache_hs_alto` |
| Aims · Cache | HS PESCOÇO | `cache_hs_pescoco` |
| Aims · Cache | HS PEITO | `cache_hs_peito` |
| Aims · Cache | BALA MÁGICA | `cache_bala_magica` |
| Chams · Holograma Armas | AMARELO | `chams_amarelo` |
| Chams · Holograma Armas | VERMELHO | `chams_vermelho` |
| Chams · Holograma Armas | ROXO | `chams_roxo` |
| Chams · Holograma Armas | LARANJA | `chams_laranja` |
| Chams · Holograma Armas | PRETO | `chams_preto` |
| Chams · Holograma Armas | BRANCO | `chams_branco` |
| Texturas | Skin Instaplayer | `textura_instaplayer` |
| Texturas | Skin Mandela | `textura_mandela` |
| Texturas | Skin RuokFF | `textura_ruokff` |
| Ajustes | Forçar 120/144 FPS | `fps_144` |

Os seis IDs Chams devem ser publicados no endpoint do manifesto antes do uso. O app valida `enabled`, `compatible_games`, tamanho e SHA-256 antes de aplicar cada arquivo.

Os payloads de Texturas e FPS permanecem protegidos localmente no binário. Os demais IDs são usados pelo atualizador online para localizar e baixar o arquivo publicado.
