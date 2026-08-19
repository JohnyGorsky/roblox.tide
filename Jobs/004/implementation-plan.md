# Implementation Plan — Job #004

**Project**: `roblox.tide`
**Created**: 2026-08-19 23:03:27
**Status**: Planning (awaiting go-ahead)

## Analysis

Both places measured over MCP and both are stock defaults; Studio API access is already enabled in both, so nothing is needed there. Four decisions agreed via wizard: game place 6 players / lobby 20; StreamingEnabled true for game and false for lobby, which creates a hard obligation that the boat controller must set each player's ReplicationFocus to the vessel rather than the character, or crew far from origin will watch the deck stream out; CharacterAutoLoads false in the game place so the expedition owns death and a downed player cannot respawn mid-revive, while the lobby keeps auto-load; and the baseline is owned as a spec table in git plus an MCP-run drift audit. Scope discipline: this job configures ENGINE settings, not art. Lighting and water get conservative starting values explicitly marked provisional and handed to features 0003 (storm) and 0004 (day/night) to own, so this job does not quietly become the visual design pass. Three classes of setting must be separated because they are applied differently: scriptable place properties (Claude writes over MCP, human must SAVE each place for persistence), NotScriptable place properties such as Lighting.Technology and PhysicsSteppingMethod (human clicks in the Properties panel - probing confirmed these are unreadable from Luau), and experience-level settings on the Creator Hub such as playable devices and avatar type (human only). Two settings not covered by the wizard, decided here and open to correction: ScreenOrientation becomes LandscapeSensor because a boat HUD with diegetic instruments needs a wide canvas, and DevTouchMovementMode becomes DynamicThumbstick so the reserved bottom-left touch rect is predictable for all future HUD layout.

## Implementation steps

1. Write docs/systems/places/settings-baseline.md - the spec table for both places, split into scriptable / NotScriptable / experience-level, with a provisional marker on every Lighting and water value and the owning feature named
2. Apply the scriptable half to the game place over MCP: MaxPlayers 6, PreferredPlayers 6, CharacterAutoLoads false, StreamingEnabled true, camera zoom clamp, touch movement mode, orientation, provisional water and fog
3. Apply the scriptable half to the lobby place over MCP: MaxPlayers 20, PreferredPlayers 20, CharacterAutoLoads true, StreamingEnabled false, and the shared player/camera/mobile settings
4. Write tools/audit-place-settings.luau - reads the live place, compares against the baseline table, prints OK / DRIFT / HUMAN-TODO per row so drift can never go unnoticed
5. Run the audit against both places and confirm every applied row reads back correct
6. Record the ReplicationFocus obligation in docs/features/0001-boat-controller/feature.md requirements, since streaming ON is now a decided constraint on that feature
7. Point the places README and the tide-project skill at the baseline doc
8. Hand the human an explicit checklist: save both places, set Lighting.Technology, verify PhysicsSteppingMethod, and set experience-level settings on the Creator Hub with ready-to-use values

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
