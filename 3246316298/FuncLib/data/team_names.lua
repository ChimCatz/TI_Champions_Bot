if GetScriptDirectory == nil then
    GetScriptDirectory = function() return 'bots' end
end

local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')

local X = {}
X.maxTeamSize = 12

local ROSTERS = {
    { 'TSpirit.Yatoro', 'TSpirit.Larl', 'TSpirit.Collapse', 'TSpirit.not me', 'TSpirit.rue' },
    { 'VISION.Satanic', 'VISION.No[o]ne-', 'VISION.Noticed', 'VISION.9Class', 'VISION.Dukalis' },
    { 'TY.watson', 'TY.CHIRA_JUNIOR', 'TY.DM', 'TY.Saksa', 'TY.Malady' },
    { 'BB.Kiritych~', 'BB.gpk~', 'BB.MieRo', 'BB.Save-', 'BB.Kataomi`' },
    { 'Liquid.miCKe', 'Liquid.Nisha', 'Liquid.Ace', 'Liquid.Boxi', 'Liquid.tOfu' },
    { 'NGX.SumaiL', 'NGX.lorenof', 'NGX.Davai', 'NGX.OmaR', 'NGX.GH' },
    { 'IW.Pure', 'IW.bzm', 'IW.33', 'IW.Ari', 'IW.Whitemon' },
    { 'FLCN.skiter', 'FLCN.Malr1ne', 'FLCN.ATF', 'FLCN.Cr1t-', 'FLCN.Sneyking' },
    { 'Aurora.Nightfall', 'Aurora.Mikoto', 'Aurora.Ws', 'Aurora.Mira', 'Aurora.kaori' },
    { 'GL.Ghost', 'GL.RCY', 'GL.Fayde', 'GL.Bignum', 'GL.Speeed' },
    { 'LGD.Yuma', 'LGD.TaiLung', 'LGD.Wisper', 'LGD.Thiolicor', 'LGD.KJ' },
    { 'TRE.YSR-04E', 'TRE.Echozz', 'TRE.niu', 'TRE.planet', 'TRE.zzq' },
    { 'VG.shiro', 'VG.Xm', 'VG.Bach', 'VG.XinQ', 'VG.y`' },
    { 'OG.Natsumi', 'OG.Yopaj-', 'OG.Raven', 'OG.TIMS', 'OG.skem' },
    { 'XG.Ame', 'XG.NothingToSay', 'XG.Xxs', 'XG.fy', 'XG.xNova' },
    { 'HULIGANI.ssnovv1', 'HULIGANI.Mirage`', 'HULIGANI.Corrupted', 'HULIGANI.sayuw', 'HULIGANI.RESPECT' },
}

local function BuildNames(customNames, roster)
    local names = {}
    for position = 1, 5 do
        local custom = customNames ~= nil and customNames[position] or nil
        if custom ~= nil and custom ~= '' and custom ~= 'Random' then
            names[position] = custom
        else
            names[position] = roster[position]
        end
    end
    for index = 6, X.maxTeamSize do
        local position = (index - 1) % 5 + 1
        names[index] = names[position] .. '.' .. tostring(index)
    end
    return names
end

function X.generateTeams(custom)
    custom = custom or {}
    local radiantRoster
    local direRoster
    if Customize.Random_TI_Rosters == false then
        radiantRoster = Customize.Fixed_Position_Names or ROSTERS[1]
        direRoster = radiantRoster
    else
        -- RandomInt alone repeatedly picked the same roster across back-to-back
        -- local test matches, suggesting the engine RNG isn't well-diversified
        -- this early in a fresh bot VM. Seed Lua's own RNG with real entropy
        -- (wall-clock time + fractional game time + team, same technique as
        -- FretBots:SetRandomSeed) and draw from that instead.
        local seeded = pcall(function()
            local sysTime = tostring(GetSystemTime()):gsub(':', '')
            local frac = Time() - math.floor(Time())
            local seed = math.floor(((tonumber(sysTime) or 0) + frac) * 1000000) + GetTeam() * 7919
            math.randomseed(seed)
        end)
        local function Pick(lo, hi)
            if seeded then return math.random(lo, hi) end
            return RandomInt(lo, hi)
        end
        local radiantIndex = Pick(1, #ROSTERS)
        local direIndex = Pick(1, #ROSTERS - 1)
        if direIndex >= radiantIndex then direIndex = direIndex + 1 end
        radiantRoster = ROSTERS[radiantIndex]
        direRoster = ROSTERS[direIndex]
    end
    return {
        Radiant = BuildNames(custom.Radiant or {}, radiantRoster),
        Dire = BuildNames(custom.Dire or {}, direRoster),
    }
end

return X
