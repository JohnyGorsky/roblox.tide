# 01 — Sea & horizon

**Group:** the water itself, sea states from dead calm to the storm wall, and every trick that makes a
bounded map feel like open ocean.
**Items:** ~34
**Depends on:** nothing. This is the foundation.
**Feeds:** boat physics (02), islands' water line (04), storm (07).

Systems: [ocean](../systems/ocean/README.md) · [wrapping](../systems/ocean/wrapping.md) ·
[boat physics](../systems/boat/physics.md) · decisions [0002](../decisions/0002-horizontal-world-wrap.md)

---

## The engine fact that shapes this whole group

Roblox terrain water gives us, for free:

- a **convincing animated surface** — `WaterWaveSize`, `WaterWaveSpeed`, `WaterReflectance`,
  `WaterTransparency`, plus reflection and refraction
- **automatic buoyancy and drag** on unanchored parts (float/sink threshold is density vs 1.0)
- swimming, and the underwater look

What it does **not** give us: **its waves do not move objects.** The visual swell is a rendering effect;
a boat sitting on it stays flat and level. So the sea splits into three layers that must be kept in
agreement:

| Layer | What it is | Who owns it |
|---|---|---|
| **Visual water** | Terrain water + its properties, per sea state | this group |
| **Gameplay wave field** | A maths function `HeightAt(x, z, t)` / `NormalAt(x, z, t)` | this group (the function), 02 (using it) |
| **Physics response** | Buoyancy spring-damper sampling the wave field | 02 (boat controller) |

Because the visual and the physical are separate, a preset that *looks* like a 4-stud swell must feed a
wave field that *is* a 4-stud swell, or the boat will visibly ride through the crests. One preset table
drives both.

⚠️ Custom buoyancy is not optional — the physics skill records Jungle burning on two specific traps
(damping inside the up-only clamp; a buoyancy cutoff height the bob reaches). Read
`roblox-physics` before writing a line of it.

---

## A. Sea states

The presets. Each is one row of data driving water, fog, sky and wave field together.

| Item | What it is | GB | Source |
|---|---|---|---|
| `SeaStates` data module | The preset table itself: per state, terrain-water properties + fog + wave-field amplitude/frequency + audio bed | ❌ | code |
| Dead Calm | Glass water, long sightlines, unnerving. A special-night state (see 07) | ❌ | code |
| Light Swell | The default cruising sea. Gentle roll, readable horizon | ❌ | code |
| Choppy | Working sea. Boat pitches, spray starts, fog closes in | ❌ | code |
| Storm | Big swell, horizontal rain, whitecaps, ~900-stud visibility | ❌ | code |
| The Wall | Storm-front interior. Near-zero visibility, extreme motion | ❌ | code |
| State blending | Interpolate between two states over N seconds so weather *arrives* instead of snapping | ❌ | code |
| Wave field function | `HeightAt`/`NormalAt` — summed sine/Gerstner waves, deterministic from a seed so server and client agree | ❌ | code |
| Wave field debug view | Floating markers on a grid sampling the field, so the maths can be *seen* against the visual water | ✅ | studio |

## B. Surface detail

What sells water as water at close range.

| Item | What it is | GB | Source |
|---|---|---|---|
| Whitecaps | Foam particles on crests, density scaling with sea state | ⚠️ | studio |
| Boat wake | Trail from two hull attachments, width and length scaling with speed | ⚠️ | studio |
| Bow spray | Particle burst on wave impact, harder in rough states | ⚠️ | studio |
| Hull foam ring | Static foam decal/particle where the hull meets water | ⚠️ | studio |
| Rain-on-water | Dense ring of impact ripples around the camera during rain | ⚠️ | studio |
| Sea spray mist | Screen-adjacent mist in Storm and The Wall | ⚠️ | studio |
| Underwater fog + colour | What a swimming or drowning player sees; darker per sea stage | ❌ | code |
| Caustics / light shafts | Optional; SunRays plus a scrolling texture. Cut first on mobile | ⚠️ | studio |

## C. Making it feel infinite

The map is bounded. These are the techniques that hide that. **This is the part worth getting right** —
it is what makes the ocean read as endless.

| Item | What it is | GB | Source |
|---|---|---|---|
| Horizon fog band | `FogEnd` tuned per state so the water fades to sky instead of ending at a visible line | ❌ | code |
| Sky set per sea stage | 7 skyboxes (Tropical Shallows → The Abyss). The sky is most of what "somewhere else" means | ⚠️ | store/meshy |
| Distant cloud bank | Billboard/mesh cloud wall on the horizon, slowly parallaxing — implies depth beyond the fog | ⚠️ | studio |
| Far silhouettes | Low-detail islands/rigs/wrecks placed beyond reachable range purely as horizon interest | ✅ | studio |
| Horizontal wrap | Cross the left edge, reappear on the right, logical longitude continuing (decision 0002) | ❌ | code |
| Wrap concealment | Fog, night, a squall line or a rock passage covering the reposition so it is never seen | ❌ | code |
| Logical position model | `logical_longitude` / `logical_distance` / `sea_stage` / `sector_seed` kept separate from physical XZ | ❌ | code |
| Forward stage transition | Advance the sea stage, swap content pool, change weather and sky — the "we have travelled" beat | ❌ | code |
| Sea-stage transition card | Brief on-screen name of the new sea, so progress is *felt* | ⚠️ | code |
| Debris field scatter | Drifting flotsam so the surface is never empty; density per stage | ✅ | studio |
| Bird flocks | Distant birds near land, absent at dusk — a navigation cue and a life cue | ⚠️ | meshy/store |
| Distant lighthouse beam | Rotating beam visible far beyond the object itself; a navigation landmark | ⚠️ | studio |
| Storm wall on the horizon | The chasing storm, always visible behind. Owned by 07, but it is a horizon element | ⚠️ | studio |

### Why these specific tricks

An ocean feels infinite when three things hold. **You cannot see an edge** — fog and a cloud bank end
vision before geometry does, which is also the standing no-visible-edges rule. **The horizon holds
detail** — an empty fog band reads as a small map, whereas silhouettes and beams imply things out there
we have not reached. **Travel changes what you see** — the same water with a new sky, new fog colour and
a new content pool reads as a new sea, which is what makes wrapping survivable.

## D. Boundaries and safety

| Item | What it is | GB | Source |
|---|---|---|---|
| Soft forward/back bound | Current, wind or fuel pressure discouraging leaving the window — never an invisible wall | ❌ | code |
| Fall-through guard | If a player ends up below the seabed, recover them rather than let them fall forever | ❌ | code |
| Seabed | Terrain floor deep enough never to be seen from the surface, shallow enough to exist for diving later | ✅ | studio |
| Out-of-bounds return | Turn the boat back, or a rescue teleport, when something goes wrong | ❌ | code |

---

## Measured in Studio, 2026-08-19 (job 007)

Six things we now know by experiment rather than assumption. They change how this group should be built.

### 1. The sky is the dominant term — and it is a blocker

`WaterColor` barely matters next to what the sky reflects. The default place ships a bright tropical
skybox, and the sea rendered as cheerful holiday blue no matter what the water properties said — exactly
the look [visual-design.md](../game/visual-design.md) forbids.

We tried to fix it in the air rather than the sky, and it does not work:

| Attempt | Result |
|---|---|
| Grey Atmosphere, `Density 0.55`, `Haze 3.0` | Colour improved, **all wave detail vanished** |
| Atmosphere pushed to `Density 0.98`, `Haze 4.5` | Sky stayed bright blue. No meaningful darkening |
| Dark `FogColor` with `FogEnd 900` | Water went dark, sky stayed bright → **hard black horizon line** |
| Remove the skybox → procedural sky | Cleanest horizon of all, but still a clear-day sky |

**Conclusion: neither Fog nor Atmosphere can turn a clear-day sky overcast.** The cold-storm palette is
blocked on real overcast sky assets. "Sky set per sea stage" in section C is therefore a **blocker, not a
polish item** — it is the single highest-value asset in this group.

### 2. Fog darkens the world but NOT the sky

This is what produced the black horizon line. A dark fog against a bright sky splits the image in two.
So fog cannot carry the mood on its own — it controls *distance*, while Atmosphere and the skybox control
*colour*. Design each state's fog for how far you can see, and the sky for how it feels.

### 3. Wave legibility comes from reflectance

The swell is only visible because crests catch light from the sky. Drop `WaterReflectance` to 0.18 under a
flat grey sky and the ocean becomes a featureless navy plane — technically the right colour, visually
dead. **Do not starve reflectance to darken the sea**; darken the sky and keep reflectance around 0.3–0.4
so the surface still reads.

### 4. `fogEnd` must stay inside the water

The ocean is a bounded patch. If fog reaches further than the water does, the player sees the sea simply
stop. Encoded as `SeaStates.OCEAN_HALF_EXTENT` with a `validateFogWithinOcean()` check; Dead Calm's
original `fogEnd 4200` was capped to 2900 because of it.

### 5. Growing the ocean is cheap

6144 × 6144 studs of water plus a sand seabed = **36 `FillRegion` tiles in 0.68 s**. Ocean size is not a
performance constraint at fill time, so if a sea state wants a longer view, enlarge the water rather than
shortening the fog.

### 6. The procedural sky gives a better horizon than the default skybox

With the skybox removed, the water met the sky seamlessly. With it present, a dark band appeared at the
horizon. The default `Sky` is parked in `ServerStorage` as `Sky_DefaultTropical_PARKED` — drag it back to
`Lighting` to restore it.

### What this means for the job order

Job 1 (sea look) cannot be finished without overcast sky assets. Everything else in it — water properties,
fog distances, the state table, the ocean itself — is done and verified. So: **source the sky sets next**,
then finish the look pass.

## Suggested job split

1. **Sea look + states** — A, plus the fog/sky half of C. Applied live, screenshotted per state, judged
   by eye. No physics. *This is the first job to run.*
2. **Wave field** — the sampling function and its debug view, matched to the presets from job 1.
3. **Surface detail** — B, once there is a boat moving to justify wake and spray.
4. **Infinite horizon** — the rest of C: cloud bank, silhouettes, birds, beams, stage skies.
5. **Wrapping** — the logical position model, the wrap itself and its concealment. Hardest; wants a boat
   to sail before it can be judged.

## Open questions

- **Wave amplitude ceiling.** How rough can it get before a small launch stops being fun rather than
  exciting? Needs the boat, then feel-testing.
- **Terrain water vs a custom mesh surface.** Terrain water is free and good; a mesh plane with a custom
  shader would allow real displaced geometry. Start with terrain water — revisit only if the swell has to
  be visibly steep.
- **How far apart do sea stages look?** Distinct skies and fog per stage, or a gradual slide? Affects how
  many sky sets are needed (7 vs ~3 plus tinting).
