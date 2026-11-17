-----------------------------------
-- func: spawnfixturemob <groupId> <groupZoneId> <level> <fixtureKey> <visibleName> [source|stationary|combat] [eastOffset 0-10] [unkillable 0|1] [facing 0|1|2]
-- desc: Creates one fresh dynamic mob fixture; refuses every existing key collision.
-- note: Private-server test support for FantasyAi; no drops and no respawn.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 1,
    parameters = 'iiisssiii'
}

local function printUsage(player, message)
    player:printToPlayer(message)
    player:printToPlayer(
        '!spawnfixturemob <groupId> <groupZoneId> <level> <fixtureKey> <visibleName> [source|stationary|combat] [eastOffset 0-10] [unkillable 0|1] [facing 0|1|2]'
    )
end

local function printReceipt(player, fixtureKey, mob)
    player:printToPlayer(string.format(
        'Fixture created: %s id=%i lv=%i HP=%i/%i.',
        fixtureKey,
        mob:getID(),
        mob:getMainLvl(),
        mob:getHP(),
        mob:getMaxHP()
    ), xi.msg.channel.SYSTEM_3)
end

local function configureFixture(mob, sourceCombat)
    -- Apply the acceptance contract only to the newly allocated entity.
    if not sourceCombat then
        mob:setSpellList(0)
        mob:setMobMod(xi.mobMod.SKILL_LIST, 0)
    end
    mob:setMobMod(xi.mobMod.EXP_BONUS, -100)
    mob:setDropID(0)
    mob:setMobMod(xi.mobMod.NO_DROPS, 1)
end

commandObj.onTrigger = function(player, groupId, groupZoneId, level, fixtureKey, visibleName, detectionProfile, eastOffset, unkillable, facing)
    if detectionProfile == 'source' then detectionProfile = nil end
    eastOffset = eastOffset or 0
    unkillable = unkillable or 0
    facing = facing or 0
    if eastOffset < 0 or eastOffset > 10 or eastOffset ~= math.floor(eastOffset) or
        (unkillable ~= 0 and unkillable ~= 1) or (facing ~= 0 and facing ~= 1 and facing ~= 2) then
        printUsage(player, 'Fixture placement or survival profile refused.')
        return
    end
    if detectionProfile ~= nil and detectionProfile ~= 'stationary' and detectionProfile ~= 'combat' then
        printUsage(player, 'Detection profile refused: only source, stationary or combat.')
        return
    end
    if detectionProfile == 'combat' and unkillable ~= 0 then
        printUsage(player, 'Source combat fixtures must remain killable.')
        return
    end
    if
        groupId == nil or
        groupZoneId == nil or
        level == nil or
        fixtureKey == nil or
        visibleName == nil
    then
        printUsage(player, 'Every fixture identity and source field is required.')
        return
    end

    if level < 1 or level > 255 then
        printUsage(player, 'Level must be between 1 and 255.')
        return
    end

    if #fixtureKey > 24 or not fixtureKey:match('^[%w_-]+$') then
        printUsage(player, 'fixtureKey must be 1-24 letters, numbers, underscores, or hyphens.')
        return
    end

    visibleName = visibleName:gsub('_', ' ')
    if #visibleName == 0 or #visibleName > 24 then
        printUsage(player, 'visibleName must be 1-24 characters; use underscores for spaces.')
        return
    end

    ---@type CZone?
    local zone = player:getZone()
    if not zone then
        printUsage(player, 'The issuing GM does not have a current zone.')
        return
    end

    -- A fixture faces the way its owner faces (0), back at its owner (1) or
    -- away from it (2). It always stands due east of the owner, so those are
    -- due west (rotation 128) and due east (0), however the owner is turned.
    local rotation = player:getRotPos()
    if facing == 1 then
        rotation = 128
    elseif facing == 2 then
        rotation = 0
    end

    local dynamicName = 'FantasyAi_Fixture_' .. fixtureKey
    if #zone:queryEntitiesByName('DE_' .. dynamicName) > 0 then
        -- The caller does not own an existing object merely because its key,
        -- source or location matches. Never adopt, reconfigure or remove it.
        player:printToPlayer('Fixture creation refused: key already exists.')
        return
    end

    local mob = zone:insertDynamicEntity({
        objtype = xi.objType.MOB,
        name = dynamicName,
        packetName = visibleName,
        x = player:getXPos() + eastOffset,
        y = player:getYPos(),
        z = player:getZPos(),
        rotation = rotation,
        groupId = groupId,
        groupZoneId = groupZoneId,
        minLevel = level,
        maxLevel = level,
        releaseIdOnDisappear = true,
        onMobDeath = function(mobArg, playerArg, optParams)
        end,
    })

    if not mob then
        printUsage(player, string.format(
            'Could not clone mob group %i from source zone %i.',
            groupId,
            groupZoneId
        ))
        return
    end

    -- The clone copies its source from the SQL mob tables. A server that loads
    -- the source zone from YAML has no such row and still returns a mob: a
    -- bare one that never aggroes. Release it and refuse rather than hand a
    -- test an inert monster; fixture_mobs.sql supplies the catalog's sources.
    if mob:getPool() == 0 then
        mob:spawn()
        DespawnMob(mob:getID())
        printUsage(player, string.format(
            'Mob group %i of zone %i has no SQL source on this server; deploy fixture_mobs.sql.',
            groupId,
            groupZoneId
        ))
        return
    end

    mob:setSpawn(
        player:getXPos() + eastOffset,
        player:getYPos(),
        player:getZPos(),
        rotation
    )
    -- Legacy lifecycle fixtures exercise melee only. The explicit combat
    -- profile keeps source spells and TP skills for real survival tests.
    -- Only rewards/roaming are suppressed; source stats and attacks stay.
    configureFixture(mob, detectionProfile == 'combat')
    mob:setUnkillable(unkillable == 1)
    -- Phoenix queues its first roam path synchronously during mob:spawn().
    -- Set SCRIPTED first or the path turns this sight ambusher away while
    -- the spawn-neutral window still prevents aggro.
    if detectionProfile == 'stationary' or detectionProfile == 'combat' then
        mob:setRoamFlags(bit.bor(mob:getRoamFlags(), xi.roamFlag.SCRIPTED))
    end
    mob:spawn()
    mob:setUnkillable(unkillable == 1)
    -- Retain the source declaration for exact fixture inspection.
    mob:setLocalVar('FantasyAiFixtureGroup', groupId)
    mob:setLocalVar('FantasyAiFixtureSourceZone', groupZoneId)
    printReceipt(player, fixtureKey, mob)
end

return commandObj
