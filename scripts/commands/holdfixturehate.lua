-----------------------------------
-- func: holdfixturehate <fixtureKey> <expectedMobId> <holderName>
-- desc: Pins only the exact named dynamic test fixture's hate on one player
--       in the issuer's zone, clearing everyone else's enmity on it.
-- note: A test arrangement that needs "the monster fights the leader, not the
--       member who also hit it". Enmity is otherwise emergent: whoever dealt
--       or took more wins, which a story cannot hold still.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'sis' }

commandObj.onTrigger = function(player, fixtureKey, expectedMobId, holderName)
    if type(fixtureKey) ~= 'string' or #fixtureKey == 0 or #fixtureKey > 24 or
        not fixtureKey:match('^[%w_-]+$') or
        type(expectedMobId) ~= 'number' or expectedMobId <= 0 or
        expectedMobId ~= math.floor(expectedMobId) or
        type(holderName) ~= 'string' or #holderName == 0
    then
        player:printToPlayer('!holdfixturehate <fixtureKey> <expectedMobId> <holderName>')
        return
    end
    local zone = player:getZone()
    if not zone then
        player:printToPlayer('Fixture hate refused: issuer has no zone.')
        return
    end
    local matched = nil
    for _, entity in ipairs(zone:queryEntitiesByName('DE_FantasyAi_Fixture_' .. fixtureKey)) do
        if entity:isMob() and entity:getID() == expectedMobId then
            if matched then
                player:printToPlayer(string.format('Fixture hate refused: %s id=%i ambiguous identity.', fixtureKey, expectedMobId))
                return
            end
            matched = entity
        end
    end
    if not matched or not matched:isSpawned() then
        player:printToPlayer(string.format('Fixture hate refused: %s id=%i not found.', fixtureKey, expectedMobId))
        return
    end
    local holder = nil
    for _, candidate in pairs(zone:getPlayers()) do
        if string.lower(candidate:getName()) == string.lower(holderName) then
            holder = candidate
        end
    end
    if not holder then
        player:printToPlayer(string.format('Fixture hate refused: %s id=%i holder %s not in zone.', fixtureKey, expectedMobId, holderName))
        return
    end
    -- LSB enmity_container: the target is the highest CE+VE, both capped at
    -- 30000. Zeroing every other owner and capping the holder makes the next
    -- AI tick choose the holder, and a level-one attacker cannot out-hate it
    -- inside a story's window.
    for _, row in ipairs(matched:getEnmityList() or {}) do
        if row.entity:getID() ~= holder:getID() then
            matched:setCE(row.entity, 0)
            matched:setVE(row.entity, 0)
        end
    end
    matched:setCE(holder, 30000)
    matched:setVE(holder, 30000)
    matched:updateEnmity(holder)
    player:printToPlayer(string.format('Fixture hate held: %s id=%i on %s.', fixtureKey, expectedMobId, holder:getName()), xi.msg.channel.SYSTEM_3)
end
return commandObj
