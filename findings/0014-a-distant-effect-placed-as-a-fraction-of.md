# FINDING 0014: A distant effect placed as a fraction of FogEnd is erased by the fog in front of it - place by target OCCLUSION instead

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-20 15:38:39

**Symptom:** The cloud wall was pinned at 82% of Lighting.FogEnd, reasoning that it needed to stay inside the fog to be visible at all. It rendered correctly and was invisible, and the user reported seeing no wall approaching. Cause: fog opacity ramps LINEARLY from clear at FogStart to solid at FogEnd, so 82% of the way to FogEnd is ~81% occluded - the wall was being erased by the air in front of it. Measured across the storm bands: 81% / 81% / 63% / 52% / 44% occlusion, so at exactly the two distances a crew watches an approach from it was gone, while every other value in its report looked correct. Every emitter setting, the geometry, the position and the colour were all right; the only thing wrong was where it stood relative to the fog curve. Fix: place by TARGET OCCLUSION rather than by any fraction of FogEnd - distance = FogStart + 0.35 * (FogEnd - FogStart) - which now yields a constant 35% at every band. This is robust in a way a FogEnd fraction cannot be, because FogStart moves independently per sea state (Dead Calm starts fog at 200, The Wall at 10), so the same fraction means wildly different occlusion in different weather. General rule: for anything meant to be SEEN at distance, compute the fog occlusion at its range and treat that as the number to hold constant; and put the occlusion in the effect's own report, because 'invisible while all settings read correct' is otherwise very hard to diagnose. Also raised the wall's own opacity (transparency floor 0.62 -> 0.46) since fog is already thinning it, and dropped MIN_INTENSITY so a faint smudge is present from 4.2 km - it is the crew's early tell and it was showing nothing for the first stretch of an approach.
**Where:** studio_game/ReplicatedStorage/CloudWallVFX.luau
**Repro / notes:** _TODO_
**Fix idea:** _TODO_

## Update — this is a CLASS of bug, now seen three times

Same root cause, three different shapes. Anything drawn at or beyond `Lighting.FogEnd` is erased, and
`FogEnd` is not a constant — the composer drives it from the sea state, so it ranges from 2550 studs in fair
weather down to **330 inside The Wall**.

| # | What | Symptom |
|---|---|---|
| 1 | Cloud wall pinned at 82% of `FogEnd` | invisible at the distances a crew watches from (81% occluded) |
| 2 | Cloud wall pinned at a **fixed** 340 studs | fine for phases 0–3, then vanished at phase 4 when `FogEnd` closed to 330 — *below* the render distance |
| 3 | Lightning bolts drawn at their true 400–2600 studs | distant strikes fogged out entirely in a storm (`FogEnd` 1280), so only the flash on the player landed |

Case 2 is the instructive one: the fix for case 1 introduced it. Pinning to a constant is just as wrong as
pinning to a fraction — the fog moves, and a constant cannot follow it.

**The rule:** anything that must be SEEN gets a render distance derived from the *current* `FogEnd`, and is
scaled by `renderDistance / trueDistance` so its apparent angular size is unchanged. True distance still
drives everything physical — thunder delay, flash strength, shake, haze — and only the *drawing* moves. Both
`CloudWallVFX` and `LightningVFX` now do exactly this.

Corollary worth keeping: put the occlusion, or the render distance against `FogEnd`, in the effect's own
report. All three cases presented as "invisible while every other value reads correct", which is close to
undiagnosable otherwise.
