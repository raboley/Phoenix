-----------------------------------
-- Phoenix-era Dynamis run supervision
-----------------------------------
xi = xi or {}
xi.dynamis = xi.dynamis or {}
xi.dynamis.runState = {}

-- The zone owns these values, just like ReservationExpires and PlayersEntered.
-- Unlike a file-local Lua table, they survive globals/module hot reload.
local fields =
{
    startTime     = 'StartTime',
    expiration    = 'ExpirationTime',
    noPlayerTimer = 'NoPlayerTimer',
}

local warningThresholds = { 600, 180, 30 }
local readyVar = '[DYNA]RunStateReady'

local function variableName(zone, field)
    assert(fields[field], 'Unknown Dynamis run-state field')
    return string.format('[DYNA]%s_%s', fields[field], zone:getID())
end

xi.dynamis.runState.isReady = function(zone)
    return zone ~= nil and zone:getLocalVar(readyVar) == 1
end

local function requireReady(zone)
    assert(xi.dynamis.runState.isReady(zone), 'Dynamis run state missing: cold zone initialization is required; do not hot-install or reset live zone locals')
end

-- Only cold zone initialization and completed cleanup establish initialized-idle.
-- Do not hydrate SQL on a tick: a missing owner is not evidence that a run is idle.
xi.dynamis.runState.initialize = function(zone)
    for field, _ in pairs(fields) do
        zone:setLocalVar(variableName(zone, field), 0)
    end

    zone:setLocalVar('[DYNA]WarningsArmed', 0)
    zone:setLocalVar(readyVar, 1)
end

xi.dynamis.runState.get = function(zone)
    requireReady(zone)
    return
        zone:getLocalVar(variableName(zone, 'startTime')),
        zone:getLocalVar(variableName(zone, 'expiration')),
        zone:getLocalVar(variableName(zone, 'noPlayerTimer'))
end

-- Keep the ordinary synchronous persistence path at lifecycle mutations, not
-- the volatile cache. SetServerVariable has no success acknowledgement.
xi.dynamis.runState.set = function(zone, field, value)
    requireReady(zone)
    local name = variableName(zone, field)
    SetServerVariable(name, value)
    zone:setLocalVar(name, value)
end

xi.dynamis.runState.armWarnings = function(zone)
    requireReady(zone)
    for _, threshold in ipairs(warningThresholds) do
        zone:setLocalVar('[DYNA]WarningSent_' .. threshold, 0)
    end

    zone:setLocalVar('[DYNA]WarningsArmed', 1)
end

xi.dynamis.runState.tickWarnings = function(zone, expiration)
    if zone:getLocalVar('[DYNA]WarningsArmed') ~= 1 then
        return
    end

    local currentTime = GetSystemTime()
    for _, threshold in ipairs(warningThresholds) do
        local sentVar = '[DYNA]WarningSent_' .. threshold
        if
            currentTime >= expiration - threshold and
            zone:getLocalVar(sentVar) == 0
        then
            zone:setLocalVar(sentVar, 1)
            xi.dynamis.dynamisTimeWarning(zone, expiration)
        end
    end
end
