local X = {}

local FARM_ITEMS = {
    npc_dota_hero_troll_warlord = 'item_bfury',
    npc_dota_hero_antimage = 'item_bfury',
    npc_dota_hero_phantom_assassin = 'item_bfury',
    npc_dota_hero_juggernaut = 'item_maelstrom',
    npc_dota_hero_faceless_void = 'item_maelstrom',
    npc_dota_hero_ember_spirit = 'item_maelstrom',
    npc_dota_hero_spectre = 'item_radiance',
    npc_dota_hero_skeleton_king = 'item_radiance',
    npc_dota_hero_necrolyte = 'item_radiance',
    npc_dota_hero_luna = 'item_mask_of_madness',
    npc_dota_hero_sven = 'item_mask_of_madness',
    npc_dota_hero_medusa = 'item_manta',
}

local BLINK_ANCHORS = {
    npc_dota_hero_axe = 'item_blade_mail',
    npc_dota_hero_centaur = 'item_veil_of_discord',
    npc_dota_hero_mars = 'item_soul_ring',
    npc_dota_hero_tidehunter = 'item_vladmir',
    npc_dota_hero_legion_commander = 'item_blade_mail',
    npc_dota_hero_magnataur = 'item_arcane_boots',
    npc_dota_hero_sand_king = 'item_veil_of_discord',
    npc_dota_hero_slardar = 'item_echo_sabre',
}

local MAGIC_HEAVY = {
    npc_dota_hero_zuus = true, npc_dota_hero_lina = true,
    npc_dota_hero_lion = true, npc_dota_hero_skywrath_mage = true,
    npc_dota_hero_leshrac = true, npc_dota_hero_queenofpain = true,
    npc_dota_hero_puck = true, npc_dota_hero_storm_spirit = true,
    npc_dota_hero_invoker = true, npc_dota_hero_witch_doctor = true,
}

local EVASION = {
    npc_dota_hero_phantom_assassin = true, npc_dota_hero_windrunner = true,
    npc_dota_hero_brewmaster = true, npc_dota_hero_tinker = true,
}

local ILLUSIONS = {
    npc_dota_hero_phantom_lancer = true, npc_dota_hero_naga_siren = true,
    npc_dota_hero_terrorblade = true, npc_dota_hero_chaos_knight = true,
}

local HEALING = {
    npc_dota_hero_huskar = true, npc_dota_hero_necrolyte = true,
    npc_dota_hero_dazzle = true, npc_dota_hero_oracle = true,
    npc_dota_hero_omniknight = true, npc_dota_hero_abaddon = true,
}

local EARLY_ITEMS = {
    item_magic_wand = true, item_wraith_band = true, item_bracer = true,
    item_null_talisman = true, item_phase_boots = true,
    item_power_treads = true, item_arcane_boots = true,
    item_tranquil_boots = true, item_boots = true,
}

local function Copy(items)
    local result = {}
    for _, item in ipairs(items or {}) do table.insert(result, item) end
    return result
end

local function Find(items, wanted)
    for index, item in ipairs(items) do
        if item == wanted then return index end
    end
    return nil
end

local function Contains(items, wanted)
    return Find(items, wanted) ~= nil
end

local function MoveAfter(items, wanted, anchor)
    local itemIndex = Find(items, wanted)
    local anchorIndex = Find(items, anchor)
    if itemIndex == nil or anchorIndex == nil or itemIndex == anchorIndex + 1 then return end
    table.remove(items, itemIndex)
    anchorIndex = Find(items, anchor)
    table.insert(items, anchorIndex + 1, wanted)
end

local function MoveAfterEarlyItems(items, wanted)
    local itemIndex = Find(items, wanted)
    if itemIndex == nil then return end
    local anchor = 0
    for index, item in ipairs(items) do
        if EARLY_ITEMS[item] and index > anchor then anchor = index end
    end
    table.remove(items, itemIndex)
    if itemIndex < anchor then anchor = anchor - 1 end
    table.insert(items, math.min(#items + 1, anchor + 1), wanted)
end

local function InsertAfter(items, wanted, anchor)
    if Contains(items, wanted) then return end
    local anchorIndex = Find(items, anchor) or math.min(8, #items)
    table.insert(items, anchorIndex + 1, wanted)
end

local function InsertBeforeLuxury(items, wanted)
    if Contains(items, wanted) then return end
    local anchors = {
        item_satanic = true, item_skadi = true, item_butterfly = true,
        item_heart = true, item_assault = true, item_sheepstick = true,
        item_octarine_core = true, item_ultimate_scepter = true,
    }
    for index, item in ipairs(items) do
        if anchors[item] then table.insert(items, index, wanted) return end
    end
    table.insert(items, wanted)
end

local function EnemyProfile()
    local profile = { magic = 0, evasion = 0, illusions = 0, healing = 0 }
    for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
        if enemy ~= nil and enemy:IsHero() then
            local name = enemy:GetUnitName()
            if MAGIC_HEAVY[name] then profile.magic = profile.magic + 1 end
            if EVASION[name] then profile.evasion = profile.evasion + 1 end
            if ILLUSIONS[name] then profile.illusions = profile.illusions + 1 end
            if HEALING[name] then profile.healing = profile.healing + 1 end
        end
    end
    return profile
end

local function OptimizeRole(bot, position, items)
    local name = bot:GetUnitName()
    if position == 1 and FARM_ITEMS[name] ~= nil then
        MoveAfterEarlyItems(items, FARM_ITEMS[name])
    elseif position == 3 and BLINK_ANCHORS[name] ~= nil then
        MoveAfter(items, 'item_blink', BLINK_ANCHORS[name])
        if name == 'npc_dota_hero_axe' then MoveAfter(items, 'item_crimson_guard', 'item_blink') end
    elseif position >= 4
        and not Contains(items, 'item_glimmer_cape')
        and not Contains(items, 'item_force_staff')
    then
        local anchor = Contains(items, 'item_arcane_boots') and 'item_arcane_boots'
            or Contains(items, 'item_tranquil_boots') and 'item_tranquil_boots'
            or 'item_boots'
        InsertAfter(items, 'item_glimmer_cape', anchor)
    end
end

local function AddCounters(position, items, profile)
    if profile.magic >= 2 then
        if position <= 2 then
            InsertBeforeLuxury(items, 'item_black_king_bar')
        elseif position == 3 then
            InsertBeforeLuxury(items, 'item_pipe')
        elseif position >= 4 and not Contains(items, 'item_glimmer_cape') then
            InsertBeforeLuxury(items, 'item_glimmer_cape')
        end
    end
    if profile.evasion >= 1 and position <= 2 then
        InsertBeforeLuxury(items, 'item_monkey_king_bar')
    end
    if profile.illusions >= 2 and position <= 2
        and not Contains(items, 'item_mjollnir')
        and not Contains(items, 'item_radiance')
        and not Contains(items, 'item_bfury')
    then
        InsertBeforeLuxury(items, 'item_mjollnir')
    end
    if profile.healing >= 2 and position >= 4 then
        InsertBeforeLuxury(items, 'item_spirit_vessel')
    end
end

function X.Optimize(bot, position, buyList, sellList)
    local items = Copy(buyList)
    OptimizeRole(bot, position, items)
    AddCounters(position, items, EnemyProfile())
    return items, sellList
end

return X
