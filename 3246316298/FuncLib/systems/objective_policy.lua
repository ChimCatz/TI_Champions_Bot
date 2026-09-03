local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}

local MIN_ROSH_TIME = 15 * 60
local ROSH_PING_RADIUS = 650
local ROSH_PING_AGE = 6
local roshanCommitUntil = -math.huge
local cachedState = nil
local cachedAt = -100

local function CountAlive(team)
    local count = 0
    for _, playerId in pairs(GetTeamPlayers(team)) do
        if IsHeroAlive(playerId) then count = count + 1 end
    end
    return count
end

local function IsOnOwnSide(unit)
    return GetUnitToLocationDistance(unit, J.GetTeamFountain())
        <= GetUnitToLocationDistance(unit, J.GetEnemyFountain())
end

local function CountAlliesOnOwnSide()
    local count = 0
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsIllusion()
            and IsOnOwnSide(ally)
        then
            count = count + 1
        end
    end
    return count
end

local function HasRecentHumanRoshanPing(location)
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and not ally:IsBot() then
            local ping = ally:GetMostRecentPing()
            if ping ~= nil
                and ping.normal_ping
                and GameTime() - ping.time <= ROSH_PING_AGE
                and J.GetDistance(ping.location, location) <= ROSH_PING_RADIUS
            then
                return true
            end
        end
    end
    return false
end

local function TeamHasEnoughRoshanDamage()
    local allies = {}
    for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        if J.IsValidHero(ally) and ally:IsAlive() and ally:IsBot() and not ally:IsIllusion() then
            table.insert(allies, ally)
        end
    end
    return J.HasEnoughDPSForRoshan(allies)
end

function X.GetState()
    if cachedState ~= nil and DotaTime() - cachedAt < 0.25 then return cachedState end
    local location = J.GetCurrentRoshanLocation()
    local allyAlive = CountAlive(GetTeam())
    local enemyAlive = CountAlive(GetOpposingTeam())
    local ownSide = CountAlliesOnOwnSide()
    local majorityOnOwnSide = ownSide >= math.ceil(allyAlive / 2)
    local humanPing = location ~= nil and HasRecentHumanRoshanPing(location)
    local numbersAdvantage = allyAlive >= 3
        and allyAlive >= enemyAlive + 2
        and majorityOnOwnSide
    -- Neither baseSafe nor numbersAdvantage checked enemies already at the pit
    -- itself, only map-wide alive count and ancient/high-ground proximity -
    -- so both teams could independently "qualify" for Roshan (e.g. via a
    -- human ping each) and walk into each other at even numbers. Require a
    -- real local advantage over whoever is actually near Roshan right now.
    local roshanEnemies = location ~= nil and #(J.GetEnemiesNearLoc(location, 2000) or {}) or 0
    local baseSafe = J.GetEnemiesAroundAncient(GetBot(), 3000) == 0
        and J.Utils.CountEnemyHeroesOnHighGround(GetTeam()) < 2
        and (roshanEnemies == 0 or allyAlive >= roshanEnemies + 2)
    local damageReady = TeamHasEnoughRoshanDamage()
    local roshanUnlocked = DotaTime() >= MIN_ROSH_TIME
    if not roshanUnlocked then roshanCommitUntil = -math.huge end
    local qualified = roshanUnlocked
        and J.IsRoshanAlive()
        and baseSafe
        and damageReady
        and (numbersAdvantage or humanPing and allyAlive >= enemyAlive)
    if qualified then roshanCommitUntil = DotaTime() + 50 end
    local commitRoshan = roshanUnlocked
        and J.IsRoshanAlive()
        and baseSafe
        and (qualified or DotaTime() < roshanCommitUntil)

    cachedState = {
        allyAlive = allyAlive,
        enemyAlive = enemyAlive,
        ownSide = ownSide,
        numbersAdvantage = numbersAdvantage,
        humanPing = humanPing,
        damageReady = damageReady,
        commitRoshan = commitRoshan,
    }
    cachedAt = DotaTime()
    return cachedState
end

function X.ShouldCommitRoshan()
    return X.GetState().commitRoshan
end

function X.ShouldReserveForRoshan()
    return X.GetState().commitRoshan
end

return X
