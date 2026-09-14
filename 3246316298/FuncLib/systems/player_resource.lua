-- Resolves the PlayerResource entity for use from inside bot-AI scripts.
--
-- The bare global `PlayerResource` is what every reference file in this
-- codebase uses (FretBots' AwardBonus.lua/GameState.lua, Buff/GPM.lua), but
-- those all originate from a different, non-bot-sandboxed script context.
-- Whether that same global is actually populated inside a per-bot AI script
-- (mode_*.lua / *_generic.lua, which is what economy_boost.lua and
-- catchup_boost.lua run under via GetBot()) is unconfirmed - live match
-- logs show economy_boost's gold/XP bonus staying at exactly 0 for an
-- entire 40+ minute match despite gold clearly fluctuating by hundreds at a
-- time, which is consistent with `PlayerResource` resolving to nil there
-- and every write silently being skipped by the `PlayerResource ~= nil`
-- guards. `GetPlayerResource()` is the documented function-call form of the
-- same lookup and, being an ordinary global function rather than a
-- pre-populated variable, has a decent chance of working in contexts where
-- the bare global doesn't. This module tries both, in order, and reports
-- (once, loudly) which one actually resolved - or that neither did - so the
-- next match's log settles the question definitively instead of guessing
-- a third time.
local X = {}

local resolved = nil
local resolvedVia = nil
local reportedOnce = false

local function TryResolve()
    if PlayerResource ~= nil then
        return PlayerResource, 'global PlayerResource'
    end
    if GetPlayerResource ~= nil then
        local ok, pr = pcall(GetPlayerResource)
        if ok and pr ~= nil then
            return pr, 'GetPlayerResource()'
        end
    end
    return nil, nil
end

function X.Get()
    if resolved == nil then
        resolved, resolvedVia = TryResolve()
        if not reportedOnce then
            reportedOnce = true
            if resolved ~= nil then
                print('[TICB-PLAYERRESOURCE] resolved via ' .. resolvedVia)
            else
                print('[TICB-PLAYERRESOURCE][ERROR] neither global PlayerResource nor ' ..
                    'GetPlayerResource() resolved - gold/XP grants and net worth reads ' ..
                    'are unavailable from this script context')
            end
        end
    end
    return resolved
end

return X
