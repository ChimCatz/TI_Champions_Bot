local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}

local function LaneForPosition(team, position)
    if position == 2 then return LANE_MID end
    if team == TEAM_RADIANT then
        if position == 1 or position == 5 then return LANE_BOT end
        return LANE_TOP
    end
    if position == 1 or position == 5 then return LANE_TOP end
    return LANE_BOT
end

function X.GetAssignedLane(bot)
    return LaneForPosition(bot:GetTeam(), J.GetPosition(bot) or 5)
end

function X.MarkReturnToLane(bot, reason, duration)
    bot._ticbReturnToLaneUntil = math.max(
        bot._ticbReturnToLaneUntil or -90,
        DotaTime() + (duration or 12)
    )
    bot._ticbReturnToLaneReason = reason or 'task_complete'
end

function X.ShouldReturnToLane(bot)
    if DotaTime() < 0 or DotaTime() > 18 * 60 then return false end
    if bot:GetActiveMode() == BOT_MODE_RETREAT or J.IsRetreating(bot) then return false end
    if bot:GetActiveMode() == BOT_MODE_RUNE and DotaTime() < (bot._ohaRuneHardPickupUntil or -90) then
        return false
    end
    if DotaTime() < (bot._ticbReturnToLaneUntil or -90) then return true end

    local lane = X.GetAssignedLane(bot)
    local anchor = GetLaneFrontLocation(bot:GetTeam(), lane, -700)
    local limit = (J.GetPosition(bot) or 5) <= 3 and 2600 or 3400
    return GetUnitToLocationDistance(bot, anchor) > limit
        and not bot:WasRecentlyDamagedByAnyHero(3)
        and #(bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE) or {}) == 0
end

function X.GetLaneReturnLocation(bot, lane)
    lane = lane or X.GetAssignedLane(bot)
    return GetLaneFrontLocation(bot:GetTeam(), lane, -750)
end

function X.GetSafeTowerLocation(bot, lane)
    lane = lane or X.GetAssignedLane(bot)
    local towerIds = {
        [LANE_TOP] = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 },
        [LANE_MID] = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 },
        [LANE_BOT] = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 },
    }
    local best, bestDistance = nil, math.huge
    for _, towerId in ipairs(towerIds[lane] or {}) do
        local tower = GetTower(bot:GetTeam(), towerId)
        if J.IsValidBuilding(tower) and tower:IsAlive() then
            local distance = GetUnitToUnitDistance(bot, tower)
            if distance < bestDistance then best, bestDistance = tower, distance end
        end
    end
    if best ~= nil then
        return J.GetXUnitsTowardsLocation2(best:GetLocation(), J.GetTeamFountain(), 350)
    end
    return J.GetTeamFountain()
end

function X.HasTowerCreepCover(bot, tower)
    if tower == nil then return true end
    local creeps = tower:GetNearbyLaneCreeps(850, true) or {}
    return #creeps >= 3
end

function X.IsUnsafeEnemyTowerArea(bot)
    local towers = bot:GetNearbyTowers(1050, true) or {}
    local tower = towers[1]
    if not J.IsValidBuilding(tower) then return false end
    if X.HasTowerCreepCover(bot, tower) then return false end
    return tower:GetAttackTarget() == bot
        or bot:WasRecentlyDamagedByTower(3)
        or GetUnitToUnitDistance(bot, tower) < 850
end

function X.GetPreferredLocation(bot, lane, proposed)
    local towers = bot:GetNearbyTowers(1200, true) or {}
    local tower = towers[1]
    if J.IsValidBuilding(tower) and not X.HasTowerCreepCover(bot, tower) then
        return X.GetSafeTowerLocation(bot, lane)
    end
    if X.ShouldReturnToLane(bot) then return X.GetLaneReturnLocation(bot, lane) end
    return proposed
end

return X
