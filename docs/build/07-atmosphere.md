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
| Storm position model | Distance behind the crew, advancing on a timer; northward travel buys distance back (decision [0019](../decisions/0019-storm-advance-model.md)). **Two tunables — advance rate and studs-gained-per-stud-travelled — and their ratio is the most important balance figure in the game** | ❌ | code |
| Shelter rate modifier | Moored at a storm shelter, the front closes at ~30%. Never zero | ❌ | code |
| Storm as a radar contact | The front rendered on the radar station with a readable distance | ⚠️ | code |
| **Server tick for `compose()`** | ~1/sec, driving the day/night + weather composer. Job 016 built the composer but nothing calls it yet | ❌ | code |
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
| Sea-state coupling | Storm level selects the sea state from group 01 — which carries the water **and** Atmosphere values, so the sea recolours as the weather turns | ❌ | code |
| Caught-by-storm consequence | Escalating damage + system faults, escapable in ~30–60s (decision [0014](../decisions/0014-storm-consequence.md)) | ❌ | code |
| **Blind-navigation state** | Inside The Wall: black void sky, ~330-stud fog, every visual heading cue gone. Crew steers by compass and chart alone | ❌ | code |
| **Compass exempt from all damage** | The compass never fails, and nothing targets it — it is the floor beneath pillar 6, guaranteeing the crew is never unable to leave | ❌ | code |
| **Radar kill inside The Wall** | Radar goes **out**, not flickery. A working-but-noisy radar lets the crew squint through the blindness and collapses the moment into a lesser Storm | ❌ | code |
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

- ~~What does being caught by the storm actually do?~~ **Decided:** escalating damage, escapable if the
  crew acts — decision [0014](../decisions/0014-storm-consequence.md). Tuning target is 30–60 seconds of
  survivability inside The Wall.
  **Built in job 022** — decision [0023](../decisions/0023-storm-damage-model.md) records the model and
  [systems/vessels/damage.md](../systems/vessels/damage.md) is the implementation map. Delivered: hull
  integrity derived from a declared `survivability`, a four-rung fault ladder (radar → generator → engine
  cut → breach), flooding that costs lift, capsize, a damage-control station, a self-lit helm compass, and
  `Storm → Survival test` to measure the 30–60 s claim rather than guess at it. Lightning's fault rolls,
  published and ignored since job 018, are now consumed. Radar and generator remain flags until there is a
  radar to lose and a light to go out; vessel loss is a placeholder until the expedition end exists
  (todo 0006). **None of it has run yet** — Studio Sync was down throughout (finding 0007).
- ~~Is the storm distance visible as a number?~~ **Decided:** radar owns the number as a physical contact;
  the HUD only throws temporary threshold alerts — decision
  [0019](../decisions/0019-storm-advance-model.md). Note the arc this creates: radar dies inside The Wall,
  so the crew watches it approach right up to the moment they most need it, then goes blind.
- ~~Can you shelter?~~ **Decided:** a shelter *slows* the front to roughly 30%, never stops it. A full stop
  would let a cautious crew wait indefinitely, which is the loitering decision 0007 exists to prevent.
- ~~How does it advance?~~ **Decided:** on a timer, with northward progress buying distance back — so
  looting is spent distance, and fuel becomes the real currency of the game.
- **Night length vs mobile session length.** A 4-minute night plus a 5-minute day is a 9-minute cycle;
  three cycles is a 27-minute run. Is that the target session?
