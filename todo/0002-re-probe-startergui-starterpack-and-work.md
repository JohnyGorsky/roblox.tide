# TODO 0002: Re-probe StarterGui, StarterPack and Workspace sync status

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-19 22:50:50

Those three were measured as non-synced in the first probe round, before the user fixed the lobby connection and ServerScriptService. They were deliberately not re-probed in round two to avoid pulling place world content (baseplate, spawn, terrain) down onto disk. They are recorded as non_synced in .jobconfig.json on the strength of the earlier round plus the fact that Jungle lists the same three as non-synced. Confirm before relying on it - and decide whether StarterGui content should be authored in Studio only, as Defender and Jungle do.
