-----------------------------------
-- func: getengagementtarget <token> <actorName> <subjectServerId>
-- desc: prints the actor's and exact subject's authoritative battle targets
-- note: private-server observation authority for Fantasy World combat tests
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 1,
    parameters = 'ssi',
}

local function validToken(token)
    return
        token ~= nil and
        #token >= 1 and
        #token <= 32 and
        token:match('^[%w_-]+$') ~= nil
end

local function printReceipt(player, token, actor, subjectServerId, sample)
    local target = actor:getTarget()
    local subject = GetEntityByID(subjectServerId)
    local subjectTarget = subject and subject:getTarget() or nil
    local unexpectedAggroId = 0
    local zone = actor:getZone()
    if zone ~= nil then
        for _, mob in pairs(zone:getMobs()) do
            local mobTarget = mob:getTarget()
            if
                mob:getID() ~= subjectServerId and
                mobTarget ~= nil and
                mobTarget:getID() == actor:getID() and
                (unexpectedAggroId == 0 or mob:getID() < unexpectedAggroId)
            then
                unexpectedAggroId = mob:getID()
            end
        end
    end
    player:printToPlayer(string.format(
        '@FE|t=%s|s=%u|a=%u|x=%u|u=%u|v=%u',
        token,
        sample,
        actor:getID(),
        target and target:getID() or 0,
        subject and subject:getID() or 0,
        subjectTarget and subjectTarget:getID() or 0
    ), xi.msg.channel.SYSTEM_3)
    player:printToPlayer(string.format(
        '@FC|t=%s|s=%u|h=%u|j=%u|g=%u|m=%u|l=%u',
        token,
        sample,
        actor:getHP(),
        subject and subject:getHP() or 0,
        unexpectedAggroId,
        actor:getVisibleGMLevel(),
        actor:getMainLvl()
    ), xi.msg.channel.SYSTEM_3)
end

commandObj.onTrigger = function(player, token, actorName, subjectServerId)
    if
        not validToken(token) or
        actorName == nil or
        #actorName == 0 or
        subjectServerId == nil or
        subjectServerId <= 0
    then
        player:printToPlayer(
            'Usage: !getengagementtarget <token> <onlineActorName> <subjectServerId>'
        )
        return
    end

    local actor = GetPlayerByName(actorName)
    if actor == nil then
        player:printToPlayer(string.format(
            '@FENG|token=%s|error=actor_not_found',
            token
        ), xi.msg.channel.SYSTEM_3)
        return
    end

    -- getTarget() is the Lua projection of CBattleEntity::GetBattleTargetID.
    -- The companion @FC receipt reports exact current HP and scans the zone's
    -- authoritative mob battle targets for an unintended hostile targeting
    -- the actor. m/l record visible GM and main level so natural-aggro setup
    -- can distinguish suppressed detection from a genuine negative sample.
    -- Both receipts remain read-only and sample the same callback.
    -- Sample after packet-processing boundaries without locking or sleeping in
    -- the actor's Behavior. This command observes only; it never selects,
    -- engages, moves, or changes either entity's combat state.
    for sample, delayMs in ipairs({ 250, 750, 1500, 3000 }) do
        player:timer(delayMs, function(playerArg)
            printReceipt(playerArg, token, actor, subjectServerId, sample)
        end)
    end
end

return commandObj
