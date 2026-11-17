-----------------------------------
-- func: setfixtureunkillable <player> <serverId> <zoneId> <0|1>
-- desc: Idempotent, identity-fenced survival setup; never targets the cursor.
-- authority: LandSandBoat 8f2442cf CBattleEntity::addHP / setUnkillable.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'siii' }

local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == math.floor(value)
        and value >= minimum and value <= maximum
end

commandObj.onTrigger = function(player, name, id, zoneId, enabled)
    local function refuse()
        player:printToPlayer('Unkillable fixture refused: exact living same-zone player and state required.')
    end
    if type(name) ~= 'string' or not name:match('^[A-Za-z]+$')
        or not integer(id, 1, 4294967295)
        or not integer(zoneId, 1, 65535)
        or not integer(enabled, 0, 1) then
        refuse()
        return
    end
    local target = GetPlayerByName(name)
    if target == nil or not target:isPC() or not target:isAlive()
        or target:getID() ~= id or target:getZoneID() ~= zoneId
        or player:getZoneID() ~= zoneId then
        refuse()
        return
    end
    -- No toggle, HP override, effect, enmity, target, or combat-stat mutation.
    -- The caller owns setup and restore; this receipt does not invent a
    -- previous-state observation (the native Lua API has no getter).
    target:setUnkillable(enabled == 1)
    player:printToPlayer(string.format(
        'Unkillable fixture applied: %s id=%u zone=%u enabled=%u.',
        target:getName(), id, zoneId, enabled
    ), xi.msg.channel.SYSTEM_3)
end

return commandObj
