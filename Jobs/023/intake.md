# Job #023: The run — a corridor to voyage, a storm on a leash, and three ways to end

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Re-scoped**: 2026-08-21 — see *Why this changed*
**Status**: ✅ Complete — see [final-summary.md](final-summary.md)

## Why this changed

This started as "the expedition loop", covering both places. Two rulings then conflicted: split at A|B with
**023 = the lobby**, and **wait for the sculpt** rather than graybox the island. The lobby half is exactly the
half that needs the island, so 023 would have begun blocked.

So the halves were swapped. **023 is the game-place half** — no art, no second player, measurable from a
probe the way job 022 was. The lobby and departure wait in
[Planned 0002](../../Planned/0002-lobby-place-and-departure.md) until the island is sculpted.

## Requirements / goal

Make a run into a run. After job 022 the game has a sea, a storm with teeth and a drivable vessel, but the
storm starts the instant the server does, there is nowhere to voyage to, and vessel loss dead-ends — she sinks,
`ExpeditionOver` is set, and nothing reads it.

Scope, all in the **game place**:

1. **Grow the ocean into a corridor** — decision 0025. X unchanged at ±3,072, Z from −1,000 north. (Shipped at 5,500 rather than 0025's 12,000 — the
   corridor invariant plus a mobile terrain budget; see the final summary.)
   `OCEAN_HALF_EXTENT` becomes two extents. The Z extent must cover the whole voyage, because
   `WaveField.HeightAt` returns flat water outside the patch and a hull that reaches the end stops floating on
   waves at all.

2. **The boarding grace** — decision 0024. The run opens on a small island with the front visible and
   **stationary**; taking the helm starts its clock. The gate must be **server-owned and one-way**: a crew
   leaving the helm must not be able to pause the storm.

3. **Northing, and a placeholder finale.** Track net northing (`hull.Z − startZ`), and resolve the run as
   finished when it passes a tunable target. It is a *placeholder* — decision 0024 ends the run by defeating a
   vessel, and the boss slots in behind this same trigger later.

4. **The three endings**, as real states rather than a stuck session:
   - **finished** — northing reached
   - **lost** — job 022 already produces this; it needs somewhere to go
   - **out of fuel** — not a third path. Adrift, the front still closes, arrives, and integrity drains: it
     terminates in `lost` on its own. What it needs is to be recorded as a **cause**, so the summary says
     "ran out of fuel" rather than "hull destroyed"

5. **Being stranded is survivable, at a price** — decision 0024. A small wooden **tender** that burns no
   diesel, and **fuel barrels drifting** 200–400 studs out. The crew rows for fuel and pays in time.
   🔴 The tender must stay **under 8.75 studs/s**, the storm's break-even speed, or a fuel-free boat outruns
   the front forever and the whole vessel becomes pointless.

6. **The in-place summary beat** — the game-place half of the split summary. She goes down, or you make your
   northing, and the screen holds. The lobby breakdown belongs to Planned 0002.

7. **Admin tools** to drive all of it: set northing, force each ending, start the storm early, run report.

Hard constraints:

- Server-authoritative. A client may request; it never decides.
- Do not break the storm's 5-minute arrival or job 022's measured damage curve (survival 45.5 s, escape
  27.9 s, distance-gain 99.2% of theory). Re-run the survival test after touching `StormFront`.
- `StormFront.reset` must keep clearing the last position rather than zeroing it, or arrival hands out free
  distance.
- The distance cap `math.min(distance, START_DISTANCE)` stays. It is what makes the threat permanently five
  minutes away instead of bankable.
- Terrain is a **saved-place change**, and nothing in the MCP can inspect a saved `.rbxl`. Grow it, read the
  voxels back, screenshot the horizon, save deliberately.

Out of scope, deliberately: DataStore persistence (nothing decision 0008 calls permanent progression exists
yet), the lobby, departure, the return teleport, and the finale vessel itself.

## What is grayboxed

| Id | Stands in for | Place | Note |
|---|---|---|---|
| `GB-GAME-START-ISLAND` | `ASSET-START-ISLAND` | game | ✅ Built and registered in job 024 |
| `GB-TENDER` | `ASSET-BOAT-TENDER` | game | The fuel-free rescue boat. A box until it earns a model |
| `GB-FUEL-BARREL` | `ASSET-FUEL-BARREL` | game | Drifting barrels. Group 03 already plans a real jerry can and barrel |
| `GB-STARTER-LAUNCH` | `ASSET-BOAT-STARTER` | game | Already registered, job 022. Unchanged |

`GB-GAME-DECK` should probably be **retired** here: its own registry note says to delete it once `GAME-0001`
lands, which it has, and decision 0024 replaces its purpose with the start island. It is editor-placed
geometry, so that deletion is the user's call.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Verified in a session — corridor continuous, grace holds, run resolved Finished at 2,402/2,400 in 144 s,
      tender 4.82 studs/s against the 8.75 break-even
- [x] Final summary + changelog written
- [ ] Two items deferred on purpose: the passage home (Planned 0002) and storm damage to the tender
