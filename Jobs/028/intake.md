# Job #028: Sea, lighting and atmosphere quality pass

**Project**: `roblox.tide`
**Created**: 2026-08-22 09:58:36
**Status**: Requirements Gathering (intake)

## Requirements / goal

The game reads flat and clipped next to comparable Roblox sea games. Four concrete complaints from the user, plus what has already been measured:

1. NO DEPTH / CLIPPED DISTANCE. Lighting.FogEnd is 2353 live (DeadCalm caps at 2900). Reference games keep islands readable as pale silhouettes several thousand studs out - atmospheric perspective, not an erase. Our fog deletes everything past ~2.3k, so the world has no depth and no sense of scale.

2. THE OCEAN HAS A VISIBLE EDGE ASTERN. Measured: water runs Z -1000..5500, so from the launch at Z=0 the south edge is 1000 studs away while fog reaches 2353. SeaStates.validateFogWithinOcean() reports OK because it compares fogEnd against OCEAN_HALF_EXTENT - a SQUARE-ocean test written before decision 0025 made the ocean an asymmetric corridor. It cannot see the south edge at all. Confirmed empirically: water at Z=-1600 yes, X=3100 no.

3. THE SEA APPEARS AS YOU MOVE. StreamingEnabled is true in the game place. StreamingTargetRadius / StreamingMinRadius / StreamingIntegrityMode are NOT script-readable (not valid members from a script context), so the radius is unmeasured - the default is 1024, which is well inside FogEnd, so terrain would pop in inside the visible range. Needs verifying in the Properties panel.

4. FLAT LIGHTING AND A DEAD PALETTE. LightingStyle is already Realistic, so this is not a cheap-path problem. Live values: Brightness 2.6, ExposureCompensation -0.05, ClockTime 13.5, Atmosphere Density 0.45 / Haze 1.4 / Glare 0, WaterColor 18,53,74 (near-black navy), WaterReflectance 0.65, WaterTransparency 0.35, SunRays and Bloom on, DepthOfField off.

OPEN QUESTION TO SETTLE FIRST: does an Atmosphere object override Lighting.FogStart/FogEnd? If it does, the per-sea-state fogEnd numbers are doing nothing and the whole storm-visibility model rests on a property with no effect. Check the official docs before changing any number.

CONSTRAINT: do not simply copy the reference game's bright tropical palette. The Last Tide is a cold storm-chase by design (decisions 0003/0019). Separate the TECHNICAL faults - visible world edge, streaming pop-in, fog erasing silhouettes instead of fading them - from ART DIRECTION, and fix the technical faults first. A cold sea can still have depth, contrast and a clean horizon.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
