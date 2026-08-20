# Implementation Plan — Job #018

**Project**: `roblox.tide`
**Feature**: GAME-0003 (storm front) · groups [07](../../docs/build/07-atmosphere.md), [01](../../docs/build/01-sea.md)
**Decisions**: 0018 (time base vs weather severity), 0019 (storm advance), **0020 (new — everyday weather)**

## Why the scope grew mid-job

The job opened as four parts: time scale, lightning, cloud wall, audio. Two things reshaped it.

**The user's note that the sea should change on a calm day.** Sea state was derived *only* from storm
distance, so every change in the water was a threat signal and a day was never simply a day. That became
decision 0020 and a fifth part — and then a **narrowing**, on the follow-up that weather may move wind,
waves and fog but must not touch "the darker side". That restriction is what makes the whole thing work:
dimming stays the storm's vocabulary, so it stays meaningful.

**Two real defects found while wiring it.** Both had been shipped and both were invisible:

1. **Nothing wrote Terrain water.** `StormFront` set the sea state, the wave field followed, and the
   *rendered* water kept whatever colour and wave size the last panel click left. The storm looked like it
   worked because the other four channels are server-composed.
2. **`StormVFX` was never started.** No client script existed in the place at all. Rain, spray and debris
   had never run once — [finding 0011](../../findings/0011-job-017-shipped-storm-vfx-that-nothing-e.md).

## Order of work, and why

| # | Part | Why here |
|---|---|---|
| 1 | Everyday weather (`LocalWeather`) | Decision 0020 first, because it changes what every later channel is allowed to do |
| 2 | Terrain water + cloud layer in `compose()` | The composer had to own them before anything else drove them |
| 3 | Time scale | A testing gap that blocked judging everything else |
| 4 | Lightning | Needs no assets |
| 5 | Cloud wall | Directional, and the diagnostic decision 0020 reserves for the storm |
| 6 | Audio | Wind from assets we own; rain and thunder left as addressable empty slots |
| 7 | Smoothness pass | Prompted by the user asking whether transitions ease or snap. They half-snapped |

## The architecture that fell out

```text
StormFront.advance()        -> StormDistance, StormIntensity, StormWind, SeaState (+ a 9s blend)
LocalWeather.step()         -> Wind, Precipitation, WaveScale, FogScale     [reads the storm]
DayNight.compose()          -> Lighting, Terrain water, Clouds              [reads both]
```

Order is load-bearing at **every** step, not just one — each stage reads the one before it.

The single most important line is `SeaStates.currentBlended()`: one implementation of "what is the sea
right now", used by the composer, by everyday weather, and by the wave field. Before it, callers read the
discrete target state, so everything derived from `severity` snapped at a band edge while the water eased.

## What weather may and may not touch

| | |
|---|---|
| ✅ | wind, wave height, rain, fog distance |
| ❌ | sky, brightness, ambient, atmosphere density/haze, severity |

Enforced by construction — `LocalWeather` publishes *modifiers* and never selects a sea state.
Two safety properties, both to be verified numerically, not by eye:

- pinning weather Glassy → Rough must leave brightness, haze, density, ambient and the sky **byte-identical**
- at storm intensity 4, every weather modifier must read exactly **1.0 / storm's own value** — a calm spell
  must never be able to *mask* an approaching front

## Acceptance

- [ ] Weather drifts across the Glassy…Rough range over minutes, showers ~15% of the time
- [ ] The two safety properties above hold, measured
- [ ] Water colour and wave size follow the storm monotonically
- [ ] A band crossing eases every channel over 9 s with no step, including the old hard switch at severity 0.90
- [ ] Lightning: silent below intensity 2, flash returns exposure exactly to baseline, bolts self-clean
- [ ] Cloud wall present astern only, driven by storm intensity and never by wind
- [ ] Every script compiles; the panel validates
