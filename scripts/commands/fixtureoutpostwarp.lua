-----------------------------------
-- Self-scoped outpost-warp fixture: read, or unlock one region's warp for the
-- character's own nation, as delivering that region's supplies does
-- (conquest.lua overseerOnEventFinish: player:addTeleport(nation, region + 5)).
-- The server has no call that takes a warp away again, so there is no lock.
-- The receipt is the server's own mask afterwards: getTeleport(nation), bit
-- region + 5 set for each unlocked warp.
-- 'newday' clears the day stamp of the character's last supply run
-- (conquest.lua suppliesAvailableBitmask: a gate guard refuses a run on the
-- Vana'diel day the last one started), so a test character can start one
-- today; the region it took and any supplies it carries are left alone.
-- Operations: read; unlock; newday.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'isis' }

commandObj.onTrigger = function(player, id, nonce, region, operation)
    if id ~= player:getID()
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or region == nil or region < 0 or region > 18 then
        player:printToPlayer('Outpost-warp fixture refused: exact self, nonce and region required.')
        return
    end
    local nation = player:getNation()
    if operation == 'unlock' then
        if not player:hasTeleport(nation, region + 5) then
            player:addTeleport(nation, region + 5)
        end
    elseif operation == 'newday' then
        player:setCharVar('supplyQuest_started', 0)
    elseif operation ~= 'read' then
        player:printToPlayer('Outpost-warp fixture refused: unlock, newday or read required.')
        return
    end
    player:printToPlayer(string.format('Fixture Outpost Warp: %s id=%u region=%u mask=%u.',
        nonce, id, region, player:getTeleport(nation)), xi.msg.channel.SYSTEM_3)
end

return commandObj
