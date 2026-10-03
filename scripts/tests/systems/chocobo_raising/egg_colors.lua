-----------------------------------
-- Real egg exdata -> trainer trade packets -> persisted color and genes.
-----------------------------------
local raisingClient = require('scripts.tests.systems.chocobo_raising.client')

describe('Chocobo egg color persistence', function()
    ---@type CClientEntityPair
    local player

    local color = xi.chocoboRaising.color
    local colors = { color.YELLOW, color.BLACK, color.BLUE, color.RED, color.GREEN }

    -- First roll inside each color's weighted interval, on the 1..1000 scale.
    local eggs =
    {
        { xi.item.CHOCOBO_EGG_FAINTLY_WARM,  { 1, 951, 981, 991, 996 } },
        { xi.item.CHOCOBO_EGG_SLIGHTLY_WARM, { 1, 851, 901, 935, 968 } },
        { xi.item.CHOCOBO_EGG_A_BIT_WARM,    { 1, 751, 851, 901, 951 } },
        { xi.item.CHOCOBO_EGG_A_LITTLE_WARM, { 1, 321, 501, 681, 841 } },
        { xi.item.CHOCOBO_EGG_SOMEWHAT_WARM, { 1, 121, 341, 561, 781 } },
    }

    before_each(function()
        xi.test.world:setSetting('main.ENABLE_CHOCOBO_RAISING', true)
        player = xi.test.world:spawnPlayer({ zone = xi.zone.SOUTHERN_SAN_DORIA })
        player:deleteRaisedChocobo()
    end)

    after_each(function()
        player:deleteRaisedChocobo()
    end)

    local function tradeAndReload(itemId, expected)
        local client = raisingClient.new(player)
        raisingClient.trade(client, { itemId })
        raisingClient.send(client, 252)
        raisingClient.finish(client, 252)
        player.assert.no:hasItem(itemId)
        local saved = assert(player:getChocoboRaisingInfo(), 'Expected a persisted raising row')
        assert(saved.stage == xi.chocoboRaising.stage.EGG, 'Color must settle before hatching')
        assert(saved.color == expected, 'Wrong persisted color')
        for slot = 1, 3 do
            assert(saved['allele' .. slot] == expected, 'Wrong persisted gene')
        end
    end

    for _, case in ipairs(eggs) do
        local itemId = case[1]
        for index, expected in ipairs(colors) do
            it(string.format('rolls and saves color %d from ordinary egg %d', expected, itemId), function()
                local egg = assert(player:addItem({ id = itemId }))
                local exdata = egg:getExData()
                assert(exdata.isBred == false, 'Ordinary egg must not have the bred marker')
                assert(exdata.dna[1] == 0 and exdata.dna[2] == 0 and exdata.dna[3] == 0, 'Expected blank native DNA')

                local weightedRolls = 0
                stub('math.randomInt', function(low, high)
                    if high == 1000 then
                        weightedRolls = weightedRolls + 1
                        -- First select color, then select three matching genes.
                        return weightedRolls == 1 and case[2][index] or 1
                    end

                    return low
                end)

                tradeAndReload(itemId, expected)
                assert(weightedRolls == 2, 'Ordinary egg must roll color and gene pattern')
            end)
        end
    end

    for _, expected in ipairs(colors) do
        it(string.format('saves bred color %d without rerolling its genes', expected), function()
            local itemId = xi.item.CHOCOBO_EGG_SOMEWHAT_WARM
            local egg = assert(player:addItem(
            {
                id     = itemId,
                exdata = { dna = { expected, expected, expected }, isBred = true },
            }))
            assert(egg:getExData().isBred, 'Expected the native bred marker')
            local founderRoll = stub('xi.chocoboRaising.rollNonBredEggAlleles', function()
                error('A bred egg must not roll founder genes, including all-yellow DNA')
            end)

            tradeAndReload(itemId, expected)
            founderRoll:called(0)
        end)
    end
end)
