# Final Summary — Job #011

**Project**: `roblox.tide`
**Completed**: 2026-08-20 12:08:20
**Status**: ✅ Completed

## What was implemented

Four decision records, 0014 to 0017, taking the accepted count from 13 to 17. Each records the rejected alternative and why, because that is the part a future reader cannot reconstruct from the decision alone. 0014 THE STORM DAMAGES: entering The Wall inflicts mounting hull damage and forced system faults, escapable in roughly 30 to 60 seconds of competent play. A run-ending wall was rejected because it deletes the exact moment the game is built around - the intended player stories are 'we ran out of fuel just before the storm caught us' and 'we barely got out', both of which require being caught to be survivable at a cost. It also gives every other system something to do at the worst possible moment, which is the game at its most alive. Consequence recorded: if it is survivable indefinitely the storm stops being a wall, so the tuning target is that a good crew escapes and a slow one does not. 0015 ONE SHARED R15 RIG for players, crew, pirates and drowned - the single largest saving in the project, removing roughly a third of group 11 and compounding, because every task animation authored for players immediately works for crew and humanoid enemies. A separate drowned skeleton was rejected as a genuine artistic loss accepted for cost, with the note that wrongness must then come from animation, shading and audio, and that adding a rig later needs a new decision rather than quiet drift. 0016 ISLANDS AS TerrainRegion PLUS PROP MODEL: keeps the smooth-terrain coastline that is most of what makes a shore read as real. Baking islands permanently into the map was rejected because fixing island positions forever is directly opposed to the curated recombination the replayability rests on. Consequences recorded: terrain data is bulky binary content so the library stays curated; terrain must exist before props are seated; validate across the whole footprint not one raycast; no land at the waterline; CopyRegion takes cell coordinates. 0017 VESSEL-LOCAL WAYPOINT GRAPH: NPCs and boarders navigate node to node in the vessel's local space, so the vessel's motion is structurally irrelevant rather than something to compensate for. PathfindingService aboard is rejected outright - its static navmesh assumption cannot hold on a pitching deck, and the observed failure is NPCs lagging the deck and walking into the sea. It also composes with the socket layout from decision 0009, and interiors on larger vessels become more nodes rather than a new system, which is what makes the Expedition Ship tractable. Propagated into every affected manifest group: the open questions in 04, 05, 07 and 11 are struck through and answered, and the item rows for island template format, caught-by-storm consequence, deck navigation and crew rig now name their decisions. Nothing in the manifest is blocked on an unanswered design question any more.

### Files changed

_Documentation only._

- `docs/decisions/0014-storm-consequence.md`
- `docs/decisions/0015-shared-humanoid-rig.md`
- `docs/decisions/0016-island-template-storage.md`
- `docs/decisions/0017-vessel-local-navigation.md`
- `docs/decisions/INDEX.md`
- `docs/build/04-islands.md`
- `docs/build/05-enemies.md`
- `docs/build/07-atmosphere.md`
- `docs/build/10-crew.md`
- `docs/build/11-animations.md`
- `docs/HANDOFF.md`
- `.claude/skills/tide-project/SKILL.md`

### What these unblock

| Decision | Unblocks |
|---|---|
| 0014 storm consequence | group 07 (atmosphere/storm) |
| 0015 shared R15 rig | groups 05, 10, 11 (enemies, crew, animations) |
| 0016 island storage | group 04 (islands) — the whole pipeline |
| 0017 vessel-local nav | groups 05, 10 (boarding, crew) |

## Verification

- [x] Four records written and listed in `docs/decisions/INDEX.md` (13 → 17 accepted)
- [x] Open questions struck through and answered in groups 04, 05, 07, 11
- [x] Item rows updated to name their decision in groups 04, 07, 10
- [x] Skill decision count and HANDOFF updated
- [x] Every relative link in the repo resolves
- [ ] Nothing implemented — **these are decisions, by design**
