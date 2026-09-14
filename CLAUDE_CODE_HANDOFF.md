# TI Champions Bot - Claude Code Handoff

## Current Live Match

- Analyzed match: `8985682484` (41:05, fully bots-only, Radiant stomped Dire
  47-11. Radiant pos1 Medusa/pos2 Kunkka/pos3 Centaur Warrunner/pos4 Shadow
  Shaman/pos5 Shadow Demon; Dire pos1 Luna/pos2 Lycan/pos3 Abyssal
  Underlord/pos4 Grimstroke/pos5 Oracle, 2026/09/06). This match is what
  **conclusively proved** `PlayerResource` is unreachable from bot-AI script
  context - see 0.7.13 below. Note: match IDs cited in older session notes
  are all stale - always confirm hero names in the log body match the report
  before trusting a cited match ID.
- Live log: `E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\console.8985682484.log`
- Current deployed version: `TI Champions Bot v0.7.17` (see version history below)
- **The gold/XP comeback system is REAL again, but requires manual
  activation every match - it is NOT automatic.** The bot-AI-sandbox
  version (`economy_boost.lua`/`catchup_boost.lua`/`player_resource.lua`)
  stays inert/dead code, confirmed unfixable from inside the automatic bot
  script path (`PlayerResource` unreachable there, proven live). Per the
  user's explicit request (2026/09/06, after finding the original FretBots/
  Buff author independently confirmed the exact same limitation in
  `Buff/README.md`), 0.7.16 ships a NEW working implementation,
  `Buff/DynamicComeback.lua`, that runs in the real game-rules VScript
  context instead - the only place `PlayerResource` actually works. **To
  turn it on for a match**: local lobby with cheats enabled, then after the
  map loads, console commands `sv_cheats 1` then `script_reload_code
  bots/Buff/DynamicComeback` (full steps in `Buff/DynamicComeback_README.md`).
  Forgetting this step means the match runs with NO comeback bonus at all,
  same as before - if a match log has zero `[TICB-COMEBACK-LIVE]` lines,
  that's why.
- 0.7.17 fixed 4 more issues from match `8985928862` (24 min, bots-only,
  Radiant pos1 Ursa/pos2 Razor/pos3 Bloodseeker/pos4 Witch Doctor/pos5
  Vengeful Spirit vs Dire pos1 Phantom Assassin/pos2 Kunkka/pos3 Enigma/
  pos4 Skywrath Mage/pos5 Shadow Shaman). See the 0.7.17 changelog entry for
  full detail on each. When checking the next match's log: for issue 1
  (Ursa's magic wand), check whether `skipping stuck item item_magic_wand`
  lines now show `gold=` at least half of `GetItemCost` for that item - if
  they still show low gold, that confirms it really was just an
  affordability/patience issue, now fixed; for issue 4, check whether any
  core enters `mode=PUSH_TOWER_*` for a lane that isn't their own within
  the first minute of `DotaTime()` - should no longer happen at all.
- Carried over from 0.7.15: `item_double_branches`-style multi-quantity
  items should no longer show up in `skipping stuck item` lines at all;
  for any item that still gets abandoned, read its `alreadyOwned=`/`gold=`/
  `courier=`/`stash=`/`needed=[...]` fields to see whether it was a false
  alarm or a genuine case; `[Purchase] ... stuck-item fallback succeeded`;
  `[TICB-GRISGRIS]` for Witch Doctor; Doom/Warlock-style solo laners'
  `mode=RETREAT` share of heartbeat samples vs `mode=LANING`.
- The log is readable while the match is running. Dota initially writes to
  `console.log`, then changes to `console.<match-id>.log` after receiving the match ID.

PowerShell commands:

```powershell
$dir = 'E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota'
Get-ChildItem $dir -Filter 'console*.log' -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 5 FullName, Length, LastWriteTime

Get-Content "$dir\console.8980476765.log" -Wait -Tail 100

Select-String -Path "$dir\console.8980476765.log" -Pattern \
  'TICB-|Script Runtime Error|error in error handling|IncrementIdleTime'
```

The player does not need to export anything. After the match, wait several
seconds and use the newest nonempty `console.<match-id>.log`.

## Correct Source Locations

The editor is currently showing `dota2bot-OpenHyperAI/bots`. That repository is
an upstream reference and is **not** the active custom build.

- Editable working copy: `C:\Users\User\OneDrive\Desktop\DOTA 2 BOT\3246316298`
- Live Workshop deployment: `E:\SteamLibrary\steamapps\workshop\content\570\3246316298`
- Upload-ready release: `C:\Users\User\OneDrive\Desktop\DOTA 2 BOT\TI-Champions-Bot\bots`
- Persistent external config: `E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\game\Customize\general.lua`
- Upstream reference only: `C:\Users\User\OneDrive\Desktop\DOTA 2 BOT\dota2bot-OpenHyperAI\bots`
- Current archive: `C:\Users\User\OneDrive\Desktop\DOTA 2 BOT\TI-Champions-Bot-v0.6.0.zip`

Patch the working copy first. After validation, synchronize changed files to
both the live Workshop folder and `TI-Champions-Bot/bots`. Keep the external
configuration at `Config_Version = 6` or increment all matching copies together.

## Patch History

### 0.1.0 - Initial decision and map behavior

- Added shared decisive-push state, lane scoring, tower momentum, and full-wipe
  finish behavior.
- Suppressed farming and side objectives during decisive finish windows.
- Added balanced push/group settings and exclusions for known weak heroes.
- Added action commitments to reduce back-and-forth movement.
- Added rune execution, support farm yielding, early-mid lane duty, post-fight
  lane selection, feasible human assistance, lane harassment coordination,
  support positioning, pulling, and stacking.

### 0.2.0 - Objectives, combos, and items

- Made Roshan and pushing mutually exclusive strategic objectives.
- Required a safe two-hero living advantage or a safe human Roshan ping.
- Added role-based Roshan-drop pickup and rune interruption of support tasks.
- Added bot-only combo damage, three-second focus locks, and calculated finishes.
- Tightened tower dives and fixed Witch Doctor Death Ward and Skywrath Atos gates.
- Stabilized push targets, introduced farming-item deadlines for initial carries,
  and added matchup item responses such as BKB, MKB, Pipe, anti-heal, and
  anti-illusion items.

### 0.3.0 - Roshan startup, survival, and names

- Fixed a negative pregame timer that caused minute-zero Roshan gatherings.
- Hard-disabled Roshan before 15:00.
- Added incoming damage forecasts for heroes, towers, and creeps.
- Added survival aborts and restored defensive spell use on human allies.
- Counted human damage only after visible commitment.
- Prioritized immediate power-rune pickup and blocked early core secret-shop trips.
- Added position-matched names from the 16-team roster dataset.

### 0.3.1 - Rune ownership

- Added all four bounty locations and deterministic collector priority:
  Position 1, 2, 3, 4, then 5; player ID breaks ties.
- Equal-number rune contests remain allowed; outnumbered/critical bots disengage.
- Human pings no longer arbitrarily cancel rune claims.
- Restricted pregame rune staging to mid and supports.

### 0.3.2 - Pickup transaction and dive safety

- Replaced direct nearby pickup with a queued transaction to prevent other logic
  overwriting it. This was later superseded because the engine rejected some
  queued pickup orders.
- Added stricter calculated tower dives and blocked team-roam bypasses.

### 0.4.0 - Fixed 18-minute economy phase

- Fixed coordinated laning/economy through 18:00.
- Added shared last-hit and deny claims with ranged, flagbearer, and siege priority.
- Added attack-arrival-aware creep timing and conservative attack/spell/item damage.
- Added safe 2v1 pressure with recent-unseen-enemy checks.
- Required lethal tower-dive forecasts, allied cover, and 55% predicted survival.
- Added temporary recovery jungling for unsafe lanes.
- Added safe all-hero jungle spell use and spells for securing valuable lane creeps.
- Added rate-limited decision diagnostics.

### 0.4.1 - Direct rune pickup hotfix

- Replaced queued pickup with repeated direct `Action_PickUpRune` calls.
- Added a 2.25-second retry window, timeout, suppression, and rune telemetry.
- Routed diagnostics into Dota console logs.

### 0.5.0 - TI Champions identity and fixed lobby roles

- Made lobby slots authoritative for roles and Radiant/Dire lane assignments.
- Removed role shuffling and position-change chat commands.
- Added 14-16 second lane-return locks after rune attempts.
- Removed legacy unsafe harassment and added enemy-tower leashing.
- Added earlier damage-based retreat decisions.
- Added first-major deadlines: Pos 1 18:00, Pos 2 16:00, Pos 3 17:00,
  supports 15:00.
- Added backpack promotion for important usable items.
- Rebranded logs/chat to TI Champions Bot and added `[TICB-*]` tags.

### 0.7.17 - 4 fixes from match 8985928862 (Ursa magic wand, lethal TP-ins, starting regen, abandoned safelane)

From a 24-minute bots-only match: `8985928862`, Radiant pos1 Ursa/pos2
Razor/pos3 Bloodseeker/pos4 Witch Doctor/pos5 Vengeful Spirit vs Dire pos1
Phantom Assassin/pos2 Kunkka/pos3 Enigma/pos4 Skywrath Mage/pos5 Shadow
Shaman.

1. **Ursa still stuck on Magic Wand** - the 0.7.15 diagnostics (`gold=`/
   `needed=[...]`) proved this one wasn't the recipe-mapping bug from
   0.7.13 at all: `needed=[item_recipe_magic_wand,item_branches,
   item_magic_stick,]` (a correct, already-partially-reduced requirement
   list - the "own 1 already" logic worked fine) with `gold=155` - she
   simply hadn't saved up the ~400g total yet (the stick alone is 200g).
   The abandon condition (`item_purchase_generic.lua`) only ever checked
   "is gold sitting idle in the courier or stash" as its "still legitimately
   saving up, don't give up" signal - it had no equivalent check for "still
   accumulating gold in-hand, also not stuck." Added one: the decisive
   `rebuildCount>=5` abandon branch now also requires the hero to already
   hold at least 50% of the item's total cost in hand - a hero nowhere
   close to affording it is just saving up, not bugged, and now gets left
   alone to keep saving instead of losing the item from their build.
2. **Bots TPing into fights the enemy can just kill them for** - traced the
   "join team fight" TP-scroll logic in `ability_item_usage_generic.lua`:
   it checked whether the BOT's *current* position had enemies nearby, but
   never evaluated the *destination* at all - no stun/disable check and no
   damage check either, exactly the gap the user described. Added an
   estimated-damage check against enemies actually near the landing spot
   (`GetEstimatedDamageToTarget` over the first 3 seconds, the same
   primitive `combat_safety.lua` uses elsewhere): if that alone would take
   the bot to 25% health or below, skip the TP-in this tick and re-evaluate
   next tick instead of committing blind.
3. **Starting kits too thin on regen** - confirmed: Ursa's opening buy is
   tango + double_branches + faerie_fire + quelling_blade + circlet - one
   single Tango's worth of sustain, nothing else. Rather than hand-edit
   starting items across 128 hero files (which would also flatten
   intentional per-hero variety, which the user explicitly did not want),
   added `EnsureStartingRegen()` to the shared purchase pipeline
   (`item_purchase_generic.lua`, same call sites as `PrioritizeBoots`/
   `PrioritizeLateGameItems`): scores each hero's first few starting items
   for sustain value (double tango = 2, single tango = 1, flask = 1.5,
   clarity = 0.5, mangoes = 0.4/0.8) and tops up with one Healing Salve
   (~110g) whenever that score is below 2 and no flask is already present.
   Heroes that already start regen-heavy (a double tango, an existing
   flask) are left completely untouched.
4. **Radiant safelane tower down before 7 minutes** - root-caused, and it
   wasn't really about the tower defense logic at all: the heartbeat log
   showed Ursa (pos1, assigned to the bot lane) sitting in
   `mode=PUSH_TOWER_MID` from literally 12 seconds after game start,
   gold frozen at 60 the entire time (meaning he never landed a single
   creep last-hit) - he wasn't in his lane to defend anything. Traced to
   `FuncLib/systems/decisive_push.lua`: `state.decisive` (the "the enemy
   team just got wiped, go push now" signal) is set whenever
   `CountAlive(enemyTeam)==0`, with no time/level gate on that specific
   branch (the existing `minMinute` floor only guarded the *other*,
   "hasNumbers" push-desire branch). `CountAlive` uses `IsHeroAlive()`,
   which also legitimately reads false for a hero that simply hasn't
   spawned into the world yet - right at game start, before all 5 enemy
   heroes finish spawning, this read as "enemy team wiped" and pulled a
   level-1 safelane carry off to push an unrelated lane. Added the same
   `DotaTime()>=60` floor to the decisive-wipe branch that the other branch
   already had, so it can never fire before the game has been running long
   enough for a real teamfight wipe to be possible.

Validated: `luac -p` clean across all 317 files. Synced
`item_purchase_generic.lua`, `ability_item_usage_generic.lua`, and
`FuncLib/systems/decisive_push.lua` to Workshop + release, SHA-256
verified. Takes effect starting the *next* match.

### 0.7.16 - Real, working gold/XP comeback system (manual activation required)

User pushed back on giving up on the comeback system, citing a GitHub
discussion (forest0xia/dota2bot-OpenHyperAI#68) claiming FretBots was able
to grant gold/XP. Investigated properly instead of re-guessing an API call:

- `WebFetch` on that discussion confirmed FretBots' bonus system is
  activated via `sv_cheats 1; script_reload_code bots/fretbots` typed into
  the dev console in a local lobby - not something that runs automatically.
- Better: this exact repo already has `Buff/README.md`, written by the
  original author of the GPM/XP-boost system `economy_boost.lua` was
  modeled on. It documents the identical activation method
  (`sv_cheats 1` + `script_reload_code bots/Buff/buff`) and states outright:
  **"It would've been nice to call this within the bot script, but I don't
  think it is possible."** - independent confirmation, from the person who
  actually built a working version of this, of exactly what 0.7.13's live
  testing found. `script_reload_code` injects a script directly into the
  real server-side VScript VM (the same one `GameRules`/`PlayerResource`/
  `SpawnEntityFromTableSynchronous` live in) - a completely different
  execution context from the automatic per-bot AI script loading path
  every `mode_*_generic.lua` file runs under, which is why it can reach
  `PlayerResource` when nothing in the bots/ folder's normal load path can.

User decided (2026/09/06): build it this way anyway, accepting the
manual-activation tradeoff, since their actual usage (local bots-only
testing lobbies) is exactly the context this mechanism supports.

**New file `Buff/DynamicComeback.lua`**, structured like `Buff/Buff.lua`
(same `Timers:CreateTimer`/`GameRules:State_Get()` init pattern, same
`PlayerResource:GetSteamID(playerID) == PlayerResource:GetSteamID(100)`
bot-detection check Buff.lua uses), running as a real, standalone
`script_reload_code`-loaded script:

- Same design as the (now-inert) bot-sandbox version: baseline x1.5 gold /
  x1.2 XP for every bot; a comeback SCALE on top (1.0x at even net worth up
  to 3.0x at a 10,000 gold team net-worth gap, so up to x4.5 gold/x3.6 XP
  at the worst gaps); a separate flat gold injection every in-game minute
  (0 to 300g/min on the same gap curve). Bots only, always.
- Ticks every second via `Timers:CreateTimer`, iterating both teams'
  players directly through `PlayerResource:GetPlayerCountForTeam`/
  `GetNthPlayerIDOnTeam` (the same real, working enumeration pattern
  `Buff.lua`/`FretBots` use) - not through any per-bot `GetBot()` call, so
  none of the bot-AI-sandbox restrictions apply here.
- Gold read/write via `PlayerResource:GetGold`/`ModifyGold` directly by
  player ID. XP read/write via the hero entity from
  `PlayerResource:GetPlayer(pid):GetAssignedHero()` - a real
  `CDOTA_BaseNPC_Hero` in this context, unlike the bot wrapper.
- Logs via plain `print()`, not this codebase's `log()` (confirmed
  earlier to be a permanent no-op unless a file explicitly forces
  `IsDebug=true`, which `Buff.lua` does and this file sidesteps entirely
  instead) - `[TICB-COMEBACK-LIVE]` per bot per 60s with net worth, gap,
  scale, and cumulative bonus granted, plus a green chat message on
  activation.

New `Buff/DynamicComeback_README.md` documents the exact activation steps
(local lobby, cheats enabled, `sv_cheats 1` then `script_reload_code
bots/Buff/DynamicComeback` after the map loads - once per match).

**This is genuinely untested in a live match** (no way to validate outside
`luac -p` without actually running it) - next match should confirm the
green activation chat message appears and `[TICB-COMEBACK-LIVE]` lines
show sensible net worth/scale numbers that track the actual game state.

Validated: `luac -p` clean across all 317 files. Synced
`Buff/DynamicComeback.lua` and `Buff/DynamicComeback_README.md` to
Workshop + release (new `Buff/` subfolder created in both), SHA-256
verified.

### 0.7.15 - Actual root cause of the broad stuck-item bug found and fixed

User pushed back on 0.7.14's fallback-only patch and asked for the real
common cause before doing more workarounds. Found it.

**The bug**: `FuncLib/systems/item.lua`'s `RemoveIntersectedItems(ag, ah)` -
used by the stuck-item "rebuild" recovery path
(`HasTargetItemCompositByItems` -> `GetReducedPurchaseList`) to strip
already-owned components out of a combo item's remaining shopping list -
tracked "which components are already satisfied" as a **boolean set**
(`am[itemName] = true`) instead of a **count**. Concretely: if a combo
needs 2x `item_branches` and the hero owns exactly 1 loose branch
(extremely common - starting-kit leftover), the old code marked
`item_branches` satisfied once and then removed **both** required branch
entries from the list, not just the one actually covered. The shopping
list goes empty, the combo item never actually gets purchased, and 5
seconds later the existing "stuck item" logic permanently deletes it from
the build. This is an exact, direct match for `item_double_branches`
getting abandoned on Medusa, and it also would have undermined the 0.7.13
Magic Wand fix itself (which needs 2 branches) the moment a hero already
carried 1 spare branch. Fixed by making it a proper multiset: consume one
match per owned instance, not one match per distinct item name.

```lua
-- before (boolean set - can remove 2 needed entries after seeing only 1 owned)
function b.RemoveIntersectedItems(ag,ah)local am={}for h,aj in ipairs(ah)do am[aj]=true end...
-- after (count-based - only removes as many entries as are actually owned)
function b.RemoveIntersectedItems(ag,ah)local am={}for h,aj in ipairs(ah)do am[aj]=(am[aj]or 0)+1 end;local an={}for h,aj in ipairs(ag)do if am[aj]~=nil and am[aj]>0 then am[aj]=am[aj]-1 else table.insert(an,aj)end end;return an end;
```

**Not yet nailed down**: the single-quantity real items that also got
abandoned this session (Glimmer Cape, Guardian Greaves, Aether Lens, Null
Talisman, Manta, Ring of Basilius) don't fit this exact bug - a
quantity-of-1 requirement can't be over-satisfied by a set-vs-count
mixup. Traced `IsItemInHero`/`GetBasicItems`/`HasTargetItemCompositByItems`
thoroughly for a matching single-item bug and didn't find one with
confidence, rather than guess a fix without evidence. Instead, the
`[Purchase] ... skipping stuck item` log line now reports the exact state
at the moment of abandonment: `alreadyOwned` (was `IsItemInHero` true or
false right then - distinguishes "false alarm, it was actually already
complete" from "genuine loss"), current `gold`/`courier`/`stash`, and the
full `needed=[...]` component list that was being tracked. Next match's
log will show directly which of these it is instead of more static-analysis
guessing.

Validated: `luac -p` clean across all 315 files. Synced `item.lua` and
`item_purchase_generic.lua` to Workshop + release, SHA-256 verified. The
0.7.14 fallback-purchase safety net stays in place as a backstop on top of
this real fix. Takes effect starting the *next* match.

### 0.7.14 - Broad stuck-item recovery (not just Magic Wand)

Follow-up in the same session, after the user decided to leave the economy
system inert (see the note at top) and asked instead for general gameplay
improvement for both teams. Re-checked match `8985682484`'s full stuck-item
log rather than just the Magic Wand cases already fixed, and found the
"permanently abandon this item" mechanism is a much broader problem than
Magic Wand alone:

```
Shadow Shaman: item_magic_wand, item_guardian_greaves, item_glimmer_cape, item_aether_lens
Medusa:        item_null_talisman (x2), item_ring_of_basilius, item_manta, item_magic_wand, item_double_branches
```

9 abandoned items for just 2 heroes in one match. Magic Wand's cause (a
missing component in the recipe map) is now fixed and doesn't explain the
other 7 - those are all real, singly-mapped or unmapped items with no
known recipe gap (`item_double_branches` in particular is about as trivial
as a "combo" gets: 2 Iron Branches, nothing else), which points at the
`GetBasicItems`/`R(H)`/`currBuyingRequiredCounts` tracking occasionally
reporting an item's component list as already-satisfied/empty when it
isn't, for reasons not fully isolated this session (traced through
`IsItemInHero`'s upgrade-redirect table and the repeat-item `sLastRepeatItem`
handling without finding a single conclusive root cause common to all 9).

Rather than keep digging for an exact root cause with diminishing returns,
added a safety net in `item_purchase_generic.lua`: right before an item
gets permanently deleted from the buy list (the `rebuildCount>=5`/
`countInvCheck>30` "stuck" branch), it now gets one direct shot via the
raw `ActionImmediate_PurchaseItem` shop call on the combo item's own name
(bypassing our component-list tracking entirely) if the bot can currently
afford it and it's in stock. A raw shop purchase call auto-assembles the
whole recipe tree the same way a human clicking "buy" does, so it
sidesteps whatever tracking state got confused. Logged via `[Purchase]
... stuck-item fallback succeeded` on success; on failure it still falls
through to the existing deletion, so this is purely additive - no
regression risk, and it recovers real value on every stuck-item case where
the underlying problem was just our own bookkeeping rather than an actual
recipe gap or lack of gold.

Validated: `luac -p` clean across all 315 files. Synced
`item_purchase_generic.lua` to Workshop + release, SHA-256 verified. Takes
effect starting the *next* match - check for `[Purchase] ... stuck-item
fallback succeeded` lines to see how much this actually recovers; any item
that still gets a bare `skipping stuck item` line with no fallback-success
line right before it means the fallback itself failed too (worth a
follow-up look specifically at that item).

### 0.7.13 - PlayerResource CONFIRMED unreachable from bot scripts; Magic Wand actually fixed at the source

From match `8985682484` (41:05, bots-only, Radiant stomped Dire 47-11 -
user correctly guessed the comeback system never triggered).

1. **Gold/XP/comeback economy: root cause conclusively identified, fix
   NOT possible via the current approach.** `[TICB-PLAYERRESOURCE][ERROR]`
   fired twice in this match: "neither global PlayerResource nor
   GetPlayerResource() resolved". `ownNW`/`enemyNW` were 0 in every single
   `[TICB-CATCHUP]` line, and `bonusGold`/`bonusXp` were 0 in every
   `[TICB-ECONOMY]` line, for the full 41 minutes - not a math bug, a
   structural one. Traced why: this project's bot AI scripts load through
   `game/botsinit.lua`'s `BotsInit.CreateGeneric()`, which wraps each bot
   script in its own sandboxed environment (`setfenv` + a metatable that
   only falls back to that sandbox's own `_G`). The engine's bot-AI Lua
   state is a genuinely separate VM from the one where `PlayerResource`
   actually lives (the real game-rules/addon VM that files like the
   disabled `FretBots.lua` and `Buff/GPM.lua` were written for and were
   presumably tested in - those files were never proven to work from a
   `mode_*_generic.lua` call chain either). This is very likely a
   deliberate Valve restriction, not an oversight: bot AI scripts are
   sandboxed away from direct economy mutation for the same anti-cheat/
   balance reasons the bot wrapper itself has no `ModifyGold`/
   `AddExperience` methods (see 0.7.10.2).
   **This means the gold/XP multiplier and dynamic comeback system as
   currently built cannot work, and no further variation on "call
   PlayerResource a different way" is going to fix it** - that door is
   closed from inside a bot AI script. Left the code in place (inert, not
   reverted) since it does no harm sitting there un-triggered, and the
   diagnostics remain useful if the user wants to pursue one of the real
   options instead of guessing a 5th API further. **This needs a user
   decision before any more work goes into it** - see the three realistic
   paths in the message accompanying this changelog entry (drop the
   currency-injection idea entirely and lean on behavior-based catch-up
   instead; or turn this Workshop item into a real custom game mode with
   its own `addon_game_mode.lua` running in the actual game-rules VM, which
   is a much bigger scope/dependency change; or some other mechanism
   entirely). Do not silently pick one and implement it.
2. **Magic Wand stuck on Shadow Shaman (and, per the user's ask, checked
   for all heroes) - actually root-caused this time, not just patched
   around.** The 0.7.12 patch (`TryCompleteMagicWandUpgrade`) never even
   fired this match (0 occurrences in the log) because the real failure
   happens earlier than that patch could catch: Shadow Shaman's log shows
   `[Purchase] npc_dota_hero_shadow_shaman skipping stuck item
   item_magic_wand (rebuilds=5 invCheck=0)` at 20:19:49 - the item was
   **permanently abandoned and dropped from the buy list entirely**, not
   left half-built. Traced through `item_purchase_generic.lua`: when a
   combo item's basic-item breakdown list empties out while the combo
   itself still isn't owned, the code treats it as "stuck," retries a
   rebuild up to 5 times, then deletes it from the purchase list forever.
   The rebuild kept failing because `FuncLib/systems/item.lua`'s
   `GetBasicItems({"item_magic_wand"})` had no entry for
   `item_magic_wand` in its component-map table, so it returned the combo
   name back as its own single "basic item" - the purchase loop then just
   re-attempted buying the literal combo token, which (unlike what a human
   shop click does) doesn't reliably self-assemble from a bot purchase
   call once partial progress exists, so the rebuild loop kept re-deriving
   the same incomplete, ungrowing list until the 5-strike abandonment
   fired. **Fixed at the actual source**: added
   `b['item_magic_wand']={'item_magic_stick','item_branches','item_branches
   ','item_recipe_magic_wand'}` to `item.lua`'s component map - this is the
   real recipe (Magic Stick + 2 Iron Branches + the upgrade recipe), and
   since it's used by the one shared `GetBasicItems`/`item_purchase_generic
   .lua` pipeline every hero's buy list goes through, this fixes Magic Wand
   for **all 128 heroes** at once, not just the 3 that happened to get
   caught this session (Dragon Knight, Ursa, Shadow Shaman). The 0.7.12
   inventory-state patch stays in place as a harmless backstop for any
   other way this could theoretically still get stuck. Note for future
   similar bugs: `GetItemComponents(itemName)` is a real native Dota
   function already used elsewhere in this file
   (`b.GetComponentList`) that returns a combo item's true recipe tree
   directly from the game's own item definitions - a more general fix
   would route `GetBasicItems`'s fallback case through that instead of
   treating every unmapped item as a flat leaf, but that changes behavior
   for every hero's entire buy list at once and wasn't done here to keep
   this patch scoped to the actual reported bug.

Validated: `luac -p` clean across all 315 files. Synced `item.lua` to
Workshop + release, SHA-256 verified. Magic Wand fix takes effect starting
the *next* match. The economy/comeback system remains deployed but inert
pending the user's decision on which direction to take it.

### 0.7.12 - Economy system root-cause dig, stuck Magic Wand fix

From match `8985540156` (42:08, user playing Radiant pos3 Centaur
Warrunner vs Dire).

1. **Gold/XP multiplier and comeback system still doing nothing**: the
   0.7.11 build ran cleanly all match with zero `[TICB-ECONOMY][ERROR]` or
   `[TICB-CATCHUP][ERROR]` lines, but `bonusGold`/`bonusXp` were exactly 0
   across all 369 economy log lines for the full 42 minutes, despite gold
   visibly swinging by hundreds between heartbeat samples - proving the
   writes are being silently skipped, not merely mis-calculated (the
   `PlayerResource ~= nil` guards added in 0.7.10.2 were passing without
   error, which only happens if either they're false and skip silently, or
   the call inside genuinely never throws while also never taking effect).
   Root suspicion: `PlayerResource` as a bare global may not actually be
   populated inside a per-bot AI script context at all - every other
   reference to it in this codebase (FretBots' `AwardBonus.lua`,
   `Buff/GPM.lua`) runs from a different, non-bot-sandboxed script context,
   so it was never actually proven to resolve from here specifically.
   New `FuncLib/systems/player_resource.lua` tries both the bare global
   `PlayerResource` and the documented `GetPlayerResource()` function call,
   in that order, and reports (once per bot, via `[TICB-PLAYERRESOURCE]`)
   which one resolved - or that neither did. `economy_boost.lua` and
   `catchup_boost.lua` now go through this resolver instead of the bare
   global, and every mutating call (`ModifyGold`, `AddExperience`) is now
   individually pcall-wrapped with its own throttled error log, so a
   failure at the mutation step itself (as opposed to resolution) is now
   distinguishable too. **This is still a diagnostic-hardening pass, not a
   confirmed fix** - if `[TICB-PLAYERRESOURCE][ERROR]` shows up in the next
   match's log, that proves Valve's bot-AI sandbox genuinely blocks this
   category of call entirely (a real, deliberate restriction bot scripts
   likely can't work around at all, for the same anti-cheat/balance reasons
   `ModifyGold`/`AddExperience` are absent from the bot wrapper itself) and
   the comeback/multiplier system would need a fundamentally different
   mechanism (e.g. bounty-rune-style native rewards) rather than another
   API guess.
2. **Dragon Knight and Ursa stuck with Magic Stick + Magic Wand recipe but
   no Iron Branches for 20+ minutes**: root-caused in `item_purchase_generic
   .lua`. Buying `item_magic_wand` as a combo token is supposed to let the
   native `ActionImmediate_PurchaseItem` call auto-assemble the whole
   recipe tree, and that's normally fine (no manual decomposition exists
   for it in `item.lua`'s `GetBasicItems`, unlike virtual tokens such as
   `item_double_branches`). In practice the observed state - Stick built,
   Wand recipe bought, but the 2 Iron Branches that recipe also needs as
   direct siblings never purchased - means the opportunistic partial-buy
   behavior doesn't reliably circle back to finish that specific gap. Added
   `TryCompleteMagicWandUpgrade(bot, heroName)`, called every
   `ItemPurchaseThink()` tick: whenever a hero holds both Magic Stick and
   the Wand recipe but not the finished Wand, and has fewer than 2 Iron
   Branches in inventory, it explicitly buys branches until the upgrade can
   complete. Logged via existing `[Purchase] ... completing stuck Magic
   Wand upgrade` line.
3. **Shadow Shaman's Massive Serpent Ward (Urnaconda) tower behavior**: not
   actually testable this match - zero `urnaconda` mentions in the log and
   no Aghanim's Shard purchase for Shadow Shaman, meaning the ability was
   never cast. The *ordinary* Serpent Wards' tower/rax engagement logic
   (fixed in an earlier session) is confirmed working in this match's log -
   `[TICB-WARD]` shows 9 separate instances of a ward actively targeting
   `npc_dota_badguys_range_rax_mid`/`npc_dota_badguys_melee_rax_mid` when
   one was in range; the large majority of "idle" samples (378/500) were
   simply nothing being in the ward's ~500-900 unit detection range at all,
   which is expected/correct behavior, not a bug. Needs a match where the
   shard actually gets cast to evaluate further.
4. "Refine more bot usage/item/spell combos" - no fresh errors or obviously
   broken interactions turned up in this match's log beyond what's covered
   above (the usual 20 harmless `error in error handling` squelch lines at
   hero-load only). Left as an open invitation rather than guessing at a
   broad, unfocused sweep - happy to dig into a specific hero or
   interaction next if one stands out from play.

Validated: `luac -p` clean across all 313 files (plus the 2 new files, now
315). Synced `player_resource.lua` (new), `catchup_boost.lua`,
`economy_boost.lua`, `item_purchase_generic.lua` to Workshop + release,
SHA-256 verified. Takes effect starting the *next* match.

### 0.7.11 - Dynamic comeback economy system

Built the comeback system scoped and confirmed with the user in the prior
round: bots-only, driven purely by team net-worth gap, smooth (not tiered)
scaling, gold/XP rate boost plus a flat per-minute gold bonus.

New file `FuncLib/systems/catchup_boost.lua`:
- `GetTeamNetWorth(team)` sums `PlayerResource:GetNetWorth(playerId)` over
  `GetTeamPlayers(team)` - the same enumeration pattern already used
  throughout the codebase (`decision_policy.lua`, `push.lua`,
  `rune_policy.lua`, etc.), so this reuses a proven-working API path rather
  than guessing at a new one.
- `GetGapFraction(bot)`: `(enemyNetWorth - ownNetWorth) / 10000`, clamped to
  `[0,1]` - 0 at even-or-ahead, 1.0 once 10,000g behind (the saturation
  point from the plan).
- `GetRateScale(bot)`: `1.0 + gapFraction * (3.0 - 1.0)` - i.e. 1.0 at even,
  3.0 at the saturation gap.
- `Think(bot)`: every 60s, grants `floor(gapFraction * 300)` flat bonus
  gold via `PlayerResource:ModifyGold` - 0 at even, up to 300g/min at the
  saturation gap, stacking on top of the rate scale below.
- Throttled `[TICB-CATCHUP]` print every 60s reporting `gapFrac`,
  `rateScale`, and cumulative timer-bonus gold per bot.

`economy_boost.lua` changes:
- Requires `catchup_boost.lua` and multiplies the existing baseline
  `GOLD_MULTIPLIER`/`XP_MULTIPLIER` (1.5/1.2) by `CatchupBoost.GetRateScale
  (bot)` every tick before computing the bonus, so a bot on a team that's
  10k+ behind effectively gets 4.5x gold / 3.6x XP instead of 1.5x/1.2x.
  At even net worth `GetRateScale` returns exactly 1.0, so this is a no-op
  change for a team that isn't losing.
- Calls `CatchupBoost.Think(bot)` (pcall-wrapped, matching the existing
  `[TICB-ECONOMY][ERROR]` convention) right after the gold/XP block, for
  the separate flat timer bonus.

Validated: `luac -p` clean across all 313 files. Synced
`catchup_boost.lua` and `economy_boost.lua` to Workshop + release, SHA-256
verified. Like the rest of the economy system, this only takes effect
starting the *next* match - see the "Current Live Match" note above for
what to look for in that match's log.

### 0.7.10.3 - Offlaner over-retreating fixed, Gris-Gris diagnostics, Alchemist mid-item insert

From the same match as the questions above (`8985436588`, 33:57, user
playing Radiant pos1 Necrophos vs Dire).

1. **Doom Bringer (pos3) and Warlock (pos4) "passive, leave lane a lot"**:
   confirmed in the heartbeat log - Doom spent 44 of 128 sampled ticks in
   `mode=RETREAT` (vs. 73 in `mode=LANING`), Warlock 35 of 126. Root cause
   in `FuncLib/systems/survival_policy.lua`'s `GetRetreatDesire`: one of the
   three escalating thresholds fires whenever `hp<0.62 and #enemies>#allies`
   after being recently hit. In a solo offlane (1 ally) facing the opposing
   duo lane (2 enemies), `#enemies>#allies` (2>1) is true by definition
   every single time - so any offlaner/soft-support taking even routine lane
   trade damage down to 62% HP was retreating out of the lane on what should
   be a completely ordinary trade. Fixed by exempting that comparison (and
   the `#enemies>#allies+1` branch of the tier above it) while
   `FuncLib.IsLaning(bot)` is true, so being outnumbered only counts as a
   danger signal once laning is over (roams/ganks/fights, where an extra
   body really does mean something). The two low/no-outnumber-needed
   thresholds (health-remaining-after-incoming-damage, absolute HP floor)
   are untouched, so genuinely losing trades still trigger retreat.
2. **Witch Doctor's Gris-Gris still unused past minute 30**: the 0.7.9.1
   force-cast backstop (`hero_witch_doctor.lua`'s `SkillsComplement`) was
   already wired in and runs before any other early-return in that function,
   but its failure path used the codebase's dead `log()` (permanent no-op,
   see 0.7.8 notes) so there was no way to tell *why* it wasn't landing -
   nothing in the match log even mentioned Gris-Gris at all. Replaced with a
   throttled (every 20s, from t=15:00 on) always-on `print()` under
   `[TICB-GRISGRIS]` that reports exactly which case is happening: item not
   in inventory, item handle nil, found-but-not-castable (with cooldown/
   silence/stun/channel state), or a successful forced cast. This is a
   diagnostic-first patch - next match's log will show definitively whether
   this is an item-name mismatch (like the Urnaconda case), a cooldown/mana
   gate, or something else, instead of guessing again.
3. **Alchemist (and cores generally) rushing straight from starting kit to
   their one major item**: user's ask - cores should pick up a couple of
   real, permanent stat items before their core item, not just consumables.
   Alchemist's `pos_1` buy list (shared by all positions via the `m['pos_2'
   ]=m['pos_1']` aliases) already had `item_circlet` before `item_radiance`,
   but Iron Branches get auto-sold by `inventory_policy.lua`'s
   `SellObsoleteItems` at the 10-minute mark (added in 0.7.9) - since
   Radiance (5150g) routinely isn't finished by then, the branches vanish
   from the inventory well before the big item lands, leaving only
   Quelling Blade + Circlet visible for most of the mid-game, which reads
   as "barely any items." Inserted `item_bracer` and `item_power_treads`
   between the starting kit and `item_radiance` in `hero_alchemist.lua` -
   both are real, permanent, non-obsoleting items so they stay visible and
   useful the whole time Radiance is being saved for, matching the user's
   "smaller items, not straight to the big one" request. **Scope note**:
   the user asked for this pattern across other heroes too; this round only
   covers Alchemist as the explicit example - a broader per-hero pass needs
   the user's input on which stat items suit which hero/role rather than
   guessing at ~120 more buy lists blind.
4. Confirmed (see the two questions answered inline above, not restated
   here) that the x1.5/x1.2 economy multiplier had been silently erroring
   every tick since 0.7.8 and was actually fixed this session as v0.7.10.2,
   effective starting the *next* match.

Validated: `luac -p` clean across all 313 files. Synced
`survival_policy.lua`, `hero_witch_doctor.lua`, `hero_alchemist.lua` to
Workshop + release, SHA-256 verified.

### 0.7.10.2 - Gold/XP multiplier was silently no-op'ing since it shipped; fixed the actual API calls

User asked to confirm the x1.5 gold / x1.2 XP bonus was actually working, and
separately asked whether a dynamic catch-up system (losing team gets a bigger
multiplier) could be built. Checked the live in-progress match log
(`console.8985436588.log`, Dire pos1 Alchemist confirmed via heartbeat) and
found the answer to question 1 was **no, it never worked, since 0.7.8**:

- `[TICB-ECONOMY][ERROR]` had fired **39,547 times** in this one match alone -
  every single tick, for every bot, the entire time. Two distinct errors:
  `attempt to call method 'ModifyGold' (a nil value)` (36,901x) and
  `attempt to call method 'GetCurrentXP' (a nil value)` (2,819x - it only got
  reached before the first gold write started erroring, code path differs).
- Root cause: `GetBot()` returns a restricted bot-AI wrapper object, not the
  real hero entity. Read-only getters like `GetGold()` are exposed on that
  wrapper (confirmed zero `GetGold` errors all match) but entity-mutating
  calls like `ModifyGold()`/`AddExperience()` are not part of that wrapper's
  API surface at all - they simply don't exist on it, hence "nil value" on
  every attempt. The 0.7.9.1 pcall fix (session before last) correctly
  stopped this from silently killing the rest of `mode_farm_generic.lua`'s
  `GetDesire()` every tick, but it never fixed the underlying call itself -
  it just made the failure loud enough to finally prove it was there.
- Fix (`FuncLib/systems/economy_boost.lua`): gold now goes through
  `PlayerResource:ModifyGold(playerId, amount, false, 0)` - `PlayerResource`
  is a real global entity with a documented, always-present `ModifyGold`,
  independent of the bot-wrapper restriction. XP now goes through the actual
  hero entity via `PlayerResource:GetSelectedHeroEntity(playerId)`, which -
  unlike the bot wrapper - is the real `CDOTA_BaseNPC_Hero` and does expose
  both `GetCurrentXP()` (for the delta-tracking read) and `AddExperience()`.
- This will only take effect starting the **next** match - Lua bot scripts
  don't hot-reload mid-match, so the currently-running match the user is
  playing will still show the old broken behavior (or at best the same
  errors, now silenced only by the pre-existing pcall).
- Validated: `luac -p` clean across all 313 files. Synced
  `economy_boost.lua` to Workshop + release folders, SHA-256 verified match.

**Question 2 (dynamic catch-up multiplier for a losing team)**: not built
this round - scoping notes only. The building blocks exist and are
confirmed-real API (some already used by the disabled FretBots subsystem,
e.g. `PlayerResource:GetNetWorth(id)` in the old `AwardBonus.lua`):
`PlayerResource:GetNetWorth(id)`, `GetKills(id)`, `GetDeaths(id)`,
`GetAssists(id)`, `GetGoldPerMin(id)`, `GetXPPerMin(id)`, `GetLevel(id)`.
There is no built-in "team net worth" or "team score" call - it has to be
summed per-player over each team's player IDs. The old FretBots `GameState.lua`
had a similar-spirit "bot lead" tracker, but it was based on building-destroy
value, not net worth, and is disabled along with the rest of FretBots. A
fresh, small module (e.g. `FuncLib/systems/catchup_boost.lua`) computing a
team net-worth gap and feeding a scaling multiplier into `economy_boost.lua`
is straightforward to build next, pending the user's exact thresholds/curve
(how far behind before it kicks in, how the multiplier scales, whether it
also affects passive gold-per-minute directly vs. just the existing delta
multiplier, whether it should ever apply to enemy *human* players too or
bots-only like the base multiplier).

### 0.7.10.1 - Urnaconda identified and fixed, shackle-escape phase 1

User identified "Urnaconda" as Shadow Shaman's new 7.41e Aghanim's Shard
ability (point-target nuke that spawns a "Massive Serpent Ward", 4x base
Serpent Ward damage/HP, 15s duration) via a screenshot - it was in fact
already partially implemented (`hero_shadow_shaman.lua` already has
`a.ConsiderUrnaconda()`, correctly wired into `SkillsComplement`, casting
under reasonable engage conditions), so nothing needed fixing on the
casting side. The reported "no-tower-attack attitude" was instead about the
summoned Massive Serpent Ward itself, same complaint as the regular
Serpent Ward: `FuncLib/hero/minion_lib/utils.lua`'s `IsAttackingWard`
(the gate that routes a summon into `attacking_wards.lua`'s hero>summon>
tower>creep hierarchy) only matched `npc_dota_shadow_shaman_ward` by
substring - if the Massive Serpent Ward's real internal unit name doesn't
literally contain that exact substring in that word order (unconfirmed,
brand-new 7.41e content), it would fall through to whatever generic/no-op
handling applies to unrecognized summons instead. Added a second match on
`'urnaconda'` as a belt-and-suspenders catch regardless of the exact real
name.

**Shackle-escape, phase 1 (user asked to scope this out; built the safe,
generically-useful slice, deferred the hero-specific slice - see below):**
found via `ability_item_usage_generic.lua`'s item-consideration dispatcher
that a STUN/hex already fully blocks the whole item pipeline (matches real
Dota - can't use items while stunned/hexed either), so "use an item to
escape a stun" was never going to be buildable or realistic. A ROOT
(Shackleshot's terrain bind included) is different - it blocks movement but
not item/spell use, and was NOT in that early-out list, meaning items were
already reachable while rooted - there just wasn't a dedicated escape
branch. Added one, checked before the normal per-item loop: if
`b:IsRooted()`, self-cast Eul's Scepter (lifts the hero airborne, breaking
a terrain-tethered bind) if held and off cooldown, else self-target Force
Staff (physical reposition) if held and off cooldown. Generic - benefits
any hero holding either item, not just Shadow Shaman's victims.
**Deferred, not built**: a Shackleshot-specific "attack/destroy the bound
tree to break free early" mechanic - needs investigation into whether the
bot API even exposes the specific tree entity a given Shackleshot cast is
tied to before this is buildable at all; flagged for a dedicated
investigation pass rather than guessing at an API that may not exist.
Validated: `luac -p` full workspace (313 files) clean. Deployed via
SHA-256-verified copy to both the Workshop folder and the release folder.

### 0.7.10 - Laning standoff distance, structure-siege support dispatch, summon self-preservation, tower auto-attack, defend-mode Think() wiring, forced Gris-Gris cash-out (match 8983550316)

Confirmed via this match's log: 0.7.9's fixes held (hard jungle lock: zero
FARM-mode heartbeats for any pos1-3 before 20:00; `[TICB-ITEM]` diagnostics
now visible). Also found and fixed a real bug in 0.7.9.1's economy boost
(below), and root-caused 5 new reports.

- **`[TICB-ECONOMY]` never once appeared despite being wired and deployed
  correctly** (`mode_farm_generic.lua`): 20 generic `Script Runtime Error:
  error in error handling` lines clustered at the exact tick every hero's
  first `GetDesire()` call happens, immediately followed by Source's
  duplicate-message squelch (silences repeats of the same generic error for
  the rest of the match) - strong circumstantial evidence an uncaught error
  inside the un-pcall'd `EconomyBoost.Think(e)` call was silently killing
  the rest of that tick's farm-mode logic, every tick, for the whole match.
  Wrapped the call in `pcall` (prints `[TICB-ECONOMY][ERROR]` with the real
  message on failure) so a future recurrence is diagnosable and, more
  importantly, no longer kills farm mode's other logic on affected ticks.
- **Structure sieged by unopposed creeps, nobody responds** (new
  `DecisionPolicy.FindUnansweredStructureSiege`/
  `X.ShouldRespondToStructureSiege`, wired into `FuncLib/systems/defend.lua`):
  root-caused precisely - Dire's bot-lane T3 and both barracks fell in a
  36-second window while every tracked hero on both teams was clustered
  around mid, because both `DecisionPolicy.ShouldDefendBase` (used to abort
  pushes) and `defend.lua`'s own large threat-scoring system are gated on
  enemy HERO presence or special/siege creep types - a plain, unanswered
  creep wave chipping down a structure over minutes was invisible to both.
  Added a narrow, additive check: is one of our own structures losing HP
  with zero allies AND zero enemy heroes anywhere near it. Per explicit
  design choice, this pulls exactly the ONE closest alive support (pos 4/5),
  never cores, never the whole team.
- **`mode_defend_tower_top/mid/bot_generic.lua` had no `Think()` at all** -
  found while wiring the above: `FuncLib/systems/defend.lua`'s
  `r.DefendThink` is a fully-built movement/attack function but was never
  called from anywhere in the codebase; the three defend-tower mode files
  only ever defined `GetDesire()`. Added `Think()` to all three, calling
  `DefendThink` - previously, even if a defend mode "won" the desire
  arbitration, nothing after that ever moved the hero.
- **Bots not auto-attacking safe T1-2 towers with creeps around and no
  enemies visible** (`FuncLib/systems/push.lua`): the tower-attack-commit
  gate required BOTH `creepCover>=3` AND the tower already mid-attacking one
  of our own creeps (`creepTanking`) - a routine lull (fewer creeps, or the
  tower simply idling) fell through and did nothing even though the broader
  `safeCommit` check (ally count >= enemy count, own HP safe, no missed kill)
  already permitted it. Added an alternate condition: commit whenever
  `safeCommit` is true and zero enemy heroes are nearby, regardless of the
  creep-tanking coincidence.
- **Melee heroes still losing most last hits/denies, Radiant apparently
  never won a safelane all game** (`mode_laning_generic.lua`): the 0.7.9 fix
  capped the lane standoff distance at 450 but still used the enemy's FULL
  attack range as the floor - for melee vs. any ranged enemy that's still
  3x the hero's own reach as the *default* resting spot between fights. The
  reachability/timing math itself (`creep_policy.lua`) was independently
  confirmed correct - the problem was starting too far away for that math to
  ever say "reachable in time." Only half the enemy's range now counts
  toward the standoff, and the cap is tightened to 350.
- **Owned/summoned units (Warlock's Golems, Beastmaster's Boars, Nature's
  Prophet's Treants, Eidolons, etc.) fight to the death with no self-
  preservation** (`FuncLib/hero/minion_lib/illusions.lua`,
  `X.ConsiderRetreat`): root-caused precisely - the retreat check required
  BOTH `&lt;30% HP` AND an *absolute* `&lt;300 HP` floor. For squishy hero
  illusions (the module's original use case) those two are nearly the same
  threshold; for a tanky summon like a Golem (~1900 max HP) it meant never
  retreating until below ~16% HP, functionally too late. Removed the
  absolute floor - retreat now triggers at the intended 30%/25% HP
  *fraction* regardless of the unit's max HP. Also gave Warlock's Golems
  their Flaming Fists toggle (`hero_warlock.lua` `a.MinionThink`) - it was
  never referenced anywhere in the codebase at all before this.
- **Witch Doctor's Gris-Gris still unused past minute 30** despite 0.7.9.1's
  15:00 trigger in the shared `ConsiderItemDesire` pipeline: could not
  confirm from this match whether the shared-pipeline path fired or was
  starved by something else in that pipeline (still no cast-event log
  instrumentation to check). Per explicit request, added a guaranteed
  backstop directly in Witch Doctor's own per-tick script
  (`hero_witch_doctor.lua` `a.SkillsComplement`, first line, unconditional):
  force `Action_UseAbility` on Gris-Gris once `DotaTime()&gt;=15*60`,
  independent of the shared pipeline entirely.
- **Shadow Shaman's Serpent Wards allegedly still not attacking towers**:
  reviewed `attacking_wards.lua` in full - the hero>summon>tower>creep
  hierarchy and the walk-into-range fallback (both from 0.6.6) look
  correctly implemented and correctly wired for `npc_dota_shadow_shaman_ward`
  specifically; found no bug. Added a throttled `[TICB-WARD]` diagnostic
  (target chosen + whether a tower was even detected) so the next match can
  show directly whether this is our logic not running, choosing wrong, or -
  as the user suspected - a deeper engine-level quirk outside this
  codebase's control.
- **Not attempted this round** (flagged, not silently dropped): a generic
  "escape a shackle/disable via item or last-hitting the binding unit"
  behavior - no such pattern exists anywhere in this codebase for any hero,
  and building one generically is a new behavior system, not a bug fix,
  matching this project's own precedent (0.6.5) of not rushing a
  from-scratch system late in a session. Also unresolved: "Urnaconda" (an
  Aghanim's Shard-granted summon reported to share the same no-tower-attack
  attitude) - could not identify which hero/ability this refers to; flagged
  back to the user rather than guessing. Also unresolved: Mirana (pos4)
  repeatedly hit the `rebuildCount&gt;=5 and courier==0 and stash==0`
  stuck-item skip across 6 different items over the whole match, including
  a 0-gold `item_ward_sentry` - confirmed firing (per the now-visible
  `[TICB-ITEM]` log), but not yet root-caused; each trigger *permanently*
  drops that item from her build (`purchaseListInReverseOrder[...]=nil`),
  which may be a bigger problem than the gate merely being slow. Needs a
  dedicated pass with the item name/gold state at the moment of each skip.
- Validated: full-workspace `luac -p` (313 files, zero errors). Deployed via
  SHA-256-verified copy to both the Workshop folder and the release folder.

### 0.7.9.1 - Gold/XP multiplier rounding bug (economy_boost.lua)

User asked directly whether the x1.5 gold / x1.2 XP bonus (added in 0.7.8)
actually worked. Verified the module was correctly wired and deployed
(checksum-matched the Workshop copy that ran in the analyzed match), but
found a real bug on inspection: `math.floor(delta * (multiplier - 1))`
discards the bonus entirely on any small delta - passive gold/XP often
ticks in 1-2 unit increments, and `math.floor(1*0.5)` is always `0`, so a
hero whose gold only ever rose in small steps got little to no bonus;
only large gains (kills, bounties, big last hits) were actually topped up.
Rewrote to carry the fractional remainder forward per bot instead of
discarding it each tick, so the full multiplier lands over time regardless
of tick size. Also added a throttled `[TICB-ECONOMY]` log line (per bot,
every 60s) reporting cumulative bonus gold/XP granted so far - there had
been no way to directly confirm this was firing at all from a match log
before now. Could not retroactively confirm from the already-played match
(no diagnostic existed at the time, and the human player isn't logged by
`TICB-HEARTBEAT` so there was no same-match unboosted baseline to compare
against); next match's log will show it directly via the new tag.
Validated: `luac -p` clean. Deployed via SHA-256-verified copy to both the
Workshop folder and the release folder.

### 0.7.9 - Item-builds-focused fix batch from match 8983434267: dead diagnostic logging restored, PrioritizeBoots cost-blindness bug (Axe stall), Guardian Greaves/Boots of Bearing boots-supersede gap (Earthshaker double boots), stray-branch sell rule (Medusa), Gris-Gris teamfight branch

User reported specific per-hero build failures despite the buy-list arrays
themselves (verified independently) already being correct and well-ordered:
Axe (pos3) buying only Tango + Boots all game, Witch Doctor (pos5) buying
only Tango, Earthshaker (pos4) ending up with two boots-tier items at once,
Medusa (pos2) still holding one unsold Iron Branch at 36 minutes, and Witch
Doctor never using Gris-Gris. Investigated via a fresh log
(`8983434267`) plus a full read of `item_purchase_generic.lua`.

**Meta-finding first, since it explains why so little of this was visible
in any prior log**: every diagnostic in `item_purchase_generic.lua`
(`[Purchase]`, `[ARDM]`, `[PosSwap]`, the purchase-failure line, the
stuck-item-skip line) goes through the shared global `log()`
(`FuncLib/systems/log.lua`), which is a permanent no-op because
`FuncLib/systems/utils.lua` hardcodes `DebugMode=false` (flows into the
global `IsDebug` via `global_overrides.lua`). Only the separate `TICB-*`
tags (which use bare `print()`) were ever actually visible. Rather than
flip the shared `IsDebug` flag (which would also unmute a lot of unrelated,
much noisier debug output elsewhere), added a small always-on `PLog()`
wrapper local to `item_purchase_generic.lua` (prints under `[TICB-ITEM]`,
the same tag `farm_timing.lua` already uses) and swapped all 13 of that
file's `log(...)` calls to it. The next match's log will actually show
purchase failures and stuck-item skips going forward.

1. **Axe pos3 stuck at Tango + Boots - CONFIRMED root cause**
   (`item_purchase_generic.lua`, `PrioritizeBoots`/`BootsTierItems`): the
   0.7.7 pass that force-promotes a hero's earliest boots-tier item to be
   literally the 2nd item bought had `BootsTierItems` including the
   *expensive* boots tiers (`item_travel_boots`, `item_travel_boots_2`,
   `item_guardian_greaves`, `item_boots_of_bearing`) alongside the cheap
   ones. Axe's pos_3 list has no cheap `item_boots` at all - its earliest
   boots-tier entry is Travel Boots (~2500g), 10 items deep in his real
   build. The pass was force-inserting that 2500g item as purchase #2,
   ahead of Ring of Protection/Gauntlets/Crimson Guard/Blade Mail, so a
   pos3 with no head start on gold sat parked saving for it most of the
   game - matching "only ever bought Tango + Boots" exactly. This is a
   pre-existing regression from 0.7.7, not something new. Fixed by
   trimming `BootsTierItems` (used only by `PrioritizeBoots`) down to the
   cheap tiers only (`item_boots`, `item_phase_boots`, `item_power_treads`,
   `item_tranquil_boots`, `item_arcane_boots`) - any hero whose earliest
   boots-tier entry actually is one of the expensive/finished tiers now
   just buys their list in the normal authored order instead.
2. **Earthshaker double boots-tier - CONFIRMED**
   (`FuncLib/systems/inventory_policy.lua`, `X.SellRedundantBoots`): Guardian
   Greaves' recipe (Mekansm + Drum of Endurance + recipe) does not consume a
   plain Boots of Speed, so a build that goes boots -> Guardian Greaves (or
   -> Boots of Bearing, several pos4/pos5 lists do this) legitimately ends
   up holding both. The existing redundant-boots sell only checked for
   Travel Boots ownership as the trigger. Added
   `item_guardian_greaves`/`item_boots_of_bearing` as additional trigger
   conditions alongside Travel Boots.
3. **Medusa's unsold Iron Branch at 36 minutes - CONFIRMED**
   (`FuncLib/systems/inventory_policy.lua`, `OBSOLETE_AFTER`/
   `X.SellObsoleteItems`): `item_branches`/`item_double_branches` were never
   in the obsolete-sell list at all, and the one entry that did exist
   (Quelling Blade) only fires once literally all 9 inventory slots are
   full - a stray, never-consumed leftover branch has no path to ever being
   sold. Restructured `OBSOLETE_AFTER` to carry a per-item `requireFull`
   flag: Quelling Blade keeps its original conservative "only once truly
   stuck" behavior, while Iron Branch/Double Branches (10-minute threshold)
   now sell regardless of inventory fullness, since a 17g leftover
   component has no plausible late-game use and holding a slot for it is
   never correct.
4. **Witch Doctor never using Gris-Gris - found and fixed a wrong-mechanic
   bug, not a targeting/timing bug.** Initially widened the existing
   targeted-curse condition (teamfight branch), but the user pushed back
   that Gris-Gris is auto-granted at game start and consumed with no
   target - confirmed via web search (Liquipedia/Escorenews): Gris-Gris is
   Witch Doctor's innate Tier-0 item, granted automatically by the Dota
   engine itself (nothing in our Lua ever needs to grant it - and indeed
   `Buff/NeutralItems.lua`'s scripted neutral-item-granting system turned
   out to be dead code, never loaded by anything, so it was never a factor
   either way), sits in the neutral item slot, banks 1 gold/3s plus 100% of
   gold lost on death, and is consumed on SELF to cash out everything
   banked - it cannot be dropped or backpacked, so leaving it unconsumed
   also blocks a real Tier 1+ neutral drop from ever being held. The
   original `ConsiderItemDesire["item_gris_gris"]` (added last session)
   modeled it as a targeted enemy slow/curse entirely wrongly - rewrote it
   from scratch as a no-target self-cash-out (`'none'` target type,
   matching the same pattern used by `item_tome_of_knowledge`), firing once
   `DotaTime() >= 15*60`, the community-standard cash-out timing the user
   confirmed. `item_gris_gris` itself does not appear in
   `FuncLib/data/item_names.lua`'s item database at all (that table
   predates this item existing, most likely) - flagged in case any other
   code ever needs the "real" internal name confirmed against a live game.
5. **Witch Doctor stuck at Tango only - instrumented, not confirmed**: gold
   timeline shows WD was heavily dove/harassed most of laning
   (`kda=0/2/1` by 15 min), which alone plausibly explains slow itemization
   independent of any bug. One structural suspect was found and left
   alone rather than blind-patched: the stuck-purchase-recovery gate
   requires `rebuildCount>=5` *and* courier-value==0 *and* stash-value==0
   before ever abandoning a currently-unbuyable queued item, and
   `rebuildCount` only increments when both those values are already zero -
   a hero with persistently nonzero courier/stash value could in theory
   never reach the skip threshold. Left as-is pending the next match's
   `[TICB-ITEM] ... skipping stuck item` log line (now actually visible
   per the meta-finding above) rather than guessing at a fix for a
   condition that couldn't be observed this round.
- **On the user's "centralize everything, or collapse to 2 archetype
  builds" proposal**: recommended against the 2-archetype (pos1-3 carry /
  pos4-5 support) collapse - Pos 1/2/3 and Pos 4/5 want structurally
  different items even within "core"/"support," and the actual bugs found
  this round were all in the *shared* purchase/inventory engine (which
  already is centralized - one `item_purchase_generic.lua` and one
  `inventory_policy.lua` for all 128 heroes), not in the per-hero-per-
  position data. Fixing the shared engine's specific defects (as done
  above) addresses the reported symptoms without discarding
  position-appropriate itemization.
- Not changed this round: the `rebuildCount`/courier-stash gate (see
  item 5 above - instrumented for next time instead), and
  `ability_item_usage_generic.lua`'s own separate `log()` calls (ARDM/reload
  diagnostics, unrelated to the reported bugs - left dead for now).
- Validated: full-workspace `luac -p` (313 files, zero errors). Deployed via
  SHA-256-verified copy to both the Workshop folder and the release folder.

### 0.7.8 - 20-item batch from match 8983322596: starter items for every hero, hard jungle lock for cores, base-defend push abort, rune fallback dispatch, slot-14 purchase-gate bug, Mekansm/Urn supersede checks, FretBots removed with bot-only gold/XP multiplier, and several hero-specific fixes (CK, Earthshaker, Clinkz, Phoenix, Warlock, Skeleton King)

All 20 items came from the user's own review plus a fresh log/code
investigation of match `8983322596`. Scope decisions (jungle-lock strictness,
FretBots disable, item-ordering approach, delivery as one patch) were
confirmed via explicit questions before implementation.

1. **Universal starter items** (`item_purchase_generic.lua` bug, `BotsLib/hero_*.lua`
   data gap): root cause was NOT a purchase-loop bug but missing data - 44 of
   128 hero files had a pos_N buy list that opened directly with an expensive
   core item (e.g. Chaos Knight's pos_1 began `{"item_armlet",...}`,
   Earthshaker's pos_4 began `{"item_blink",...}`). Purchases are strictly
   sequential, so a hero literally could not buy anything until they could
   afford that first item outright - log-confirmed on Chaos Knight (gold flat
   at 600 for 90+ seconds, first purchase not until ~7 minutes in). Wrote a
   scripted audit+patch (`starter_items_audit.lua`, one-off, not committed)
   that scans every `m['pos_N']={...}` array and, only when the array's FIRST
   entry isn't already a recognized cheap/starter item, prepends a
   position-based starter kit (matching `common-starting-builds.txt`:
   tango/quelling/branches/circlet for pos 1, branches/faerie fire for pos 2,
   ring of protection/gauntlets for pos 3, wards/blood grenade for pos 4/5).
   62 arrays across 44 files patched; verified with `luac -p` across the
   whole workspace before and after.
2/4/9. **Pos 1-3 jungle/river attitude, pre-20:00 forced laning stage**
   (`FuncLib/systems/decision_policy.lua`, `X.ShouldForceLaneCommitment`):
   the 0.7.3 exception (`IsSafeToJungleNearLane` - "wave genuinely parked
   near own T1, someone's holding it") was still letting locked cores step
   away to farm nearby camps during the lock window. Per explicit choice,
   removed that exception entirely for pos 1-3: while `IsLaneLockActive()`
   (pre-20:00, no fallen T3), `ShouldForceLaneCommitment` now unconditionally
   returns true with no jungle escape hatch at all (`IsSafeToJungleNearLane`
   itself is left defined in case something else still wants the signal).
3. **Enemy heroes (and our own) standing too far from the wave, hard to
   last-hit, especially melee** (`mode_laning_generic.lua`): the lane
   stand-off distance formula (`math.max(ownAttackRange, 250,
   furthestEnemyAttackRange)`) had no upper bound, so facing a long-ranged
   enemy hero could push a hero 500-700+ units behind the wave by design -
   worst for melee heroes with the least reach to compensate. Capped the
   stand-off at 450 units (`math.min(..., 450)`); the existing
   harass/retreat combat logic elsewhere still pulls a hero back further if
   actually threatened, so this only removes the excessive *default*
   distance. Runs for both teams (shared file), so it also addresses the
   "enemy laners running away, our team wins the safelane" side of item 9.
5/19. **Earthshaker missing Basilius/boots/circlet, Mekansm rebought after
   Guardian Greaves, Urn stuck (no space, no Circlet)**
   (`BotsLib/hero_earthshaker.lua`, `item_purchase_generic.lua`): added
   Circlet + Ring of Basilius + a basic boots item ahead of Blink Dagger in
   both pos_4/pos_5 buy lists. Root-caused the Mekansm rebuy: nothing
   anywhere checked "already own the upgrade" before re-adding the base
   item, so a purchase-list rebuild (hero swap / PosSwap) that ran after
   Mekansm had already been consumed into Guardian Greaves saw it as "not
   owned" and queued it again. Added a supersede check in the purchase
   validity gate (`R(H)` in `item_purchase_generic.lua`): skip buying
   `item_mekansm`/`item_buckler` if `item_guardian_greaves` or
   `item_boots_of_bearing` is already owned, and skip `item_urn_of_shadows`
   if `item_spirit_vessel` is already owned.
6. **Full-inventory purchase deadlock** (`item_purchase_generic.lua`): found
   the actual mechanism behind "no space, courier stuck trying to deliver an
   item, no further purchases happen" - the live (non-ARDM) purchase
   function gated EVERY purchase behind `a:GetItemInSlot(14)==nil` (stash
   slot 14 completely empty), with no fallback if the courier had auto-
   stashed something there because both main inventory and backpack were
   full. Loosened the gate to `a:GetItemInSlot(14)==nil or
   f.CountBackpackEmptySpace(a)>0` (the same real-free-space check already
   used elsewhere in this file for secret-shop purchases), so a hero isn't
   permanently blocked just because slot 14 specifically is occupied while
   real space exists.
6 (rune half). **Only 1 of 4 bounty runes ever collected, others ignored
   all game** (`FuncLib/systems/rune_policy.lua`, `mode_rune_generic.lua`):
   log audit across a full match confirmed 2 of 4 bounty spots never got a
   single pickup attempt from anyone. Root cause: `GetBestRune()` requires a
   bot to be the single globally-closest ally to a rune's location
   (`IsTheClosestAlly`); whenever one hero happens to be globally closest to
   two or more bounty spots at once, every other teammate permanently fails
   that check for the "extra" spot too, with no fallback. Added
   `RunePolicy.IsAbandoned(bot, location)` (true if literally no ally is
   within 2500 units) and let any hero consider a bounty rune specifically
   when it's abandoned, not just when they're the closest.
7. **Phoenix harassing but never engaging/Sun Ray-ing** (`BotsLib/hero_phoenix.lua`):
   skill build trained Sun Ray for the first time at level 4, not level 1-2 -
   log confirmed Phoenix stuck level 1-2 for the entire observed harass
   window, meaning Sun Ray was flatly untrainable during it. Swapped the
   level-2/level-4 skill slots so Sun Ray gets its first point at level 2.
   Also relaxed the offensive engage branch's ally-count gate (previously
   required 2+ allies already in ATTACK mode within 900 units, a teamfight-
   only threshold) to also fire with just 1 nearby ally while laning.
8. **Clinkz Pos 2 build too item-light in lane, no boots, Searing
   Arrows/Strafe never used on creeps** (`BotsLib/hero_clinkz.lua`): buy list
   went straight from starter items into Dragon Lance/Desolator with zero
   stat item and zero boots anywhere in the array. Added Wraith Band + Power
   Treads early and Travel Boots (+ Travel Boots 2, matching the 0.7.7
   precedent of only adding the upgrade to lists that already build the
   base) before the late-game items. Root-caused the spell-usage gap:
   `ConsiderSearingArrows`'s autocast toggle and `ConsiderStrafe`'s wave-clear
   branch both checked `IsPushing`/`IsDefending`/`IsFarming` but never
   `IsLaning` - during ordinary laning the code fell through to the default
   "turn autocast off" branch and Strafe's neutral/lane-creep branches never
   ran at all. Added `IsLaning` to both gates plus a small dedicated lane-
   creep branch to each.
10. **Chaos Knight rushing Armlet then Boots of Travel with no mid-game
   items** (`BotsLib/hero_chaos_knight.lua`): per explicit instruction,
   inserted Magic Wand + Phase Boots + Bracer (pos_1) and Phase Boots +
   Bracer (pos_3) between the starter kit and Armlet, so he has a normal
   early curve before committing to the Armlet/late-item sequence; Travel
   Boots still arrives later in the same list, to be replaced by Travel
   Boots 2 (moved to the very end by item 17's pass).
11. **Warlock buying a Pipe recipe ahead of his real next item**
   (`item_purchase_generic.lua`): the stuck-purchase recovery path (fires
   after 5 failed rebuild attempts) scanned all 15 inventory slots for ANY
   item containing "recipe" in its name and jumped the FIRST one found to
   the front of the purchase queue, regardless of what was actually being
   saved for. Scoped the scan to only match a recipe whose base item equals
   `a.currBuyingItemInPurchaseList` (the item actually next in the build),
   so an unrelated leftover recipe can no longer hijack the purchase order.
12/13. **Bots grouping at a tower but not attacking despite no visible
   threat; groups reading as indecisive** (`FuncLib/systems/push.lua`): the
   ally/enemy "is it safe" head-count used a flat 1600-unit radius around the
   push location. Per explicit instruction, tightened to 1200 (blink range)
   so a distant, unthreatening enemy hero no longer counts against the
   safe-to-commit check; the existing 2.5s tower-commit lock
   (`_ticbTowerCommitTarget`/`_ticbTowerCommitUntil`, from a prior session)
   already suppresses tick-to-tick flip-flopping once a target is chosen.
14. **FretBots removed, replaced with a bot-only x1.5 gold / x1.2 XP
   multiplier**: confirmed with the user that "FretBots" here meant
   OpenHyperAI's own bundled sub-AI system (`FretBots.lua` and its full
   require chain - RoleDetermination, DynamicDifficulty, NeutralItems find-
   timing, Modifier, BonusTimers, its own separate Lone Druid handler), not
   the Dota lobby setting that lets custom bot scripts run at all. Confirmed
   nothing in the custom decision-making layer (`decision_policy.lua`,
   `lane_tactics.lua`, etc.) referenced any FretBots internals directly, and
   this project already has its own `BotsLib/hero_lone_druid.lua` /
   `hero_lone_druid_bear.lua` superseding FretBots' version. Disabled by
   renaming `FretBots.lua` -> `--FretBots.lua`, matching this codebase's own
   established disable-by-rename convention (already used for
   `--mode_wisdom_shrine_generic.lua` etc.). Updated the one in-game
   "try enabling the enhanced Fretbots mode" tip string in
   `FuncLib/systems/localization.lua` (English locale; found to be dead/
   unread data with no current caller, updated anyway per request). Added a
   new standalone module (`FuncLib/systems/economy_boost.lua`, hooked from
   `mode_farm_generic.lua`'s per-tick `GetDesire()`): tracks each bot's own
   gold/XP gain tick-to-tick and grants the extra 50%/20% on top via
   `ModifyGold`/`AddExperience` - only on positive gains (deaths/spending
   are never amplified), gated to `bot:IsBot()` so humans are untouched.
15. **Skeleton King never using Bone Guard** (`BotsLib/hero_skeleton_king.lua`):
   `ConsiderW` required the Bone Guard modifier to already be active before
   it would even consider casting the ability - meaning it could activate a
   recast/reinforcement but never the initial cast, so the shield never
   turned on in the first place. Added a leading branch: if the modifier
   isn't active yet, cast it once level >= 4 while in lane, farming, or
   facing enemies.
16. **Witch Blade never upgraded into Parasma**: added `item_parasma`
   immediately after `item_witch_blade` in all 9 hero files that build
   Witch Blade (Jakiro, Obsidian Destroyer, Puck, Queen of Pain, Silencer,
   Storm Spirit, Vengeful Spirit, Venomancer, Winter Wyvern).
17. **Aghanim's Scepter/Blessing, Boots of Travel 2, Aghanim's Shard, Moon
   Shard not reliably last** (`item_purchase_generic.lua`): added a generic
   `PrioritizeLateGameItems()` pass (same shape as 0.7.7's `PrioritizeBoots`),
   run at all 3 purchase-list-build call sites. It only reorders these five
   tokens when a hero's build already contains them (never adds one to a
   hero who doesn't build it), pulling them to the very end in the fixed
   order Scepter -> Blessing -> Boots of Travel 2 -> Shard -> Moon Shard.
18. **Neutral item actives**: audited `ability_item_usage_generic.lua`'s
   `ConsiderItemDesire` table against the current neutral item pool - found
   it already covers ~40+ neutral actives by name (including several added
   since 0.7.7's Gris-Gris fix - Iron Talon, Bullwhip, Havoc Hammer,
   Trickster Cloak, etc.), so no gap was found this round; left as-is.
20. **Team kept pushing mid while the enemy was already sieging the
   throne** (`FuncLib/systems/push.lua`, `FuncLib/systems/decisive_push.lua`):
   confirmed via `grep` that neither file referenced `DecisionPolicy` at
   all - once "decisive push" locked in, nothing ever re-checked whether the
   team's own base needed defending instead. Added
   `DecisionPolicy.ShouldDefendBase(bot)` as an early-out in both
   `Push.GetPushDesire` and `DecisivePush.GetPushDesire`, so a real threat to
   the ancient/high ground now overrides a committed push the same way it
   already overrides farm mode.
- Not separately re-touched this round: item 3's "hard-fixed Pos 3, why does
   Pos 1 still misbehave" framing - covered by items 1/2/4/9 together (the
   starter-item gap and the exception-free jungle lock were the actual
   remaining gaps; Pos 3's existing lock was already correct).
- Validated: full-workspace `luac -p` (313 files, zero errors) after every
  edit and again at the end. Deployed via SHA-256-verified copy to both the
  Workshop folder and the release folder.

### 0.7.7 - 15-item batch from bots-only spectated match (8983174204): rune pickup, mid aggression, lane-jungle contradiction, tower siege response, boots priority, ward tower engage, neutral actives, Aegis pickup, Ringmaster whip, throne-exposed defense, late-item builds

All items below came from watching a full 5v5 bots-only match (~53 min) as
Radiant spectator. Each was root-caused against the log/source before
fixing; scope decisions were made per the user's explicit answers.

1. **Bounty/Water rune false pickup timeout** (`rune_policy.lua`): log
   showed Razor standing on top of a rune (`distance=1`) for the entire
   2.25s retry window and still hitting `PICKUP_TIMEOUT` - `GetRuneStatus()`
   never flipped off `AVAILABLE` in that window, and the existing
   "resolved" signal check (rune type flips to -1 on pickup) only existed
   in a different branch (the one taken when `FindImmediatePickup` returns
   nil), not this hard-timeout branch. Applied the same resolved check
   here before blacklisting a rune that was very likely already collected.
2. **Mid too passive** (`lane_tactics.lua`, `mode_laning_generic.lua`):
   tuned existing lane-locked KILL/HARASS thresholds looser (killRatio
   1.5->1.35, riskRatio 0.15->0.20 for KILL; riskRatio 0.35->0.45,
   CountCreepsAttacking <=1->2 for HARASS), and broadened the last-hit
   priority desire override in `mode_laning_generic.lua` (previously gated
   to `pos1 AND a human plays pos5`, a narrow one-off case) to all cores
   (pos<=3) so a good last-hit isn't starved out just because the enemy
   laner is standing nearby, which is the lane's normal state.
3. **Pos1/mid still oscillating jungle/lane** (`decision_policy.lua`):
   found two *independent* jungle-permission judgments that could disagree
   in the same tick with no coordination - `mode_laning_generic.lua` asks
   `ShouldCoreTemporarilyJungle` (self-suppress laning desire), while
   `mode_farm_generic.lua` separately asks `ShouldForceLaneCommitment`
   (suppress farm desire). When they disagreed, both modes could report
   NONE simultaneously, letting some other mode with a modest baseline
   desire win by default - the actual mechanism behind the "indecisive"
   look. `ShouldCoreTemporarilyJungle` now short-circuits to false whenever
   `ShouldForceLaneCommitment` already said "return to lane", so the two
   can no longer contradict each other.
4. **Safelane towers falling early / support+pos1 absent** (new
   `DecisionPolicy.IsOwnTowerUnderSiege`): none of the existing jungle/task
   safety checks asked "is *my own* T1 under attack right now" - they only
   judged whether it was safe to *leave*. Wired as an immediate,
   highest-priority trigger into `ShouldForceLaneCommitment` (cores) and
   `lane_tactics.lua`'s `IsTaskSafe` (supports, interrupts an active
   pull/stack) so both return home the instant their own tower is
   contested, ahead of the wave-state exemption.
5/6/7. **Boots missing/buried in builds** (Underlord, Ringmaster,
   Earthshaker): not actually absent - e.g. Underlord's pos-3 list has
   Travel Boots 6th, behind Crimson Guard/Halberd/Lotus/Shard/Gungir, so a
   mid-game snapshot looks boot-less. Rather than hand-edit 128 hero files
   (many mix literal item strings with dynamic `RandomInt`-picked
   variables, too risky for a blind text pass), added a generic
   `PrioritizeBoots()` pass in `item_purchase_generic.lua` that runs
   wherever a hero's purchase list is (re)built and pulls the earliest
   boots-tier entry up to the 2nd item bought (never 1st, to preserve each
   hero's deliberate starting item).
8. **Wards not attacking towers** (`attacking_wards.lua`): tower detection
   was capped at the ward's own attack range (~500), with no fallback to
   walk closer - a ward near-but-not-quite in range just idled. Detection
   radius widened to `max(attackRange, 900)`; if a tower is found but not
   yet in range, the ward now walks toward it instead of standing still.
9. **Gris-Gris (and other simple neutral actives) never used**
   (`ability_item_usage_generic.lua`): confirmed there was no handler for
   `item_gris_gris` at all - or for most simple unit-targeted neutral
   actives - so once picked up it permanently occupied a slot. Added a
   `ConsiderItemDesire["item_gris_gris"]` entry modeled on the existing
   `item_urn_of_shadows` pattern: casts on a valid enemy target when going
   aggressive (offense) or when being chased while retreating (defense).
10. **Side lane waves disregarded**: the reactive wave-clear hook already
    added in 0.7.5 (`CreepPolicy.FindSafeWaveClearTarget`) is lane-agnostic
    (works on whatever lane creeps are nearby, own lane or not) - the gap
    was just that a farming core rarely got physically close enough to a
    side lane to trigger it. Per the user's "opportunistic only" choice
    (no new routing/split-push decision system), widened the detection
    radius in `mode_farm_generic.lua` from 1200 to 1600 so a core farming
    near a side lane is more likely to notice and clear a free wave in
    passing.
11. **Redundant boots** (Zeus keeping Arcane after Travels, general
    pattern): the existing sell-on-travel-boots logic only ran as a side
    effect of a full-backpack-near-shop cleanup pass, which could go
    unfired for an entire match if the hero was never both full and near a
    shop at once. Added `InventoryPolicy.SellRedundantBoots` - a standalone
    check (Dota allows selling from anywhere) that sells any earlier boots
    tier still held once Travel Boots (either level) are acquired, for all
    heroes.
12. **Aghanim's Blessing / Moon Shard / Travel Boots 2 missing from
    builds**: audited all 128 hero files - Moon Shard was already in 126/128
    and Travel Boots 2 in 101/102 of the heroes that build base Travels, so
    those two were nearly complete already. Aghanim's Blessing was in 0/128.
    Wrote a scripted pass (same real-`lua.exe` technique as the 0.7.6 item
    audit) that appends, per buy-list array: Aghanim's Blessing as the last
    item to any list that already builds Aghanim's Scepter (261 arrays
    across 86 files), Moon Shard to the few lists missing it, and Travel
    Boots 2 to lists that already build base Travel Boots but not the
    upgrade (skipped entirely for heroes that don't build Travels at all,
    per the user's instruction). Verified with a full `luac -p` pass on all
    128 files afterward and a manual diff spot-check.
13. **No Aegis pickup after Roshan** (`mode_roshan_generic.lua`): this
    mode's own desire collapses to NONE the instant `IsRoshanAlive()` flips
    false, and the only dropped-item pickup logic elsewhere
    (`item_purchase_generic.lua`) explicitly filters to items *the bot
    itself* dropped - nothing anywhere ever went to claim Roshan's aegis.
    Added a `FindDroppedAegis` check (scans `GetDroppedItemList()` near the
    current Roshan pit) that keeps this mode's desire at VERYHIGH and
    routes `Think()` to walk to and pick up an unclaimed aegis until
    someone gets it.
14. **Ringmaster cancelling autoattacks while farming**: found he already
    has a full custom ability script embedded in `BotsLib/hero_ringmaster.lua`
    (like other heroes) - not missing one, as first assumed when asking the
    user about this. The actual bug: `TameTheBeastsCrack` (his whip, which
    a `b.whip_to_farm` state flag confirms is also used for clearing
    waves) fired via immediate `Action_UseAbility`, which interrupts an
    in-progress attack windup - unlike sibling abilities in the same
    function (`WheelOfWonder`, `TameTheBeasts`, etc.) that correctly use
    the queued `ActionQueue_UseAbility*` form. Fixed by queuing the cast
    specifically when `b.whip_to_farm` is the reason (kill/engage/retreat/
    push/defend/miniboss/aoe_kill casts stay immediate, since those
    genuinely need instant response).
15. **Passive defense with throne exposed** (`decision_policy.lua`): added
    `X.IsThroneExposed()` (true once any barracks has fallen) and used it to
    widen `ShouldDefendBase`'s ancient-defense radius from 4000 to 5500 once
    true, so farm/roam desire is suppressed proactively for anyone in that
    wider radius rather than only once an enemy is already right on the
    ancient.

Validated: full-workspace `luac -p` (321 files, all pass) both mid-session
and again after the bulk 128-file item-build pass. Deployed via
SHA-256-verified copy to both the Workshop folder and the release folder.

### 0.7.6 - Fixed cosmetic-placeholder items contaminating 83 of 128 hero buy lists (major), fixed obsolete-item-sell trigger

User asked for a full item-build audit ("check all item builds and make
sure no item build has an error"), plus clarified 0.7.5's obsolete-item
feature was meant to unblock stuck builds specifically, not proactively
tidy up on a timer.

- **Root cause found via static audit**: wrote a script (real `lua.exe`,
  not the engine) that extracted every `m['pos_N']={...}` / `sBuyList']=
  {...}` buy-list array literal from all 128 `BotsLib/hero_*.lua` files and
  cross-checked every token against the canonical item list
  (`FuncLib/data/item_names.lua`) plus the neutral item table. Result: 43
  of 128 heroes had their buy list start with a cosmetic wearable/arcana
  name instead of a real item - e.g. Alchemist's Pos 1 build literally
  began `{"item_bristleback_outfit", "item_radiance", ...}`. 15 distinct
  bogus tokens appeared 200 times total across 83 files (`_outfit` cosmetic
  placeholders like `item_tank_outfit`/`item_mage_outfit`/`item_priest_
  outfit`/etc., and arcana weapon names like `item_disperser`/
  `item_devastator`/`item_harpoon`/`item_angels_demise`/`item_phylactery`).
  These read as leftover role-archetype template placeholders (the outfit
  names literally match hero archetypes - "tank", "mage", "priest",
  "ranged_carry" - suggesting a generation template that was never fully
  replaced with a real item for every hero/position). Effect: the purchase
  state machine wasted early cycles trying to resolve a non-existent first
  "item" before reaching the real build - a genuine, if usually minor,
  drag on early-game item timing for the majority of the hero pool.
- **Fix**: scripted removal of all 15 confirmed-bogus tokens from every
  buy-list literal, regardless of quote style or position in the list.
  Verified: re-ran the audit (zero remaining), checked for stray-comma
  artifacts (none), spot-checked several diffs by hand, and confirmed
  `sSellList`s were untouched (tokens only ever appeared in buy lists).
- **Obsolete-item-sell trigger fixed** (`inventory_policy.lua`): per the
  user's clarification, `SellObsoleteItems` now only sells (Quelling Blade,
  still gated at 14:00+) once the inventory is completely full - i.e. only
  when it would actually be blocking the next purchase/pickup - rather
  than unconditionally once the timer passes regardless of whether there's
  a real space problem.
- Validated: `luac -p` full-workspace loop, clean, both this round and
  after the 83-file bulk edit. Deployed via SHA-256-verified copy (all 128
  `BotsLib/*.lua` files individually verified) to Workshop folder and
  release folder.

### 0.7.5 - Proactive safe-wave push for cores, obsolete starter-item auto-sell

Same round as 0.7.4's lane-assignment fix - two smaller, contained items
from the user's 8-item list, implemented now; the rest (shared team push-
priority system, general ward-clearing, general blink-combo rule, fog-
respecting retreat pathing) explicitly scoped and deferred to the next
round (the user's own planned bots-only spectator match) rather than rushed.

- **Passive-core fix** (`mode_farm_generic.lua`): `CreepPolicy.
  FindSafeWaveClearTarget`'s attack-the-wave logic already existed, but its
  only caller was `mode_laning_generic.lua`'s `Think()` - which only runs
  when THAT mode is active. Farm mode is very often the active mode for a
  core near its own lane, and had no equivalent "there's a free, safe wave
  right here" reflex of its own, just neutral-camp routing - so a core
  could end up doing nothing productive next to an attackable, hero-free
  wave (the Skywrath Mage report). Added the same check directly to farm
  mode's `Think()`, so it's the default regardless of which mode nominally
  won that tick.
- **Obsolete starter-item auto-sell** (`inventory_policy.lua`): added
  `X.SellObsoleteItems`, an explicit, narrow, threshold-based list (Quelling
  Blade only, sellable after 14:00) rather than a general "looks outgrown"
  heuristic, per the user's conservative choice. Wired into
  `item_purchase_generic.lua`'s `ItemPurchaseThink` alongside the existing
  `InventoryPolicy.Optimize` call.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.
  Not yet verified in a live match.

### 0.7.4 - Fixed Dire's lane-assignment scramble (major - likely explains much of the multi-session "Pos 1 river attitude" saga) (match 8983102083, 42 min)

0.7.2/0.7.3's new `[TICB-VALIDATE]` lane check immediately paid for itself:
this match showed Dire Pos 1 Bristleback assigned `lane=MID` (expected TOP),
Pos 2 Underlord assigned `lane=BOT` (expected MID), Pos 4 Warlock assigned
`lane=TOP` (expected BOT) - a clean one-slot rotation, Dire only, zero
mismatches on Radiant.

- **Root cause**: `hero_selection.lua`'s `az()` function, which populates
  `f[team]` (the array `UpdateLaneAssignments()` returns - read by the
  ENGINE itself, keyed by the same raw `GetTeamPlayers(team)` index it uses
  to apply lanes to each player). Radiant's branch does this correctly:
  `f.TEAM_RADIANT[Z] = V[RoleAssignment[Z]]`, storing and reading at the
  same index `Z`. Dire's branch was different: it processed the human
  first, then the bots, storing results into a *remapped* "human-first"
  index `aB` while still looking the lane VALUE up using the *raw* index
  `Z` (`f.TEAM_DIRE[aB] = W[RoleAssignment[Z]]`) - two different indices
  into the same array. Since `RoleAssignment` is unconditionally reset to
  plain identity `{1,2,3,4,5}` before this runs (confirmed - this was a
  leftover from the pre-0.5.0 role-shuffling system, which used to give
  `RoleAssignment[Z]` real per-slot meaning), this reduces to `f.TEAM_DIRE[aB]
  = W[Z]` - silently correct only on the coincidence that the human already
  sat at Dire's raw slot 1, and scrambled by one rotation otherwise. Cross-
  referencing Bristleback's heartbeats confirmed he spent the *entire*
  42-minute match with `lane=MID` - not random wandering near the river/
  Roshan/secret-shop area as it looked, but a hero correctly, consistently
  playing the wrong lane the whole game, because that lane runs right past
  that exact area. This is very likely a significant contributor to many of
  this session's "Pos 1/2 river attitude" reports whenever the human
  happened to be on Dire.
- **Fix**: simplified Dire's branch in `az()` to exactly mirror Radiant's
  (`f.TEAM_DIRE[Z] = W[RoleAssignment[Z]]`), dropping the now-pointless
  human-first two-pass/remap bookkeeping entirely.
- Also ran the full hero-pool distribution audit again and reviewed this
  match's `TICB-VALIDATE` output for position/weight mismatches (0.7.0's
  fix) - none found; only the lane-side bug above.
- Validated: `luac -p` full-workspace loop, clean. Deployed via
  SHA-256-verified copy to Workshop folder and release folder.

### 0.7.3 - Creep-wave-gated farm exception for cores, rune-stall diagnostics

Follow-up to the 0.7.2 findings-and-questions round on match 8983037341.
Per the user's explicit design choices (asked via AskUserQuestion):

- **Creep-wave farm gate** (`decision_policy.lua`, `X.IsSafeToJungleNearLane`):
  replaces "was the raw distance to lane front the right signal for
  farm-vs-lane" with the thing the user actually pointed at - a locked core
  (Pos 1-3 only, supports untouched) may now leave its wave to farm nearby
  camps ONLY while (a) it's within 2200 units of the lane's enemy T1 tower,
  (b) both an allied AND an enemy lane creep are near it (the wave is
  genuinely parked there, not just "somewhere"), and (c) at least one hero
  (either side) is within 1400 units of that tower to hold the wave. The
  moment any of that stops being true, `ShouldForceLaneCommitment` forces an
  immediate return with no grace period (tracked via a one-shot
  `_ohaWasJungleExempt` flag) - explicitly chosen over holding the exemption
  or finishing the current camp. This directly targets the Gyrocopter/
  Alchemist jungle-oscillation pattern: the old distance leash flickered
  tick-to-tick with no regard for what the lane itself was doing; this gate
  only opens when the wave's position already justifies it, which is a far
  more stable signal. The pre-existing distance/hysteresis logic
  (`LaneDiscipline.ShouldReturnToLane` + 0.7.0's 18s hold) remains as the
  fallback for the default "come back, nothing justifies where you are"
  case - this is additive, not a replacement of that system.
- **Rune-pickup stall diagnostics** (`rune_policy.lua`): investigated the
  Witch Doctor bounty-rune stall (confirmed via log: closed to 56 units,
  still `PICKUP_TIMEOUT`'d) but per the user's choice, added diagnostics
  before attempting a fix rather than guessing. `TICB-RUNE` lines now also
  include the bot's current action type (resolved by name via live
  `BOT_ACTION_TYPE_*` globals, not a guessed number), active mode, and
  whether the rune's location is currently pathable - enough to tell next
  time whether it's a stuck order, a competing mode overriding the pickup,
  or something else.
- **Explicitly deferred, not forgotten**: the Alchemist-naming cosmetic
  issue (engine-level race on the first-created bot slot, always Pos 1,
  doesn't affect gameplay - user chose to deprioritize); the vision/
  fog-of-war finding (350+ call sites use an omniscient `GetEnemiesNearLoc`
  vs. 19 using the vision-respecting `GetLastSeenEnemiesNearLoc` - user
  chose to leave as-is for now, treating it as inherited "danger-sense"
  rather than a bug); and the push-priority/base-race feature (item 6 from
  the user's list) - a distinct, sizably-scoped new feature not yet
  designed or built.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.
  Not yet verified in a live match.

### 0.7.2 - Fix false-positive lane validation warnings (match 8983037341, 38 min)

0.7.1's new lane-validation check fired at `ConfigurePurchaseList` time, but
`bot:GetAssignedLane()` reliably still reports `0` (unresolved) at that
point in the pregame sequence - every single hero in this match's log threw
a `[TICB-VALIDATE][WARNING] ... assigned lane=0` false positive, and
`TICB-ITEM` itself printed `lane=?` for the same reason. Split the check:
`ValidatePositionWeight` (doesn't depend on lane) still runs immediately;
`ValidateLane` is now deferred to the first `Heartbeat` call per bot
(`decision_log.lua`), by which point lane assignment has settled. Position-
weight validation itself found nothing wrong this match - every hero's
label matched its weight table, consistent with 0.7.0's fix holding up.

This round is otherwise a large findings-and-questions pass on 7 new
observations from the match (naming, Pos 1 core farm/lane indecision, rune
pickup stall, tower-defense passivity, vision/fog-of-war, push priority,
creep-wave-based farm/lane decisioning) - see conversation log for the full
writeup; no further code changes made pending the user's answers to avoid
a large speculative rewrite of the farm/lane/defend systems.

### 0.7.1 - Proactive audit: self-validating position/lane logging, hero-pool distribution check, recursion safety cap

No new match yet (this round was requested before the next test) - a
proactive audit of hero picking/position/lane assignment for further small
bugs, plus a naming question about the previous match.

- **Naming question answered from the log, not a code change**: checked
  match 8982296896 (the one 0.6.9's name-pool fix was validated against) -
  its 9 `ClientPutInServer` lines are all from the HULIGANI/VISION roster
  pair, no "TSpirit"/"Yatoro" anywhere in the file, and Anti-Mage (Pos 1,
  playerID 0) maps to a real assigned name ("HULIGANI.ssnovv1") by the same
  sequential-apply contract used throughout this codebase. Could not find
  evidence of either report in this log - most likely either a recollection
  of the earlier match that genuinely did use the TSpirit roster
  (8982243476, before the 0.6.9 fix), or a live client-side rendering quirk
  the text log wouldn't capture either way. Nothing changed here; flagged
  back to the user to double check on the next occurrence.
- **Hero position-weight table audited** (`FuncLib/data/hero_pos_weights.lua`,
  127 heroes): no malformed entries, no all-zero (unpickable) heroes, every
  position has a healthy pool of eligible heroes (56-125 out of 127,
  lowest as expected for Pos 5 hard support). The weight *data* was never
  the problem - confirms 0.7.0's diagnosis that the bug was purely in how
  the picked position got relabeled afterward, not in what got picked.
- **Added a self-check that would have caught the Jakiro bug immediately**:
  `farm_timing.lua`'s `ConfigurePurchaseList` (already the single place
  `TICB-ITEM` fires once per hero) now also cross-checks the assigned
  position against that hero's own weight table entry, and the assigned
  lane against the expected lane for that position/team - logging
  `[TICB-VALIDATE][WARNING]` immediately if either ever looks wrong again.
  `TICB-ITEM` itself now also prints the resolved lane.
- **Found and defused a latent, unconfirmed-in-practice bug**: hero
  selection's candidate-pool builder (`N(D,J)` in `hero_selection.lua`)
  recurses on itself with no depth limit whenever fewer than 6 heroes pass
  its archetype filter, re-rolling `RandomInt` against the same weight
  table each time with no guarantee of eventual success - a theoretical
  unbounded-recursion/stack-overflow risk under a heavily
  banned/customized hero pool, never observed to actually fire in these
  logs. Added a 25-attempt cap as cheap insurance; normal-pool behavior is
  unaffected (this codebase always has 50+ eligible heroes per position).
- **Heartbeat logging expanded**: `TICB-HEARTBEAT` now also includes
  kills/deaths/assists and current target unit, on top of the existing
  hp/mana/level/gold/mode/exit-reason - closer to "all the small
  background information" requested.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.
  Standalone distribution audit run via a real `lua.exe` interpreter
  against the actual `hero_pos_weights.lua` module (script not committed -
  one-off analysis, results captured here).

### 0.7.0 - Position-label mismatch fixed (root cause of Jakiro-as-Pos-1 and likely much of the river-attitude reports), lane-commitment hysteresis (match 8982296896)

Match reported: naming confirmed fixed by the user's own observation; Radiant
Pos 1 Anti-Mage drifted/thrashed starting ~4:00 despite good early laning;
Dire's Jakiro was labeled Pos 1 despite being a support hero.

- **Root cause found: `role.lua`'s `GetPosition()` and `hero_selection.lua`'s
  picking loop use two different player-enumeration calls that can disagree
  on order.** Picking correctly draws each hero from a position-weighted
  pool (`hero_pos_weights.lua`; Jakiro's weight for Pos 1 is a flat `0` -
  mathematically impossible to draw for that slot, so it was picked
  correctly, almost certainly for Pos 4/5). But the position *label* shown
  everywhere else (`TICB-ITEM`, lane-lock, `IsCore`, every hero-specific
  script) comes from a completely separate function that re-derives it by
  scanning `GetTeamPlayers(team)` (no sort arg) and using the scan index
  into a fixed `{1,2,3,4,5,...}` table - while picking itself enumerated
  players via `GetTeamPlayers(team, true)`. When those two enumerations
  don't agree, the hero drafted for one role gets labeled with another
  team's-list-index-based one. This is the same class of "engine assigns
  sequentially with no role awareness" issue that caused the 0.6.4/0.6.5
  naming bugs, except for gameplay *positions* this time - which is far
  more consequential, since every lane-lock/farm-focus/harass-balance fix
  from 0.6.6 onward is built directly on `GetPosition()`. A support hero
  mislabeled as Pos 1 gets held to the hard-carry farm-priority/lane-lock
  rules, while whichever hero should have been Pos 1 may get mislabeled a
  support and left free to roam - a strong candidate explanation for
  "good for the first few minutes, then falls apart."
  - Fix (per explicit request: label should match what the hero was
    actually picked for): `hero_selection.lua`'s `b7()` now records
    `i.PickedPosition[playerId] = Z` at the exact moment a bot's hero is
    selected from pool `Z`, using the authoritative pick-time index instead
    of ever re-deriving it later.
  - `role.lua`'s `GetPosition()` had an existing same-purpose cache
    (`a.HeroPositions`), but it's a memo of the buggy scan's *own* answer,
    and gets wiped whenever `GetAssignedLane()` changes for that bot - which
    would have silently reintroduced the mismatch mid-game even after a
    correct pick, matching the "fine at first, breaks around minute 4"
    timing. Added a second, never-cleared table (`a.PickedPosition`) that
    `GetPosition()` now checks first, before falling back to the scan -
    immune to that wipe.
- **Lane-commitment hysteresis**: `LaneDiscipline.ShouldReturnToLane` can
  flip true/false tick-to-tick right around its distance threshold, and
  since farm mode re-earns an `ABSOLUTE` camp desire the instant it drops
  false, a locked core sitting near that boundary visibly thrashed between
  LANING and FARM (and by extension ATTACK/RETREAT) every ~10s - read as
  "undecisive." `DecisionPolicy.ShouldForceLaneCommitment` now holds a
  return-to-lane commitment for a minimum 18s once triggered, instead of
  re-evaluating every tick.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.
- Not yet re-verified in a live match - this is the biggest-blast-radius
  change of the session (touches the function nearly everything else reads
  position from), so the next match's `TICB-ITEM` lines are the thing to
  check first: hero-role fit should look sane for every position, on both
  teams, all game.

### 0.6.9 - Rune-chase river-drift root cause (3rd site), name-pool dupes, sell-from-anywhere fix (match 8982243476)

Match ended 3:40, human Dire Pos 2/3 Doom. Reported: Radiant Pos 1 Monkey King
and Pos 2 Nevermore still oscillating/idling near the river; Radiant Pos 1
had no name; concern that inventory space is stopping cores from finishing
item builds.

- **Root cause of the continuing river drift**: `mode_rune_generic.lua`'s
  `coreLeashed` check (added in 0.6.4 to stop pos 1/3 chasing distant runes)
  used `b.IsInLaningPhase()` - the exact same flag identified as fragile in
  0.6.7 (only set by `mode_laning_generic.lua`, stuck false for the whole
  pre-horn `DotaTime()<0` window and also false during recognized `laning
  mode` early-outs like enemies-near-ancient or push situations). With
  `coreLeashed=false`, pos 1/3 were free to chase ANY closest safe rune
  map-wide - including the pregame power rune at the river - with no
  distance limit. This is the third place this same flag has caused a
  "supposedly restricted, actually silently unrestricted" bug (0.6.7 was
  the secret shop; this is rune-chasing). Fixed both `GetBestRune()` and
  `GetLaningRuneDesire()` to use `DecisionPolicy.IsLaneLockActive()` instead
  (flag-independent, matches the shared 20:00/pre-T3 lock window).
- Confirmed via heartbeat log that pos 1/2/3 all shared active mode 17
  during the stall and converge on nearly identical coordinates - consistent
  with several of them independently qualifying for the same unleashed rune
  pursuit. Could not conclusively name mode 17 from memory (Valve has added
  modes like Outpost over time, shifting the classic enum), so added a
  `ModeName()` resolver to `decision_log.lua`'s heartbeat that reads the
  live `BOT_MODE_*` globals at runtime instead of a hardcoded/guessed table -
  future logs will name the mode directly instead of a bare number.
- **Bot naming**: `[TICB-NAMES]` was silently never appearing in any log
  because it used `print(...)` instead of this codebase's `log(...)`
  convention - fixed. Also found and fixed a real defect in
  `hero_selection.lua`'s `GetBotNames()`: it shuffled and returned the FULL
  12-entry array `team_names.lua` builds (5 real roster identities padded
  out to 12 slots for LAN-substitute support, e.g. index 12 is identity #2
  + ".12"), so a normal 5-bot team's draw could land both an identity and
  its padded-suffix duplicate (e.g. "Larl" and "Larl.12" on two different
  bots) - looks like a broken/duplicate name even though the strings
  technically differ. Now only shuffles/uses the first 5 (one per position,
  all genuinely distinct). Root cause of the specific "Monkey King has no
  name" report couldn't be confirmed from this log (no evidence of an empty
  string reaching the engine) - the `[TICB-NAMES]` fix means the next
  occurrence will be traceable.
- **Item/inventory space**: found a genuine bug, worsened by our own
  lane-lock changes. `item_purchase_generic.lua`'s full-inventory
  make-room-for-purchase sell logic required being within 200 units of the
  fountain or secret shop to fire - but selling doesn't require shop
  proximity in Dota 2 (unlike buying), and other unconditioned
  `ActionImmediate_SellItem` calls elsewhere in the same file confirm this.
  With Pos 1-3 now locked in lane until 20:00 (0.6.6/0.6.7), a core with a
  full inventory had no way to clear space for its next purchase until
  returning to base - directly causing "items not finishing due to space."
  Removed the proximity requirement from that gate; left the separate
  paired-item/outdated-boots cleanup gate (a lower-priority tidying pass)
  proximity-gated as before.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.

### 0.6.8 - Secret-shop hero-walk now defers to courier auto-dispatch

Follow-up to 0.6.7, prompted by the user asking "why not just use the
courier?" - correct instinct. `ability_item_usage_generic.lua` already has
an automatic courier dispatch (`COURIER_ACTION_SECRET_SHOP`) that sends the
courier to buy the moment `bot.SecretShop` turns true, with its own
2.3s-cooldown/no-enemy-near-shop safety checks, and is flatly blocked before
`DotaTime()<-56` (most of the pregame draft window). `mode_secret_shop_generic.lua`
(the mode that walks the *hero* there) only deferred to it if the courier
was `COURIER_STATE_MOVING` *at that exact instant* - so in the gap between
`bot.SecretShop` flipping true and the courier actually taking off, the hero
mode raced ahead uncontested and pulled the hero itself, defeating the whole
point of having a courier fetch it. This was a general redundancy affecting
every hero all game, not just Pos 1-3 pregame.

- Added `bot._ohaSecretShopPendingSince` tracking and a 30-second courier
  grace period: the hero-walk branch (aside from the courier-is-dead
  fallback, which fires immediately as before) now only activates if the
  courier hasn't managed to start moving within 30s of the item becoming
  purchasable - a real fallback for a stuck/busy courier, not a race.
- 0.6.7's `DecisionPolicy.IsLaneLocked` gate on this same mode stays in
  place as a hard backstop specifically for Pos 1-3 during the lane-lock
  window, so even in a courier-dead edge case cores still won't leave lane
  before 20:00/a fallen T3.
- Validated: `luac -p` clean. Deployed via SHA-256-verified copy to Workshop
  folder and release folder.

### 0.6.7 - Secret-shop pregame drift fixed, Pos 1-3 harass rebalanced, supports tuned more aggressive (match 8982169848)

Root cause found via heartbeat log: Radiant Pos 1 Alchemist (and matching
reports of Dire Pos 1/Radiant Pos 3) was walking to map-center/river-adjacent
secret shop and idling there for ~20-30s right at horn (0:00), costing early
last hits and leaving Alchemist level 1 at ~1:00, level 2 by minute 6.

- **Root cause**: `mode_secret_shop_generic.lua`'s guard against pulling
  Pos 1-3 to the shop during laning depended on `J.IsInLaningPhase()`, which
  just reads `bot.isInLanePhase` - a flag only `mode_laning_generic.lua`
  ever sets, and that file returns `NONE` at its very first line
  (`DotaTime()<0`) *before* setting it. For the entire pre-horn strategy-time
  window the flag was stuck false, so the guard never engaged; if the hero's
  item build wanted anything from the shop (`bot.SecretShop=true`), that mode
  won with 0.7-0.85 desire (vs. farm/laning's ~0) and dragged the core to the
  shop the instant the game started. Fixed by gating on
  `DecisionPolicy.IsLaneLocked(bot)` (time+position, no dependency on another
  mode's execution order) instead of the fragile flag - also extends the
  window from the old hardcoded 12:00 to the shared 20:00/pre-T3 lock.
- **Pos 1-3 harass rebalance**: 0.6.6's lane-lock combat gate only allowed a
  fight if the core had just been attacked, or an exceptionally clean/safe
  kill was available - reported as too passive ("only use spells when
  attacked"). Loosened to also allow a safe in-range poke (`HARASS`) when an
  enemy hero is already standing within the core's attack range + 150, risk
  is low, allies aren't outnumbered, and it won't cost a last hit
  (`HasDyingCreep` check) - still never chases or steps out toward a fight.
- **Supports tuned more aggressive**: no specific bug reported, just general
  tuning per request. Pos 4-5's `HARASS` risk tolerance raised from
  `0.62*aggression` to `0.75*aggression` and simultaneous-attacking-creep
  cap raised from 2 to 3, so supports lean harder into poking/harassing
  during laning. Deny priority (`CreepPolicy.HasPriorityCreep`) already
  checked denies before last hits for position >= 4; left untouched as
  already correct.
- Validated: `luac -p` individually and full-workspace loop, both clean.
  Deployed via SHA-256-verified copy to Workshop folder and release folder.

### 0.6.6 - Pure-farm lane lock, hard 30-min Roshan gate, ward target hierarchy, base-defend trigger, heartbeat logging (match 8982026058)

Confirmed via this match's log: 0.6.5's lane-leash kept cores geographically
near their lane, but they were still cycling HARASS/PRESSURE/LANE_RECOVERY
every 2-10 seconds continuously (often at near-zero damage ratio), consuming
100% of their attention and leaving no time to last-hit - explains
Phantom Lancer being level 4 at minute 10. User requested (and confirmed via
clarifying questions) a much stricter "pure farm focus" for positions 1-3.

- **`decision_policy.lua`**: added `X.IsLaneLockActive()` (DotaTime() < 20:00
  AND no Tier-3 tower fallen anywhere - shared by every system below so "must
  stay in lane" means the same window everywhere) and `X.IsLaneLocked(bot)`
  (position <= 3 AND lock active). `ShouldForceLaneCommitment` now built on
  top of these. Added `X.ShouldDefendBase(bot)`: any position, any enemy hero
  merely seen near the ancient (4000 units) or on our own high ground forces
  an immediate farm-desire suppression, overriding even the lane lock -
  addresses "force all bots to defend base" (item 4). This layers on top of
  the base engine's own slower defend-desire system rather than replacing it.
- **`lane_tactics.lua`**: `EvaluateCombat` now skips the entire
  HARASS/PRESSURE decision tree while lane-locked, unless the bot was
  directly attacked in the last 2.5s (a genuine defensive trade) - only an
  exceptionally clean, low-risk kill (ratio >= 1.5, risk <= 0.15, not
  outnumbered) is allowed through untouched. `SelectNeutralTask`
  (pull/stack) is also skipped while locked - no side-tasks, pure lane focus.
  Now requires `decision_policy.lua` (no circular dependency - traced the
  full require graph).
- **`combat_coordination.lua`**: the 3-bot "punishment" system's lane
  exemption now uses the same shared `IsLaneLocked` - locked cores can never
  participate in cross-map coordinated ganks, matching "no assisting other
  lanes."
- **`objective_policy.lua`**: Roshan gate rewritten per explicit
  instruction. `MIN_ROSH_TIME` raised 15:00 -> 30:00 with zero exceptions;
  the human-ping bypass path removed entirely (was also present as a
  *separate*, looser bypass inside `mode_roshan_generic.lua` itself, but
  traced that file's `GetDesire()` and confirmed `ObjectivePolicy.GetState()`
  is checked first and unconditionally, so tightening this one gate is
  sufficient regardless of that file's own logic). The advantage check now
  counts bots only (`IsPlayerBot` filter) so a human's presence doesn't
  factor in. Added death-during-commit detection: if ally-alive-bots drops
  while `commitRoshan` was true, the sticky 50s commit window is cleared
  immediately rather than riding out - "forget the roshan and go back to the
  tactics," no fixed cooldown, just requires the numbers criterion to be
  freshly re-satisfied (naturally harder right after a death, per the user's
  own answer: "until next full team wipe/reset").
- **`FuncLib/hero/minion_lib/attacking_wards.lua` +
  `.../minion_lib/utils.lua`**: rewrote the target-priority hierarchy for
  all "attacking ward" minions (Shadow Shaman's Serpent Wards, Venomancer's
  Plague Wards, Witch Doctor's Death Ward - one shared file covers all
  three). Old order was hero -> any enemy creep -> tower, so a ward parked
  near a tower with nothing else in its short attack range sat fully idle.
  New order per explicit clarification: enemy heroes -> enemy-controlled
  summoned units (familiars, dominated creeps, treants - detected via
  `GetPlayerOwnerID() >= 0`, which plain lane/neutral creeps don't have) ->
  towers/buildings -> plain enemy creeps (last resort, so it's never idle).
- **`creep_policy.lua`**: `CanActivelyClearWave`'s enemy-visibility radius
  aligned from 1800 to the user's literal 1500 spec.
- **Heartbeat logging added** (`decision_log.lua`): `[TICB-HEARTBEAT]` line
  every 10 seconds per bot (independent throttle from the 1.5s diagnostic
  interval) - team/position/lane/location (via the existing `BotLabel`),
  HP%, mana%, level, gold, active mode, and the bot's last farm-exit reason.
  Hooked into `mode_farm_generic.lua`'s `GetDesire()`, which the engine calls
  every tick for every bot regardless of which mode is actually active, so
  this fires reliably no matter what the bot is doing. Per explicit choice,
  this writes to the same `console.<matchid>.log` rather than a separate
  file (untested whether Source 2 VScript's sandbox even permits arbitrary
  file I/O - would need verification before attempting that path).
- Not attempted tonight: proactively walking a locked core up to attack an
  enemy tower once its wave is clear (relies on the existing, more mature
  `CreepPolicy.CanActivelyClearWave` / push.lua systems rather than a new
  one - the scope here was removing the combat/recovery volatility that was
  preventing cores from ever reaching a calm, safe-to-push state, not
  rebuilding the push system itself).
- All nine changed files parse-checked clean (`luac -p`, whole workspace)
  and synced by SHA-256 to the Workshop deployment and `TI-Champions-Bot/bots`.

### 0.6.5 - Lane lock, naming simplified per request, Roshan mutual-clash gap, rune mislabel (match 8980663786)

- **Naming: abandoned slot/position matching entirely, per explicit request.**
  0.6.4's `humanPositions` exclusion (based on `GetTeamPlayers`/`IsPlayerBot`
  at call time) did not fix anything in this match - Radiant still showed
  the same shifted-by-one pattern, and Dire fell back to pure Valve default
  names (`Ольга`, `Alejandro`, ...) despite `bQ.Dire` being deployed and
  valid. Root mechanism still unconfirmed (no error logged; most likely the
  engine calls `GetBotNames()` at a point where slot/human presence isn't
  yet reliably queryable). Per instruction, replaced with a much simpler,
  dependency-free contract: shuffle each team's own roster (already
  guaranteed distinct from the opposing team) and return it as-is, no
  position correspondence attempted. Added a `[TICB-NAMES]` log line so the
  next match shows definitively what each team's `GetBotNames()` actually
  returns - if Dire *still* shows Valve defaults after this, the bug is
  upstream of our Lua entirely (the engine not calling/honoring
  `GetBotNames()` for that team at all).
- **Forced lane commitment for cores (pos 1-3) - fixes both the Dire Pos 1
  "never touched lane in 20 minutes" and Dire Pos 3 "undecisive in the
  river" reports.** Root cause: `mode_farm_generic.lua` (base engine file)
  picks farm locations via "closest neutral camp" with zero lane awareness,
  and once actively camping returns `BOT_MODE_DESIRE_ABSOLUTE` (0.7) -
  which outranks `lane_discipline.lua`'s existing return-to-lane desire
  (`BOT_MODE_DESIRE_VERYHIGH`, 0.6) even though that mechanism was already
  fully wired into `mode_laning_generic.lua`. Added
  `DecisionPolicy.ShouldForceLaneCommitment(bot)`: for positions 1-3, while
  `DotaTime() < 20:00` AND no Tier-3 tower has fallen anywhere on the map,
  suppress farm desire outright whenever `LaneDiscipline.ShouldReturnToLane`
  is true - letting laning mode's desire win and pull the core back via the
  lane-return mechanism that already existed but was never able to act.
- **Roshan mutual-clash gap found and fixed.** `objective_policy.lua`'s
  `baseSafe`/`numbersAdvantage` only checked map-wide alive counts and
  ancient/high-ground proximity - never whether enemies were already AT
  Roshan's pit. Both teams could independently "qualify" (e.g. via a human
  ping each satisfying the equal-numbers OR-branch) and walk into each
  other. Added a real local-advantage requirement: `allyAlive >=
  roshanEnemies + 2` where `roshanEnemies` counts enemies within 2000 units
  of Roshan's current location specifically.
- **Rune success rate still looked broken (1 resolved / 13 completed
  attempts) even after 0.6.2's in-flight-continuation fix - found the real
  cause.** Every `PICKUP_ABORTED` entry in this match's log showed
  `type=-1` (rune slot empty - i.e. actually picked up) while
  `GetRuneStatus` still lagged one tick behind reporting `AVAILABLE`. The
  resolved/aborted classification in `rune_policy.lua` trusted status alone,
  so real successful close-range pickups (71-233 unit distances) were
  systematically mislabeled as failures. Now treats a negative `GetRuneType`
  as resolution too.
- Not done this round: item 4 from tonight's list (Medusa should fight more
  while her ultimate is active/channeling) - no existing hero-specific
  defensive-buff pattern exists anywhere in the codebase to extend safely,
  and building one from scratch wasn't attempted this late in the session
  rather than risk an untested hack. The "what I like, please refine" list
  (support camp-clear speed, carry defensive/offensive item usage, support
  auto-attack/deny discipline) and the "why I loved HyperAI before" wishlist
  (mid roams for 3v2s, proactive tower-push interception, coordinated lane
  pushes, desperate high-ground defense) are understood but out of scope for
  tonight - each is a genuinely new behavior system, not a bug fix, and
  would need its own dedicated session.
- All five changed files (`rune_policy.lua`, `objective_policy.lua`,
  `hero_selection.lua`, `decision_policy.lua`, `mode_farm_generic.lua`)
  parse-checked clean and synced by SHA-256 to the Workshop deployment and
  `TI-Champions-Bot/bots`.
- Git housekeeping: root repo (`https://github.com/ChimCatz/TI_Champions_Bot`)
  confirmed as the only git connection in the project tree -
  `dota2bot-OpenHyperAI/`'s separate nested `.git` (pointing to a different
  repo, `ChimCatz/dota2bot-OpenHyperAI`) was detached; its files are
  untouched and still gitignored from the main repo as reference-only.

### 0.6.4 - Root-caused naming precisely, RNG diversity, mid-clash root cause (match 8980601360)

- **Naming: found the exact mechanism, not just a plausible one.** Read the raw
  server log around bot creation (`ClientPutInServer create new player
  controller [...]`) and matched it against `CSODOTALobby.all_members[0].slot`.
  Confirmed: the engine takes whatever array `GetBotNames()` returns and
  assigns its entries **sequentially to bot player-IDs in creation order**,
  with zero notion of "position" - it does not skip the slot reserved for a
  human. Playing Radiant Pos 1 (human), Team Yandex roster: playerID 1 (bot)
  got `TY.watson` (position 1's name - reserved for the human!), playerID 2
  got `TY.CHIRA_JUNIOR`, playerID 3 got `TY.DM`, playerID 4 got `TY.Saksa`;
  `TY.Malady` (position 5) never appeared - the whole array shifted down by
  exactly one because the human's name was never excluded before handoff to
  the engine. `GetBotNames()` now determines which position(s) are
  human-occupied (via `i.RoleAssignment`) and excludes those names entirely
  before returning the array, so the remaining sequential engine assignment
  lines up correctly regardless of which position a human plays.
- **Roster randomness: `RandomInt` repeated the same roster (Team Yandex)
  across at least 4 separate matches** - roughly a 1-in-4000 chance if
  actually uniform. `team_names.lua` now explicitly seeds Lua's own RNG per
  team-VM load with wall-clock time + fractional game time + `GetTeam()`
  (the same technique already proven working in `FretBots:SetRandomSeed`)
  and draws the roster index from `math.random` instead, falling back to
  `RandomInt` only if seeding fails.
- **Root-caused the minute-0 mid clash and "Pos 1/3 stuck at mid" from three
  separate, independently-discovered gaps**, all now closed with the same
  2600-unit own-lane-front leash used in 0.6.3's `lane_tactics.lua` fix:
  1. `combat_coordination.lua` (the 3-bot "punishment" system) had **no time
     gate beyond `DotaTime() <= 0`** and **no lane awareness at all** - log
     showed it locking Dire's Pos 1/2/3 into a coordinated gank on enemy mid
     at 5.5 seconds into the match, before creeps even spawn. Added a 30s
     minimum activation time and the lane leash for cores.
  2. `mode_rune_generic.lua`'s `GetBestRune()` let position-1 (top rune
     priority in the whole team) chase power/bounty runes anywhere on the
     map purely by priority rank, with no consideration of how far that is
     from its own lane - this is what put Dire's Pos 1 (`monkey_king`,
     assigned TOP) at map-center coordinates 5-12 seconds into the match.
     Added the same lane leash, active during laning only.
  3. `GetLaningRuneDesire()` (a second, independent rune-desire path used
     1:00-7:00) had the identical gap for both its power-rune and
     any-rune-type searches. Same fix applied.
- Checked whether Steam Workshop or something else was silently reverting
  edits mid-session (the user's suspicion after repeated similar symptoms) -
  ruled out again: file hashes/mtimes confirm 0.6.3 was live and its effects
  visible in this match's log before these new bugs were found. Every
  reported symptom traced to a real, distinct code path.
- All four changed files (`hero_selection.lua`, `team_names.lua`,
  `combat_coordination.lua`, `mode_rune_generic.lua`) parse-checked clean and
  synced by SHA-256 to the Workshop deployment and `TI-Champions-Bot/bots`.
- Not yet done: issues 3/5/7 from this round (cores engaging creeps more
  confidently/less passively during laning, further lane-tactics timing
  polish) are expected to improve as a side effect of the lane-leash fixes
  above (cores can no longer be pulled away to justify not farming) but
  weren't independently verified - re-check `creep_policy.lua` retreat
  thresholds specifically if lane presence is still weak after retesting.

### 0.6.3 - Naming fix was wrong, lane-boundary discipline added, diagnostics enriched (match 8980563394)

- **Confirmed the edit pipeline is not the problem.** Checked whether Steam
  Workshop silently reverts local edits to the live deployment folder before
  a match starts (the user's hypothesis for "no matter how much we edit
  nothing gets compiled"): file hashes and mtimes show the 0.6.2 files were
  still in place, untouched, when this match started, and their effects were
  visibly active in the log (correct `enemies=2 allies=1` gating on
  `LANE_RECOVERY`, zero compile errors). Local edits to the Workshop content
  folder do take effect for local bot matches - no re-publish needed. The
  remaining symptoms were new/different bugs, not a stale build.
- **Naming: the 0.6.2 "fix" was itself wrong.** Compared against the upstream
  reference (`dota2bot-OpenHyperAI/bots/hero_selection.lua`), which the whole
  custom build is based on and is known to work correctly. Upstream's
  `GetBotNames()` is trivial - it returns the full 5-name positional array
  directly (`return GetTeam()==TEAM_RADIANT and teamPlayerNames.Radiant or
  teamPlayerNames.Dire`) with **no filtering by bot/human and no player-ID
  math at all**; the engine maps position to slot internally. Both the
  original custom-build version and my 0.6.2 revision reimplemented that
  mapping by hand and got it wrong in different ways. Replaced with the
  upstream shape exactly.
- **Lane-boundary discipline added to `lane_tactics.lua`.** Root-caused the
  "Pos 1 not in lane" reports: `EvaluateCombat` scans for any visible enemy
  within 1600 units and engages, for the entire 18-minute economy phase, with
  zero awareness of the bot's own assigned lane. Log evidence from this match:
  Dire's Pos 2 (mid, `obsidian_destroyer`) left mid at 18-90s to 2v1 Radiant's
  Pos 1 (`skeleton_king`) in the bot lane alongside Dire's actual Pos 1 -
  `LANE_RECOVERY` was firing correctly by that point (`enemies=2 allies=1`,
  a real disadvantage), the bug was upstream of it: nothing stopped the mid
  laner from abandoning lane to gang up in the first place. Added
  `IsNearOwnLane` - cores (pos 1-3) now only enter HARASS/PRESSURE/KILL if
  within 2600 units of their own assigned lane's front; supports (pos 4-5)
  are exempt since roaming is expected of them. This directly targets the
  user's diagnosis that "a general lane_tactics might work but causes issues"
  since each position has a different lane/role.
- **Combat-state flicker reduced.** `PRESSURE`/`HARASS` commit windows raised
  from 1.2s/1.6s to 3.0s (previous match log showed `FARM -> PRESSURE`
  relabeling 6 times in 40 seconds against one target). Ratio-floor tuning for
  `PRESSURE` (currently has none) is still open if flicker persists after
  retesting.
- **Diagnostics enriched per request**, so match observations don't need to
  be re-explained: `TICB-DIAG` lines now carry team, position, assigned lane,
  and current (x,y) location for every bot (`decision_log.lua`); `TICB-RUNE`
  and `TICB-ITEM` now carry team and position too. The rate-limit throttle key
  is unaffected (kept separate from the new descriptive label) so log volume
  doesn't change.
- All six changed files (`hero_selection.lua`, `decision_log.lua`,
  `rune_policy.lua`, `farm_timing.lua`, `lane_tactics.lua`, plus 0.6.2's
  `decision_policy.lua`) parse-checked clean and synced by SHA-256 to the
  Workshop deployment and `TI-Champions-Bot/bots`.

### 0.6.2 - Three real logic bugs found after the 0.6.1 crash fix (match 8980512953)

The 0.6.1 compile fix confirmed working (no compile errors, TICB-DIAG/TICB-RUNE
firing throughout). That isolated three independent, pre-existing logic bugs
that had been masked/amplified by the crash and were never actually fixed in
0.1.0-0.6.0 despite being partially noted:

1. **Lane oscillation** (`FuncLib/systems/decision_policy.lua`,
   `ShouldCoreTemporarilyJungle`). `severeDisadvantage` and `waveDangerous`
   triggered an 8-second "temporarily jungle" retreat from level gap or enemy
   tower proximity alone, **without checking whether the bot actually had the
   numbers disadvantage**. Log evidence: dozens of `LANE_RECOVERY` firings
   with `enemies=0-1 allies=2` (a favorable fight) still triggering retreat,
   every few seconds, all match, for both teams - this is the exact behavior
   the 0.6.0 preliminary findings had already flagged and never fixed. Fixed
   by requiring `#enemies >= #allies` for both conditions.
2. **Rune pickups almost never completing** (`FuncLib/systems/rune_policy.lua`,
   `TryImmediatePickup`). Log tally: 220 `TRY`, 198 `PICKUP_ABORTED`, 5
   `PICKUP_TIMEOUT`, **0 `PICKUP_RESOLVED`** in the entire match. Every tick
   re-derived eligibility via `IsLocallySafe`/`IsDesignatedCollector`, so a
   single momentary blip (an enemy passing within 1100 units, a teammate's
   priority flickering) cancelled an already-in-progress pickup before the
   rune's status could flip to picked-up. Fixed by letting an in-flight
   attempt (already within pickup range, at least one order issued) press
   through re-evaluation noise; it now only ends via the existing 2.25s
   timeout or the bot actually needing to flee (`IsRetreating`).
3. **Combat state flapping** (`FuncLib/systems/lane_tactics.lua`,
   `EvaluateCombat`/`Update`). `PRESSURE` and `HARASS` commit for only 1.2s/1.6s
   before re-evaluating, with `PRESSURE` requiring no kill-ratio floor at all -
   log showed `FARM -> PRESSURE` transitions 6 times in the first 40 seconds
   against the same target with a damage ratio as low as 0.00-0.16. Flagged as
   a likely secondary contributor to visible lane indecision; not yet patched -
   candidate fix is longer commit windows and/or a minimal ratio floor for
   PRESSURE, revisit if oscillation persists after bugs 1-2 are fixed.
4. **Bot naming still wrong independent of the crash** (`hero_selection.lua`,
   `GetBotNames`). Computed each bot's roster position from raw `playerID`
   arithmetic (`playerID+1` Radiant / `playerID-4` Dire), which silently
   assumes contiguous player IDs (0-4 Radiant, 5-9 Dire) - an assumption nowhere
   else in the codebase relies on. Every other position-sensitive path
   (`i.RoleAssignment`, hero pick, lane assignment) instead uses the bot's
   enumeration index within `GetTeamPlayers(GetTeam())`, which the file already
   normalizes for Dire via a `GetTeamPlayers` override in `global_overrides.lua`
   specifically because raw player IDs aren't reliable. Observed effect: names
   shifted by one slot with the human's positional name leaking onto an ally
   and the last position's name dropped. Fixed by rewriting `GetBotNames` to
   use `i.RoleAssignment[B][Z]` (Z = enumeration index) like the rest of the
   file.

All four fixed files (`decision_policy.lua`, `rune_policy.lua`, `hero_selection.lua`;
`lane_tactics.lua` left as-is pending bug 3) parse-checked clean with `luac -p`
across the whole working copy, and matching SHA-256 hashes were synced to the
Workshop live deployment and `TI-Champions-Bot/bots`. Needs a fresh lobby to
validate: confirm `LANE_RECOVERY`/`waveDanger` no longer fires at favorable
counts, confirm `PICKUP_RESOLVED` starts appearing in `TICB-RUNE`, and confirm
bot names match the assigned roster roster-wide on both teams.

### 0.6.1 - Critical hotfix: mode_rune_generic.lua failed to compile

- Root cause of the 8980476765 match observations (all bots rushing/fighting
  over the mid/bottom rune from 0:00, carries and even supports drifting to
  mid all game, and Radiant/Dire naming glitches): `mode_rune_generic.lua`
  had a missing `end` (the `if d.rune and d.rune.normal then` block opened at
  line 22 was never closed, only `GetDesireRaw()`'s body was), so the whole
  file failed `LoadAndCompileScriptFile` for every bot on both teams,
  repeatedly, from the moment hero selection started (`console log lines
  427-503`, 09/03 19:59:32-33), producing the flood of `Script Runtime Error:
  error in error handling` with no rune desire/lane-return-lock logic ever
  loading. With that module dead, all 10 bots fell back to unrestricted
  default rune-chasing behavior for the entire match - explaining the
  full-team rush to the bottom/mid rune at minute 0 and the persistent
  "everyone wants mid" behavior. The same crash window is also the most
  likely explanation for that match's naming glitches (unnamed Pos 1 Monkey
  King, Dire showing Valve's default bot names instead of roster names),
  though this needs re-confirmation in a clean match now that the crash is
  fixed - if it recurs, `GetBotNames()`'s playerID-to-position arithmetic
  (`hero_selection.lua`, `playerID+1` for Radiant / `playerID-4` for Dire)
  is the next thing to instrument, since it assumes contiguous player IDs
  (0-4 Radiant, 5-9 Dire) rather than reading actual slot/role assignment.
- Fixed by adding the missing `end`; verified with `luac -p` on every `.lua`
  file in the working copy (all pass) and re-synced matching SHA-256 hashes
  to the Workshop live deployment and the `TI-Champions-Bot/bots` release
  copy.
- Requires a brand-new lobby to validate - this file could not have loaded
  correctly in any prior match either, so treat all prior rune/lane-return
  telemetry as suspect until re-tested post-fix.

### 0.6.0 - Strict runes and coordinated punishment

- Log analysis found hundreds of pursuits of rune `type=-1`, `status=UNKNOWN`.
- Rune movement now requires `AVAILABLE` and a nonnegative rune type.
- Replaced false pickup completion with resolved, aborted, and timeout states.
- Added active attacks and low-cooldown spells on uncontested waves.
- Supports cannot clear enemy creeps while a core is within 1200 range.
- Added a 2.5-second tower attack commitment while allied creeps tank.
- Added bot-only three-hero intruder punishment, shared targeting, and Blink entry.
- Added 16 complete random position-linked rosters and player-ID-based name mapping.
- Temporarily banned Kez because both weapon forms produced missing-slot errors.
- Added version-aware configuration loading and new diagnostic categories.

## Important Modules

- `FuncLib/systems/rune_policy.lua`: strict validity, ownership, pickup transaction.
- `mode_rune_generic.lua`: rune desire/movement and lane return.
- `FuncLib/systems/lane_tactics.lua`: lane kill, pressure, harassment, pull, stack.
- `FuncLib/systems/decision_policy.lua`: lane recovery, mid duty, support yielding.
- `FuncLib/systems/creep_policy.lua`: last hit, deny, and safe active wave clear.
- `FuncLib/systems/farm_ability_policy.lua`: lane/jungle farming spells.
- `FuncLib/systems/combat_coordination.lua`: three-bot punishment and Blink target.
- `mode_team_roam_generic.lua`: shared combat target execution.
- `FuncLib/systems/push.lua`: push movement and tower attack commitment.
- `FuncLib/data/team_names.lua` and `hero_selection.lua`: roster and slot mapping.
- `FuncLib/systems/custom_loader.lua`: packaged/external config precedence.

## Diagnostic Tags

- `[TICB-BOOT]`: confirms version loaded for both teams.
- `[TICB-ITEM]`: role and first-major timing plan.
- `[TICB-RUNE]`: pickup attempt, resolved, aborted, or timeout.
- `[TICB-DIAG][LANE_STATE]`: FARM/HARASS/PRESSURE/KILL transitions.
- `[TICB-DIAG][LANE_RECOVERY]`: temporary jungle decision and cause.
- `[TICB-DIAG][LANE_WAVECLEAR]`: safe farming spell use.
- `[TICB-DIAG][FOCUS_TARGET]`: three-bot shared punishment target.
- `[TICB-DIAG][BLINK_READY]`: coordinated Blink opportunity.
- `[TICB-DIAG][TOWER_COMMIT]`: structure attack latch.

## Preliminary Findings From Match 8980476765

At approximately 3:39-4:45 game time:

- Wraith King repeatedly logged `LANE_RECOVERY` from a two-level gap even with
  `enemies=1 allies=2`. In `decision_policy.lua`, `severeDisadvantage` can become
  true from level gap plus one visible enemy without considering allied numbers.
- Dark Seer repeatedly logged recovery with `waveDanger=true`, `enemies=1`, and
  `allies=2`. The wave-danger condition similarly ignores a favorable local count.
- Several heroes cycle `FARM -> HARASS/PRESSURE` every 2-5 seconds with very low
  kill ratios (observed as low as 0.07). Review the pressure threshold and use a
  cooldown/hysteresis state to prevent positional oscillation.
- Two opaque startup records say `Script Runtime Error: error in error handling`.
  No actionable stack trace is printed; preserve `SafeCall` labels and inspect
  surrounding startup output before attributing these to a specific module.
- No `[TICB-RUNE]` record had appeared by this point. That is not itself a bug:
  v0.6 only logs a pickup after a rune is positively reported as available.

## Required Validation After Any Patch

1. Parse every changed Lua file with `luaparser`.
2. Confirm source, Workshop, and release copies have matching SHA-256 hashes.
3. Start a new lobby; Lua changes do not reliably reload in an existing match.
4. Verify no rune `TRY` record has `type=-1` or unknown/missing status.
5. Test one Radiant and one Dire lobby with humans occupying different slots.
6. Check lane presence, net worth, idle-time records, tower damage, and state
   transition frequency rather than judging only the final kill score.
