local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local Diagnostics = require(GetScriptDirectory() .. '/FuncLib/systems/decision_log')
local DecisionPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/decision_policy')

local X = {}
local SEARCH_RADIUS = 1250
local GROUP_RADIUS = 1400
local LOCK_SECONDS = 3.2
local MIN_ACTIVATION_TIME = 30

-- Cores (pos 1-3) own a specific lane and must stay there while lane-locked
-- (pre-20:00/pre-T3) - no exceptions, this is exactly the cross-lane
-- "assisting" the lock is meant to eliminate. Supports (pos 4-5) are exempt
-- since roaming is their job.
local function IsNearOwnLane(bot)
    return not DecisionPolicy.IsLaneLocked(bot)
end

local function IsEnemy(unit)
    return J.IsValidHero(unit)
        and J.CanBeAttacked(unit)
        and not J.IsSuspiciousIllusion(unit)
        and not unit:HasModifier('modifier_dazzle_shallow_grave')
        and not unit:HasModifier('modifier_oracle_false_promise_timer')
        and not unit:HasModifier('modifier_abaddon_borrowed_time')
        and not unit:HasModifier('modifier_item_aeon_disk_buff')
end

local function CountBots(location, radius)
    local count = 0
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and ally:IsBot()
            and not ally:IsIllusion() and not J.IsRetreating(ally)
            and J.GetHP(ally) > 0.34
            and GetUnitToLocationDistance(ally, location) <= radius
        then
            count = count + 1
        end
    end
    return count
end

local function CountEnemies(location, radius)
    local count = 0
    for _, enemy in pairs(J.GetEnemiesNearLoc(location, radius) or {}) do
        if IsEnemy(enemy) then count = count + 1 end
    end
    return count
end

local function HasEnemyTower(target)
    return J.IsValidBuilding((target:GetNearbyTowers(900, false) or {})[1])
end

local function Score(bot, target, bots, enemies)
    local score = (bots - enemies) * 22
        + (1 - J.GetHP(target)) * 42
        - GetUnitToUnitDistance(bot, target) / 80
    if target:IsChanneling() or target:IsCastingAbility() then score = score + 36 end
    if J.IsDisabled(target) then score = score + 24 end
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and target:GetAttackTarget() == ally then
            score = score + 30
            break
        end
    end
    return score
end

local function Validate(bot, target)
    if not IsEnemy(target)
        or GetUnitToUnitDistance(bot, target) > 1550
        or J.GetHP(bot) < 0.40
        or J.IsRetreating(bot)
        or bot:WasRecentlyDamagedByTower(2.0)
        or HasEnemyTower(target)
    then
        return false, 0, 0
    end
    local location = target:GetLocation()
    local bots = CountBots(location, GROUP_RADIUS)
    local enemies = CountEnemies(location, GROUP_RADIUS + 100)
    return bots >= 3 and bots >= math.max(1, enemies), bots, enemies
end

function X.GetIntent(bot)
    if Customize.Enable == false or Customize.Coordinated_Punish_Enabled == false
        or bot == nil or not bot:IsAlive() or bot:IsIllusion() or DotaTime() < MIN_ACTIVATION_TIME
        or not IsNearOwnLane(bot)
    then
        return nil
    end

    local current = bot._ticbPunishIntent
    if current ~= nil and DotaTime() < current.untilTime then
        local valid, bots, enemies = Validate(bot, current.target)
        if valid then
            current.bots = bots
            current.enemies = enemies
            bot:SetTarget(current.target)
            return current
        end
    end

    local best = nil
    local bestScore = -math.huge
    for _, target in pairs(bot:GetNearbyHeroes(SEARCH_RADIUS, true, BOT_MODE_NONE) or {}) do
        local valid, bots, enemies = Validate(bot, target)
        if valid then
            local score = Score(bot, target, bots, enemies)
            if score > bestScore then
                bestScore = score
                best = { target = target, bots = bots, enemies = enemies }
            end
        end
    end
    if best == nil then
        bot._ticbPunishIntent = nil
        return nil
    end

    best.untilTime = DotaTime() + LOCK_SECONDS
    best.desire = 0.94
    bot._ticbPunishIntent = best
    bot:SetTarget(best.target)
    Diagnostics.Write(bot, 'FOCUS_TARGET', 'target=%s bots=%d enemies=%d lock=%.1f',
        best.target:GetUnitName(), best.bots, best.enemies, LOCK_SECONDS)
    return best
end

function X.GetBlinkTarget(bot, maximumRange)
    local intent = X.GetIntent(bot)
    if intent == nil then return nil end
    local target = intent.target
    local distance = GetUnitToUnitDistance(bot, target)
    if distance <= 500 or distance > maximumRange then return nil end
    if intent.bots < intent.enemies or intent.bots < 3 or HasEnemyTower(target) then return nil end
    Diagnostics.Write(bot, 'BLINK_READY', 'target=%s distance=%.0f bots=%d enemies=%d',
        target:GetUnitName(), distance, intent.bots, intent.enemies)
    return target
end

return X
