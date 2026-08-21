# Job #027: Islands, first slice: prove the template pipeline with one

**Project**: `roblox.tide`
**Created**: 2026-08-22 00:22:53
**Status**: Requirements Gathering (intake)

## Requirements / goal

Group 04's own instruction: 'its first job proves it with one island before any others are built.' So this job builds the PIPELINE and exactly one island, not a library.

WHY NOW: the radar landed in job 026 and searches an almost empty sea - six contacts, four of them fuel barrels. Decision 0024's run wants about 4 deep islands plus 6 quick stops, and the storm's whole stop-cost economy (a moored 5.5-minute visit costs 33% of the cushion) only bites when there is a reason to stop. Every surrounding piece now exists: the corridor, the storm with teeth, fuel, and a radar that accepts contacts by tag at zero integration cost.

SCOPE:
1. A reusable island SCULPTOR, generalised out of job 024's profile-and-paint code so the second island costs almost nothing. Radial profile with noise on the band radii (flat top, gentle upper beach, steep face across the waterline, underwater shelf), painted by height with a noisy grass line.
2. ONE island sculpted to the manifest's smallest template - the shape it specifies: beach, wreck corner, camp, rise, reef.
3. Captured as a TerrainRegion into ServerStorage/Islands/<Name>/Terrain, per decision 0016.
4. Meta markers: dock point, loot points, spawn points, POI marker. Placed as attachments/parts so group 03 and group 05 have somewhere to attach to.
5. A spawner that pastes the template along the corridor at a few positions, seats the markers on the terrain it just created, and tags each island as a radar contact of kind 'land'.
6. Graybox props only. The manifest's palms, tent, crates, rowboat and drums are Meshy/Creator Store assets and therefore the user's half - this job stands in boxes and registers them.

THE KEY REALISATION about decision 0016: CopyRegion/PasteRegion normally needs a human step, because moving terrain BETWEEN places means the human copies the TerrainRegion in Explorer (roblox-terrain skill section 6). Here the source and the target are the SAME place - the game place - so the whole capture-and-paste cycle runs in one script with no human in the loop. Decision 0016 is satisfiable end to end today.

Hard constraints from the roblox-terrain skill, all of which have burned this project already:
- CopyRegion takes Region3int16 and PasteRegion takes Vector3int16, in CELL coordinates, not studs. Passing a Region3 errors. All translation is therefore quantised to 4 studs - an 18-stud offset is impossible, 16 or 20 only.
- pasteEmptyCells must be FALSE, or the paste clears existing terrain in every empty cell of the region and punches holes in the surrounding ocean.
- Offsets must be derived SURFACE-TO-SURFACE, not centre-to-level. The skill's worked example gets +16 where the naive answer is +18.
- TerrainRegion does NOT replicate between server and client, so the paste must happen on the server.
- THE SHELF ARTIFACT: no land surface may sit between the water level and about WATER_Y + 8, or it renders as hole-riddled sheets. Job 024 measured the floor at 240 columns for a 400-column shoreline ring; the profile must cross that band in roughly one voxel.
- PROBE FOR GROUND before seating anything, and validate across the island's whole FOOTPRINT rather than one raycast (decision 0016's own consequence, plus the validate-footprint-not-point and dont-build-before-terrain-streams lessons).
- Verify in a SEPARATE execute_luau call from the write - a read in the same script can return pre-write data.
- Terrain is a saved-place change and nothing in the MCP can inspect a saved .rbxl.

Out of scope: the other 11 islands, the 9 sea POIs, the 6 rare POIs, encounter variants (the manifest's four are designed but need loot and enemies), loot tables (group 03), enemies (group 05), and real props.

Known honesty about the first slice: pasting one template at several positions means several identical islands. That is what proving a pipeline looks like, and it is worth saying rather than dressing up - variants are what make the library non-repetitive and they need content this job does not have.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
