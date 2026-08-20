# 07 — Atmosphere, storm & day/night

**Group:** the chasing storm, the day→night heartbeat, and the lighting/weather layer that carries most of
the game's mood.
**Items:** ~58
**Depends on:** 01 (sea states to drive).
**Feeds:** everything — this is what makes the same water feel safe or lethal.

Systems: [storm](../systems/storm/README.md) · [day/night](../systems/day-night/README.md) ·
[visual design](../game/visual-design.md) · decisions [0006](../decisions/0006-day-night-loop.md),
[0007](../decisions/0007-storm-forward-pressure.md) · `roblox-vfx` skill

---

## The two clocks

**The day/night cycle** is the emotional heartbeat: dawn 30–45s, day 4–5min, dusk ~45s, night 3–4min
(prototype values). **The storm** is the macro pressure that stops you living in the safe half.

The storm must read as *a character chasing the boat*, never a progress bar. That means it is visible on
the horizon, audible before it arrives, and it changes the sea as it approaches.

---

## A. Day/night cycle — 12 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Cycle controller | Server-authoritative phase clock, replicated | ❌ | code |
| Phase definitions | Dawn / Day / Dusk / Night with durations and transitions | ❌ | code |
| Lighting curve per phase | ClockTime, brightness, ambient, fog, exposure keyframes | ❌ | code |
| Dawn look | Relief. Warmth returning, visibility opening | ⚠️ | studio |
| Day look | Muted teal, faded sun, good visibility | ⚠️ | studio |
| Dusk look | **The warning phase.** Warm then draining, wind rising | ⚠️ | studio |
| Night look | Abyss navy, silhouettes, lights become the whole world | ⚠️ | studio |
| Dusk warning | "Sunset in 60 seconds" — diegetic if possible (birds leaving, bell) | ⚠️ | code |
| Night intensity ramp | Night N is worse than night N−1 | ❌ | code |
| Sun/moon direction | Consistent shadow direction; moon phase for variety | ❌ | code |
| Phase-change hooks | Events other systems subscribe to (spawns, POI variants, audio) | ❌ | code |
| Time skip / debug | Jump to any phase instantly for testing | ❌ | code |

## B. Special nights — 7 items

Named nights give players stories to tell.

| Night | What it changes |
|---|---|
| Dead Calm | Glass sea, no wind, wrong silence. Something is coming |
| Heavy Fog | Visibility collapses; radar becomes the only sense |
| Pirate Hunt | Hunted by boats all night |
| Red Storm | Cursed weather; supernatural enemies strengthen |
| Ghost Signal | A radio/radar transmission that should not exist |
| Severe Storm | The storm catches up early |
| Boss night | The set-piece |

## C. Storm system — 17 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Storm position model | Distance behind the crew, advancing; server-authoritative | ❌ | code |
| Intensity levels 0–4 | Calm → Incoming → Storm → Severe → **The Wall** | ❌ | code |
| Storm wall geometry | The visible black cloud wall on the horizon | ⚠️ | studio |
| Cloud wall material | Scrolling, layered, parallaxing; readable at distance | ⚠️ | studio |
| Rain (local) | Around the camera, not world-wide; angle from wind | ⚠️ | studio |
| Horizontal rain | Severe/Wall: rain nearly sideways | ⚠️ | studio |
| Wind model | Direction and strength driving rain, spray, cloth, audio | ❌ | code |
| Lightning (server) | Authoritative strike events: position, intensity, timing | ❌ | code |
| Lightning (client) | Bolt, sky flash, delayed thunder, camera response | ⚠️ | studio |
| Rare strike effects | Radar disruption, generator surge, system fault, direct hit | ❌ | code |
| Rain curtain / squall line | A moving wall of rain, also usable as wrap concealment | ⚠️ | studio |
| Fog ramp per level | FogEnd/colour tied to intensity | ❌ | code |
| Sea-state coupling | Storm level selects the sea state from group 01 | ❌ | code |
| Caught-by-storm consequence | What actually happens at Level 4 — damage, or a run-ending grab | ❌ | code |
| Storm audio bed | Rumble, wind, rain-on-water, rain-on-metal, hull creaks | ⚠️ | sound |
| Storm warning UI | Temporary HUD alert: `STORM FRONT: 0.8 KM` | ⚠️ | code |
| Siren | The boat's own alarm when the storm closes | ⚠️ | sound |

## D. Lighting & post-processing — 10 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Atmosphere tuning per stage | Density, haze, glare, decay (Decay is a Color3) | ❌ | code |
| Sky sets | Owned by group 01; consumed here | ⚠️ | store |
| ColorCorrection per phase | The single cheapest mood lever | ❌ | code |
| Bloom tuning | Restrained. Lamps and radar glow, not everything | ❌ | code |
| DepthOfField | Subtle; horizon separation | ❌ | code |
| SunRays | Dawn/dusk only; off at night | ❌ | code |
| Lightning flash exposure | Brief exposure/brightness spike | ❌ | code |
| Underwater lighting | Distinct while swimming; darker per stage | ❌ | code |
| **Mobile quality tiers** | Effects that switch off on low-end devices | ❌ | code |
| Lighting perf budget | What is allowed at once — measured, not guessed | ❌ | code |

⚠️ `LightingStyle = Realistic` is currently set in both places (a deliberate choice for this mood). It is
the expensive path — its cost is unmeasured, tracked as todo 0003. The quality tiers above are how we keep
it affordable.

## E. Ambient life & weather detail — 12 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Bird flocks | Near land; gone at dusk — a diegetic clock | ⚠️ | meshy |
| Fish schools | Visible under clear water | ✅ | studio |
| Dolphins | Rare, joyful, contrast before the horror | ⚠️ | meshy |
| Bioluminescence | Night water glow in later stages | ⚠️ | studio |
| Distant lightning (no storm) | Weather elsewhere; the world is bigger than you | ⚠️ | studio |
| Rain ripples on water | Owned by 01, driven by storm level | ⚠️ | studio |
| Cloth response to wind | Flags, tarps, canvas | ⚠️ | studio |
| Spray on the camera | Lens-style droplets in rough seas — use sparingly | ⚠️ | studio |
| Whirlpool / current | Event-scale hazard | ⚠️ | studio |
| Aurora / wrong sky | Cursed Waters and Abyss stages | ⚠️ | studio |
| Floating mist patches | Localised fog banks you sail into | ⚠️ | studio |
| Debris in the wind | Storm-driven junk crossing the deck | ✅ | studio |

---

## Suggested job split

1. **Day/night cycle** — A. Feature 0004. Judgeable on a baseplate ocean immediately.
2. **Storm core** — the position model, intensity levels, sea-state coupling, fog ramp. Feature 0003.
3. **Storm visuals** — cloud wall, rain, wind, squall lines.
4. **Lightning** — server authority, client rendering, rare system effects.
5. **Lighting & post pass** — D, including the mobile quality tiers and the `Realistic` measurement.
6. **Special nights** — B, once the cycle and storm both exist.
7. **Ambient life** — E. Cheap, high-charm, do it whenever there is slack.

## Open questions

- **What does being caught by the storm actually do?** Damage over time, forced movement, or run-ending?
  This is the single most important undecided rule in the game — the storm's whole authority rests on it.
- **Is the storm distance visible as a number?** A HUD readout is clear; a purely visual/audible storm is
  more frightening. Perhaps radar shows it and the HUD does not.
- **Can you shelter?** Island 10 is a "storm shelter". If sheltering works, the storm stops being a wall
  and becomes a puzzle — which may be better.
- **Night length vs mobile session length.** A 4-minute night plus a 5-minute day is a 9-minute cycle;
  three cycles is a 27-minute run. Is that the target session?
