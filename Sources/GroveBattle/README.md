# GroveBattle — Battlegrounds Phase 0

Pure-Swift, offline, deterministic battle engine for the Grove Battlegrounds
concept. No app dependencies; runnable with `swift test`.

## What's here
- **Cards are derived, not rolled.** `BattleCard` builds stats from an archetype
  (shape) + level (size). Every archetype shares the same stat budget at a level
  (`totalBudget`), so species is flavour, never power — this is what sidesteps the
  Vision/label problem entirely.
- **Type wheel** (`BattleType`) — the 8 habitats, beats-the-next-two.
- **Battle Plans** (`BattlePlan`) — the gambit format (condition → action) that
  makes async play work; each archetype ships a sensible default.
- **Deterministic engine** (`simulate`) — two cards + two plans + a seed → an
  identical replay log + result, every time. This is what lets a match be
  refereed server-side (anti-cheat) and replayed on both devices.

## Status: engine ✅ · core triangle ✅

`swift test` runs a win-rate harness (500 seeds/matchup, neutral types) that now
*asserts* the archetype triangle holds:

| Matchup | favoured win-rate |
|---|---|
| Speed › Power (Skirmisher › Bruiser) | ~54% ✅ |
| Power › Bulk (Bruiser › Wall) | ~97% ✅ |
| Bulk › Speed (Wall › Skirmisher) | ~95% ✅ |

The leg that broke first (Speed › Power) was closed by pricing SPD correctly:
the much-faster combatant earns scaling **extra turns**, so speed investment pays
off — while the Wall's high DEF keeps a fast attacker from ever cracking it, so
Bulk › Speed stays safe.

### Next
- Fold in the off-triangle specialists (Trickster, All-rounder) and the type
  multiplier as second-layer matchup tests.
- A `describe()` on `BattleResult` already prints a readable play-by-play
  (`testPrintSampleReplay`) — the seed for a real replay UI.
