---
id: GAME-0005
name: Curated Island Library
area: islands
status: IN_PROGRESS
priority: P0
last_verified: 2026-08-22
---

# Curated Island Library

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [x] **Approved template format** — `ReplicatedStorage/IslandTemplates.luau`. Data only: band radii and
      heights, radius noise, paint rules, and the marker layout. Island #2 is a table entry, not a new script
- [x] **Terrain + props strategy** — decision 0016's pipeline, end to end and with nobody in the loop:
      sculpt in Edit → verify → `CopyRegion` → `ServerStorage/Islands/Cay/{Terrain, Props, Meta}` → paste at
      boot. The saved place carries the *template*, not the islands. Props are graybox
- [x] **Gameplay markers** — 15 per island across the manifest's five zones, tagged `IslandMarker`, polar so
      they scale with the template. The POI is also a `RadarContact`
- [ ] **Runtime selection** — the paste is fully positional and 4 islands are placed from one template, but
      the positions and the count are a fixed list. Per-run selection and more than one template are next
- [ ] **Cleanup/reuse** — islands are pasted once at boot and never removed. Nothing reuses or unloads a
      region yet, which is only a problem once there are 10–20 of them (decision 0024)
- [x] **At least one authored island** — the `Cay`, 350 studs across, verified and approved by eye

## Not started, and named here so it is not mistaken for done

The design intent in [systems/islands](../../systems/islands/README.md) also calls for **encounter
variants** — the same terrain reused as pirates / abandoned / trader / drowned / storm-damaged / rare-loot /
night. None of that exists. Nor do difficulty-stage tags or encounter weights. That is the largest
outstanding part of this feature, and it depends on groups 03 and 05 having anything to vary.

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.

## Measured (job 027)

| Check | Result |
|---|---|
Plateau flatness | one distinct height, **Y=18**, across 952 columns |
Ground check per island | **13/13 probes**, worst error **0.0 studs** against a 0.6 tolerance |
Shelf artifact off the landing arc | **0 columns** (was 335 with a continuous 60° face) |
Shelf artifact on the landing arc | 38 columns — accepted, one beach, jetty art will cover it |
Water above dry land | **0 voxels** over 3,382 dry columns, on all four islands |
Holes punched in the ocean | **0** |
Paste fidelity | all four islands byte-identical in every counted metric, which also proves cell alignment |
Cliff slope | **72°**, walkable (Humanoid `MaxSlopeAngle` defaults to 89) |
Markers seated | **15/15** per island, 0 with no ground |
Radar | 4 islands as `land` contacts; Anvil Cay stays an amber circle for the whole centreline run |
