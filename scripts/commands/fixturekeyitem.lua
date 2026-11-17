-----------------------------------
-- Self-scoped key-item fixture: read or absolute set, never a blind toggle.
-- Stock !addkeyitem/!delkeyitem only echo the request, and no stock command
-- reports or clears the "seen" flag the server keeps per key item, which a
-- quest can branch on (Groceries: Zelman answers by seenKeyItem(TAMIS_NOTE)).
-- The receipt is the server's own state afterwards: held + 2 * seen.
-- Operations: read; held (add it); absent (remove it and clear its seen flag,
-- as for a key item the character never had); unseen (clear the seen flag and
-- leave possession alone).
-- Authority: LandSandBoat addKeyItem/delKeyItem/hasKeyItem/seenKeyItem/
-- unseenKeyItem. Each mutation sends the client a 0x055 for the table.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'isis' }

commandObj.onTrigger = function(player, id, nonce, keyItemId, operation)
    if id ~= player:getID()
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or keyItemId == nil or keyItemId < 1 or keyItemId > 4095 then
        player:printToPlayer('Key-item fixture refused: exact self, nonce and key item required.')
        return
    end
    if operation == 'held' then
        if not player:hasKeyItem(keyItemId) then
            player:addKeyItem(keyItemId)
        end
    elseif operation == 'absent' then
        if player:hasKeyItem(keyItemId) then
            player:delKeyItem(keyItemId)
        end
        player:unseenKeyItem(keyItemId)
    elseif operation == 'unseen' then
        player:unseenKeyItem(keyItemId)
    elseif operation ~= 'read' then
        player:printToPlayer('Key-item fixture refused: held, absent, unseen or read required.')
        return
    end
    local state = (player:hasKeyItem(keyItemId) and 1 or 0) + (player:seenKeyItem(keyItemId) and 2 or 0)
    player:printToPlayer(string.format('Fixture Key Item: %s id=%u item=%u state=%u.',
        nonce, id, keyItemId, state), xi.msg.channel.SYSTEM_3)
end

return commandObj
