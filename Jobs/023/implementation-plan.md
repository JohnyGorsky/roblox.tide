# Implementation Plan — Job #023

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Status**: In flight — steps 1–4 and 8 landed and measured; 6, 7, 9 remain

## Progress (2026-08-21)

| Step | State |
|---|---|
| 1. Grow the ocean into a corridor | ✅ Filled Z 3072→5500 in 18 tiles, 0.34 s. Water continuous through the old seam, ends exactly at 5500, edges at ±3072 |
| 1b. Extent model | ✅ `OCEAN_EXTENT_X` / `OCEAN_EXTENT_Z`, `SeaStates.insideOcean` now the single owner, `WaveField` delegates to it. **Waves verified through Z=5400 and flat from 5600** — the change that could have silently stopped the hull floating halfway up the voyage |
| 2. The boarding gate | ✅ All three claims measured: parked at 4200 during the grace (0.00 drift over 12 s), closing at −14.09 studs/s after boarding, and **still −14.05 after the helm is released** — the exploit is closed |
| 3. `Expedition.luau` | ✅ Pure model: states, causes, northing, the summary shape |
| 4. `ExpeditionServer` | ✅ Run resolved **Finished / northing at 2402 of 2400 in 144 s**, hull ending with 3,097 studs of water still ahead. `ExpeditionOver` now has one owner — that write moved out of job 022's `loseVessel` |
| 5. Start island | ✅ Job 024 |
| 8. Admin tools | ✅ 5 tools in a new **Expedition** section, ordered first. 49 tools total, scopes valid |
| 6. Tender + fuel barrels | ⬜ **Remaining** — the one uncertain piece (a second vessel against `VesselServer`'s singleton `state`) |
| 7. The in-place summary beat | ⬜ Remaining |
| 9. Docs | ⬜ Remaining |

### One deliberate deviation from decision 0025

The corridor was filled to **Z=5500, not 12000**, and the reasoning is now a stated invariant rather than a
judgement call:

> `OCEAN_EXTENT_Z.max ≥ northing target + the largest fogEnd`

With the placeholder target of 2400 and Dead Calm's capped fogEnd of 2900 that is 5300, hence 5500 with 200
studs of margin. The full 12000 is +145% terrain on a mobile-first game for a target nobody has tuned;
5500 is +40%.

The invariant also **explains decision 0025's own figure**, which the decision did not spell out: 12000 is a
target of about 9100 plus the same 2900 of fog. `SeaStates.validateCorridorForTarget` evaluates it, and the
admin tool prints it whenever the target changes.

The run — a corridor to voyage through, a storm on a leash, and three ways to end. Game place only; the lobby
and departure wait in [Planned 0002](../../Planned/0002-lobby-place-and-departure.md) for the sculpted island.

---

## Rulings (2026-08-21)

| Question | Ruling |
|---|---|
| Finding 0018, the endless sea | **Grow the patch** — decision [0025](../../docs/decisions/0025-ocean-is-a-corridor.md), a corridor north rather than a bigger square |
| Being stranded | **A tender and floating fuel**, not an abandon-ship button. Survive at the cost of time |
| The lobby island | Originally *wait for the sculpt*, which is why this job is the game-place half. Superseded the same day — Claude sculpted both islands in job 024 — but the split stands on its own merits |
| Scope | **Split at A|B**, halves swapped so the blocked half waits |
| How a run ends successfully | Northing threshold, and it **triggers the finale** rather than being the victory |
| DataStore persistence | Out of scope |
| Summary | Split — this job builds the in-place beat only |

---

## Analysis

### The corridor: one constant becomes two

`SeaStates.OCEAN_HALF_EXTENT` is a single scalar used as a **square** bound, read in five places across
`SeaStates`, `WaveField`, `DayNight` and `AdminTools` (plus the dead `P2`). Two of those carry meaning:

```lua
local function insideOcean(x, z)          -- WaveField
    local half = SeaStates.OCEAN_HALF_EXTENT
    return math.abs(x) <= half and math.abs(z) <= half
end
```

and `SeaStates.validateFogWithinOcean`, which enforces the job-007 rule that `fogEnd` must stay inside the
water or the sea visibly stops.

So: `OCEAN_EXTENT_X = 3072` and `OCEAN_EXTENT_Z = { min = -1000, max = 12000 }`, with `insideOcean` and the
fog validator updated. The fog rule must check against the **nearest** edge, which stays east–west at 3,072 —
so `fogEnd` keeps its current ceiling of 2,900 and the horizon treatment carries over untouched. That is the
whole reason a corridor is cheap and a bigger square would not have been.

🔴 **The Z extent must cover the entire voyage.** Outside the patch `HeightAt` returns flat `WATER_Y` — no
waves — so a hull that reaches the end of the corridor silently stops floating on a sea and starts floating on
a plane. It reads as the wave field breaking, not as running out of world. The placeholder northing target must
therefore stay well inside `OCEAN_EXTENT_Z.max`.

⚠️ Terrain is a **saved-place change** and nothing in the MCP can inspect a saved `.rbxl` (handoff note). So:
fill, read the voxels back, screenshot the horizon, then save deliberately — and expect the graybox audit and
place-settings audit to be re-run afterwards.

### The boarding gate, and the one way it can be exploited

Decision 0024: the storm is stationary until the crew takes the helm. Implementation is a flag, and the flag
is where the care goes.

```
storm advances  ==  runStarted AND NOT expeditionOver
```

`runStarted` is set **once**, server-side, the first time the helm is taken, and **never cleared**. Two
failure modes if that is got wrong:

- **clearing it when the driver leaves the helm** turns the grace into a switch that stops the game's only
  pressure — stand up, and the storm politely waits
- **letting a client set it** is the usual remote-trust mistake; only `VesselServer`'s own prompt handler may
  raise it

Cheap upside: the same gate held permanently off is exactly what the lobby needs later, so the lobby's
"storm that never arrives" is a setting rather than a second implementation.

`WorldTick` currently calls `StormFront.advance(step * timeScale(), vesselZ())` unconditionally. The gate goes
there, and the five stationary minutes fall out for free — the front is *drawn* at its start distance the whole
time, because `apply()` still runs and still publishes intensity and wind.

### Northing cannot be storm distance

Worth restating because it is the trap: `StormFront.advance` ends with
`distance = math.min(distance, START_DISTANCE)`. The cap stops an early lead becoming un-loseable — and it
means distance **stops rising** once the crew is 4,200 ahead. A crew could sail north for ten minutes and the
number would not move.

So the run tracks **net northing**, `hull.Z − startZ`. Net displacement rather than accumulated northward
deltas: `StormFront` counts only northward travel, and copying that here would let a crew farm progress by
oscillating.

### The three endings are two code paths and a cause

- **finished** — northing ≥ target → placeholder finale → resolve
- **lost** — job 022's `loseVessel`, which already fires and already sets `ExpeditionOver`
- **out of fuel** — a **cause**, not a path. It terminates in `lost` on its own: adrift, the front closes at
  14 studs/s, arrives, and integrity drains in 45 s. The summary needs to say which of the two happened,
  because "we ran out of fuel just before it caught us" is the story the design is built around

### Stranded: the numbers the tender has to satisfy

Decision 0024's amendment. Two constraints, and the first is a hard one:

🔴 **Under 8.75 studs/s.** Break-even is `ADVANCE_RATE / GAIN_PER_STUD` = 14 / 1.6. A fuel-free boat above
that gains ground on the storm forever, and the launch — plus the entire fuel economy it exists to consume —
becomes pointless. **The tender is ~6 studs/s.** It must feel like a rowboat because mechanically it has to
be one.

**Barrels at 200–400 studs**, costing 22–44% of the cushion for a round trip at 6 studs/s. Expensive enough to
hurt, survivable enough to be worth trying.

There is also a safety property that comes free and is worth not breaking: **`StormFront` chases the vessel**,
reading its Z through `_G.TideVessel`. A crew that takes the tender and leaves the ship does not escape — the
front closes on the launch, destroys it, and the run ends. Abandoning the ship *is* losing. If a future job
ever makes the storm chase players instead, this mechanic becomes an exploit.

Implementation note: the tender is a **second vessel**, and decision 0009's kit already covers that — a `Spec`
with its own `density`, `draft`, `thrust`, `cruise` and buoyancy points. It should be built through
`Vessel.build` rather than hand-rolled, which also means it inherits the clamped buoyancy that stopped job
021's hull destroying itself. What it must *not* inherit is `VesselServer`'s singleton assumptions — that file
holds one `state` table for one hull, so a second vessel needs the ownership and helm logic generalised, or a
deliberately separate and much simpler driver.

⚠️ That is the one genuinely uncertain cost in this job. I will know which after reading `VesselServer` with a
second hull in mind; if generalising it looks like it would destabilise the measured physics, the tender gets
its own minimal driver and a todo for unifying them later.

### Arrival is not automatic

`CharacterAutoLoads = false` by design (job 004). Admins auto-spawn via `AdminServer`; nobody else does. The
run must spawn its crew **on the start island**, not on the deck — the five minutes to board only exist if you
begin ashore.

---

## 🧱 What is grayboxed

| Id | Stands in for | Place | Note |
|---|---|---|---|
| `GB-GAME-START-ISLAND` | `ASSET-START-ISLAND` | game | ✅ **Built in job 024** — 120 studs across, flat plateau at +12, verified clear of the launch's spawn. Registered; nothing to do here |
| `GB-TENDER` | `ASSET-BOAT-TENDER` | game | The fuel-free rescue boat, built through the vessel kit. A box until it earns a model |
| `GB-FUEL-BARREL` | `ASSET-FUEL-BARREL` | game | Drifting barrels, 200–400 studs out. Group 03 already plans a real barrel and jerry can |
| `GB-STARTER-LAUNCH` | `ASSET-BOAT-STARTER` | game | Registered in job 022, runtime-built, unchanged |

The start island is **editor-placed** (yours or mine — say which); the tender and barrels are **runtime-built**
like the launch, so they register with `runtime = true` and the Edit-mode audit reports them as `RUNTIME`
rather than missing.

**`GB-GAME-DECK` should be retired here.** Its own note says to delete it once `GAME-0001` lands, which it has,
and decision 0024 replaces its purpose with the start island. It is editor-placed geometry and Studio Sync is
two-way, so I will not delete it unasked — confirm and I will.

---

## Implementation steps

1. **Grow the ocean.** `OCEAN_HALF_EXTENT` → X and Z extents; update `insideOcean` and
   `validateFogWithinOcean`; fill the corridor; read voxels back; screenshot the horizon. Save the place.
2. **The boarding gate.** `runStarted` in `Expedition`, raised once by the helm prompt, read by `WorldTick`
   before advancing. Verify the front does not move before boarding and does not stop after.
3. **`ReplicatedStorage/Expedition.luau`** — pure run-state model: `startZ`, northing, target, state, cause,
   the gate, the summary shape. No instances, testable from a probe like `VesselDamage`.
4. **`ServerScriptService/ExpeditionServer.server.luau`** — spawn crew on the start island, own the gate, watch
   northing, hook job 022's loss, resolve into a summary, publish it.
5. ~~The start island~~ — **done in job 024**. The `SpawnLocation` is already on its plateau and the launch's spawn point was verified as open water.
6. **The tender and the barrels** — a second `Vessel.Spec` at ~6 studs/s, barrels drifting 200–400 studs out,
   both runtime-built and registered. Refuelling the launch from a carried barrel is the interaction that makes
   it matter.
7. **The in-place beat** — `ExpeditionClient.local.luau`. Hold the screen on the ending. On `Heartbeat`, not
   `RenderStepped` (finding 0022).
8. **Admin tools** — `Expedition → Set northing`, `Force an ending`, `Start the storm`, `Run report`.
9. **Docs** — a systems doc for the run; update `GAME-0003`/`GAME-0001` and the manifest; register every
   graybox; re-run `build-status.py`.

---

## What I need from you

- [ ] **Go-ahead.**
- [ ] **The start island**: do you want to place it, or shall I stand in a graybox disc? (The *lobby* island is
      the one you are sculpting; this is a different, smaller one.)
- [ ] **Retire `GB-GAME-DECK`?** Yes/no — it is place geometry, so it is your deletion to authorise.
- [ ] Nothing to source. The tender and barrels are boxes; group 03 will replace them.

---

## Verification

- [ ] **The corridor holds waves to its end** — sample `HeightAt` along Z out to the max extent; no flat water
      inside the patch, and no visible edge on a horizon screenshot
- [ ] **`fogEnd` still passes** `validateFogWithinOcean` against the nearest edge
- [ ] **The front does not move before boarding** — sample `StormDistance` for 60 s, then take the helm and
      confirm it starts
- [ ] **Leaving the helm does not stop it** — the exploit check
- [ ] **Northing drives the ending**, and still works after `StormDistance` has capped at 4,200
- [ ] **Out of fuel is labelled fuel, not hull**
- [ ] **The tender cannot outrun the storm** — measure its top speed against 8.75 studs/s; then drive it north
      at full effort for 60 s and confirm `StormDistance` **falls**
- [ ] **A round trip to a barrel costs what the table says** — time it, and check the cushion spent
- [ ] **Job 022 is not regressed** — re-run the survival test both modes (45 s hold, escape with hull left) and
      the buoyancy-under-flooding check
- [ ] No new analyzer diagnostics; Play stopped; Studio left in Edit; place saved deliberately
