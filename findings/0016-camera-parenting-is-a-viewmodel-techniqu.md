# FINDING 0016: Camera-parenting is a viewmodel technique; a distant world-scale object rendered from the Camera did not show at all

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-20 15:53:56

**Symptom:** The cloud wall's emitter part was parented to workspace.CurrentCamera at ~1000 studs, copying the pattern StormVFX uses for rain. That pattern is correct for rain because rain sits a few tens of studs from the lens - it is a VIEWMODEL technique. Applied to a kilometre-distant, world-scale object it produced nothing the user could see, even after the fog-occlusion placement bug (finding 0014) was fixed and every reported value - emitter enabled, rate, size, colour, position, occlusion - read correct. The deeper mistake was betting an important silhouette entirely on one uncertain rendering mechanism. Rewritten as GEOMETRY FIRST: nine anchored slabs in Workspace forming a 200-degree arc, which are guaranteed to render, with particles demoted to churn on the top edge only so the silhouette is ragged rather than a clean rectangle. If the particles fail for any reason the wall is still there. Two supporting notes: Part.Size silently CLAMPS AT 2048 studs (asking 3000 returns 2048), so a horizon-spanning wall must be several parts; and client-created instances in Workspace are not replicated, so building world geometry on the client is safe. Also learned that a narrow wall is indistinguishable from a missing one when the tester has no compass - hence the 200-degree arc and the new 'Face the storm' admin tool.
**Where:** studio_game/ReplicatedStorage/CloudWallVFX.luau
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
