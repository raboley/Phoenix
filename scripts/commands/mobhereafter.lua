-----------------------------------
-- func: mobhereafter <delayMs> <mobId> <actorName>
-- desc: Moves a stock mob to the issuing GM's captured position after a bounded
--       delay, then makes it acquire the named actor as hostile.
-- note: Lets a measured client command begin before the add is staged. The
--       acquisition is explicit rather than left to a timing-dependent natural
--       sight check: a stock mob teleported onto a route can miss its sight
--       window entirely while the actor walks past, which produced a fixture
--       that silently never preempted anything.
-----------------------------------
---@type TCommand
local commandObj = {}

-- A delayed fixture can be scheduled again before the prior 15-second
-- restoration callback runs. Keep one generation-owned lease per stock mob so
-- a stale callback can never restore over the newer placement. The first
-- generation retains the database home; successors inherit that same home
-- rather than accidentally treating the prior temporary home as canonical.
local nextPlacementGeneration = 0
local placementLeases = {}

commandObj.cmdprops =
{
    permission = 1,
    parameters = 'iis',
}

local function printUsage(player, message)
    player:printToPlayer(message)
    player:printToPlayer('!mobhereafter <250-5000 delayMs> <mobId> <actorName>')
end

local function acquirePlacementLease(mobId, observedSpawn)
    nextPlacementGeneration = nextPlacementGeneration + 1
    local previous = placementLeases[mobId]
    local originalSpawn = observedSpawn
    if previous ~= nil then
        originalSpawn = previous.originalSpawn
    end
    placementLeases[mobId] =
    {
        generation = nextPlacementGeneration,
        originalSpawn = originalSpawn,
    }
    return nextPlacementGeneration
end

local function restorePlacementIfOwned(player, mobId, generation, restoreCurrentPosition)
    local lease = placementLeases[mobId]
    if lease == nil or lease.generation ~= generation then
        return false
    end

    local mob = GetMobByID(mobId)
    if mob == nil then
        -- Retain the canonical home for a later generation rather than losing
        -- it merely because the actor disappeared during this callback.
        return false
    end

    local originalSpawn = lease.originalSpawn
    mob:setSpawn(
        originalSpawn.x,
        originalSpawn.y,
        originalSpawn.z,
        originalSpawn.rot
    )
    if restoreCurrentPosition then
        mob:setPos(
            originalSpawn.x,
            originalSpawn.y,
            originalSpawn.z,
            originalSpawn.rot,
            mob:getZoneID()
        )
    end
    placementLeases[mobId] = nil
    player:printToPlayer(string.format(
        '@FMHR|m=%u|x=%.3f|y=%.3f|z=%.3f|r=%u',
        mob:getID(),
        originalSpawn.x,
        originalSpawn.y,
        originalSpawn.z,
        originalSpawn.rot
    ), xi.msg.channel.SYSTEM_3)
    return true
end

commandObj.onTrigger = function(player, delayMs, mobId, actorName)
    if delayMs == nil or delayMs < 250 or delayMs > 5000 then
        printUsage(player, 'Delay must be between 250 and 5000 milliseconds.')
        return
    end

    if mobId == nil or mobId <= 0 then
        printUsage(player, 'Mob ID must be a positive server ID.')
        return
    end

    if actorName == nil or actorName == '' then
        printUsage(player, 'Actor name is required so the add can acquire an exact target.')
        return
    end

    local zoneId = player:getZoneID()
    local x = player:getXPos()
    local y = player:getYPos()
    local z = player:getZPos()
    local rotation = player:getRotPos()

    player:printToPlayer(string.format(
        '@FMHS|m=%u|d=%u|z=%u|a=%s',
        mobId,
        delayMs,
        zoneId,
        actorName
    ), xi.msg.channel.SYSTEM_3)

    player:timer(delayMs, function(playerArg)
        local mob = GetMobByID(mobId)
        if mob == nil or mob:getZoneID() ~= zoneId then
            playerArg:printToPlayer(string.format(
                '@FMH|m=%u|e=mob_not_in_zone',
                mobId
            ), xi.msg.channel.SYSTEM_3)
            return
        end

        if not mob:isSpawned() then
            SpawnMob(mobId)
        end

        -- `setPos` alone leaves a stock mob's database home unchanged. A mob
        -- staged hundreds of yalms from that home can therefore lose the
        -- natural-aggro race to LandSandBoat's far-from-home despawn path.
        -- Give the delayed fixture a temporary, scoped home at the captured
        -- position, then restore the stock home after the aggro oracle has had
        -- ample time to observe the encounter.
        local placementGeneration = acquirePlacementLease(mobId, mob:getSpawnPos())
        mob:setSpawn(x, y, z, rotation)
        mob:setPos(x, y, z, rotation, zoneId)

        -- Placement alone only gives the mob an opportunity to notice the
        -- actor. Acquire it explicitly through the same server API the stock
        -- `!provokeall` command uses (`mob:updateEnmity`), so the fixture
        -- proves an unexpected hostile actually targeted the actor instead of
        -- depending on a sight check that can be missed while the actor walks
        -- past.
        local actor = GetPlayerByName(actorName)
        if actor == nil then
            restorePlacementIfOwned(playerArg, mobId, placementGeneration, true)
            playerArg:printToPlayer(string.format(
                '@FMH|m=%u|e=actor_not_found|a=%s',
                mobId,
                actorName
            ), xi.msg.channel.SYSTEM_3)
            return
        end

        if actor:getZoneID() ~= zoneId then
            restorePlacementIfOwned(playerArg, mobId, placementGeneration, true)
            playerArg:printToPlayer(string.format(
                '@FMH|m=%u|e=actor_wrong_zone|a=%s|az=%u|z=%u',
                mobId,
                actorName,
                actor:getZoneID(),
                zoneId
            ), xi.msg.channel.SYSTEM_3)
            return
        end

        mob:updateEnmity(actor)

        -- Native FFXI chat truncates long system lines. Keep the terminal
        -- authority receipt to only the fields the typed consumer requires;
        -- placement is independently proven through the entity projection.
        playerArg:printToPlayer(string.format(
            '@FMH|m=%u|a=%s|ai=%u|e=enmity_requested',
            mobId,
            actorName,
            actor:getID()
        ), xi.msg.channel.SYSTEM_3)

        playerArg:timer(15000, function(restorePlayer)
            -- Preserve an active encounter while restoring its stock home.
            -- Refusal paths above restore both home and current position. A
            -- superseded generation is intentionally a no-op.
            restorePlacementIfOwned(restorePlayer, mobId, placementGeneration, false)
        end)
    end)
end

return commandObj
