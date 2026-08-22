# FINDING 0028: OCEAN_EXTENT_Z.min says -1000 but the water actually reaches -3070

**Project:** `roblox.tide`
**Status:** open
**Severity:** low
**Created:** 2026-08-22 10:33:00

**Symptom:** Measured by walking the liquid channel outward and bisecting: water ends at Z=-3070 south, Z=5502 north, X=+3074/-3070. The Z minimum constant therefore under-reports the real fill by 2070 studs, and insideOcean() is built on it - so every caller treats the world as ending at Z=-1000 when there is open water for another 2 km. Wrong in the safe direction (nothing gets placed outside the water) but it is a constant that lies, and it already misled me into reporting a visible world edge that does not exist.
**Where:** SeaStates.OCEAN_EXTENT_Z, insideOcean, validateCorridorForTarget
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
