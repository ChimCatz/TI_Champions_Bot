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

return X
