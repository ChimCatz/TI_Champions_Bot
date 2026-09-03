local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local LaneDiscipline = require(GetScriptDirectory() .. '/FuncLib/systems/lane_discipline')

local X = {}
local RUNES = {
    RUNE_BOUNTY_1,
    RUNE_BOUNTY_2,
    RUNE_BOUNTY_3,
    RUNE_BOUNTY_4,
    RUNE_POWERUP_1,
    RUNE_POWERUP_2,
}
local BOUNTY_RUNES = {
    [RUNE_BOUNTY_1] = true,
    [RUNE_BOUNTY_2] = true,
    [RUNE_BOUNTY_3] = true,
    [RUNE_BOUNTY_4] = true,
}
local CLAIM_RADIUS = 900
local CLAIM_HOLD = 4.0
local PICKUP_RETRY_SECONDS = 2.25
local PICKUP_ORDER_INTERVAL = 0.15
local FAILED_RUNE_SUPPRESSION = 55

local function RuneLog(bot, event, rune, distance)
    local now = DotaTime()
    if event == 'TRY' and now < (bot._ohaRuneLastLog or -90) + 0.5 then return end
    bot._ohaRuneLastLog = now
    pcall(function()
        local team = bot:GetTeam() == TEAM_RADIANT and 'Radiant' or 'Dire'
        local location = bot:GetLocation()
        local loc = location ~= nil and string.format('(%.0f,%.0f)', location.x, location.y) or '(?,?)'
        print(string.format('[TICB-RUNE] %s team=%s pos=%s hero=%s loc=%s rune=%s type=%s status=%s distance=%.0f action=%s queued=%s',
            event, team, tostring(J.GetPosition(bot)), bot:GetUnitName(), loc, tostring(rune), tostring(GetRuneType(rune)),
            tostring(GetRuneStatus(rune)), distance or -1,
            tostring(bot:GetCurrentActionType()), tostring(bot:NumQueuedActions())))
    end)
end

function X.IsTemporarilySuppressed(bot, rune)
    local failed = bot._ohaRuneFailed
    return failed ~= nil and failed.rune == rune and DotaTime() < failed.untilTime
end

local function CountNearbyAllies(location, radius)
    local count = 0
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsIllusion()
            and GetUnitToLocationDistance(ally, location) <= radius
        then
            count = count + 1
        end
    end
    return count
end

local function IsHigherPriority(candidate, owner)
    local candidatePosition = J.GetPosition(candidate) or 5
    local ownerPosition = J.GetPosition(owner) or 5
    if candidatePosition ~= ownerPosition then return candidatePosition < ownerPosition end
    return (candidate:GetPlayerID() or 99) < (owner:GetPlayerID() or 99)
end

function X.GetRunes()
    return RUNES
end

function X.IsBountyRune(rune)
    return BOUNTY_RUNES[rune] == true
end

function X.IsLocallySafe(bot, location)
    if J.IsRetreating(bot) or J.GetHP(bot) < 0.42 then return false end
    local enemies = J.GetEnemiesNearLoc(location, 1100) or {}
    if #enemies == 0 then return true end
    local allies = CountNearbyAllies(location, 1100)
    if allies < #enemies then return false end
    return J.GetHP(bot) >= 0.52 or allies > #enemies
end

function X.IsDesignatedCollector(bot, rune)
    if X.IsTemporarilySuppressed(bot, rune) then return false end
    local location = GetRuneSpawnLocation(rune)
    local owner = bot
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally)
            and ally:IsAlive()
            and ally:IsBot()
            and not ally:IsIllusion()
            and GetUnitToLocationDistance(ally, location) <= CLAIM_RADIUS
            and IsHigherPriority(ally, owner)
        then
            owner = ally
        end
    end
    return owner == bot
end

local function IsCollectible(rune)
    local status = GetRuneStatus(rune)
    local runeType = GetRuneType(rune)
    return status == RUNE_STATUS_AVAILABLE
        and runeType ~= nil
        and runeType >= 0
end

function X.IsCollectible(rune)
    return rune ~= nil and IsCollectible(rune)
end

local function Commit(bot, rune)
    bot._ohaRuneCommitRune = rune
    bot._ohaRuneCommitUntil = DotaTime() + CLAIM_HOLD
end

function X.FindSafeAvailableRune(bot, radius)
    local committed = bot._ohaRuneCommitRune
    if committed ~= nil and DotaTime() < (bot._ohaRuneCommitUntil or -90) then
        local location = GetRuneSpawnLocation(committed)
        local distance = GetUnitToLocationDistance(bot, location)
        if distance <= radius
            and IsCollectible(committed)
            and X.IsDesignatedCollector(bot, committed)
            and X.IsLocallySafe(bot, location)
        then
            return committed, distance
        end
    end

    local bestRune = nil
    local bestDistance = math.huge
    for _, rune in pairs(RUNES) do
        local location = GetRuneSpawnLocation(rune)
        local distance = GetUnitToLocationDistance(bot, location)
        if distance <= radius
            and distance < bestDistance
            and IsCollectible(rune)
            and X.IsDesignatedCollector(bot, rune)
            and X.IsLocallySafe(bot, location)
        then
            bestRune = rune
            bestDistance = distance
        end
    end
    if bestRune ~= nil then Commit(bot, bestRune) end
    return bestRune, bestDistance
end

function X.FindImmediatePickup(bot, radius)
    return X.FindSafeAvailableRune(bot, radius or 300)
end

function X.TryImmediatePickup(bot, radius)
    if bot == nil or not bot:IsAlive() or bot:IsIllusion() then return false end
    local now = DotaTime()

    -- An attempt already underway (bot is within pickup range and has issued at
    -- least one order) presses through momentary IsLocallySafe/IsDesignatedCollector
    -- flicker instead of re-deriving eligibility every tick. Re-checking those on
    -- every Think() was cancelling near-complete pickups the instant an enemy
    -- passed within 1100 units, well before the rune's status could flip -
    -- producing hundreds of PICKUP_ABORTED with zero PICKUP_RESOLVED in practice.
    local inFlight = bot._ohaRunePickupAttempt
    if inFlight ~= nil
        and now - inFlight.started < PICKUP_RETRY_SECONDS
        and IsCollectible(inFlight.rune)
        and not J.IsRetreating(bot)
    then
        if now >= inFlight.lastOrder + PICKUP_ORDER_INTERVAL then
            inFlight.lastOrder = now
            inFlight.orders = inFlight.orders + 1
            bot:Action_PickUpRune(inFlight.rune)
            RuneLog(bot, 'TRY', inFlight.rune, GetUnitToLocationDistance(bot, GetRuneSpawnLocation(inFlight.rune)))
        end
        bot._ohaRuneHardPickupUntil = now + 0.3
        bot._ohaRunePickupUntil = now + 0.35
        return true
    end

    local rune, distance = X.FindImmediatePickup(bot, radius or 325)
    if rune == nil then
        local attempt = bot._ohaRunePickupAttempt
        if attempt ~= nil then
            local attemptLocation = GetRuneSpawnLocation(attempt.rune)
            local attemptDistance = GetUnitToLocationDistance(bot, attemptLocation)
            local resolved = attempt.orders > 0
                and attemptDistance <= 425
                and GetRuneStatus(attempt.rune) ~= RUNE_STATUS_AVAILABLE
            RuneLog(bot, resolved and 'PICKUP_RESOLVED' or 'PICKUP_ABORTED', attempt.rune, attemptDistance)
            LaneDiscipline.MarkReturnToLane(bot, resolved and 'rune_resolved' or 'rune_aborted', 16)
        end
        bot._ohaRuneHardPickupUntil = -90
        bot._ohaRunePickupAttempt = nil
        return false
    end

    local attempt = bot._ohaRunePickupAttempt
    if attempt == nil or attempt.rune ~= rune then
        attempt = { rune = rune, started = now, lastOrder = -90, orders = 0 }
        bot._ohaRunePickupAttempt = attempt
    end

    if now - attempt.started >= PICKUP_RETRY_SECONDS then
        bot._ohaRuneFailed = {
            rune = rune,
            untilTime = now + FAILED_RUNE_SUPPRESSION,
        }
        RuneLog(bot, 'PICKUP_TIMEOUT', rune, distance)
        bot._ohaRunePickupAttempt = nil
        bot._ohaRuneCommitRune = nil
        bot._ohaRuneCommitUntil = -90
        bot._ohaRuneHardPickupUntil = -90
        bot._ohaRunePickupUntil = -90
        bot:Action_ClearActions(false)
        LaneDiscipline.MarkReturnToLane(bot, 'rune_timeout', 16)
        return false
    end

    if now >= attempt.lastOrder + PICKUP_ORDER_INTERVAL then
        attempt.lastOrder = now
        attempt.orders = attempt.orders + 1
        -- The API supplies no success result. Reissuing the direct action is safer
        -- than trusting a queued command that the engine may leave unexecuted.
        bot:Action_PickUpRune(rune)
        RuneLog(bot, 'TRY', rune, distance)
    end
    bot._ohaRuneHardPickupUntil = now + 0.3
    bot._ohaRunePickupUntil = now + 0.35
    return true
end

local function IsOnOwnSide(location)
    return J.GetDistance(location, J.GetTeamFountain())
        <= J.GetDistance(location, J.GetEnemyFountain())
end

local function NearestRuneToLocation(runes, location, ownSideOnly)
    local best = nil
    local bestDistance = math.huge
    for _, rune in pairs(runes) do
        local runeLocation = GetRuneSpawnLocation(rune)
        if not ownSideOnly or IsOnOwnSide(runeLocation) then
            local distance = J.GetDistance(location, runeLocation)
            if distance < bestDistance then
                best = rune
                bestDistance = distance
            end
        end
    end
    return best
end

function X.GetPregameRune(bot)
    local position = J.GetPosition(bot)
    local lane = bot:GetAssignedLane() or LANE_MID
    local laneLocation = GetLaneFrontLocation(GetTeam(), lane, 0)
    if position == 2 then
        local rune = NearestRuneToLocation({ RUNE_POWERUP_1, RUNE_POWERUP_2 }, laneLocation, false)
        return X.IsCollectible(rune) and rune or nil
    end
    if position == 4 or position == 5 then
        local rune = NearestRuneToLocation({
            RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_BOUNTY_3, RUNE_BOUNTY_4,
        }, laneLocation, true)
        return X.IsCollectible(rune) and rune or nil
    end
    return nil
end

function X.ShouldInterruptSupportTask(bot)
    return X.FindSafeAvailableRune(bot, 750) ~= nil
end

return X
