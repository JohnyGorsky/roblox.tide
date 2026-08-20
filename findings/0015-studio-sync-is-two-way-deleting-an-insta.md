# FINDING 0015: Studio Sync is TWO-WAY: deleting an instance via execute_luau deleted the source file on disk

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-20 15:53:56

**Symptom:** While cleaning up test artefacts I ran a name-matched delete across several containers, and the pattern 'inst.Name == StormVFX' matched ReplicatedStorage.StormVFX - the real module, not a test clone. It destroyed the instance AND, because Studio Sync is two-way, the file studio_game/ReplicatedStorage/StormVFX.luau was deleted from disk. Recovered with git checkout HEAD, and only because the user had committed mid-session; without that commit an entire module of work would have been gone with no undo, since the deletion happened outside Studio's undo stack. Three rules from this. (1) Deleting an instance in a synced place is a DESTRUCTIVE FILESYSTEM OPERATION, not a scene edit - treat it with the care of rm, not of a scene tidy. (2) Never clean up by matching names across containers. Scope cleanup to the specific container the artefacts were created in (Workspace, SoundService), never ReplicatedStorage/ServerStorage/ServerScriptService where the real code lives, and match against an explicit allowlist of names this session created rather than a pattern. (3) Prefer parenting test artefacts to a single uniquely-named folder so cleanup is one delete of a known container. Fixed the cleanup to use an explicit TEST_NAMES allowlist restricted to Workspace and SoundService.
**Where:** MCP execute_luau cleanup + Studio Sync
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
