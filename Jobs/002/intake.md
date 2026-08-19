# Job #002: Record the two-place architecture (lobby + game)

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:26:50
**Status**: Requirements Gathering (intake)

## Requirements / goal

The Roblox experience exists and has two places: 'The Last Tide' (91870148721134, start place = lobby) and 'The Last Tide Game' (100885379547959, game place). Capture this as project knowledge and restructure the sync roots accordingly. (1) Replace the single studio/ root with studio_lobby/ and studio_game/, each with its own Rojo project file. (2) Add decision record 0013 for WHY the experience is split. (3) Add docs/systems/places/README.md for HOW it works - place ids, what lives where, the lobby-to-game teleport, what state crosses the boundary, and the never-edit-across-places rule. (4) Add a Places section to the tide-project skill. (5) Add a place qualifier to every asset in assets/registry/assets.yaml, since bare service paths are now ambiguous. Index lines for the two new docs are included so they are not orphaned.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
