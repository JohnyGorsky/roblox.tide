# Implementation Plan — Job #027

**Project**: `roblox.tide`
**Created**: 2026-08-22
**Status**: Planning (awaiting go-ahead)

Islands, first slice — prove the template pipeline with one. Group 04's own instruction, not a scoping choice:
*"its first job proves it with one island before any others are built."*

---

## Analysis

### The pipeline decision 0016 describes is buildable today, with nobody in the loop

Decision 0016 stores each island as a `TerrainRegion` in `ServerStorage`, captured with `CopyRegion`. The
`roblox-terrain` skill's recipe for moving terrain involves a **human step** — source place → `CopyRegion` →
*the human copies the TerrainRegion in Explorer* → target place → `PasteRegion`.

That step exists because the recipe is about moving terrain **between places**. Here the source and the target
are the *same* place: sculpt the island in the game place's ocean, capture it, paste it elsewhere in the same
ocean. One script, no hand-off.

### 🔴 Authoring happens in EDIT. Pasting happens at runtime.

This split is forced and it is easy to get wrong:

| | Where | Why |
|---|---|---|
**Author** the template — sculpt, capture, store in `ServerStorage` | **Edit**, via a `tools/` script | A `TerrainRegion` created in a Play session is discarded when Play stops. It has to exist in the saved place |
**Paste** it into the world | **runtime**, server-side | `TerrainRegion` does not replicate server→client, so the paste must be server-side. And per decision 0016 the point of a template is that positions are *not* fixed forever |

So the island's terrain is **not** in the saved place — only the template is. That is decision 0016 working as
intended: *"runtime picks a template, pastes it."*

### `pasteEmptyCells = false`, and the subtle reason it is safe

`true` makes the paste exact — every **empty** cell in the region clears whatever is at the destination, which
would punch square holes of nothing through the surrounding ocean.

With `false`, only non-empty source cells are written, and the question becomes: does the destination's water
survive where it should not? Worked through:

```
source, at an above-water column:   solid from the seabed up to +14, air above +14
destination, same column:           water -56..0, air above 0
```

The island's solid runs from *below the seabed* to +14, so it overwrites every water cell in that column. Air
only exists in the source above +14, where the destination has air too. **No water is left stranded above
land.** Where the source has water (its outer shelf), water is pasted over water at the same level.

This only holds because the island is sculpted **in the ocean at the same water level it will be pasted into**.
Sculpt it on dry ground or at a different sea level and the reasoning collapses.

### Dimensions, from the manifest's smallest template

| | |
|---|---|
Plateau | r = 90 at **+14** |
Upper beach | to r = 130 |
Steep face | to r = 138 — crosses 0…+8 in roughly one voxel |
Underwater shelf | to r = 175 |
**Across** | **350 studs** |
Capture region | 390 × 80 × 390 studs = 97 × 20 × 97 = **188,180 cells** |

⚠️ **Do not oversize the island to pad dwell time.** A lap of its beach is 817 studs — **51 seconds** at walk
speed. Decision 0024 wants 5–6 minutes on a deep island, and that time comes from *content*: the manifest's own
template has five loot points, a hidden cache under the rise, and three or four enemies. Acreage would just be
walking. The island is correctly sized for what it is; the minutes arrive with groups 03 and 05.

### Where they go

Four positions along the corridor, chosen so the radar has to work for them:

| Position (X, Z) | Off the centreline | On radar from the centreline |
|---|---|---|
(600, 500) | 600 | confident |
(−900, 1100) | 900 | confident |
(1300, 1700) | 1300 | **uncertain — an amber circle first** |
(−500, 2200) | 500 | confident |

All four are exact multiples of 4, because `PasteRegion` takes **cell** coordinates and every translation is
quantised to 4 studs. The 1300 one is deliberate: it is the first island a crew will see as a question mark and
have to decide about, which is the whole point of the edge treatment.

### Seating, and why one raycast is not enough

Decision 0016's own consequence: *"Terrain must exist before anything is seated on it — probe for ground, never
assume, and validate across the island's whole footprint rather than one raycast."* Both failures are in the
terrain skill.

So the sequence per island is **paste → verify the terrain arrived → seat markers → tag**. The verify step
samples the plateau across a grid, not at its centre, and refuses to seat anything if the ground is not there —
better a missing island than props floating over open water.

---

## Implementation steps

1. **`ReplicatedStorage/IslandTemplates.luau`** — the template *specs*: band radii, heights, paint rules, and
   the marker layout per zone. Data, no instances. Generalised out of job 024's sculpting code so island #2 is
   a table entry rather than a new script.
2. **`tools/author-island.luau`** — run once in **Edit** via `execute_luau`. Sculpts the template into a clear
   patch of ocean, verifies it in a separate call, captures it with `CopyRegion`, and stores
   `ServerStorage/Islands/Cay/{Terrain, Props, Meta}`. Then the source sculpt is removed, so the place carries
   the *template* and not a stray island.
3. **`ServerScriptService/IslandServer.server.luau`** — at run start, paste the template at each position with
   `pasteEmptyCells = false`, verify the ground, seat the `Meta` markers onto it, clone the graybox `Props`,
   and tag each island's POI marker as a `RadarContact` of kind `land`.
4. **Graybox props** — boxes at the manifest's zones (wreck corner, camp, rise) so the island is not bare and
   groups 03 and 05 have anchors to attach to. Registered as a graybox.
5. **Admin tools** — `Islands → List` (positions, whether each pasted and seated) and `Islands → Put me
   ashore` (teleport to a chosen island, because sailing 500–2,200 studs to check a paste is not a test loop).
6. **Docs** — a systems doc for the pipeline, `GAME-0005` to `IN_PROGRESS`, register the grayboxes, re-run
   `build-status.py`.

---

## What I need from you

- [ ] **Go-ahead.**
- [ ] **A saved place afterwards** — authoring the template writes to `ServerStorage` in Edit, and that only
      persists if the place is saved. I will say when.
- [ ] Nothing to source yet. Real props (palms, tent, crates, rowboat, drums) become an asset table once the
      zone shapes are settled and I know what sizes to ask for.

---

## Verification

- [ ] **The sculpt** — plateau flat to one distinct height; shelf-artifact columns near the floor job 024
      measured; no floating voxels
- [ ] **The capture** — `ServerStorage/Islands/Cay/Terrain` exists and is a `TerrainRegion`
- [ ] **The paste** — at each of the four positions, probe the plateau on a grid and confirm land at +14, then
      probe *between* islands and confirm open water. This is the check that catches `pasteEmptyCells` being
      wrong: holes in the ocean show as missing water, not missing land
- [ ] **No water stranded above land** — sample columns on each pasted plateau for liquid above the surface
- [ ] **Seating** — every marker sits on ground, none floating or buried; and the refuse-to-seat path works
      when asked to paste somewhere with no ground
- [ ] **Radar** — each island appears as a `land` contact at the right distance, and the one at 1300 off the
      centreline reads as an **uncertain amber circle** from the centreline before resolving as you close
- [ ] **The ocean is intact** — no square holes anywhere near a paste site; fog and horizon unchanged
- [ ] Verified in **separate calls** from every write; screenshots from sea level and above
- [ ] No new analyzer diagnostics; Play stopped; camera restored; place saved deliberately
