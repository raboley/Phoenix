-- The 0x0DC invitation names its inviter: UniqueNo at 0x04, ActIndex at 0x08,
-- name at 0x0C. Clients that do not render the inviter identify it by these
-- fields alone, so they must never carry the invitee's own identity.

---@param player CClientEntityPair
local function receivedInvitation(player)
    for _, packet in ipairs(player.packets:getIncoming()) do
        if packet.type == 0x0DC then
            local data = packet.data
            local name = ''
            for offset = 0x0C, 0x1B do
                if data[offset] == 0 then
                    break
                end

                name = name .. string.char(data[offset])
            end

            return {
                uniqueNo = data[0x04] + data[0x05] * 256 + data[0x06] * 65536 + data[0x07] * 16777216,
                actIndex = data[0x08] + data[0x09] * 256,
                kind     = data[0x0B],
                name     = name,
            }
        end
    end

    assert(false, 'no party invitation packet was received')
end

describe('Party invitation packet', function()
    ---@type CClientEntityPair
    local leader
    ---@type CClientEntityPair
    local invitee

    local function spawnNear(anchor)
        local player = xi.test.world:spawnPlayer({ zone = xi.zone.WEST_RONFAURE })
        if anchor then
            player:setPos(anchor:getXPos(), anchor:getYPos(), anchor:getZPos())
        end

        return player
    end

    before_each(function()
        leader  = spawnNear()
        invitee = spawnNear(leader)
        invitee.packets:clear()
    end)

    it('names the inviter of a party invitation', function()
        leader.actions:inviteToParty(invitee)

        local invitation = receivedInvitation(invitee)
        assert(invitation.uniqueNo == leader:getID(), 'UniqueNo is not the inviter: ' .. invitation.uniqueNo)
        assert(invitation.actIndex == leader:getTargID(), 'ActIndex is not the inviter: ' .. invitation.actIndex)
        assert(invitation.name == leader:getName(), 'name is not the inviter: ' .. invitation.name)
    end)

    it('names the inviter of an alliance invitation', function()
        local member = spawnNear(leader)
        leader.actions:inviteToParty(member)
        member.actions:acceptPartyInvite()
        local otherMember = spawnNear(leader)
        invitee.actions:inviteToParty(otherMember)
        otherMember.actions:acceptPartyInvite()
        invitee.packets:clear()

        leader.actions:formAlliance(invitee)

        local invitation = receivedInvitation(invitee)
        assert(invitation.uniqueNo == leader:getID(), 'UniqueNo is not the inviter: ' .. invitation.uniqueNo)
        assert(invitation.actIndex == leader:getTargID(), 'ActIndex is not the inviter: ' .. invitation.actIndex)
        assert(invitation.name == leader:getName(), 'name is not the inviter: ' .. invitation.name)
    end)
end)
