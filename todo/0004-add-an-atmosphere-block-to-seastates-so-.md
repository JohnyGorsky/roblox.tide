# TODO 0004: Add an atmosphere block to SeaStates so the sea recolours with the weather

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-20 12:22:41

SeaStates currently drives terrain water plus fog, but job 007 established that Atmosphere and the sky dominate the sea's apparent colour while WaterColor is a weak lever - four attempts to recolour the ocean through water properties and fog alone all failed. So each state needs an atmosphere block (Density, Offset, Haze, Glare, Color, Decay) applied alongside the water and fog values, and SeaStates.lerp must interpolate it too so weather arrives smoothly. The values to use already exist as measurements: job 007 found Haze 3.0 flattens all wave detail while 1.1 keeps depth, and the storm treatment used Density 0.62 / Haze 2.2 / Color 86,96,105 / Decay 30,36,44. The copyAsLuau admin tool already emits current Atmosphere values as comments precisely so they can be pasted in once the block exists. Separately, consider a transient response so a rain squall or a lightning flash can shift the water read briefly rather than colour only ever stepping between the five states. Note the ceiling on all of this: until overcast sky assets exist (finding 0006) no amount of Atmosphere tuning reaches the intended palette.
