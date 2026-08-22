# FINDING 0024: Smooth terrain's collision surface sits RES/2 above the height you sculpt, not at the top voxel's centre + RES/2

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-22 01:04:00

**Symptom:** The roblox-terrain skill states 'surface height = topmost solid voxel centre + RES/2'. Measured against 73 columns of a real sculpt, that rule has a mean absolute error of 1.657 studs and a worst case of exactly 2.0. The rule that fits is 'topmost NON-EMPTY voxel centre + occupancy * RES' (mean absolute error 0.087), which for a sculpt target h simplifies to h + RES/2. A plateau sculpted at 16 is walked on at 18. Job 027 first saw this as 'worst error 2.0 studs' with the tolerance set to exactly 2 - a passing test that a 1.9 tolerance would have failed.
**Where:** tools/author-island.luau, IslandTemplates.surfaceOf, roblox-terrain skill section 3
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
