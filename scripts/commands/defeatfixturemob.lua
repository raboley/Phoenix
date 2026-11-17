-----------------------------------
-- func: defeatfixturemob <fixtureKey> <expectedMobId>
-- desc: Defeats only the exact named dynamic test fixture in the issuer's zone.
-- note: An explicit fixture end is not an operator combat or engagement command.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'si' }

commandObj.onTrigger = function(player, fixtureKey, expectedMobId)
    if type(fixtureKey) ~= 'string' or #fixtureKey == 0 or #fixtureKey > 24 or
        not fixtureKey:match('^[%w_-]+$') or
        type(expectedMobId) ~= 'number' or expectedMobId <= 0 or
        expectedMobId ~= math.floor(expectedMobId)
    then
        player:printToPlayer('!defeatfixturemob <fixtureKey> <expectedMobId>')
        return
    end
    local zone = player:getZone()
    if not zone then
        player:printToPlayer('Fixture defeat refused: issuer has no zone.')
        return
    end
    local matched = nil
    for _, entity in ipairs(zone:queryEntitiesByName('DE_FantasyAi_Fixture_' .. fixtureKey)) do
        if entity:isMob() and entity:getID() == expectedMobId then
            if matched then
                player:printToPlayer('Fixture defeat refused: ambiguous identity.')
                return
            end
            matched = entity
        end
    end
    if not matched then
        -- This is a refusal, not an absence proof: the caller may be in the
        -- wrong zone, or the id may now identify an unrelated entity.
        player:printToPlayer(string.format('Fixture defeat refused: %s id=%i not found.', fixtureKey, expectedMobId))
        return
    end
    if not matched:isSpawned() then
        player:printToPlayer('Fixture defeat refused: fixture is not spawned.')
        return
    end
    -- LSB 8f2442cf CLuaBaseEntity::setHP sets HP and lets normal mob AI
    -- produce death. No enmity or player attack is manufactured by this command.
    -- addHP clamps zero back to one while unkillable. Release only this
    -- exact owned monster's protection immediately before deliberate defeat.
    -- Player survival is untouched and remains owned by later cleanup.
    matched:setUnkillable(false)
    matched:setHP(0)
    -- A request receipt is not death proof: the caller must observe the exact corpse.
    player:printToPlayer(string.format('Fixture defeat requested: %s id=%i.', fixtureKey, expectedMobId), xi.msg.channel.SYSTEM_3)
end
return commandObj
