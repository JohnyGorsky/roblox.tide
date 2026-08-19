# FINDING 0000: Stray empty folders at the wrong level in studio_game/

**Project:** `roblox.tide`
**Status:** fixed (2026-08-19) — NOT A DEFECT - my diagnosis was backwards. MCP sync probes (job 003) proved Studio Sync uses a FLAT layout: studio_game/StarterPlayerScripts/ syncs to StarterPlayer.StarterPlayerScripts, while the nested studio_game/StarterPlayer/StarterPlayerScripts/ never syncs at all. So the two folders I called stray were created by Studio Sync itself and are the CANONICAL ones; the nested pair I created in job 002 were the dead ones. Job 003 deleted the nested tree and flattened both sync roots to match.
**Severity:** med
**Created:** 2026-08-19 22:30:21

**Symptom:** studio_game/StarterCharacterScripts/ and studio_game/StarterPlayerScripts/ exist as empty folders directly under studio_game/, duplicating the correct studio_game/StarterPlayer/StarterCharacterScripts/ and .../StarterPlayerScripts/. Created 2026-08-19 22:27, after the job 002 restructure - not created by the restructure script. Git does not track empty folders so they are invisible in git status. They are harmless but will confuse anyone reading the tree, and Rojo maps only the nested paths. Leaving them in place pending confirmation they were not intentional.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
