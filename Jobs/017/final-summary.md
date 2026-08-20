# Final Summary — Job #017

**Project**: `roblox.tide`
**Completed**: 2026-08-20 14:35:20
**Status**: ✅ Completed

## What was implemented

The front now moves, the world now ticks, and the approach is felt rather than only measured. STORM FRONT per decision 0019: a timer advance of 14 studs/s with 1.6 studs of distance bought per stud travelled north, so at ~12 studs/s cruise a vessel nets +5.2 studs/s and standing still loses 14/s. Verified exactly: 60 seconds stopped costs 840 studs, 60 seconds at cruise from 2000 gives 2312 which matches the predicted 2000 + 60x5.2 to the stud, shelter costs exactly 30% of the unsheltered rate, and running SOUTH gains nothing but is not double-punished either. Distance is clamped at the 4200 start so an early lead cannot become un-loseable. Five intensity bands, deliberately uneven - the outer ones wide so most of a run sits at 0-1, the inner ones narrow so the last stretch escalates fast; a linear ramp would make the whole expedition feel uniformly threatened, which is the same mistake as a storm that cannot be outrun. WORLD TICK closes the loose end job 016 left: compose() had no caller, so the sky only changed when something happened to poke it. One loop at 1 Hz, and the ORDER is load-bearing - storm first so it sets the sea state, then the composer reads it; reversed, the sky lags the storm by a second. WIND is the new idea and the reason the sensory half holds together: a single 0-1 value on a Workspace attribute that everything reads, so rain, spray, debris, audio and later the boat's handling can never disagree about how bad it is. Published at 1 Hz and smoothed client-side, because a storm arriving in one-second steps reads as a bug. APPROACH VISUALS, per the user's addition: rain scaling quadratically 0 to 865 so it is almost absent until it matters, spray gating on above wind 0.25 because it means the tops are coming off the sea, and wind-blown debris above 0.6 only. The strongest cue turned out to be rain ANGLE rather than density - 31 degrees from vertical at light wind, 60 at half, 74 at full - because a player reads direction instantly whereas densities have to be compared against a memory. Everything is camera-local rather than world-wide: a player only ever sees a few hundred studs, and filling 6 km of ocean with emitters would cost everything and show nothing. NOT DONE, and honestly out of scope for one job: the horizon cloud wall (needs art), screen-level rain streaks, audio hooks, and lightning. Panel is now 23 tools with a Storm section that moves the front and toggles shelter, and it does so by moving the front rather than by writing lighting - the same one-directional flow the real game uses.

### Files changed

- `studio_game/ReplicatedStorage/StormFront.luau`
- `studio_game/ReplicatedStorage/StormVFX.luau`
- `studio_game/ServerScriptService/WorldTick.server.luau`
- `studio_game/ServerStorage/AdminTools.luau`
- `studio_lobby/ServerStorage/AdminTools.luau`
- `docs/decisions/0019-storm-advance-model.md`

### Driving it

**Storm** section in the panel: distance (4.2 km → 0.15 km), shelter toggle, status readout.
The front moves and everything else follows — sea state, sky, fog, wind, rain.

### The number to tune when it feels wrong

`ADVANCE_RATE` (14 studs/s) against `GAIN_PER_STUD` (1.6). Their ratio decides how much looting an
expedition affords:

```text
at 12 studs/s northward   ->  +5.2 studs/s   (slowly pulling away)
stopped                   ->  -14 studs/s
60-second island visit    ->  costs 840 studs, ~20% of the starting cushion
```

Looting is spent distance. **Fuel is therefore the real currency** — no fuel means no progress means the
front closes at full rate, so fuel scarcity has to be tuned *with* the storm, not separately.

### Not done — honestly out of scope for one job

- **Horizon cloud wall** — needs art. The biggest remaining piece of the approach
- Screen-level rain streaks and spray on the camera
- Audio hooks (the rumble should track the same wind value)
- Lightning

## Verification

- [x] 60 s stopped costs exactly 840 studs
- [x] 60 s at 12 studs/s from 2000 → **2312**, matching the predicted 2000 + 60×5.2 to the stud
- [x] Shelter costs exactly **30%** of the unsheltered rate
- [x] Southward travel gains nothing, but is not double-punished
- [x] Distance clamps at the 4200 start — an early lead cannot become un-loseable
- [x] All five bands map to the right intensity and sea state
- [x] Wind rises 0.00 → 0.25 → 0.49 → 0.74 → 0.98 across the bands
- [x] Rain quadratic 0→865; spray gates above 0.25; debris above 0.6
- [x] Rain angle 31° → 60° → 74° from vertical
- [x] VFX cleans up fully on stop
- [x] 23 tools register; registry validates
- [ ] Seen running in Play — **my Play control wedges; yours will work**
- [ ] The approach judged by eye — **yours**
