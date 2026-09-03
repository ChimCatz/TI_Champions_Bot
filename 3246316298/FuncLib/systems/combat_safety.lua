local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}

local function SafeNumber(call, fallback)
    local ok, value = pcall(call)
    if ok and type(value) == 'number' then return value end
    return fallback or 0
end

local function EstimatedDamage(attacker, target, seconds)
    return math.max(0, SafeNumber(function()
        return attacker:GetEstimatedDamageToTarget(true, target, seconds, DAMAGE_TYPE_ALL)
    end))
end

local function AttackDamageOverTime(attacker, target, seconds)
    local attackDamage = SafeNumber(function() return attacker:GetAttackDamage() end)
    local secondsPerAttack = math.max(0.35, SafeNumber(function()
        return attacker:GetSecondsPerAttack()
    end, 1.0))
    local rawDamage = attackDamage * math.max(1, seconds / secondsPerAttack)
    return math.max(0, SafeNumber(function()
        return target:GetActualIncomingDamage(rawDamage, DAMAGE_TYPE_PHYSICAL)
    end, rawDamage))
end

local function IsAttackThreat(unit, bot, target)
    local attackTarget = unit:GetAttackTarget()
    if attackTarget == bot then return true end
    return target ~= nil and target:IsHero() and GetUnitToUnitDistance(unit, bot) <= 650
end

function X.Evaluate(bot, target, seconds)
    seconds = seconds or 3.5
    local heroDamage = 0
    local creepDamage = 0
    local towerDamage = 0

    for _, enemy in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
            local damage = EstimatedDamage(enemy, bot, seconds)
            if enemy:GetAttackTarget() ~= bot and not enemy:IsFacingLocation(bot:GetLocation(), 45) then
                damage = damage * 0.55
            end
            heroDamage = heroDamage + damage
        end
    end

    for _, creep in pairs(bot:GetNearbyLaneCreeps(900, true) or {}) do
        if J.IsValid(creep) and IsAttackThreat(creep, bot, target) then
            local weight = creep:GetAttackTarget() == bot and 1.0 or 0.55
            creepDamage = creepDamage + AttackDamageOverTime(creep, bot, seconds) * weight
        end
    end

    local towerRisk = false
    local seenTowers = {}
    local function AddTowerThreat(tower, anticipated)
        if J.IsValidBuilding(tower) then
            if seenTowers[tower] then return end
            seenTowers[tower] = true
            towerRisk = true
            local focused = tower:GetAttackTarget() == bot or bot:WasRecentlyDamagedByTower(2.0)
            local weight = focused and 1.0 or (anticipated and 0.45 or 0.65)
            towerDamage = towerDamage + AttackDamageOverTime(tower, bot, seconds) * weight
        end
    end
    for _, tower in pairs(bot:GetNearbyTowers(1100, true) or {}) do
        AddTowerThreat(tower, false)
    end
    if target ~= nil then
        for _, tower in pairs(target:GetNearbyTowers(900, false) or {}) do
            AddTowerThreat(tower, true)
        end
    end

    local incoming = heroDamage + creepDamage + towerDamage
    local health = math.max(1, bot:GetHealth())
    local predictedHealth = health - incoming + bot:GetHealthRegen() * seconds
    local predictedRatio = predictedHealth / math.max(1, bot:GetMaxHealth())
    return {
        incoming = incoming,
        riskRatio = incoming / health,
        predictedHealth = predictedHealth,
        predictedRatio = predictedRatio,
        heroDamage = heroDamage,
        creepDamage = creepDamage,
        towerDamage = towerDamage,
        towerRisk = towerRisk,
        lethal = predictedHealth <= 0,
    }
end

function X.CanCommit(bot, target, killRatio)
    if not J.IsValidHero(target) or J.IsRetreating(bot) then return false end
    local forecast = X.Evaluate(bot, target, 3.5)
    if forecast.lethal or forecast.predictedRatio < 0.24 then return false end
    if forecast.towerRisk then
        if J.IsInLaningPhase() then
            local alliedCreepCover = 0
            local nearbyBotAllies = 0
            for _, creep in pairs(bot:GetNearbyLaneCreeps(1600, false) or {}) do
                if J.IsValid(creep) and GetUnitToUnitDistance(creep, target) <= 900 then
                    alliedCreepCover = alliedCreepCover + 1
                end
            end
            for _, ally in pairs(J.GetAlliesNearLoc(target:GetLocation(), 1100) or {}) do
                if ally ~= bot and J.IsValidHero(ally) and ally:IsBot() and not J.IsRetreating(ally) then
                    nearbyBotAllies = nearbyBotAllies + 1
                end
            end
            local towerFocused = false
            for _, tower in pairs(bot:GetNearbyTowers(1100, true) or {}) do
                if J.IsValidBuilding(tower) and tower:GetAttackTarget() == bot then
                    towerFocused = true
                    break
                end
            end
            if killRatio < 1.25
                or J.GetHP(bot) < 0.68
                or forecast.predictedRatio < 0.55
                or alliedCreepCover < 3
                or nearbyBotAllies < 1
                or towerFocused
            then
                return false
            end
        end
        if bot:WasRecentlyDamagedByTower(1.5) and forecast.predictedRatio < 0.48 then return false end
        if killRatio < 1.35 or forecast.predictedRatio < 0.38 then return false end
    end
    if forecast.creepDamage > bot:GetHealth() * 0.28 and killRatio < 1.15 then return false end
    return forecast.riskRatio <= (killRatio >= 1.2 and 0.82 or 0.62)
end

function X.ShouldEscape(bot, target)
    local forecast = X.Evaluate(bot, target, 2.5)
    return forecast.lethal
        or forecast.predictedRatio < 0.20
        or forecast.towerRisk and bot:WasRecentlyDamagedByTower(1.5) and forecast.predictedRatio < 0.42
end

return X
