---
id: GAME-0004
name: Day / Dusk / Night
area: atmosphere
status: IN_PROGRESS
priority: P0
last_verified: null
---

# Day / Dusk / Night

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [x] Lighting transitions — `DayNight.compose()`, the sole writer of Lighting/Terrain water/clouds
- [ ] Dusk warning — the 45 s Dusk phase exists, but nothing *warns* the crew it is coming
- [x] Night visibility reduction — fog and brightness are hour-based; weather multiplies, never replaces
- [ ] Enemy/event hooks — nothing consumes the phase yet; needs group 05
- [x] Dawn recovery beat — 40 s Dawn phase exists in the cycle

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.

## Status note — 2026-08-20

The cycle runs (Dawn 40 s, Day 280 s, Dusk 45 s, Night 210 s = 575 s) driven by `WorldTick` at 1 Hz, and
`compose()` is the single writer of Lighting, Terrain water and the cloud layer. Decision 0018's time-base
plus weather-severity blend is implemented and job 018 made it smooth across band crossings.

What is missing is not the clock but the **consequences**: nothing warns the crew that dusk is coming, and
nothing keys off the phase. Both wait on other groups.
