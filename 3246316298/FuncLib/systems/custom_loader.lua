local cached = nil

local USER_OVERRIDE_KEYS = {
    'Enable', 'Localization', 'Radiant_Heros', 'Dire_Heros', 'Ban',
    'Allow_Repeated_Heroes', 'Strict_Ban_Match', 'Allow_Trash_Talk',
    'Allow_AI_GPT_Response', 'Trash_Talk_Level', 'Radiant_Names', 'Dire_Names',
    'Show_Team_Names', 'Radiant_Team_Name', 'Dire_Team_Name', 'Fretbots', 'ThinkLess',
}

local function Warn(message)
    if log then log('[TICB-CONFIG] %s', message) else print('[TICB-CONFIG] ' .. message) end
end

local function LoadPackaged()
    if GetScriptDirectory() == 'bots' then return require('bots.Customize.general') end
    return require(GetScriptDirectory() .. '/Customize/general')
end

local function LoadExternal()
    local external = nil
    local ok = xpcall(function() external = require('game/Customize/general') end, function() end)
    return ok and external or nil
end

local function MergeLegacyUserSettings(packaged, external)
    if external == nil then return packaged end
    for _, key in pairs(USER_OVERRIDE_KEYS) do
        if external[key] ~= nil then packaged[key] = external[key] end
    end
    Warn(string.format('ignored stale behavior settings version=%s; packaged version=%s',
        tostring(external.Config_Version), tostring(packaged.Config_Version)))
    return packaged
end

function LoadCustomize()
    if cached ~= nil then return cached end
    local packaged = LoadPackaged()
    local external = LoadExternal()
    if external ~= nil and external.Config_Version == packaged.Config_Version then
        cached = external
    else
        cached = MergeLegacyUserSettings(packaged, external)
    end
    return cached
end

return LoadCustomize()
