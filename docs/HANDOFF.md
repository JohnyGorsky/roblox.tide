# Handoff — where we left off

**Snapshot: 2026-08-20.** Pick up here, then read [BUILD-STATUS.md](../BUILD-STATUS.md) and
[docs/build/](build/README.md).

---

## 🔴 Two places of unsaved work

Both places hold **unsaved Edit-mode changes**. Claude cannot save them — there is no save capability in
the Studio MCP. **`Ctrl+S` in each place.**

| Place | At stake if not saved |
|---|---|
| **Game** | 6144 × 6144 ocean (water Y=0, sand seabed −64…−56), baseplate deleted, spawn raised, Light Swell lighting, tropical sky parked in `ServerStorage` |
| **Lobby** | 4096 × 4096 harbour, baseplate deleted, `GB_SpawnDock` + spawn on it, harbour water and fog |

**Safe already** — everything on disk and committed: `SeaStates.luau`, the four admin scripts in each
place, all docs, the manifest, the tools.

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
- 13 decisions, 17 system docs, 12 features.

**Game content**

| Feature | Status | Notes |
|---|---|---|
| `GAME-0011` Sea & Sea States | `IN_PROGRESS` | Ocean + harbour built and verified. Five states in `SeaStates.luau`. Look **not approved**; blocked on sky assets |
| `GAME-0012` Admin Panel | `IN_PROGRESS` | Built in both places. **F4** or the **ADM** button (bottom-right). 7 tools in game, 3 in lobby. Gate attack-tested and passed |

---

## Waiting on you

| # | What | Why |
|---|---|---|
| 1 | **Save both places** | Otherwise the ocean and harbour are lost |
| 2 | Unwedge Studio's Play | Blocks the final two admin checks |
| 3 | Judge the sea and harbour screenshots | Shape and horizon work; colour does not |
| 4 | **finding 0006** — overcast sky assets | Proven blocker on the whole art direction, both places |
| 5 | **finding 0004** — game place is `Fully Open` | A stranger could deep-link into a running expedition |
| 6 | **finding 0005** — Social Slots on the game place | A friend could drop into a 6-slot crew mid-run |
| 7 | todo 0003 — measure `LightingStyle = Realistic` on a phone | You chose the expensive path; cost unmeasured |
| 8 | todo 0001 / 0002 — `tide-style` skill; re-probe `StarterGui`/`StarterPack`/`Workspace` sync | Minor |

---

## Recommended next move

**Source the overcast skies** (finding 0006) — group 01 cannot finish without them, and everything else in
the sea look is done. Creator Store search is the fast route; Claude presents candidates for approval per
the asset policy.

**Then** [group 02 job 1 — vessel foundation](build/02-boat-parts.md): the module kit plus the starter hull
at correct dimensions, floating and steering. This is the first moment the game exists as a game. Note two
constraints already recorded against it: the boat **must** set `ReplicationFocus` to the vessel (streaming
is on), and custom buoyancy against our own wave field is required because **terrain-water waves do not
move objects**.

---

## Design questions still blocking whole groups

1. **What happens when the storm catches you?** Damage, forced movement, or run-ending. The storm's entire
   authority rests on this. Blocks group 07.
2. **Is one humanoid R15 rig shared** across players, NPC crew, pirates and drowned? Changes the animation
   count by roughly a third. Blocks 05, 10, 11.
3. **How is an island template stored?** Terrain regions are large binary data. Blocks group 04.
4. **Deck pathfinding on a moving vessel** — Roblox pathfinding assumes a static navmesh. Blocks boarding
   enemies and NPC crew.
