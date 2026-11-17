-----------------------------------
-- func: getbattletelemetry
-- desc: prints the selected mob's authoritative HP / MP / level telemetry
-- note: private-server diagnostic command for FantasyAi battle dashboard
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = '',
}

local function clean(value)
    return tostring(value or 'unknown')
        :gsub('|', '_')
        :gsub('%s+', '_')
        :gsub('[\r\n]', ' ')
end

local function safeNumber(entity, methodName)
    if not entity or not entity[methodName] then
        return 0
    end

    local ok, value = pcall(function()
        return entity[methodName](entity)
    end)

    return ok and tonumber(value) or 0
end

local function entityId(entity)
    return safeNumber(entity, 'getID')
end

local function printUsage(player, message)
    player:printToPlayer(message)
    player:printToPlayer('Usage: select a monster, then run !getbattletelemetry')
end

commandObj.onTrigger = function(player)
    local mob = player:getCursorTarget()

    if not mob or not mob:isMob() then
        printUsage(player, 'You must select a monster first.')
        return
    end

    -- Keep this line short.  FFXI chat messages have a practical length limit,
    -- and a truncated diagnostic line loses the exact MP fields.
    player:printToPlayer(string.format(
        '@FBP|id=%u|n=%s|lv=%u|hp=%d|mhp=%d|hpp=%u|mp=%d|mmp=%d|mpp=%u',
        entityId(mob),
        clean(mob:getName()),
        safeNumber(mob, 'getMainLvl'),
        safeNumber(mob, 'getHP'),
        safeNumber(mob, 'getMaxHP'),
        safeNumber(mob, 'getHPP'),
        safeNumber(mob, 'getMP'),
        safeNumber(mob, 'getMaxMP'),
        safeNumber(mob, 'getMPP')
    ))
end

if xi and xi.commands then
    xi.commands.getbattletelemetry = commandObj
    xi.commands.getbt = commandObj
end

return commandObj
