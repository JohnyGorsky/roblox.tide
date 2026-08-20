# Final Summary — Job #019

**Project**: `roblox.tide`
**Completed**: 2026-08-20
**Status**: ✅ Completed

## What was implemented

**The world has a voice now.** The ocean, wind, weather and storm all existed and all ticked, and were almost
silent — job 018 wired four channels and nothing else. Nine channels now play, all levelled from the same
attributes the lighting composer reads, so sound and look are incapable of disagreeing about the weather.

**THE ONE ARCHITECTURAL DECISION was to extract rather than copy.** `StormAudio` already held real, measured
anti-repetition machinery, and the ambience beds needed exactly the same thing. The alternative — a second,
similar, subtly-worse implementation — is how a codebase ends up with two half-right versions of its hardest
problem. So it became **`AudioBed`**, and both modules sit on it: several voices, equal-power crossfade,
random re-seek while a voice is silent, per-voice detune plus shared drift. One place to fix, one place for
the reasoning to live. `StormAudio` was refactored onto it and verified **behaviour-preserving by
measurement**, not by reading.

**LEGACY `Sound`, deliberately, against the skill's recommendation.** The `roblox-audio` skill prefers
`AudioPlayer`/`AudioEmitter` for new work and is right — for *spatial* sound. Every channel here is a 2D
non-positional bed: ocean and weather are everywhere at once, and a positioned emitter would get quieter
when the player turns their head, which is both wrong and very noticeable. The new API's advantages buy
nothing for a bed while mixing two audio APIs across two modules would buy real confusion. The boat's engine
and hull creak genuinely *are* positional, and that is the right moment to introduce `AudioEmitter`.

**FIVE ASSETS SOURCED, TWO REJECTED ON THEIR OWN DESCRIPTIONS.** Per the standing rule set this session, the
market was searched first: Pro Sound Effects on the Creator Store turned out to carry free, verified,
properly-categorised clips of **28–110 s** where most Roblox audio is 2–5. Length is not a nicety here, it is
*the* problem — it is what defeats audible looping — so that library became the primary source
([decision 0021](../../docs/decisions/0021-audio-direction.md)). All five verified loaded and length-checked
against their store claims.

The two rejections are the more instructive half, and are exactly what the "what must it NOT contain" step
exists for: `Ocean Surf 1` is *"…Roar of White Noise, **Prop Plane Fly By**"* and `San Pedro Harbor 2` is
*"…Seagulls, **Heavy Helicopter Fly By**"*. A vehicle baked into an ocean bed would be glaring, and on a loop
it recurs forever. **Read the description, not just the category.** Relatedly, a searching lesson worth
keeping: this library indexes by its own vocabulary, so `"thunder rumble distant"` returned the entire
Thunder category while `"wind gust howling loop"` returned subway trains and sci-fi whooshes.

**NO MUSIC, AT ALL** (decision 0021). Not a reduced score, not a menu theme. The storm doc argues serious
weather wants less music and more environmental sound; taken to its conclusion, the cleanest answer is that
there is nothing to take away — if there has never been music, silence is the default state rather than an
effect, and every sound the player hears is something in the world with them. It also protects the POC's own
question, because music is very good at making a hollow loop feel purposeful.

**DEAD CALM NEEDED NO ASSET.** It is meant to be the *most* unsettling state — glass water and a long clear
horizon in a game built on weather means something is wrong — so silence would read as a bug, but
"unsettling ocean" is not a thing that can be searched for. Measured that `PlaybackSpeed` accepts values down
to 0.05, so Dead Calm is the **calm ocean bed itself at 0.35**, pitched down until it stops sounding like
water: a slow low surge with no identifiable source. Literally the sea, slowed until it is wrong. Verified at
level 0.340 in the one state that selects it.

**THE RAIN SWAP** is the clearest case of preferring a longer clip to cleverer code. Our own upload is 1.54 s,
which needed **4 voices at ±13% detune** to hide the loop — and that wide detune was never a preference, it
was the price of a short clip. The 36.01 s loop brings it back to the normal **2 voices at ±2%**, removing a
workaround rather than tuning one.

**TWO BUGS FOUND BY CHECKING NUMBERS RATHER THAN LISTENING**, and both would have been nearly impossible to
diagnose by ear:

1. **A single-voice bed went fully silent once per cycle.** The crossfade window reaches zero once per
   period; with two or more voices that is the whole point, but with one there is nothing to cross to, so the
   total collapses, gets clamped to avoid a divide, and the gain becomes `sqrt(0/1)` = 0. Caught by checking
   the sum-of-squares invariant across the phase range — it read `0.000000 .. 1.000000` for one voice where
   two and four both read exactly `1.000000`. `deadCalm` was configured with one voice at the time, so it
   would have pulsed to silence every 30 seconds.
2. **Voices were never staggered when a clip loaded slowly.** `TimeLength` is 0 until the asset streams in,
   and every position operation is guarded on `TimeLength > 0` — so a bed built before its clip arrived got
   no stagger and no re-seeks, leaving all its voices in perfect phase playing identical audio. Precisely the
   artefact the module exists to prevent, arriving through the back door. Caught by a readout printing
   `0.0s clip`. The stagger is now deferred to the first step that finds a real length, and `describe()`
   flags a bed whose voices are not yet staggered.

Verified after the fixes: every clip reports its true length (13.4–109.7 s) and voices sit 6.7–54.9 s apart.

### Files changed

- `studio_game/ReplicatedStorage/AudioBed.luau` *(new — the extracted machinery)*
- `studio_game/ReplicatedStorage/Ambience.luau` *(new — five channels)*
- `studio_game/ReplicatedStorage/StormAudio.luau` — refactored onto `AudioBed`; rain swapped
- `studio_game/StarterPlayerScripts/WeatherClient.local.luau` — starts and steps `Ambience`
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/…` — Audio readout covers both modules
- `docs/decisions/0021-audio-direction.md` *(new)*
- `Jobs/019/`, `Planned/0001-living-world-audio.md`
- `roblox.workspace/Assets/registry/audio.md` — five assets, the two rejections, and the search lessons

### The channels

| Channel | Asset | Length | Rises with |
|---|---|---|---|
| `oceanCalm` | Waves Rolling 2 | 33.1 s | calm seas; fades as severity climbs |
| `oceanHeavy` | Water Wake Constant 2 | 28.8 s | severity — crossfades *against* the calm bed |
| `deadCalm` | *same clip at pitch 0.35* | 33.1 s | severity below 0.15 only |
| `birds` | Seagulls And Crows 1 | 70.4 s | daylight **×** calm **×** no storm |
| `stormBed` | Thunder Distant Rumble 1 | 109.7 s | storm intensity ≥ 1 |
| `windLow` / `windHigh` | ours (Jungle) | 13.4 / 19.0 s | `Wind`, crossfaded at 0.35 |
| `rain` | Rain On Water 1 | 36.0 s | `Precipitation` |
| `thunder` | ours | 5.5 s | per strike, one-shot |

### The numbers to tune when it feels wrong

```text
AudioBed voices          a PERFORMANCE budget. 2 is the default; 4 only for short, noise-like clips
AudioBed spread          detune width. Wide is compensation for a short clip, never a preference
Ambience maxVolume       per channel. birds sit at 0.22 - loud gulls on open ocean would be a lie
Ambience deadCalm pitch  0.35. Lower is more wrong; PlaybackSpeed accepts down to 0.05
```

### Open

- **16 concurrent looping voices** (10 ambience + 6 storm). Fine on desktop, unmeasured on a phone — and
  mobile guidance is explicit about limiting simultaneous audio. First thing to tier down is voice count,
  which halves cleanly to 8.
- Balance is unheard by a human. Every level here is a considered guess, verified numerically only.
- Underwater ambience and `SoundService.AmbientReverb` zoning are unbuilt — cheap, and worth doing when
  there is something to be underneath.
- Shore and rock wash need islands to be near (group 04).
