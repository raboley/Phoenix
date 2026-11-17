-----------------------------------
-- Self-scoped current-nation CP fixture: read or absolute set, never a toggle.
-- Stock !cp only reports a delta. Baseline/finally restoration needs readback.
-- Authority: LandSandBoat 8f2442cf getCP/addCP, immediately persisted char_points.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'iiss' }

commandObj.onTrigger = function(player, id, nation, nonce, value)
    if id ~= player:getID() or nation ~= player:getNation()
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 32 then
        player:printToPlayer('CP fixture refused: exact self, nation and nonce required.')
        return
    end
    if value ~= 'read' then
        local desired = tonumber(value)
        if desired == nil or desired ~= math.floor(desired) or desired < 0 or desired > 2147483647 then
            player:printToPlayer('CP fixture refused: bounded integer balance required.')
            return
        end
        player:addCP(desired - player:getCP())
    end
    player:printToPlayer(string.format('Fixture CP: %s id=%u nation=%u balance=%u.',
        nonce, id, nation, player:getCP()), xi.msg.channel.SYSTEM_3)
end

return commandObj
