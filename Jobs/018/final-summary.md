# Final Summary — Job #018

**Project**: `roblox.tide`
**Completed**: 2026-08-20
**Status**: ✅ Completed

## What was implemented

**EVERYDAY WEATHER** is the change that matters most, and it came from the user's note that the sea should
vary on a calm day. Sea state had been derived *only* from storm distance, which cost twice: the world was
mechanical, because every change in the water was a threat signal and a day was never simply a day; and it
diluted the storm, because if only the front can raise a wave then any wave reads as the front. `LocalWeather`
drifts a sum of sines over server time — deterministic, so every context computes the same weather with
nothing replicated, and it can be *forecast*, which is the only practical way to test a system that changes
over minutes. Then the user narrowed it, and the narrowing is what makes it work: weather may move **wind,
waves, rain and fog** and may **not** touch the sky, brightness, ambient, atmosphere or severity. Dimming
stays the storm's vocabulary, so it stays meaningful. Enforced by construction — weather publishes
*modifiers* and never selects a sea state — and verified numerically rather than by eye: pinning Glassy →
Rough leaves brightness, haze, density, ambient and the sky byte-identical while fog, waves and wind move.
The other safety property is the dangerous one, and it also holds: at storm intensity 4 every weather
modifier reads exactly 1.0, so a calm spell can never *mask* an approaching front. Rain is published as its
own channel rather than derived from wind, which is what allows a **windless shower** — the clearest possible
way to teach a player that rain is not the storm. Showers land ~17% of the time, tuned up from a measured 30%
because frequent rain is exactly what stops rain being noticed.

**TWO SHIPPED DEFECTS, both invisible, both found while wiring the above.** Nothing wrote `Terrain` water:
`StormFront` set the sea state and the wave field followed, while the *rendered* water kept whatever colour
and wave size the last admin-panel click had left on it. Walking the front in *looked* like it worked because
the other four channels are server-composed. `compose()` now owns Terrain water and the cloud layer for the
same reason it owns Lighting — one writer — and the water darkens monotonically with the front, measured
18,53,74 → 15,42,58 → 11,30,45 → 8,20,30 with wave size climbing to the engine's 1.0 cap. Worse:
**`StormVFX` had never run once** — the place had no client script but the admin panel, so job 017's rain,
spray and debris had never existed at runtime ([finding 0011](../../findings/0011-job-017-shipped-storm-vfx-that-nothing-e.md),
logged high). The lesson kept: a client module is not wired up until something in `StarterPlayerScripts`
requires it, and a server-composed world will happily hide the difference.

**SMOOTHNESS**, prompted by the user asking whether transitions ease or snap. They half-snapped, and the
audit is the most valuable thing in this job. Callers each looked up the discrete *target* state, so at a
band crossing everything derived from `severity` — brightness, fog, ambient, the atmosphere, cloud cover —
stepped in a single frame while only the water and the wave field crossfaded. Half the world eased and half
snapped, and the snap is what the eye catches. Fixed at the source with `SeaStates.currentBlended()`: one
implementation of "what is the sea right now", used by the composer, by everyday weather, and by the wave
field, so they cannot disagree about how far through a transition the sea is. The blend went 6 s → 9 s, and
the ratio-vs-absolute rule that keeps The Wall timeless became a smoothstep crossfade over severity
0.85–0.95 instead of a hard `if`. Measured across a Choppy → Storm crossing: severity 0.45 → 0.80,
brightness 2.37 → 1.63, fog 2280 → 1280, cloud cover 0.64 → 0.88, all monotone, no steps; and the old switch
point now shows uniform ~0.14 increments with no discontinuity.

**TIME SCALE** is why the job existed. The panel's distance buttons *teleport* the front, so a tester sees
five separate looks rather than an approach, and watching the real thing close 4200 studs at 14 studs/s takes
five real minutes. `TimeScale` on the world tick compresses it — "Watch a full approach" resets to 4.2 km and
winds the clock to 10× in one click. It scales the front's advance but not the vessel's travel, which is
correct for looking and wrong for balancing, so it says so in the code and in the tool's own output.

**LIGHTNING** is server-chosen and client-rendered, because a crew shouting "did you see that" only works if
they saw the same thing. Silent below storm intensity 2 so it can never fire on an ordinary wet afternoon —
it is one of very few storm-only signals. Rate climbs 2 → 9 → 22 per minute; the interesting quantity is the
*gap*, not the average. Four staged channels: bolt, flash, shake, then thunder at `distance / 300` — 0.6 s at
180 studs, 8.7 s at 2600, a deliberately unphysical speed tuned so a player can *count* it and read the
storm's distance off the sky. The flash takes `ExposureCompensation`, the one Lighting property `compose()`
never writes, because two writers on `Brightness` produce a flicker that looks like a bug in the day/night
cycle. Verified: rises +1.30 in 40 ms, decays over ~180 ms, returns *exactly* to baseline with no leak;
distant strikes still register faintly (+0.197); bolts build at the right bearing and distance with no NaN
and self-clean. Close strikes raise a `LightningFault` attribute for radar/generator — published and
consumed by nothing, because those systems do not exist yet and faking the effect would mean writing it twice.

**CLOUD WALL.** Decision 0020 promotes this from decoration to *the* diagnostic: weather comes and goes, the
wall only ever grows, so a crew learns to glance astern rather than panic at rain. Measured that the built-in
`Clouds` instance is real and free but **sky-wide only** — Cover/Density clamp to 0..1 and there is no bearing
control at all — so it does the overall thickening (0.38 → 1.00 cover, pale → near-black, driven by severity
and provably untouched by weather) and the directional half is a bank of very large, very slow particles
astern. Particles over a textured arc, per the user's pick, because it needed no sourced art and could
therefore be judged against the real approach today. It is pinned *just inside the fog* rather than at its
true distance: at intensity 2 fog ends near 2260 while the front may still be 2500 out, so a truthful wall
would be invisible and the warning would arrive too late. It grows in height as it closes, because angular
size is what a person reads as "approaching" — a mass that darkens without growing reads as nightfall.

**AUDIO** — four channels, all live, all ours. The user uploaded rain (`133061174808986`) and thunder
(`88316151105164`) mid-job; wind reuses two Jungle assets already scanned and logged, and the registry note
that `wind_rush` must fade in is honoured by it being silent below wind 0.35.

The interesting problem was the user's note that the wind **felt repetitive** — correctly, and it was not
the clip's fault. Ambient wind is the worst possible case for looping: there is no rhythm or melody for the
ear to attach to, so the only structure it *can* latch onto is the loop period itself, and once heard it
cannot be unheard. Three techniques stacked, each attacking a different giveaway. Several voices per layer,
**equal-power** crossfaded — verified the sum of squared gains is exactly 1.000000 at every phase for both 2
and 4 voices, because normalising amplitudes instead would dip the bed at each handover, a quieter but
equally recognisable artefact than the seam being removed. Random **re-seek** while a voice is silent, which
is what actually kills the periodicity. And a fixed per-voice detune plus a shared slow ±4% drift on periods
sharing no factors, so no two layers hand over together. Plus **gusts**: short sharper one-shots at
randomised intervals whose frequency and strength scale with wind, so the bed has events in it and not only
texture — reusing the wind clips at raised pitch, which is what a gust actually is.

Then a measurement that changed the design: **the rain clip is 1.54 s**, against 13.4 s and 19.0 s for the
wind. A 1.5-second loop is normally the most audible thing in a mix, and re-seeking barely helps because
there is only ~1.2 s to seek within. What rescues it is that rain is broadband *noise*, which survives
pitch-shifting almost unnoticed where wind would sound like a machine spinning up. So rain gets **4 voices
at ±13% detune** against wind's 2 at ±1.5–2%; the four effective periods land at 1.77/1.61/1.48/1.36 s and
drift permanently out of phase. Logged in the registry as compensation rather than preference — a 6–15 s
recording should replace it if one turns up.

**LIGHTNING LIGHT.** The user's second note: the flash needed *more light attached*, and this was a real
design error rather than a tuning one. `ExposureCompensation` is a **tonemap** — it rescales the frame that
was already rendered, so everything brightens by the same proportion and nothing is actually *lit*. A dark
deck stayed a flat dark shape, only paler, which the eye reads as the gamma being nudged rather than as the
sky going off. Fixed by driving three channels together: exposure for the frame-wide response,
**`Lighting.Ambient`** for real global illumination that reaches into shadow, and a **`PointLight`** near the
camera offset toward the strike so surfaces closest to the crew catch it hardest — falloff is what sells a
light as having a position. Plus PointLights on the bolt's lower segments so it glows *into* the fog instead
of being a bright shape drawn on top of it. `Ambient` was verified free: `compose()` writes `OutdoorAmbient`
(the sky-lit term) and never `Ambient` (the floor applied everywhere), so lightning can own it outright and
there is still exactly one writer per property. Measured on a close strike: exposure −0.050 → +1.215,
ambient 0.275 → 0.924, point light 17.7 at the engine's 120-stud range cap, bolt lights 9.6/12.8/16.0
brightening toward the waterline; a 2400-stud strike lifts ambient to only 0.376. All three hand back exactly
to baseline.

**TWO CORRECTIONS AFTER THE USER TESTED**, both real defects rather than tuning.

*"I did not see any wall approaching."* The wall was pinned at 82% of `FogEnd`, on the reasoning that it had
to stay inside the fog to be visible. It rendered perfectly and was invisible: fog opacity ramps linearly
from clear at `FogStart` to solid at `FogEnd`, so 82% of the way to FogEnd is **~81% occluded** - the wall was
being erased by the air in front of it. Measured across the bands: 81% / 81% / 63% / 52% / 44%, so at exactly
the two distances a crew watches an approach from, it was gone while every value in its own report read
correct. Now placed by **target occlusion** - `FogStart + 0.35 x (FogEnd - FogStart)` - which holds a constant
35% at every band, and is robust in a way no fraction of FogEnd can be because `FogStart` moves independently
per sea state (Dead Calm 200, The Wall 10). Opacity raised too (floor 0.62 -> 0.46, since fog is already
thinning it), and the intensity gate dropped for a faint smudge from 4.2 km - it is the crew's *early* tell
and it was showing nothing for the first stretch. Occlusion is now in the wall's report, because "invisible
while all settings read correct" is otherwise very hard to diagnose. Finding 0014, high.

*"Distance lightning that lights my way."* The falloff was linear, leaving a 2.4 km strike at about a quarter
of a close one - physically defensible and useless. On an unlit ocean, distant lightning is the only thing
that shows the crew the shape of the world, and a flash you can see but cannot see *by* is just a white
frame. Now a square-root curve with a high floor: **+117% at 2400 studs, +51% at 1600, and only +4% up close**,
so the near end is untouched and the far end becomes usable light. It is also true to life for a
counter-intuitive reason - what a distant strike lights is not the ground near you but the whole cloud base
above you, which is an enormous area source.

**THE WALL TOOK THREE ATTEMPTS**, and the third is the one that should have been first.

The user reported "no wall at all", twice. Attempt one placed it at 82% of `FogEnd`, which is ~81% occluded -
the fog in front erased it (finding 0014). Attempt two fixed the placement and it was *still* invisible, with
every reported value correct: emitter enabled, rate 11, particles 447-761 studs, colour, position, 35%
occlusion, all fine. The cause was that the emitter part was parented to `workspace.CurrentCamera` at ~1000
studs, copying the pattern `StormVFX` uses for rain. That pattern is right for rain because rain sits a few
tens of studs from the lens - it is a **viewmodel** technique - and wrong for a kilometre-distant world-scale
object (finding 0016).

Attempt two was slab geometry in Workspace - which DID render, and read as flat grey cards with hard
vertical lines between them. Two causes, and neither was tunable. The segments overlapped (a factor added to
hide gaps), and two surfaces at 39% transparency composite into a visibly *darker* strip, so the gap-hiding
became the artefact. Worse and less obvious: on a 200-degree arc, adjacent slabs face 22 degrees apart, so
each catches the directional light differently and every boundary becomes a crease.

The lesson worth keeping is that **a flat transparent surface always reads as a card**: hard silhouette edge,
uniform interior, the opposite of cloud. Overlap to hide the seams and you get bands instead of lines, which
is worse. Cloud needs SOFT EDGES, and there are only two ways to get them - alpha-faded particles, or real
cloud art with an alpha channel.

Attempt three: particles only, no geometry, at their true ~1000 studs. **Nothing visible at all** - while
the slabs from attempt 2 had rendered fine at that exact distance. So the failure is specific to particles at
range, with two plausible causes I could not distinguish without eyes on the scene: Roblox culling distant
emitters, or a cap on rendered particle size far below the ~1000 studs the property happily accepts.

Attempt four, which shipped: **drawn near, made to look far.** Rather than gamble a fifth attempt on picking
the right cause, the bank is drawn at a fixed **340 studs** with modest 75-257 stud particles, which defeats
both candidates at once. Apparent distance is then produced the way it actually reaches the eye: width and
height are authored as **angles** (140 degrees wide, 19-41 degrees tall) and converted at the render distance,
and **haze is applied by hand** - the colour blended toward the fog colour and opacity reduced by the
occlusion the *pretend* distance implies, since real fog cannot do that from 340 studs. This is the trick
every skybox uses, and it has a real bonus: fog can no longer erase the wall, because haze is now applied
deliberately instead of suffered. What it gives up is parallax, which at a simulated kilometre is
imperceptible.

The construction is still particles only, as the user asked:
Seven emitters spread over 5200 studs astern in a Workspace folder, parts at `Transparency = 1` so nothing
but particles is ever visible. Long 14-24 second lifetimes and a low rate, so the bank ACCUMULATES into a
standing mass rather than streaming past - anything fast enough to see moving reads as smoke from a fire.
`LightInfluence` at 0.55 rather than 1: fully lit it went almost black under a storm sky and vanished against
it, fully unlit it floated free of the lighting. At phase 1 the bank is 5497 studs wide - about 140 degrees -
and 35 degrees tall. A `prime()` burst fills it on start and at every band crossing, because a bank filling
over its own 20-second lifetime is indistinguishable from one that is not being drawn.

One thing caught by measurement rather than by eye, twice: rate is an **overdraw budget**, not a density
dial. rate x lifetime x emitters = particles alive, and each sprite subtends ~40 degrees of view at the render
distance. The first setting gave ~390 alive; a later one, raised in the name of density, gave 500-1100 -
roughly four times the overdraw of the version it replaced. Both were caught by reading the numbers back
rather than by looking, which is the only way this kind of mistake surfaces before a phone finds it. Held to
128-252 across the phases. Density is bought with SIZE, which costs one draw, not with COUNT, which costs a
draw each - so if the bank looks thin, the particles get bigger, not more numerous.

Two supporting facts found on the way: `Part.Size` silently **clamps at 2048** studs (asking 3000 returns
2048), so a horizon-spanning wall must be several parts; and a *narrow* wall is indistinguishable from a
missing one when the tester has no compass, which is why the arc is 200 degrees and there is now a
**Face the storm** tool. That ambiguity alone cost a full round of debugging.

Presence at phase 1 also raised on the user's instruction - a power curve puts intensity 1 at **0.56** rather
than the 0.34 a linear ramp gave. At that level the wall is 4344 studs wide and subtends **41 degrees of
elevation** from sea level.

**LIGHT AT THE STRIKE.** The user's report that "only above me is working, not where lightning strikes" was
precise and correct. A `PointLight` on the bolt caps at 120 studs of range, and a strike 400-2600 studs away
has almost nothing within 120 studs to light - just open water, which barely responds. So all the visible
response came from the camera-local light overhead. The fix is not more range, because the cap is the cap: it
is an emissive **body** at the waterline, a large Neon sphere that collapses over ~0.3 s. Neon is surface
emission and so does not fall off with distance at all - measured 13.7 degrees wide at 400 studs, 7.3 at 1200,
5.7 at 2400 - which is exactly the property needed. At distance that glowing mass *is* the strike, far more
than the bolt line is.

**AND ONE SELF-INFLICTED INCIDENT.** A name-matched cleanup of test artefacts destroyed
`ReplicatedStorage.StormVFX` - the real module. Because **Studio Sync is two-way**, that also deleted
`studio_game/ReplicatedStorage/StormVFX.luau` from disk, outside Studio's undo stack. Recovered with
`git checkout HEAD` and only because the user had committed mid-session; without that commit a whole module
was gone. Cleanup is now an explicit allowlist scoped to Workspace and SoundService and never touches the
containers where real code lives. Finding 0015, high, plus a persistent memory - deleting an instance in a
synced place is a destructive filesystem operation, not a scene tidy.

**AND THEN IT WAS TOO LIGHT** - approved after a final pass. The lightness had three separate sources, and
changing any one alone would only have got halfway. The palette's pale end was 158,166,176, practically white,
when even a distant front is dark - that is what makes it a front rather than a cloud. The haze blend was the
main offender: its factor was 0.75, so at 55% haze it dragged the colour 41% of the way toward the fog colour,
which in fair weather is a LIGHT grey - meaning the further away the front, the whiter it went, exactly
backwards. And `LightInfluence` at 0.5 let bright daylight wash it out, when the front is supposed to look
dark AT NOON. Fixed all three: luminance now falls 0.324 / 0.231 / 0.187 / 0.106 / 0.042 across the phases and
transparency roughly doubled in opacity, while particle counts stayed put so there was no overdraw regression.

Deliberately still not opaque. Density has to come from many overlapping soft sprites, because that is what
produces a cloud EDGE - push individual particles to solid and each becomes legible as a blob, which is the
particle form of the flat-card problem that caused the grey lines in attempt 2.

**TWO MORE FOG ERASURES, after the wall was approved.** The user reported the wall "disappears too fast at
the last step" and that lightning "is only on me, not in distance". Same root cause as finding 0014, and it
is now a class of bug seen three times: anything drawn at or beyond `FogEnd` is erased, and `FogEnd` is not a
constant - the composer drives it from 2550 studs in fair weather down to **330 inside The Wall**.

The wall had been pinned at a *fixed* 340 studs, which was the fix for the first erasure and introduced the
second: fine for phases 0-3, then completely wiped at phase 4 when the fog closed inside it. Lightning was
drawn at its true 400-2600 studs, so in Storm conditions (`FogEnd` 1280) every strike beyond ~1300 studs was
fogged out entirely - which is exactly why only the flash on the player was landing.

Both now derive a render distance from the *current* `FogEnd` and scale their geometry by
`renderDistance / trueDistance`, leaving apparent angular size unchanged. True distance still drives
everything physical - thunder delay, flash strength, camera shake, haze - and only the drawing moves.

The user also asked that the wall "come more and more", which was fair: elevation topped out at 42 degrees, so
it read as a distant band no matter how close the front got. Now 14 to **76 degrees**, and the arc widens from
156 to **230 degrees** - past the sides, so at the last phase it engulfs rather than standing off. The arc
placement is only safe because particles are camera-facing billboards; there are no facets to catch the light
differently, so the crease problem that killed the slab version cannot recur.

**NOT DONE**: screen-level rain streaks.

### Files changed

- `studio_game/ReplicatedStorage/LocalWeather.luau` *(new)*
- `studio_game/ReplicatedStorage/Lightning.luau` *(new)*
- `studio_game/ReplicatedStorage/LightningVFX.luau` *(new)*
- `studio_game/ReplicatedStorage/CloudWallVFX.luau` *(new)*
- `studio_game/ReplicatedStorage/StormAudio.luau` *(new)*
- `studio_game/ServerScriptService/LightningServer.server.luau` *(new)*
- `studio_game/StarterPlayerScripts/WeatherClient.local.luau` *(new — the missing client)*
- `studio_game/ReplicatedStorage/SeaStates.luau` — `currentBlended()`
- `studio_game/ReplicatedStorage/DayNight.luau` — blended severity, Terrain water, clouds, fog scale, crossfaded absolute rule
- `studio_game/ReplicatedStorage/WaveField.luau` — wave scale applied in one place
- `studio_game/ReplicatedStorage/StormVFX.luau` — reads `Wind`/`Precipitation`, rain decoupled from wind
- `studio_game/ReplicatedStorage/StormFront.luau` — blend 6 s → 9 s
- `studio_game/ServerScriptService/WorldTick.server.luau` — weather step, time scale, creates the cloud layer
- `studio_game/StarterPlayerScripts/AdminClient.local.luau` — free-text control
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/…` — 23 → 32 tools
- `docs/decisions/0020-local-weather-vs-storm.md` *(new)*
- `roblox.workspace/Assets/registry/audio.md` — wind assets now tide too, plus the two wanted slots
- `findings/0011`, `findings/0012`, `findings/0013`

### Driving it

| Section | Tool |
|---|---|
| **Storm** | Time scale · **Watch a full approach** · Force a lightning strike · Rain/spray/cloud wall status |
| **Weather** | Pin today's weather · Forecast (next 20 min) · Weather status |
| **Audio** | Audio status (what is still silent) · Audition a sound id |

Start with **Watch a full approach → 30 seconds (10×)**, then turn round and look astern.

### The numbers to tune when it feels wrong

```text
LocalWeather.WIND_MAX        0.45   ceiling on an ordinary day — the safety property
LightningVFX AMBIENT_GAIN    0.55   how hard a strike lights the world. THE dial for flash strength
Lightning.flashExposure      floor 0.45 + 1.15*sqrt(near) - raise the FLOOR for more distant light
CloudWallVFX TARGET_OCCLUSION 0.35  how much fog sits in front of the wall. >0.6 and it disappears
CloudWallVFX PRESENCE_CURVE  0.55   lower = more wall earlier. Phase 1 currently lands at 0.56
CloudWallVFX ARC_DEGREES     140    narrower is much easier to miss entirely
CloudWallVFX STORM_GREY/BLACK the colour ramp ends. Darker still? Start here
CloudWallVFX haze * 0.28      how much distance BLEACHES it. Was 0.75 and far too pale
CloudWallVFX e.Rate          an OVERDRAW budget. Prefer bigger sprites over more of them
LightningVFX LIGHT_GAIN      14     the local PointLight; range caps at 120 studs engine-side
StormAudio VOICES[x].spread  detune width — wider for short clips, narrow for long ones
LocalWeather.SHOWER_THRESHOLD 0.72  15% wet. 0.62 gave 30%, which was a wet climate
WaveField blend               9 s   the whole transition, every channel
Lightning RATE_PER_MINUTE     2/9/22  the GAP between strikes is what is felt
Lightning.SOUND_STUDS_PER_SECOND 300  legibility, not physics — do not "correct" it
```

### Open

- **The storm cannot hurt you.** The Wall looks unsurvivable and does nothing (decision 0014). This is the
  single biggest gap and it is what stands between a spectacle and a threat.
- A longer rain recording (6-15 s) would let the rain voice count drop from 4 to 2
- `PointLight.Shadows = true` on the camera-local flash light is a mobile tier-down candidate; unmeasured
- Screen-level rain streaks
- Non-admin refusal end-to-end test still needs a stable Play session

- Non-admin refusal end-to-end test still needs a stable Play session
