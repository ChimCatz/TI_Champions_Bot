# TI Champions Bot - Claude Code Handoff

## Current Live Match

- Match ID: `8980512953`
- Live log: `E:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\console.8980512953.log`
- Current deployed version: `TI Champions Bot v0.6.2` (0.6.1 rune-compile hotfix confirmed
  working in this match: TICB-DIAG x393, TICB-RUNE x423, zero compile errors)
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
