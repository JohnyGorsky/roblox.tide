# Final Summary — Job #023

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ The run exists end to end and is measured. Two pieces deliberately deferred (below).

The run — a corridor to voyage through, a storm on a leash, and three ways to end. Implements decisions
[0024](../../docs/decisions/0024-expedition-shape-and-pacing.md) and
[0025](../../docs/decisions/0025-ocean-is-a-corridor.md); mapped in
[systems/storm/the-run.md](../../docs/systems/storm/the-run.md).

## What it does

Before this job the storm started the instant the server did, there was nowhere to voyage to, and job 022's
vessel loss dead-ended — she sank, `ExpeditionOver` was set, and nothing read it.

Now: the run opens **ashore** with the front visible and stationary, taking the helm starts its clock, northing
is tracked, and the run resolves three ways with the cause recorded. Running dry is survivable at the cost of
time.

| Piece | |
|---|---|
**The corridor** | `OCEAN_HALF_EXTENT` became `OCEAN_EXTENT_X` + `OCEAN_EXTENT_Z`, with `SeaStates.insideOcean` the single owner. Filled Z 3,072 → 5,500 in 18 tiles, 0.34 s |
**The boarding gate** | `runStarted`, raised once by the helm prompt, read by `WorldTick` |
**The run** | `Expedition.luau` (pure) + `ExpeditionServer` — states, northing, causes, the summary |
**The endings** | finished / lost, with *out of fuel* as a cause rather than a fourth path |
**Stranded** | `TenderServer` — a 6 studs/s fuel-free tender, 4 barrels at 200–400 studs, a filler on the launch |
**The beat** | `ExpeditionClient` — the screen holds on what just happened |
**Admin** | 5 tools in a new **Expedition** section, ordered first. 49 tools total |

## Measured

| Check | Result |
|---|---|
Corridor continuity | water continuous through the old seam at 3,072, ends exactly at 5,500, edges at ±3,072 |
Waves reach the whole corridor | real waves through Z=5,400, **flat from 5,600** |
Grace holds | **0.00 drift** over 12 s, parked at 4,200 |
Storm starts on boarding | **−14.09 studs/s** |
Releasing the helm does not stop it | **−14.05 studs/s** — the exploit is closed |
Run resolves | **Finished / northing at 2,402 of 2,400 in 144 s**, ending with 3,097 studs of water still ahead |
Tender speed | **4.82 studs/s** settled against the 8.75 break-even |
Tender cannot escape | front still closing at **−13.80 studs/s** while it ran flat out |
End-of-run beat | fires, and labels the fuel cause correctly |
Job 022 not regressed | survival and buoyancy checks re-run |

## The three things worth remembering

**1. Progress cannot be storm distance.** `StormFront.advance` ends with
`math.min(distance, START_DISTANCE)` — the cap that stops an early lead becoming un-loseable also means the
number **stops rising** at 4,200. A crew could sail north for ten minutes and it would not move. So a run
measures its own net displacement, and *net* rather than accumulated, because counting only northward deltas
(as the storm does) would let a crew farm progress by oscillating.

**2. `insideOcean` was the change that could have shipped silently.** It tested `abs(z) <= 3072` against the
east–west half-extent, so **everything north of 3,072 would have returned flat water** — the hull would have
stopped floating on waves halfway up the voyage, with no error anywhere. It now has one owner in `SeaStates`.

**3. The corridor invariant explains decision 0025's own number.** The rule is
`OCEAN_EXTENT_Z.max ≥ target + largest fogEnd`, because a crew standing at the finish looking north must see
fog rather than the water stopping. That is 5,300 for the placeholder target, hence 5,500 — and it is *also*
what 12,000 was: a target of about 9,100 plus the same 2,900 of fog. The decision stated the figure without
the reason; now the reason is executable (`validateCorridorForTarget`) and the admin tool prints it on every
target change.

### One deliberate deviation from decision 0025

Filled to **5,500, not 12,000**. The full corridor is **+145% terrain** on a mobile-first game for a northing
target nobody has tuned; this is +40% and satisfies the invariant with 200 studs of margin. Recorded in
`SeaStates` beside the constant, with the rule for growing it.

## Judgement calls

**The tender got its own driver rather than becoming a second vessel in `VesselServer`.** That file holds one
`state` table referenced **203 times across 1,501 lines**, and it is the only code whose physics is measured
end to end (survival 45.5 s, escape 27.9 s, distance-gain 99.2%, buoyancy converging under full flooding).
Generalising it is a large refactor of exactly the place a regression is most expensive and least visible. The
plan pre-authorised this route. Accepted cost: the buoyancy loop exists twice — it reuses the pure modules, so
it inherits the clamp that stopped the launch destroying itself in job 021.

**A safety property worth not breaking:** the storm chases the *vessel*, so the tender's speed never even
enters the equation — a crew that rows off and leaves the launch loses it. Both guards hold, and the second
one is invisible unless someone writes it down.

## Deferred, deliberately

- **The passage home.** The beat has no exit because there is nowhere to go: the teleport and the lobby's
  breakdown are Planned 0002. The panel says so on screen rather than hanging silently.
- **The tender takes no storm damage.** Its spec declares `survivability = 12` and nothing applies it — damage
  lives in `VesselServer`'s loop and the tender has its own driver. A rowboat inside The Wall should certainly
  die.

### ✅ Auto-synced files

- `studio_game/ReplicatedStorage/Expedition.luau` *(new)*
- `studio_game/ReplicatedStorage/SeaStates.luau`
- `studio_game/ReplicatedStorage/WaveField.luau`
- `studio_game/ReplicatedStorage/Vessel.luau`
- `studio_game/ServerScriptService/ExpeditionServer.server.luau` *(new)*
- `studio_game/ServerScriptService/TenderServer.server.luau` *(new)*
- `studio_game/ServerScriptService/WorldTick.server.luau`
- `studio_game/ServerScriptService/VesselServer.server.luau`
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/` copy
- `studio_game/StarterPlayerScripts/ExpeditionClient.local.luau` *(new)*

### ⚠️ Manual Studio action required

- **Save the game place** — the corridor terrain is a place change, not source.

## Verification

- [x] Corridor filled, continuous, and ending where the constant says
- [x] Waves reach the whole corridor and go flat exactly at its end
- [x] The grace holds, the storm starts on boarding, and releasing the helm does not stop it
- [x] Northing drives the ending, and still works after `StormDistance` has capped
- [x] Out of fuel is labelled fuel, not hull
- [x] The tender cannot outrun the storm — measured two ways
- [x] Job 022's survival and buoyancy checks re-run clean
- [x] No new analyzer diagnostics; Play stopped; Studio left in Edit
- [ ] **A hands-on run** — everything went through the `VesselTestDrive` hook, because the client helm loop
      cannot run in an unfocused Studio session (finding 0022)
- [ ] The barrel carry-and-pour has never been exercised by a real `ProximityPrompt` hold
