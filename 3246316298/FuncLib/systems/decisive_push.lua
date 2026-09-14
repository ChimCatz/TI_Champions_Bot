local X = {}

local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local ObjectivePolicy = require(GetScriptDirectory() .. '/FuncLib/systems/objective_policy')
local DecisionPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/decision_policy')

local CACHE_TTL = 0.25
local TOWER_MOMENTUM_SECONDS = 20
local FIGHT_MOMENTUM_SECONDS = 18
local LANE_COMMIT_SECONDS = 15
local state = {
    lastUpdate = -100,
    active = false,
    decisive = false,
    lane = LANE_MID,
    allyAlive = 0,
    enemyAlive = 0,
    enemyTowerCount = nil,
    towerMomentumUntil = -100,
    fightMomentumUntil = -100,
    laneCommitUntil = -100,
    previousEnemyAlive = nil,
    teamHealth = 1,
}

local laneStructures = {
    [LANE_TOP] = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 },
    [LANE_MID] = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 },
    [LANE_BOT] = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 },
}

local barracksByLane = {
    [LANE_TOP] = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED },
    [LANE_MID] = { BARRACKS_MID_MELEE, BARRACKS_MID_RANGED },
    [LANE_BOT] = { BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED },
}

local function IsEnabled()
    return Customize.Enable ~= false and Customize.Decisive_Push_Enabled ~= false
end

local function CountAlive(team)
    local count = 0
    for _, playerId in pairs(GetTeamPlayers(team)) do
        if IsHeroAlive(playerId) then count = count + 1 end
    end
    return count
end

local function CountEnemyTowers(enemyTeam)
    local count = 0
    local towers = {
        TOWER_TOP_1, TOWER_MID_1, TOWER_BOT_1,
        TOWER_TOP_2, TOWER_MID_2, TOWER_BOT_2,
        TOWER_TOP_3, TOWER_MID_3, TOWER_BOT_3,
        TOWER_BASE_1, TOWER_BASE_2,
    }
    for _, towerId in pairs(towers) do
        local tower = GetTower(enemyTeam, towerId)
        if tower ~= nil and tower:IsAlive() then count = count + 1 end
    end
    return count
end

local function LaneProgress(enemyTeam, lane)
    for index, towerId in ipairs(laneStructures[lane]) do
        local tower = GetTower(enemyTeam, towerId)
        if tower ~= nil and tower:IsAlive() then return index end
    end
    for _, barracksId in pairs(barracksByLane[lane]) do
        local barracks = GetBarracks(enemyTeam, barracksId)
        if barracks ~= nil and barracks:IsAlive() then return 4 end
    end
    return 5
end

local function GetNextStructure(enemyTeam, lane)
    for _, towerId in ipairs(laneStructures[lane]) do
        local tower = GetTower(enemyTeam, towerId)
        if tower ~= nil and tower:IsAlive() then return tower end
    end
    for _, barracksId in pairs(barracksByLane[lane]) do
        local barracks = GetBarracks(enemyTeam, barracksId)
        if barracks ~= nil and barracks:IsAlive() then return barracks end
    end
    return GetAncient(enemyTeam)
end

local function GetTeamCenterAndHealth()
    local center = Vector(0, 0, 0)
    local health = 0
    local count = 0
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil and ally:IsAlive() and not ally:IsIllusion() then
            center = center + ally:GetLocation()
            health = health + ally:GetHealth() / math.max(1, ally:GetMaxHealth())
            count = count + 1
        end
    end
    if count == 0 then return GetAncient(GetTeam()):GetLocation(), 0 end
    return center / count, health / count
end

local function CountRecentEnemies(location, radius)
    local count = 0
    for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(playerId) then
            local seen = GetHeroLastSeenInfo(playerId)
            local info = seen ~= nil and seen[1] or nil
            if info ~= nil
                and info.time_since_seen < 3
                and (info.location - location):Length2D() <= radius
            then
                count = count + 1
            end
        end
    end
    return count
end

local function HumanPressureBonus(location)
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if ally ~= nil
            and ally:IsAlive()
            and not ally:IsBot()
            and GetUnitToLocationDistance(ally, location) <= 1800
        then
            return 38
        end
    end
    return 0
end

local function SelectLane(enemyTeam, decisive, now)
    if now < state.laneCommitUntil then return state.lane end
    local teamCenter = GetTeamCenterAndHealth()
    local bestLane = LANE_MID
    local bestScore = -math.huge
    for _, lane in pairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        local structure = GetNextStructure(enemyTeam, lane)
        local location = structure:GetLocation()
        local distance = (teamCenter - location):Length2D()
        local danger = decisive and 0 or CountRecentEnemies(location, 1800)
        local score = LaneProgress(enemyTeam, lane) * 12
            - distance / 170
            - danger * 32
            + HumanPressureBonus(location)
        if lane == LANE_MID then score = score + 5 end
        if score > bestScore then
            bestLane = lane
            bestScore = score
        end
    end
    state.laneCommitUntil = now + LANE_COMMIT_SECONDS
    return bestLane
end

local function UpdateState()
    local now = DotaTime()
    if now - state.lastUpdate < CACHE_TTL then return state end
    state.lastUpdate = now
    state.active = false
    state.decisive = false
    if not IsEnabled() then return state end

    local team = GetTeam()
    local enemyTeam = GetOpposingTeam()
    local enemyAncient = GetAncient(enemyTeam)
    if enemyAncient == nil or not enemyAncient:IsAlive() then return state end

    state.allyAlive = CountAlive(team)
    state.enemyAlive = CountAlive(enemyTeam)
    local _, teamHealth = GetTeamCenterAndHealth()
    state.teamHealth = teamHealth
    if state.previousEnemyAlive ~= nil
        and state.previousEnemyAlive - state.enemyAlive >= 2
        and state.allyAlive >= state.enemyAlive + 1
    then
        state.fightMomentumUntil = now + FIGHT_MOMENTUM_SECONDS
    end
    state.previousEnemyAlive = state.enemyAlive
    local towerCount = CountEnemyTowers(enemyTeam)
    if state.enemyTowerCount ~= nil and towerCount < state.enemyTowerCount then
        state.towerMomentumUntil = now + TOWER_MOMENTUM_SECONDS
    end
    state.enemyTowerCount = towerCount

    local minMinute = tonumber(Customize.Decisive_Push_Minute) or 10
    local minAllies = tonumber(Customize.Decisive_Push_Min_Allies) or 1
    if state.allyAlive < minAllies then return state end

    -- state.enemyAlive==0 is meant to mean "the whole enemy team just got
    -- wiped" (a real, decisive push signal), but IsHeroAlive() also
    -- legitimately returns false for a hero that simply hasn't spawned
    -- into the world yet. Right at game start, before all 5 heroes have
    -- finished spawning, this made CountAlive(enemyTeam) read 0 for a
    -- moment - a false "enemy wiped" reading with no minute/level gate
    -- (the minMinute check below only applies to the OTHER, "hasNumbers"
    -- branch) - and pulled a level-1 safelane carry off to push mid within
    -- the first minute of the match while their own lane sat empty. Guard
    -- the decisive-wipe branch with the same minimum-minute floor so it
    -- can never fire before the game has genuinely been running long
    -- enough for a real teamfight to have happened.
    local pastStartupWindow = DotaTime() >= 60
    state.decisive = pastStartupWindow and state.enemyAlive == 0
    if state.decisive then
        state.active = true
        state.lane = SelectLane(enemyTeam, true, now)
        return state
    end
    -- A complete wipe always means end the game; otherwise Roshan owns the advantage.
    if ObjectivePolicy.ShouldReserveForRoshan() then return state end
    if now < minMinute * 60 then return state end

    local hasNumbers = state.allyAlive >= 3
        and state.enemyAlive <= 3
        and state.allyAlive >= state.enemyAlive + 1
    local hasTowerMomentum = now <= state.towerMomentumUntil
        and state.allyAlive >= state.enemyAlive
    local hasFightMomentum = now <= state.fightMomentumUntil
        and state.allyAlive >= 3
        and state.allyAlive >= state.enemyAlive + 1
    state.active = state.teamHealth >= 0.42
        and (hasNumbers or hasTowerMomentum or hasFightMomentum)
    if state.active then state.lane = SelectLane(enemyTeam, false, now) end
    return state
end

function X.GetState() return UpdateState() end
function X.IsActive() return UpdateState().active end
function X.IsDecisive() return UpdateState().decisive end
function X.ShouldSuppressFarm() return UpdateState().active end
function X.ShouldSuppressSideObjectives() return UpdateState().decisive end

function X.GetPushDesire(bot, lane)
    -- No committed push, however decisive it looked a moment ago, is worth
    -- more than the enemy already being on our own base (item 20: creeps
    -- hitting the throne while everyone kept pushing mid "like nothing
    -- happened"). Bail out to nil so mode_push_tower_*'s desire falls
    -- through to Push.GetPushDesire, which carries the same base-defend
    -- check and will stand down too.
    if DecisionPolicy.ShouldDefendBase(bot) then return nil end
    local current = UpdateState()
    if not current.active then return nil end
    if lane ~= current.lane then return BOT_MODE_DESIRE_NONE end
    local health = bot:GetHealth() / math.max(1, bot:GetMaxHealth())
    local minHealth = tonumber(Customize.Decisive_Push_Min_Health) or 0.3
    if health < minHealth then return BOT_MODE_DESIRE_VERYLOW end
    if current.decisive then return BOT_MODE_DESIRE_OVERRIDE or 1.0 end
    return 0.86
end

return X
