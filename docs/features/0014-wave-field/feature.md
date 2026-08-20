---
id: GAME-0014
name: Wave Field
area: sea
status: IN_PROGRESS
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

### Proven 2026-08-20: the rendered swell exists *only* in the shader

A raycast against terrain water returns a perfectly flat plane at `WATER_Y`, always. Measured: 12
raycasts across 450 studs gave a spread of **0.000000**; the same point sampled repeatedly over half a
second gave **0.000000**; and `WaterWaveSize` at its maximum of 1.4 still returned exactly **0.0000**.

So this module is not one of two truths — **it is the only non-flat truth about the sea.** Every Roblox
system believes the water is a flat plane at Y=0.

Three consequences:

1. **Exact calibration is impossible in principle**, not merely fiddly. Nothing can report the rendered
   height, so it can only be judged by eye against a physical ruler in a screenshot. The tolerance is
   generous, because nothing in the engine can betray a mismatch except the player.
2. **⚠️ Auto-buoyancy will fight this field.** Terrain water floats objects toward that flat Y=0 plane. A
   hull driven by `WaveField` while also subject to engine buoyancy has two systems pulling it to
   different heights — one to a flat plane, one to a moving crest. The symptom looks like inexplicable
   bobbing, not a design conflict. **GAME-0001 must make hull parts non-buoyant to the engine, or account
   for the engine's contribution explicitly.** This is the mechanism behind the `roblox-physics` advice not
   to rely on terrain-water auto-buoyancy.
3. Debris and props that only need to *look* afloat can keep using auto-buoyancy — it is free, and at
   Y=0 it is close enough for anything small.

`SeaStates.luau` already carries a `wave` block per state — amplitude, length, speed, choppiness,
direction spread — precisely so both truths come from one table. This feature is the consumer of that
block.

## Requirements

- [x] `WaveField.HeightAt(x, z, t)` → surface Y in studs
- [x] `WaveField.NormalAt(x, z, t)` → surface normal, for orienting a hull
- [ ] **Deterministic** — same inputs give the same answer on every client and the server, with no
      replication traffic. Derive time from a **synchronised clock** (`Workspace:GetServerTimeNow()`),
      never from a local `tick()` or per-client accumulator
- [x] Driven by the active sea state's `wave` block, so the five states each feel different
- [x] Smooth transition when the sea state changes or blends — no instant jump in surface height, which
      would launch or submerge a floating object
- [ ] **Calibrated against the visual water** — see below. Per sea state
- [ ] Cheap enough to sample **8–12 points per frame** (a hull needs several; debris needs one each)
- [x] Sensible outside the ocean extent: return `WATER_Y`, never `nan`
- [x] Debug visualiser: a grid of markers that sit on the sampled surface, so the maths can be *seen*
      against the rendered water
- [x] Admin panel toggle for the visualiser (group 13 already lists it)

## The calibration step — do not skip this

We cannot change the *shape* of Roblox's visual waves, so the field has to be fitted to them rather than
the reverse. For each sea state:

1. Set the state's `WaterWaveSize` / `WaterWaveSpeed`.
2. Measure the **apparent** amplitude and wavelength of the rendered water with a **vertical ruler**: a
   ladder of thin markers at known Y values, screenshotted from water level, so it is visible which
   height the crests actually reach. This is the only way in — the rendered amplitude is not readable
   from any property; `WaterWaveSize` is a dimensionless dial, not studs.
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
- [ ] Debug markers' **envelope and wavelength** match the rendered water in every sea state
      *(corrected 2026-08-20: the original wording said markers must "sit on the rendered surface", which is
      impossible — Roblox does not expose its water's wave phase, so our field can never be phase-aligned
      to it. What is achievable, and what actually matters, is that the crest-to-trough range and the
      apparent distance between crests agree. Point-for-point alignment is not a goal.)*
- [ ] Switching or blending states moves the surface smoothly
- [ ] 12 samples per frame cost is measured and acceptable on a phone
- [x] Sampling far outside the ocean returns `WATER_Y` and never errors

## Verification

Never mark VERIFIED without a real Studio check. The specific test that matters: **put the debug grid and
the ruler on the water in all five states and screenshot each.** Compare the marker cloud's vertical
*envelope* against where the rendered crests reach on the ruler. If the envelopes disagree, the boat will
climb crests that are not there.

Do **not** expect the markers to sit on individual visible crests — see the corrected criterion above.

Already verified in Edit (job 012, 2026-08-20): determinism identical across repeat calls; `directionDeg`
present on all five states and interpolated by `lerp`; out-of-bounds returns `WATER_Y`, never `nan`;
normals vertical in Dead Calm (y = 1.00000) and tilted in The Wall (y = 0.88); measured crest-to-trough
86–98% of `amplitude × 2`, the shortfall being finite-grid sampling rather than a normalisation error;
12 `HeightAt` calls cost 0.0126 ms, which is 0.08% of a 60 fps frame.

## Status note — 2026-08-20

`WaveField.luau` is built and in use: `HeightAt`, `NormalAt`, `SurfaceAt`, `SubmersionAt`, `measureRange`,
plus `WaveFieldDebug` (`showGrid` / `showRuler` / `report`) and panel toggles. State and blend live on
Workspace attributes so every context agrees, and job 018 added `SeaStates.currentBlended()` so the field,
the composer and everyday weather share one blend. Everyday weather scales amplitude through a single point
in `currentWave()`, so height and normals can never disagree.

**Still genuinely open, and all three need the boat or a phone:**

- calibration of the field against the *rendered* water per sea state (the envelope/wavelength match)
- the 8–12 samples-per-frame cost measured on a real phone
- server/client agreement measured in a live session rather than reasoned about

Those are why this is not `IMPLEMENTED`. Nothing floats on it yet, so its accuracy has never actually
mattered — group 02 is what will expose it.
