# FINDING 0027: Legacy fog is INERT because an Atmosphere object is present, so every per-sea-state fogEnd is doing nothing

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-22 10:02:47

**Symptom:** Roblox hides and stops applying Lighting.FogStart/FogEnd/FogColor whenever Lighting contains an Atmosphere object. The game place has one (Density 0.45, Haze 1.4, Offset 0.25). Proved it: set FogEnd from 2353 to 300 with FogStart 0 - so aggressive that only the island 260 studs out should have stayed visible - and the screenshot from an identical camera was PIXEL-IDENTICAL. Consequences, all of them load-bearing: (1) SeaStates' fogEnd ladder (DeadCalm 2900, LightSwell 2800, Choppy 1900, Storm 900, TheWall 330) has no visual effect at all, so the storm's you-cannot-see mechanic is not happening through fog - only the job-014 atmosphere block does anything. (2) Radar.visibility is derived from fogEnd, so the instrument reports a percentage with no visual counterpart - it lies to the player. (3) validateFogWithinOcean and validateCorridorForTarget both assert invariants about an inert property, so the map-edge concealment rule is enforced by nothing - which is why the ocean's south edge is visible. (4) Decision 0025 sized the corridor at Z=5500 from 'target + largest fogEnd = 2400 + 2900'; that arithmetic is void. Either drive visibility from Atmosphere.Density/Haze/Offset instead, or remove the Atmosphere object and go back to fog - but the two cannot both be the story.
**Where:** SeaStates.luau sky.fogEnd for all 5 states, validateFogWithinOcean, validateCorridorForTarget, Radar.visibility, decision 0025
**Repro / notes:** _TODO_
**Fix idea:** _TODO_


## Correction (2026-08-22)

Consequence (3) originally added *"which is why the ocean's south edge is visible"*. **That clause was
wrong.** I took the south edge to be 1,000 studs away by reading `OCEAN_EXTENT_Z.min` rather than measuring
the water. Measured, the fill reaches `Z = -3070` — three times further — and the horizon reads clean looking
south from 150 studs up in Dead Calm.

The rest of the finding stands unchanged: fog is inert, and every invariant expressed in `fogEnd` is
therefore meaningless. It simply was not concealing anything that needed concealing.

A separate, smaller defect came out of the same measurement: `OCEAN_EXTENT_Z.min` under-reports the real
fill by 2,070 studs and `insideOcean()` is built on it, so callers believe the ocean is smaller than it is.
