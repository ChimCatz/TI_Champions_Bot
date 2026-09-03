local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local CreepPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/creep_policy')
local EconomyPhase = require(GetScriptDirectory() .. '/FuncLib/systems/economy_phase')
local Diagnostics = require(GetScriptDirectory() .. '/FuncLib/systems/decision_log')

local X = {}

local CORE_FARM_RADIUS = 1200
local MID_LANE_DUTY_END = EconomyPhase.END_TIME
local MID_UNSAFE_HOLD = 8
local HUMAN_ASSIST_MAX_DISTANCE = 6500
local HUMAN_ASSIST_RADIUS = 1500

local function IsHealthyResponder(unit)
    return J.IsValidHero(unit)
        and unit:IsAlive()
        and not unit:IsIllusion()
        and J.GetHP(unit) > 0.4
        and not J.IsRetreating(unit)
end

local function IsViableHuman(unit)
    return J.IsValidHero(unit)
        and unit:IsAlive()
        and not unit:IsIllusion()
        and not unit:IsBot()
        and J.GetHP(unit) > 0.18
end

function X.GetNearbyCore(bot, range)
    range = range or CORE_FARM_RADIUS
    local nearest = nil
    local nearestDistance = math.huge
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil
            and ally ~= bot
            and J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsIllusion()
            and J.GetPosition(ally) <= 3
        then
            local distance = GetUnitToUnitDistance(bot, ally)
            if distance <= range and distance < nearestDistance then
                nearest = ally
                nearestDistance = distance
            end
        end
    end
    return nearest
end

function X.ShouldYieldLaneCreeps(bot, range, creep)
    if J.GetPosition(bot) <= 3 then return false end
    if creep ~= nil then return CreepPolicy.ShouldSupportYield(bot, creep, range) end
    return X.GetNearbyCore(bot, range) ~= nil
end

local function GetMidThreat(bot)
    local front = GetLaneFrontLocation(GetTeam(), LANE_MID, 0)
    local enemies = J.GetEnemiesNearLoc(front, 1700) or {}
    local strongest = nil
    local strongestIncoming = 0

    for _, enemy in pairs(enemies) do
        if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
            local incoming = enemy:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
            if incoming > strongestIncoming then
                strongest = enemy
                strongestIncoming = incoming
            end
        end
    end
    return enemies, strongest, strongestIncoming
end

function X.ShouldMidTemporarilyJungle(bot, assignedLane)
    if J.GetPosition(bot) ~= 2 or assignedLane ~= LANE_MID then return false end
    local now = DotaTime()
    if now <= 0 or now >= MID_LANE_DUTY_END then return false end

    local midTower = GetTower(GetTeam(), TOWER_MID_1)
    if midTower ~= nil and midTower:IsAlive() then
        local towerEnemies = J.GetEnemiesNearLoc(midTower:GetLocation(), 1300) or {}
        if #towerEnemies > 0 then
            bot._ohaMidUnsafeUntil = nil
            return false
        end
    end

    local enemies, strongest, incoming = GetMidThreat(bot)
    local unsafe = #enemies >= 2
    if strongest ~= nil then
        local outgoing = bot:GetEstimatedDamageToTarget(true, strongest, 5, DAMAGE_TYPE_ALL)
        local levelGap = strongest:GetLevel() - bot:GetLevel()
        local losesTrade = incoming > bot:GetHealth() * 0.62
            and outgoing < strongest:GetHealth() * 0.58
        unsafe = unsafe
            or levelGap >= 2 and losesTrade
            or bot:WasRecentlyDamagedByHero(strongest, 3)
                and J.GetHP(bot) < 0.45
                and incoming > outgoing
    end

    if unsafe then
        bot._ohaMidUnsafeUntil = now + MID_UNSAFE_HOLD
        return true
    end

    if bot._ohaMidUnsafeUntil ~= nil and now < bot._ohaMidUnsafeUntil then
        return true
    end
    bot._ohaMidUnsafeUntil = nil
    return false
end

function X.ShouldCoreTemporarilyJungle(bot, assignedLane)
    local position = J.GetPosition(bot)
    if position == nil or position > 3 or not EconomyPhase.IsActive() then return false end
    if position == 2 then return X.ShouldMidTemporarilyJungle(bot, assignedLane) end

    local towerIds = { [LANE_TOP] = TOWER_TOP_1, [LANE_MID] = TOWER_MID_1, [LANE_BOT] = TOWER_BOT_1 }
    local alliedTower = GetTower(GetTeam(), towerIds[assignedLane] or TOWER_MID_1)
    if alliedTower ~= nil and alliedTower:IsAlive()
        and #(J.GetEnemiesNearLoc(alliedTower:GetLocation(), 1300) or {}) > 0
    then
        bot._ohaLaneRecoveryUntil = nil
        return false
    end

    local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
    local allies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
    local deaths = GetHeroDeaths(bot:GetPlayerID())
    local kills = GetHeroKills(bot:GetPlayerID())
    local losingRepeatedly = deaths >= 2 and kills + 1 < deaths and J.GetHP(bot) < 0.72
    local outnumbered = #enemies > #allies and #enemies >= 2
    local levelGap = 0
    for _, enemy in pairs(enemies) do
        if J.IsValidHero(enemy) then levelGap = math.max(levelGap, enemy:GetLevel() - bot:GetLevel()) end
    end
    local severeDisadvantage = levelGap >= 2 and #enemies >= #allies
        and (#enemies >= 1 or bot:WasRecentlyDamagedByAnyHero(4.0))

    local enemyTower = GetTower(GetOpposingTeam(), towerIds[assignedLane] or TOWER_MID_1)
    local front = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
    local waveDangerous = enemyTower ~= nil and enemyTower:IsAlive()
        and GetUnitToLocationDistance(enemyTower, front) <= 1350
        and #(bot:GetNearbyLaneCreeps(1200, false) or {}) < 3
        and #enemies >= #allies

    if losingRepeatedly or outnumbered or severeDisadvantage or waveDangerous then
        bot._ohaLaneRecoveryUntil = DotaTime() + 8
        Diagnostics.Write(bot, 'LANE_RECOVERY', 'jungle deaths=%d levelGap=%d enemies=%d allies=%d waveDanger=%s',
            deaths, levelGap, #enemies, #allies, tostring(waveDangerous))
        return true
    end
    if DotaTime() < (bot._ohaLaneRecoveryUntil or -90) then return true end
    bot._ohaLaneRecoveryUntil = nil
    return false
end

function X.ShouldSuppressEarlyMidFarm(bot)
    if J.GetPosition(bot) ~= 2 or DotaTime() <= 0 or DotaTime() >= MID_LANE_DUTY_END then
        return false
    end
    return not X.ShouldMidTemporarilyJungle(bot, LANE_MID)
end

local function SelectThreateningEnemy(human, enemies)
    local selected = nil
    local bestScore = -math.huge
    for _, enemy in pairs(enemies) do
        if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
            local score = (1 - J.GetHP(enemy)) * 40
            if enemy:GetAttackTarget() == human or enemy:GetTarget() == human then
                score = score + 45
            end
            if enemy:IsChanneling() then score = score + 50 end
            if score > bestScore then
                selected = enemy
                bestScore = score
            end
        end
    end
    return selected
end

local function GetResponderRank(bot, location)
    local botDistance = GetUnitToLocationDistance(bot, location)
    local rank = 1
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil and ally ~= bot and ally:IsBot() and IsHealthyResponder(ally) then
            if GetUnitToLocationDistance(ally, location) + 250 < botDistance then
                rank = rank + 1
            end
        end
    end
    return rank
end

function X.FindHumanAssist(bot)
    if DotaTime() < 6 * 60
        or J.GetHP(bot) < 0.45
        or J.IsRetreating(bot)
        or J.GetEnemiesAroundAncient(bot, 3200) > 0
    then
        return nil
    end

    local best = nil
    local bestScore = -math.huge
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local human = GetTeamMember(index)
        if human ~= nil and IsViableHuman(human) then
            local location = human:GetLocation()
            local distance = GetUnitToLocationDistance(bot, location)
            local enemies = J.GetEnemiesNearLoc(location, HUMAN_ASSIST_RADIUS) or {}
            local allies = J.GetAlliesNearLoc(location, HUMAN_ASSIST_RADIUS) or {}
            local underPressure = #enemies >= 2
                and (human:WasRecentlyDamagedByAnyHero(3) or J.GetHP(human) < 0.72)
            local feasible = #allies + 1 >= #enemies or J.GetHP(human) < 0.45

            if underPressure
                and feasible
                and distance > 150
                and distance <= HUMAN_ASSIST_MAX_DISTANCE
                and GetResponderRank(bot, location) <= 2
            then
                local score = #enemies * 25 - distance / 250 + (1 - J.GetHP(human)) * 45
                if score > bestScore then
                    bestScore = score
                    best = {
                        ally = human,
                        target = SelectThreateningEnemy(human, enemies),
                        location = location,
                        enemies = #enemies,
                        desire = J.GetHP(human) < 0.45 and 0.92 or 0.82,
                    }
                end
            end
        end
    end
    return best
end

return X
