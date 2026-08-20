# 0020 — Everyday weather is separate from the storm, and it may not use the storm's language

Status: Accepted

## Decision

The sea varies on its own, independently of the storm — but only through a **restricted set of channels**.

Everyday weather is a set of **modifiers**. It never selects a sea state, and it never writes Lighting.

| Channel | Everyday weather | Storm |
|---|---|---|
| Wind | ✅ up to 0.45 | ✅ to 1.0 |
| Wave height / steepness | ✅ ×0.55 … ×1.60 | ✅ |
| Rain | ✅ showers, to 0.55 | ✅ to 1.0 |
| Fog distance | ✅ ×0.72 … ×1.06 | ✅ |
| **Sky** | ❌ | ✅ |
| **Brightness / ambient** | ❌ | ✅ |
| **Atmosphere density, haze** | ❌ | ✅ |
| **Severity** | ❌ | ✅ |

The bottom four rows are **the darker side**, and they stay owned by the hour of the day and by the
storm alone.

## Why

Three separate problems, one fix.

**The world was mechanical.** With sea state derived only from storm distance, every change in the water
was a threat signal. Rain meant the storm. A rising swell meant the storm. A day never simply *was* a
day — it was a countdown with weather-shaped ticks. Real seas change constantly for no reason at all, and
a world where nothing is incidental feels like a machine.

**It diluted the storm.** The counter-intuitive half: if weather can do everything the front does, the
front has no signature. Making an afternoon breeze ordinary is what lets the real thing be frightening.

**And dimming is the storm's vocabulary.** This is why the restriction exists rather than just a severity
cap. If a passing shower darkens the world, we are straight back to problem one — the crew reads the dim
as the front, and a shower becomes a false alarm. Darkness has to stay *rare and meaningful*, so weather
gets wind, water, rain and fog, and nothing that touches the light.

The happy consequence is that a day now feels natural for free: the sun stays where the hour puts it, and
the sea underneath it works, calms, and works again.

## What that reserves for the storm

| Tell | Weather | Storm |
|---|---|---|
| Rain, chop, wind, a closing horizon | ✅ common | ✅ |
| **The world going dark** | ❌ never | ✅ |
| **A cloud wall astern** | ❌ never | ✅ **the signature** |
| One-way escalation that does not relent | ❌ drifts both ways | ✅ |

So the cloud wall stops being decoration and becomes **the diagnostic**: weather comes and goes, the wall
only ever grows. A crew learns to glance astern rather than to panic at rain.

## Consequences

- Weather publishes `Wind`, `Precipitation`, `WaveScale`, `FogScale` — and the consumers read those
  instead of reading `StormWind`, so nothing downstream has to know which system is responsible.
- **`Precipitation` is separate from `Wind`** rather than derived from it. That is what makes a windless
  shower possible, and a windless shower is the clearest way to teach a player that rain is not the storm.
- Rain is no longer evidence of the storm. Anything that warns — HUD alerts, crew lines, audio stings —
  must key off **storm distance**, never off precipitation.
- **Weather influence fades as the front closes** (`weight = 1 − intensity/4`), reaching zero inside The
  Wall. Taking the stronger of the two values everywhere means a calm spell can never *mask* an
  approaching front, which would be the one genuinely dangerous failure here.
- The drift is a **pure function of server time**, so every context computes the same weather with nothing
  replicated, and it can be *forecast* — the only practical way to test a system that changes over minutes.
- Weather must drift over minutes. At tens of seconds it reads as a flicker, which is worse than no
  variation at all because it looks like a bug.
- Group [07](../build/07-atmosphere.md) owns the drift; the cloud wall's promotion to signature status
  raises its priority, since without it a bad afternoon and the end of the run look alike.
