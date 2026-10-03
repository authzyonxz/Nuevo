from __future__ import annotations

from dataclasses import dataclass
from typing import Final


@dataclass(frozen=True)
class FunctionDefinition:
    id: str
    group_id: str
    group_name: str
    name: str
    description: str


FUNCTIONS: Final[tuple[FunctionDefinition, ...]] = (
    FunctionDefinition("aim.high_hs", "aim_avatar", "AIM · AVATAR", "HS ALTO", "Ajuste de mira para a região superior."),
    FunctionDefinition("aim.neck_hs", "aim_avatar", "AIM · AVATAR", "HS PESCOÇO", "Ajuste de mira para a região do pescoço."),
    FunctionDefinition("aim.neck_antenna", "aim_avatar", "AIM · AVATAR", "HS PESCOÇO + ANTENA", "Combinação de mira para pescoço e antena."),
    FunctionDefinition("aim.chest_hs", "aim_avatar", "AIM · AVATAR", "HS PEITO", "Ajuste de mira para a região do peito."),
    FunctionDefinition("aim.cache_high_hs", "aim_cache_res", "AIM · CACHE_RES", "HS ALTO", "HS ACIMA DA CABEÇA DO INIMIGO."),
    FunctionDefinition("aim.cache_neck_hs", "aim_cache_res", "AIM · CACHE_RES", "HS PESCOÇO", "HS NO PESCOÇO DO INIMIGO."),
    FunctionDefinition("aim.cache_chest_hs", "aim_cache_res", "AIM · CACHE_RES", "HS PEITO", "HS NO PEITO DO INIMIGO."),
    FunctionDefinition("aim.cache_magic_bullet", "aim_cache_res", "AIM · CACHE_RES", "BALA MAGICA", "ACERTE BALAS MESMO A MIRA NÃO GRUDANDO."),
    FunctionDefinition("hologram.weapons", "hologram", "FUNÇÕES HOLOGRAMAS", "HOLOGRAMA ARMAS", "Habilita o holograma de armas."),
    # O ID antigo é preservado para não invalidar publicações existentes.
    FunctionDefinition("panel.ffh4x", "panel", "ESP", "ESP 3D + AIM SILIENT", "Painel ESP 3D combinado com AIM SILIENT."),
    FunctionDefinition("game.reset_guest", "game_config", "CONFIG DO JOGO", "RESET GUEST", "Restaura a configuração de convidado do jogo."),
)

FUNCTION_BY_ID: Final = {item.id: item for item in FUNCTIONS}
GROUPS: Final = {
    "aim_avatar": "AIM · AVATAR",
    "aim_cache_res": "AIM · CACHE_RES",
    "hologram": "FUNÇÕES HOLOGRAMAS",
    "panel": "ESP",
    "game_config": "CONFIG DO JOGO",
}

GROUP_DESCRIPTIONS: Final = {
    "aim": "Funções de assistência de mira.",
    "hologram": "Recursos visuais para armas e equipamentos.",
    "panel": "Recursos ESP e assistência visual.",
    "game_config": "Configurações gerais e ajustes do jogo.",
}


def validate_function_id(function_id: str) -> FunctionDefinition:
    try:
        return FUNCTION_BY_ID[function_id]
    except KeyError as exc:
        raise ValueError("Unknown function identifier") from exc
