# FINDING 0012: RunService.RenderStepped does not fire in the MCP Edit context, so any effect driven by it is silently untestable

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-20 15:13:37

**Symptom:** Lightning's exposure flash was originally driven by RunService.RenderStepped. In an Edit-mode execute_luau test the bolt geometry verified perfectly - 5 segments, correct distances, no NaN, self-cleanup - while the exposure never moved from its baseline. There is no error and nothing distinguishes 'RenderStepped never fires here' from 'the flash is broken' without entering Play, which is exactly the state where MCP start_stop_play tends to wedge (see the play-control note). Moved the flash to RunService.Heartbeat, which fires in both Edit and on a client and is per-frame anyway - the flash writes a Lighting property, not a camera transform, so it needs no render-time precision. Camera SHAKE stays on RenderStepped, because that one genuinely must run at render time or the camera script overwrites it the same frame. General rule worth keeping: prefer Heartbeat for anything that does not strictly need render timing, because it is the half that stays testable from Edit - and a channel that cannot be checked is a channel that quietly rots (see finding 0011 for what that costs).
**Where:** MCP execute_luau, Edit datamodel
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
