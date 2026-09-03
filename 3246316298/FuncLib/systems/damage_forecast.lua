local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local X = {}
local TARGET_ENEMY = DOTA_UNIT_TARGET_TEAM_ENEMY or 2
local TARGET_FRIENDLY = DOTA_UNIT_TARGET_TEAM_FRIENDLY or 1

local function Safe(call, fallback)
    local ok, value = pcall(call)
    if ok and type(value) == 'number' then return value end
    return fallback or 0
end

local function ArrivalTime(hero, target)
    local distance = GetUnitToUnitDistance(hero, target)
    local approach = math.max(0, distance - hero:GetAttackRange()) / math.max(220, hero:GetCurrentMovementSpeed())
    local projectile = 0
    local speed = hero:GetAttackProjectileSpeed()
    if speed > 0 and hero:GetAttackRange() > 320 then projectile = math.max(0, distance - 80) / speed end
    return approach + hero:GetAttackPoint() + projectile
end

local function AttackDamage(hero, target, seconds)
    local arrival = ArrivalTime(hero, target)
    local active = seconds - arrival
    if active <= 0 then return 0 end
    local attacks = math.max(1, math.floor(active / math.max(0.35, hero:GetSecondsPerAttack())) + 1)
    local raw = hero:GetAttackDamage() * attacks
    return Safe(function() return target:GetActualIncomingDamage(raw, DAMAGE_TYPE_PHYSICAL) end, raw)
end

local function CanDamageEnemy(ability)
    local behavior = Safe(function() return ability:GetBehavior() end, 0)
    local targetTeam = Safe(function() return ability:GetTargetTeam() end, TARGET_ENEMY)
    if J.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET) then
        return J.CheckBitfieldFlag(targetTeam, TARGET_ENEMY)
    end
    return not J.CheckBitfieldFlag(targetTeam, TARGET_FRIENDLY)
        or J.CheckBitfieldFlag(targetTeam, TARGET_ENEMY)
end

local function AbilityDamage(hero, target, seconds)
    if not hero:IsBot() or hero:IsSilenced() then return 0, 0 end
    local mana = hero:GetMana()
    local conservative = 0
    local maximum = 0
    for slot = 0, 5 do
        local ability = hero:GetAbilityInSlot(slot)
        if ability ~= nil and not ability:IsHidden() and ability:IsTrained() and ability:IsFullyCastable()
            and not J.CheckBitfieldFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_PASSIVE)
            and CanDamageEnemy(ability)
        then
            local damage = Safe(function() return ability:GetAbilityDamage() end, 0)
            local cost = Safe(function() return ability:GetManaCost() end, 0)
            local castPoint = Safe(function() return ability:GetCastPoint() end, 0)
            local castRange = Safe(function() return ability:GetCastRange() end, hero:GetAttackRange())
            local moveTime = math.max(0, GetUnitToUnitDistance(hero, target) - math.max(200, castRange))
                / math.max(220, hero:GetCurrentMovementSpeed())
            if damage > 0 and mana >= cost and moveTime + castPoint <= seconds then
                local damageType = Safe(function() return ability:GetDamageType() end, DAMAGE_TYPE_MAGICAL)
                local actual = damageType == DAMAGE_TYPE_PURE and damage
                    or Safe(function() return target:GetActualIncomingDamage(damage, damageType) end, damage * 0.75)
                maximum = maximum + actual
                conservative = conservative + actual * 0.72
                mana = mana - cost
            end
        end
    end
    return conservative, maximum
end

local function ItemDamage(hero, target, seconds)
    local conservative = 0
    local maximum = 0
    for slot = 0, 5 do
        local item = hero:GetItemInSlot(slot)
        if item ~= nil and item:IsFullyCastable() then
            local name = item:GetName()
            local damage = 0
            local damageType = DAMAGE_TYPE_MAGICAL
            if string.find(name, 'item_dagon', 1, true) then
                damage = Safe(function() return item:GetSpecialValueInt('damage') end, 0)
            elseif name == 'item_urn_of_shadows' then
                damage = 150
            elseif name == 'item_spirit_vessel' then
                damage = 200
            elseif name == 'item_blood_grenade' then
                damage = 125
            end
            if damage > 0 and seconds >= Safe(function() return item:GetCastPoint() end, 0) then
                local actual = Safe(function() return target:GetActualIncomingDamage(damage, damageType) end, damage * 0.75)
                maximum = maximum + actual
                conservative = conservative + actual * 0.80
            end
        end
    end
    return conservative, maximum
end

function X.ForHero(hero, target, seconds)
    seconds = seconds or 4.5
    if not J.IsValidHero(hero) or not J.IsValidHero(target) then
        return { conservative = 0, expected = 0, maximum = 0, arrival = math.huge }
    end
    local attacks = AttackDamage(hero, target, seconds)
    local abilityConservative, abilityMaximum = AbilityDamage(hero, target, seconds)
    local itemConservative, itemMaximum = ItemDamage(hero, target, seconds)
    local conservative = attacks * 0.82 + abilityConservative + itemConservative
    local maximum = attacks + abilityMaximum + itemMaximum
    return {
        conservative = conservative,
        expected = conservative * 0.55 + maximum * 0.45,
        maximum = maximum,
        attacks = attacks,
        abilities = abilityMaximum,
        items = itemMaximum,
        arrival = ArrivalTime(hero, target),
    }
end

return X
