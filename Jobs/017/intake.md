# Job #017: Storm core: position, intensity, and the server tick

**Project**: `roblox.tide`
**Created**: 2026-08-20 14:28:29
**Status**: Requirements Gathering (intake)

## Requirements / goal

Group 07 job 2, feature GAME-0003. Build the advancing front per decision 0019: a timer-driven advance with northward progress buying distance back, so looting is spent distance and fuel becomes the real currency. Intensity levels 0-4 map onto the five sea states, whose severity then drives the look via decision 0018 - the storm never writes lighting itself, it only sets intensity, which keeps the flow one-directional with no loops. Also build the server tick that job 016 left undone: compose() needs calling about once a second or the look only updates when something happens to call it. Includes the shelter rate modifier (~30%, never zero), radar rendering the front as a contact with a readable distance, and temporary HUD threshold alerts rather than a permanent readout. Two tunables to expose clearly - base advance rate and studs-gained-per-stud-travelled - because their ratio decides how much looting an expedition affords and is the single most important balance figure in the game. Note the deliberate consequence: no fuel means no progress means the front closes at full rate, so fuel exhaustion is a death sentence by construction and fuel scarcity must be tuned together with the storm rather than separately.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
