-----------------------------------
-- Self-scoped fixture prerequisite. Never used as product purchase behavior.
-- LandSandBoat 8f2442cf: getFreeSlotsCount/getStorageItem/delItemAt.
-- Exactly one plain unlocked stack may be discarded, only if Inventory is full.
-----------------------------------
---@type TCommand
local commandObj = {}
commandObj.cmdprops = { permission = 1, parameters = 'iss' }

local function plain(item)
    if item:state() ~= xi.itemState.FREE or item:getSignature() ~= '' then
        return false
    end
    for _, byte in pairs(item:getExDataRaw()) do
        if byte ~= 0 then
            return false
        end
    end
    return true
end

commandObj.onTrigger = function(player, id, nonce, mode)
    if id ~= player:getID() or type(nonce) ~= 'string'
        or not nonce:match('^[a-f0-9]+$') or #nonce ~= 16
        or (mode ~= 'read' and mode ~= 'ensure') then
        player:printToPlayer('Inventory fixture refused: exact self, nonce and mode required.')
        return
    end
    local bag = xi.inv.INVENTORY
    if mode == 'ensure' and player:getFreeSlotsCount(bag) == 0 then
        local seen = {}
        -- 80 is the server's maximum, not an assumption about this actor's
        -- unlocked capacity. Out-of-capacity getStorageItem returns nil.
        for slot = 1, 80 do
            local item = player:getStorageItem(bag, slot, 255)
            if item and not seen[item:getID()] then
                seen[item:getID()] = true
                if plain(item) then
                    local itemId = item:getID()
                    local quantity = item:getQuantity()
                    if player:delItemAt(itemId, quantity, bag, slot) then
                        player:printToPlayer(string.format(
                            'Inventory fixture discarded item=%u quantity=%u slot=%u.',
                            itemId, quantity, slot), xi.msg.channel.SYSTEM_3)
                    end
                    break
                end
            end
        end
    end
    player:printToPlayer(string.format('Fixture Inventory Space: %s id=%u free=%u.',
        nonce, id, player:getFreeSlotsCount(bag)), xi.msg.channel.SYSTEM_3)
end

return commandObj
