-- Dedicated crop-clock fixture, never a production gardening operation.
-- Phoenix 008cd1ca: setExData marks dirty; CCharEntity::PostTick calls
-- InventorySyncState::flushDirtyItems (DB save + ordinary ItemAttr packet).
-- Only shortens an examined outdoor crop's deadline. The server must grow it
-- on ordinary entry; the product must examine, feed and harvest it itself.
local commandObj = {}
commandObj.cmdprops = { permission = 5, parameters = 'isiiiiiis' }
local protected = { atomsk=true, bhoradun=true, erk=true, haruko=true, raskemond=true, shikari=true }
local growing = { [1]=true, [2]=true, [6]=true, [8]=true, [9]=true }
local singleFeed = { [2]=true, [3]=true, [4]=true, [8]=true }
commandObj.onTrigger = function(player, id, nonce, bag, slot, stage, planted, expectedDue, delay, mode)
    if player:getID() ~= id or protected[player:getName():lower()]
        or type(nonce) ~= 'string' or #nonce ~= 16 or not nonce:match('^[a-f0-9]+$')
        or (bag ~= 1 and bag ~= 9) or not slot or slot < 1 or slot > 80
        or not stage or not planted or planted <= 0 or not expectedDue
        or not delay or delay < 1 or delay > 120
        or (mode ~= 'read' and mode ~= 'shorten') then
        player:printToPlayer('Garden clock refused: exact test self, nonce, crop and bounded delay required.')
        return
    end
    local item = player:getStorageItem(bag, slot, 255)
    if not item or item:getID() ~= 218 or item:getQuantity() ~= 1
        or item:state() ~= 3 or not item:isInstalled() then
        player:printToPlayer('Garden clock refused: exact installed Earthen pot required.')
        return
    end
    local data = item:getExData()
    if data.step ~= stage or data.timePlanted ~= planted or data.z ~= 0
        or (mode == 'shorten' and data.timeNextStep ~= expectedDue) then
        player:printToPlayer('Garden clock refused: crop or deadline changed; read before retrying.')
        return
    end
    if mode == 'shorten' then
        local due = VanadielTime() + delay
        if player:inMogHouse() or not growing[data.step] or not singleFeed[data.kind]
            or data.dried or not data.examined or due >= data.timeNextStep then
            player:printToPlayer('Garden clock refused: examined outdoor growing crop and earlier future deadline required.')
            return
        end
        item:setExData({ timeNextStep = due })
        data = item:getExData()
    end
    player:printToPlayer(string.format('Fixture Garden Clock: %s id=%u bag=%u slot=%u stage=%u planted=%u due=%u.',
        nonce, id, bag, slot, data.step, data.timePlanted, data.timeNextStep), xi.msg.channel.SYSTEM_3)
end
return commandObj
