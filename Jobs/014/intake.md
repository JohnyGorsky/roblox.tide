# Job #014: Make the game place enterable for a dev: spawn-on-demand and an observation deck

**Project**: `roblox.tide`
**Created**: 2026-08-20 13:23:01
**Status**: Requirements Gathering (intake)

## Requirements / goal

Pressing Play in the game place does nothing: CharacterAutoLoads is false by design (job 004, decision 0014 territory - the expedition owns death and nothing respawns unasked), so no character loads, there is no camera subject, and the view is static. Even if a character did load, the SpawnLocation floats at Y=8 over open water with nothing under it, so it would drop into the sea. Rather than fight the baseline by turning autoload back on - which would be real drift on a deliberate decision, and which the settings audit would correctly flag - add a deliberate opt-in: an admin tool that calls LoadCharacter on request. That respects the rule (nothing respawns unasked) while letting a developer get a body when they actually want one. Plus a temporary observation deck to stand on, built as a registered graybox representing the starter vessel's deck, since standing on the boat is what will eventually replace it.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
