# Implementation Plan — Job #007

**Project**: `roblox.tide`
**Created**: 2026-08-20 00:02:07
**Status**: Planning (awaiting go-ahead)

## Analysis

The game place was a bare baseplate, so the sea had to be built before anything about it could be judged. Approach agreed via wizard: visual only, no wave physics. Consulted roblox-terrain first (voxel grid must be resolution 4; Read/WriteVoxels throw above 4,194,304 voxels; overlapping writes overwrite so never interleave; no land surface between the water level and WATER_Y+8 or it renders as hole-riddled sheets; verify by read-back AND screenshot) and roblox-physics for the buoyancy context that shapes the wave-field contract. Used FillRegion rather than WriteVoxels because two non-overlapping regions - sand below, water above - need no per-voxel authoring, which made the fill three orders of magnitude cheaper. The five sea states live in one data module so the visual numbers and the future wave-field numbers cannot drift apart.

## Implementation steps

1. Clear the default baseplate and raise the SpawnLocation above the waterline
2. Fill sand -64..-56 then water -56..0, chunked, non-overlapping
3. Verify by voxel read-back at centre, edge and outside, plus a surface raycast
4. Write SeaStates.luau: five states, each driving water + fog + ambient, plus lerp for arriving weather and the wave contract for physics
5. Enlarge the ocean until fog closes before the water ends; encode that as a constant and a validator
6. Apply states live and screen-capture them; iterate the lighting treatment by eye
7. Record findings, register blocking assets, release the camera

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
