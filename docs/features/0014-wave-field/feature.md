---
id: GAME-0014
name: Wave Field
area: sea
status: READY
priority: P0
depends_on: [GAME-0011]
assets: []
last_verified: null
---

# Wave Field

## Goal

A shared, deterministic function that answers **"how high is the sea at this point, right now, and which
way is the surface tilted?"** — `HeightAt(x, z, t)` and `NormalAt(x, z, t)`.

Everything that needs to sit on, bob in, or be thrown by the ocean samples this one function: the vessel,
floating debris, buoys, spray, the wake, and eventually swimming.

## Player value

None directly — and that is the point of building it before the boat. It is the difference between a
vessel that *rides* the sea and one that slides across a flat plane while painted waves pass through it.

## The problem it exists to solve

Roblox terrain water's waves are a **rendering effect**. They animate the surface visually and do not move
objects at all. So the sea has two independent truths:

| | Owned by | Player sees it as |
|---|---|---|
| Visual swell | `Terrain.WaterWaveSize` / `WaterWaveSpeed` | the water moving |
| Physical swell | **this feature** | the boat moving |

If these disagree the illusion breaks in a very specific, very visible way: the hull climbs a crest that
is not there, or punches through one that is.

`SeaStates.luau` already carries a `wave` block per state — amplitude, length, speed, choppiness,
direction spread — precisely so both truths come from one table. This feature is the consumer of that
block.

## Requirements

- [ ] `WaveField.HeightAt(x, z, t)` → surface Y in studs
- [ ] `WaveField.NormalAt(x, z, t)` → surface normal, for orienting a hull
- [ ] **Deterministic** — same inputs give the same answer on every client and the server, with no
      replication traffic. Derive time from a **synchronised clock** (`Workspace:GetServerTimeNow()`),
      never from a local `tick()` or per-client accumulator
- [ ] Driven by the active sea state's `wave` block, so the five states each feel different
- [ ] Smooth transition when the sea state changes or blends — no instant jump in surface height, which
      would launch or submerge a floating object
- [ ] **Calibrated against the visual water** — see below. Per sea state
- [ ] Cheap enough to sample **8–12 points per frame** (a hull needs several; debris needs one each)
- [ ] Sensible outside the ocean extent: return `WATER_Y`, never `nan`
- [ ] Debug visualiser: a grid of markers that sit on the sampled surface, so the maths can be *seen*
      against the rendered water
- [ ] Admin panel toggle for the visualiser (group 13 already lists it)

## The calibration step — do not skip this

We cannot change the *shape* of Roblox's visual waves, so the field has to be fitted to them rather than
the reverse. For each sea state:

1. Set the state's `WaterWaveSize` / `WaterWaveSpeed`.
2. Measure the **apparent** amplitude and wavelength of the rendered water — a line of thin markers at
   known heights, read from a screenshot at water level, is enough.
3. Tune that state's `wave.amplitude` / `wave.length` / `wave.speed` to match what the eye sees.
4. Record the measured numbers as comments beside the values, so a later change knows what it is breaking.

Two known mismatches to decide about rather than discover later:

- **Direction — decided.** A **dominant swell direction plus a spread that widens in rougher states**
  (2026-08-20). This is what real seas do, it is what `directionSpread` in `SeaStates` already implies,
  and it makes the helm a skill: heading into the swell, across it, or running with it must feel
  different. The visual mismatch is accepted, and it hides itself — spread is *narrowest* in the calm
  states, where amplitude is too small for anyone to notice the disagreement, and *widest* in The Wall,
  where the sea is confused enough that no pattern is legible anyway.
  Per-state direction is a new field. **Correcting my own wording from the plan:** the swell travels
  broadly *with* the direction of travel — northward, arriving from astern. Waves "opposing travel" would
  arrive from ahead, which is the opposite of a storm pushing you from behind. So: a **following sea**,
  which is also the more interesting one to steer, because following seas make a small vessel yaw.
- **Choppiness.** `choppiness` and `directionSpread` in `SeaStates` have no visual counterpart at all.
  They will only ever be felt through the boat, which is fine — but they must not be tuned by eye.

## Out of scope

Buoyancy and the boat's response — that is GAME-0001 (manifest group
[02](../../build/02-boat-parts.md)). This feature only *answers questions* about the surface; it applies
no forces and moves nothing.

Whitecaps, spray and wake belong to group 01's surface-detail job, though they will sample this field.

## Roblox touchpoints

`ReplicatedStorage.WaveField` (new module), `ReplicatedStorage.SeaStates` (the `wave` block),
`Workspace:GetServerTimeNow()`.

## Acceptance criteria

- [ ] Server and a client sampling the same `(x, z, t)` return the same height to within a rounding error
- [ ] Debug markers visually sit on the rendered water surface in every sea state, not above or below it
- [ ] Switching or blending states moves the surface smoothly
- [ ] 12 samples per frame cost is measured and acceptable on a phone
- [ ] Sampling far outside the ocean returns `WATER_Y` and never errors

## Verification

Never mark VERIFIED without a real Studio check. The specific test that matters: **stand the debug grid on
the water in all five states and screenshot each.** If the markers float or sink, the field and the visuals
disagree and the boat will look wrong later.
