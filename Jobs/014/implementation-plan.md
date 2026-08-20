# Implementation Plan — Job #014

**Project**: `roblox.tide`
**Created**: 2026-08-20 13:37:09
**Status**: Planning (awaiting go-ahead)

## Analysis

Play in the game place did nothing: CharacterAutoLoads is false by design so no character loads, no camera subject exists, and the view sits static - and the SpawnLocation floated at Y=8 over open water with nothing beneath it. Two ways to fix it and the choice matters: turning autoload back on would be genuine drift on a deliberate decision (nothing respawns behind the run's back) and the settings audit would rightly flag it, so instead the fix is an explicit opt-in - an admin tool that calls LoadCharacter when asked. That is exactly the contract the rule describes. Paired with a temporary deck to stand on, built as a registered graybox representing the starter vessel, because standing on the launch's deck is what replaces it.

## Implementation steps

1. Add spawnMe and despawnMe admin tools, scope local
2. Create GB_ObservationDeck with rails, move the SpawnLocation onto it
3. Register GB-GAME-DECK in assets.yaml and the audit script
4. Run the graybox audit to confirm it is tracked, not untracked
5. Also close todo 0004 in the same pass: give SeaStates an atmosphere block so switching a state moves the air, not just the water

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
