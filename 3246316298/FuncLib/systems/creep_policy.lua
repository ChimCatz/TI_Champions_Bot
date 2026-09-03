local J = require(GetScriptDirectory() .. '/FuncLib/func_utils')
local Customize = require(GetScriptDirectory() .. '/FuncLib/systems/custom_loader')

local X = {}
local CLAIM_SECONDS = 0.75

local function HasRecentEnemyRisk(bot, radius, seconds)
    if #(bot:GetNearbyHeroes(math.min(radius, 1600), true, BOT_MODE_NONE) or {}) > 0 then return true end
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

local function IsValidCreep(creep)
    return J.IsValid(creep) and creep:IsCreep() and creep:IsAlive() and J.CanBeAttacked(creep)
end

local function Value(creep)
    local name = creep:GetUnitName() or ''
    if string.find(name, 'ranged') then return 4 end
    if string.find(name, 'flagbearer') then return 3 end
    if string.find(name, 'siege') then return 2 end
    return 1
end

local function AttackDamage(bot)
    local damage = bot:GetAttackDamage()
    local slot = bot:FindItemSlot('item_quelling_blade')
    if slot >= 0 and bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN then
        damage = damage + (bot:GetAttackRange() > 310 and 4 or 8)
    end
    return math.max(1, damage - 2)
end

local function Arrival(bot, creep)
    local ok, delay = pcall(J.GetAttackProDelayTime, bot, creep)
    return ok and math.max(0.05, delay or 0.2) or 0.2
end

local function CanLandKill(bot, creep)
    local delay = Arrival(bot, creep)
    local ok, result = pcall(J.WillKillTarget, creep, AttackDamage(bot), DAMAGE_TYPE_PHYSICAL, delay)
    if ok and result then return true, delay end
    local real = creep:GetActualIncomingDamage(AttackDamage(bot), DAMAGE_TYPE_PHYSICAL)
    return creep:GetHealth() + creep:GetHealthRegen() * delay <= real, delay
end

local function ClaimOwner(creep)
    local best = nil
    local bestPosition = 99
    local bestDistance = math.huge
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(index)
        if J.IsValidHero(ally) and ally:IsAlive() and not ally:IsIllusion() then
            local claim = ally._ohaCreepClaim
            if claim ~= nil and claim.creep == creep and DotaTime() < claim.untilTime then
                local position = J.GetPosition(ally) or 5
                local distance = GetUnitToUnitDistance(ally, creep)
                if position < bestPosition or position == bestPosition and distance < bestDistance then
                    best = ally
                    bestPosition = position
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

local function CanCoreReach(core, creep)
    if not J.IsValidHero(core) or not core:IsAlive() then return false end
    local distance = GetUnitToUnitDistance(core, creep)
    if distance > math.min(1550, core:GetAttackRange() + 650) then return false end
    local canKill, delay = CanLandKill(core, creep)
    return canKill or creep:GetHealth() > core:GetAttackDamage() and delay < 1.2
end

function X.ShouldSupportYield(bot, creep, range)
    if (J.GetPosition(bot) or 5) <= 3 then return false end
    range = range or 1200
    for index = 1, #GetTeamPlayers(GetTeam()) do
        local core = GetTeamMember(index)
        if core ~= nil and core ~= bot and J.IsValidHero(core)
            and core:IsAlive() and not core:IsIllusion()
            and (J.GetPosition(core) or 5) <= 3
            and GetUnitToUnitDistance(core, creep) <= range
            and CanCoreReach(core, creep)
        then
            return true
        end
    end
    return false
end

local function Select(bot, creeps, deny)
    local best = nil
    local bestScore = -math.huge
    for _, creep in pairs(creeps or {}) do
        if IsValidCreep(creep) and (not deny or J.GetHP(creep) < 0.5) then
            local canKill, delay = CanLandKill(bot, creep)
            if canKill and (deny or not X.ShouldSupportYield(bot, creep, 1200)) then
                local owner = ClaimOwner(creep)
                local botPosition = J.GetPosition(bot) or 5
                local ownerPosition = owner ~= nil and (J.GetPosition(owner) or 5) or 99
                local canOverride = owner == nil or owner == bot
                    or not deny and botPosition < ownerPosition
                    or deny and botPosition > ownerPosition
                if canOverride then
                    local score = Value(creep) * 100 - delay * 18 - GetUnitToUnitDistance(bot, creep) / 80
                    if score > bestScore then best, bestScore = creep, score end
                end
            end
        end
    end
    if best ~= nil then
        bot._ohaCreepClaim = { creep = best, untilTime = DotaTime() + CLAIM_SECONDS, deny = deny }
    end
    return best
end

function X.FindLastHit(bot, creeps)
    return Select(bot, creeps, false)
end

function X.FindDeny(bot, creeps)
    return Select(bot, creeps, true)
end

function X.HasPriorityCreep(bot, radius)
    radius = radius or 1200
    if (J.GetPosition(bot) or 5) >= 4 then
        local deny = X.FindDeny(bot, bot:GetNearbyLaneCreeps(radius, false) or {})
        if deny ~= nil then return true, deny, 'DENY' end
    end
    local enemy = X.FindLastHit(bot, bot:GetNearbyLaneCreeps(radius, true) or {})
    if enemy ~= nil then return true, enemy, 'LAST_HIT' end
    local deny = X.FindDeny(bot, bot:GetNearbyLaneCreeps(radius, false) or {})
    if deny ~= nil then return true, deny, 'DENY' end
    return false, nil, nil
end

function X.CanActivelyClearWave(bot)
    if Customize.Active_Wave_Clear_Enabled == false
        or bot == nil or not bot:IsAlive() or bot:IsIllusion()
        or DotaTime() < 0
        or J.IsRetreating(bot)
        or J.GetHP(bot) < 0.42
        or bot:WasRecentlyDamagedByAnyHero(4.0)
        or HasRecentEnemyRisk(bot, 1800, 5.0)
    then
        return false
    end

    local enemyTower = (bot:GetNearbyTowers(1050, true) or {})[1]
    if J.IsValidBuilding(enemyTower) then
        local alliedCreeps = enemyTower:GetNearbyLaneCreeps(850, true) or {}
        if #alliedCreeps < 3 then return false end
    end

    if (J.GetPosition(bot) or 5) >= 4 then
        if Customize.Support_Wave_Clear_Enabled == false then return false end
        for index = 1, #GetTeamPlayers(GetTeam()) do
            local core = GetTeamMember(index)
            if core ~= nil and core ~= bot and J.IsValidHero(core)
                and core:IsAlive() and not core:IsIllusion()
                and (J.GetPosition(core) or 5) <= 3
                and GetUnitToUnitDistance(bot, core) <= 1200
            then
                return false
            end
        end
    end
    return true
end

function X.FindSafeWaveClearTarget(bot, creeps)
    if not X.CanActivelyClearWave(bot) then return nil end
    local best = nil
    local bestScore = math.huge
    for _, creep in pairs(creeps or {}) do
        if IsValidCreep(creep) then
            local owner = ClaimOwner(creep)
            if owner == nil or owner == bot or (J.GetPosition(bot) or 5) <= (J.GetPosition(owner) or 5) then
                local score = creep:GetHealth() + GetUnitToUnitDistance(bot, creep) * 0.08
                if score < bestScore then best, bestScore = creep, score end
            end
        end
    end
    if best ~= nil then
        bot._ohaCreepClaim = { creep = best, untilTime = DotaTime() + CLAIM_SECONDS, deny = false }
    end
    return best
end

function X.GetValue(creep)
    return creep ~= nil and Value(creep) or 0
end

return X
