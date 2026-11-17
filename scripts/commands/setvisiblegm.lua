-----------------------------------
-- func: setvisiblegm <level> <optional player>
-- desc: Sets one GM's visible name/icon level deterministically for live tests.
-- note: This does not grant GM permission; the target's persisted gmlevel owns that.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 1,
    parameters = 'is',
}

local function printUsage(player, message)
    player:printToPlayer(message)
    player:printToPlayer('!setvisiblegm <0-7> (onlinePlayer)')
end

commandObj.onTrigger = function(player, level, targetName)
    if level == nil or level < 0 or level > 7 then
        printUsage(player, 'Visible GM level must be between 0 and 7.')
        return
    end

    local target = player
    if targetName ~= nil then
        target = GetPlayerByName(targetName)
        if target == nil then
            printUsage(player, string.format(
                'Player named "%s" is not online.',
                targetName
            ))
            return
        end
    end

    target:setVisibleGMLevel(level)
    player:printToPlayer(string.format(
        'Visible GM fixture player=%s level=%u.',
        target:getName(),
        level
    ), xi.msg.channel.SYSTEM_3)
end

return commandObj
