-----------------------------------
-- Self-scoped nation-mission fixture: read one mission's log state, or put the
-- character where its gate guard offers that mission.
-- Stock !addmission/!delmission only echo the request and touch one mission,
-- so a character whose rank, rank points or earlier missions do not allow the
-- mission looks, to a setup, exactly like one that was arranged.
-- The receipt is the server's own state afterwards:
--   completed + 2 * current   (current: it is the log's active mission).
-- Operations:
--   read     report the state and change nothing.
--   offered  make the mission the next one the gate guard lists: no active
--            mission, mission status 0, every lower-numbered mission of the
--            log completed, this mission not completed, the given rank in
--            the character's nation and a full rank bar. The mission log must
--            be the character's own nation; the fixture never changes nation.
-- Authority: LandSandBoat addMission/completeMission/delMission/setRank/
-- setRankPoints/setMissionStatus, and xi.mission.getMissionMask, which lists a
-- mission only when its rank, rank points and required missions allow it.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'isiisi' }

commandObj.onTrigger = function(player, id, nonce, logId, missionId, operation, rank)
    if id ~= player:getID()
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or logId == nil or logId < 0 or logId > 2
        or missionId == nil or missionId < 0 or missionId > 63 then
        player:printToPlayer('Mission fixture refused: exact self, nonce, nation log and mission required.')
        return
    end
    local none = xi.mission.id.nation.NONE
    if operation == 'offered' then
        if player:getNation() ~= logId then
            player:printToPlayer('Mission fixture refused: the mission log is not the character\'s nation.')
            return
        end
        if rank == nil or rank < 1 or rank > 10 then
            player:printToPlayer('Mission fixture refused: rank 1 through 10 required.')
            return
        end
        local current = player:getCurrentMission(logId)
        if current ~= none then
            player:delMission(logId, current)
        end
        -- completeMission only completes the active mission, so each earlier
        -- mission is taken and then completed.
        for earlier = 0, missionId - 1 do
            if not player:hasCompletedMission(logId, earlier) then
                player:addMission(logId, earlier)
                player:completeMission(logId, earlier)
            end
        end
        player:delMission(logId, missionId)
        player:setMissionStatus(logId, 0)
        player:setRank(rank)
        player:setRankPoints(4000)
    elseif operation ~= 'read' then
        player:printToPlayer('Mission fixture refused: offered or read required.')
        return
    end
    local state = (player:hasCompletedMission(logId, missionId) and 1 or 0)
        + (player:getCurrentMission(logId) == missionId and 2 or 0)
    player:printToPlayer(string.format('Fixture Mission: %s id=%u log=%u mission=%u state=%u.',
        nonce, id, logId, missionId, state), xi.msg.channel.SYSTEM_3)
end

return commandObj
