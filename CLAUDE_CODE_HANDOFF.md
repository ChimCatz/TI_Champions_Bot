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
