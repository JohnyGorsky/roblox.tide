---
id: GAME-0011
name: Sea & Sea States
area: sea
status: IN_PROGRESS
priority: P0
depends_on: []
assets: []
last_verified: null
---

# Sea & Sea States

## Goal

Give the game place a real ocean, and make its mood switchable between named sea states so the look can
be tuned by eye rather than argued about. Visual only — no wave physics in this feature.

## Player value

The sea is the thing the player looks at for the entire run. It has to read as a cold, deep, dangerous
ocean rather than a swimming pool, and it has to change convincingly when the weather turns — otherwise
the storm carries no threat.

## Requirements

- [x] Terrain ocean in the game place: water surface at Y=0 over a sand seabed
- [x] Chunked terrain writes that stay under the 4,194,304-voxel limit
- [x] No land surface between the water level and `WATER_Y + 8` (shelf artifact)
- [x] `SeaStates` data module defining the five states, one table driving water + fog + ambient together
- [x] A way to apply a state live for judging
- [ ] The user picks which states read correctly and which need tuning
- [x] Ocean sized so fog closes before the water ends (6144 studs; `OCEAN_HALF_EXTENT` + validator)
- [ ] **BLOCKED: overcast sky assets.** Proven in job 007 that neither Fog nor Atmosphere can make
      Roblox's clear-day sky overcast, so the cold palette cannot be reached without them
      (`ASSET-SKY-OVERCAST`, finding 0006)
- [ ] Horizon treatment beyond fog (cloud bank, silhouettes) — needs art, deferred
- [ ] **`atmosphere` block per state** — Density, Haze, Glare, Color, Decay. Currently `SeaStates` drives
      only fog, but job 007 proved Atmosphere and the sky dominate the sea's apparent colour, so without
      this the states cannot actually change how the water reads
- [ ] Transient weather response beyond the five states: a rain squall or lightning flash briefly altering
      the water read, rather than colour only ever stepping between states
- [ ] Wave-height sampler so physics can agree with the visuals — GAME-0014

## Out of scope

Wave physics and buoyancy (boat controller, GAME-0001), the storm's advance and lightning (GAME-0003),
day/night lighting curves (GAME-0004), world wrapping. This feature only makes the water look right and
switch cleanly.

## Roblox touchpoints

`Terrain` (`WriteVoxelChannels`, `ReadVoxelChannels`, water properties), `Lighting` fog/ambient,
`ReplicatedStorage.SeaStates`.

## Assets

None yet. The horizon work (sky sets per sea stage, distant cloud bank, far silhouettes) is listed in
[the manifest](../../build/01-sea.md) and needs registry entries when started.

## Acceptance criteria

- [ ] Water reads as cold open ocean, not a pool, at the default state
- [ ] The five states are visibly distinct at a glance
- [ ] No visible edge where the ocean ends — fog closes vision before geometry does
- [ ] Switching states does not require a rejoin
- [ ] Verified by voxel read-back **and** screenshot, per the terrain discipline

## Verification

Never mark VERIFIED without a real Studio/playtest check.

Done in job 007 (2026-08-19):
- Ocean verified by voxel read-back: sand −62…−58 occupancy 1.0, water −54…−2 occupancy 1.0, air above,
  nothing beyond x=3072. Raycast confirms the surface at Y=0.0.
- `validateFogWithinOcean()` passes for all five states.
- Four screenshots captured across four lighting treatments; findings written up in
  [docs/build/01-sea.md](../../build/01-sea.md).
- Camera released back to `Custom` (screen_capture had left it `Fixed`).

Still needed for VERIFIED: the user's judgement on the water look, and the overcast sky assets that the
palette depends on.
