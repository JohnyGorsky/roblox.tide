# Implementation Plan — Job #010

**Project**: `roblox.tide`
**Created**: 2026-08-20 10:29:37
**Status**: Planning (awaiting go-ahead)

## Analysis

The lobby was still a bare baseplate while the game place already had its ocean. Two constraints shaped the work. First, the lobby has CharacterAutoLoads=true, so deleting its baseplate without providing ground would drop every joining player into the sea - hence a temporary dock, built deliberately as a registered graybox so it cannot be forgotten, which also exercises the graybox register for the first time (the one verification item left open from job 005). Second, the lobby had FogEnd 5000 from the job 004 baseline, and any water smaller than that would show its edge - the same rule job 007 established for the game place, now applying to a second place, so it is a general rule rather than a one-off. The harbour is deliberately NOT the open sea: shallower seabed, greener water, higher transparency so the bottom is visible, and a much smaller wave size, because docs/systems/places says the lobby should read as a sheltered bay.

## Implementation steps

1. Remove the lobby baseplate
2. Fill 4096x4096 of harbour water over a sand seabed at -48..-40, chunked and non-overlapping
3. Create GB_SpawnDock, tag it Graybox, set GrayboxId, and move the SpawnLocation onto it
4. Set harbour water: greener, calmer, more transparent than the open sea
5. Set fog inside the water extent
6. Verify by voxel read-back and screenshot, and run the graybox audit
7. Register the dock, its eventual replacement and the harbour water in assets.yaml, and add the dock to the audit script
8. Release the camera afterwards

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
