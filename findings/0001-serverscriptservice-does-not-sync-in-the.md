# FINDING 0001: ServerScriptService does not sync in the game place

**Project:** `roblox.tide`
**Status:** fixed (2026-08-19) — FIXED Studio-side by the user. Re-probed 2026-08-19: studio_game/ServerScriptService/_Scope2_ServerScriptService.luau arrived at ServerScriptService, and so did the lobby's. Also confirmed while there: .server.luau gives a Script with RunContext=Server and .client.luau gives RunContext=Client even inside ServerScriptService, so the suffix - not the folder - decides run context. .jobconfig.json moved both ServerScriptService paths back to synced_paths and docs/systems/places/README.md was corrected.
**Severity:** med
**Created:** 2026-08-19 22:43:52

**Symptom:** Three probes written to studio_game/ServerScriptService/ (_ProbeA.luau, _ProbeB.server.luau, init.server.luau) never appeared in the place, re-checked after a delay. Every other service probe arrived: ReplicatedFirst, ReplicatedStorage, ServerStorage, StarterPlayerScripts, StarterCharacterScripts. This is unexpected - Jungle's .jobconfig.json lists ServerScriptService as auto-synced, and it is where server game logic belongs, so The Last Tide currently has nowhere on disk to put server scripts. Not diagnosable from disk; needs the Studio Sync panel checked for the game place (per-service toggle or scope setting). Blocks any server-side work. Recorded as non_synced in .jobconfig.json and documented in docs/systems/places/README.md until fixed.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
