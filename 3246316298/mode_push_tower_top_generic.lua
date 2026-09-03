local Push = require(GetScriptDirectory() .. '/FuncLib/systems/push')
local DecisivePush = require(GetScriptDirectory() .. '/FuncLib/systems/decisive_push')
local bot = GetBot()

if bot.PushLaneDesire == nil then bot.PushLaneDesire = { 0, 0, 0 } end

function GetDesire()
    if ShouldSkipBotThink(bot) then return BOT_MODE_DESIRE_NONE end
    local override = DecisivePush.GetPushDesire(bot, LANE_TOP)
    if override ~= nil then return override end
    return Push.GetPushDesire(bot, LANE_TOP)
end

function Think()
    if ShouldSkipBotThink(bot) then return end
    Push.PushThink(bot, LANE_TOP)
end

if SafeCall then
    GetDesire = SafeCall(GetDesire, BOT_MODE_DESIRE_NONE, 'PUSH_TOWER_TOP_GetDesire')
    Think = SafeCall(Think, nil, 'PUSH_TOWER_TOP_Think')
end
