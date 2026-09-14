-- Dynamic gold/XP comeback system for bots, running in the REAL game-rules
-- VScript context instead of the sandboxed per-bot AI script environment.
--
-- Why this file exists and can't just be part of the normal bot AI:
-- PlayerResource is unreachable from inside mode_*_generic.lua / any file
-- required through the automatic per-bot script loading path (confirmed
-- live: both the bare `PlayerResource` global and `GetPlayerResource()`
-- return nil from there - see FuncLib/systems/player_resource.lua and the
-- inert economy_boost.lua/catchup_boost.lua for that whole investigation).
-- This is not a bug in our code - Buff/README.md (this same repo, written
-- by the original author of the GPM/XP boost this is modeled on) says it
-- outright: "It would've been nice to call this within the bot script, but
-- I don't think it is possible." The only way to reach PlayerResource is
-- to run code in the real server VScript VM, which for a bot-only Workshop
-- item means manually injecting it via the dev console - there is no way
-- to make this happen automatically for a normal player. See the README
-- next to this file for the exact activation steps.
--
-- Design (rewritten after live reports of multi-level instant jumps - see
-- the big comment above DynamicComeback:TickTeam for what changed and why):
-- - FLAT gold/XP granted once per real 60s, per hero, never as a
--   multiplier on that hero's actual earnings.
-- - Each hero's own comeback fraction (0..1) is still computed from THEIR
--   net worth vs. the enemy team's average (per-hero, not team-wide - see
--   GetHeroRateScale), so a struggling hero on an otherwise-winning team
--   still gets more than an already-ahead teammate.
-- - Bots only, always - human players are never read from or written to.
-- - Hard per-hero, per-game caps on total gold/XP granted regardless of
--   any other calculation, so a logic bug anywhere in this file can never
--   produce more than a bounded, known amount of free gold/XP.

-- NOTE: this codebase's log() (FuncLib/systems/log.lua) is a permanent
-- no-op inside the bot-AI sandbox because IsDebug is hardcoded false there
-- (see global_overrides.lua). Buff.lua works around that by forcing
-- IsDebug=true after requiring it; this file just uses plain print()
-- everywhere instead, so it doesn't depend on that flag's state in this
-- separate script_reload_code execution context at all.
if GetScriptDirectory == nil then GetScriptDirectory = function() return "bots" end end
require('bots/Buff/Timers')
require('bots/Buff/Helper')

if DynamicComeback == nil then DynamicComeback = {} end

local NETWORTH_SATURATION_GAP = 10000
local RATE_SCALE_MIN = 1.0
local RATE_SCALE_MAX = 3.0
local TIMER_INTERVAL = 60

-- Flat per-minute grants only - no multiplier is ever applied to a hero's
-- actual gold/XP income. BASE_* is a small always-on trickle (present even
-- at zero gap); MAX_EXTRA_* is added on top, scaled 0..1 by that hero's own
-- comeback fraction, fully scaled at NETWORTH_SATURATION_GAP.
local BASE_GOLD_PER_MIN = 40
local MAX_EXTRA_GOLD_PER_MIN = 260
local BASE_XP_PER_MIN = 25
local MAX_EXTRA_XP_PER_MIN = 175

-- Safety net: even if every calculation above is somehow wrong, no hero can
-- ever receive more than this much total bonus gold/XP across a whole game.
-- At the max per-minute rate (300g / 200xp) these caps aren't reachable
-- until roughly minute 100, so they only ever matter if something breaks.
local HARD_CAP_TOTAL_GOLD = 18000
local HARD_CAP_TOTAL_XP = 12000

local lastTimerTick = {}
local totalGoldBonus = {}
local totalXpBonus = {}
local lastLog = {}

local BOT_STEAM_ID = nil -- resolved lazily; PlayerResource:GetSteamID(100) is the fake-client sentinel

local function IsBotPlayer(playerID)
    if BOT_STEAM_ID == nil then BOT_STEAM_ID = PlayerResource:GetSteamID(100) end
    local ok, steamID = pcall(function() return PlayerResource:GetSteamID(playerID) end)
    return ok and steamID == BOT_STEAM_ID
end

function DynamicComeback:GetTeamNetWorth(team)
    local total = 0
    local count = PlayerResource:GetPlayerCountForTeam(team)
    for i = 0, count - 1 do
        local pid = PlayerResource:GetNthPlayerIDOnTeam(team, i)
        if pid ~= nil and pid >= 0 then
            local ok, nw = pcall(function() return PlayerResource:GetNetWorth(pid) end)
            if ok and nw ~= nil then total = total + nw end
        end
    end
    return total
end

function DynamicComeback:GetRateScale(team, enemyTeam)
    local ownNW = self:GetTeamNetWorth(team)
    local enemyNW = self:GetTeamNetWorth(enemyTeam)
    local gap = enemyNW - ownNW
    if gap <= 0 then return RATE_SCALE_MIN, 0, ownNW, enemyNW end
    local frac = gap / NETWORTH_SATURATION_GAP
    if frac > 1 then frac = 1 end
    return RATE_SCALE_MIN + frac * (RATE_SCALE_MAX - RATE_SCALE_MIN), frac, ownNW, enemyNW
end

-- Per-hero scale, not team-wide: the old design applied ONE scale to every
-- bot on a team based only on the team's total net worth gap. That meant a
-- teammate who was already winning their lane snowballed even HARDER off
-- the multiplier (bigger raw gold/XP events * the same team-wide scale)
-- than the actual struggling hero on the same team, whose raw gold/XP
-- events were smaller to begin with - observed live as Earthshaker/Tiny
-- hitting level 30 with near-full builds by minute ~30 while their own
-- teammates (Monkey King/Shadow Shaman, the heroes actually behind) were
-- still level ~17. It also meant one hot lane (e.g. a crushing offlane)
-- could keep the WHOLE team's scale low even while other lanes on that
-- same team were genuinely behind.
-- This computes each bot's own scale from THEIR net worth against the
-- enemy team's average net worth, so an underperforming hero gets boosted
-- more than an already-ahead teammate even though they're on the same
-- team, and a team that's winning in aggregate but has one losing lane
-- still lifts that specific lane.
function DynamicComeback:GetHeroRateScale(pid, enemyTeam)
    local ok, heroNW = pcall(function() return PlayerResource:GetNetWorth(pid) end)
    if not ok or heroNW == nil then return RATE_SCALE_MIN, 0 end
    local enemyCount = PlayerResource:GetPlayerCountForTeam(enemyTeam)
    if enemyCount <= 0 then return RATE_SCALE_MIN, 0 end
    local enemyAvgNW = self:GetTeamNetWorth(enemyTeam) / enemyCount
    local gap = enemyAvgNW - heroNW
    if gap <= 0 then return RATE_SCALE_MIN, 0 end
    local frac = gap / NETWORTH_SATURATION_GAP
    if frac > 1 then frac = 1 end
    return RATE_SCALE_MIN + frac * (RATE_SCALE_MAX - RATE_SCALE_MIN), frac
end

local function OtherTeam(team)
    if team == DOTA_TEAM_GOODGUYS then return DOTA_TEAM_BADGUYS end
    return DOTA_TEAM_GOODGUYS
end

-- REWRITTEN: the previous version applied a multiplier to each hero's
-- REAL gold/XP delta on every ~1-second timer tick (Tick() below returns 1,
-- meaning it fires roughly once a second). Live matches showed multiple
-- heroes instantly jumping ~12 levels (18 -> 30) within a 5-10 second
-- window while team net worth was reportedly close to even - a jump far
-- too large to come from a bounded <=3.6x multiplier on normal per-tick
-- earnings, which points at GetCurrentXP()/delta tracking going wrong
-- around some edge case (level-up, respawn, hero handle refresh) rather
-- than the scale math itself. Rather than keep chasing that specific edge
-- case blind, this removes the entire "multiply a tracked delta" mechanism
-- - the class of bug it enables - in favor of a flat, bounded, once-per-
-- minute grant that cannot compound: it reads current gold/XP for logging
-- only and never derives a bonus from a delta between ticks.
function DynamicComeback:TickTeam(team)
    local enemyTeam = OtherTeam(team)
    local ownNW = self:GetTeamNetWorth(team)
    local enemyNW = self:GetTeamNetWorth(enemyTeam)
    local now = Helper.DotaTime()

    local count = PlayerResource:GetPlayerCountForTeam(team)
    for i = 0, count - 1 do
        local pid = PlayerResource:GetNthPlayerIDOnTeam(team, i)
        if pid ~= nil and pid >= 0 and IsBotPlayer(pid) then
            if now >= (lastTimerTick[pid] or 0) + TIMER_INTERVAL then
                lastTimerTick[pid] = now
                local _, frac = self:GetHeroRateScale(pid, enemyTeam)

                local goldBefore = PlayerResource:GetGold(pid)
                local goldBonus = math.floor(BASE_GOLD_PER_MIN + frac * MAX_EXTRA_GOLD_PER_MIN)
                local remainingGoldCap = HARD_CAP_TOTAL_GOLD - (totalGoldBonus[pid] or 0)
                if goldBonus > remainingGoldCap then goldBonus = remainingGoldCap end
                if goldBonus > 0 then
                    PlayerResource:ModifyGold(pid, goldBonus, false, 0)
                    totalGoldBonus[pid] = (totalGoldBonus[pid] or 0) + goldBonus
                end

                local xpBefore = 0
                local xpBonus = 0
                local player = PlayerResource:GetPlayer(pid)
                local hero = player ~= nil and player:GetAssignedHero() or nil
                if hero ~= nil and hero:IsAlive() then
                    local ok, xp = pcall(function() return hero:GetCurrentXP() end)
                    if ok and xp ~= nil then xpBefore = xp end
                    xpBonus = math.floor(BASE_XP_PER_MIN + frac * MAX_EXTRA_XP_PER_MIN)
                    local remainingXpCap = HARD_CAP_TOTAL_XP - (totalXpBonus[pid] or 0)
                    if xpBonus > remainingXpCap then xpBonus = remainingXpCap end
                    if xpBonus > 0 then
                        hero:AddExperience(xpBonus, 0, false, true)
                        totalXpBonus[pid] = (totalXpBonus[pid] or 0) + xpBonus
                    end
                end

                -- Analytics log: one line per hero per minute, grep-able by
                -- the TICB-COMEBACK-LOG tag, for post-game gold/XP-per-
                -- minute review independent of the live debug tag below.
                local heroName = hero ~= nil and hero:GetUnitName() or 'unknown'
                print('[TICB-COMEBACK-LOG] t=' .. tostring(math.floor(now)) ..
                    ' pid=' .. tostring(pid) ..
                    ' hero=' .. tostring(heroName) ..
                    ' team=' .. tostring(team) ..
                    ' level=' .. tostring(hero ~= nil and hero:GetLevel() or -1) ..
                    ' goldBefore=' .. tostring(goldBefore) ..
                    ' goldBonus=' .. tostring(goldBonus) ..
                    ' xpBefore=' .. tostring(xpBefore) ..
                    ' xpBonus=' .. tostring(xpBonus) ..
                    ' heroGapFrac=' .. tostring(math.floor(frac * 100)) .. '%' ..
                    ' cumGoldBonus=' .. tostring(totalGoldBonus[pid] or 0) ..
                    ' cumXpBonus=' .. tostring(totalXpBonus[pid] or 0))
            end

            if now >= (lastLog[pid] or -1e9) + 60 then
                lastLog[pid] = now
                print('[TICB-COMEBACK-LIVE] pid=' .. tostring(pid) ..
                    ' teamOwnNW=' .. tostring(math.floor(ownNW)) ..
                    ' teamEnemyNW=' .. tostring(math.floor(enemyNW)) ..
                    ' cumGoldBonus=' .. tostring(totalGoldBonus[pid] or 0) ..
                    ' cumXpBonus=' .. tostring(totalXpBonus[pid] or 0))
            end
        end
    end
end

function DynamicComeback:Tick()
    local ok, err = xpcall(function()
        self:TickTeam(DOTA_TEAM_GOODGUYS)
        self:TickTeam(DOTA_TEAM_BADGUYS)
    end, function(e) return e .. '\n' .. debug.traceback() end)
    if not ok then print('[TICB-COMEBACK-LIVE][ERROR] ' .. tostring(err)) end
    return 1
end

function DynamicComeback:Init()
    if GameRules:State_Get() < DOTA_GAMERULES_STATE_HERO_SELECTION then
        return 1
    end
    if self.waitTicks == nil then self.waitTicks = 0 end
    if GameRules:State_Get() < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self.waitTicks = self.waitTicks + 1
        return 1
    end
    if self.started then return end
    self.started = true
    print('[TICB-COMEBACK-LIVE] Dynamic comeback economy system started (live VScript context)')
    Timers:CreateTimer(function() return DynamicComeback:Tick() end)
end

if not DynamicComeback.isInitialized then
    DynamicComeback.isInitialized = true
    GameRules:SendCustomMessage('<font color="#1ce8b5">[TI Champions Bot] Dynamic comeback economy: activated.</font>', 0, 0)
    Timers:CreateTimer('DynamicComebackInit', { endTime = 1, callback = function() return DynamicComeback:Init() end })
else
    print('[TICB-COMEBACK-LIVE] Dynamic comeback economy has already been enabled for this game.')
end

return DynamicComeback
