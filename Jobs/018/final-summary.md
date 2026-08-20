# Final Summary — Job #018

**Project**: `roblox.tide`
**Completed**: 2026-08-20
**Status**: ✅ Completed (audio partially — two slots deliberately left empty, see below)

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

**AUDIO**, partially. Wind is live on two layers crossfaded, both assets we already own and had already
scanned, so no approval round was needed; the registry note that `wind_rush` must fade in is honoured by it
being silent below wind 0.35. Rain and thunder are **empty slots holding `""`, not placeholder ids** — a
wrong rumble is much harder to notice than a missing one, and placeholders are how the wrong sound ships.
`missing()` reports them and the panel prints them on start so they cannot be forgotten. Both are
addressable at runtime via a new free-text panel control, so a candidate can be heard *under the live wind
bed at the storm's own volume curve* rather than judged alone on a store page.

**NOT DONE**: the two audio clips (the user offered to source them; spec is in the shared registry), and
screen-level rain streaks. The thunder timing is already live and testable without a single sound file.

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
LocalWeather.SHOWER_THRESHOLD 0.72  15% wet. 0.62 gave 30%, which was a wet climate
WaveField blend               9 s   the whole transition, every channel
Lightning RATE_PER_MINUTE     2/9/22  the GAP between strikes is what is felt
Lightning.SOUND_STUDS_PER_SECOND 300  legibility, not physics — do not "correct" it
```

### Open

- Rain and thunder clips (spec in `Assets/registry/audio.md`)
- Whether the particle wall reads as cloud or as smoke — the escalation is a textured arc
- Non-admin refusal end-to-end test still needs a stable Play session
