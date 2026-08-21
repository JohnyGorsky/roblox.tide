# 0025 — The ocean is a corridor grown north, not a bigger square

Status: Accepted

Answers [finding 0018](../../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md), open and marked high
since 2026-08-20, which [decision 0024](0024-expedition-shape-and-pacing.md) promoted to a blocker.

## Decision

**Grow the ocean north into a corridor.** Roughly:

```
X:  ±3,072   unchanged  — east/west stays as it is
Z:  -1,000 → +12,000    — 13,000 studs of northing to voyage through
```

`SeaStates.OCEAN_HALF_EXTENT` becomes **two extents**, X and Z, rather than one square bound.

East–west stays narrow on purpose: decision [0002](0002-horizontal-world-wrap.md) already says the ocean
**wraps left↔right**. Width is that decision's job, not this one's. Until the wrap exists, ±3,072 is enough
for a crew heading broadly north.

## Why, and why not the alternatives

Decision 0024 needs **19,800 studs of travel** for a fifty-minute run. The patch is 6,144 across. So
something had to change.

**Recentring the world on the vessel** was the recommendation and was rejected. It is genuinely unbounded and
the buoyancy risk turned out to be solvable in one line — `WaveField.HeightAt` sampling in the shifted frame
rather than absolute XZ. But it touches the most safety-critical module in the project, and every island, POI
and spawn afterwards has to respect a moving origin forever. That is a permanent tax on all future content
for a problem a corridor solves outright.

**Fencing it in fiction** was rejected as the finding predicted: 19,800 studs of travel inside 6,144 means the
crew circles a pond for fifty minutes.

### Growing is far cheaper than first estimated

The first estimate said ~10× the terrain, and that was **wrong** — it assumed a larger *square*. The voyage is
directional, so only Z needs to grow:

| | Current | Corridor | |
|---|---|---|---|
| Water area | 6,144 × 6,144 = 37.7M | 6,144 × 13,000 = 79.9M | **2.1×** |
| Fill time | 36 tiles, 0.68 s (job 007) | ~76 tiles | ~1.4 s |
| `fogEnd` ceiling | 2,900 | **2,900, unchanged** | no draw-distance cost |

That last row is the one that matters. The hard rule from job 007 is `fogEnd` < the distance to the water's
edge, or the sea visibly stops. With east–west unchanged the **nearest** edge is still 3,072, so the fog and
the whole horizon treatment carry over untouched. Growing a square would have forced the view distance up with
it, and that is where the real cost would have been.

## Consequences

- **`OCEAN_HALF_EXTENT` becomes two numbers.** It is read in five places across `SeaStates`, `WaveField`,
  `DayNight` and `AdminTools` (plus the dead `P2`). `insideOcean` and `validateFogWithinOcean` are the two
  that carry meaning; the rest are diagnostics.
- 🔴 **The Z extent must cover the entire voyage.** `WaveField.HeightAt` returns flat water outside the
  patch, so a hull that reaches the end of the corridor stops floating on waves at all — the failure looks
  like the wave field breaking rather than like running out of world.
- **The finale sits inside the corridor**, around northing 11,000, with margin to the edge. The placeholder
  2,400 target in job 023 becomes real once this lands.
- **The southern margin is deliberate.** −1,000 gives the crew somewhere to be swept while the storm is behind
  them, so being pushed south is not instantly being pushed out of the world.
- **This does not make the sea infinite**, and the finding stays worth re-reading before any vessel faster
  than the launch ships. It makes the sea big enough for the run decision 0024 specifies, which is a different
  claim. A crew that deliberately drives east for ten minutes still finds an edge until decision 0002's wrap
  exists.
- Terrain lives in the place file, not in source, so growing it is a **saved-place change** — and per the
  handoff's note, nothing in the MCP can inspect a saved `.rbxl`. Grow it, read the voxels back, screenshot
  the horizon, and save deliberately.
