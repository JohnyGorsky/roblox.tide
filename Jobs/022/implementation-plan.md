# Implementation Plan — Job #022

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Status**: Implemented and measured in a session 2026-08-21 — two items still need a hands-on look (compass orientation, damage-control hold)

The storm's teeth — hull damage and system faults inside The Wall. Implements
[decision 0014](../../docs/decisions/0014-storm-consequence.md).

---

## Analysis

### What already exists to build on

| Piece | Where | What it gives this job |
|---|---|---|
| Band 4 `The Wall` | `StormFront.BANDS` | distance < 260 studs = inside the front. Already published as `StormIntensity 4` |
| `TheWall` sea state | `SeaStates.luau` | fog 330, `BlackVoid` sky, brightness 0.30, waveSize capped 1.0 — **the blind-navigation state already renders** |
| Server-owned hull + forces | `VesselServer.server.luau` | one place to apply damage, all forces already `RelativeTo = World` |
| Derived-constant kit | `Vessel.luau` + `VesselPhysics.luau` | the pattern damage must follow: spec states intent, code derives |
| Admin `Vessel` + `Storm` sections | `AdminTools.luau` | `stormDistance` already teleports the front, so exposure is drivable without waiting 5 minutes |

### 🔴 Two defects found while reading, both in this job's path

**1. Northward progress buys the crew nothing. The storm cannot be outrun at all today.**

`WorldTick.vesselZ()` ([WorldTick.server.luau:78](../../studio_game/ServerScriptService/WorldTick.server.luau#L78))
looks for `workspace.Vessels.Hull`. `VesselServer` parents the model straight to `workspace` under the spec
id, so the lookup is `workspace.StarterLaunch.Hull` — the folder `Vessels` has never existed. The function
returns `nil` every tick, `StormFront.advance` gets no `vesselZ`, and `GAIN_PER_STUD` has never once been
applied. The comment above it still says "There is no vessel yet", which was true at job 017 and stopped
being true at job 021.

This is not a side issue for job 022 — it is load-bearing. Escaping The Wall *is* the reaction decision 0014
requires, and with this bug the escape is arithmetically impossible: distance only ever decreases. The
survival target cannot be tuned, or even measured, until it is fixed. **Fix it first, before any damage code.**

**2. `VesselHeading` is published to a Workspace attribute and read by nothing.**

[VesselServer.server.luau:101](../../studio_game/ServerScriptService/VesselServer.server.luau#L101). Workspace
attributes replicate to every client, so the hull's heading is already sitting on the wire in degrees. Decision
0014's blind-navigation clause — *"the HUD must never show a heading, or the blindness is free"* — is one
`GetAttribute` away from being void, and nothing consumes it. Stop publishing it; keep it in the server-only
`_G.TideVessel.report()` where the admin panel already reads it. `VesselSpeed` stays: a speed readout is not a
heading and does not tell you which way is out.

### The escape arithmetic, from the numbers already in the repo

This is what makes the 30–60 s target checkable rather than a hope:

```
ADVANCE_RATE   14 studs/s      the front always closes
GAIN_PER_STUD  1.6             per stud travelled north
cruise         18 studs/s      the launch's settled speed

full throttle due north:  18 x 1.6 - 14  =  +14.8 studs/s net
The Wall boundary:        distance 260

  from distance    0  ->  260 studs to cover  ->  17.6 s to clear the front
  from distance -200  ->  460 studs          ->  31.1 s
  from distance -450  ->  710 studs          ->  48.0 s
```

So the front's own numbers already produce a **17–48 second escape**, which lands inside decision 0014's
30–60 s window without touching a single storm constant. That is the anchor for the damage rate: a hull that
dies after ~45 seconds of *full* exposure kills a crew that dithers and spares one that reacts, and the
5-minute arrival timing is untouched (requirement 4 of the intake).

### Where the damage model lives, and why not in a new "StormDamage" module

Two modules, matching the split that already works:

- **`StormFront.exposure()`** — *how bad is it out here*. StormFront already owns distance, bands, intensity
  and wind; exposure is one more derivation from the same distance and belongs beside them. A separate module
  would need to re-read the same attribute and could disagree with the band.
- **`VesselDamage.luau`** (new, `ReplicatedStorage`) — *what this hull does about it*. Pure data and maths, no
  instances, no Workspace writes: integrity, damage rate, fault thresholds, flooding effect. Same shape as
  `VesselPhysics` so it is testable from a probe and reusable by every future hull.

`VesselServer` stays the only thing that touches instances and forces.

### Keeping decision 0009's promise (nothing tuned per hull)

The spec gains **one field**, and it is a statement of intent in the same family as `draft` and `rudderLag`:

```lua
--- Seconds of CONTINUOUS FULL exposure inside The Wall this hull survives, unrepaired.
survivability = 45,
```

Everything else derives from it: integrity points scale off the hull's own mass, the damage-per-second is
`integrity / survivability`, and fault thresholds are fractions of integrity. A trawler declares 90 and gets a
tougher hull, a raider declares 25 and gets a fragile fast one — no second set of constants. A hand-written
damage number on a later hull breaks the same promise `VesselPhysics` protects.

### Exposure and the damage curve

```
exposure = clamp((260 - distance) / 260, 0, 1)     0 at the band edge, 1 at distance 0, saturating below
rate     = (integrityMax / survivability) * exposure^2
```

Squared, not linear, because decision 0014 requires the curve be *"steep enough that lingering is never a
shortcut for extra looting"*. At half penetration the hull takes a quarter rate — a crew can dip into the
front's edge and live, which is the interesting decision. Deep inside it is fatal fast, which is the
uninteresting one, correctly punished.

### Faults: what has teeth today, and what is honestly a stub

The intake names engine cut, radar loss, breach and generator trouble. Two of those have nothing to act on
yet — `GAME-0002 Radar Mk1` is `PLANNED` and the vessel's `light` socket is empty, so there is no radar to
lose and no lights for a generator to stop powering. Building them as flags now and pretending they bite
would be the worse choice, so:

| Fault | Effect | Real today? |
|---|---|---|
| **Engine cut** | thrust to zero for 6–10 s, then relights | ✅ real |
| **Hull breach** | flooding rises; buoyancy per point scaled by `(1 - flooding * 0.35)`, so she sits lower and takes green water | ✅ real |
| **Steering damage** | rudder authority cut ~55%; she answers the wheel slowly, which is a genuine escape problem | ✅ real — **added to the intake's list**, because it is implementable and two of the four named faults are not |
| **Radar loss** | `VesselFaultRadar` attribute; honoured by GAME-0002 when it lands | ⬜ flag + documented stub |
| **Generator trouble** | `VesselFaultGenerator` attribute; will kill deck lights and radar power when those exist | ⬜ flag + documented stub |

Order is **deterministic, not random**: radar → generator → engine cut → breach, fired at 20 / 40 / 60 / 75 %
integrity lost. Deterministic because a randomised order makes the 30–60 s target unmeasurable and the failure
unlearnable; the escalation is also *designed* — you lose the number, then the light, then the ability to run,
then the floor. A seeded per-run shuffle can come later if it reads as too scripted.

Faults the crew can act on: a **damage-control point** on the aft deck (uses the empty `station`-kind socket
pattern), `ProximityPrompt`, 3-second hold — clears the oldest active fault and returns a slice of integrity.
Deliberately minimal: group 03's repair kits and their resource cost replace the free hold later.

### Two failure states, not one

- **Integrity zero** → vessel lost.
- **Capsize** → sustained tilt past ~100° for 4 s → vessel lost. `VesselServer` already flags this as owed
  work: *"a full capsize is unrecoverable… capsizing belongs to the storm-damage job as a real failure state
  rather than being papered over by a constraint here."* This job is where that promise comes due.

### 🟡 Vessel loss has no end-of-expedition flow to hand off to

Decisions [0008](../../docs/decisions/0008-progression-model.md) and
[0011](../../docs/decisions/0011-shared-expedition-rewards.md) say run power resets and permanent progression
is credited per player — but nothing implements an expedition end, and the lobby is a **separate place** with
no `TeleportService` flow built. So vessel loss cannot do the real thing yet.

Scoped honestly: loss kills the engine and the helm, stops buoyancy so the hull sinks, sets `ExpeditionOver`,
and prints a run summary. A todo is logged for the real end-of-expedition + teleport-home flow. I will not
invent progression rules inside a storm-damage job.

### The compass — in scope, and why

Decision 0014's blind-navigation clause has a hard requirement attached: *"the compass and chart must be
self-lit and readable in darkness, or the blindness is free"*, and the storm doc adds *"the compass cannot be
destroyed, and nothing targets it"*. Without one, The Wall is not a navigation problem — it is a guess, and
the 30–60 s escape becomes unmeasurable because there is no way to steer north on purpose.

So this job builds a **minimal self-lit compass card on the helm console** — a `SurfaceGui`, needle driven
client-side from the hull's own orientation. Diegetic by construction: readable only while standing at the
helm, never a screen overlay, so it cannot become the HUD readout decision 0014 forbids. Exempt from every
fault by construction — no fault touches it, and the code says so.

This is slightly wider than the intake's literal wording; flagging it rather than doing it quietly. The
polished instrument is a group 02 item and this is not it.

---

## Implementation steps

1. **Fix `WorldTick.vesselZ()`** to find the real hull, and delete the stale "there is no vessel yet" comment.
   Verify by construction: `StormDistance` must *rise* while driving north. Log a finding — the storm's central
   mechanic was silently inert from job 021 to now.
2. **Stop publishing `VesselHeading`** to Workspace; move it into `_G.TideVessel.report()` only. Comment it
   with decision 0014's rule so it is not re-added.
3. **`Vessel.luau`** — add `survivability` to `Spec` (with the reasoning comment) and `45` to the starter
   launch. Add a `damageControl` socket of kind `station` to its socket table.
4. **`VesselDamage.luau`** (new) — `integrityFor(spec, mass)`, `damageRate(spec, exposure)`,
   `faultSchedule()`, `floodingBuoyancyFactor(flooding)`, `isCapsized(cframe, seconds)`, `report()`. Pure;
   no instances, no attribute writes.
5. **`StormFront.exposure()`** — derived from the same distance the bands use, plus an `exposure` line in
   `StormFront.report()`.
6. **`VesselServer`** — accumulate damage per step from exposure; apply flooding to the per-point float force
   *inside* the existing clamp (never by editing `state.stiffness`, which would break the derivation and risk
   the divergence that already destroyed the hull once); engine-cut and steering faults as timed multipliers on
   throttle and `rudderAuthority`; capsize timer; loss handler. Publish `VesselIntegrity`,
   `VesselIntegrityMax`, `VesselFlooding`, `VesselFault*`, `ExpeditionOver`.
7. **Damage-control point** — part welded at the new socket, `ProximityPrompt` hold 3 s, clears the oldest
   fault and restores integrity. Server-side handler; the client sends nothing.
8. **Self-lit compass** on the helm console — `SurfaceGui` card, needle from `hull.CFrame` client-side, and a
   comment recording that nothing may ever fault it.
9. **Admin tools** (`Vessel` section unless noted):
   - `vesselDamageSet` — integrity to full / 75% / 25% / critical
   - `vesselFault` — inflict engine / generator / radar / breach / steering, or repair all
   - `vesselDamageReport` — integrity, flooding, active faults, exposure, seconds to loss at current rate
   - `stormSurvivalTest` (`Storm`) — **the measured one.** Pins the front inside The Wall, opens full throttle
     due north, samples until the hull clears band 4 or is lost, and reports seconds-to-escape and integrity
     remaining against decision 0014's 30–60 s window. Same discipline as `vesselStability`: this is not
     judgeable by eye.
10. **Docs** — decision 0023 recording the damage model and the three scope calls (steering fault added, two
    faults stubbed, loss outcome placeheld); `docs/systems/vessels/damage.md`; feature `0003-storm-front`
    and `0001-boat-controller` frontmatter and notes; tick the three manifest rows in
    [07-atmosphere](../../docs/build/07-atmosphere.md); re-run `python tools/build-status.py`.
11. **Findings/todos** — finding for the `vesselZ` bug; todo for the end-of-expedition flow; todo for the
    two stubbed faults; todo for any storm-alarm audio (no channel exists and asset sourcing is yours).

---

## Rulings (2026-08-21)

| Question | Ruling |
|---|---|
| Starter launch `survivability` | **45 s** of continuous full exposure. Escape from distance 0 costs ~40% integrity; a crew that reacts immediately lives, one that dallies 20 s does not |
| Minimal self-lit compass on the helm console | **In scope.** Without it The Wall is a guess rather than a navigation problem, and the 30–60 s escape is unmeasurable |
| Vessel-loss outcome | **Placeholder + todo.** Engine and helm dead, buoyancy off, she sinks, `ExpeditionOver` set, run summary printed. The real end-of-expedition and teleport-home flow is logged, not invented here |

## What I need from you

- [x] **Go-ahead on the scope calls above** — ruled, see the table.
- [ ] **Studio open with both places synced, and no Play session running.** I will not start Play without
      saying so, and I will stop any session I start.
- [ ] Nothing to source. No new asset or audio ID is needed for this job; if a storm alarm turns out to be
      wanted, it becomes a spec for you rather than something I insert.

---

## Verification

Measured, not asserted. `VERIFIED` is not awarded for code merely written.

- [ ] **Storm distance rises while driving north** — the step-1 fix, checked by reading `StormDistance` before
      and after a run at full throttle. Without this nothing else in the job is meaningful.
- [ ] **`Storm → Survival test` reports an escape inside 30–60 s** from a standing start at distance 0, with
      integrity remaining above zero. Run it three times; a spread wider than a few seconds means something is
      still frame-rate dependent.
- [ ] **Lingering is fatal** — same test with the throttle shut: integrity reaches zero, loss fires, hull
      sinks, `ExpeditionOver` set.
- [ ] **Faults fire in order at their thresholds** and each one is observable: engine cut stops her, steering
      damage visibly slows the turn (compare yaw build against the pre-damage figure), breach drops her
      waterline.
- [ ] **Damage-control point clears a fault** on a 3-second hold, and returns integrity.
- [ ] **Buoyancy still converges under flooding** — `Vessel → Buoyancy stability check`, 60 s, with flooding
      pinned at maximum. Must report converging. This is the regression that matters most: flooding scales the
      float force, and a growing amplitude here means the same divergence that removed the hull in job 021.
- [ ] **No yaw leak** — after every force change, wheel amidships at full throttle for 20 s, heading drift
      under a couple of degrees ([finding 0019](../../findings/0019-a-large-torque-applied-in-a-body-relativ.md)).
- [ ] **The compass reads in the dark** at The Wall's brightness 0.30, from a standing position at the helm —
      by screenshot.
- [ ] **No heading anywhere on screen**, and `workspace:GetAttribute("VesselHeading")` returns `nil` from a
      client.
- [ ] **The 5-minute storm arrival is unchanged** — `Storm → Storm report` still shows advance 14 studs/s and
      gain 1.6/stud, and a stationary front still arrives in 300 s.
- [ ] Graybox audit and place-settings audit still clean; `build-status.py` re-run and committed by you.
