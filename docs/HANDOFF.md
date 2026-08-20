# Handoff — where we left off

**Snapshot: 2026-08-20.** Pick up here, then read [BUILD-STATUS.md](../BUILD-STATUS.md) and
[docs/build/](build/README.md).

---

## ✅ Both places saved (2026-08-20)

Verified present after the save:

| Place | Confirmed |
|---|---|
| **Game** | Ocean at (400,400) and (3000,0); baseplate gone (Workspace = Terrain, SpawnLocation, Camera); `StreamingEnabled true`, `CharacterAutoLoads false`, `FogEnd 2800`, `WaterWaveSize 0.18`, `LightingStyle Realistic`; all four admin scripts present with `AdminClient` a LocalScript; tropical sky parked in `ServerStorage` |
| **Lobby** | Harbour water at (300,300); baseplate gone; `GB_SpawnDock` present and still tagged `Graybox` with `GrayboxId=GB-LOBBY-DOCK`, 64×4×40; `StreamingEnabled false`, `FogEnd 1900`, `WaveSize 0.06`; all four admin scripts present |

Both cameras read `Fixed`, so Studio has viewport control in each.

> Note: what was verified is that the **content is correct in the live sessions**. Nothing in the MCP can
> inspect the saved `.rbxl` itself, so if the places are ever reopened and something is missing, the save
> is the first suspect.

---

## 🟡 Studio's start-play is wedged

The MCP reports *"start play hasn't finished yet"* while Studio reports Edit mode. Check for a modal
dialog, or restart Studio. It blocks the last two admin checks:

1. The panel builds **exactly once** (it built twice before the `.client.luau` → `.local.luau` fix; the
   fix is confirmed at instance level, not yet at runtime).
2. A **non-admin is refused end to end** — point the allowlist at a different UserId, Play, confirm no
   button appears and every tool refuses.

---

## What exists

**Infrastructure — done and verified**

- Two places, both synced. Layout is **flat**. Suffixes: `.luau` → ModuleScript, `.server.luau` →
  Script/Server, **`.local.luau` → LocalScript** (use this in `StarterPlayerScripts`, *not*
  `.client.luau`, which runs twice). `.module.luau` and `.localscript.luau` are traps.
- Place settings baseline applied and audited. Crew size confirmed 6 / 20.
- Build board (`tools/build-status.py`), graybox register (`tools/audit-graybox.luau`), settings audit
  (`tools/audit-place-settings.luau`).
- ⚠️ A failed or stale `require` is cached for the whole Edit session — clone the module and require the
  clone to read what is actually on disk.

**Design — done**

- [The build manifest](build/README.md): ~630 items in 13 groups.
- 17 decisions, 17 system docs, 12 features.

**Game content**

| Feature | Status | Notes |
|---|---|---|
| `GAME-0011` Sea & Sea States | `IN_PROGRESS` | Ocean + harbour built and verified. Five states in `SeaStates.luau`. Skies sourced; look approved |
| `GAME-0003` Advancing Storm Front | `IN_PROGRESS` | Front advances, world ticks, everyday weather drifts, lightning strikes, cloud wall astern. **Not done: damage when caught** — The Wall only *looks* unsurvivable |
| `GAME-0004` Day/Night | `IN_PROGRESS` | 575 s cycle. `DayNight.compose()` is the sole writer of Lighting, Terrain water and the cloud layer |
| `GAME-0012` Admin Panel | `IN_PROGRESS` | Both places. **F4** or **ADM** (bottom-right). **32 tools** in game across Sea / Weather / Storm / Audio / Diagnostics. Gate attack-tested and passed |

---

## Waiting on you

| # | What | Why |
|---|---|---|
| 1 | **Judge the storm approach** | Panel → Storm → **Watch a full approach (10x)**, then look ASTERN. Everything in job 018 is unjudged by a human |
| 2 | **Two sound clips** — rain loop, thunder one-shot | Spec + rules in `Assets/registry/audio.md`. Audition them live via Audio → Audition a sound id; no code change needed |
| 3 | **Unwedge Studio's Play** | Blocks the non-admin refusal check — the only outstanding admin verification |
| 4 | **finding 0004** — game place is `Fully Open` | A stranger could deep-link into a running expedition |
| 5 | **finding 0005** — Social Slots on the game place | A friend could drop into a 6-slot crew mid-run |
| 6 | todo 0003 — measure `LightingStyle = Realistic` on a phone | You chose the expensive path; cost unmeasured |
| 7 | todo 0001 / 0002 — `tide-style` skill; re-probe `StarterGui`/`StarterPack`/`Workspace` sync | Minor |

---

## Recommended next move

**[02](build/02-boat-parts.md) vessel foundation.** Groups 01 and 07 are now built as far as they can go
without a deck to stand on: the sea, its states, the wave field, the day/night cycle, everyday weather and
the storm all exist and all tick. The next thing that changes the game rather than the scene is the hull.

It also makes the storm's central mechanic real for the first time. `StormFront` buys distance for northward
travel and there is nothing to travel with, so today the front simply closes — which is exactly what a
fuel-less crew will experience, and nothing else.

Two constraints already logged: `ReplicationFocus` must point at the vessel (streaming is on), and buoyancy
must be custom, because Roblox terrain-water waves exist only in the shader
([finding 0008](../findings/0008-roblox-terrain-water-waves-exist-only-in.md)) so engine auto-buoyancy pulls
toward a flat Y=0 plane and will fight the wave field — and the symptom looks like jitter rather than like a
conflict.

**Then**, in this order (see [the manifest](build/README.md) for why):

1. **[01](build/01-sea.md) wave field** — `HeightAt`/`NormalAt`, the maths everything floats on.
2. **[07](build/07-atmosphere.md) day/night, then storm core** — judgeable with no boat, and it defines the
   full range of sea before anything is tuned to it.
3. **[02](build/02-boat-parts.md) vessel foundation** — the module kit plus the starter hull at correct
   dimensions, floating and steering. Two constraints already logged: `ReplicationFocus` must point at the
   vessel (streaming is on), and buoyancy must be custom against our wave field, because terrain-water
   waves do not move objects.

The caught-by-storm consequence (decision 0014) is deliberately last — it needs a hull and systems to
damage.

---

## Design questions — all four answered

The questions that were blocking whole groups are now decisions:

| Decision | Unblocks |
|---|---|
| [0014](decisions/0014-storm-consequence.md) — the storm damages, escapable in ~30–60s, does not instantly end the run | group 07 |
| [0015](decisions/0015-shared-humanoid-rig.md) — one shared humanoid R15 rig | groups 05, 10, 11 |
| [0016](decisions/0016-island-template-storage.md) — island = `TerrainRegion` + prop `Model` + markers | group 04 |
| [0017](decisions/0017-vessel-local-navigation.md) — NPCs navigate a waypoint graph in vessel-local space | groups 05, 10 |

Nothing in the manifest is now blocked on an unanswered design question. What remains open is smaller and
listed in each group's own "open questions" section — plus the asset blocker (finding 0006) and the two
Access settings (findings 0004, 0005).
