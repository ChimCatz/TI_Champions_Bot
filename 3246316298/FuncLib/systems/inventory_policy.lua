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

-- Conservative, explicit list only - never guess at whether a component or
-- situational item is still useful. Each entry becomes eligible once
-- DotaTime() passes its threshold (whatever early-game value it had -
-- laning cleave/attack speed, mana sustain, etc. - is long gone by then),
-- but is only actually SOLD once the inventory is genuinely full and would
-- otherwise block the next purchase/pickup - the point is unsticking a
-- blocked build (e.g. Underlord still holding a Quelling Blade with no
-- room left for his next item), not proactively tidying up a build that
-- isn't actually stuck. Deliberately a narrow, explicit list rather than a
-- general "sell whatever looks outgrown" heuristic.
local OBSOLETE_AFTER = {
    item_quelling_blade = 14 * 60,
}

-- Sells a clearly-obsolete starter item, but only once it's actually
-- blocking progress (inventory completely full). Safe to call every tick
-- from item purchase logic - throttled and a no-op the rest of the time.
function X.SellObsoleteItems(bot)
    if bot == nil or not bot:IsAlive() then return end
    local now = DotaTime()
    if now < (bot._ticbObsoleteCheckAt or -90) then return end
    bot._ticbObsoleteCheckAt = now + 5.0

    for slot = 0, 8 do
        if bot:GetItemInSlot(slot) == nil then return end
    end

    for itemName, threshold in pairs(OBSOLETE_AFTER) do
        if now >= threshold then
            local slot = bot:FindItemSlot(itemName)
            if slot >= 0 and slot <= 5 then
                local item = bot:GetItemInSlot(slot)
                if item ~= nil then
                    bot:ActionImmediate_SellItem(item)
                end
            end
        end
    end
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
