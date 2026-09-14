-- Item 14: bot-only economy multiplier (x1.5 gold, x1.2 XP), added when
-- FretBots (which used to own this kind of catch-up/bonus system via its
-- own DynamicDifficulty/BonusTimers) was fully disabled and removed. This
-- is a standalone replacement scoped to exactly what was asked for: track
-- each bot's own gold/XP gain per tick and grant the extra fraction on top
-- via the normal ModifyGold/AddExperience APIs. Gold/XP LOSSES (death
-- gold penalty, etc.) are never amplified - only positive gains are
-- topped up. Human players are untouched.
local CatchupBoost = require(GetScriptDirectory() .. '/FuncLib/systems/catchup_boost')
local PlayerResourceLib = require(GetScriptDirectory() .. '/FuncLib/systems/player_resource')

local X = {}
local lastMutateErrorLog = -1e9

local GOLD_MULTIPLIER = 1.5
local XP_MULTIPLIER = 1.2

local lastGold = {}
local lastXP = {}
-- Passive income often ticks in small (sometimes 1-gold) increments, more
-- often than Think() even runs. A bare math.floor(delta*0.5) throws away
-- most of the bonus on every small tick (floor(1*0.5)=0, forever, for any
-- hero whose gold only ever goes up by 1-2 at a time) - only large deltas
-- (kills/bounties/big last hits) were actually getting topped up, so the
-- x1.5/x1.2 was real but barely perceptible on top of ordinary passive gold
-- and XP. Carry the fractional remainder forward per bot instead of
-- discarding it, so the full multiplier lands over time regardless of how
-- small each individual tick is.
local goldRemainder = {}
local xpRemainder = {}
-- Throttled visibility so a match log can directly confirm the bonus is
-- firing (and roughly how much), rather than needing to infer it from gold
-- curves after the fact.
local lastLog = {}
local totalGoldBonus = {}
local totalXpBonus = {}

function X.Think(bot)
    if bot == nil or not bot:IsBot() then return end
    local id = bot:GetPlayerID()
    if id == nil then return end

    -- The npcBot handle GetBot() returns is a restricted bot-AI wrapper, not
    -- the full hero entity: read-only getters like GetGold()/GetCurrentXP()
    -- work on it, but entity-mutating calls like ModifyGold()/AddExperience()
    -- are simply absent from that wrapper (confirmed live: both threw
    -- "attempt to call method '...' (a nil value)" every tick, so the x1.5/
    -- x1.2 bonus was never actually applied despite the throttled log firing).
    -- The 0.7.10.2 fix routed gold through PlayerResource and XP through the
    -- real hero entity - that stopped the errors, but a full 42-minute match
    -- afterward still showed bonusGold/bonusXp stuck at exactly 0 the entire
    -- time despite gold visibly swinging by hundreds, which means the writes
    -- are being silently skipped, not merely miscalculated. The prime
    -- suspect: `PlayerResource` as a bare global may simply not be populated
    -- inside this per-bot AI script context at all (every reference to it
    -- elsewhere in this codebase - FretBots, Buff/GPM.lua - runs from a
    -- different, non-bot-sandboxed script context, so it was never actually
    -- proven to work from here). player_resource.lua now tries both the
    -- bare global and GetPlayerResource() and reports which (if either)
    -- resolves; the mutating calls below are also pcall-wrapped so a failure
    -- there specifically (as opposed to PlayerResource itself being nil)
    -- shows up loudly instead of just silently producing another 0.
    local pr = PlayerResourceLib.Get()
    local heroEnt = nil
    if pr ~= nil then
        local ok, ent = pcall(function() return pr:GetSelectedHeroEntity(id) end)
        if ok then heroEnt = ent end
    end

    -- The comeback scale (1.0 at even net worth, up to 3.0 at a 10k+ gap)
    -- multiplies directly onto the baseline multipliers below, so a losing
    -- bot's 1.5x/1.2x baseline can reach 4.5x/3.6x at the worst gaps. The
    -- flat per-minute catch-up gold (separate from this rate) is handled
    -- entirely inside CatchupBoost.Think.
    local rateScale = CatchupBoost.GetRateScale(bot)
    local goldMultiplier = GOLD_MULTIPLIER * rateScale
    local xpMultiplier = XP_MULTIPLIER * rateScale

    local gold = bot:GetGold()
    local prevGold = lastGold[id]
    if prevGold ~= nil then
        local delta = gold - prevGold
        if delta > 0 then
            local raw = delta * (goldMultiplier - 1) + (goldRemainder[id] or 0)
            local bonus = math.floor(raw)
            goldRemainder[id] = raw - bonus
            if bonus > 0 and pr ~= nil then
                local ok, err = pcall(function() pr:ModifyGold(id, bonus, false, 0) end)
                if ok then
                    totalGoldBonus[id] = (totalGoldBonus[id] or 0) + bonus
                else
                    local now2 = DotaTime()
                    if now2 >= lastMutateErrorLog + 30 then
                        lastMutateErrorLog = now2
                        print('[TICB-ECONOMY][ERROR] ModifyGold failed: ' .. tostring(err))
                    end
                end
            end
        end
    end
    lastGold[id] = bot:GetGold()

    local xp = heroEnt ~= nil and heroEnt:GetCurrentXP() or nil
    local prevXP = lastXP[id]
    if xp ~= nil and prevXP ~= nil then
        local deltaXP = xp - prevXP
        if deltaXP > 0 then
            local raw = deltaXP * (xpMultiplier - 1) + (xpRemainder[id] or 0)
            local bonus = math.floor(raw)
            xpRemainder[id] = raw - bonus
            if bonus > 0 then
                local ok, err = pcall(function() heroEnt:AddExperience(bonus, 0, false, true) end)
                if ok then
                    totalXpBonus[id] = (totalXpBonus[id] or 0) + bonus
                else
                    local now2 = DotaTime()
                    if now2 >= lastMutateErrorLog + 30 then
                        lastMutateErrorLog = now2
                        print('[TICB-ECONOMY][ERROR] AddExperience failed: ' .. tostring(err))
                    end
                end
            end
        end
    end
    lastXP[id] = xp

    local _cbOk, _cbErr = pcall(CatchupBoost.Think, bot)
    if not _cbOk then print('[TICB-CATCHUP][ERROR] ' .. tostring(_cbErr)) end

    local now = DotaTime()
    if now >= (lastLog[id] or -1e9) + 60 then
        lastLog[id] = now
        print('[TICB-ECONOMY] '..tostring(bot:GetUnitName())..' bonusGold='..
            tostring(math.floor(totalGoldBonus[id] or 0))..' bonusXp='..
            tostring(math.floor(totalXpBonus[id] or 0)))
    end
end

return X
