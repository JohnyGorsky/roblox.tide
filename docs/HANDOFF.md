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
| `GAME-0011` Sea & Sea States | `IN_PROGRESS` | Ocean + harbour built and verified. Five states in `SeaStates.luau`. Look **not approved**; blocked on sky assets |
| `GAME-0012` Admin Panel | `IN_PROGRESS` | Built in both places. **F4** or the **ADM** button (bottom-right). 7 tools in game, 3 in lobby. Gate attack-tested and passed |

---

## Waiting on you

| # | What | Why |
|---|---|---|
| 1 | **Unwedge Studio's Play** | Blocks the final two admin checks — the only outstanding verification |
| 2 | Judge the sea and harbour screenshots | Shape and horizon work; colour does not |
| 3 | **finding 0006** — overcast sky assets | Proven blocker on the whole art direction, both places |
| 4 | **finding 0004** — game place is `Fully Open` | A stranger could deep-link into a running expedition |
| 5 | **finding 0005** — Social Slots on the game place | A friend could drop into a 6-slot crew mid-run |
| 6 | todo 0003 — measure `LightingStyle = Realistic` on a phone | You chose the expensive path; cost unmeasured |
| 7 | todo 0001 / 0002 — `tide-style` skill; re-probe `StarterGui`/`StarterPack`/`Workspace` sync | Minor |

---

## Recommended next move

**Source the overcast skies** (finding 0006) — group 01 cannot finish without them, and everything else in
the sea look is done. Creator Store search is the fast route; Claude presents candidates for approval per
the asset policy.

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
