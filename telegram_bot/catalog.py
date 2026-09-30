from __future__ import annotations

from dataclasses import dataclass
from typing import Final


@dataclass(frozen=True)
class FunctionDefinition:
    id: str
    group_id: str
    group_name: str
    name: str


FUNCTIONS: Final[tuple[FunctionDefinition, ...]] = (
    FunctionDefinition("aim.high_hs", "aim", "FUNÇÕES AIM", "HS ALTO"),
    FunctionDefinition("aim.neck_hs", "aim", "FUNÇÕES AIM", "HS PESCOÇO"),
    FunctionDefinition("aim.neck_antenna", "aim", "FUNÇÕES AIM", "HS PESCOÇO + ANTENA"),
    FunctionDefinition("aim.chest_hs", "aim", "FUNÇÕES AIM", "HS PEITO"),
    FunctionDefinition("hologram.weapons", "hologram", "FUNÇÕES HOLOGRAMAS", "HOLOGRAMA ARMAS"),
    FunctionDefinition("panel.ffh4x", "panel", "PAINEL", "PAINEL FFH4X"),
)

FUNCTION_BY_ID: Final = {item.id: item for item in FUNCTIONS}
GROUPS: Final = {
    "aim": "FUNÇÕES AIM",
    "hologram": "FUNÇÕES HOLOGRAMAS",
    "panel": "PAINEL",
}


def validate_function_id(function_id: str) -> FunctionDefinition:
    try:
        return FUNCTION_BY_ID[function_id]
    except KeyError as exc:
        raise ValueError("Unknown function identifier") from exc
