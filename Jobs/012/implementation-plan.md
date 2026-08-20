# Implementation Plan — Job #012

**Project**: `roblox.tide`
**Created**: 2026-08-20 12:30:35
**Status**: Planning (awaiting go-ahead)

## Analysis

Feature GAME-0014. Build WaveField as a ReplicatedStorage module exposing HeightAt(x,z,t) and NormalAt(x,z,t), consumed later by the vessel, debris, spray and wake so there is exactly one definition of where the sea surface is. Determinism is the hard requirement: derive time from Workspace:GetServerTimeNow() so server and every client agree with zero replication traffic, and never from a local tick or a per-client accumulator. Sum a small number of Gerstner-style waves whose amplitude, wavelength, speed, choppiness and direction spread come from the active sea state's wave block, so all five states feel different and the physical sea cannot drift from the table the visuals also read. DECIDED 2026-08-20: the field has a dominant swell direction with a spread that widens in rougher states, rather than being omnidirectional - real seas behave that way, it makes heading into or across the swell a genuine helm skill, and the visual mismatch conveniently hides itself because spread is narrowest exactly where amplitude is too small to notice and widest where the sea is too confused to read a pattern. This adds a per-state direction field to SeaStates, broadly opposing travel so the storm reads as pushing from astern. The calibration step is part of the job, not a follow-up: the shape of Roblox's rendered waves cannot be changed, so the maths must be fitted to the visuals - measure the apparent amplitude and wavelength per state from a marker line read at water level, tune the wave block to match, and record the measured numbers as comments so a later change knows what it is breaking. Note that choppiness and directionSpread have no visual counterpart at all and can only ever be felt through the boat, so they must not be tuned by eye. Out of scope: buoyancy and any force application, which belong to GAME-0001.

## Implementation steps

1. Add a direction field to each sea state's wave block in SeaStates, and extend SeaStates.lerp to interpolate it
2. Write ReplicatedStorage/WaveField.luau: HeightAt, NormalAt, summed directional waves from the active state, GetServerTimeNow as the clock, WATER_Y fallback outside the ocean extent
3. Add a smooth transition so a state change or blend never steps the surface height and launches or submerges a floating object
4. Write the debug visualiser: a grid of markers that sit on the sampled surface
5. Register the visualiser toggle as an admin tool (group 13 already lists it)
6. Calibrate per state against the rendered water; record measured numbers as comments
7. Verify determinism by sampling the same x,z,t from a Server and a Client context and comparing
8. Measure the cost of 12 samples per frame
9. Screenshot the debug grid in all five states - markers that float or sink are the proof the field and visuals disagree

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
