local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local Site = require(GetScriptDirectory() .. '/FuncLib/data/site')
local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local RunePolicy = require(GetScriptDirectory() .. '/FuncLib/systems/rune_policy')
local CombatSafety = require(GetScriptDirectory() .. '/FuncLib/systems/combat_safety')
local DamageForecast = require(GetScriptDirectory() .. '/FuncLib/systems/damage_forecast')
local CreepPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/creep_policy')
local Diagnostics = require(GetScriptDirectory() .. '/FuncLib/systems/decision_log')
local EconomyPhase = require(GetScriptDirectory() .. '/FuncLib/systems/economy_phase')
local DecisionPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/decision_policy')
J.IsInLaningPhase = EconomyPhase.IsActive

local X = {}

local UPDATE_INTERVAL = 0.2
local LANE_END_TIME = EconomyPhase.END_TIME
local TASK_END_TIME = 18 * 60
local COMBAT_RADIUS = 1600
local TASK_DANGER_RADIUS = 1300
local OWN_LANE_LEASH = 2600

local function IsEnabled(name, default)
    if Customize.Enable == false then return false end
    local value = Customize[name]
    if value == nil then return default end
    return value ~= false
end

local function GetState(bot)
    if bot._ohaLaneTactics == nil then
        local playerId = bot:GetPlayerID() or 0
        bot._ohaLaneTactics = {
            kind = 'FARM',
            untilTime = -100,
            lastUpdate = -100,
            desire = 0,
            target = nil,
            camp = nil,
            phase = nil,
            phaseUntil = -100,
            taskStarted = -100,
            nextTaskAt = 75,
            nextCombatAt = -100,
            aggressionBias = 0.94 + (playerId % 5) * 0.03,
        }
    end
    return bot._ohaLaneTactics
end

local function IsValidEnemy(unit)
    return J.IsValidHero(unit)
        and not J.IsSuspiciousIllusion(unit)
        and J.CanBeAttacked(unit)
end

local function IsValidCreep(unit)
    return J.IsValid(unit) and unit:IsCreep() and unit:IsAlive()
end

local function GetLaneTower(team, lane)
    local towers = {
        [LANE_TOP] = TOWER_TOP_1,
        [LANE_MID] = TOWER_MID_1,
        [LANE_BOT] = TOWER_BOT_1,
    }
    return towers[lane] ~= nil and GetTower(team, towers[lane]) or nil
end

local function GetLaneCore(bot, lane)
    local best = nil
    local bestDistance = math.huge
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil
            and ally ~= bot
            and J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsIllusion()
            and J.GetPosition(ally) <= 3
            and ally:GetAssignedLane() == lane
        then
            local distance = GetUnitToUnitDistance(bot, ally)
            if distance < bestDistance then
                best = ally
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

local function GetVisibleEnemies(location, radius)
    local result = {}
    for _, enemy in pairs(J.GetEnemiesNearLoc(location, radius) or {}) do
        if IsValidEnemy(enemy) then table.insert(result, enemy) end
    end
    return result
end

local function GetAllies(location, radius)
    local result = {}
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and not ally:IsIllusion()
            and GetUnitToLocationDistance(ally, location) <= radius
        then
            table.insert(result, ally)
        end
    end
    return result
end

local function HasRecentUnseenThreat(target)
    local location = target:GetLocation()
    local targetId = target:GetPlayerID()
    for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if playerId ~= targetId and IsHeroAlive(playerId) then
            local info = GetHeroLastSeenInfo(playerId)
            local seen = info ~= nil and info[1] or nil
            if seen ~= nil and seen.time_since_seen <= 4.0
                and J.GetDistance(location, seen.location) <= 2500
            then
                return true
            end
        end
    end
    return false
end

local function IsHumanCommitted(ally, target)
    if ally:IsBot() or J.IsRetreating(ally) then return false end
    if GetUnitToUnitDistance(ally, target) > ally:GetAttackRange() + 350 then return false end
    local attackOk, attackTarget = pcall(function() return ally:GetAttackTarget() end)
    local targetOk, selectedTarget = pcall(function() return ally:GetTarget() end)
    return attackOk and attackTarget == target or targetOk and selectedTarget == target
end

local function SafeEstimatedDamage(attacker, target, seconds)
    local ok, damage = pcall(function()
        return attacker:GetEstimatedDamageToTarget(true, target, seconds, DAMAGE_TYPE_ALL)
    end)
    if ok and damage ~= nil then return math.max(0, damage) end
    return 0
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
            if ok and damage ~= nil and damage > 0 then
                total = total + math.min(damage, 450)
            else
                total = total + 18
            end
        end
    end
    return math.min(total, 700)
end

local function CountCreepsAttacking(bot)
    local count = 0
    for _, creep in pairs(bot:GetNearbyLaneCreeps(900, true) or {}) do
        if IsValidCreep(creep) and creep:GetAttackTarget() == bot then count = count + 1 end
    end
    return count
end

local function HasDyingCreep(bot)
    if J.GetPosition(bot) >= 4 then return false end
    local damage = bot:GetAttackDamage() * 1.55
    for _, creep in pairs(bot:GetNearbyLaneCreeps(math.min(1600, bot:GetAttackRange() + 450), true) or {}) do
        if IsValidCreep(creep) and creep:GetHealth() <= damage then return true end
    end
    return false
end

local function TargetHasProtection(target)
    return target:HasModifier('modifier_dazzle_shallow_grave')
        or target:HasModifier('modifier_oracle_false_promise_timer')
        or target:HasModifier('modifier_abaddon_borrowed_time')
        or target:HasModifier('modifier_item_aeon_disk_buff')
        or target:HasModifier('modifier_templar_assassin_refraction_absorb')
end

local function EvaluateTarget(bot, target)
    local location = target:GetLocation()
    local allies = GetAllies(location, 1500)
    local enemies = GetVisibleEnemies(location, 1800)
    local combinedDamage = 0
    local alliedHealth = 0
    local closeAllies = 0
    local combatAllies = 0
    for _, ally in pairs(allies) do
        local distance = GetUnitToUnitDistance(ally, target)
        local arrival = math.max(0, (distance - ally:GetAttackRange()) / math.max(220, ally:GetCurrentMovementSpeed()))
        local activeSeconds = math.max(1, 4.5 - arrival)
        local contributes = ally:IsBot() and not J.IsRetreating(ally) or IsHumanCommitted(ally, target)
        if contributes then
            combatAllies = combatAllies + 1
            local forecast = DamageForecast.ForHero(ally, target, activeSeconds)
            combinedDamage = combinedDamage + (ally:IsBot() and forecast.conservative or forecast.expected * 0.55)
            if ally ~= bot and distance <= 1100 then closeAllies = closeAllies + 1 end
        end
        alliedHealth = alliedHealth + ally:GetHealth()
    end

    local safety = CombatSafety.Evaluate(bot, target, 3.5)
    local enemyDamage = safety.incoming
    local effectiveHealth = target:GetHealth() + target:GetHealthRegen() * 4
    local killRatio = combinedDamage / math.max(1, effectiveHealth)
    local riskRatio = enemyDamage / math.max(1, bot:GetHealth() + bot:GetHealthRegen() * 3)
    local targetTower = target:GetNearbyTowers(850, false)
    local towerRisk = safety.towerRisk
        or targetTower ~= nil and J.IsValidBuilding(targetTower[1])
    local coordinated = false
    for _, ally in pairs(allies) do
        if ally ~= bot and (ally:GetTarget() == target or ally:GetAttackTarget() == target) then
            coordinated = true
            break
        end
    end

    local score = killRatio * 100
        - riskRatio * 42
        + (1 - J.GetHP(target)) * 24
        + (combatAllies - #enemies) * 9
        + (coordinated and 20 or 0)
        + (J.IsDisabled(target) and 18 or 0)
        - (towerRisk and 38 or 0)
        - (TargetHasProtection(target) and 60 or 0)

    return {
        target = target,
        allies = combatAllies,
        enemies = #enemies,
        killRatio = killRatio,
        riskRatio = riskRatio,
        towerRisk = towerRisk,
        score = score,
        alliedHealth = alliedHealth,
        closeAllies = closeAllies,
        safety = safety,
    }
end

local function IsCombatCommitValid(bot, state)
    if not IsValidEnemy(state.target) or DotaTime() >= state.untilTime then return false end
    if J.GetHP(bot) < (state.kind == 'KILL' and 0.34 or 0.48) then return false end
    if J.IsRetreating(bot) or bot:WasRecentlyDamagedByTower(1.5) then return false end
    if (state.kind == 'HARASS' or state.kind == 'PRESSURE') and CountCreepsAttacking(bot) >= 3 then return false end
    local evaluation = EvaluateTarget(bot, state.target)
    if not CombatSafety.CanCommit(bot, state.target, evaluation.killRatio) then return false end
    if evaluation.enemies > evaluation.allies and evaluation.killRatio < 1.18 then return false end
    if evaluation.towerRisk and (state.kind ~= 'KILL'
        or evaluation.killRatio < 1.25
        or evaluation.closeAllies == 0)
    then
        return false
    end
    if evaluation.closeAllies == 0 and evaluation.killRatio < 1.15 then return false end
    return GetUnitToUnitDistance(bot, state.target) <= 1400
end

local function SetCombatState(bot, state, kind, evaluation, desire, duration)
    local previous = state.kind
    state.kind = kind
    state.target = evaluation.target
    state.desire = desire
    state.untilTime = DotaTime() + duration
    state.camp = nil
    state.phase = nil
    bot:SetTarget(evaluation.target)
    Diagnostics.State(bot, previous, kind, string.format('target=%s ratio=%.2f risk=%.2f',
        evaluation.target:GetUnitName(), evaluation.killRatio, evaluation.riskRatio))
end

-- Cores (pos 1-3) each own a specific lane; without this, EvaluateCombat's
-- 1600-radius scan lets a bot chase/assist a fight in a different lane
-- entirely (e.g. a mid laner drifting down to gang up on the safelane),
-- abandoning its own duty for the whole 18-minute economy phase. Supports
-- (pos 4-5) are excluded since roaming/ganking is expected of them.
local function IsNearOwnLane(bot, lane)
    local position = J.GetPosition(bot)
    if position == nil or position > 3 then return true end
    local front = GetLaneFrontLocation(GetTeam(), lane, 0)
    return GetUnitToLocationDistance(bot, front) <= OWN_LANE_LEASH
end

local function EvaluateCombat(bot, lane)
    if not IsEnabled('Lane_Tactics_Enabled', true)
        or DotaTime() <= 0
        or DotaTime() >= LANE_END_TIME
        or DotaTime() < GetState(bot).nextCombatAt
        or J.GetHP(bot) < 0.42
        or J.IsRetreating(bot)
        or not IsNearOwnLane(bot, lane)
    then
        return nil
    end

    local enemies = bot:GetNearbyHeroes(COMBAT_RADIUS, true, BOT_MODE_NONE) or {}
    local best = nil
    for _, enemy in pairs(enemies) do
        if IsValidEnemy(enemy) then
            local evaluation = EvaluateTarget(bot, enemy)
            if best == nil or evaluation.score > best.score then best = evaluation end
        end
    end
    if best == nil then return nil end

    -- Pure farm focus: while lane-locked (pos 1-3, pre-20:00/pre-T3), skip
    -- the whole HARASS/PRESSURE decision tree entirely unless the bot was
    -- just directly attacked (a genuine defensive trade). Constant petty
    -- harassment at near-zero damage ratio was consuming 100% of a core's
    -- attention and leaving no time to last-hit. An exceptionally safe,
    -- clean kill is still allowed through even when untouched.
    if DecisionPolicy.IsLaneLocked(bot) and not bot:WasRecentlyDamagedByAnyHero(2.5) then
        if best.killRatio >= 1.5
            and best.riskRatio <= 0.15
            and best.enemies <= best.allies
            and not best.towerRisk
            and not TargetHasProtection(best.target)
            and CombatSafety.CanCommit(bot, best.target, best.killRatio)
        then
            return best, 'KILL'
        end
        return nil
    end

    local state = GetState(bot)
    local aggression = (tonumber(Customize.Lane_Aggression) or 1.0) * state.aggressionBias
    local numbersAcceptable = best.allies >= best.enemies
        or best.killRatio >= 1.18
        or J.IsDisabled(best.target)
    local killThreshold = 0.88 / math.max(0.75, aggression)
    if best.killRatio >= killThreshold
        and best.riskRatio <= 0.82 * aggression
        and numbersAcceptable
        and (best.closeAllies >= 1 or best.killRatio >= 1.15)
        and (not best.towerRisk or best.killRatio >= 1.25 and best.closeAllies >= 1)
        and not TargetHasProtection(best.target)
        and CombatSafety.CanCommit(bot, best.target, best.killRatio)
    then
        return best, 'KILL'
    end

    local priorityCreep = CreepPolicy.HasPriorityCreep(bot, 1200)
    if priorityCreep then return nil end

    local core, coreDistance = GetLaneCore(bot, bot:GetAssignedLane() or LANE_MID)
    local supportLeashed = J.GetPosition(bot) < 4 or core == nil or coreDistance <= 1400
    local isolatedAdvantage = best.allies >= 2
        and best.enemies == 1
        and not HasRecentUnseenThreat(best.target)
        and not best.towerRisk
        and best.riskRatio <= 0.62
        and supportLeashed
    if isolatedAdvantage then
        return best, 'PRESSURE'
    end

    if HasDyingCreep(bot) or J.GetHP(bot) < 0.52 then return nil end
    local enemyCreeps = CountCreepsAttacking(bot)
    local isolated = best.enemies <= 1
    local safeTrade = best.riskRatio <= 0.62 * aggression
        and enemyCreeps <= 2
        and not best.towerRisk
    local approachBuffer = J.GetPosition(bot) >= 4 and 550 or 300
    local inReach = GetUnitToUnitDistance(bot, best.target) <= math.min(1500, bot:GetAttackRange() + approachBuffer)
    if safeTrade and inReach and (best.allies >= best.enemies or isolated) then
        return best, 'HARASS'
    end
    return nil
end

local function CampRecord(index, attributes)
    return { idx = attributes.idx or index, cattr = attributes }
end

local function IsOwnCamp(attributes)
    return attributes ~= nil
        and attributes.location ~= nil
        and attributes.team == GetTeam()
        and attributes.type ~= 'ancient'
end

local function IsTaskOwner(bot, lane, location)
    local botDistance = GetUnitToLocationDistance(bot, location)
    local botId = bot:GetPlayerID() or 99
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil
            and ally ~= bot
            and ally:IsBot()
            and J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsIllusion()
            and J.GetPosition(ally) >= 4
            and ally:GetAssignedLane() == lane
        then
            local allyDistance = GetUnitToLocationDistance(ally, location)
            local allyId = ally:GetPlayerID() or 99
            if allyDistance + 100 < botDistance
                or math.abs(allyDistance - botDistance) <= 100 and allyId < botId
            then
                return false
            end
        end
    end
    return true
end

local function IsCampClaimed(bot, location)
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil
            and ally ~= bot
            and J.IsValidHero(ally)
            and ally:IsAlive()
            and ally:GetActiveMode() == BOT_MODE_FARM
            and GetUnitToLocationDistance(ally, location) <= 650
        then
            return true
        end
    end
    return false
end

local function GetCampCandidates(bot, lane, forPull)
    local candidates = {}
    local tower = GetLaneTower(GetTeam(), lane)
    local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
    local position = J.GetPosition(bot)
    for index, attributes in pairs(GetNeutralSpawners() or {}) do
        if IsOwnCamp(attributes) then
            local correctType = not forPull
                or position == 5 and attributes.type == 'small'
                or position == 4 and (attributes.type == 'large' or attributes.type == 'medium')
            if correctType then
                local botDistance = GetUnitToLocationDistance(bot, attributes.location)
                local towerDistance = tower ~= nil and GetUnitToLocationDistance(tower, attributes.location) or math.huge
                local laneDistance = (attributes.location - laneFront):Length2D()
                if botDistance <= (forPull and 2700 or 2400)
                    and (not forPull or towerDistance <= 3100 and laneDistance <= 3000)
                    and IsTaskOwner(bot, lane, attributes.location)
                    and not IsCampClaimed(bot, attributes.location)
                then
                    local score = forPull
                        and botDistance + towerDistance * 0.45 + laneDistance * 0.25
                        or botDistance + laneDistance * 0.10
                    table.insert(candidates, { camp = CampRecord(index, attributes), score = score })
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.score < b.score end)
    return candidates
end

local function IsCoreSafe(bot, lane)
    local core = GetLaneCore(bot, lane)
    if core == nil or J.GetHP(core) < 0.38 then return false end
    local enemies = GetVisibleEnemies(core:GetLocation(), 1400)
    local allies = GetAllies(core:GetLocation(), 1400)
    if core:WasRecentlyDamagedByAnyHero(2.0) and #enemies >= #allies then return false end
    return #enemies <= 1 or #allies > #enemies
end

local function IsWavePushed(lane)
    local tower = GetLaneTower(GetTeam(), lane)
    if tower == nil or not tower:IsAlive() then return false end
    local front = GetLaneFrontLocation(GetTeam(), lane, 0)
    return GetUnitToLocationDistance(tower, front) >= 1850
end

local function IsTaskSafe(bot, lane)
    if J.GetPosition(bot) < 4
        or lane == LANE_MID
        or DotaTime() < 75
        or DotaTime() >= TASK_END_TIME
        or J.GetHP(bot) < 0.48
        or J.IsRetreating(bot)
        or bot:WasRecentlyDamagedByAnyHero(2.0)
        or #GetVisibleEnemies(bot:GetLocation(), TASK_DANGER_RADIUS) > 0
    then
        return false
    end
    return IsCoreSafe(bot, lane)
end

local function FinishTask(state, delay)
    state.kind = 'FARM'
    state.desire = 0
    state.target = nil
    state.camp = nil
    state.phase = nil
    state.untilTime = -100
    state.phaseUntil = -100
    state.nextTaskAt = DotaTime() + (delay or 20)
end

local function StartTask(state, kind, camp)
    state.kind = kind
    state.camp = camp
    state.target = nil
    state.phase = 'APPROACH'
    state.taskStarted = DotaTime()
    state.untilTime = DotaTime() + (kind == 'STACK' and 18 or 24)
    state.desire = kind == 'PULL' and 0.78 or 0.74
end

local function SelectNeutralTask(bot, lane, state)
    if DotaTime() < state.nextTaskAt or not IsTaskSafe(bot, lane) then return false end
    local second = math.floor(DotaTime()) % 60
    local minute = math.floor(DotaTime() / 60)

    if IsEnabled('Support_Pulls_Enabled', true)
        and IsWavePushed(lane)
        and ((second >= 8 and second <= 19) or (second >= 38 and second <= 49))
    then
        local candidates = GetCampCandidates(bot, lane, true)
        if candidates[1] ~= nil then
            StartTask(state, 'PULL', candidates[1].camp)
            return true
        end
    end

    local nextMinuteHasBounty = (minute + 1) % 3 == 0
    if IsEnabled('Support_Stacks_Enabled', true)
        and not nextMinuteHasBounty
        and second >= 44
        and second <= 54
    then
        local candidates = GetCampCandidates(bot, lane, false)
        for _, candidate in pairs(candidates) do
            local destination = Site.GetCampMoveToStack(candidate.camp.idx)
            if destination ~= nil then
                local distance = (destination - candidate.camp.cattr.location):Length2D()
                if distance >= 250 and distance <= 2200 and IsLocationPassable(destination) then
                    candidate.camp.stackDestination = destination
                    StartTask(state, 'STACK', candidate.camp)
                    return true
                end
            end
        end
    end
    return false
end

local function Update(bot, lane)
    local state = GetState(bot)
    local now = DotaTime()
    if now - state.lastUpdate < UPDATE_INTERVAL then return state end
    state.lastUpdate = now

    if not IsEnabled('Lane_Tactics_Enabled', true) or now <= 0 or now >= LANE_END_TIME then
        FinishTask(state, 5)
        return state
    end

    if state.kind == 'KILL' or state.kind == 'HARASS' or state.kind == 'PRESSURE' then
        if IsCombatCommitValid(bot, state) then
            bot:SetTarget(state.target)
            return state
        end
        state.nextCombatAt = now + (state.kind == 'KILL' and 2.5 or 1.6)
        FinishTask(state, 0.4)
    end

    if state.kind == 'PULL' or state.kind == 'STACK' then
        if RunePolicy.ShouldInterruptSupportTask(bot) then
            FinishTask(state, 3)
            return state
        end
        if now < state.untilTime and IsTaskSafe(bot, lane) then
            local evaluation, combatKind = EvaluateCombat(bot, lane)
            if evaluation ~= nil and combatKind == 'KILL' then
                SetCombatState(bot, state, 'KILL', evaluation, 0.90, 6.0)
            end
            return state
        end
        FinishTask(state, 15)
    end

    local evaluation, combatKind = EvaluateCombat(bot, lane)
    if evaluation ~= nil then
        if combatKind == 'KILL' then
            SetCombatState(bot, state, 'KILL', evaluation, 0.90, 6.0)
        elseif combatKind == 'PRESSURE' then
            SetCombatState(bot, state, 'PRESSURE', evaluation, 0.80, 3.0)
        else
            local desire = J.GetPosition(bot) >= 4 and 0.76 or 0.72
            SetCombatState(bot, state, 'HARASS', evaluation, desire, 3.0)
        end
        return state
    end

    if not RunePolicy.ShouldInterruptSupportTask(bot) and not DecisionPolicy.IsLaneLocked(bot) then
        SelectNeutralTask(bot, lane, state)
    end
    return state
end

local function GetNearestNeutral(bot)
    local best = nil
    local bestDistance = math.huge
    for _, creep in pairs(bot:GetNearbyNeutralCreeps(900) or {}) do
        if IsValidCreep(creep) then
            local distance = GetUnitToUnitDistance(bot, creep)
            if distance < bestDistance then
                best = creep
                bestDistance = distance
            end
        end
    end
    return best
end

local function GetNearestAlliedLaneCreep(bot)
    local best = nil
    local bestDistance = math.huge
    for _, creep in pairs(bot:GetNearbyLaneCreeps(1600, false) or {}) do
        if IsValidCreep(creep) then
            local distance = GetUnitToUnitDistance(bot, creep)
            if distance < bestDistance then
                best = creep
                bestDistance = distance
            end
        end
    end
    return best
end

local function ThinkStack(bot, lane, state)
    local campLocation = state.camp.cattr.location
    if state.phase == 'APPROACH' then
        if GetUnitToLocationDistance(bot, campLocation) > 450 then
            bot:Action_MoveToLocation(campLocation)
            return true
        end
        state.phase = 'WAIT'
    end

    if state.phase == 'WAIT' then
        local neutral = GetNearestNeutral(bot)
        local second = DotaTime() % 60
        local stackTime = Site.GetCampStackTime(state.camp)
        if neutral == nil then
            if second >= 57 then FinishTask(state, 25) else bot:Action_MoveToLocation(campLocation) end
            return true
        end
        local projectileSpeed = bot:GetAttackProjectileSpeed()
        local flight = projectileSpeed > 0 and GetUnitToUnitDistance(bot, neutral) / projectileSpeed or 0
        local trigger = stackTime - bot:GetAttackPoint() - flight
        if second >= trigger then
            state.target = neutral
            state.phase = 'AGGRO'
            state.phaseUntil = DotaTime() + bot:GetAttackPoint() + 0.12
            bot:Action_AttackUnit(neutral, true)
        else
            bot:Action_MoveToLocation(campLocation)
        end
        return true
    end

    if state.phase == 'AGGRO' then
        if DotaTime() >= state.phaseUntil then state.phase = 'DRAG' end
        return true
    end

    if state.phase == 'DRAG' then
        bot:Action_MoveToLocation(state.camp.stackDestination)
        if DotaTime() % 60 <= 3 or DotaTime() - state.taskStarted > 17 then
            FinishTask(state, 24)
        end
        return true
    end
    FinishTask(state, 20)
    return false
end

local function IsPullConnected(bot)
    local neutrals = bot:GetNearbyNeutralCreeps(1000) or {}
    local laneCreeps = bot:GetNearbyLaneCreeps(1000, false) or {}
    for _, neutral in pairs(neutrals) do
        if IsValidCreep(neutral) then
            local target = neutral:GetAttackTarget()
            if target ~= nil and target:GetTeam() == GetTeam() and target:IsCreep() then return true end
        end
    end
    for _, creep in pairs(laneCreeps) do
        if IsValidCreep(creep) then
            local target = creep:GetAttackTarget()
            if target ~= nil and target:GetTeam() == TEAM_NEUTRAL then return true end
        end
    end
    return false
end

local function ThinkPull(bot, lane, state)
    local campLocation = state.camp.cattr.location
    if state.phase == 'APPROACH' then
        if GetUnitToLocationDistance(bot, campLocation) > 500 then
            bot:Action_MoveToLocation(campLocation)
            return true
        end
        state.phase = 'WAIT'
    end

    if state.phase == 'WAIT' then
        local second = DotaTime() % 60
        local neutral = GetNearestNeutral(bot)
        local waveCreep = GetNearestAlliedLaneCreep(bot)
        local inWindow = second >= 12 and second <= 20 or second >= 42 and second <= 50
        if neutral ~= nil and waveCreep ~= nil and inWindow then
            state.target = neutral
            state.pullDestination = waveCreep:GetLocation()
            state.phase = 'AGGRO'
            state.phaseUntil = DotaTime() + bot:GetAttackPoint() + 0.12
            bot:Action_AttackUnit(neutral, true)
            return true
        end
        if second > 21 and second < 38 or second > 51 then
            FinishTask(state, 18)
        else
            bot:Action_MoveToLocation(campLocation)
        end
        return true
    end

    if state.phase == 'AGGRO' then
        if DotaTime() >= state.phaseUntil then
            state.phase = 'DRAG'
            state.phaseUntil = DotaTime() + 7
        end
        return true
    end

    if state.phase == 'DRAG' then
        local waveCreep = GetNearestAlliedLaneCreep(bot)
        if waveCreep ~= nil then state.pullDestination = waveCreep:GetLocation() end
        local destination = state.pullDestination or GetLaneFrontLocation(GetTeam(), lane, -300)
        bot:Action_MoveToLocation(destination)
        if IsPullConnected(bot) and DotaTime() - state.taskStarted > 3 then
            FinishTask(state, 22)
        elseif DotaTime() >= state.phaseUntil then
            FinishTask(state, 18)
        end
        return true
    end
    FinishTask(state, 18)
    return false
end

function X.GetCombatIntent(bot, lane)
    lane = lane or bot:GetAssignedLane() or LANE_MID
    local state = Update(bot, lane)
    if state.kind == 'KILL' or state.kind == 'HARASS' or state.kind == 'PRESSURE' then
        return { kind = state.kind, target = state.target, desire = state.desire }
    end
    return nil
end

function X.GetTaskIntent(bot, lane)
    lane = lane or bot:GetAssignedLane() or LANE_MID
    local state = Update(bot, lane)
    if state.kind == 'PULL' or state.kind == 'STACK' then
        return { kind = state.kind, desire = state.desire, camp = state.camp }
    end
    return nil
end

function X.ThinkTask(bot, lane)
    lane = lane or bot:GetAssignedLane() or LANE_MID
    local state = Update(bot, lane)
    if state.kind == 'STACK' and state.camp ~= nil then return ThinkStack(bot, lane, state) end
    if state.kind == 'PULL' and state.camp ~= nil then return ThinkPull(bot, lane, state) end
    return false
end

function X.GetPreferredLaneLocation(bot, lane, fallback)
    if J.GetPosition(bot) < 4 then return fallback end
    local front = GetLaneFrontLocation(GetTeam(), lane, 0)
    local ancient = GetAncient(GetTeam())
    if ancient == nil then return fallback end
    local origin = ancient:GetLocation()
    local dx = front.x - origin.x
    local dy = front.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return fallback end
    dx = dx / length
    dy = dy / length
    local back = math.max(350, bot:GetAttackRange() * 0.55)
    local side = ((bot:GetPlayerID() or 0) % 2 == 0) and 300 or -300
    local location = Vector(front.x - dx * back - dy * side, front.y - dy * back + dx * side, front.z)
    if IsLocationPassable(location) then return location end
    return fallback
end

function X.IsNeutralTaskActive(bot)
    local state = GetState(bot)
    return state.kind == 'PULL' or state.kind == 'STACK'
end

function X.IsEconomyPhase()
    return EconomyPhase.IsActive()
end

return X
