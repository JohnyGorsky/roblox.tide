# 0016 — Island templates are a TerrainRegion plus a prop Model

Status: Accepted

## Decision

Each curated island (decision [0003](0003-curated-islands.md)) is stored in `ServerStorage` as:

```text
ServerStorage/Islands/<Name>/
  Terrain   TerrainRegion   captured with Terrain:CopyRegion
  Props     Model           rocks, buildings, clutter
  Meta      markers         dock points, loot points, spawns, POI markers, stage tags
```

At runtime the engine pastes the terrain, then props are cloned and seated on the ground it created.

## Why

Islands must keep the **smooth-terrain look**. Beaches, dunes and eroded coastline are most of what makes
a shore read as real, and part-and-mesh islands cannot produce them — a mesh coastline looks built rather
than sculpted, which fights the whole tone.

The alternative of baking every island permanently into the world map was rejected because it fixes island
positions forever, which is directly opposed to the curated recombination the replayability rests on: the
same island appearing somewhere new, with a different variant, is the point.

## Consequences

- **Terrain data is bulky binary content** in the place file. Island count therefore has a real storage
  cost, and that is another reason to keep the library curated rather than large.
- **Paste is asynchronous in effect.** Terrain must exist before anything is seated on it — probe for
  ground, never assume, and validate across the island's whole footprint rather than one raycast. The
  `roblox-terrain` skill records both failures.
- Land must never sit at the waterline (the shelf artifact): a bank starts clear of the water and rises.
- Templates contribute **land only**. The ocean stays global and shared.
- `CopyRegion`/`PasteRegion` take cell coordinates, not studs.
- Manifest group [04](../build/04-islands.md) owns the pipeline, and its first job proves it with one
  island before any others are built.
