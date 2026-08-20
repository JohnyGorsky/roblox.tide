# Final Summary — Job #007

**Project**: `roblox.tide`
**Completed**: 2026-08-20 00:02:07
**Status**: ✅ Completed

## What was implemented

The game place now has an ocean, and four experiments established why it does not yet look right. BUILT: 6144x6144 studs of terrain water at Y=0 over a sand seabed at -64..-56, filled as 36 non-overlapping FillRegion tile pairs in 0.68 seconds - so ocean size is not a performance constraint. Verified by voxel read-back at three locations (sand -62..-58 occupancy 1.0, water -54..-2 occupancy 1.0, air above, nothing past x=3072) and a surface raycast returning Water at Y=0.0. The default Baseplate was removed because it would have stood in the sea, and the SpawnLocation was raised above the waterline. SeaStates.luau defines Dead Calm, Light Swell, Choppy, Storm and The Wall, each driving terrain water plus fog plus ambient from one row, with a lerp so weather arrives instead of snapping, and a wave block that is deliberately not read by the engine - it is the contract our own wave field will honour, so the visual swell and the physical swell cannot drift apart. FOUR FINDINGS, each from an experiment rather than an assumption. (1) The sky dominates the sea's colour and it is a hard blocker: the default skybox rendered the sea as holiday blue regardless of water properties, and four attempts to fix it in the air all failed - grey Atmosphere at Haze 3.0 improved colour but killed every trace of wave detail, Atmosphere pushed to Density 0.98/Haze 4.5 left the sky still bright blue, a dark FogColor darkened the water but not the sky, and removing the skybox gave the cleanest horizon but still a clear-day sky. Neither Fog nor Atmosphere can make a clear-day sky overcast, so the art direction is unreachable until real overcast sky assets exist - now registered as ASSET-SKY-OVERCAST and promoted from polish item to the highest-value asset in group 01 (finding 0006). (2) Fog darkens the world but NOT the sky, which is what produced a hard black horizon line; fog therefore controls distance while sky and Atmosphere control colour. (3) Wave legibility comes from WaterReflectance catching sky contrast, so darkening the sea by starving reflectance produces a featureless navy plane - keep reflectance around 0.3-0.4 and darken the sky instead. (4) fogEnd must stay inside the water or the ocean visibly stops; encoded as SeaStates.OCEAN_HALF_EXTENT with a validateFogWithinOcean() check, and Dead Calm's requested fogEnd of 4200 was capped to 2900 for exactly that reason. Left the place in the best default found (Light Swell, procedural sky, reflectance 0.36) with the original tropical Sky parked in ServerStorage as Sky_DefaultTropical_PARKED so it can be restored by one drag, and released CameraType back to Custom - screen_capture had left it Fixed, which would have locked viewport navigation.

### Files changed

_`SeaStates.luau` is real game code and synced into the game place's `ReplicatedStorage`.
The terrain and lighting changes live in the `.rbxl` — **save the place to keep them.**_

- `studio_game/ReplicatedStorage/SeaStates.luau`
- `docs/features/0011-sea-states/feature.md`
- `docs/build/01-sea.md`
- `assets/registry/assets.yaml`

### ⚠️ For you, in the morning

1. **Save the game place** — the ocean, the removed baseplate and the lighting are unsaved Edit-mode
   changes. Closing Studio without saving loses the sea.
2. **Look at the four screenshots** in the conversation and tell me which reading is closest to what you
   want. The water shape and horizon work; the colour does not, and I know why.
3. **The one thing that needs sourcing: overcast sky assets.** This is a proven blocker, not a preference —
   see finding 0006. Creator Store is the fast route; I can search and present candidates for approval.
4. If you want the original tropical sky back, drag `Sky_DefaultTropical_PARKED` from `ServerStorage` into
   `Lighting`.

### How to switch states yourself

```lua
local SeaStates = require(game.ReplicatedStorage.SeaStates)
SeaStates.apply(SeaStates.Storm)      -- or DeadCalm / LightSwell / Choppy / TheWall
```

## Verification

- [x] Voxel read-back at centre, edge and outside the ocean — sand, water and air exactly as intended
- [x] Surface raycast returns `Water` at `Y = 0.0`
- [x] Ocean edge measured at exactly `x = 3072`; nothing at 3100
- [x] `validateFogWithinOcean()` passes for all five states
- [x] `SeaStates` confirmed synced into the place and requireable
- [x] Four screenshots captured across four lighting treatments
- [x] `CameraType` restored to `Custom` (screen_capture had left it `Fixed`)
- [ ] Water look approved — **awaiting the user's eye**
- [ ] Cold palette — **blocked on overcast sky assets (finding 0006)**
- [ ] Settings persisted — **requires saving the place**
