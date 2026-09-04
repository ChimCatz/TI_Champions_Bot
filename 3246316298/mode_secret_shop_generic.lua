local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive()
    or not string.find(botName, 'hero') or bot:IsIllusion()
then
    return
end

local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')
local DecisionPolicy = require(GetScriptDirectory() .. '/FuncLib/systems/decision_policy')
Customize.ThinkLess = Customize.Enable and Customize.ThinkLess or 1

local X = {}
local shopLocation = nil
local primaryShop = GetShopLocation(GetTeam(), SHOP_SECRET)
local secondaryShop = GetShopLocation(GetTeam(), SHOP_SECRET2)

function GetDesire()
    if ShouldSkipBotThink(GetBot()) then return 0 end
    return GetDesireHelper()
end

function GetDesireHelper()
    if J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then return BOT_MODE_DESIRE_NONE end
    -- J.IsInLaningPhase() just reads bot.isInLanePhase, a flag only
    -- mode_laning_generic.lua sets - and that file returns before ever
    -- setting it whenever DotaTime()<0 (the whole pre-horn strategy-time
    -- window). That left this guard disabled at exactly the moment Pos 1-3
    -- most needed it, pulling cores to the river-adjacent secret shop the
    -- instant the horn hit. DecisionPolicy.IsLaneLocked() is time/position
    -- based and doesn't depend on another mode's execution order.
    if DecisionPolicy.IsLaneLocked(bot) then
        return BOT_MODE_DESIRE_NONE
    end

    local ancient = GetAncient(GetTeam())
    if J.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
        or ancient and J.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1
    then
        return BOT_MODE_DESIRE_NONE
    end
    if J.IsFarming(bot) and J.IsPushing(bot) and J.IsDefending(bot) then return BOT_MODE_DESIRE_NONE end
    if not X.IsSuitableToBuy() then return BOT_MODE_DESIRE_NONE end

    local inventoryFull = true
    for slot = 0, 8 do
        if bot:GetItemInSlot(slot) == nil then inventoryFull = false end
    end
    if inventoryFull and bot:GetLevel() > 11 and bot:FindItemSlot('item_aegis') < 0 then
        local canSell = X.HaveItemToSell()
        if canSell then
            shopLocation = X.GetPreferredSecretShop()
            if shopLocation ~= nil then
                return RemapValClamped(GetUnitToLocationDistance(bot, shopLocation), 6000, 0, 0.75, 0.95)
            end
        end
        return BOT_MODE_DESIRE_NONE
    end

    local courier = bot.theCourier
    local courierState = courier ~= nil and GetCourierState(courier) or COURIER_STATE_DEAD
    if bot.SecretShop and courierState ~= COURIER_STATE_MOVING then
        shopLocation = X.GetPreferredSecretShop()
        if shopLocation ~= nil and courierState == COURIER_STATE_DEAD then
            return RemapValClamped(GetUnitToLocationDistance(bot, shopLocation), 6000, 0, 0.7, 0.85)
        end
        if shopLocation ~= nil and GetUnitToLocationDistance(bot, shopLocation) <= 3200 then
            return RemapValClamped(GetUnitToLocationDistance(bot, shopLocation), 3200, 0, 0.7, 0.85)
        end
    end
    return BOT_MODE_DESIRE_NONE
end

function OnStart() end
function OnEnd() end

function Think()
    if J.CanNotUseAction(bot) or bot:IsChanneling() or bot:NumQueuedActions() > 0
        or bot:IsCastingAbility() or bot:IsUsingAbility()
    then
        return
    end
    if shopLocation == nil then shopLocation = X.GetPreferredSecretShop() end
    if shopLocation == nil then return end
    if bot:DistanceFromSecretShop() == 0 then
        bot:Action_MoveToLocation(shopLocation + RandomVector(200))
    else
        bot:Action_MoveToLocation(shopLocation + RandomVector(20))
    end
end

function X.HaveItemToSell()
    local expendable = {
        'item_clarity', 'item_faerie_fire', 'item_tango', 'item_flask',
        'item_bracer', 'item_wraith_band', 'item_null_talisman',
        'item_infused_raindrop', 'item_bottle',
    }
    for _, itemName in pairs(expendable) do
        local slot = bot:FindItemSlot(itemName)
        if slot >= 0 and slot <= 8 then return true, slot end
    end
    return false, nil
end

function X.GetPreferredSecretShop()
    if GetTeam() == TEAM_RADIANT then
        return GetUnitToLocationDistance(bot, secondaryShop) <= 3800 and secondaryShop or primaryShop
    end
    return GetUnitToLocationDistance(bot, primaryShop) <= 3800 and primaryShop or secondaryShop
end

function X.IsSuitableToBuy()
    local activeMode = bot:GetActiveMode()
    local enemies = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}
    if not bot:IsAlive()
        or bot:HasModifier('modifier_item_shadow_amulet_fade')
        or activeMode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
        or activeMode == BOT_MODE_ATTACK
        or activeMode == BOT_MODE_DEFEND_ALLY
        or #enemies >= 2
        or enemies[1] ~= nil and X.IsStronger(bot, enemies[1])
        or GetUnitToUnitDistance(bot, GetAncient(GetTeam())) < 2300
        or GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) < 3500
    then
        return false
    end
    return true
end

function X.IsStronger(unit, enemy)
    local ownDamage = unit:GetEstimatedDamageToTarget(true, enemy, 4.0, DAMAGE_TYPE_ALL)
    local enemyDamage = enemy:GetEstimatedDamageToTarget(true, unit, 4.0, DAMAGE_TYPE_ALL)
    return enemyDamage > ownDamage
end

if SafeCall then
    GetDesire = SafeCall(GetDesire, 0, 'SECRET_SHOP_GetDesire')
    Think = SafeCall(Think, nil, 'SECRET_SHOP_Think')
end
