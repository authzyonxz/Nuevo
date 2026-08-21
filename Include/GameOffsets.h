#ifndef GAME_OFFSETS_H
#define GAME_OFFSETS_H

#include <stdint.h>

// Offsets extraídas do SDK do Free Fire Max (com.dts.freefireth)
struct GameOffsets {
    static constexpr uintptr_t GetHp = 0x54D2DF8;
    static constexpr uintptr_t Curent_Match = 0x59C4A38;
    static constexpr uintptr_t GetLocalPlayer = 0x30792AC;
    static constexpr uintptr_t GetHeadPositions = 0x54F252C;
    static constexpr uintptr_t get_position = 0x92CB4DC;
    static constexpr uintptr_t Component_GetTransform = 0x92B91C4;
    static constexpr uintptr_t get_camera = 0x915E9E4;
    static constexpr uintptr_t WorldToViewpoint = 0x925ED78;
    static constexpr uintptr_t get_isVisible = 0x5464DC4;
    static constexpr uintptr_t get_isLocalTeam = 0x547F138;
    static constexpr uintptr_t get_IsDieing = 0x544559C;
    static constexpr uintptr_t get_MaxHP = 0x54D2F08;
};

#endif
