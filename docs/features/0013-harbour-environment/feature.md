---
id: GAME-0013
name: Harbour Environment
area: lobby
status: IN_PROGRESS
priority: P1
depends_on: []
assets: [ASSET-HARBOUR-WATER, GB-LOBBY-DOCK, ASSET-LOBBY-HARBOUR-DOCK]
last_verified: null
---

# Harbour Environment

## Goal

The lobby's physical space: a sheltered harbour that reads as safe and calm, and visibly not the open sea
players sail into.

## Player value

The harbour is where progress becomes visible — the fleet at its berths, the Shipyard, a ship under
construction. It is also the emotional contrast that makes the expedition feel dangerous.

## Requirements

- [x] Harbour water: 4096 × 4096, sand seabed −48…−40
- [x] Calm, shallow, greener and more transparent than the open sea — it must not read as the ocean
- [x] Fog inside the water extent (`FogEnd 1900` < half-extent 2048)
- [x] Default baseplate removed
- [x] A spawn that is not in the water — currently `GB_SpawnDock`, a registered graybox
- [ ] Replace the graybox dock with the real jetty (`ASSET-LOBBY-HARBOUR-DOCK`)
- [ ] Harbour greybox layout: berths, Shipyard, dry dock, warehouse, crew quarters, departure gate
- [ ] Objects hand-placed in the editor and found by name by scripts — not generated at runtime
- [ ] Harbour art pass once the layout is proven

## Out of scope

The Shipyard's progression logic (GAME-0010), party and departure flow, fleet display logic. This feature
owns the *place*, not what happens in it.

## Roblox touchpoints

`Terrain`, `Lighting`, `Workspace`. `StreamingEnabled` is **off** here, so everything is always loaded —
keep the footprint honest.

## Assets

`ASSET-HARBOUR-WATER` (implemented), `GB-LOBBY-DOCK` (graybox in place),
`ASSET-LOBBY-HARBOUR-DOCK` (idea). Manifest group [08](../../build/08-lobby-shipyard.md).

## Acceptance criteria

- [x] No visible edge to the water
- [x] Reads as a sheltered bay, not open ocean
- [ ] A player can walk from spawn to every harbour function without swimming
- [ ] Layout approved before art is commissioned

## Verification

Water and dock verified by voxel read-back and screenshot in job 010; graybox audit reports 1 tracked,
0 untracked. Layout and look still need judgement.
