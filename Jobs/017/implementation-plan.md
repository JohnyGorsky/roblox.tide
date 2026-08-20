# Implementation Plan — Job #017

**Project**: `roblox.tide`
**Created**: 2026-08-20 14:30:46
**Status**: Planning (awaiting go-ahead)

## Analysis

Decision 0019 fixes the mechanics; the user's addition is that the APPROACH must be felt, not merely measured - special visuals for the incoming storm, decals, particles and rising wind. That reframes the job: the radar owns the number, and the WORLD owns the feeling. Those two channels are deliberately separate, because a crew with nobody at the radar should still know in their gut that something is coming. Architecture keeps the one-directional flow from decision 0018: StormFront computes distance and intensity, intensity selects a sea state, the state's severity drives the look through DayNight.compose(). The storm never writes Lighting. What it DOES own is wind, which is new and is the master control for everything sensory - rain angle, spray density, cloth, debris, audio level, and later the boat's handling. Wind goes on a Workspace attribute like the clock and the sea state, so every client's particles agree without traffic. Order of work matters: the position model and the server tick come first because nothing sensory can be tuned against a storm that does not move, then wind, then the visuals that read from it.

## Implementation steps

1. Write StormFront.luau: distance model (timer advance, northward travel buys distance back), intensity 0-4 from distance thresholds, intensity to sea state mapping, shelter rate modifier
2. Add the server tick: advance the front and call DayNight.compose() about once a second - the loose end job 016 left
3. Add the wind model: a single 0-1 value on a Workspace attribute, driven by intensity, that everything sensory reads from
4. Build the approach visuals driven by wind: rain that angles with it, sea spray, wind-blown debris crossing the deck, and the cloud wall on the horizon
5. Add screen-level effects for the close range: rain streaks and spray on the camera, used sparingly
6. Wire audio hooks so the rumble and wind level track the same wind value
7. Admin tools: force intensity, force distance, toggle the shelter modifier, and a readout of distance/intensity/wind
8. Verify the approach reads WITHOUT radar - the world alone should tell you it is coming

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
