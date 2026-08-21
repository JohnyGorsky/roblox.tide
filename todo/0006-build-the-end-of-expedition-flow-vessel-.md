# TODO 0006: Build the end-of-expedition flow; vessel loss is a placeholder

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-21 09:18:26

Job 022 can now LOSE the vessel (integrity zero, or capsize held past 100 degrees for 4s), but there is nothing correct to hand off to: no expedition end exists, and the lobby is a separate place with no TeleportService flow built. So loseVessel() kills the engine and helm, zeroes every force so she sinks, sets ExpeditionOver / ExpeditionOverReason, prints a run summary, and removes the wreck 200 studs down. No progression is granted or taken.

Decisions 0008 (run power resets, permanent progression unlocks blueprints/mastery/discoveries) and 0011 (permanent progression credited individually to every participant) say what SHOULD happen. Implementing them needs: an expedition-end state, the crew teleported back to the lobby place, and the per-player credit. See the roblox-multiplayer skill for reserved servers and party teleport.

Delete the placeholder when the real flow lands - do not build on it. Marked by a yellow block comment in VesselServer.loseVessel.
