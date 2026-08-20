# Handoff — where we left off

**Snapshot: 2026-08-21.** Pick up here, then read [BUILD-STATUS.md](../BUILD-STATUS.md) and
[docs/build/](build/README.md).

## 🚤 Where the game actually is

Five jobs landed in sequence (017–021) and the game now has a **sea, weather, a storm, a soundscape and a
boat you can drive**. Everything below is measured in the engine rather than assumed.

| | |
|---|---|
| **Sea** | Ocean + harbour, five sea states, wave field (`HeightAt`/`NormalAt`), skies sourced and approved |
| **Weather** | Everyday weather drifts independently of the storm (decision 0020) — it may move wind, waves, rain and fog, and may **not** touch the sky, brightness or ambient. Verified byte-identical |
| **Storm** | Advances 14 studs/s from 4200 → **arrives in exactly 5 minutes** stationary. Lightning, cloud wall astern, 5 escalating bands |
| **Audio** | 9 channels through `AudioBed` — multi-voice, equal-power crossfade, random re-seek, detune. No music at all (decision 0021) |
| **Boat** | Starter launch, MVP signed off. Floats on the wave field, steers like a rudder, heels through a turn, trims under power, burns fuel |

**Read before touching vessel physics:**
[finding 0019](../findings/0019-a-large-torque-applied-in-a-body-relativ.md) — a large torque in a
body-relative frame leaks into every axis the body rotates about. It spun the hull 178° in 8 seconds with the
wheel amidships, and made repeated measurements disagree between runs. Every force on the vessel is now
`RelativeTo = World` with an explicitly aimed direction; **keep it that way.**

**The kit property that must not be broken:** nothing on a vessel is tuned per hull. Buoyancy stiffness, drag,
rudder authority and yaw damping are all *derived* from the spec's statements of intent (`draft`, `cruise`,
`rudderLag`) plus the hull's own mass and inertia — verified exact from 4,200 to 90,000 mass. A hand-tuned
constant on a later vessel destroys decision 0009's promise.

## 🔧 How to drive and test it

1. **Press Play.** Admins auto-spawn with a body, on the boat's deck (the game place keeps
   `CharacterAutoLoads = false` — that governs *respawn*, and is deliberate).
2. **F4** for the panel — 39 tools in 6 collapsible sections, `Vessel` first.
3. Walk to the **helm console**, press **E**, then **W/S** throttle and **A/D** steer.

Panel tools worth knowing: `Vessel → Buoyancy stability check` (reports converging/growing);
`Vessel → Put me on the boat`; `Storm → Watch a full approach (10×)`; `Sea → Sea state` (pins an override so
the world tick cannot clobber it); `Sea → Time of day`; `Audio → Solo one channel`.

⚠️ **Studio Sync does not reach a running Play session** — the Server datamodel is a snapshot from when Play
started. Every code change needs a Play restart. And **always stop Play if you started it**; if a start or stop
has not taken effect in ~20 s, stop retrying and say so.

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

## 🟡 Start-play is unreliable (not wedged right now)

It has timed out and needed a Studio restart several times. Observed pattern: it jams when a request lands
right after a long-running `execute_luau` (20–30 s sampling loops), so leave a gap or keep runs short. It has
also returned `"Game Stopped"` while the state still read `Play`, settling a moment later — **the reply is not
proof**; check `get_studio_state`, and if it disagrees, wait rather than firing again.

Two admin checks are still outstanding because they need a stable multiplayer session:

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
| `GAME-0001` Boat Controller | `IMPLEMENTED` | Job 021, **MVP signed off 2026-08-21**. Floats, steers, trims, heels, burns fuel. Server-owned, helm is a standing station not a seat. Not VERIFIED: never tested with two players, and mobile controls never run on a touch canvas |
| `GAME-0003` Advancing Storm Front | `IMPLEMENTED` | Job 018. Front advances, everyday weather drifts, lightning lights the sea at range, cloud wall grows and engulfs, 4-channel audio bed. **Approved by eye for the POC.** Not VERIFIED because the storm still cannot hurt you |
| `GAME-0004` Day/Night | `IN_PROGRESS` | 575 s cycle. `DayNight.compose()` is the sole writer of Lighting, Terrain water and the cloud layer |
| `GAME-0012` Admin Panel | `IN_PROGRESS` | Both places. **F4** or **ADM** (bottom-right). **32 tools** in game across Sea / Weather / Storm / Audio / Diagnostics. Gate attack-tested and passed |

---

## Resuming after a Studio restart (read this first)

Studio was closed on 2026-08-20 with jobs 018 and 019 both complete. Nothing is lost — every source file
is on disk — but two things need checking before trusting what you see:

1. **Re-verify Studio Sync.** [Finding 0007](../findings/0007-reopening-a-place-can-drop-the-studio-sy.md):
   reopening a place can silently drop the sync connection, so scripts look present while edits go nowhere.
   Check a known module exists in `ReplicatedStorage` (there should be **14**), and that
   `ServerScriptService` has **3** and `StarterPlayerScripts` **2**. (14 after job 019.)

2. **The `Clouds` layer is not backed by a file.** It was created over MCP in Edit, so if the place was
   closed without saving it is gone. This costs nothing — `WorldTick` recreates it on start if missing — but
   the Edit-mode view will show a clear sky until something runs.

Nothing else in the place is script-generated; the ocean, harbour and spawn are all saved geometry.

## Waiting on you

| # | What | Why |
|---|---|---|
| 1 | **Commit `docs/HANDOFF.md`** | The only uncommitted file. Studio Sync is two-way — deleting an instance deletes the FILE, and a mid-session commit is what saved `StormVFX` when a cleanup pattern matched it (finding 0015) |
| 2 | **Decide how the ocean stops having an edge** — [finding 0018](../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md), high | Centre-to-edge is **2.8 min** at cruise; fuel lasts 3.0. The fuel tank is the only thing hiding the edge of the world, **by twelve seconds** — and faster vessels (group 02) and jerry cans (group 03) are both planned. Options are in the finding: grow the patch, recentre the world on the vessel, or fence it in fiction |
| 3 | **Listen to the audio bed** | Nine channels whose balance no human has heard. Panel → Audio → *Audio status*, and *Solo one channel* to pick one out |
| 4 | **Judge the boat's feel** | The numbers are right; whether she reads as a launch is your call. `cruise` is the dial, and `GAIN_PER_STUD` gets solved for whatever you pick — the 5-minute storm arrival is untouched either way |
| 5 | **Two-player test** | The one thing blocking `GAME-0001` from `VERIFIED`: never driven with a second crew member aboard. Also blocks the non-admin refusal check |
| 6 | **finding 0004 / 0005** — game place is `Fully Open`, Social Slots on | A stranger could deep-link into a running expedition; a friend could drop into a 6-slot crew mid-run |
| 7 | todo 0003 — measure `LightingStyle = Realistic` on a phone | You chose the expensive path; cost unmeasured. Mobile helm controls are also written but never run on a touch canvas |
| 8 | todo 0001 / 0002 — `tide-style` skill; re-probe `StarterGui`/`StarterPack`/`Workspace` sync | Minor |
| 9 | Delete `ServerStorage.P2` and `SkyQuarantine` | Both dead. `P2` is a stale duplicate of `AdminTools` from commit `6617b24` |

---

## Recommended next move

**The storm's teeth** — [decision 0014](decisions/0014-storm-consequence.md) makes the front inflict hull
damage and system faults, escapable in 30-60s, and nothing implements it. It was deferred precisely because it
needs a hull to damage, and now there is one. It is also small, and it converts the storm from a spectacle
into the threat the whole macro loop depends on.

Then **[03](build/03-items-props.md) items** — fuel is the loop's real currency, and the boat currently starts
with a full tank and no way to refill it.

~~**[02](build/02-boat-parts.md) vessel foundation.**~~ *(delivered, job 021)* Groups 01 and 07 are now built as far as they can go
without a deck to stand on, and the storm was signed off for the POC on 2026-08-20: the sea, its states, the
wave field, the day/night cycle, everyday weather, lightning, the cloud wall and the audio bed all exist and
all tick. The next thing that changes the game rather than the scene is the hull.

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
