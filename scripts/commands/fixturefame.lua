-----------------------------------
-- Self-scoped fame fixture: read or absolute set, never a blind change.
-- Stock !setfamelevel sets a rank and reports it, but never what the server
-- holds afterwards, and it cannot put back points between two ranks. A quest
-- offered only from a fame rank needs that rank set, and the original points
-- restored when the scenario ends. The receipt is the server's own getFame
-- afterwards.
-- Areas: xi.fameArea (0 San d'Oria, 1 Bastok, 2 Windurst, ...). Jeuno and
-- Selbina/Rabao are worked out from nation fame and refused.
-- Points: 0 to 2500, the server's stored scale (xi.data.fame.rankPoints
-- gives where each rank starts).
-- Authority: LandSandBoat setFame/getFame, persisted char_profile fame.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 1,
    parameters = 'isis',
}

commandObj.onTrigger = function(player, id, nonce, area, value)
    if
        id ~= player:getID() or
        type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16 or
        area == nil or area < 0 or area > 15 or
        area == xi.fameArea.JEUNO or area == xi.fameArea.SELBINA_RABAO
    then
        player:printToPlayer('Fame fixture refused: exact self, nonce and a stored fame area required.')
        return
    end

    if value ~= 'read' then
        local points = tonumber(value)
        if points == nil or points < 0 or points > 2500 or points ~= math.floor(points) then
            player:printToPlayer('Fame fixture refused: points 0 to 2500 or read required.')
            return
        end

        player:setFame(area, points)
    end

    player:printToPlayer(string.format('Fixture Fame: %s id=%u area=%u points=%u.',
        nonce, id, area, player:getFame(area)), xi.msg.channel.SYSTEM_3)
end

return commandObj
