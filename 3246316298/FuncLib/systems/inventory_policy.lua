local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}

local PRIORITY = {
    item_black_king_bar = 5000,
    item_blink = 4200,
    item_overwhelming_blink = 4200,
    item_arcane_blink = 4200,
    item_swift_blink = 4200,
    item_satanic = 4000,
    item_manta = 3600,
    item_force_staff = 3000,
    item_hurricane_pike = 3200,
    item_glimmer_cape = 3000,
    item_lotus_orb = 3000,
    item_cyclone = 2800,
    item_sheepstick = 3000,
    item_orchid = 2500,
    item_bloodthorn = 3200,
}

local LOW_VALUE = {
    item_branches = -800,
    item_tango = -800,
    item_clarity = -700,
    item_flask = -600,
    item_faerie_fire = -500,
    item_infused_raindrop = -300,
    item_magic_stick = -200,
}

local function Score(item)
    if item == nil then return -100000 end
    local name = item:GetName()
    if string.find(name, 'recipe', 1, true) then return -2000 end
    return (GetItemCost(name) or 0) + (PRIORITY[name] or 0) + (LOW_VALUE[name] or 0)
end

function X.Optimize(bot)
    local now = DotaTime()
    if now < (bot._ticbInventoryCheckAt or -90) then return false end
    bot._ticbInventoryCheckAt = now + 2.0
    if bot:WasRecentlyDamagedByAnyHero(4)
        or #(bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE) or {}) > 0
        or J.IsRetreating(bot)
    then
        return false
    end

    local bestBackpack, bestScore = nil, -100000
    for slot = 6, 8 do
        local score = Score(bot:GetItemInSlot(slot))
        if score > bestScore then bestBackpack, bestScore = slot, score end
    end
    if bestBackpack == nil or bot:GetItemInSlot(bestBackpack) == nil then return false end

    local worstMain, worstScore = nil, 100000
    for slot = 0, 5 do
        local item = bot:GetItemInSlot(slot)
        if item == nil then
            worstMain, worstScore = slot, -100000
            break
        end
        local score = Score(item)
        if score < worstScore then worstMain, worstScore = slot, score end
    end
    if worstMain ~= nil and bestScore >= worstScore + 350 then
        bot:ActionImmediate_SwapItems(bestBackpack, worstMain)
        bot._ticbInventoryCheckAt = now + 7.0
        return true
    end
    return false
end

return X
