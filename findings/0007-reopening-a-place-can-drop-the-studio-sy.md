# FINDING 0007: Reopening a place can drop the Studio Sync connection silently

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-20 12:36:00

**Symptom:** After the game place was closed and reopened on 2026-08-20, Studio Sync stopped delivering. Evidence: ReplicatedStorage.SeaStates in Studio was 10205 chars with no directionDeg field while the file on disk was 11079 chars and contained it, and the newly written WaveField.luau was absent from ReplicatedStorage entirely - one modified file and one new file, both undelivered, 15+ seconds after writing. Earlier in the session the same place synced within seconds, so this is not latency. The failure is SILENT: nothing in Studio or the MCP announces that sync is no longer connected, and the symptom presents as 'my edit did nothing' or, worse, as a module that loads and behaves like an older version - which is easy to misread as a logic bug. Compounding it, require() caches per Edit session, so a stale module can be served from cache on top of a stale file. Mitigation while this stands: after any place reopen, verify sync before trusting an edit - compare #Source in Studio against the byte count on disk, or write a throwaway probe file and confirm it arrives. Ask the user to reconnect Studio Sync. Worth checking whether the sync connection can be queried from Luau at all, so a check could be automated instead of remembered.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_

## Clarification (2026-08-20, same day)

**MCP and file sync are separate connections.** The user showed the Assistant Settings → MCP Servers panel
reporting "Enable Studio as MCP server / 1 client connected" — that is the MCP link, and it was working
fine throughout; it is what makes `execute_luau` possible and how the staleness was detected at all. What
is down is whatever delivers `studio_game/` files into the place. Do not conflate them: a healthy MCP
connection says nothing about whether file sync is alive.

## Scope was wider than first recorded

Three edits were confirmed missing, not two — and one of them (`AdminTools` gaining `setAtmosphere`) was
written *before* the place was reopened. So the place was running entirely off the saved `.rbxl` with
nothing delivered since. That widens the diagnosis: it is not "the reopen dropped an in-flight edit", it is
"the sync link is not established for this session at all".

## Detection recipe

Cheapest reliable check, and worth running after any reopen before trusting an edit:

```lua
-- compare against the byte count on disk
local m = game:GetService("ReplicatedStorage"):FindFirstChild("SeaStates")
print(m and #m.Source or "absent")
```

A mismatch or an absent instance means sync, not logic. Do this *before* debugging behaviour, because a
stale module that loads and runs looks exactly like a logic bug.
