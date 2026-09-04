local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

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

-- Unconditional periodic snapshot (every 10s per bot, independent of the
-- LANE_STATE/LANE_RECOVERY throttle above) so a full match has a
-- position/status trail even for bots that never trigger another category -
-- requested so match reviews don't need extra explanation of who was where.
function X.Heartbeat(bot)
    if not enabled or bot == nil then return end
    local key = BotKey(bot)
    local now = DotaTime()
    if now < (heartbeatLast[key] or -1e9) + HEARTBEAT_INTERVAL then return end
    heartbeatLast[key] = now
    local okHp, hpPct = pcall(function() return 100 * bot:GetHealth() / math.max(1, bot:GetMaxHealth()) end)
    local okMp, mpPct = pcall(function() return 100 * bot:GetMana() / math.max(1, bot:GetMaxMana()) end)
    local okLvl, level = pcall(function() return bot:GetLevel() end)
    local okGold, gold = pcall(function() return bot:GetGold() end)
    local okMode, mode = pcall(function() return bot:GetActiveMode() end)
    Output(string.format('[TICB-HEARTBEAT][%s] hp=%s%% mana=%s%% lvl=%s gold=%s mode=%s exit=%s',
        BotLabel(bot),
        okHp and string.format('%.0f', hpPct) or '?',
        okMp and string.format('%.0f', mpPct) or '?',
        tostring(okLvl and level or '?'),
        tostring(okGold and gold or '?'),
        tostring(okMode and mode or '?'),
        tostring(bot._farmExitReason or '-')))
end

return X
