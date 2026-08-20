# Job #007: Build the sea: ocean terrain and sea-state presets

**Project**: `roblox.tide`
**Created**: 2026-08-19 23:51:40
**Status**: Requirements Gathering (intake)

## Requirements / goal

First sea job from manifest group 01. The game place is a bare baseplate, so there is no water to judge - build one, then make it switchable between named sea states so the look can be tuned by eye. Scope (agreed): visual only, no wave physics. (1) Replace the baseplate with real ocean: terrain water surface at Y=0 over a sand seabed, chunked writes under the 4,194,304-voxel limit, using the channel API, keeping all land clear of the waterline to avoid the shelf artifact. (2) SeaStates data module in studio_game/ReplicatedStorage defining Dead Calm, Light Swell, Choppy, Storm and The Wall - each setting terrain water properties plus fog and ambient together, so visual and later wave-field values come from one table. (3) Apply each state live and screen-capture it for the user to judge in the morning. (4) Record the infinite-ocean techniques that need no new assets - horizon fog band tuned per state - and note which ones need art. Verify by voxel read-back AND screenshot per the terrain discipline, and reset CameraType to Custom afterwards so the user's navigation is not left locked.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
