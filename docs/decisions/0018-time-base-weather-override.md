# 0018 — Time is the base, weather overrides by severity

Status: Accepted

## Decision

**Time of day owns the baseline** light, sky, ambient, fog and atmosphere. **Sea state overrides it in
proportion to severity.**

Every sea state carries a `severity` from 0 to 1. The applied look is that state's values blended over the
time-of-day base by that amount:

| Sea state | Severity | Effect |
|---|---|---|
| Dead Calm | 0.00 | Time wins entirely. A calm night looks like night |
| Light Swell | 0.15 | Time wins; weather barely tints |
| Choppy | 0.45 | Weather tints heavily |
| Storm | 0.80 | Weather nearly wins |
| The Wall | 1.00 | Weather total. Identical at noon and midnight |

**Weather multiplies the base; it does not replace it.** Each state's brightness and fog are read as a
*ratio* against the reference sea (Light Swell), and the ratio is what blends in. Blending toward the
state's absolute values instead was tried first and was wrong: those numbers were authored for daytime, so
a stormy night came out brighter than a clear one (clear night 0.70, Light Swell night 1.04, Choppy night
1.47) and a storm let you see further in the dark. A ratio darkens whatever hour it lands on.

The **sky** cannot blend — it is six discrete image ids — so it switches rather than mixes: above a
severity threshold the weather's sky wins, below it the time's sky does.

## Why

Both systems want the same properties, and without a rule the last one to run wins — which produces bugs
that look like flickering rather than like a design conflict.

Two failure modes the rule is chosen to avoid:

- **Sea state dominant** would mean a calm night uses the daytime sky, merely dimmed. Night would never
  read as night, and `NightFog` would go unused.
- **A full matrix** of 4 phases × 5 states = 20 hand-tuned presets gives total control and no single
  source of truth for "what night looks like". Twenty sets of values drift.

Severity blending also produces the right answer at the extremes for free: **The Wall is timeless.** At
severity 1.0 the time of day contributes nothing, which is correct — inside the front there is no sun, no
stars and no horizon, so whether it is noon or midnight is unknowable. That falls out of the maths rather
than needing a special case.

## Consequences

- `SeaStates` gains a `severity` field. It is not decoration: it is the blend weight.
- Nothing may write `Lighting` directly except the composer. A system that sets `FogEnd` on its own will
  be overwritten on the next tick and the bug will look like a flicker.
- Skies are assigned twice: one per time phase, one per severe weather state. Seven skies cover both
  (`SunlessBlue`, `SnowGrey`, `NightFog` for time; `FogOnWater`, `AngryHeavens`, `BlackVoid` for weather;
  `ClassicRoblox` as fallback).
- The storm system does not set lighting. It sets **intensity**, which selects a sea state, whose severity
  then does the work. One direction of flow, no loops.
- Cycle timing is fixed at roughly a **9–10 minute** cycle: dawn 30–45 s, day 4–5 min, dusk ~45 s, night
  3–4 min, giving a ~28 minute three-cycle expedition (confirmed 2026-08-20, matching
  [roadmap/poc.md](../roadmap/poc.md)).
