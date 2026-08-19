# FINDING 0002: Lobby place is not connected to Studio Sync

**Project:** `roblox.tide`
**Status:** fixed (2026-08-19) — FIXED Studio-side by the user. Re-probed 2026-08-19: all six folders in studio_lobby/ now sync into The Last Tide (91870148721134) - ReplicatedFirst, ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayerScripts, StarterCharacterScripts - and the lobby place behaves identically to the game place, including the flat StarterPlayerScripts mapping. Both places verified clean of probe residue afterwards.
**Severity:** med
**Created:** 2026-08-19 22:43:52

**Symptom:** A probe written to studio_lobby/ReplicatedStorage/_SyncProbe.luau never appeared in The Last Tide (91870148721134), while the identical probe written to studio_game/ReplicatedStorage/ arrived in The Last Tide Game within seconds. Both places are open in Studio and both respond to MCP, so this is sync configuration, not connectivity. Blocks all lobby work - Shipyard, fleet, parts inventory, loadout, crew roster. Fix: connect Studio Sync for the lobby place pointing at studio_lobby/, then re-run the probe to confirm, and confirm which services it covers.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
