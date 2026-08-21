# Job #024: Sculpt and paint two islands: the lobby hub and the game start island

**Project**: `roblox.tide`
**Created**: 2026-08-21 21:34:02
**Status**: Requirements Gathering (intake)

## Requirements / goal

The user asked for both islands to be sculpted and painted by Claude rather than hand-built (2026-08-21), overriding GROUND-RULES line 40 which assigns hand-sculpted islands to the human. Noted and proceeding: a radial island profile with noise is COMPUTED geometry, which is squarely the procedural terrain work the roblox-terrain skill puts in scope - what Claude cannot do is judge whether the result looks good, so expect the user to sculpt on top.

Both islands, both places:

1. LOBBY HUB ISLAND. 'Normal type island with shores and middle flat where we will plant trees and party pads.' The flat middle is a functional requirement, not a look: party pads (Planned 0002) get placed on it in the editor, so it must be genuinely level and large enough for several pads plus trees.

2. GAME START ISLAND. Smaller. Somewhere the crew stands for the five-minute boarding grace (decision 0024) with a line of sight to the moored launch. Registered as GB-GAME-START-ISLAND in job 023's plan; this job supplies it.

Both need: shores meeting water, an underwater shelf, and painted materials (sand at the shore, grass on top) rather than one flat material.

Hard constraints from the roblox-terrain skill, all of which have burned this project before:
- Voxels are 4x4x4 and a voxel's world Y is its CENTRE, so surface = top solid voxel centre + 2. Off-by-2 here is the most common analysis error.
- ReadVoxels/WriteVoxels THROW above 4,194,304 voxels, and a pcall whose result is ignored turns that into a silent no-op that reports success. Slab the regions and check every pcall.
- THE SHELF ARTIFACT: no land surface may sit between the water level and about WATER_Y + 8, or it renders as hole-riddled sheets. A gentle beach ramp through the waterline produces the artifact along its whole length, so the shore must cross that band quickly.
- Prefer ReadVoxelChannels/WriteVoxelChannels for anything where land and water share voxels.
- BOUND THE EDIT: state the maximum extent and make the code unable to exceed it. Job 071 in the Jungle repo flattened a 400-stud plateau because a blend profile had no MAX_Y guard.
- Verify in a SEPARATE execute_luau call - re-reading right after a write can return pre-write data, which has already produced a repair that reported success and changed nothing.
- Size probe regions to the terrain's true range: a probe with a Y ceiling of 40 reports every taller column as exactly 40.
- Terrain is a saved-place change and nothing in the MCP can inspect a saved .rbxl. Fill, read voxels back, screenshot, then save deliberately.
- screen_capture with camera_position leaves the camera Scriptable and locks the user's navigation; restore CameraType = Custom afterwards.

Out of scope: trees and props (the user plants those), the party pads themselves (Planned 0002), and any change to the ocean corridor (that is job 023, decision 0025).

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
