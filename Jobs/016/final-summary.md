# Final Summary — Job #016

**Project**: `roblox.tide`
**Completed**: 2026-08-20 14:23:50
**Status**: ✅ Completed

## What was implemented

The clock and the composer, built as one module because they cannot be separated - both want to write Lighting, and whoever writes last wins with a bug that looks like a flicker rather than a conflict. DayNight.compose() is now the single writer. CLOCK: dawn 40s, day 280s, dusk 45s, night 210s = 575s, a 9.6 minute cycle giving a 29 minute three-cycle expedition, matching the POC target. Dawn and dusk are deliberately short - they are punctuation, and a warning that lasts four minutes is not a warning. State lives on Workspace attributes for the same reason WaveField's does: per-context module copies would let server and clients disagree about the hour. Includes pause, resume and jump-to-phase, with a resume that shifts the start so no cycle time passes while frozen. Phase looks blend across the last 25% of each phase so dusk arrives rather than cutting; ClockTime snaps at the halfway point instead of lerping, because 17.8 to 0.4 would run backwards through noon. COMPOSITION, and this took three attempts because two properties pull against each other. Attempt one blended toward the sea state's absolute values and made the night BRIGHTER as weather worsened - clear night 0.70, Light Swell night 1.04, Choppy night 1.47 - because those numbers were authored for daytime and were being used as blend targets at any hour. Attempt two read each state as a RATIO against the reference sea, which fixed the brightening at every hour but destroyed timelessness, because a ratio always multiplies whatever base it lands on: The Wall came out 0.87 by day and 0.23 at night. Attempt three keeps the ratio below severity 0.9 and switches to the state's absolute values above it - a switch rather than a curve, because the two properties live at opposite ends of the range and the threshold only ever catches The Wall, which is exactly the state that should not know the time. That exposed a fourth thing: The Wall's absolute brightness was 1.0, a daytime number, so entering the front at night still brightened it (night Storm 0.44, night Wall 1.00). Set to 0.30, which is darker than the darkest hour and is also the right design answer, since 'you cannot tell noon from midnight' means noon must look like midnight. ALL THREE PROPERTIES NOW HOLD TOGETHER: weather never brightens any hour (verified monotonic across all four phases x five states), The Wall is identical at dawn, day, dusk and night (0.30 / fog 330 / BlackVoid), and a calm night reads as night at 3.7x darker than day with the NightFog sky rather than the day sky.

### Files changed

- `studio_game/ReplicatedStorage/DayNight.luau`
- `studio_game/ReplicatedStorage/SeaStates.luau`
- `docs/decisions/0018-time-base-weather-override.md`

### 🔴 One rule this job creates

**`DayNight.compose()` is the only thing allowed to write `Lighting`.** `SeaStates.apply()` still owns the
*values* for each weather, but it must hand them over rather than apply them. Anything else that sets
`Lighting.FogEnd` will be overwritten on the next tick, and the bug will present as a flicker rather than
as two systems disagreeing.

### Still to wire

`compose()` needs calling ~1/second from a server script. Not done yet — there is no server tick for it,
so the look currently only updates when something calls it. That is the first thing the storm job needs.

## Verification

- [x] Cycle = 575 s (9.6 min); three cycles = 29 min, matching the POC target
- [x] **Property 1:** weather never brightens any hour — monotonic across 4 phases × 5 states
- [x] **Property 2:** The Wall identical at dawn/day/dusk/night (0.30 / fog 330 / BlackVoid)
- [x] **Property 3:** calm night reads as night — 3.7× darker than day, NightFog sky not the day sky
- [x] Fog falls with severity too; sky switches at the 0.4 threshold, between Light Swell and Choppy
- [x] `severity` on all five states, carried through `lerp`
- [ ] Server tick calling `compose()` — **not built yet**
- [ ] Judged by eye across a full cycle — **yours**; my captures exceed the API size limit at your
      current Studio window size
