# Implementation Plan — Job #016

**Project**: `roblox.tide`
**Created**: 2026-08-20 14:17:56
**Status**: Planning (awaiting go-ahead)

## Analysis

The sea work already owns Lighting through SeaStates.apply, so this job is as much a refactor as an addition: apply() must stop writing Lighting and instead contribute values to a composer that also takes the time of day. Decision 0018 fixes the arithmetic - result = lerp(timeBase, weatherValues, severity) for everything continuous, and a threshold switch for the sky because six ContentIds cannot blend. Severity is the new field on each sea state: DeadCalm 0.0, LightSwell 0.15, Choppy 0.45, Storm 0.80, TheWall 1.00. That gives two properties for free: a calm night reads as night because severity is near zero, and The Wall is timeless because at severity 1.0 the time contributes nothing - correct, since inside the front there is no sun, stars or horizon to tell the hour by. Sky assignment doubles up: SunlessBlue for dawn, SnowGrey for day, SunlessBlue again for dusk (we have no warm sky - dusk gets its warmth from ambient and fog instead), NightFog for night, and the weather skies FogOnWater, AngryHeavens and BlackVoid take over above the severity threshold. Clock lives on Workspace attributes for the same reason WaveField's state does: per-context module copies would otherwise disagree about the hour. Server drives it; everyone reads it.

## Implementation steps

1. Add severity to all five sea states
2. Write DayNight.luau: phase definitions, durations, server clock on Workspace attributes, per-phase base look
3. Write SkyComposer or extend SeaStates: single owner of Lighting, blending time base with weather by severity, sky by threshold
4. Refactor SeaStates.apply to contribute values rather than write Lighting directly
5. Verify the two properties that matter: a calm night reads as night, and The Wall is identical at noon and midnight
6. Add admin tools: jump to phase, scrub the clock, pause the cycle
7. Verify determinism of the clock across a fresh module load

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
