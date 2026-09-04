local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}

-- Hard rule: no Roshan consideration at all before 30:00, no exceptions
-- (including a human ping - mode_roshan_generic.lua has its own separate
-- ping-based bypass, but it's gated behind this module's commitRoshan flag
-- as an unconditional first check, so keeping this strict here is sufficient
-- to block it regardless of what that file's own logic wants to do).
local MIN_ROSH_TIME = 30 * 60
local roshanCommitUntil = -math.huge
local cachedState = nil
local cachedAt = -100
local previousAllyAliveBots = nil

local function CountAlive(team)
    local count = 0
    for _, playerId in pairs(GetTeamPlayers(team)) do
        if IsHeroAlive(playerId) then count = count + 1 end
    end
    return count
end

-- "bots (not entire team)" - a human's presence/absence shouldn't factor
-- into whether the bots themselves have enough of a numbers edge to commit.
local function CountAliveBots(team)
    local count = 0
    for _, playerId in pairs(GetTeamPlayers(team)) do
        if IsPlayerBot(playerId) and IsHeroAlive(playerId) then count = count + 1 end
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
    local allyAliveBots = CountAliveBots(GetTeam())
    local enemyAlive = CountAlive(GetOpposingTeam())
    local ownSide = CountAlliesOnOwnSide()
    local majorityOnOwnSide = ownSide >= math.ceil(allyAlive / 2)
    -- Bots-only 2+ advantage is the sole criterion - no ping bypass, no
    -- lower minimum. A human's presence/absence doesn't count toward it.
    local numbersAdvantage = allyAliveBots >= enemyAlive + 2
        and majorityOnOwnSide
    -- Neither baseSafe nor numbersAdvantage checked enemies already at the pit
    -- itself, only map-wide alive count and ancient/high-ground proximity -
    -- so both teams could independently "qualify" for Roshan and walk into
    -- each other. Require a real local advantage over whoever is actually
    -- near Roshan right now.
    local roshanEnemies = location ~= nil and #(J.GetEnemiesNearLoc(location, 2000) or {}) or 0
    local baseSafe = J.GetEnemiesAroundAncient(GetBot(), 3000) == 0
        and J.Utils.CountEnemyHeroesOnHighGround(GetTeam()) < 2
        and (roshanEnemies == 0 or allyAliveBots >= roshanEnemies + 2)
    local damageReady = TeamHasEnoughRoshanDamage()
    local roshanUnlocked = DotaTime() >= MIN_ROSH_TIME
    if not roshanUnlocked then roshanCommitUntil = -math.huge end

    -- If a hero died while the team was already committed to Roshan, drop
    -- the commitment immediately rather than letting the sticky window ride
    -- it out - "forget the roshan and go back to the tactics."
    local diedDuringRoshan = cachedState ~= nil
        and cachedState.commitRoshan
        and previousAllyAliveBots ~= nil
        and allyAliveBots < previousAllyAliveBots
    if diedDuringRoshan then roshanCommitUntil = -math.huge end
    previousAllyAliveBots = allyAliveBots

    local qualified = not diedDuringRoshan
        and roshanUnlocked
        and J.IsRoshanAlive()
        and baseSafe
        and damageReady
        and numbersAdvantage
    if qualified then roshanCommitUntil = DotaTime() + 50 end
    local commitRoshan = not diedDuringRoshan
        and roshanUnlocked
        and J.IsRoshanAlive()
        and baseSafe
        and (qualified or DotaTime() < roshanCommitUntil)

    cachedState = {
        allyAlive = allyAlive,
        allyAliveBots = allyAliveBots,
        enemyAlive = enemyAlive,
        ownSide = ownSide,
        numbersAdvantage = numbersAdvantage,
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
