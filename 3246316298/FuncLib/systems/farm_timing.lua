local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local HeroPosWeights = require(GetScriptDirectory() .. '/FuncLib/data/hero_pos_weights')

local X = {}

-- Expected lane per position per team, matching hero_selection.lua's V/W
-- maps used to build the actual lane assignment - kept here independently
-- so this validation doesn't have to reach into hero_selection.lua's
-- private locals, and stays correct even if that file's internals change.
local EXPECTED_LANE = {
    [TEAM_RADIANT] = { [1] = LANE_BOT, [2] = LANE_MID, [3] = LANE_TOP, [4] = LANE_TOP, [5] = LANE_BOT },
    [TEAM_DIRE] = { [1] = LANE_TOP, [2] = LANE_MID, [3] = LANE_BOT, [4] = LANE_BOT, [5] = LANE_TOP },
}
local LANE_NAMES = { [LANE_TOP] = 'TOP', [LANE_MID] = 'MID', [LANE_BOT] = 'BOT' }

-- One-time self-check, run right alongside the existing TICB-ITEM line so a
-- position/hero-suitability or position/lane mismatch (the Jakiro-as-Pos1
-- class of bug fixed in 0.7.0) is immediately visible in the log again if
-- it ever regresses, instead of requiring another multi-match investigation.
local function ValidateAssignment(bot, position, team)
    local weights = HeroPosWeights.GetHeroPositions()[bot:GetUnitName()]
    if weights ~= nil and (weights[position] or 0) <= 5 then
        pcall(function()
            print(string.format(
                '[TICB-VALIDATE][WARNING] %s labeled pos%d but its weight for that position is only %d (weights=%d,%d,%d,%d,%d) - likely a position-label mismatch',
                bot:GetUnitName(), position, weights[position] or 0,
                weights[1] or 0, weights[2] or 0, weights[3] or 0, weights[4] or 0, weights[5] or 0))
        end)
    end

    local expected = EXPECTED_LANE[team] and EXPECTED_LANE[team][position]
    local okLane, actualLane = pcall(function() return bot:GetAssignedLane() end)
    if expected ~= nil and okLane and actualLane ~= expected then
        pcall(function()
            print(string.format(
                '[TICB-VALIDATE][WARNING] %s pos%d assigned lane=%s but expected lane=%s for this position/team',
                bot:GetUnitName(), position, tostring(LANE_NAMES[actualLane] or actualLane),
                tostring(LANE_NAMES[expected] or expected)))
        end)
    end
end

local DEADLINES = {
    [1] = 18 * 60,
    [2] = 16 * 60,
    [3] = 17 * 60,
    [4] = 15 * 60,
    [5] = 15 * 60,
}

local EXCLUDED = {
    item_boots = true,
    item_power_treads = true,
    item_phase_boots = true,
    item_arcane_boots = true,
    item_tranquil_boots = true,
    item_travel_boots = true,
    item_travel_boots_2 = true,
    item_magic_wand = true,
    item_bracer = true,
    item_wraith_band = true,
    item_null_talisman = true,
    item_soul_ring = true,
    item_bottle = true,
    item_aghanims_shard = true,
}

local ALWAYS_MAJOR = {
    item_bfury = true,
    item_maelstrom = true,
    item_radiance = true,
    item_hand_of_midas = true,
    item_blink = true,
    item_mask_of_madness = true,
    item_armlet = true,
    item_diffusal_blade = true,
    item_witch_blade = true,
    item_glimmer_cape = true,
    item_force_staff = true,
    item_pavise = true,
    item_mekansm = true,
}

local function IsMajorItem(itemName)
    if itemName == nil or EXCLUDED[itemName] then return false end
    if string.find(itemName, 'outfit', 1, true) then return false end
    if string.find(itemName, 'recipe', 1, true) then return false end
    if ALWAYS_MAJOR[itemName] then return true end
    local ok, cost = pcall(GetItemCost, itemName)
    return ok and cost ~= nil and cost >= 1800
end

function X.ConfigurePurchaseList(bot, purchaseList)
    if bot == nil or type(purchaseList) ~= 'table' then return end
    local target = nil
    for _, itemName in ipairs(purchaseList) do
        if IsMajorItem(itemName) then
            target = itemName
            break
        end
    end
    local position = J.GetPosition(bot) or 5
    bot._ticbFarmTimingPlan = {
        item = target,
        target = DEADLINES[position],
        position = position,
    }
    local team = bot:GetTeam()
    pcall(function()
        local okLane, lane = pcall(function() return bot:GetAssignedLane() end)
        print(string.format('[TICB-ITEM] team=%s hero=%s pos=%d lane=%s first_major=%s deadline=%.0f',
            team == TEAM_RADIANT and 'Radiant' or 'Dire', bot:GetUnitName(), position,
            (okLane and LANE_NAMES[lane]) or '?', tostring(target), DEADLINES[position] or 0))
    end)
    ValidateAssignment(bot, position, team)
end

function X.GetState(bot)
    local position = J.GetPosition(bot) or 5
    local plan = bot._ticbFarmTimingPlan
    if plan == nil or plan.item == nil then
        return { position = position, complete = true, recovery = false }
    end
    if bot:FindItemSlot(plan.item) >= 0 then bot._ticbFarmTimingComplete = plan.item end
    local complete = bot._ticbFarmTimingComplete == plan.item
    return {
        position = position,
        item = plan.item,
        target = plan.target,
        complete = complete,
        recovery = not complete and DotaTime() > plan.target,
    }
end

function X.AdjustDesire(bot, desire)
    local state = X.GetState(bot)
    if state.complete then return desire end
    bot._ohaFarmTimingItem = state.item
    bot._ohaFarmTimingRecovery = state.recovery

    if J.IsRetreating(bot)
        or bot:WasRecentlyDamagedByAnyHero(2)
        or #(J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) > 0
        or J.IsInTeamFight(bot, 1800)
    then
        return desire
    end

    if state.position >= 4 then return desire end
    local floors = state.recovery and { 0.72, 0.62, 0.52 } or { 0.61, 0.52, 0.43 }
    local floor = floors[state.position] or desire
    local multiplier = state.recovery and 1.4 or 1.2
    return math.max(desire * multiplier, floor)
end

return X
