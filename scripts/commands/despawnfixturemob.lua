-----------------------------------
-- func: despawnfixturemob <fixtureKey> <expectedMobId>
-- desc: Removes only the exact named dynamic test fixture in the issuer's zone.
-- note: Stock despawnmob cannot fence a recycled id to fixture ownership.
-----------------------------------
---@type TCommand
-- Compact machine receipt keeps all exact authority in one native chat row.
-- Human prose wrapped before the zone at the normal 800-pixel client width.
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'si' }

commandObj.onTrigger = function(player, fixtureKey, expectedMobId)
    if type(fixtureKey) ~= 'string' or #fixtureKey == 0 or #fixtureKey > 24 or
        not fixtureKey:match('^[%w_-]+$') or
        type(expectedMobId) ~= 'number' or expectedMobId <= 0 or
        expectedMobId ~= math.floor(expectedMobId)
    then
        player:printToPlayer('!despawnfixturemob <fixtureKey> <expectedMobId>')
        return
    end
    local zone = player:getZone()
    if not zone then
        player:printToPlayer('Fixture cleanup refused: issuer has no zone.')
        return
    end
    local matched = nil
    for _, entity in ipairs(zone:queryEntitiesByName('DE_FantasyAi_Fixture_' .. fixtureKey)) do
        if entity:getID() == expectedMobId then
            if not entity:isMob() then
                player:printToPlayer('Fixture cleanup refused: identity is not a mob.')
                return
            end
            if matched then
                player:printToPlayer('Fixture cleanup refused: ambiguous identity.')
                return
            end
            matched = entity
        end
    end
    if not matched then
        -- Natural death may have released the dynamic fixture before teardown.
        -- This proves only this key/ID's absence in this zone, not ownership.
        -- The caller must retain its exact spawn receipt and match the zone.
        -- Never despawn an unrelated replacement that happens to reuse the ID.
        player:printToPlayer(string.format('@FCLEAN %s %i %i', fixtureKey, expectedMobId, player:getZoneID()), xi.msg.channel.SYSTEM_3)
        return
    end
    if matched:isSpawned() then
        DespawnMob(expectedMobId)
    end
    -- The request is not completion. Re-query the exact ownership key on the
    -- server after despawn processing; never retain a dynamic entity pointer
    -- across a timer because disappearance can release it and recycle its ID.
    player:printToPlayer(string.format('Fixture cleanup requested: %s id=%i.', fixtureKey, expectedMobId), xi.msg.channel.SYSTEM_3)
    local zoneId = player:getZoneID()
    local function confirm(issuer, remaining)
        if issuer:getZoneID() ~= zoneId then
            return
        end
        local currentZone = issuer:getZone()
        if not currentZone then
            return
        end
        for _, entity in ipairs(currentZone:queryEntitiesByName('DE_FantasyAi_Fixture_' .. fixtureKey)) do
            if entity:getID() == expectedMobId and (not entity:isMob() or entity:isSpawned()) then
                if remaining > 0 then
                    issuer:timer(250, function(nextIssuer) confirm(nextIssuer, remaining - 1) end)
                end
                return
            end
        end
        issuer:printToPlayer(string.format('@FCLEAN %s %i %i', fixtureKey, expectedMobId, zoneId), xi.msg.channel.SYSTEM_3)
    end
    player:timer(250, function(issuer) confirm(issuer, 39) end)
end
return commandObj
