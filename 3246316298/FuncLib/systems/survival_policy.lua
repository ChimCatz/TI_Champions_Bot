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

-- Hero-owned summons (Warlock's Golem, Enigma's Eidolons, Lone Druid's
-- Bear) and dominated neutrals hit hero-hard but are neutral-team, so they
-- never showed up in bot:GetNearbyHeroes() - with #enemies==0 short-
-- circuiting this whole function to "no need to retreat", bots kept
-- forced-attacking a Golem/Bear/Eidolon until they died instead of
-- fleeing, since as far as this retreat check was concerned nothing was
-- actually attacking them.
local DANGEROUS_SUMMON_NAME = {
    npc_dota_warlock_golem = true,
    npc_dota_unit_enigma_eidolon = true,
    npc_dota_lone_druid_bear = true,
}
local function IsDangerousSummon(unit)
    local name = unit:GetUnitName()
    if DANGEROUS_SUMMON_NAME[name] then return true end
    return unit:HasModifier('modifier_helm_of_the_dominator_dominated')
        or unit:HasModifier('modifier_helm_of_the_overlord_dominated')
end

local function IncomingSummonDamage(bot, seconds)
    local total = 0
    local engaged = false
    for _, unit in pairs(bot:GetNearbyCreeps(900, true) or {}) do
        if J.IsValid(unit) and IsDangerousSummon(unit) then
            if unit:GetAttackTarget() == bot then engaged = true end
            local ok, damage = pcall(function()
                return unit:GetEstimatedDamageToTarget(true, bot, seconds, DAMAGE_TYPE_ALL)
            end)
            if ok and damage ~= nil then total = total + math.max(0, damage) end
        end
    end
    return total, engaged
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
    local summonDamage, summonEngaged = IncomingSummonDamage(bot, 3.0)
    if #enemies == 0 and not summonEngaged then return BOT_MODE_DESIRE_NONE end

    local recentlyHit = bot:WasRecentlyDamagedByAnyHero(3) or summonEngaged
    local incoming = IncomingHeroDamage(bot, enemies, 3.0) + summonDamage
    local remaining = (bot:GetHealth() - incoming) / math.max(1, bot:GetMaxHealth())
    -- A solo laner facing a duo lane is outnumbered by definition
    -- (#enemies > #allies is true every single time), so during normal
    -- laning that comparison isn't a danger signal on its own - it was
    -- making 1v2 offlaners/soft-supports retreat out of completely
    -- ordinary trades at a fairly high 62% HP, which read as "passive,
    -- leaves lane constantly". Only count being outnumbered as a retreat
    -- trigger once laning is over (roams/ganks/fights, where an extra
    -- enemy body really does mean danger).
    local isLaning = J.IsLaning(bot)
    if recentlyHit and (remaining < 0.22 or hp < 0.34) then
        return BOT_MODE_DESIRE_ABSOLUTE
    end
    if recentlyHit and ((not isLaning and #enemies > #allies + 1) or remaining < 0.30 or hp < 0.40) then
        return BOT_MODE_DESIRE_VERYHIGH + 0.08
    end
    if recentlyHit and hp < 0.62 and not isLaning and #enemies > #allies then
        return BOT_MODE_DESIRE_HIGH
    end
    return BOT_MODE_DESIRE_NONE
end

return X
