# Final Summary — Job #027

**Project**: `roblox.tide`
**Completed**: 2026-08-22
**Status**: ✅ Built and measured. `GAME-0005` is now `IN_PROGRESS`.

Islands, first slice. Group 04's own instruction was to *"prove it with one island before any others are
built"* — one template exists, and it is pasted at four positions to prove it is a template rather than a
place. Mapped in [systems/islands](../../docs/systems/islands/README.md).

## What it does

| Piece | |
|---|---|
`IslandTemplates.luau` | what an island **is**, as data. Bands, radius noise, paint rules, 15 markers |
`tools/author-island.luau` | the authoring pipeline: sculpt → verify → capture → restore, one step per call |
`IslandServer.server.luau` | pastes the template at boot, verifies the ground, seats markers, builds grayboxes |
`ServerStorage/Islands/Cay` | the stored template — `{Terrain, Props, Meta}`, 240,429 cells |
Admin | an **Islands** section: *List islands*, *Put me ashore* |

Decision 0016's pipeline now runs end to end **with nobody in the loop**. The terrain skill's recipe for
moving terrain needs a human to copy a `TerrainRegion` between places in Explorer; here source and
destination are the *same* place, so one script does it.

## The three things worth keeping

### 🔴 A gentle shore cannot avoid the shelf artifact at all. Only a discontinuity can.

This is the finding of the job. The rule was known — no land surface between the water level and about +8, or
it renders as thin hole-riddled sheets — and job 024 measured 240 offending columns of a 400-column shoreline
as *"what as good as it gets looks like"*.

That framing hid the real conclusion. **Any continuous profile crossing the waterline must put some column's
surface inside the band**, so steepening only reduces the count and can never reach zero. My first sculpt used
a 60° face and measured **335** offending columns — plainly visible as flat sheets lying on the sea, which is
how I found it.

Making the drop a **discontinuity** — jump straight from `beachTop` to `faceBottom`, generate nothing between
— took it to **exactly 0**, because no column's surface can land in a band no column targets. The renderer
bridges the two adjacent columns with a 72° face, which a Humanoid still walks up.

The cost is a bluff coastline, so **one arc keeps a real beach**: 26° either side of the Dock's bearing,
16 studs of run, 38 accepted columns. That is where you land and where the jetty art will go.

### 🔴 Terrain stands 2 studs higher than the height you sculpt

The `roblox-terrain` skill said *"surface height = topmost solid voxel centre + RES/2"*. Measured against 73
columns:

| Rule | Mean abs. error | Worst |
|---|---|---|
`centre + RES/2` — what the skill said | **1.657** | 2.000 |
**`centre + occupancy × RES`** | **0.087** | 0.973 |

Substituting the voxel arithmetic, that collapses to **`sculpt target + RES/2`**. A plateau declared at 16 is
walked on at 18. Verified both ways: a column targeted at 9.98 measured 11.982.

**How it surfaced is the part worth remembering.** The first ground check reported *"worst error 2.0 studs"*
on all four islands against a tolerance of exactly 2 — a pass that a 1.9 tolerance would have failed. That is
a test agreeing with a bug rather than testing anything. After the conversion the same check reads **0.0**
and the tolerance is 0.6.

### The islands are not in the saved place — only the template is

Which is decision 0016 working as intended, and the thing most likely to look like a bug later. Authoring
happens in **Edit** (a `TerrainRegion` made during Play is discarded); pasting happens at **runtime**
server-side (`TerrainRegion` does not replicate). If `ServerStorage/Islands` is empty, the place was never
saved after authoring — and *List islands* says exactly that rather than showing an empty sea.

**Pasted at boot, not at run start**, which departs from the plan's wording on purpose: a 240,000-cell paste
mid-run is a hitch at the moment the crew is being chased, and having the first island already on the scope
teaches the radar during the five minutes before departure.

## Where they are, and why one of them matters

| Island | Position | Off the centreline | On radar from the centreline |
|---|---|---|---|
Gull Rock | (600, 500) | 600 | a labelled fix from the first second |
The Spit | (−900, 1100) | 900 | resolves as you close |
**Anvil Cay** | **(1300, 1700)** | **1300** | **amber circle — and it never resolves** |
Long Shoal | (−500, 2200) | 500 | resolves as you close |

Anvil Cay is job 026's edge treatment finally having something to point at. 1300 is its closest approach on
the centreline, outside the 1080-stud confidence radius, so it stays an unlabelled question mark unless the
crew decides to go and look. Checked against `Radar.classify`, not by eye.

## Measured

| Check | Result |
|---|---|
Plateau | **one** distinct height, Y=18, across 952 columns; 0 soft-lid columns |
Ground check | **13/13** probes per island, worst error **0.0** studs against a 0.6 tolerance |
Shelf artifact off the landing arc | **0** — was 335 |
Shelf artifact on the landing arc | 38, accepted |
Water above dry land | **0** voxels over 3,382 dry columns, all four islands |
Holes punched in the ocean | **0**; and no seam at the capture boundary — the shelf runs smoothly into the seabed at −54 |
Paste fidelity | all four islands identical in **every** counted metric, which is also the cell-alignment proof |
Cliff slope | **72°** (walk limit is 89) |
Markers | **15/15** seated per island, **0** with no ground |
Sculpt site after restore | 11,236 columns all at −54, 0 dry, 0 thin water — no stray island in the saved place |

## Six bugs, and how each was found

1. **The plateau was a half-full lid.** Declared at 14, its top voxel came out at occupancy **0.498** with
   full sand beneath showing through. Voxel-aligning it to 16 makes it solid 1.0. *Found by dumping the raw
   column rather than trusting "1 distinct height".*
2. **The plateau came out 707 sand to 101 grass** when it should be green. Material was chosen per voxel from
   that voxel's own height, so the topmost mostly-solid voxel sat below the grass line. Now the material is
   chosen once per column from the column's **surface**, then applied down 6 studs.
3. **`footprint()` under-reported by 6 studs.** It returned `ro + 20` = 195 while the radius noise swells the
   outline to `ro × 1.15` = 201, so the outermost shelf ring fell outside the capture box on the four axis
   directions — a one-cell step underwater. It now sums the noise amplitudes.
4. **The Rise mound was a 26-stud tower.** A cylinder's axis is its **local X**, so a low disc is
   `Size(thickness, diameter, diameter)`. Same bug in the firepit. *Found in a screenshot.*
5. **The ground tolerance was hiding the surface-rule error** — see above.
6. **`require` without `:Clone()` returned a stale module.** The `execute_luau` context caches, so a verify
   call got a nil `faceRun` and failed with *"attempt to call a nil value"* immediately after the file synced.

### Three of my own measurements were wrong before the code was

Worth recording, because each nearly became a false conclusion:

- **"335 offending columns, ratio 0.12"** — I divided by an *annulus* of 1,056 columns and reported it as a
  5× improvement on job 024's 0.60. Against the shoreline **circumference** the same count is **0.60** — the
  identical floor, no improvement at all.
- **"33,070 voxels of water above land"** — the check counted the ocean sitting over the island's own
  underwater shelf, which is correct water. Only land whose surface is *above* the datum can strand anything.
- **"0/8 bearings are open water"** — the probe points sat **outside** the read region, so the bounds check
  returned "not water" for every bearing with the terrain perfectly intact.

And one visual misread: the first screenshot looked like a **bowl** with a raised sand rim. An ASCII height
map settled it in one call — monotonically decreasing on every bearing, no rim. The bright sand ring below
the green plateau just reads as a wall in an oblique view.

## Deferred

- **Per-run selection.** Positions and count are a fixed list; the template is fully positional, which was
  the point of proving it at four positions
- **No cleanup or reuse.** Islands are pasted once and never unloaded — fine at four, a question at 10–20
- **Encounter variants** (pirates / abandoned / trader / drowned / storm-damaged / night), difficulty tags
  and encounter weights: the design doc's largest outstanding section, and it needs groups 03/05 first
- **Real props.** The three graybox zones become an asset table once the zone shapes are settled
- **The coastline is a bluff** everywhere except the landing arc. That is the artifact trade, and a mesh
  shoreline is the eventual answer
- **The Islands admin tools appear in the lobby too** and always report "no island server", which is how
  every other place-specific section already behaves — `AdminTools` is shared verbatim

### ✅ Auto-synced files

- `studio_game/ReplicatedStorage/IslandTemplates.luau` *(new)*
- `studio_game/ServerScriptService/IslandServer.server.luau` *(new)*
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/` copy — a new **Islands** section
- `tools/author-island.luau` *(new)*, `tools/audit-graybox.luau` — registered `GB-ISLAND-PROPS`

### ⚠️ Manual Studio action required

- 🔴 **Save the game place.** `ServerStorage/Islands/Cay/{Terrain, Props, Meta}` was written into the live
  Edit session and **only persists in the saved file**. Without the save, the next server boot finds no
  template and places no islands — `Islands → List islands` will say so.

## Verification

- [x] Sculpt verified in a **separate call** from every write, per the terrain discipline
- [x] Plateau flat to one height; 0 soft-lid columns; 0 floating voxels
- [x] Shelf artifact **0** off the landing arc, on the source sculpt **and** on all four pasted copies
- [x] No water stranded above land, no holes in the ocean, no seam at the capture boundary
- [x] Ground verified on a **grid** across the footprint before anything was seated (not one raycast)
- [x] Voxel and raycast surfaces cross-checked and made to agree
- [x] Radar contacts confirmed against `Radar.classify`, including the amber case
- [x] Source sculpt removed and the site re-verified as plain ocean
- [x] Screenshots from sea level and oblique; the landing beach seen up close
- [x] No new analyzer diagnostics (diffed against `HEAD` for `AdminTools`); 18 shared files identical
- [x] Play stopped; Studio left in Edit
- [ ] **Not** tested with a character walking up the 72° cliff — the slope is under the documented limit but
      nobody has walked it
- [ ] Never seen on a phone (todo 0003 territory)
