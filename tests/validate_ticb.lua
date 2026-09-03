local root = arg[1] or '3246316298'
package.path = root .. '/?.lua;' .. package.path

TEAM_RADIANT, TEAM_DIRE = 2, 3
LANE_TOP, LANE_MID, LANE_BOT = 1, 2, 3
BOT_MODE_NONE, BOT_MODE_RETREAT, BOT_MODE_RUNE = 0, 1, 2
BOT_MODE_DESIRE_NONE, BOT_MODE_DESIRE_HIGH = 0, 0.6
BOT_MODE_DESIRE_VERYHIGH, BOT_MODE_DESIRE_ABSOLUTE = 0.8, 1.0
DAMAGE_TYPE_ALL = 0

local now = 600
function DotaTime() return now end
function GetScriptDirectory() return root end
function RandomInt(low) return low end
function GetItemCost(name)
    local costs = {
        item_tango = 90, item_boots = 500, item_radiance = 4700,
        item_glimmer_cape = 2150, item_force_staff = 2200,
    }
    return costs[name] or 0
end

local J = {
    GetPosition = function(bot) return bot.position end,
    IsRetreating = function() return false end,
    IsInTeamFight = function() return false end,
    GetNearbyHeroes = function() return {} end,
    GetHP = function(bot) return bot:GetHealth() / bot:GetMaxHealth() end,
    IsValidHero = function(unit) return unit ~= nil end,
    IsSuspiciousIllusion = function() return false end,
    IsValidBuilding = function(unit) return unit ~= nil end,
    VectorAway = function(location) return location end,
}
package.loaded[root .. '/FuncLib/func_utils'] = J
package.loaded[root .. '/FuncLib/systems/custom_loader'] = {
    Random_TI_Rosters = false,
    Fixed_Position_Names = {
        'TSpirit.Yatoro', 'TSpirit.Larl', 'TSpirit.Collapse',
        'TSpirit.not me', 'TSpirit.rue',
    },
}

local Names = require(root .. '/FuncLib/data/team_names')
local teams = Names.generateTeams()
assert(teams.Radiant[2] == 'TSpirit.Larl')
assert(teams.Dire[5] == 'TSpirit.rue')

local FarmTiming = require(root .. '/FuncLib/systems/farm_timing')
local carry = {
    position = 1,
    GetUnitName = function() return 'npc_dota_hero_alchemist' end,
    FindItemSlot = function() return -1 end,
}
FarmTiming.ConfigurePurchaseList(carry, {
    'item_tango', 'item_boots', 'item_radiance', 'item_force_staff',
})
assert(carry._ticbFarmTimingPlan.item == 'item_radiance')
assert(carry._ticbFarmTimingPlan.target == 18 * 60)

local support = {
    position = 5,
    GetUnitName = function() return 'npc_dota_hero_witch_doctor' end,
    FindItemSlot = function() return -1 end,
}
FarmTiming.ConfigurePurchaseList(support, {
    'item_tango', 'item_boots', 'item_glimmer_cape', 'item_force_staff',
})
assert(support._ticbFarmTimingPlan.item == 'item_glimmer_cape')
assert(support._ticbFarmTimingPlan.target == 15 * 60)

local Inventory = require(root .. '/FuncLib/systems/inventory_policy')
local swapped = nil
local items = {
    [0] = { GetName = function() return 'item_tango' end },
    [6] = { GetName = function() return 'item_force_staff' end },
}
local inventoryBot = {
    GetItemInSlot = function(_, slot) return items[slot] end,
    WasRecentlyDamagedByAnyHero = function() return false end,
    GetNearbyHeroes = function() return {} end,
    ActionImmediate_SwapItems = function(_, from, to) swapped = { from, to } end,
}
assert(Inventory.Optimize(inventoryBot))
assert(swapped[1] == 6 and swapped[2] == 1 or swapped[2] == 0)

print('TI Champions Bot policy validation passed')
