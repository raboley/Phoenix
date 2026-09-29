-- Offline boundary tests for the real Phoenix-era Lua lifecycle. No xi_test,
-- database connection, sockets, characters or server executables are used.
-- Run from the repository root: luajit tools/tests/dynamis_run_state.lua
-- Count comparison: luajit tools/tests/dynamis_run_state.lua benchmark <source-root>
local mode = arg[1] or 'test'
local sourceRoot = arg[2] or '.'
package.path = sourceRoot .. '/?.lua;' .. package.path
unpack = unpack or table.unpack

local function equal(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function enum()
    return setmetatable({}, {
        __index = function(t, key)
            local value = #t + 1
            t[value] = key
            t[key] = value
            return value
        end,
    })
end

local function loadSource(name)
    dofile(sourceRoot .. '/scripts/globals/dynamis/' .. name .. '.lua')
end

local function fixture(count)
    xi = { dynamis = {}, zone = enum(), effect = enum(), item = enum(), msg = { channel = enum(), basic = enum() }, region = enum(), status = enum(), ki = enum() }
    zones = {}
    local h = { now = 100000, reads = 0, writes = 0, db = {}, readKeys = {}, zoneList = {}, timers = {}, spawns = 0, lockouts = 0 }
    local names = {
        'DYNAMIS_SAN_DORIA',
        'DYNAMIS_BASTOK',
        'DYNAMIS_WINDURST',
        'DYNAMIS_JEUNO',
        'DYNAMIS_BEAUCEDINE',
        'DYNAMIS_XARCABARD',
        'DYNAMIS_VALKURM',
        'DYNAMIS_BUBURIMU',
        'DYNAMIS_QUFIM',
        'DYNAMIS_TAVNAZIA',
    }
    for index, name in ipairs(names) do
        xi.zone[name] = 184 + index
    end

    GetSystemTime = function()
        return h.now
    end

    GetZone = function(id)
        return h.zoneList[id]
    end

    GetNPCByID = function()
        return nil
    end

    DespawnMob = function()
        -- No native entity spawning in this offline fixture.
    end

    GetServerVariable = function(name)
        h.reads = h.reads + 1
        h.readKeys[name] = (h.readKeys[name] or 0) + 1
        return h.db[name] or 0
    end

    SetServerVariable = function(name, value)
        h.writes = h.writes + 1
        h.db[name] = value
        -- Like the native API, deliberately return no acknowledgement.
    end

    utils = {
        clamp = function(value, low, high)
            return math.max(low, math.min(value, high))
        end,
    }
    package.loaded['scripts/globals/battlefield'] = true
    package.loaded['scripts/globals/missions'] = true
    package.loaded['scripts/globals/npc_util'] = true
    package.loaded['scripts/globals/dynamis/run_state'] = nil
    loadSource('dynamis_system')
    loadSource('settings_era')
    loadSource('participants')
    loadSource('entry_era')
    loadSource('hourglass')
    loadSource('ejection')
    loadSource('npc_handlers')
    xi.dynamis.entryInfoEra = {}
    xi.dynamis.dynaIDLookup = {}
    xi.dynamis.dynaInfoEra = {}
    xi.dynamis.wave = {}
    xi.dynamis.spawnWave = function()
        h.spawns = h.spawns + 1
    end

    xi.dynamis.recordLockout = function()
        h.lockouts = h.lockouts + 1
    end

    xi.dynamis.isPlayerLockedOut = function()
        return 0
    end

    xi.dynamis.getZoneMessageID = function(name)
        return name
    end

    xi.dynamis.onNewDynamisTav = function()
        -- No native entity spawning in this offline fixture.
    end

    local zoneMethods = {}
    function zoneMethods:getID()
        return self.id
    end

    function zoneMethods:getLocalVar(name)
        return self.vars[name] or 0
    end

    function zoneMethods:setLocalVar(name, value)
        self.vars[name] = value
    end

    function zoneMethods:resetLocalVars()
        self.vars = {}
    end

    function zoneMethods:getPlayers()
        return self.players
    end

    function zoneMethods:getMobs()
        return {}
    end

    function zoneMethods:getNPCs()
        return {}
    end

    function h:newZone(id)
        local zone = setmetatable({ id = id, vars = {}, players = {} }, { __index = zoneMethods })
        self.zoneList[id] = zone
        return zone
    end

    for index = 1, count or 1 do
        local id = 184 + index
        local entryId = 100 + index
        h:newZone(entryId)
        local zone = h:newZone(id)
        zones[id] = { text = enum() }
        zones[entryId] = { text = enum() }
        xi.dynamis.entryInfoEra[entryId] = { dynaZone = id, enabled = true, csBit = index, maxCapacity = 64, csRegisterGlass = 10, csDyna = 11, enteredVar = 'entered', enterPos = { 1, 2, 3, 4, id } }
        xi.dynamis.dynaIDLookup[id] = { entryZone = entryId }
        xi.dynamis.dynaInfoEra[id] = { winQM = 0, timeExtensions = {}, entryPos = { 1, 2, 3, 4 }, ejectPos = { 1, 2, 3, 4, entryId } }
        xi.dynamis.wave[id] = { {} }
        xi.dynamis.clearOnInit(zone)
    end

    h.zone = h.zoneList[185]
    h.entry = h.zoneList[101]
    function h:key(field, id)
        return '[DYNA]' .. field .. '_' .. (id or 185)
    end

    function h:value(field, id)
        return self.db[self:key(field, id)] or 0
    end

    function h:resetCounts()
        self.reads = 0
        self.writes = 0
        self.readKeys = {}
    end

    function h:player(id, zoneId, gm)
        local p = { id = id or 1, zoneId = zoneId or 101, gm = gm or 0, vars = {}, charVars = {}, items = {}, messages = {}, consumed = 0, entries = {}, cutscenes = {}, disengaged = 0 }
        function p:getID()
            return self.id
        end

        function p:getName()
            return 'Fixture' .. self.id
        end

        function p:getZoneID()
            return self.zoneId
        end

        function p:getZone()
            return GetZone(self.zoneId)
        end

        function p:getMainLvl()
            return 75
        end

        function p:getVisibleGMLevel()
            return self.gm
        end

        function p:isInDynamis()
            return self.zoneId >= 185
        end

        function p:getCurrentRegion()
            return self:isInDynamis() and xi.region.DYNAMIS or 0
        end

        function p:getLocalVar(name)
            return self.vars[name] or 0
        end

        function p:setLocalVar(name, value)
            self.vars[name] = value
        end

        function p:getCharVar(name)
            return self.charVars[name] or 0
        end

        function p:setCharVar(name, value)
            self.charVars[name] = value
        end

        function p:printToPlayer(message)
            table.insert(self.messages, { message })
        end

        function p:messageSpecial(...)
            table.insert(self.messages, { ... })
        end

        function p:timer(ms, fn)
            table.insert(h.timers, { due = h.now + ms / 1000, player = self, fn = fn })
        end

        function p:disengage()
            self.disengaged = self.disengaged + 1
        end

        function p:startCutscene(id)
            table.insert(self.cutscenes, id)
        end

        function p:startEvent(id)
            self.event = id
        end

        function p:setPos(_, _, _, _, destination)
            if destination then
                h:move(self, destination)
            end
        end

        function p:getXPos()
            return 1
        end

        function p:getYPos()
            return 1
        end

        function p:getZPos()
            return 1
        end

        function p:getFreeSlotsCount()
            return 20
        end

        function p:addStatusEffect(effect)
            self.statusEffect = effect
        end

        function p:hasItem(id)
            return #self:findItems(id) > 0
        end

        function p:findItems(id)
            local found = {}
            for _, item in ipairs(self.items) do
                if item.id == id then
                    table.insert(found, item)
                end
            end

            return found
        end

        function p:addItem(data)
            local item = { id = data.id, data = data.exdata }
            function item:getExData()
                local copy = {}
                for key, value in pairs(self.data) do
                    copy[key] = value
                end

                return copy
            end

            function item:setExData(value)
                self.data = value
            end

            table.insert(self.items, item)
        end

        function p:getTrade()
            return {
                getSlotCount = function()
                    return 1
                end,

                getItemCount = function()
                    return 1
                end,

                getItemQty = function(_, id)
                    return id == xi.item.TIMELESS_HOURGLASS and 1 or 0
                end,
            }
        end

        function p:tradeComplete()
            self.consumed = self.consumed + 1
        end

        function p:instanceEntry(_, result)
            table.insert(self.entries, result)
        end

        return p
    end

    function h:move(player, id)
        for _, zone in pairs(self.zoneList) do
            for index = #zone.players, 1, -1 do
                if zone.players[index] == player then
                    table.remove(zone.players, index)
                end
            end
        end

        player.zoneId = id
        table.insert(self.zoneList[id].players, player)
    end

    function h:register(id)
        id = id or 185
        local entryId = xi.dynamis.dynaIDLookup[id].entryZone
        local p = self:player(id, entryId)
        local npc = {
            getID = function()
                return 1
            end,

            getName = function()
                return 'Trail_Markings'
            end,

            getZoneID = function()
                return entryId
            end,
        }
        xi.dynamis.entryNpcOnEventUpdate(p, 10, 0, npc)
        return p
    end

    function h:tick(zone)
        xi.dynamis.dynamisTick(zone or self.zone)
    end

    function h:runTimers()
        local pending = self.timers
        self.timers = {}
        for _, timer in ipairs(pending) do
            if timer.due <= self.now then
                timer.fn(timer.player)
            else
                table.insert(self.timers, timer)
            end
        end
    end

    h:resetCounts()
    return h
end

-- Canonical semantic snapshots compare baseline and candidate without internal
-- cache/warning flags or SQL counts. Message order is unspecified by the old
-- pairs-based warning queue, so compare its multiset (including duplicates).
local function canonical(value)
    if type(value) ~= 'table' then
        return tostring(value)
    end

    local entries = {}
    for key, item in pairs(value) do
        table.insert(entries, tostring(key) .. '=' .. canonical(item))
    end

    table.sort(entries)
    return '{' .. table.concat(entries, ',') .. '}'
end

local function traceCheckpoint(h, label, players)
    local states = {}
    for index, player in ipairs(players or {}) do
        local messages = {}
        for _, message in ipairs(player.messages) do
            table.insert(messages, canonical(message))
        end

        table.sort(messages)
        local glass = {}
        for _, item in ipairs(player.items) do
            table.insert(glass, item:getExData())
        end

        states[index] = {
            zone = player.zoneId,
            vars = player.vars,
            charVars = player.charVars,
            glass = glass,
            messages = messages,
            entries = player.entries,
            consumed = player.consumed,
            cutscenes = player.cutscenes,
            disengaged = player.disengaged,
        }
    end

    local pending = {}
    for _, timer in ipairs(h.timers) do
        table.insert(pending, { due = timer.due, player = timer.player.id })
    end

    print(
        label
            .. ' '
            .. canonical({
                now = h.now,
                durable = h.db,
                reservation = h.zone:getLocalVar(h:key('ReservationExpires')),
                entered = h.zone:getLocalVar(h:key('PlayersEntered')),
                cooldown = h.entry:getLocalVar(h:key('ZoneCooldown')),
                cleanup = h.entry:getLocalVar(h:key('CleanupScript')),
                participants = xi.dynamis.instances,
                players = states,
                timers = pending,
                spawns = h.spawns,
                lockouts = h.lockouts,
            })
    )
end

if mode == 'trace' then
    local h = fixture()
    local p = h:register()
    traceCheckpoint(h, 'reserved', { p })
    h.now = 100030
    h:move(p, 185)
    h:tick()
    traceCheckpoint(h, 'entered', { p })
    h.now = 103000
    h:tick()
    traceCheckpoint(h, 'warning', { p })
    xi.dynamis.addMinutesToDynamis(h.zone, 30)
    traceCheckpoint(h, 'extended', { p })
    h.now = 103020
    h:move(p, 101)
    h:tick()
    traceCheckpoint(h, 'departed', { p })
    h.now = 103614
    h:move(p, 185)
    h:tick()
    traceCheckpoint(h, 'returned', { p })
    h.now = 105400
    h:tick()
    traceCheckpoint(h, 'expired', { p })
    h.now = 105430
    h:runTimers()
    traceCheckpoint(h, 'eject-grace-ended', { p })
    h.now = 105432
    h:runTimers()
    traceCheckpoint(h, 'eject-cutscene', { p })
    h.now = 105442
    h:runTimers()
    traceCheckpoint(h, 'eject-fallback', { p })

    h = fixture()
    p = h:register()
    h.now = 100179
    h:tick()
    traceCheckpoint(h, 'unused-before-timeout', { p })
    h.now = 100180
    h:tick()
    traceCheckpoint(h, 'unused-cleaned', { p })
    h.now = 100200
    local blocked = h:register()
    traceCheckpoint(h, 'cooldown-denied', { p, blocked })
    h.now = 100271
    local fresh = h:player(3, 101)
    fresh:setCharVar('entered', 1)
    local npc = {
        getID = function()
            return 1
        end,

        getName = function()
            return 'Trail_Markings'
        end,

        getZoneID = function()
            return 101
        end,
    }
    xi.dynamis.entryNpcOnTrade(fresh, npc, fresh:getTrade())
    equal(fresh.event, 10, 'registration trade after cooldown')
    xi.dynamis.entryNpcOnEventUpdate(fresh, 10, 0, npc)
    traceCheckpoint(h, 'cooldown-new-run', { p, fresh })
    return
end

if mode == 'benchmark' then
    for trial = 1, 5 do
        for _, workload in ipairs({ 'idle', 'reserved', 'occupied' }) do
            local h = fixture(10)
            if workload ~= 'idle' then
                for id = 185, 194 do
                    local player = h:register(id)
                    equal(player.consumed, 1, 'real NPC registration')
                    if workload == 'occupied' then
                        h:move(player, id)
                    end
                end
            end

            h:resetCounts()
            for step = 1, 300 do
                h.now = 100000 + step * 0.4
                for id = 185, 194 do
                    h:tick(h.zoneList[id])
                end
            end

            print(string.format('trial=%d workload=%s zones=10 ticks=3000 simulated_seconds=120 reads=%d writes=%d', trial, workload, h.reads, h.writes))
            if xi.dynamis.runState then
                equal(h.reads, 0, 'candidate tick polling')
            else
                equal(h.reads, 12000, 'baseline tick polling')
            end
        end
    end

    return
end

local tests = {}
local function test(name, fn)
    table.insert(tests, { name, fn })
end

test('idle ticks do not read or write SQL', function()
    local h = fixture()
    for _ = 1, 1000 do
        h:tick()
    end

    equal(h.reads, 0)
    equal(h.writes, 0)
end)

test('reservation is supervised before anybody enters and cleans after 180 seconds', function()
    local h = fixture()
    local p = h:register()
    equal(p.consumed, 1)
    equal(p.entries[1], 4)
    equal(h:value('StartTime'), 100000)
    equal(h:value('ExpirationTime'), 103600)
    equal(h.zone:getLocalVar(h:key('ReservationExpires')), 100180)
    equal(h.lockouts, 1)
    equal(h.spawns, 1)
    h:resetCounts()
    h.now = 100179
    h:tick()
    equal(h.reads, 0)
    equal(h:value('NoPlayerTimer'), 0)
    h.now = 100180
    h:tick()
    equal(h:value('StartTime'), 0)
    equal(h:value('ExpirationTime'), 0)
    equal(h.entry:getLocalVar(h:key('ZoneCooldown')), 100270)
    assert(xi.dynamis.runState.isReady(h.zone))
    h:resetCounts()
    h:tick()
    equal(h.reads, 0)
    equal(h.writes, 0)
end)

test('delayed first entry cancels reservation and does not start abandonment', function()
    local h = fixture()
    local p = h:register()
    h.now = 100179
    h:move(p, 185)
    h:tick()
    equal(h.zone:getLocalVar(h:key('PlayersEntered')), 1)
    equal(h.zone:getLocalVar(h:key('ReservationExpires')), 0)
    h.now = 100181
    h:tick()
    equal(h:value('StartTime'), 100000)
    equal(h:value('NoPlayerTimer'), 0)
end)

test('abandonment deadline persists, return cancels it, later departure gets a fresh deadline', function()
    local h = fixture()
    local p = h:register()
    h:move(p, 185)
    h:tick()
    h:move(p, 101)
    h.now = 100010
    h:tick()
    equal(h:value('NoPlayerTimer'), 100605)
    h.now = 100604
    h:move(p, 185)
    h:tick()
    equal(h:value('NoPlayerTimer'), 0)
    h.now = 100606
    h:tick()
    equal(h:value('StartTime'), 100000)
    h:move(p, 101)
    h.now = 100607
    h:tick()
    equal(h:value('NoPlayerTimer'), 101202)
    h.now = 101202
    h:tick()
    equal(h:value('StartTime'), 0)
    equal(h:value('NoPlayerTimer'), 0)
    equal(h.entry:getLocalVar(h:key('ZoneCooldown')), 101292)
end)

test('extension near expiry changes retained and durable expiry and refreshes hourglass', function()
    local h = fixture()
    local p = h:register()
    h:move(p, 185)
    h:tick()
    h.now = 103599
    xi.dynamis.addMinutesToDynamis(h.zone, 30)
    equal(h:value('ExpirationTime'), 105400)
    equal(p.items[1].data.endTime, 105400)
    h:resetCounts()
    h.now = 103601
    h:tick()
    equal(h.reads, 0)
    equal(h:value('StartTime'), 100000)
    equal(p:getLocalVar('Received_Eject_Warning'), 0)
end)

test('warnings fire once and extensions re-arm even already elapsed thresholds', function()
    local h = fixture()
    local p = h:register()
    h:move(p, 185)
    h:tick()
    p.messages = {}
    h.now = 103580
    h:tick()
    equal(#p.messages, 3, 'all due thresholds')
    h:tick()
    equal(#p.messages, 3, 'no repeats')
    xi.dynamis.addMinutesToDynamis(h.zone, 1)
    p.messages = {}
    h:tick()
    equal(#p.messages, 2, '10m and 3m re-armed immediately')
    h.now = 103630
    h:tick()
    equal(#p.messages, 3, '30s warning')
    h:tick()
    equal(#p.messages, 3)
end)

test('invalid hourglass in active run preserves delayed ejection', function()
    local h = fixture()
    h:register()
    local p = h:player(2, 185)
    h:move(p, 185)
    h:tick()
    equal(p:getLocalVar('Received_Eject_Warning'), 1)
    equal(#p.cutscenes, 0)
    h.now = 100030
    h:runTimers()
    equal(p.disengaged, 1)
    h.now = 100032
    h:runTimers()
    equal(p.cutscenes[1], 100)
    h.now = 100042
    h:runTimers()
    equal(p:getZoneID(), 101)
end)

test('idle non-GM trespass still gets hourglass ejection, idle GM does not', function()
    local h = fixture()
    local p = h:player(2, 185)
    local gm = h:player(3, 185, 3)
    h:move(p, 185)
    h:move(gm, 185)
    h:tick()
    equal(p:getLocalVar('Received_Eject_Warning'), 1)
    equal(gm:getLocalVar('Received_Eject_Warning'), 0)
    equal(h.reads, 0)
    equal(h.writes, 0)
end)

test('expiry ejects and cleanup cannot reuse the pre-cleanup abandonment deadline', function()
    local h = fixture()
    local p = h:register()
    h:move(p, 185)
    h:tick()
    h:move(p, 101)
    h.now = 100010
    h:tick()
    equal(h:value('NoPlayerTimer'), 100605)
    h.now = 103600
    h:tick()
    equal(h:value('StartTime'), 0)
    equal(h:value('NoPlayerTimer'), 0)
    equal(h.entry:getLocalVar(h:key('CleanupScript')), 1)
    equal(h.entry:getLocalVar(h:key('ZoneCooldown')), 103690)
    equal(h.zone:getLocalVar(h:key('PlayersEntered')), 0)
    h:resetCounts()
    h:tick()
    equal(h.reads, 0)
    equal(h.writes, 0)
end)

test('expiry with occupants uses real ejection and leaves initialized idle', function()
    local h = fixture()
    local p = h:register()
    h:move(p, 185)
    h:tick()
    h.now = 103600
    h:tick()
    equal(p:getLocalVar('Received_Eject_Warning'), 1)
    equal(h:value('ExpirationTime'), 0)
    assert(xi.dynamis.runState.isReady(h.zone))
end)

test('cleanup and reentry use a new run identity; old glass is rejected', function()
    local h = fixture()
    local old = h:register()
    xi.dynamis.cleanupDynamis(h.zone)
    h.now = 100100
    local fresh = h:register()
    equal(fresh.consumed, 1)
    equal(h:value('StartTime'), 100100)
    equal(xi.dynamis.verifyTradeHourglass(old, 101, old.items[1]), xi.dynamis.hourglassTradeResult.INVALID)
    equal(xi.dynamis.verifyTradeHourglass(fresh, 101, fresh.items[1]), xi.dynamis.hourglassTradeResult.REGISTERED)
end)

test('cold init cleans stale SQL instead of resurrecting it, including recreated zone', function()
    local h = fixture()
    h:register()
    h.zone = h:newZone(185)
    assert(not xi.dynamis.runState.isReady(h.zone))
    xi.dynamis.clearOnInit(h.zone)
    equal(h:value('StartTime'), 0)
    equal(h:value('ExpirationTime'), 0)
    assert(xi.dynamis.runState.isReady(h.zone))
    h:resetCounts()
    h:tick()
    equal(h.reads, 0)
end)

test('globals hot reload preserves reservation, retained times and warnings', function()
    local h = fixture()
    h:register()
    package.loaded['scripts/globals/dynamis/run_state'] = nil
    loadSource('dynamis_system')
    h:resetCounts()
    h.now = 100179
    h:tick()
    equal(h.reads, 0)
    h.now = 100180
    h:tick()
    equal(h:value('ExpirationTime'), 0)
    h.now = 100300
    h.entry:setLocalVar(h:key('ZoneCooldown'), 0)
    local p = h:register()
    h:move(p, 185)
    h:tick()
    h.now = 103300
    p.messages = {}
    h:tick()
    equal(#p.messages, 1)
    package.loaded['scripts/globals/dynamis/run_state'] = nil
    loadSource('dynamis_system')
    h:resetCounts()
    h:tick()
    equal(#p.messages, 1)
    equal(h.reads, 0)
    h.now = 103720
    h:tick()
    equal(#p.messages, 2)
end)

test('unexpected state loss fails closed and denies registration before trade consumption', function()
    local h = fixture()
    h:register()
    h.zone:resetLocalVars()
    local ok, message = pcall(function()
        h:tick()
    end)

    equal(ok, false)
    assert(tostring(message):find('cold zone initialization', 1, true))
    local p = h:register()
    equal(p.consumed, 0)
    equal(p.entries[1], 3)
    equal(h:value('StartTime'), 100000, 'no implicit stale-run adoption/cleanup')
end)

test('missing cross-process destination denies registration and GM entry', function()
    local h = fixture()
    h.zoneList[185] = nil
    local p = h:register()
    equal(p.consumed, 0)
    equal(p.entries[1], 3)
    local gm = h:player(3, 101, 3)
    xi.dynamis.entryNpcOnEventFinishEra(gm, 11, 0)
    equal(gm:getZoneID(), 101)
    equal(h.lockouts, 0)
end)

test('GM debug mode bypass and GM cleanup retain their existing meanings', function()
    local h = fixture()
    local gm = h:player(3, 185, 3)
    xi.dynamis.onNewDynamis(gm, 1, 185)
    equal(h.zone:getLocalVar('debugMode'), 1)
    h:resetCounts()
    h:tick()
    equal(h.reads, 0)
    xi.dynamis.cleanupDynamis(h.zone)
    equal(h.zone:getLocalVar('debugMode'), 0)
    assert(xi.dynamis.runState.isReady(h.zone))
end)

for _, entry in ipairs(tests) do
    local ok, message = xpcall(entry[2], debug.traceback)
    if not ok then
        error('FAIL ' .. entry[1] .. '\n' .. tostring(message))
    end

    print('PASS ' .. entry[1])
end

print(string.format('PASS %d offline lifecycle tests (mocked native/SQL boundaries; real Lua rules)', #tests))
