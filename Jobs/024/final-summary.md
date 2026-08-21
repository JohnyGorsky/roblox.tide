# Final Summary — Job #024

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ Both islands built, measured and painted. ⚠️ **Neither place has been saved yet** — see below.

Sculpt and paint two islands: the lobby hub, and the game place's start island.

## The ground rule this overrode

[GROUND-RULES.md line 40](../../../roblox.workspace/GROUND-RULES.md) assigns hand-sculpted islands to the
human and says plainly that hero terrain *"is not Claude's job"*. The user overrode it — *"no you sculpt
island, i think you can do it"* — which is theirs to do, and the override was flagged before starting rather
than after.

Worth recording how it actually went, because it informs whether to do this again: a radial profile with
noise is **computed** geometry, so the *shape* came out correct first time and provably so. What took three
passes was the **paint**, which is exactly the "eyeballing" half the rule carves out. Claude can build a
correct island; judging whether it looks good still needs eyes.

## What was built

| | Lobby hub | Game start |
|---|---|---|
| Overall | **600 studs across** | 120 studs across |
| Flat top | **350 across at Y=+14** | 60 across at Y=+12 |
| Bands (plateau/beach/face/shelf) | 175 / 240 / 248 / 300 | 30 / 42 / 47 / 60 |
| Voxels written | 221,572 of a 379,456 region | 10,942 of a 25,920 region |
| Status | **Real** — `ASSET-LOBBY-ISLAND`, not a graybox | Graybox — `GB-GAME-START-ISLAND` |

Both are one continuous fill from below the existing seabed up to the profile, so they **merge with the
seabed** rather than floating above it — the lobby's is at −40, the game's at −56, which is why the two
regions have different floors.

### The plateau is measurably flat

Not "looks flat":

- **Lobby: one distinct surface height across 4,404 columns.**
- **Game: one distinct surface height across 112 columns.**

That is the functional requirement, not a cosmetic one — party pads get placed on it in the editor
(Planned 0002), and a plateau with a 4-stud step in it would make that miserable.

It is flat *because* the coastline noise is applied to the band **radii** rather than to the heights. The
outline wanders; the top cannot.

### The steep shoreline is deliberate

The `roblox-terrain` skill's shelf artifact: land whose surface sits between the water level and about +8
renders as thin hole-riddled sheets, and *a gentle beach ramp through the waterline produces it along its
entire length*. So the profile crosses 0…+8 in roughly one voxel column.

Measured: **240 columns in the 0…+8 band on the lobby island, 19 on the game island.** The lobby's shoreline
ring is about 400 voxel columns around, so 240 means most ring positions jump straight from above +8 to below
0 with no column in the band at all. **That is the floor for any land meeting water, not a defect** — you
cannot have a shore without some voxel spanning the waterline.

The visible consequence is a short beach face rather than a long shallow sand slope. That is the honest trade
Roblox terrain imposes.

## Three things I got wrong, and how they showed up

**1. My own verification under-reported the plateau by 2 studs.** The first check used
`occupancy > 0.5`, which excludes the exactly-half-full top voxel whose iso-surface sits at 14 — so a plateau
built at +14 measured as +12. The terrain was right; the *test* was wrong. This is precisely the off-by-2
class the skill warns about, arriving in the measurement rather than the geometry. Later checks use `>= 0.5`.

**2. Painting by height alone made the shore mostly grass.** Pass 1 used `wy >= 10` for grass while the beach
descends 14 → 8, so nearly the whole shore came out green and the sand read as a thin rim.

**3. Then the fix put a bald sand patch on the flat top.** Pass 2 moved the sand/grass line to a noisy
contour, `12.2 + 1.4 × noise` — and the noise reaches ~1.5, so the line could exceed the plateau's own height
of 14 and paint patches of the top as sand. Visible immediately as a white blob in the middle of the green.
Pass 3 clamps the line below the plateau and centres it lower, which produced the wide sand shore and
irregular grass edge that reads as a cay.

The general lesson worth keeping: **a material rule keyed to absolute height will collide with any flat
surface at that height.** Clamp it against the surface it must not reach.

## Instances moved, none deleted

Old positions recorded so any of it can be put back.

| Place | Instance | From | To |
|---|---|---|---|
| Lobby | `SpawnLocation` | (0, 5, 0) | (0, 16, 0) — on the plateau |
| Lobby | `GB_SpawnDock` | (0, 2, 0) | (−254, 6, 0) — a jetty |
| Game | `SpawnLocation` | (0, 5, 0) | (0, 14, 0) — on the plateau |
| Game | `GB_ObservationDeck` | (0, 3, 0) | (0, 3, −400) — parked clear |

**The dock needed a second attempt.** Placed at the nominal shoreline (r≈252) its inner end landed at r=220
where the beach is +8.4 — three studs *above* the dock's deck, i.e. buried. The coastline noise makes the
waterline bearing-dependent: on the −X side the profile's factor is 0.954, putting the real waterline at
**r=228** (measured by walking the surface inward, not computed). Re-sited to span r=222…286 with its deck at
Y=8, so it runs from the beach crest out over 20 studs of water.

`GB_ObservationDeck` is **parked, not deleted** — its own registry note says to retire it now `GAME-0001` has
landed, and decision 0024 replaces its purpose with the start island, but deleting place geometry is the
user's call.

## Verified

- [x] Lobby plateau flat: 1 height / 4,404 columns, all Grass or LeafyGrass
- [x] Game plateau flat: 1 height / 112 columns
- [x] Profiles match the intended bands at every sampled radius, allowing for the noise factor
- [x] Shelf artifact at the floor: 240 columns (lobby, ~400-column ring), 19 (game)
- [x] No floating voxels above either plateau
- [x] 🔴 **The launch's spawn is still open water** — (70, 0, 0) reads seabed 56 studs down, and the port side
      at (63, 0, 0) is 20 studs clear of the hull's 1.8 draft. This was the one way this job could have broken
      job 022
- [x] Every terrain read/write size-checked, every `pcall` result checked
- [x] Verified in **separate calls** from the writes, never in the same script
- [x] Camera restored to `Custom` in both places after every capture
- [x] Screenshots: lobby from sea level and from above, game island from sea level

### ⚠️ Not done — needs you

- [ ] **SAVE BOTH PLACES.** Terrain lives in the place file, not in source, and there is no save tool in the
      MCP — so both islands exist only in the currently open sessions. Nothing can inspect a saved `.rbxl`
      either, so if they are missing next session, the save is the first suspect.
- [ ] **Judge the look.** The shape is provably correct; whether it reads well is yours. The lobby's sand
      apron is wide — one number (the grass line, currently ~10.4 against a +14 plateau) moves that either
      way, and repainting touches no geometry.
- [ ] **Retire `GB_ObservationDeck`?** Parked at (0, 3, −400), still registered.
- [ ] **`GB-LOBBY-DOCK`'s future** — now a jetty on the island's shore, which is the "real harbour furniture"
      option Planned 0002 offered. Confirm and I will re-register it as such rather than as a placeholder.

## Knock-on effects

- **[Planned 0002](../../Planned/0002-lobby-place-and-departure.md) is unblocked.** It was waiting on this
  island; it is now ready to promote.
- **Job 023's start island is done** — that step and its graybox row are struck through in its plan.
- `tools/audit-graybox.luau` gained `GB-GAME-START-ISLAND`. Terrain cannot carry a `CollectionService` tag,
  so a transparent marker part at the island's centre holds the `GrayboxId` for the audit to find.

### ✅ Auto-synced files

- `tools/audit-graybox.luau`
- `assets/registry/assets.yaml`

### ⚠️ Manual Studio action required

- **Both places must be saved by hand** (see above). The terrain itself is not in source and cannot be.
