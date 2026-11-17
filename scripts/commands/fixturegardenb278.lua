-- Disposable scout fixture, NOT a production gardening command.
-- Only Gardenqa, one exact installed Earthen Flowerpot in Mog Safe.
-- Changes only its next-step deadline; never seed, feed, RNG, harvest or global time.
local commandObj = {}
commandObj.cmdprops = { permission = 5, parameters = 'isiis' }
commandObj.onTrigger = function(player, id, nonce, slot, expectedStep, mode)
    if player:getName() ~= 'Gardenqa' or player:getID() ~= id
        or type(nonce) ~= 'string' or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or not slot or slot < 1 or slot > 80
        or (not player:inMogHouse() and mode ~= 'read')
        or (mode ~= 'read' and mode ~= 'due' and mode ~= 'soon') then
        player:printToPlayer('Garden scout refused: exact owned actor, nonce, room, slot and mode required.')
        return
    end
    local item = player:getStorageItem(xi.inv.MOGSAFE, slot, 255)
    if not item or item:getID() ~= 218 or not item:isInstalled() then
        player:printToPlayer('Garden scout refused: installed Earthen Flowerpot required.')
        return
    end
    local data = item:getExData()
    if mode == 'due' or mode == 'soon' then
        if data.step ~= expectedStep or data.step < 1 or data.step > 9
            or data.step == 4 or data.step == 7 or data.dried or not data.examined then
            player:printToPlayer('Garden scout refused: examined growing stage must match; feeding windows protected.')
            return
        end
        -- A short future deadline permits an ordinary exit before natural expiry.
        local delay = mode == 'soon' and 120 or 0
        item:setExData({ timeNextStep = VanadielTime() + delay })
        data = item:getExData()
    end
    player:printToPlayer(string.format('GardenScout %s slot=%u step=%u seed=%u feed=%u/%u care=%s rng=%u due=%u now=%u room=%s',
        nonce, slot, data.step, data.kind, data.crystal1, data.crystal2,
        tostring(data.examined), data.strength, data.timeNextStep, VanadielTime(), tostring(player:inMogHouse())), xi.msg.channel.SYSTEM_3)
end
return commandObj
