# TODO 0007: PlayerRemoving is connected inside buildVessel, so a rebuild leaks a connection

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-21 09:18:26

VesselServer.buildVessel() connects Players.PlayerRemoving to release the helm. buildVessel is also called by recoverIfLost() and by _G.TideVessel.rebuild(), so every rebuild adds another live connection to the same handler. Harmless in effect (the handler is idempotent - it clears a driver that is already cleared) but it is an unbounded leak on a path that fires after a physics divergence, i.e. exactly when things are already going wrong.

Fix: move the connection to module scope alongside the Players.PlayerAdded connection at the bottom of the file. One line moved. Left alone in job 022 to keep that job's diff to storm damage - noticed while wiring the loss handler, which touches the same helm-release logic.
