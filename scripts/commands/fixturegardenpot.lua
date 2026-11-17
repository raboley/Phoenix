-- Arrange only: an owned empty pot is placed before a gardening Act.
-- Phoenix 008cd1ca: getStorageItem, flowerpot raw exdata and setExDataRaw.
-- Never creates an item, resets a crop, feeds, selects RNG or grants harvests.
local commandObj = {}
commandObj.cmdprops = { permission = 5, parameters = 'isiiiiis' }
local protected = { atomsk=true, bhoradun=true, erk=true, haruko=true, raskemond=true, shikari=true }
commandObj.onTrigger = function(player, id, nonce, bag, slot, itemId, x, z, mode)
    if player:getID() ~= id or protected[player:getName():lower()]
        or type(nonce) ~= 'string' or #nonce ~= 16 or not nonce:match('^[a-f0-9]+$')
        or (bag ~= 1 and bag ~= 9) or not slot or slot < 1 or slot > 80
        or itemId ~= 218 or not x or x < 0 or x > 5 or not z or z < 0 or z > 22
        or (mode ~= 'read' and mode ~= 'install') then
        player:printToPlayer('Garden fixture refused: exact test self, nonce, Earthen pot and floor location required.')
        return
    end
    local item = player:getStorageItem(bag, slot, 255)
    if not item or item:getID() ~= itemId or item:getQuantity() ~= 1 then
        player:printToPlayer('Garden fixture refused: exact owned pot required.')
        return
    end
    -- Phoenix ItemState, not the unrelated static ItemFlag bitfield.
    -- Permit an already placed empty fixture, never worn/bazaar/transaction.
    if item:state() ~= 0 and item:state() ~= 3 then
        player:printToPlayer('Garden fixture refused: pot is not free or placed furniture.')
        return
    end
    local data = item:getExDataRaw()
    if data[0] ~= 0 or data[4] ~= 0 or bit.band(data[1], 0x80) ~= 0 then
        player:printToPlayer('Garden fixture refused: existing crops are never reset.')
        return
    end
    if mode == 'install' then
        -- Preserve all crop/RNG/unknown bytes, altering placement alone.
        item:setExDataRaw({ [1]=bit.bor(bit.band(data[1], 0x7E), 0x40), [6]=x, [7]=0, [8]=z, [9]=0 })
        data = item:getExDataRaw()
    end
    local installed = bit.band(data[1], 0xC1) == 0x40 and data[6] == x
        and data[7] == 0 and data[8] == z and data[9] == 0
    player:printToPlayer(string.format('Fixture Garden Pot: %s id=%u bag=%u slot=%u installed=%u.',
        nonce, id, bag, slot, installed and 1 or 0), xi.msg.channel.SYSTEM_3)
end
return commandObj
