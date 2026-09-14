-- Dynamic comeback economy system. Bots-only, always - never triggered by
-- or applied to human players' net worth (matches the scope of the base
-- x1.5/x1.2 multiplier in economy_boost.lua).
--
-- Two effects, both driven by the same team net-worth gap:
-- 1. A rate SCALE (1.0 at even, up to 3.0 at a 10k+ gap) that
--    economy_boost.lua multiplies its own gold/XP multipliers by, so the
--    baseline 1.5x/1.2x becomes up to 4.5x/3.6x the further behind the
--    bot's team falls.
-- 2. A flat gold injection every 60s, scaling from 0 up to a 300g/min cap
--    at the same 10k gap, stacking on top of the rate scale.
local PlayerResourceLib = require(GetScriptDirectory() .. '/FuncLib/systems/player_resource')

local X = {}

local NETWORTH_SATURATION_GAP = 10000
local RATE_SCALE_MIN = 1.0
local RATE_SCALE_MAX = 3.0
local TIMER_BONUS_CAP = 300
local TIMER_INTERVAL = 60

local lastTimerTick = {}
local lastLog = {}
local totalTimerBonus = {}
local lastNetWorthErrorLog = -1e9

-- GetRateScale is read every single economy tick (every bot, every Think),
-- so the underlying team net-worth scan is cached briefly instead of
-- re-summing all 10 players' PlayerResource:GetNetWorth every call.
local cachedFrac = 0
local cachedFracTime = -1e9
local CACHE_SECONDS = 2.0

local function GetTeamNetWorth(pr, team)
    if pr == nil then return 0, 0 end
    local total = 0
    local errors = 0
    local ids = GetTeamPlayers(team) or {}
    for i = 1, #ids do
        local pid = ids[i]
        local ok, nw = pcall(function() return pr:GetNetWorth(pid) end)
        if ok and nw ~= nil then
            total = total + nw
        else
            errors = errors + 1
        end
    end
    return total, errors
end

local function ComputeGapFraction()
    local pr = PlayerResourceLib.Get()
    if pr == nil then return 0, 0, 0 end
    local ownNW, ownErr = GetTeamNetWorth(pr, GetTeam())
    local enemyNW, enemyErr = GetTeamNetWorth(pr, GetOpposingTeam())
    if ownErr + enemyErr > 0 then
        local now = DotaTime()
        if now >= lastNetWorthErrorLog + 30 then
            lastNetWorthErrorLog = now
            print('[TICB-CATCHUP][ERROR] GetNetWorth failed for ' ..
                tostring(ownErr + enemyErr) .. ' player(s) this check')
        end
    end
    local gap = enemyNW - ownNW
    local frac = 0
    if gap > 0 then
        frac = gap / NETWORTH_SATURATION_GAP
        if frac > 1 then frac = 1 end
    end
    return frac, ownNW, enemyNW
end

-- 0 = even or ahead, 1 = at/past the saturation gap.
function X.GetGapFraction(bot)
    if bot == nil then return 0 end
    local now = DotaTime()
    if now >= cachedFracTime + CACHE_SECONDS then
        cachedFracTime = now
        cachedFrac = ComputeGapFraction()
    end
    return cachedFrac
end

-- 1.0 (no change) up to 3.0 (baseline multipliers tripled) as the gap widens.
function X.GetRateScale(bot)
    local frac = X.GetGapFraction(bot)
    return RATE_SCALE_MIN + frac * (RATE_SCALE_MAX - RATE_SCALE_MIN)
end

function X.Think(bot)
    if bot == nil or not bot:IsBot() then return end
    local id = bot:GetPlayerID()
    if id == nil then return end

    local now = DotaTime()
    if now < (lastTimerTick[id] or 0) + TIMER_INTERVAL then return end
    lastTimerTick[id] = now

    local frac, ownNW, enemyNW = ComputeGapFraction()
    if frac > 0 then
        local bonus = math.floor(frac * TIMER_BONUS_CAP)
        local pr = PlayerResourceLib.Get()
        if bonus > 0 and pr ~= nil then
            local ok = pcall(function() pr:ModifyGold(id, bonus, false, 0) end)
            if ok then totalTimerBonus[id] = (totalTimerBonus[id] or 0) + bonus end
        end
    end

    -- Always logs every 60s regardless of frac, so a close/even match still
    -- proves the system is alive instead of going silent (the previous
    -- version only logged when frac>0, which meant a whole even match left
    -- zero evidence either way in the log).
    if now >= (lastLog[id] or -1e9) + 60 then
        lastLog[id] = now
        print('[TICB-CATCHUP] ' .. tostring(bot:GetUnitName()) .. ' ownNW=' ..
            tostring(math.floor(ownNW or 0)) .. ' enemyNW=' ..
            tostring(math.floor(enemyNW or 0)) .. ' gapFrac=' ..
            tostring(math.floor(frac * 100)) .. '% rateScale=' ..
            tostring(RATE_SCALE_MIN + frac * (RATE_SCALE_MAX - RATE_SCALE_MIN)) ..
            ' timerBonusTotal=' .. tostring(totalTimerBonus[id] or 0))
    end
end

return X
