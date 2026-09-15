/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#include "login/login_helpers.h"

#include <catch2/catch_test_macros.hpp>

TEST_CASE("character creation stays within the client login identity range", "[login][character]")
{
    REQUIRE(loginHelpers::nextClientCharacterId(0, 1) == 1);
    REQUIRE(loginHelpers::nextClientCharacterId(1, 1) == 2);
    REQUIRE(loginHelpers::nextClientCharacterId(2, 0x700000) == 0x700000);
    REQUIRE(loginHelpers::nextClientCharacterId(0x700000, 0x700000) == 0x700001);
    REQUIRE(loginHelpers::nextClientCharacterId(loginHelpers::MaxClientCharacterId - 1, 1) == loginHelpers::MaxClientCharacterId);
    REQUIRE_FALSE(loginHelpers::nextClientCharacterId(loginHelpers::MaxClientCharacterId, 1).has_value());
    REQUIRE_FALSE(loginHelpers::nextClientCharacterId(loginHelpers::MaxClientCharacterId + 1, 1).has_value());
    REQUIRE_FALSE(loginHelpers::nextClientCharacterId(0, 0).has_value());
    REQUIRE_FALSE(loginHelpers::nextClientCharacterId(0, loginHelpers::MaxClientCharacterId + 1).has_value());
}

TEST_CASE("new character lobby entries contain the data required by the client", "[login][character]")
{
    char_mini character{};
    std::memcpy(character.m_name, "Erk", 4);
    character.m_mjob      = 3;
    character.m_zone      = xi::ZoneId::PortBastok;
    character.m_nation    = 1;
    character.m_look.race = 2;
    character.m_look.face = 4;
    character.m_look.size = 1;

    const auto info = loginHelpers::makeNewCharacterInfo(character, 0x700001, "Phoenix");

    REQUIRE(std::string(info.character_name) == "Erk");
    REQUIRE(std::string(info.world_name) == "Phoenix");
    REQUIRE(info.ffxi_id == 0x700001);
    REQUIRE(info.ffxi_id_world == 1);
    REQUIRE(info.ffxi_id_world_tbl == 0x70);
    REQUIRE(info.status == 1);
    REQUIRE(info.character_info.mon_no == 2);
    REQUIRE(info.character_info.mjob_no == 3);
    REQUIRE(info.character_info.mjob_level == 1);
    REQUIRE(info.character_info.town_no == 1);
    REQUIRE(info.character_info.zone_no == static_cast<uint8>(xi::ZoneId::PortBastok));
    REQUIRE(info.character_info.face_no == 4);
    REQUIRE(info.character_info.hair_no == 4);
    REQUIRE(info.character_info.size == 1);
    REQUIRE(info.character_info.GrapIDTbl[0] == 4);
}
