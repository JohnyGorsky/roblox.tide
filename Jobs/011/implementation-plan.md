# Implementation Plan — Job #011

**Project**: `roblox.tide`
**Created**: 2026-08-20 12:08:20
**Status**: Planning (awaiting go-ahead)

## Analysis

All four questions were answered with the recommended option in each case, and all four shape the game rather than one feature, so all four become decision records rather than notes buried in a manifest group. The records deliberately capture what was REJECTED and why, since that is the part a future reader cannot reconstruct: a run-ending storm was rejected because it deletes the near-miss moment the whole game is built around; a separate skeleton for the drowned was rejected as a real artistic loss accepted for cost; part-and-mesh islands were rejected because a mesh coastline reads as built rather than sculpted; and PathfindingService aboard a vessel was rejected because a static navmesh assumption cannot hold on a pitching deck.

## Implementation steps

1. Write docs/decisions/0014-storm-consequence.md
2. Write docs/decisions/0015-shared-humanoid-rig.md
3. Write docs/decisions/0016-island-template-storage.md
4. Write docs/decisions/0017-vessel-local-navigation.md
5. Add all four to docs/decisions/INDEX.md
6. Close the matching open questions in manifest groups 04, 05, 07, 10 and 11, and update the affected item rows to reference the decisions
7. Update the skill's decision count and the handoff doc, which listed all four as blocking

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
