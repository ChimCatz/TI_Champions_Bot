local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local CombatSafety = require(GetScriptDirectory() .. '/FuncLib/systems/combat_safety')
local DamageForecast = require(GetScriptDirectory() .. '/FuncLib/systems/damage_forecast')
local EconomyPhase = require(GetScriptDirectory() .. '/FuncLib/systems/economy_phase')
J.IsInLaningPhase = EconomyPhase.IsActive

local X = {}
local FOCUS_HOLD_SECONDS = 3.0
local FOCUS_SWITCH_MARGIN = 18
local SelectFocusTarget

local function SafeUnitTarget(unit, attackTarget)
    local ok, target = pcall(function()
        return attackTarget and unit:GetAttackTarget() or unit:GetTarget()
    end)
    return ok and target or nil
end

local function IsHumanCommitted(ally, enemy)
    if ally:IsBot() or J.IsRetreating(ally) then return false end
    if GetUnitToUnitDistance(ally, enemy) > ally:GetAttackRange() + 350 then return false end
    return SafeUnitTarget(ally, true) == enemy or SafeUnitTarget(ally, false) == enemy
end

local function IsUsableEnemy(enemy)
    if enemy == nil then return false end
    if not J.IsValidHero(enemy) or not enemy:CanBeSeen() then return false end
    if enemy:IsInvulnerable() or enemy:HasModifier('modifier_dazzle_shallow_grave') then return false end
    if enemy:HasModifier('modifier_oracle_false_promise_timer') then return false end
    return not J.IsSuspiciousIllusion(enemy)
end

local function GetAllyCommitment(allies, enemy)
    local commitment = 0
    for _, ally in pairs(allies) do
        if J.IsValidHero(ally) then
            local target = SafeUnitTarget(ally, false)
            local attackTarget = SafeUnitTarget(ally, true)
            local weight = ally:IsBot() and 1.0 or 0.45
            if target == enemy then commitment = commitment + 20 * weight end
            if attackTarget == enemy then commitment = commitment + 12 * weight end

            if ally:IsBot() then
                local activeAbility = ally:GetCurrentActiveAbility()
                if activeAbility ~= nil and target == enemy then
                    commitment = commitment + 12 * weight
                end
            end
        end
    end
    return commitment
end

local function SafeEstimatedDamage(attacker, target, seconds)
    local ok, damage = pcall(function()
        return attacker:GetEstimatedDamageToTarget(true, target, seconds, DAMAGE_TYPE_ALL)
    end)
    return ok and math.max(0, damage or 0) or 0
end

local function GetReadyAbilityDamage(hero)
    if not hero:IsBot() or hero:IsSilenced() then return 0 end
    local total = 0
    for slot = 0, 5 do
        local ability = hero:GetAbilityInSlot(slot)
        if ability ~= nil
            and not ability:IsHidden()
            and ability:IsTrained()
            and ability:IsFullyCastable()
            and not J.CheckBitfieldFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_PASSIVE)
        then
            local ok, damage = pcall(function() return ability:GetAbilityDamage() end)
            total = total + (ok and math.min(450, math.max(0, damage or 0)) or 0)
        end
    end
    return math.min(total, 900)
end

local function GetBotComboDamage(allies, enemy)
    local damage = 0
    for _, ally in pairs(allies) do
        if J.IsValidHero(ally) and ally:IsAlive() and not J.IsRetreating(ally) then
            local distance = GetUnitToUnitDistance(ally, enemy)
            if distance <= 1800 then
                local arrival = math.max(0, (distance - ally:GetAttackRange()) / math.max(220, ally:GetCurrentMovementSpeed()))
                if ally:IsBot() then
                    local forecast = DamageForecast.ForHero(ally, enemy, math.max(1.2, 4.5 - arrival))
                    damage = damage + forecast.conservative
                elseif IsHumanCommitted(ally, enemy) then
                    local forecast = DamageForecast.ForHero(ally, enemy, math.max(1.0, 3.0 - arrival))
                    damage = damage + forecast.expected * 0.45
                end
            end
        end
    end
    return damage
end

local function GetFocusScore(bot, enemy, allies, currentTarget)
    local maxHealth = math.max(1, enemy:GetMaxHealth())
    local healthRatio = enemy:GetHealth() / maxHealth
    local distance = GetUnitToUnitDistance(bot, enemy)
    local comboDamage = GetBotComboDamage(allies, enemy)
    local killRatio = comboDamage / math.max(1, enemy:GetHealth() + enemy:GetHealthRegen() * 4)
    local score = (1 - healthRatio) * 58
        + math.max(0, 38 - distance / 55)
        + math.min(85, killRatio * 55)
        + enemy:GetLevel() * 0.7
        + GetAllyCommitment(allies, enemy)

    if killRatio >= 1 then score = score + 70 end
    if not enemy:IsBot() and J.GetPosition(enemy) <= 2 then score = score + 18 end
    if enemy:IsChanneling() then score = score + 45 end
    if enemy == currentTarget then score = score + 14 end
    if enemy:IsMagicImmune() then score = score - 12 end
    if enemy:HasModifier('modifier_item_lotus_orb_active') then score = score - 22 end
    if enemy:HasModifier('modifier_item_sphere_target') then score = score - 12 end
    if enemy:HasModifier('modifier_item_aeon_disk_buff') then score = score - 35 end
    return score
end

local function GetAllAllies(bot, radius, includeSelf)
    local result = {}
    local hasSelf = false
    for _, ally in pairs(J.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(ally) and ally:IsAlive() and not ally:IsIllusion() then
            table.insert(result, ally)
            if ally == bot then hasSelf = true end
        end
    end
    if includeSelf and not hasSelf then table.insert(result, bot) end
    return result
end

local function CountCommittedAllies(allies, enemy)
    local count = 0
    for _, ally in pairs(allies) do
        if ally:IsBot() and not J.IsRetreating(ally) or IsHumanCommitted(ally, enemy) then
            count = count + 1
        end
    end
    return count
end

function X.FindBotCombo(bot, radius)
    radius = radius or 1600
    local cached = bot._ohaComboCache
    if cached ~= nil
        and DotaTime() - cached.time < 0.18
        and cached.result ~= nil
        and IsUsableEnemy(cached.result.target)
    then
        return cached.result
    end
    local enemies = J.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}
    local allies = GetAllAllies(bot, 1800, true)
    local target = SelectFocusTarget(bot, enemies, allies, J.GetProperTarget(bot), true, true)
    if not IsUsableEnemy(target) then return nil end

    local damage = GetBotComboDamage(allies, target)
    local effectiveHealth = target:GetHealth() + target:GetHealthRegen() * 4
    local killRatio = damage / math.max(1, effectiveHealth)
    local visibleEnemies = 0
    for _, enemy in pairs(enemies) do
        if IsUsableEnemy(enemy) then visibleEnemies = visibleEnemies + 1 end
    end
    local committedAllies = CountCommittedAllies(allies, target)
    local safeNumbers = committedAllies >= visibleEnemies
    local canKill = killRatio >= 0.95
        and (safeNumbers or killRatio >= 1.18)
        and CombatSafety.CanCommit(bot, target, killRatio)
    local result = {
        target = target,
        damage = damage,
        killRatio = killRatio,
        canKill = canKill,
        allies = committedAllies,
        enemies = visibleEnemies,
    }
    bot._ohaComboCache = { time = DotaTime(), result = result }
    return result
end

SelectFocusTarget = function(bot, enemies, allies, fallback, isTeamFight, isEngaging)
    if not isTeamFight and not isEngaging then return fallback end

    local now = DotaTime()
    local held = bot._ohaFocusTarget
    if bot._ohaFocusUntil ~= nil
        and now < bot._ohaFocusUntil
        and IsUsableEnemy(held)
        and GetUnitToUnitDistance(bot, held) <= 1800
    then
        return held
    end

    local best = nil
    local bestScore = -math.huge
    local heldScore = -math.huge
    for _, enemy in pairs(enemies) do
        if IsUsableEnemy(enemy) then
            local score = GetFocusScore(bot, enemy, allies, fallback)
            if enemy == held then heldScore = score end
            if score > bestScore then
                best = enemy
                bestScore = score
            end
        end
    end

    if IsUsableEnemy(held)
        and GetUnitToUnitDistance(bot, held) <= 1800
        and heldScore + FOCUS_SWITCH_MARGIN >= bestScore
    then
        best = held
    end

    if best ~= nil then
        bot._ohaFocusTarget = best
        bot._ohaFocusUntil = now + FOCUS_HOLD_SECONDS
        if not bot:IsChanneling() and not bot:IsCastingAbility() then bot:SetTarget(best) end
        return best
    end

    bot._ohaFocusTarget = nil
    bot._ohaFocusUntil = nil
    return fallback
end

local function GetDisableRemaining(target)
    if target == nil then return 0 end
    local remaining = 0
    local modifierCount = target:NumModifiers()
    for index = 0, modifierCount - 1 do
        local name = target:GetModifierName(index)
        if type(name) == 'string' and (
            string.find(name, 'stun')
            or string.find(name, 'hex')
            or string.find(name, 'root')
            or string.find(name, 'nightmare')
            or string.find(name, 'taunt')
        ) then
            remaining = math.max(remaining, target:GetModifierRemainingDuration(index) or 0)
        end
    end
    return remaining
end

function X.Build(bot)
    local enemies = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}
    local allies = GetAllAllies(bot, 1600, false)
    local comboAllies = GetAllAllies(bot, 1800, true)
    local isTeamFight = J.IsInTeamFight(bot, 1200)
    local isEngaging = J.IsGoingOnSomeone(bot)
    local target = SelectFocusTarget(
        bot,
        enemies,
        comboAllies,
        J.GetProperTarget(bot),
        isTeamFight,
        isEngaging
    )

    local context = {
        bot = bot,
        target = target,
        enemies = enemies,
        allies = allies,
        hp = J.GetHP(bot),
        mp = J.GetMP(bot),
        level = bot:GetLevel(),
        mana = bot:GetMana(),
        maxMana = bot:GetMaxMana(),
        attackRange = bot:GetAttackRange(),
        isRetreating = J.IsRetreating(bot),
        isTeamFight = isTeamFight,
        isEngaging = isEngaging,
        isBusy = bot:IsUsingAbility() or bot:IsCastingAbility() or bot:IsChanneling(),
        queuedActions = bot:NumQueuedActions(),
        targetDisableRemaining = GetDisableRemaining(target),
        comboDamage = target ~= nil and GetBotComboDamage(comboAllies, target) or 0,
    }

    context.aetherRange = J.IsItemAvailable('item_aether_lens') ~= nil and 250 or 0
    return context
end

return X
