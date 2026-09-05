local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local FarmTiming = require(GetScriptDirectory() .. '/FuncLib/systems/farm_timing')

local X = {}
local enabled = Customize.Enable ~= false and Customize.Laning_Diagnostics == true
local interval = tonumber(Customize.Diagnostic_Min_Interval) or 1.5
local last = {}
local function Output(message)
    if type(print) == 'function' then
        pcall(print, message)
    end
end

-- Stable, cheap key used only for the log-throttle cache. Must not include
-- anything that changes every tick (like location), or the throttle is defeated.
local function BotKey(bot)
    if bot == nil then return 'global' end
    return tostring(bot:GetPlayerID() or -1) .. ':' .. tostring(bot:GetUnitName())
end

local LANE_NAMES = { [LANE_TOP] = 'TOP', [LANE_MID] = 'MID', [LANE_BOT] = 'BOT' }

-- Full descriptive label used in the printed line: team, position, hero,
-- assigned lane, and current world location, so match observations can be
-- correlated with the log without re-explaining who/where every time.
local function BotLabel(bot)
    if bot == nil then return 'global' end
    local okTeam, team = pcall(function() return bot:GetTeam() == TEAM_RADIANT and 'Radiant' or 'Dire' end)
    team = okTeam and team or '?'
    local okPos, position = pcall(function() return J.GetPosition(bot) end)
    local okLane, lane = pcall(function() return bot:GetAssignedLane() end)
    lane = okLane and (LANE_NAMES[lane] or 'NONE') or '?'
    local okLoc, location = pcall(function() return bot:GetLocation() end)
    local loc = (okLoc and location ~= nil) and string.format('(%.0f,%.0f)', location.x, location.y) or '(?,?)'
    return string.format('%s:pos%s:%s:lane=%s:loc=%s',
        team, tostring(okPos and position or '?'), tostring(bot:GetUnitName()), lane, loc)
end

function X.IsEnabled()
    return enabled
end

function X.Write(bot, category, formatString, ...)
    if not enabled then return end
    local key = BotKey(bot) .. ':' .. tostring(category)
    local now = DotaTime()
    if now < (last[key] or -90) + interval then return end
    last[key] = now
    local message = select('#', ...) > 0 and string.format(formatString, ...) or formatString
    Output(string.format('[TICB-DIAG][%s][%s][%.1f] %s', category, BotLabel(bot), now, message))
end

function X.State(bot, previous, current, reason)
    if previous == current then return end
    X.Write(bot, 'LANE_STATE', '%s -> %s reason=%s', tostring(previous), tostring(current), tostring(reason))
end

local heartbeatLast = {}
local HEARTBEAT_INTERVAL = 10

-- BOT_MODE_* are engine globals whose numeric values aren't documented
-- anywhere in this codebase and have shifted across Dota versions as Valve
-- added modes (Outpost, etc.) - a bare mode number in a log is not reliably
-- identifiable later. Resolve against the live constants instead of a
-- hardcoded table so this is always correct for whatever version is running.
local modeConstantNames = {
    'BOT_MODE_NONE', 'BOT_MODE_LANING', 'BOT_MODE_ATTACK', 'BOT_MODE_FARM',
    'BOT_MODE_PUSH_TOWER_TOP', 'BOT_MODE_PUSH_TOWER_MID', 'BOT_MODE_PUSH_TOWER_BOT',
    'BOT_MODE_DEFEND_TOWER_TOP', 'BOT_MODE_DEFEND_TOWER_MID', 'BOT_MODE_DEFEND_TOWER_BOT',
    'BOT_MODE_ASSEMBLE', 'BOT_MODE_TEAM_ROAM', 'BOT_MODE_ROSHAN', 'BOT_MODE_SECRET_SHOP',
    'BOT_MODE_RUNE', 'BOT_MODE_RETREAT', 'BOT_MODE_ITEM', 'BOT_MODE_WARD',
    'BOT_MODE_ASSEMBLE_WITH_HUMANS', 'BOT_MODE_DEFEND_ALLY', 'BOT_MODE_EVASIVE_MANEUVERS',
    'BOT_MODE_ROAM', 'BOT_MODE_LOTS_OF_DEATHS', 'BOT_MODE_OUTPOST',
}
local modeNameByValue = nil
local function ModeName(mode)
    if modeNameByValue == nil then
        modeNameByValue = {}
        for _, name in ipairs(modeConstantNames) do
            local ok, value = pcall(function() return _G[name] end)
            if ok and value ~= nil then modeNameByValue[value] = name:gsub('^BOT_MODE_', '') end
        end
    end
    return modeNameByValue[mode] or tostring(mode)
end

-- Unconditional periodic snapshot (every 10s per bot, independent of the
-- LANE_STATE/LANE_RECOVERY throttle above) so a full match has a
-- position/status trail even for bots that never trigger another category -
-- requested so match reviews don't need extra explanation of who was where.
local laneValidated = {}

function X.Heartbeat(bot)
    if not enabled or bot == nil then return end
    local key = BotKey(bot)
    local now = DotaTime()
    if now < (heartbeatLast[key] or -1e9) + HEARTBEAT_INTERVAL then return end
    heartbeatLast[key] = now
    -- Position/weight is validated immediately at pick time (farm_timing.lua),
    -- but GetAssignedLane() isn't resolved yet then - it reliably is by this
    -- point, so the lane half of that same check runs here instead, once.
    if not laneValidated[key] then
        laneValidated[key] = true
        local okPos, position = pcall(J.GetPosition, bot)
        if okPos and position ~= nil then
            FarmTiming.ValidateLane(bot, position, bot:GetTeam())
        end
    end
    local okHp, hpPct = pcall(function() return 100 * bot:GetHealth() / math.max(1, bot:GetMaxHealth()) end)
    local okMp, mpPct = pcall(function() return 100 * bot:GetMana() / math.max(1, bot:GetMaxMana()) end)
    local okLvl, level = pcall(function() return bot:GetLevel() end)
    local okGold, gold = pcall(function() return bot:GetGold() end)
    local okMode, mode = pcall(function() return bot:GetActiveMode() end)
    local okKda, kills, deaths, assists = pcall(function()
        local id = bot:GetPlayerID()
        return GetHeroKills(id), GetHeroDeaths(id), GetHeroAssists(id)
    end)
    local okTarget, target = pcall(function()
        local t = bot:GetTarget()
        return t ~= nil and t:GetUnitName() or '-'
    end)
    Output(string.format('[TICB-HEARTBEAT][%s] hp=%s%% mana=%s%% lvl=%s gold=%s kda=%s mode=%s exit=%s target=%s',
        BotLabel(bot),
        okHp and string.format('%.0f', hpPct) or '?',
        okMp and string.format('%.0f', mpPct) or '?',
        tostring(okLvl and level or '?'),
        tostring(okGold and gold or '?'),
        okKda and string.format('%d/%d/%d', kills, deaths, assists) or '?/?/?',
        okMode and ModeName(mode) or '?',
        tostring(bot._farmExitReason or '-'),
        okTarget and target or '?'))
end

return X
