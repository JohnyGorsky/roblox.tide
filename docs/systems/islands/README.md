> This file carries **two** things: the implementation reference for what is built, and below it the
> original design intent for the system as a whole, preserved verbatim. Where the two disagree, the design
> intent is the destination and the implementation is how far along the way we are.

# Islands — the template pipeline

Implementation reference for `GAME-0005`, first slice built in job 027. Governed by
[decision 0016](../../decisions/0016-island-terrain-pipeline.md) (islands are templates pasted at runtime),
[0024](../../decisions/0024-expedition-shape-and-pacing.md) (5–6 minutes per island) and
[0025](../../decisions/0025-ocean-is-a-corridor.md) (where they may sit).

## Where it lives

| File | Owns |
|---|---|
`ReplicatedStorage/IslandTemplates.luau` | what an island **is**, as data. Profile, paint rules, markers. Pure |
`tools/author-island.luau` | the **authoring** pipeline — sculpt, verify, capture, restore. Run in **Edit** |
`ServerScriptService/IslandServer.server.luau` | pastes the templates at boot, seats markers, builds grayboxes |
`ServerStorage/Islands/Cay/{Terrain, Props, Meta}` | the stored template. **Lives in the saved place, not in code** |

## The split that is easy to get wrong

| | Where | Why |
|---|---|---|
**Author** a template | **Edit**, via `tools/author-island.luau` | a `TerrainRegion` made in a Play session is discarded when Play stops. It has to exist in the **saved** place |
**Paste** it into the world | **runtime**, server-side | `TerrainRegion` does not replicate server → client. And per 0016, positions are not fixed forever |

🔴 **The islands are therefore not in the saved place — only the template is.** If `ServerStorage/Islands`
is empty, nothing was saved after authoring, and `Islands → List islands` says so in as many words.

## The profile, and the one rule it exists to obey

```
r <= 90        flat plateau at +16   (walked on at +18)
90 < r <= 130  upper beach, down to +8   (surface +10)
r > 130        THE DROP - a cliff, except on the landing arc
... <= 175     underwater shelf, to -22
```

350 studs across, from the manifest's smallest template. The radius noise (three harmonics, ±15%) is applied
to the band **radii only, never the heights**, so the outline wanders while the plateau stays provably flat —
which matters because things get placed on it.

### 🔴 The shelf artifact is avoided BY CONSTRUCTION, and a gentle beach cannot do it

Land whose surface sits between the water level and about +8 renders as thin hole-riddled sheets. The
important discovery of this job is that **no continuous profile can avoid that** — to get from +10 to −4
continuously you must pass through the band, and whatever column lands in there is a sheet. Steepening only
reduces the count.

| Profile | Offending columns |
|---|---|
Gentle bank (job 024's floor) | 240 of a 400-column shoreline |
60° face, job 027's first sculpt | **335** — clearly visible as sheets on the sea |
**Discontinuity, this profile** | **0 off the landing arc** |

`heightAt` jumps straight from `beachTop` to `faceBottom` and generates **nothing between them**, so no
column's surface can land in a band no column targets. The renderer bridges the two adjacent columns with a
**~72° face**, which a Humanoid still walks up — `MaxSlopeAngle` defaults to 89.

**The cost is a bluff coastline, so one arc keeps a real beach.** 26° either side of bearing 200 — the same
bearing as the `Dock` marker — spreads the drop over 16 studs. That arc is the only place the artifact is
accepted (38 columns), it is where you land, and it is where the jetty art will sit.

### 🔴 Terrain stands 2 studs higher than the height you sculpt

Measured across 73 columns: the collision surface is `topmost non-empty voxel centre + occupancy × RES`,
which for a sculpt target `h` simplifies to **`h + 2`**. Use `IslandTemplates.surfaceOf`. Finding 0024 has
the numbers; the `roblox-terrain` skill has been corrected.

The plateau height must also be a **multiple of 4**, so its top voxel is solid 1.0 rather than a half-full
lid with the sand beneath showing through. 14 gave occupancy 0.498; 16 gives 1.000.

## Where they are

Four, up the corridor. All coordinates are multiples of 4 — `PasteRegion` takes **cell** coordinates, so
anything else is quantised silently and the island ends up somewhere its markers are not.

| Island | Position | Off the centreline | On radar from the centreline |
|---|---|---|---|
Gull Rock | (600, 500) | 600 | a labelled fix from the start |
The Spit | (−900, 1100) | 900 | fix as you close |
**Anvil Cay** | **(1300, 1700)** | **1300** | **amber circle, and it NEVER resolves** |
Long Shoal | (−500, 2200) | 500 | fix as you close |

Anvil Cay is the point of the radar's edge treatment: 1300 is its closest approach on the centreline, which
is outside the 1080-stud confidence radius, so it stays an unlabelled question mark unless the crew goes and
looks. Gull Rock is the opposite — a labelled contact from the first second, which teaches the instrument
during the five minutes before departure.

## Markers

15 per island, polar (a fraction of `ro` plus a bearing) so a bigger template places them proportionally.
Tagged `IslandMarker` with `IslandId`, `MarkerKind` and the design `Note`. Discovered by **tag**, never by
path — finding 0020.

Mapped to the manifest's five zones: POI · Dock · Wreck + 2 loot · Camp + 2 loot · Rise + hidden cache ·
Reef + crab pot · 3 enemy spawns. Nothing here places loot or enemies; groups 03 and 05 do that, and these
are the anchors they attach to.

The **POI** marker is additionally tagged `RadarContact` with `RadarKind = "land"`, so an island only has to
exist to appear on the scope.

## Verify the ground, then seat. Never the other way round.

Decision 0016's own consequence. Per island: **paste → verify → seat → tag**, and the verify samples a grid
across the plateau rather than one raycast at the centre, because one central raycast passes for an island
that pasted only its middle column.

- the paste is verified by **voxels** (authoritative, no physics dependency)
- markers are seated by **raycast** (what every later system will use)
- the two are cross-checked, and a mismatch is reported rather than smoothed over
- a failed verify **skips the island** and warns. A missing island is a bug you can see; props floating over
  open water is a bug that ships

⚠️ Voxels need a frame or two after the paste before a raycast will hit them.

## `pasteEmptyCells = false`, and why it is safe

`true` would clear every **empty** source cell at the destination, punching square holes of nothing through
the surrounding ocean. `false` overlays solid cells only, and the question becomes whether the destination's
water survives where it should not:

```
source, above-water column:  solid from below the seabed up to +16, air above
destination, same column:    water -54..0, air above 0
```

The island's solid overwrites every water cell in that column, and air exists in the source only where the
destination has air too. Measured after pasting: **0 voxels of water above dry land, 0 holes in the ocean.**

🔴 This only holds because the island is **sculpted in the ocean at the same water level it is pasted into**.
Sculpt it on dry ground or at a different sea level and the reasoning collapses.

## Testing it

`Islands` section in the admin panel, ordered third:

- **List islands** — the template store, which islands placed, their ground-check detail, and any marker
  that found no ground
- **Put me ashore** — drops you on the chosen island's **landing beach**, at a freshly probed height rather
  than a stored one. Sailing 500–2,200 studs to look at a paste is not a test loop

## Traps

🔴 **`footprint()` must account for the radius noise.** It returned `ro + 20` = 195 while the noise swells
the outline to `ro × 1.15` = 201, so the outermost shelf ring fell outside the capture box on the four axis
directions — a one-cell step underwater. It now sums the amplitudes.

🔴 **`Region3int16`'s max corner is INCLUSIVE.** `SizeInCells` came back 107 for a half-width of 53, i.e.
`max − min + 1`. The paste corner is `destinationCentreCell − halfCells`. Finding 0025.

🔴 **A cylinder's axis is its LOCAL X.** A low disc is `Size(thickness, diameter, diameter)` rotated 90°
about Z. `Size(26, 6, 26)` builds a 26-stud tower, which is what the first Rise mound was.

🔴 **The sculpt must be idempotent** — write every voxel in the band explicitly, carving above the surface
and rebuilding water. A fill-only pass cannot lower a band and leaves the previous profile behind.

⚠️ **`require` without `:Clone()` in `execute_luau` returns a stale module.** That context caches, so a
plain require gives the copy from before the last sync — which is how one authoring run got a nil `faceRun`.

## Still owed

- **Per-run selection.** Positions and count are fixed for this slice; 0016's point is that they need not be
- **10–20 islands** per decision 0024, and more than one template. Island #2 should be a **table entry**
- **Real props.** The three graybox zones become an asset table once the zone shapes are settled
- **Loot, enemies, and the reason to stop** — groups 03 and 05, attaching to the markers above
- **The dwell time.** A lap of the beach is 51 seconds; the 5–6 minutes come from content, not acreage

---

# Design intent (original, preserved)

The design this system is heading towards, written before any of it was built. **Nothing here has been
edited** — it is the yardstick, not a description of the current state.

Status against the sections below, as of job 027:

| Design element | State |
|---|---|
Curated templates, not uncontrolled runtime procedural | ✅ done — one template, pasted at runtime |
Terrain snapshot/region · metadata | ✅ done — `ServerStorage/Islands/Cay/{Terrain, Meta}` |
Dock points · loot points · enemy spawns · POI markers | ✅ done as **markers**; nothing spawns on them yet |
Object model collection | 🟡 graybox boxes only |
Difficulty/stage tags · encounter weights | ❌ not started |
Island Forge workflow (generate → reject/keep → sculpt → props) | 🟡 `tools/author-island.luau` does generate → verify → capture. The human reject/keep and hand-sculpt passes are not wired |
Encounter variants and the variation states | ❌ not started — this is the big one still outstanding |
Global water, islands contribute land only | ✅ done — one ocean, and the template is sculpted *in* it |

## Decision

Major islands should be **curated templates**, not uncontrolled runtime procedural terrain.

Procedural generation may be used during development to produce candidates, which are then selected and manually improved.

## Island Forge workflow

```text
generate candidate
→ reject or keep
→ sculpt/fix
→ add rocks/trees/buildings
→ add gameplay markers
→ save approved template
```

## Template concept

Each island should have:

- terrain snapshot/region
- object model collection
- metadata
- dock points
- loot points
- enemy spawn points
- POI markers
- difficulty/stage tags
- encounter weights

## Runtime

```text
choose approved template
→ paste terrain / clone props
→ choose encounter variant
→ spawn loot
→ spawn enemies/events
```

## Variation

Reuse terrain with different states:
- pirates
- abandoned
- trader
- drowned enemies
- storm damaged
- rare loot
- nighttime variant

## Global water

Prefer a shared/global ocean. Island templates should primarily contribute land/materials and their local props.
