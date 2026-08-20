# FINDING 0009: Terrain.WaterWaveSize is capped at 1.0 - The Wall silently asked for 1.4

**Project:** `roblox.tide`
**Status:** fixed (2026-08-20) — Fixed in job 012. The Wall's waveSize changed from an unachievable 1.4 to 1.0 with the engine cap documented at the value, and the admin panel's wave-size slider now maxes at 1 instead of 2 so nobody can drag into a range that silently does nothing. The design consequence is recorded in the feature and the manifest: 1.0 is the roughest the RENDERED water can look, so The Wall's extra violence must come from the wave field, spray and camera shake rather than this dial.
**Severity:** med
**Created:** 2026-08-20 13:18:00

**Symptom:** SeaStates specified waveSize 1.4 for The Wall. Read-back after applying it returned exactly 1.00, so the engine clamps WaterWaveSize to a maximum of 1.0 and the extra was discarded silently - no error, no warning. Consequence for the design: 1.0 is the roughest the RENDERED water can ever look, so The Wall cannot be made visually rougher than Storm by very much (Storm is 0.85). The extra violence has to come from somewhere else - the wave field amplitude, spray and whitecap density, camera shake, and audio - not from this dial. Also worth noting the admin panel's water slider allowed 0..2, which let a user drag into a range that silently does nothing above 1; its max should be 1. Fixed in SeaStates with the cap documented at the value.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
