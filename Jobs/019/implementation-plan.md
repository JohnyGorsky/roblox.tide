# Implementation Plan — Job #019

**Project**: `roblox.tide`
**Group**: [12 — Audio](../../docs/build/12-audio.md), the P0 half
**Decisions**: [0021](../../docs/decisions/0021-audio-direction.md) (no music, Pro Sound Effects, long clips)

## The one architectural decision

`StormAudio` already contains real, measured anti-repetition machinery — N voices, equal-power crossfade
verified to sum to exactly 1.0 at every phase, random re-seek while silent, per-voice detune plus shared
drift. The ambience beds need *exactly the same thing*.

So the machinery is **extracted into `AudioBed.luau`** and both modules use it. Not copied, not
reimplemented, not "similar but with its own bugs". Three consequences worth stating:

- `StormAudio` gets refactored to sit on `AudioBed`. That is a change to tested code, so it must be
  verified **behaviour-preserving by measurement**, not by reading it.
- Only one place ever needs fixing when a repetition artefact turns up.
- `AudioBed` is where the hard-won knowledge lives, so its header carries the reasoning rather than it being
  scattered.

## Legacy `Sound`, not the new audio-object API — deliberately

The `roblox-audio` skill recommends `AudioPlayer`/`AudioEmitter`/`Wire` for new work, and it is right for
**spatial** sound. Every channel in this job is a **2D non-positional bed**: weather and ocean are everywhere
at once, and a positioned emitter would get quieter when the player turns their head — wrong, and very
noticeable.

The new API's advantages (distance attenuation, effect wiring, listeners) buy nothing here, while mixing two
audio APIs across `StormAudio` and `Ambience` would buy real confusion. When the boat arrives, its engine and
hull creak genuinely *are* positional, and that is the right moment to introduce `AudioEmitter`.

## Channels

| Channel | Asset | Length | Levelled by |
|---|---|---|---|
| `oceanCalm` | Waves Rolling 2 `9120621776` | 33.13 s | inverse sea severity |
| `oceanHeavy` | Water Wake Constant 2 `9120610116` | 28.77 s | sea severity |
| `stormBed` | Thunder Distant Rumble 1 `9120018692` | 109.74 s | storm intensity ≥ 1 |
| `birds` | Seagulls And Crows 1 `9112870863` | 70.37 s | day phase × calm × no storm |
| `deadCalm` | *(no asset — see below)* | — | how close the sea is to Dead Calm |
| `rain` | Rain On Water 1 `9112855484` | 36.01 s | replaces the 1.54 s upload |

All five verified loaded and length-checked against their store claims.

**Two candidates rejected on their own descriptions**, which is exactly what the "what must it NOT contain"
step is for:

- `Ocean Surf 1` (`9117143192`) — *"…Roar of White Noise, **Prop Plane Fly By**"*
- `San Pedro Harbor 2` (`9112870008`) — *"…Seagulls, **Heavy Helicopter Fly By**"*

A vehicle baked into an ocean bed would be glaring, and on a loop it would recur forever.

## Dead Calm needs no asset

Dead Calm is meant to be the *most* unsettling state — glass water and a long clear horizon in a game built
on weather means something is wrong. Silence reads as a bug, so it needs a bed, but "unsettling ocean" is not
a thing to search for.

Measured that `PlaybackSpeed` accepts values down to **0.05**. So Dead Calm is the *calm ocean bed itself*,
pitched down until it stops sounding like water — a slow, low surge with no identifiable source. It is
literally the sea, slowed until it is wrong, which is a better answer than anything a search would return.

## Work order

1. **`AudioBed.luau`** — extract the voice machinery. Config: id, voice count, crossfade, drift period,
   detune spread, base pitch. API: `AudioBed.new`, `bed:setLevel`, `bed:step`, `bed:prime`, `bed:destroy`.
2. **Refactor `StormAudio`** onto it, and prove equivalence by measurement.
3. **Swap rain** to `9112855484`; voices 4 → 2, detune ±13% → ±2%. Removes a workaround rather than tuning it.
4. **`Ambience.luau`** — the five ambience channels, levelled off the same `SeaState`/blend/`StormIntensity`
   attributes the composer uses, so sound and look can never disagree about the weather.
5. **Wire into `WeatherClient`** — and remember finding 0011: a client module is not wired up until something
   in `StarterPlayerScripts` requires it.
6. **Panel** — an Audio section readout showing every channel's level, voice count and clip length, so a
   silent channel is diagnosable rather than mysterious.
7. **Registry** — log all five in `roblox.workspace/Assets/registry/audio.md` with licence recorded as
   Roblox-only.

## Acceptance

- [ ] `StormAudio` behaviour unchanged after the refactor, measured not read
- [ ] Rain runs 2 voices at ±2% and shows no audible period
- [ ] Ocean bed crossfades with sea state across a band crossing, with no dip at the handover
- [ ] Storm bed silent at intensity 0, rising with the front
- [ ] Birds only in daylight, only in calm, never during a storm
- [ ] Dead Calm's bed is present and *wrong*, not absent
- [ ] Total live voices stays within budget — read the number back, do not trust the ear
- [ ] Every channel appears in the panel readout with its real level

## Out of scope

Vessel machinery (needs group 02) · creature sounds (group 05) · music of any kind (decision 0021) · the
lobby's own bed (group 08) · shore and rock wash, which needs islands to be near (group 04).
