# Implementation Plan — Job #028

**Project**: `roblox.tide`
**Created**: 2026-08-22
**Status**: Planned — direction settled with the user. Awaiting one measurement (`StreamingTargetRadius`) and go-ahead.

Sea, lighting and atmosphere quality pass. Everything below was **measured**, not eyeballed.

---

## Analysis

### 1. 🔴 Legacy fog is INERT, and a lot rests on it

**Roblox hides and stops applying `FogStart`/`FogEnd`/`FogColor` whenever `Lighting` contains an
`Atmosphere` object.** Ours does.

Proved it rather than trusting a forum summary: set `FogEnd` from 2353 → **300** with `FogStart 0` — so
aggressive that only the island 260 studs away should have survived — and re-shot from an identical camera.
**Pixel-identical.** Finding 0027.

What that invalidates:

| Thing built on `fogEnd` | Status |
|---|---|
`SeaStates` fog ladder (2900 / 2800 / 1900 / 900 / 330) | **no visual effect whatsoever** |
`Radar.visibility` % | derived from `fogEnd`, so **the instrument reports a number with no visual counterpart** |
`validateFogWithinOcean()` | asserts an invariant about an inert property — passes meaninglessly |
`validateCorridorForTarget()` / decision 0025's `Z=5500` | sized from "target + largest fogEnd"; **that arithmetic is void** |

**What still works:** the job-014 `atmosphere` block per state *is* applied and *is* blended —
`density 0.30 → 0.85`, `offset 0.25 → 0.10` across the ladder. So the storm genuinely does blind you. The
blinding is real; the *numbers we reason with* are fiction.

### 2. 🔴 The ocean has a visible edge, and nothing was ever concealing it

Measured: water runs `Z −1000 … 5500`, so from the launch at `Z=0` the **south edge is 1,000 studs away**.
Water at `Z=−1600` reads empty; at `X=3100` empty. On a clear day you see far past 1,000 studs.

This is finding 0018 reappearing at the other end. Decision 0025 only ever constrained the **north** edge
(`max ≥ target + fogEnd`), and `validateFogWithinOcean` tests `fogEnd < OCEAN_HALF_EXTENT` — a **square-ocean
test written before 0025 made the ocean an asymmetric corridor.** It cannot see the south edge at all.

### 3. The sea "appears" as you move — streaming, unmeasured

`StreamingEnabled = true` (deliberate, per the settings baseline). But `StreamingTargetRadius`,
`StreamingMinRadius` and `StreamingIntegrityMode` are **not valid members from a script context** — I cannot
read or write them. The default target radius is 1,024 studs, which is well inside what you can see, so
terrain would materialise inside the visible range. **Needs a human read in the Properties panel** before any
claim is made.

### 4. Almost every visual lever is at zero

This is the real answer to "why does it look awful". It is not that Roblox can't do it:

| Lever | Now | What it costs us |
|---|---|---|
`Sky.SunAngularSize` | **0** | **no sun disc in the sky, in any sea state** |
`Sky.StarCount` / `CelestialBodiesShown` | **0 / false** | no stars, no moon, ever |
`SunRaysEffect.Intensity` | **0** | the object is enabled and does *nothing* |
`BloomEffect.Threshold` | **2.6** | nothing in an 18%-luminance sea ever exceeds it — bloom does nothing |
`Atmosphere.Glare` | **0.02–0.05** | 🔴 **`Decay` only renders when `Glare > 0`**, so the away-from-sun hue is inert and the sky is a *uniform* wash with no directional value falloff |
`DepthOfFieldEffect` | disabled, `FocusDistance 0.05` | misconfigured, contributing nothing |
`ColorCorrectionEffect` | **absent** | no contrast / saturation / tint control exists at all |
`Terrain.Clouds` | present, `Cover 0.15` | dynamic clouds exist and are nearly invisible |

**Five of the seven effect objects in the place are zeroed, mis-set, or inert.**

### 5. The colour maths behind "flat"

Relative luminance, linearised from sRGB:

| | sRGB | linear luminance |
|---|---|---|
`WaterColor` (Deep Ocean) | 18, 53, 74 | **3.2 %** |
`Atmosphere.Color` (LightSwell) | 132, 145, 154 | **27.5 %** |
`Atmosphere.Decay` | 58, 68, 80 | 5.6 % — **but inert, because Glare ≈ 0** |

So distant sea is pulled from 3.2 % toward 27.5 % — an **8.6× value inversion** over distance. Everything far
away converges on one bright grey, which is exactly the flat band in the screenshot.

Atmospheric perspective is supposed to *reduce* contrast with distance, **not abolish it** — distant objects
stay readable as desaturated, low-contrast, simplified shapes. Two of our settings abolish it:

- **`Offset` is the silhouette control.** Roblox's own docs: *"Lower values blend distant objects seamlessly
  into the skybox; higher values create horizon silhouettes."* Ours is **0.25 on the calmest day**. That is
  why distant land dissolves instead of reading as a pale shape.
- **`Glare ≈ 0` disables `Decay`**, so there is no darker away-from-sun hue to give the sky variation.

### 6. Not everything is a bug — two things are design, and one is an unfair comparison

- **`waveSize = 0.02` in DeadCalm is deliberate** — *"a mirror sea is the whole point."* The screenshot was
  taken at `STRENGTH CALM`, i.e. the state designed to be flattest.
- **The sunless skies are deliberate.** `SkyLibrary` defaults `sunSize/moonSize/stars` to 0 and only
  `ClassicRoblox` enables them; `SunlessBlue`'s own note reads *"No sun disc: the original had celestial
  bodies on, turned off here."*
- The reference game is a **bright tropical noon**, and the first read of decisions 0003/0019 was that we
  should stay cold and simply do it better. **That was the wrong conclusion** — see the settled direction
  below. A permanently cold sea has nothing to lose when the storm arrives.

---

## 🔴 The settled direction: the ladder is a TEMPERATURE JOURNEY

Decided with the user, and it replaces "keep it cold":

> **A normal day is warm and sunny. The storm takes that away, and you feel it go.**

This is better than a uniformly cold sea for a reason worth writing down: **if the world is already grey,
the storm arriving costs the player nothing visually.** Draining warmth, colour and light *as severity
climbs* makes the front's approach legible on the water itself — no HUD needed — and gives every other
system (radar visibility, the damage ladder, the fuel panic) something the eye already agrees with.

It also fixes the DeadCalm brief rather than fighting it. *"The calm that feels wrong"* is not a cold calm —
it is the **doldrums**: a blazing, hazy, windless mirror you cannot move on. Oppressive by heat and stillness
instead of by cold, which is a genuinely different note from the storm and stops the two extremes rhyming.

### The ladder

Starting points to tune by eye in Studio, not final values:

| State | Sun | Atmosphere `Color` → `Decay` | Water | ColorCorrection | Clouds `Cover` |
|---|---|---|---|---|---|
**DeadCalm** | full disc, **high `Glare`** — hazy white glare off a mirror | warm pale → warm blue | bright, lit, near-mirror | saturation **+**, warm tint | 0.10 |
**LightSwell** | full disc, clean | warm pale blue → mid blue | bright working blue | neutral | 0.25 |
**Choppy** | disc going hazy behind cloud | grey-blue → cool grey | blue draining to grey | saturation **−**, cooling | 0.55 |
**Storm** | **gone** | cold grey → dark slate | dark navy | saturation **−−**, contrast **+**, cold | 0.85 |
**The Wall** | none | near-black → black | black | saturation **−−−** | 1.00 |

Two engine facts this leans on, both confirmed above: **`Decay` only renders when `Glare > 0`** (so raising
Glare is what buys the warm-near-sun / cool-away-from-sun sky), and **`Offset` is the silhouette control**
(low blends distant land into the skybox, high keeps it readable).

⚠️ The sun must **fade out across Choppy**, not vanish between frames. `SunAngularSize`, `Glare` and the
ColorCorrection tint all blend through `SeaStates.lerp`, so the crossfade machinery already exists — the sky
*swap* is the one discrete step, and it needs to land where cloud cover already hides the disc.

---

## Implementation steps

Steps 1–3 and 5–8 are unconditional. Step 4 needs the decision below.

1. **Make visibility honest.** Atmosphere becomes the *only* visibility system.
   - Add an explicit `visibility` field per sea state (studs of useful sight) as the number instruments and
     invariants may quote, derived from and documented against `density`/`offset` — not from `fogEnd`.
   - Repoint `Radar.visibility` at it, so the readout stops being fiction.
   - Delete `sky.fogEnd` or reduce it to a commented no-op, and set `Lighting.FogEnd` high so that *removing*
     the Atmosphere degrades to "no fog" instead of a hard clip at 2.3 km.
   - Rewrite `validateFogWithinOcean` → `validateVisibilityWithinOcean`, asserting against **both** Z ends and
     both X sides of the **corridor**, not a square half-extent.
2. **Close the world edge.** Extend the ocean south from `Z=−1000` to about `−3000` so the calmest state's
   sight line cannot reach it, and re-check the north end against the corrected invariant. Cost is a one-time
   `FillRegion`; job 007 measured ~0.68 s for 36 tiles.
3. **Streaming**: you read `StreamingTargetRadius` in the Properties panel, I add it to the settings-baseline
   spec's human-click section and to the audit. If it is 1,024, raise it past the visible range.
4. **Put the sun back on the fair states.** `SkyLibrary` already has the fields (`sunSize`, `moonSize`,
   `stars`, `celestial`) and defaults them all to 0 — only `ClassicRoblox` sets them. Give SunlessBlue,
   SnowGrey and a warmed Choppy sky real discs, fading to nothing by Storm. `SunRaysEffect.Intensity` and
   `Bloom.Threshold` then finally have something to act on. Rename `SunlessBlue` — it will no longer be
   sunless, and a name that lies is worse than an ugly one.
5. **Add a per-state `ColorCorrectionEffect`**, blended exactly like the atmosphere block: a little added
   contrast, a little desaturation, a cool tint that deepens with severity. This is the single cheapest depth
   lever and we currently have none.
6. **Fix the inert levers**: `Glare` up so `Decay` actually renders; `Bloom.Threshold` down so water
   highlights bloom; `DepthOfField` either configured for real distance falloff or deleted rather than left
   misconfigured; `Offset` raised on the calm/working states so distant land reads as a silhouette.
7. **Use the clouds we already have.** `Cover 0.15` is invisible; drive `Cover`/`Density`/`Color` from
   `severity` so the sky thickens as the storm closes. Dynamic clouds are the biggest sky win available and
   they are already instantiated.
8. **Docs**: a `systems/atmosphere` reference mapping each lever to what it fixes; update
   `settings-baseline.md`; re-run the place-settings audit; register the findings.

---

## What I need from you

- [x] ~~The sun decision~~ — settled: sun on the fair states, gone by Storm; warm normal day that cools as
      the front closes.
- [ ] **Read `Workspace.StreamingTargetRadius`** in the Properties panel and tell me the number. It is not
      script-readable, and it is the one remaining unmeasured cause.
- [ ] **A view on the skyboxes.** The five current skies were chosen for a sunless game; at least the two
      fair ones now want warm skyboxes with a sun. I will search the marketplace first and then give you an
      asset table (type / name / how to search) for anything I cannot find.

---

## Verification

- [ ] Every claim re-measured **after** the change, from a fixed camera, before/after screenshots
- [ ] Visibility: the ocean edge unreachable by sight from anywhere on the route, at **every** sea state,
      asserted by the new invariant and confirmed by screenshots astern from `Z=0`
- [ ] Distant land reads as a **pale silhouette**, not a dissolve — checked at 1 km, 2 km, 3 km
- [ ] Value contrast measured, not judged: sample the rendered luminance of near sea, far sea and sky and
      confirm the far sea does not converge on the sky
- [ ] The storm ladder still blinds: The Wall must remain genuinely blind after fog is retired
- [ ] **The journey is legible**: screenshot the same camera at all five states in order and confirm warmth,
      saturation and light drain monotonically. If any step reads warmer than the one before it, the ladder
      is broken
- [ ] **The sun fades, it does not pop.** Step severity in small increments across Choppy and confirm no
      frame where the disc appears or disappears abruptly
- [ ] `Radar` visibility % matches something a player can actually see
- [ ] Mobile cost checked against todo 0003 — `Realistic` + stacked post-effects is the heaviest path, and
      adding ColorCorrection makes one more full-screen pass
- [ ] No new analyzer diagnostics; shared parity holds; Play stopped; camera restored
