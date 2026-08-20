# FINDING 0006: Cold-ocean palette is blocked on overcast sky assets

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-20 00:01:35

**Symptom:** Established by experiment in job 007, not assumed. The sea's colour is dominated by what the sky reflects, and Roblox's default skybox (asset 6412503613) plus its procedural fallback are both clear-day skies. Four attempts to fix it in the air all failed: grey Atmosphere at Density 0.55/Haze 3.0 improved colour but killed all wave detail; pushing Atmosphere to Density 0.98/Haze 4.5 left the sky still bright blue; a dark FogColor with FogEnd 900 darkened the water but not the sky, producing a hard black horizon line; and removing the skybox gave the cleanest horizon but still a clear-day sky. Conclusion: neither Fog nor Atmosphere can turn a clear-day sky overcast, so docs/game/visual-design.md's cold Bermuda-military look is unreachable until real overcast sky assets exist. Registered as ASSET-SKY-OVERCAST (status IDEA) and elevated in docs/build/01-sea.md from a polish item to the highest-value asset in the group. Need at least 3 (overcast day, storm, night), ideally 7, one per sea stage. Also record two related facts learned: fog darkens the world but NOT the sky, so fog controls distance while sky and Atmosphere control colour; and wave legibility depends on WaterReflectance catching sky contrast, so darkening the sea by starving reflectance renders it as a featureless plane.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
