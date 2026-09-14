Dynamic gold/XP comeback system for bots. Once per real 60 seconds, grants
every bot a FLAT gold/XP bonus (not a multiplier on their actual earnings):
a small always-on baseline (40g / 25xp per minute) plus up to another
260g / 175xp per minute, scaled 0..1 by how far THAT SPECIFIC HERO is
behind the enemy team's average net worth (fully scaled at a 10,000 gold
gap). Bots only - human players are never touched. Hard per-hero, per-game
caps (18,000 total bonus gold / 12,000 total bonus XP) apply on top of all
of this as a safety net.

The scale is per-hero, not per-team: each bot's own net worth is compared
against the enemy team's average, so a struggling hero gets boosted more
than an already-ahead teammate on the same team, and a team that's winning
in aggregate but has one losing lane still lifts that lane specifically.
(An earlier version scaled every bot on a team by the same team-wide net
worth gap, which let an already-winning hero snowball even harder off the
multiplier than the teammate who was actually behind.)

The bonus is flat-per-minute rather than a multiplier on real earnings as
of this version: a prior multiplier-based design caused live matches to
show multiple heroes jumping ~12 levels in under 10 seconds. A flat grant
this small cannot do that even in the worst case - see the comment above
`DynamicComeback:TickTeam` in `DynamicComeback.lua` for the full story.
Every application also prints a `[TICB-COMEBACK-LOG]` line (hero, level,
gold/XP before and bonus granted, comeback fraction, running totals) for
post-game gold/XP-per-minute analysis.

This has to run outside the normal bot AI scripts because `PlayerResource`
(needed to grant gold/XP at all) is unreachable from inside them - see the
comment block at the top of `DynamicComeback.lua` for the full story. The
activation method below is the same one this repo's own `Buff/Helper.lua`
system and FretBots use for the same reason.

# To use

1. Launch Dota 2 with console enabled.
2. Create a Lobby (local host). Make sure `Enable Cheats` is checked.
3. After the map finishes loading, open the console and type, in order:
   - `sv_cheats 1`
   - `script_reload_code bots/Buff/DynamicComeback`
4. That's it - the system is now running for the rest of the match. You'll
   see a green "[TI Champions Bot] Dynamic comeback economy: activated."
   message in chat, `[TICB-COMEBACK-LIVE]` lines (once per bot per 60s,
   team net worth + cumulative bonus), and `[TICB-COMEBACK-LOG]` lines
   (once per bot per 60s, the full per-minute analytics record: hero,
   level, gold/XP before and bonus granted, comeback fraction, running
   totals) in the console/log.

Only step 3's second command needs to be run once per match, after heroes
have loaded in. If you see "Dynamic comeback economy has already been
enabled for this game" in the log, it's already active - no need to run it
again.
