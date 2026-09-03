local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local LaneDiscipline = require(GetScriptDirectory() .. '/FuncLib/systems/lane_discipline')

local X = {}

local function IncomingHeroDamage(bot, enemies, seconds)
    local total = 0
    for _, enemy in pairs(enemies) do
        if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
            local ok, damage = pcall(function()
                return enemy:GetEstimatedDamageToTarget(true, bot, seconds, DAMAGE_TYPE_ALL)
            end)
            if ok and damage ~= nil then total = total + math.max(0, damage) end
        end
    end
    return total
end

function X.GetRetreatDesire(bot)
    if bot == nil or not bot:IsAlive() then return BOT_MODE_DESIRE_NONE end
    if bot:HasModifier('modifier_item_satanic_unholy')
        or bot:HasModifier('modifier_abaddon_borrowed_time')
        or bot:HasModifier('modifier_dazzle_shallow_grave')
        or bot:HasModifier('modifier_oracle_false_promise_timer')
        or bot:HasModifier('modifier_muerta_pierce_the_veil_buff')
        or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active')
    then
        return BOT_MODE_DESIRE_NONE
    end
    local hp = J.GetHP(bot)
    local enemies = bot:GetNearbyHeroes(1400, true, BOT_MODE_NONE) or {}
    local allies = bot:GetNearbyHeroes(1400, false, BOT_MODE_NONE) or {}

    if LaneDiscipline.IsUnsafeEnemyTowerArea(bot) then
        return BOT_MODE_DESIRE_ABSOLUTE
    end
    if #enemies == 0 then return BOT_MODE_DESIRE_NONE end

    local recentlyHit = bot:WasRecentlyDamagedByAnyHero(3)
    local incoming = IncomingHeroDamage(bot, enemies, 3.0)
    local remaining = (bot:GetHealth() - incoming) / math.max(1, bot:GetMaxHealth())
    if recentlyHit and (remaining < 0.22 or hp < 0.34) then
        return BOT_MODE_DESIRE_ABSOLUTE
    end
    if recentlyHit and (#enemies > #allies + 1 or remaining < 0.38 or hp < 0.50) then
        return BOT_MODE_DESIRE_VERYHIGH + 0.08
    end
    if recentlyHit and hp < 0.62 and #enemies > #allies then
        return BOT_MODE_DESIRE_HIGH
    end
    return BOT_MODE_DESIRE_NONE
end

return X
