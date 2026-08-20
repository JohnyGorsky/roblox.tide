# 0021 — Ambience carries the mood; there is no music in the POC

Status: Accepted (2026-08-20)

## Decision

Three parts, settled together.

**1. No music in the POC.** Not a reduced score, not a menu theme — none. The ocean, the wind, the weather
and the machinery carry the entire mood.

**2. Pro Sound Effects (Creator Store, free) is the primary audio source.**

**3. Long clips over clever code.** Where a longer recording exists, take it and delete the workaround.

## Why no music

The storm system doc already argues that serious weather wants *less* music and *more* environmental sound —
that the scariest thing a mixer can do is take the music away. Follow that to its conclusion and the cleanest
answer is that there is nothing to take away in the first place: if there has never been music, silence is the
default state rather than an effect, and every sound the player hears is something in the world with them.

It also protects the POC's own question. [roadmap/poc.md](../roadmap/poc.md) asks whether
`explore → dusk → survive → dawn` is fun with other people. Music is very good at making a boring middle feel
purposeful, which is exactly the wrong help — it would let a hollow loop pass. Answer the question dry.

Cheapest option, and the most likely to be *right* rather than merely affordable.

## Why Pro Sound Effects

The library is free, from a verified creator, and — the part that actually decides it — its clips are **long**:
30–135 seconds where most Roblox audio is 2–5. Verified by loading them:

| Asset | Id | Length | Slot |
|---|---|---|---|
| Rain On Water 1 | `9112855484` | 36.01 s | rain |
| Waves Rolling 2 | `9120621776` | 33.13 s | ocean bed — calm / swell |
| Ocean Surf 1 | `9117143192` | 31.51 s | shore and rock wash |
| Thunder Distant Rumble 1 | `9120018692` | 109.74 s | storm bed |
| Thunder Distant Rumble 1 | `9120018411` | 80.94 s | storm bed, shorter |
| Ship Stern Wash 1 | `9112871242` | 36.01 s | hull wash — needs the boat |

Length is not a nicety here, it is *the* problem. Ambient beds are the worst case for audible looping: there
is no rhythm or melody for the ear to hold onto, so the only structure it can latch onto is the loop period
itself, and once heard it cannot be unheard. `StormAudio` already carries real machinery to fight this —
multiple voices, equal-power crossfade, random re-seek, per-voice detune — and all of it is *compensation for
short source material*. A 36-second clip needs far less of it than a 1.5-second one.

Hence part 3: **the rain slot moves from our 1.54 s upload to the 36 s loop, and the voice count drops from 4
at ±13% detune to 2 at ±2%.** That removes a workaround instead of tuning it. The wide detune was never a
preference; it was the price of a short clip.

## Consequences

- **Search by the library's own category names.** Its descriptions carry `Category: Thunder`,
  `Category: Water - Surf`, `Category: Boats - Bow Wash`. Searching "wind gust howling loop" returned subway
  trains and sci-fi whooshes; searching "thunder rumble distant" returned the entire Thunder category. The
  category vocabulary is the search key.
- **The Thunder clips have rain baked in** ("Thunder, Rolling, Distant Rumble, Light Rain"). That disqualifies
  them from the per-strike `thunder` one-shot — where anything baked in fires at the wrong moment — but makes
  them ideal for a *continuous storm bed*, which is a new channel rather than a replacement.
- Licence is **use within Roblox only**. Fine for our purposes, and it must be recorded that way in the
  registry; these are not ours and cannot be reused outside Roblox.
- **A third-party dependency.** A Creator Store asset can in principle be taken down or moderated.
  `StormAudio.missing()` already reports empty channels, which is the mitigation: a channel that goes silent
  announces itself instead of just stopping.
- Music is **not** ruled out forever — it is ruled out of the POC. If the loop proves fun and feels thin, a
  single storm-ducking drone was the runner-up and is the natural first step.
- Group [12](../build/12-audio.md) drops its music items from the P0 half.
