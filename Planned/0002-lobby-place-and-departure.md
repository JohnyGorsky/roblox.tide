# PLANNED 0002 — The lobby as a place, and departure to sea

**Project**: `roblox.tide`
**Group**: [08 — Lobby & shipyard](../docs/build/08-lobby-shipyard.md)
**Raised**: 2026-08-21, by the user — *"same endless sea, small island, storm in distance that never arrives,
and then pads for parties, like in jungle game"*
**Status**: ◐ **Partly promoted.** The lobby's *atmosphere* became [job 025](../Jobs/025/intake.md) on
2026-08-21 (sea, sky, cloud wall, lightning, audio, and the static horizon storm — all measured). What is
left here is **departure**: the party pads, the reserved-server teleport, the return, and the summary panel.

The island exists — the user asked Claude to sculpt it
(*"no you sculpt island, i think you can do it"*) and [job 024](../Jobs/024/intake.md) built it: 600 studs
across, a flat plateau at Y=+14 and 350 studs across, painted, with the dock re-sited as a jetty. Ready to
promote.

## Why it is planned rather than in flight

This was going to be job 023. Two rulings on 2026-08-21 turned out to conflict:

- split the expedition loop at A|B, with **023 = the lobby as a place**
- **wait for the sculpt** rather than graybox the island

The lobby half is the half that needs the island, so 023 would have started blocked. So the halves were
**swapped**: [job 023](../Jobs/023/intake.md) took the game-place mechanics, which need no art and no second
player.

Then the blocker dissolved anyway — the user asked Claude to do the sculpting, and job 024 built both islands.
The swap still stands, because the ordering turned out to be better on its own merits: the game-place half is
measurable from a probe the way job 022 was, and it is where the run's substance lives.

## Scope when promoted

**The lobby as a place**

- the same endless sea as the game place — `SeaStates`, `WaveField`, sky and cloud wall copied into
  `studio_lobby/`, byte-identical
- a **storm on the horizon that never arrives**: the same boarding gate job 023 builds, held permanently off.
  🔴 Reusing `StormFront` unmodified gives the lobby a front that closes at 14 studs/s and eventually engulfs
  the harbour — the module's whole purpose. One mechanism, two settings
- the **sculpted island**, with everything else on it graybox
- re-check `FogEnd` against the ocean extent rather than raising it alone (the hard rule from job 007). Note
  decision 0025 made the game's ocean a corridor, so the two places no longer share one extent

**Departure**

- party pads, **editor-placed**, discovered at runtime by attribute `Station = "PartyPad"` — reuse Jungle's
  shape (`roblox.jungle.game/lobby/sync/ServerScriptService/LobbyServer.server.luau`), do not invent a second
  pattern. No count constant: Jungle deleted theirs after it drifted to a lie, 3 declared against 4 placed
- `PAD_RADIUS = 9`; sign (`BillboardGui`, `MaxDistance 40`) and `ProximityPrompt` script-attached to your
  geometry, so replacing a pad needs no code change
- countdown → `ReserveServerAsync` → `TeleportAsync`, **3 attempts 1 s apart**, with the launch VFX and audio
  fired **before** the call, because the call is the part that fails
- `MAX_PER_PAD` set against Tide's confirmed 6 / 20 crew size rather than inherited from Jungle's 6

**The return**

- the lobby half of the split summary: job 023 ships the in-place beat, this reads the result out of
  `TeleportData` and shows the breakdown
- failure handling both ways — a crew that cannot get home must not be stranded in a dead reserved server

**Place settings**

- close [finding 0004](../findings/0004-game-place-direct-access-control-is-full.md) and
  [finding 0005](../findings/0005-social-slots-enabled-on-the-game-place-m.md): the game place is `Fully Open`
  with Social Slots on, which is exactly wrong for a reserved-server expedition — a stranger can deep-link
  into a running run, a friend can drop into a 6-slot crew mid-expedition. Needs the user's hands in the
  place's settings

## Grayboxes it will register

Everything on the island except the island.

| Id | Stands in for | Note |
|---|---|---|
| `GB-LOBBY-PAD` | `ASSET-LOBBY-PARTY-PAD` | One entry for all pads, as `GB-STARTER-LAUNCH` is one entry for the whole ship. Editor-placed, tagged `Graybox`, discovered by attribute |
| `GB-LOBBY-STORM` | `ASSET-CLOUD-WALL` | Inherits `GB-CLOUD-TEXTURE`'s note; that entry gains `place: game, lobby` |

And a decision is owed on **`GB-LOBBY-DOCK`**: it exists only because the lobby has
`CharacterAutoLoads = true`, so removing the baseplate would drop joining players into the sea. An island
supersedes that reason, so the dock is either retired or promoted to real harbour furniture. Deleting place
content is the user's call — Studio Sync is two-way.

## The duplication problem, which needs solving here

The lobby's `ReplicatedStorage` is **empty on disk**, and Roblox has no cross-place `ReplicatedStorage`. So
every shared module gets copied into both sync roots and must stay byte-identical — the arrangement
`AdminTools` already lives with, and which silently rotted by 12,234 bytes during job 022.

So this job should carry **`tools/check-shared-parity.py`**: diff the shared files between `studio_game/` and
`studio_lobby/` and fail loudly. Write it before the duplication exists, not after.

## What must be true before promoting

1. ~~The **sculpted island** exists in the lobby place.~~ ✅ Job 024. The plateau is measurably flat — one
   distinct surface height across 4,404 columns — which is what the pads need.
2. Job 023 has landed, so the boarding gate and the run's endings exist to connect to.
3. Lobby Studio Sync is delivering — it was dead for most of job 022 and only reconnected on 2026-08-21.
   Verify by **content**, not by child counts (see finding 0007).
