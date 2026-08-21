# The run: a corridor, a storm on a leash, and three ways to end

Implementation reference for [decision 0024](../../decisions/0024-expedition-shape-and-pacing.md) (the
expedition's shape) and [0025](../../decisions/0025-ocean-is-a-corridor.md) (the ocean). Built in job 023.

## Where it lives

| File | Owns |
|---|---|
`ReplicatedStorage/Expedition.luau` | the run-state model. Pure — states, causes, northing, the summary shape |
`ServerScriptService/ExpeditionServer.server.luau` | the run: spawns crew ashore, watches northing, resolves the ending, publishes the summary |
`StarterPlayerScripts/ExpeditionClient.local.luau` | the in-place beat when a run ends |
`ServerScriptService/TenderServer.server.luau` | the rescue loop — the fuel-free tender, drifting barrels, the filler |
`ReplicatedStorage/SeaStates.luau` | the corridor's extents and the two invariants that govern them |
`ServerScriptService/WorldTick.server.luau` | the boarding gate — where the storm's clock is allowed to run |
`ServerScriptService/VesselServer.server.luau` | raises the gate, once, when the helm is first taken |

## The three numbers that govern the world

```
OCEAN_EXTENT_X       ±3,072          east–west, unchanged, and the FOG constraint
OCEAN_EXTENT_Z       −1,000 … 5,500  the corridor the expedition travels along
NORTHING_TARGET      2,400           a PLACEHOLDER — see below
```

Two invariants, both enforceable in code rather than by memory:

**1. Fog must stay inside the water** (`validateFogWithinOcean`, the rule from job 007). The nearest edge is
east–west and does not change as the corridor grows, so `OCEAN_HALF_EXTENT` is retained and still means
exactly what every fog check needs.

**2. The corridor must hold the run** (`validateCorridorForTarget`):

> `OCEAN_EXTENT_Z.max ≥ northing target + the largest fogEnd`

Because a crew standing *at* the finish and looking north must still see fog rather than the water stopping.
2,400 + 2,900 = 5,300, hence 5,500 with 200 studs of margin.

This rule also explains decision 0025's own figure of 12,000, which the decision did not spell out: it is a
target of about 9,100 plus the same 2,900 of fog. **Grow the target and the water together** — the admin tool
prints the check on every target change.

🔴 **If the constant claims water that is not filled**, `WaveField.HeightAt` returns flat `WATER_Y` out there:
the hull stops floating on a sea and starts floating on a plane, and it reads as the wave field breaking rather
than as running out of world.

## Progress is net northing, not storm distance

`StormFront.advance` ends with `distance = math.min(distance, START_DISTANCE)`. That cap stops an early lead
becoming un-loseable — and it means the number **stops rising** once the crew is 4,200 ahead. A crew could sail
north for ten minutes and it would not move.

So a run measures its own displacement, `hull.Z − startZ`, captured when the helm is first taken.

**Net** displacement, not accumulated northward deltas. `StormFront` deliberately counts only northward travel;
copying that here would let a crew farm progress by oscillating north and south. Net Z cannot be farmed.

## The boarding gate

```
storm advances  ==  runStarted AND NOT expeditionOver
```

`runStarted` is raised **once**, server-side, by the helm prompt, and only `ExpeditionServer.beginBoarding`
may lower it — a path not reachable during a run. Two ways to get this wrong, both of which switch off the
game's only pressure:

- clearing it when the driver steps away — stand up, and the storm politely waits
- letting a client raise or lower it

The lobby is the same idea taken further: it ships no `StormFront` at all, so there is nothing there to
advance (job 025).

## The endings: two paths and a cause

- **finished** — northing ≥ target → the placeholder finale → resolve
- **lost** — job 022's `loseVessel` fires; `ExpeditionServer` decides the *run* is over
- **out of fuel** — **a cause, not a path.** Adrift, the front closes at 14 studs/s, arrives, and integrity
  drains in 45 s: it terminates in `lost` on its own. It is recorded as a cause so the summary says "ran out
  of fuel" rather than "hull destroyed", because that is the story decision 0024 is built around

🔴 **`ExpeditionOver` has one owner.** Job 022 set it directly as an admitted placeholder; that write moved to
`ExpeditionServer`. `VesselServer` says *the vessel is lost*, which is a different statement from *the run is
over*. Two writers for one flag is how a run ends twice.

## Stranded: the tender

| | |
|---|---|
Tender cruise | **6 studs/s**, and the ceiling is 8.75 |
Break-even | `ADVANCE_RATE / GAIN_PER_STUD` = 14 / 1.6 = **8.75 studs/s** |
Barrels | 4, at 200–400 studs, 35 fuel each |
Round-trip cost | 22–44% of the storm's cushion |

🔴 **A fuel-free boat faster than 8.75 gains ground on the storm forever**, which makes the launch — and the
whole fuel economy it exists to consume — pointless.

There is a second guard that comes free: **`StormFront` chases the vessel**, reading its Z through
`_G.TideVessel`. So a crew that rows away and leaves the launch does not escape; the front closes on the
launch and the run ends. Abandoning the ship *is* losing. Measured: the front kept closing at −13.80 studs/s
while the tender ran flat out. **If a future job ever makes the storm chase players instead, this mechanic
becomes an exploit.**

The tender has **its own driver** rather than being a second vessel inside `VesselServer`, which holds one
`state` table referenced 203 times across 1,501 lines — the only file whose physics is measured end to end.
It reuses the pure modules, so it inherits the force clamp that stopped the launch destroying itself in job
021. Accepted cost: the buoyancy loop exists twice.

## Testing it

`Expedition` section in the admin panel, ordered first:

- **Run status** — northing, target, state, cause, the corridor check
- **Northing target** — 300 (quick test) / 1200 / 2400 / 5000, and it prints the corridor rule every time
- **Start the storm now** — skips the walk to the helm
- **Force an ending** — each of the five outcomes, so a summary can be checked without sailing for it
- **Reset to boarding** — the one path that hands the grace back

## Measured 2026-08-21

| Check | Result |
|---|---|
Corridor filled | Z 3,072 → 5,500 in 18 tiles, 0.34 s. Continuous through the old seam; ends exactly at 5,500 |
Waves reach the whole corridor | real waves through Z=5,400, flat from 5,600 |
Grace holds | 0.00 drift over 12 s at 4,200 |
Storm starts on boarding | −14.09 studs/s |
Releasing the helm does **not** stop it | −14.05 studs/s |
Run resolves | **Finished / northing at 2,402 of 2,400 in 144 s**, 3,097 studs of water still ahead |
Tender speed | 4.82 studs/s settled, front still closing at −13.80 |
End-of-run beat | fires, and labels the fuel cause correctly |

## Traps

🔴 **Never measure progress with storm distance** — the cap makes it stop rising.

🔴 **The gate is one-way.** Only `beginBoarding` lowers it.

🔴 **`insideOcean` has one owner** (`SeaStates`). It used to be duplicated in `WaveField` as a square bound,
which would have reported everything north of 3,072 as outside the ocean.

🔴 **Grow the corridor and the target together**, or the crew sails to a flat plane.

## Still owed

- The in-place beat has **no exit** — the teleport home and the lobby's breakdown are Planned 0002
- The tender takes **no storm damage** (its spec declares `survivability = 12`, unwired). A rowboat inside The
  Wall should certainly die
- The northing target is a **placeholder**; the real figure is decision 0024's ~50-minute run
- The finale is a placeholder; the boss is groups 05 and 06
