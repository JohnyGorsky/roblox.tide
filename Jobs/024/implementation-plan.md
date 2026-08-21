# Implementation Plan — Job #024

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Status**: Planning (awaiting go-ahead — terrain is a saved-place change)

Sculpt and paint two islands: the lobby hub, and the game place's start island.

---

## Survey — what is actually there

Probed both places with a deliberately wide Y range, because a probe ceiling silently reports every taller
column as exactly the ceiling.

| | Lobby | Game |
|---|---|---|
| Terrain cells | 12,582,912 | 37,748,736 |
| Water surface | **Y = 0** | **Y = 0** |
| Seabed surface | **−40** (Sand) | **−56** (Sand) |
| Water extent | ~±1,022 | ≥±3,200 (found water at X 3,200 and Z 3,200) |
| `WaterWaveSize` | 0.060 | 0.025 |
| `FogEnd` | 1,900 | 2,353 |

Both places are already an all-water patch with a flat sand seabed. So an island is **fill**, not carve, and
there is no hand-sculpted work nearby to protect — which removes the whole class of risk the skill's
"bound the edit" rule exists for. I will still bound it.

### 🔴 Both places have geometry exactly where the island goes

| Place | Instance | At | Problem |
|---|---|---|---|
| Lobby | `GB_SpawnDock` 64×4×40 | (0, 2, 0) | Would be buried inside the island |
| Lobby | `SpawnLocation` | (0, 5, 0) | Would be inside the island — players spawn in rock |
| Game | `GB_ObservationDeck` 48×2×32 | (0, 3, 0) | Would be buried |
| Game | `SpawnLocation` | (0, 5, 0) | Same as the lobby's |

Proposed handling, none of it destructive:

- **Move both `SpawnLocation`s onto their plateau** (Y = plateau + 3). Required, or spawning is broken.
- **Move `GB_SpawnDock` to the lobby island's shore.** Planned 0002 already lists "promoted to real harbour
  furniture" as one of its two options, and a dock at the water's edge of a hub island is exactly that. Moving
  is reversible; deleting is not.
- **Move `GB_ObservationDeck` clear of the game island** rather than deleting it. Its own registry note says
  to delete it now that `GAME-0001` has landed, and decision 0024 replaces its purpose — but that deletion is
  yours to authorise, so I will park it aside and leave it registered.

---

## The profile, and why it has a cliff at the waterline

A radial height profile with an angular noise term on the **band radii** rather than on the height — so the
coastline is irregular while the plateau stays **genuinely flat**, which is a functional requirement: party
pads get placed on it in the editor.

```
r <= Rp          h = PLATEAU            flat, no noise
Rp < r <= Rb     h: PLATEAU -> +8       upper beach, gentle
Rb < r <= Rf     h: +8 -> -6            THE STEEP FACE, ~1.75:1
Rf < r <= Ro     h: -6 -> -20           underwater shelf
r > Ro           no fill                existing seabed
```

🔴 **The steep face is not a style choice.** The skill's shelf artifact: land whose surface sits between the
water level and about `WATER_Y + 8` renders as thin hole-riddled sheets — a waffle of partial occupancy that
reads as broken sandbars. A gentle beach ramp through the waterline produces it *along its entire length*.

So the profile crosses 0…+8 in about **4.5 studs horizontally — roughly one voxel column** — which means
there is effectively no land surface in the forbidden band. The visible result is a short beach face rather
than a long shallow sand slope. That is the honest trade: a Roblox-terrain island cannot have a gentle
shoreline without the artifact.

### Dimensions

| | Lobby hub | Game start |
|---|---|---|
| Plateau height | +14 | +12 |
| Plateau radius `Rp` | 110 | 30 |
| Upper beach `Rb` | 150 | 42 |
| Foot of face `Rf` | 158 | 47 |
| Outer shelf `Ro` | 200 | 60 |
| Flat area | ~220 studs across | ~60 studs across |
| Region | 408 × 64 × 408 = **166,464 voxels** | 128 × 80 × 128 = **20,480 voxels** |

Both are far under the 4,194,304 ceiling, so no slabbing — but the size check runs anyway and the `pcall`
result is checked, because ignoring it is how a size violation becomes a silent no-op that reports success.

**The game island's radius is set by the launch.** `VesselServer.SPAWN_OFFSET` is (70, 0, 0) and the hull is
14 wide, so it spans X 63…77. An outer shelf at 60 leaves it clear, and the shelf is underwater at −20 so
there is nothing for the hull to collide with. The crew stands on the island and looks at their moored boat,
which is the point of the boarding grace.

### Painting

| Band | Material | Why |
|---|---|---|
| Above +10 | `Grass` | the flat top where trees and pads go |
| −2 … +10 | `Sand` | the beach face and upper beach |
| Below −2 | `Sand` | continuous with the existing seabed, which is already Sand |
| Scattered on the face | `Rock` | a few angular patches so the shoreline is not uniform |

Materials are chosen by the voxel's own height, so the paint follows the shape automatically instead of being
a second thing to keep in sync.

### Bounding the edit

Mandatory even here, where nothing nearby is precious:

```lua
local MAX_R = Ro            -- no column outside the outer shelf radius is touched
local MAX_Y = PLATEAU + 4   -- never write above the plateau
local MIN_Y = -60           -- never write below the known seabed
```

The failure the rule exists for — a blend profile sampled far away cutting through a hillside — cannot happen
on a flat seabed. The guards go in anyway, because the next island may not be on a flat seabed.

---

## Implementation steps

1. **Move the four instances** (two `SpawnLocation`s, the dock, the deck) and record their old positions in
   the summary, so any of it can be put back.
2. **Fill the lobby island** — one `WriteVoxels` over a checked region, profile + noise + material by height.
3. **Verify in a separate call** (never in the same script as the write — a re-read can return pre-write
   data): plateau flatness, the height at several radii, and a **count of voxels whose surface lands in
   0…+8**, which must be near zero. Report the violations with coordinates rather than a pass/fail claim.
4. **Screenshot** the lobby island from a boat's-eye view and from above. Restore `CameraType = Custom`
   afterwards — `screen_capture` with `camera_position` leaves the camera `Scriptable` and locks navigation.
5. **Repeat 2–4 for the game island.**
6. **Save both places** deliberately, and note that nothing in the MCP can inspect a saved `.rbxl`, so the
   save is the first suspect if anything is missing later.
7. **Register** `GB-GAME-START-ISLAND` in the asset registry and the graybox audit. The lobby island is *not*
   a graybox — it is the real thing this job delivers.
8. **Update** `Planned/0002` to unblock it, and job 023's plan to note its start island now exists.

---

## What I need from you

- [ ] **Go-ahead**, and a look at the dimensions above — a 220-stud flat top for the hub is my guess at
      "room for trees and several party pads", and it is much cheaper to change now than after the fill.
- [ ] **Confirm the instance moves** (dock to the shore, deck parked aside, spawns onto the plateaus). I will
      not delete anything.

---

## Verification

- [ ] Plateau is **flat** — sample a grid across it; every surface the same height, no noise
- [ ] **Shelf artifact**: count surfaces landing in 0…+8. Near zero, with any offenders listed by coordinate
- [ ] Heights match the profile at each band radius, remembering **surface = top solid voxel centre + 2**
- [ ] The island is **connected to nothing** — no floating voxels above the plateau, no detached bars offshore
- [ ] The launch at (70, 0, 0) still floats level and has not collided with the new shelf — re-run
      `Vessel → Buoyancy stability check`
- [ ] Screenshots from sea level and above, both places, camera restored to `Custom`
- [ ] Spawning works in the lobby (its `CharacterAutoLoads` is true, so this is immediately visible)
- [ ] Graybox audit clean in both places
