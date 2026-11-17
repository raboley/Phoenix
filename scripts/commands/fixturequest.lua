-----------------------------------
-- Self-scoped quest-status fixture: read or absolute set, never a blind toggle.
-- Stock !addquest/!delquest only echo the request and never report the
-- resulting status, so a setup that silently did not apply looks identical to
-- one that did. The receipt is the server's own getQuestStatus afterwards.
-- Status: 0 available, 1 accepted, 2 completed (xi.questStatus).
-- Authority: LandSandBoat addQuest/delQuest/completeQuest, persisted chars.quests.
-- A set also clears every variable the quest keeps, the way the server's own
-- quest cleanup does (interaction/container.lua cleanup: clearVarsWithPrefix).
-- Otherwise a quest set back to available keeps the progress of an earlier
-- run (Prog), and a repeatable quest keeps the mustZone that makes its NPC
-- ignore trades until the player changes zone.
-- The value 'mustzone' sets that variable instead and leaves the status alone.
-- The value 'var:<Name>=<number>' or 'var:<Name>=today' sets one variable the
-- quest keeps (Quest[log][quest]<Name>) and leaves the status alone too:
-- how far a staged quest has come (Prog), and the Vana'diel day its NPC last
-- took a step (Timer), which 'today' names by the server's own
-- VanadielUniqueDay(). A quest that waits for the next Vana'diel day cannot
-- be staged any other way without waiting the days out.
-- 'stored:<Name>=read' or a signed int32 value addresses only Cargo's
-- BuyDate (log4 quest20), Crisis's Progress/NeedToZone (log2 quest2),
-- Something Fishy's SpokenTo/NeedToZone (log2 quest52), Falling Star's
-- Progress (log2 quest53), or Twinstone's SpokenTo/NeedToZone (log2 quest62).
-- Unlike a status set it never
-- clears variables or changes quest status. TestApp captures and restores
-- this value independently; setting eligibility is not daily-recovery proof.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'isiis' }

commandObj.onTrigger = function(player, id, nonce, logId, questId, value)
    if id ~= player:getID()
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or logId == nil or logId < 0 or logId > 10
        or questId == nil or questId < 0 or questId > 255 then
        player:printToPlayer('Quest fixture refused: exact self, nonce, log and quest required.')
        return
    end
    -- Read-only shared NPC wait. Never clear/set NPC state or alter status.
    -- Phoenix 008cd1ca Bastok14, Aquillina17739784 in Bastok Markets235.
    if type(value) == 'string' and value:sub(1, 7) == 'npcwait' then
        if value ~= 'npcwait' or logId ~= 1 or questId ~= 14 or player:getZoneID() ~= 235 then
            player:printToPlayer('Quest fixture refused: audited same-zone NPC wait required.')
            return
        end
        local npc = GetNPCByID(17739784)
        if npc == nil or npc:getID() ~= 17739784 or npc:getZoneID() ~= 235 then
            player:printToPlayer('Quest fixture refused: exact NPC unavailable.')
            return
        end
        local deadline = npc:getLocalVar('tradeCooldown')
        local now = GetSystemTime()
        local function uint32(number)
            return type(number) == 'number' and number >= 0 and number <= 4294967295 and number % 1 == 0
        end
        if not uint32(deadline) or not uint32(now) then
            player:printToPlayer('Quest fixture refused: uint32 NPC deadline and server time required.')
            return
        end
        player:printToPlayer(string.format('Fixture Quest NPC Wait: %s id=%u log=1 quest=14 seconds=%u.',
            nonce, id, math.max(0, deadline - now)), xi.msg.channel.SYSTEM_3)
        return
    end
    -- Explicit legacy addresses only: never accept an arbitrary char-var name.
    -- Phoenix 008cd1ca owns these explicit legacy addresses; raw charvars refuse.
    if type(value) == 'string' and value:sub(1, 7) == 'stored:' then
        local name, raw = value:match('^stored:(%a+)=([%w%-]+)$')
        local address
        if logId == 4 and questId == 20 and name == 'BuyDate' then
            address = 'VuntarCanBuyItem_date'
        elseif logId == 2 and questId == 2 and name == 'Progress' then
            address = 'QuestCrisisMaking_var'
        elseif logId == 2 and questId == 2 and name == 'NeedToZone' then
            address = '[generic]mustZone'
        elseif logId == 2 and questId == 52 and name == 'SpokenTo' then
            address = 'TokakaSpokenTo'
        elseif logId == 2 and questId == 52 and name == 'NeedToZone' then
            address = '[generic]mustZone'
        elseif logId == 2 and questId == 53 and name == 'Progress' then
            address = 'QuestCatchAFallingStar_prog'
        elseif logId == 2 and questId == 62 and name == 'SpokenTo' then
            address = 'GiohAijhriSpokenTo'
        elseif logId == 2 and questId == 62 and name == 'NeedToZone' then
            address = '[generic]mustZone'
        else
            player:printToPlayer('Quest fixture refused: unknown stored quest variable.')
            return
        end
        if raw ~= 'read' then
            local number = raw and raw:match('^%-?%d+$') and tonumber(raw)
            if number == nil or number < -2147483648 or number > 2147483647 then
                player:printToPlayer('Quest fixture refused: signed int32 stored value required.')
                return
            end
            player:setCharVar(address, number)
        end
        player:printToPlayer(string.format('Fixture Quest Variable: %s id=%u log=%u quest=%u name=%s value=%d.',
            nonce, id, logId, questId, name, player:getCharVar(address)), xi.msg.channel.SYSTEM_3)
        return
    end
    if value == 'mustzone' then
        player:setCharVar(string.format('Quest[%d][%d]mustZone', logId, questId), player:getZoneID())
    elseif type(value) == 'string' and value:sub(1, 4) == 'var:' then
        local name, raw = value:match('^var:(%a+)=(%w+)$')
        local number = raw == 'today' and VanadielUniqueDay() or tonumber(raw)
        if name == nil or number == nil or number < 0 then
            player:printToPlayer('Quest fixture refused: var:<Name>=<number> or var:<Name>=today required.')
            return
        end
        player:setCharVar(string.format('Quest[%d][%d]%s', logId, questId, name), number)
    elseif value ~= 'read' then
        local desired = tonumber(value)
        if desired ~= 0 and desired ~= 1 and desired ~= 2 then
            player:printToPlayer('Quest fixture refused: status 0, 1, 2, mustzone or read required.')
            return
        end
        -- delQuest clears both the current and the completed bit, so every
        -- set starts from available and applies exactly one transition.
        player:delQuest(logId, questId)
        player:clearVarsWithPrefix(string.format('Quest[%d][%d]', logId, questId))
        if desired == 1 then
            player:addQuest(logId, questId)
        elseif desired == 2 then
            player:completeQuest(logId, questId)
        end
    end
    player:printToPlayer(string.format('Fixture Quest: %s id=%u log=%u quest=%u status=%u.',
        nonce, id, logId, questId, player:getQuestStatus(logId, questId)), xi.msg.channel.SYSTEM_3)
end

return commandObj
