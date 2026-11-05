-- Characters that zone in close together must spawn for one another.
-- A client drops entity spawns that reach it while its loading screen is up,
-- and the server never repeats a spawn it believes was delivered: a character
-- spawned for a client that was still loading stayed invisible to it until one
-- of them left the area.

local zone = xi.zone.SOUTH_GUSTABERG
local spot = { x = -1.0, y = 0.0, z = -1.0 }

-- Every 0x00D the player holds about `other`, oldest first: its index and
-- whether it spawns (name and model) or despawns the character.
---@param player CClientEntityPair
---@param other CClientEntityPair
local function charPacketsAbout(player, other)
    local found = {}
    for _, packet in ipairs(player.packets:getIncoming()) do
        if packet.type == 0x00D then
            local data     = packet.data
            local uniqueNo = data[0x04] + data[0x05] * 256 + data[0x06] * 65536 + data[0x07] * 16777216
            if uniqueNo == other:getID() then
                local sendFlags = data[0x0A]
                table.insert(found,
                {
                    actIndex = data[0x08] + data[0x09] * 256,
                    spawns   = bit.band(sendFlags, 0x18) == 0x18, -- Name and Model
                    despawns = bit.band(sendFlags, 0x20) ~= 0,
                })
            end
        end
    end

    return found
end

---@param player CClientEntityPair
---@param other CClientEntityPair
local function assertSpawnedFor(player, other)
    local packets = charPacketsAbout(player, other)
    local packet  = packets[#packets]
    assert(packet ~= nil, string.format('%s never received a spawn of %s', player:getName(), other:getName()))

    local seen = {}
    for _, received in ipairs(packets) do
        table.insert(seen, string.format('[%d spawns=%s despawns=%s]', received.actIndex, tostring(received.spawns), tostring(received.despawns)))
    end

    local received = table.concat(seen, ' ')
    assert(packet.spawns, string.format('%s received no name and model for %s: %s', player:getName(), other:getName(), received))
    assert(not packet.despawns, string.format('%s was told to despawn %s: %s', player:getName(), other:getName(), received))
    assert(packet.actIndex == other:getTargID(), string.format('%s holds %s at index %d, not %d: %s',
        player:getName(), other:getName(), packet.actIndex, other:getTargID(), received))
end

local function spawnAtSpot()
    local player = xi.test.world:spawnPlayer({ zone = zone })
    player:gotoZone(zone, spot)
    return player
end

-- A few zone ticks, enough for each loaded client's own character pass.
local function letZoneRun()
    for _ = 1, 3 do
        xi.test.world:skipTime(1)
    end
end

describe('PC spawns after zoning', function()
    ---@type CClientEntityPair
    local first
    ---@type CClientEntityPair
    local second

    before_each(function()
        first  = spawnAtSpot()
        second = spawnAtSpot()

        -- Each zones in where the other already stands, so each has spawned the other,
        -- and both clients have taken every packet sent so far.
        first:gotoZone(zone, spot)
        letZoneRun()
        first.packets:clear()
        second.packets:clear()
    end)

    it('spawns a character at once for a client that has loaded the zone', function()
        second:gotoZone(zone, spot)

        assertSpawnedFor(first, second)
    end)

    it('despawns a character at its old index when it comes back at another', function()
        local oldIndex = second:getTargID()

        -- Both packets wait in the first client's queue, as they do for a client still
        -- working through its backlog.
        second:gotoZone(xi.zone.NORTH_GUSTABERG)
        spawnAtSpot() -- takes the index the second character left
        second:gotoZone(zone, spot)
        assert(second:getTargID() ~= oldIndex, 'the second character came back at its old index')

        local despawnedAtOldIndex = false
        for _, packet in ipairs(charPacketsAbout(first, second)) do
            if packet.actIndex == oldIndex and packet.despawns then
                despawnedAtOldIndex = true
            end
        end

        assert(despawnedAtOldIndex, string.format('%s was never despawned at its old index %d', second:getName(), oldIndex))
        assertSpawnedFor(first, second)
    end)

    it('spawns a newcomer for a client that was still loading once it has loaded', function()
        first:beginZoneIn(zone, spot)
        second:gotoZone(zone, spot)

        -- Whatever reached the first client during its loading screen is lost.
        first.packets:clear()
        first:finishLoadingZone()
        letZoneRun()

        assertSpawnedFor(first, second)
    end)

    it('spawns everyone already there for a client once it has loaded', function()
        second:beginZoneIn(zone, spot)
        second.packets:clear()

        second:finishLoadingZone()
        letZoneRun()

        assertSpawnedFor(second, first)
    end)

    it('spawns both for each other when they finish loading in either order', function()
        first:beginZoneIn(zone, spot)
        second:beginZoneIn(zone, spot)
        first.packets:clear()
        second.packets:clear()

        second:finishLoadingZone()
        letZoneRun()
        first:finishLoadingZone()
        letZoneRun()

        assertSpawnedFor(first, second)
        assertSpawnedFor(second, first)
    end)
end)
