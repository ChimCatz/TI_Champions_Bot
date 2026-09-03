local bot = GetBot()
if bot == nil or not bot:IsHero() or bot:IsIllusion() then return end

local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')

local ROSHAN_ITEMS = {
    item_aegis = true,
    item_cheese = true,
    item_refresher_shard = true,
    item_aghanims_shard_roshan = true,
    item_ultimate_scepter_2 = true,
    item_roshan_banner = true,
}

local targetDrop = nil

local function HasInventorySpace(unit)
    for slot = 0, 8 do
        if unit:GetItemInSlot(slot) == nil then return true end
    end
    return false
end

local function HumanIsWaiting(location)
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally)
            and ally:IsAlive()
            and not ally:IsBot()
            and GetUnitToLocationDistance(ally, location) <= 700
        then
            return true
        end
    end
    return false
end

local function PickupScore(unit, itemName, location)
    if not unit:IsBot() or not HasInventorySpace(unit) then return -math.huge end
    local position = J.GetPosition(unit)
    local score = -GetUnitToLocationDistance(unit, location) / 100

    if itemName == 'item_aegis' then
        score = score + (position == 1 and 80 or position == 2 and 65 or position == 3 and 45 or 10)
        score = score + unit:GetLevel() * 1.5
    elseif itemName == 'item_cheese' then
        score = score + (position <= 3 and 45 or 30) + unit:GetMaxHealth() / 160
    elseif itemName == 'item_refresher_shard' then
        score = score + unit:GetMaxMana() / 45 + (position <= 3 and 25 or 15)
    elseif itemName == 'item_aghanims_shard_roshan' then
        score = score + (position <= 3 and 35 or 25) + unit:GetLevel()
    else
        score = score + (position >= 4 and 35 or 25)
    end
    return score
end

local function IsAssignedPickup(drop)
    local itemName = drop.item:GetName()
    local ourScore = PickupScore(bot, itemName, drop.location)
    if ourScore == -math.huge then return false end

    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and ally ~= bot then
            if PickupScore(ally, itemName, drop.location) > ourScore + 0.1 then return false end
        end
    end
    return true
end

local function FindDrop()
    local best = nil
    local bestDistance = math.huge
    local roshanLocation = J.GetCurrentRoshanLocation()
    for _, drop in pairs(GetDroppedItemList()) do
        if drop ~= nil
            and drop.item ~= nil
            and ROSHAN_ITEMS[drop.item:GetName()]
            and roshanLocation ~= nil
            and J.GetDistance(drop.location, roshanLocation) <= 1400
            and not HumanIsWaiting(drop.location)
            and IsAssignedPickup(drop)
        then
            local distance = GetUnitToLocationDistance(bot, drop.location)
            if distance <= 2200 and distance < bestDistance then
                best = drop
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

function GetDesire()
    if ShouldSkipBotThink(bot)
        or not bot:IsAlive()
        or bot:IsIllusion()
        or J.IsRetreating(bot)
        or bot:WasRecentlyDamagedByAnyHero(2)
    then
        targetDrop = nil
        return BOT_MODE_DESIRE_NONE
    end

    local distance
    targetDrop, distance = FindDrop()
    if targetDrop == nil then return BOT_MODE_DESIRE_NONE end
    if distance <= 500 then return BOT_MODE_DESIRE_ABSOLUTE end
    return BOT_MODE_DESIRE_VERYHIGH
end

function Think()
    targetDrop = FindDrop()
    if targetDrop == nil or targetDrop.item == nil then return end
    if GetUnitToLocationDistance(bot, targetDrop.location) <= 150 then
        bot:Action_PickUpItem(targetDrop.item)
    else
        bot:Action_MoveToLocation(targetDrop.location)
    end
end
