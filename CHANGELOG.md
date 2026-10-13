# Changelog

All notable changes to TI Champions Bot are logged here, newest first. Versions
track the in-game chat/version string (`Customize.Config_Version` /
`FuncLib/systems/version.lua`), not semver.

## 0.7.9 — 2026-10-13

Hero-pick variety and combat-aggression tuning pass:

- **Draft pool**: the "weak hero" pick penalty was over-tuned — `Weak_Hero_Cap`
  defaulted to `0`, which silently blocked ~18 heroes (Chen, Tinker, Morphling,
  Ember Spirit, etc.) from ever being drafted at all, and the runtime penalty
  list had drifted out of sync with the one documented in `Customize/general.lua`.
  Raised the cap to 1 per team, softened the exponential penalty curve, resynced
  the two lists, and loosened the random candidate-entry filter from a 30% to a
  60% chance per pick attempt. Heroes with genuine engine-side Valve bugs
  (Muerta, Marci, Lone Druid, Primal Beast, Dark Willow, Elder Titan, Hoodwink,
  Wisp, Kez) remain banned on purpose.
- **Sand King**: Burrow Strike now also engages on a numbers-advantage read
  (not just own stun level / mana), and Epicenter fires as a finishing combo
  move when physical + ultimate damage together secure a kill — previously it
  only ulted on already-disabled/silenced/invisible targets, so the
  dagger → stun → ult combo often stalled out.
- **Treant Protector**: Overgrowth used to require an explicit "team fight"
  state with 2+ enemies nearby. Added a single-target branch so he roots/
  silences for a solo kill when he's engaging with a numbers advantage, instead
  of holding the ultimate for a group fight that never arrives.
- **Support ward pathing**: root-caused supports drifting toward the river/
  Roshan-pit area and getting stuck mid-laning-phase — `mode_ward_generic.lua`
  had no laning-phase gate, so ward desire could out-compete lane desire while
  an enemy was still actively contesting the lane, and `LaneDiscipline` then
  refuses to pull the bot back while an enemy is nearby, producing visible
  back-and-forth indecision. Ward desire is now suppressed outright while
  laning with an enemy hero within 900 units.
- **Passivity**: bots were eating free hits instead of trading. Lowered the
  retreat-trigger HP thresholds (`survival_policy.lua`, 50%→40% HP / 38%→30%
  projected), lowered the HP floor to commit to a fight (48%→40%), and —
  the main one — dropped the kill-ratio a solo bot needed just to fight back
  in an even 1v1 from 1.15 (favorable) to 1.0 (even trade), since requiring a
  favorable ratio just to swing back meant bots never fought back in fair
  fights (`lane_tactics.lua`, `combat_safety.lua`).

## 0.7.8 — 2026-09-21

- Ward-vs-tower targeting now lets `Action_AttackUnit` handle move-into-range
  itself instead of a manual, hull-unaware distance check.
- Glyph of Fortification fires regardless of whether humans are on the team,
  and proactively glyphs an undefended Tier 1 under attack instead of waiting
  for it to drop below 36% HP.
- Tower-push commit: dropped the "tower already tanking a creep" chicken-and-
  egg requirement, lowered the creep-cover threshold.
- Centaur: Hoof Stomp no longer waits until Stampede is also affordable;
  Stampede gets a real initiation branch instead of only firing mid-fight.
- Shadow Shaman now uses Ether Shock on lane waves while farming, not just
  jungle camps.
- Viper's pos 1/2 buy list jumped straight to Dragon Lance with zero starting
  items — added Tango/Branches/Circlet/Wand/Treads.
- **Dynamic Comeback rewrite**: replaced the per-second multiplier-on-real-
  earnings model — implicated in live reports of heroes jumping ~12 levels in
  under 10 seconds — with a flat, capped per-60-second grant scaled by each
  hero's own net-worth gap, plus hard per-hero game-long caps. See
  [`3246316298/Buff/DynamicComeback_README.md`](3246316298/Buff/DynamicComeback_README.md).

## 0.7.7 — 2026-09-14

15-item fix batch root-caused against a spectated 5v5 bots-only match: rune
pickup timeout, boots purchase priority, tower-siege response, ward-vs-tower
engagement, Aegis pickup, Ringmaster whip usage, throne defense, mid-lane
aggression, a jungle/lane decision contradiction, neutral item actives, and
late-game item build gaps.

## 0.7.6 — 2026-09-14

Static audit (parsed every `BotsLib/hero_*.lua` buy list against
`FuncLib/data/item_names.lua`) found 43 of 128 heroes' purchase lists opened
with a leftover cosmetic placeholder token (an outfit/arcana name) instead of
a real item — 15 distinct bogus tokens, 200 occurrences across 83 files.
Stripped all of them. Also fixed the previous version's "sell obsolete items"
trigger to only fire when inventory is actually full.

## 0.7.5 — 2026-09-01

Cores now proactively attack a safe, hero-free creep wave instead of standing
next to one — the wave-clear logic existed but wasn't wired into farm mode's
own think loop. Added narrow, time-gated auto-sell for obsolete starter items.

## 0.7.4 — 2026-09-01

Fixed a Dire-only lane-assignment bug: the pick logic stored Dire's lane table
at a human-first remapped index while looking it up by the raw team-list
index — two different indices into the same engine array. Confirmed via a
full match where Dire's Pos 1 laned at MID the entire game.

## 0.7.0 – 0.7.3 — 2026-08-31 – 2026-09-01

- **0.7.0**: root-caused the "Jakiro drafted for Pos 4 but treated as Pos 1
  everywhere else" class of bug — the picking loop and the position-lookup
  function enumerated team players via two calls that could disagree on
  order. Positions are now recorded once at pick time and never re-derived.
  Added hysteresis so a lane-locked core stops thrashing between LANING and
  FARM mode every ~10 seconds.
- **0.7.1**: audited `hero_pos_weights.lua`'s full 127-hero distribution,
  added self-validating position/lane assignment logging, capped a recursive
  candidate-pool search that was previously unbounded.
- **0.7.2**: fixed false-positive validation warnings firing before lane
  assignment had actually resolved.
- **0.7.3**: let a lane-locked core leave its wave to farm nearby camps only
  while both creep waves are parked under the enemy tower and contested —
  replacing a flickery raw-distance signal with actual lane state.

## 0.6.5 – 0.6.9 — 2026-08-31

- **0.6.5**: lane-commitment lock for cores before 20:00 (farm desire was
  outranking the return-to-lane desire, letting cores camp jungle
  indefinitely), Roshan mutual-clash fix (both teams could independently
  "qualify" and walk into each other), rune-pickup mislabeling fix.
- **0.6.6**: hard 30-minute Roshan gate with no ping bypass, ward target
  priority reordered (heroes → enemy summons → towers → creeps), instant
  base-defend override, 10-second heartbeat diagnostics.
- **0.6.7**: root-caused Pos 1/3 dawdling at the river/secret shop right at
  horn — a guard depended on a laning-phase flag that wasn't set yet during
  the pre-horn window.
- **0.6.8**: secret-shop hero-walk now waits a 30-second grace period for the
  existing courier auto-dispatch instead of racing it.
- **0.6.9**: fixed rune-chasing across the map during the pregame window
  (same stale laning-phase flag as 0.6.7), duplicate-looking bot names from a
  padded name pool, and a sell-item bug that required shop proximity even
  though selling doesn't need it.

## 0.6.4 — Initial commit — 2026-08-31

Baseline snapshot after the first fix pass: a missing-`end` compile crash that
was silently breaking rune logic for every bot in every match, lane-recovery
false positives, bot-name assignment rewritten to match the engine's actual
(position-unaware) contract, and per-match RNG reseeding so the same roster
wasn't repeating across games.
