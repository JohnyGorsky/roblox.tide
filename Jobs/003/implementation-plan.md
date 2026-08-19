# Implementation Plan — Job #003

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:44:16
**Status**: Planning (awaiting go-ahead)

## Analysis

Job 002 built the sync roots from convention because no place existed. The places now exist, are open in Studio and reachable over MCP, so the layout was tested rather than assumed - the first exercise of the new GROUND-RULES rule that Claude runs the tests. Method: write probe files to disk, then query each place through execute_luau to see what arrived and as what class. Results: the layout is FLAT (studio_game/StarterPlayerScripts/ reaches StarterPlayer.StarterPlayerScripts; the nested studio_game/StarterPlayer/StarterPlayerScripts/ never arrives), five folders sync (ReplicatedFirst, ReplicatedStorage, ServerStorage, StarterPlayerScripts, StarterCharacterScripts), four do not (ServerScriptService, StarterGui, StarterPack, Workspace), .luau becomes a ModuleScript, .client.luau becomes a Script with RunContext=Client, .module.luau is not a recognised suffix and yields a ModuleScript literally named Name.module, deletions propagate cleanly, and the lobby place receives nothing at all. Two blockers are Studio-side and not fixable from disk (findings 0001, 0002).

## Implementation steps

1. Delete the dead nested studio_*/StarterPlayer/ trees and flatten both roots to the verified shape
2. Rewrite .jobconfig.json from observation - move ServerScriptService to non_synced_paths, drop the unverified guesses
3. Flatten the StarterPlayer mapping in lobby.project.json and game.project.json to point at the flat folders
4. Add a 'Studio Sync - verified behavior' section to docs/systems/places/README.md: flat layout, per-folder sync table, suffix-to-class table, lobby not connected
5. Add the flat-layout rule, the suffix rules and the two known-broken items to the tide-project skill
6. Resolve finding 0000 with the corrected diagnosis; log findings 0001 and 0002
7. Remove all probe residue and verify via MCP that the place is clean

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
