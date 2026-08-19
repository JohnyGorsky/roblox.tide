# TODO 0000: Confirm studio/ sync paths against the live Studio Explorer

**Project:** `roblox.tide`
**Status:** resolved (2026-08-19) — Superseded by the job 003 probe rounds - the sync paths are no longer provisional. Both places were probed folder by folder over MCP and .jobconfig.json now records observed behavior for all 12 synced paths. The remaining unverified case (StarterGui/StarterPack/Workspace) is tracked as todo 0002.
**Created:** 2026-08-19 22:21:53

The Roblox place for The Last Tide does not exist yet, so .jobconfig.json synced_paths/non_synced_paths were written from the Jungle convention rather than observed. Once the place is created and Studio Sync is connected, check the sync arrows in the Studio Explorer and correct .jobconfig.json. Also decide whether StarterGui/StarterPack/Workspace are needed at all.
