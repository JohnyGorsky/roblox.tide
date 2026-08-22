# FINDING 0025: Region3int16's max corner is INCLUSIVE, so a CopyRegion of min..max captures max-min+1 cells

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-22 01:04:14

**Symptom:** Nothing in our terrain reference states whether Region3int16's max corner is inclusive or exclusive, and the paste corner maths depends on it. Measured: CopyRegion over min (-653,-15,1097) to max (-547,5,1203) returned SizeInCells 107,21,107, which is max-min+1 rather than max-min. So a half-width of 53 cells captures 107 cells, and the paste corner is destinationCentreCell - halfCells.
**Where:** tools/author-island.luau cellRegion, roblox-terrain skill section 6
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
