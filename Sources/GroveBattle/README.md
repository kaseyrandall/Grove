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

## Status: engine ✅ · balance ⛏️ in progress
`swift test` runs a **win-rate harness** over the three core matchups. Current:

| Matchup | favoured win-rate |
|---|---|
| Power › Bulk (Bruiser › Wall) | ~87% ✅ |
| Bulk › Speed (Wall › Skirmisher) | ~100% ✅ |
| Speed › Power (Skirmisher › Bruiser) | ~14% ❌ |

Two legs of the triangle hold; **Speed › Power does not** — the Bruiser
archetype is over-efficient in a 1v1. The engine + harness make this measurable;
closing it is the next slice, and belongs in the **archetype weights** (raise the
value of SPD / temper the ATK+HP concentration), not in engine constants.
