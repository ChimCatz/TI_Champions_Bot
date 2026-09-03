local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local Diagnostics = require(GetScriptDirectory() .. '/FuncLib/systems/decision_log')
local CreepPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/creep_policy')

local X = {}
local TARGET_ENEMY = DOTA_UNIT_TARGET_TEAM_ENEMY or 2
local TARGET_FRIENDLY = DOTA_UNIT_TARGET_TEAM_FRIENDLY or 1
local ROLE_RESERVE = { [1] = 0.28, [2] = 0.36, [3] = 0.32, [4] = 0.40, [5] = 0.44 }
local HERO_RESERVE = {
    npc_dota_hero_antimage = 0.34,
    npc_dota_hero_ember_spirit = 0.40,
    npc_dota_hero_faceless_void = 0.38,
    npc_dota_hero_juggernaut = 0.34,
    npc_dota_hero_queenofpain = 0.42,
    npc_dota_hero_slark = 0.38,
    npc_dota_hero_storm_spirit = 0.52,
    npc_dota_hero_void_spirit = 0.42,
    npc_dota_hero_weaver = 0.38,
    npc_dota_hero_zuus = 0.42,
}
local FORBIDDEN_NAME_PARTS = {
    'blink', 'teleport', 'relocate', 'ball_lightning', 'waveform', 'time_walk',
    'leap', 'pounce', 'charge_of_darkness', 'shukuchi', 'shadow_dance',
    'ghost_walk', 'snowball', 'hookshot', 'stampede', 'global_silence',
}

local function SafeCall(call, fallback)
    local ok, value = pcall(call)
    if ok and value ~= nil then return value end
    return fallback
end

local function IsForbidden(ability)
    local name = ability:GetName() or ''
    for _, part in pairs(FORBIDDEN_NAME_PARTS) do
        if string.find(name, part, 1, true) then return true end
    end
    return false
end

local function CanDamageEnemies(ability)
    local targetTeam = SafeCall(function() return ability:GetTargetTeam() end, TARGET_ENEMY)
    local behavior = SafeCall(function() return ability:GetBehavior() end, 0)
    if J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET) then
        return J.CheckBitfieldFlag(targetTeam, TARGET_ENEMY)
    end
    return not J.CheckBitfieldFlag(targetTeam, TARGET_FRIENDLY)
        or J.CheckBitfieldFlag(targetTeam, TARGET_ENEMY)
end

local function GetReserve(bot, selected)
    local maxMana = math.max(0, bot:GetMaxMana())
    if maxMana <= 0 then return 0 end
    local role = J.GetPosition(bot) or 5
    local ratio = HERO_RESERVE[bot:GetUnitName()] or ROLE_RESERVE[role] or 0.40
    local emergencyCost = 0
    for slot = 0, 5 do
        local ability = bot:GetAbilityInSlot(slot)
        if ability ~= nil and ability ~= selected and ability:IsTrained() and not ability:IsHidden()
            and not SafeCall(function() return ability:IsUltimate() end, false)
        then
            emergencyCost = math.max(emergencyCost, SafeCall(function() return ability:GetManaCost() end, 0))
        end
    end
    return math.max(maxMana * ratio, emergencyCost * 1.05)
end

local function RecentEnemyRisk(bot, radius, seconds)
    if #(bot:GetNearbyHeroes(math.min(1600, radius), true, BOT_MODE_NONE) or {}) > 0 then return true end
    local location = bot:GetLocation()
    for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(playerId) then
            local info = GetHeroLastSeenInfo(playerId)
            local seen = info ~= nil and info[1] or nil
            if seen ~= nil and seen.time_since_seen <= seconds
                and J.GetDistance(location, seen.location) <= radius
            then
                return true
            end
        end
    end
    return false
end

local function AbilityRadius(ability)
    local radius = 0
    for _, key in pairs({ 'radius', 'aoe', 'area_of_effect', 'damage_radius', 'width' }) do
        radius = math.max(radius, SafeCall(function() return ability:GetSpecialValueInt(key) end, 0))
    end
    return math.max(250, math.min(700, radius))
end

local function IsEligible(ability)
    if ability == nil or ability:IsHidden() or not ability:IsTrained() or not ability:IsFullyCastable() then return false end
    if SafeCall(function() return ability:IsUltimate() end, false) then return false end
    if SafeCall(function() return ability:GetChannelTime() end, 0) > 0 then return false end
    if SafeCall(function() return ability:GetCooldown() end, 99) > 20 then return false end
    if SafeCall(function() return ability:GetAbilityDamage() end, 0) <= 0 then return false end
    if IsForbidden(ability) then return false end
    if not CanDamageEnemies(ability) then return false end
    local behavior = SafeCall(function() return ability:GetBehavior() end, 0)
    return J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET)
        or J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_POINT)
        or J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_NO_TARGET)
end

local function GetNeutrals(bot)
    local result = {}
    for _, creep in pairs(bot:GetNearbyNeutralCreeps(1200) or {}) do
        if J.IsValid(creep) and creep:IsAlive() and J.CanBeAttacked(creep) then table.insert(result, creep) end
    end
    return result
end

local function Center(units)
    local center = Vector(0, 0, 0)
    for _, unit in pairs(units) do center = center + unit:GetLocation() end
    return center / math.max(1, #units)
end

local function Evaluate(bot, ability, neutrals)
    local castRange = math.min(1200, math.max(250, SafeCall(function() return ability:GetCastRange() end, 0)))
    local radius = AbilityRadius(ability)
    local inRange = {}
    local totalHealth = 0
    local hasAncient = false
    local highest = nil
    for _, creep in pairs(neutrals) do
        if GetUnitToUnitDistance(bot, creep) <= castRange + radius then
            table.insert(inRange, creep)
            totalHealth = totalHealth + creep:GetHealth()
            hasAncient = hasAncient or creep:IsAncientCreep()
            if highest == nil or creep:GetHealth() > highest:GetHealth() then highest = creep end
        end
    end
    if #inRange < 2 and not hasAncient then return nil end
    if totalHealth <= bot:GetAttackDamage() * 4 and not hasAncient then return nil end

    local manaCost = SafeCall(function() return ability:GetManaCost() end, 0)
    if bot:GetMana() - manaCost < GetReserve(bot, ability) then return nil end
    local damage = SafeCall(function() return ability:GetAbilityDamage() end, 0)
    local behavior = SafeCall(function() return ability:GetBehavior() end, 0)
    local hitCount = J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET) and 1 or #inRange
    return {
        ability = ability,
        units = inRange,
        target = highest,
        location = Center(inRange),
        behavior = behavior,
        score = damage * hitCount / math.max(25, manaCost),
    }
end

function X.TryCast(bot)
    if bot == nil or not bot:IsAlive() or bot:IsIllusion() or J.CanNotUseAbility(bot) then return false end
    if bot:GetActiveMode() ~= BOT_MODE_FARM or J.IsRetreating(bot) or J.GetHP(bot) < 0.42 then return false end
    if RecentEnemyRisk(bot, 1800, 4.0) then return false end
    local neutrals = GetNeutrals(bot)
    if #neutrals == 0 then return false end

    local best = nil
    for slot = 0, 5 do
        local ability = bot:GetAbilityInSlot(slot)
        if IsEligible(ability) then
            local candidate = Evaluate(bot, ability, neutrals)
            if candidate ~= nil and (best == nil or candidate.score > best.score) then best = candidate end
        end
    end
    if best == nil then return false end

    if J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_UNIT_TARGET) then
        bot:Action_UseAbilityOnEntity(best.ability, best.target)
    elseif J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_POINT) then
        bot:Action_UseAbilityOnLocation(best.ability, best.location)
    else
        bot:Action_UseAbility(best.ability)
    end
    Diagnostics.Write(bot, 'FARM_SPELL', 'ability=%s neutrals=%d mana=%d reserve=%d',
        best.ability:GetName(), #best.units, bot:GetMana(), GetReserve(bot, best.ability))
    return true
end

function X.TrySecureLaneCreep(bot)
    if bot == nil or (J.GetPosition(bot) or 5) > 3 or J.CanNotUseAbility(bot) or J.IsRetreating(bot) then return false end
    local bestCreep = nil
    local bestValue = 0
    for _, creep in pairs(bot:GetNearbyLaneCreeps(1200, true) or {}) do
        if J.IsValid(creep) and creep:IsAlive() and J.CanBeAttacked(creep) then
            local name = creep:GetUnitName() or ''
            local value = string.find(name, 'ranged') and 4
                or string.find(name, 'flagbearer') and 3
                or string.find(name, 'siege') and 2 or 0
            if value > bestValue then
                local delay = SafeCall(function() return J.GetAttackProDelayTime(bot, creep) end, 0.2)
                local attackKills = SafeCall(function()
                    return J.WillKillTarget(creep, bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL, delay)
                end, false)
                if not attackKills then bestCreep, bestValue = creep, value end
            end
        end
    end
    if bestCreep == nil then return false end

    local best = nil
    for slot = 0, 5 do
        local ability = bot:GetAbilityInSlot(slot)
        if IsEligible(ability) and SafeCall(function() return ability:GetCooldown() end, 99) <= 12 then
            local cost = SafeCall(function() return ability:GetManaCost() end, 0)
            local castPoint = SafeCall(function() return ability:GetCastPoint() end, 0)
            local range = math.max(250, SafeCall(function() return ability:GetCastRange() end, 0))
            local raw = SafeCall(function() return ability:GetAbilityDamage() end, 0)
            local damageType = SafeCall(function() return ability:GetDamageType() end, DAMAGE_TYPE_MAGICAL)
            local real = damageType == DAMAGE_TYPE_PURE and raw
                or SafeCall(function() return bestCreep:GetActualIncomingDamage(raw, damageType) end, raw * 0.75)
            if GetUnitToUnitDistance(bot, bestCreep) <= range + AbilityRadius(ability)
                and bot:GetMana() - cost >= GetReserve(bot, ability)
                and real >= bestCreep:GetHealth() + bestCreep:GetHealthRegen() * castPoint
            then
                if best == nil or cost < best.cost then
                    best = { ability = ability, cost = cost, behavior = ability:GetBehavior() }
                end
            end
        end
    end
    if best == nil then return false end
    if J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_UNIT_TARGET) then
        bot:Action_UseAbilityOnEntity(best.ability, bestCreep)
    elseif J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_POINT) then
        bot:Action_UseAbilityOnLocation(best.ability, bestCreep:GetLocation())
    else
        bot:Action_UseAbility(best.ability)
    end
    Diagnostics.Write(bot, 'LANE_SPELL_LASTHIT', 'ability=%s creep=%s mana=%d',
        best.ability:GetName(), bestCreep:GetUnitName(), bot:GetMana())
    return true
end

function X.TryClearLaneWave(bot)
    if bot == nil or J.CanNotUseAbility(bot) or not CreepPolicy.CanActivelyClearWave(bot) then return false end
    local creeps = {}
    for _, creep in pairs(bot:GetNearbyLaneCreeps(1200, true) or {}) do
        if J.IsValid(creep) and creep:IsAlive() and J.CanBeAttacked(creep) then
            table.insert(creeps, creep)
        end
    end
    if #creeps < 3 then return false end

    local best = nil
    for slot = 0, 5 do
        local ability = bot:GetAbilityInSlot(slot)
        if IsEligible(ability) and SafeCall(function() return ability:GetCooldown() end, 99) <= 12 then
            local candidate = Evaluate(bot, ability, creeps)
            if candidate ~= nil and (best == nil or candidate.score > best.score) then best = candidate end
        end
    end
    if best == nil then return false end

    if J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_UNIT_TARGET) then
        bot:Action_UseAbilityOnEntity(best.ability, best.target)
    elseif J.CheckBitfieldFlag(best.behavior, ABILITY_BEHAVIOR_POINT) then
        bot:Action_UseAbilityOnLocation(best.ability, best.location)
    else
        bot:Action_UseAbility(best.ability)
    end
    Diagnostics.Write(bot, 'LANE_WAVECLEAR', 'ability=%s creeps=%d mana=%d reserve=%d',
        best.ability:GetName(), #best.units, bot:GetMana(), GetReserve(bot, best.ability))
    return true
end

return X
