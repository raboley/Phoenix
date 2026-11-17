-----------------------------------
-- Read-only self-scoped GM authority receipt. Never grants privileges.
-- Phoenix has no LandSandBoat HTTP admin endpoint; verify the live actor,
-- rather than accidentally promoting a namesake on a different server.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 0, parameters = 'is' }

commandObj.onTrigger = function(player, id, nonce)
    if id ~= player:getID() or type(nonce) ~= 'string'
        or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16 then
        return
    end
    player:printToPlayer(string.format('Fixture GM: %s id=%u level=%u.',
        nonce, id, player:getGMLevel()), xi.msg.channel.SYSTEM_3)
end

return commandObj
