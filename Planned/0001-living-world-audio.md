# PLANNED 0001 — Living-world audio: ambience, weather beds, and a storm bed

**Project**: `roblox.tide`
**Group**: [12 — Audio](../docs/build/12-audio.md)
**Raised**: 2026-08-20, by the user — *"we want game to feel live"*
**Status**: ✅ **PROMOTED to [Job 019](../Jobs/019/intake.md)** on 2026-08-20. Kept for the reasoning; the
job carries the scope.

## Why this is worth doing before the boat

The manifest already argues audio is the cheapest large improvement in the project, and the reason it can go
early is the same reason the atmosphere group could: **most of it needs no vessel.** The ocean, the wind, the
weather and the storm all exist and all tick right now, and they are currently almost silent — job 018 wired
four channels (two wind layers, rain, thunder) and nothing else.

A sea that is visually alive and acoustically dead does not feel live. It feels like a screensaver.

## The split — mirrors how group 07 was divided

Group 12 divides on the same line group 07 did, and for the same reason: what needs a hull, and what does not.

| Can be built NOW | Needs the boat (group 02) | Needs enemies (group 05) |
|---|---|---|
| Ocean beds per sea state (calm → heavy) | Engine idle/low/cruise/max, start-catch, start-fail | Creature vocalisations |
| Wind layers *(partly done, job 018)* | Hull creak light/stressed/severe | Attack and death sets |
| Waves on hull *(needs a hull — defer)* | Propeller, fouled propeller | |
| Waves on shore / on rocks | Generator loop, surge, fault | |
| Underwater ambience | Pumps | |
| Rigging and cloth | | |
| Distant sea birds | | |
| Dead calm "silence" — a subtly wrong bed | | |
| **The ambience mixer** | | |
| ~~The music system~~ — **cut, decision 0021** | | |

## What the first job should cover

Deliberately scoped to what is judgeable today.

1. **An ambience mixer** — the piece that actually makes it feel alive rather than layered. It must
   crossfade beds by sea state and time of day the way `StormAudio` crossfades wind, and it must reuse that
   module's anti-repetition machinery: several voices per bed, equal-power crossfade, random re-seek, slow
   pitch drift. That work is done and proven; do not write a second, worse version of it.
2. **Ocean beds** for the five sea states, crossfaded off the same `SeaState` / blend attributes the composer
   uses, so sound and look can never disagree about the weather.
3. **Day/night ambience** — sea birds by day, and the different quiet of night. Keys off
   `DayNight.currentPhase()`.
4. **Dead Calm's bed**, which is a design problem rather than a sourcing one: Dead Calm is meant to be the
   *most* unsettling state, so its audio must be wrong-sounding rather than absent. Silence reads as a bug.
5. ~~The music system.~~ **Cut** by [decision 0021](../docs/decisions/0021-audio-direction.md). The storm doc
   argues serious storms want *less* music and *more* environmental sound — and taken to its conclusion, the
   cleanest answer is that there is nothing to take away in the first place. Replaced by a **storm bed**: a
   continuous rolling-rumble layer levelled off storm intensity, using the 80–135 s Thunder clips, which are
   unusable as per-strike one-shots because they have rain baked in but ideal as ambience.
6. **Positional discipline** — a growl to port, a radar ping that stays at its station. Weather is the
   exception and must stay non-positional; it is everywhere at once, and a positioned weather emitter gets
   quieter when the player turns their head, which is both wrong and very noticeable.

## Constraints already known

- **Asset policy applies in full**: our registry first, then candidates presented for approval before use,
  then scan, then log in `roblox.workspace/Assets/registry/audio.md`. Sourcing is Pixabay or Creator Store.
- **Empty slots hold `""`, never a placeholder id.** A wrong sound is much harder to notice than a missing
  one, and placeholders are how the wrong sound ships. `StormAudio.missing()` is the pattern.
- **Audition before committing.** The panel's *Audio → Audition a sound id* exists so a candidate is heard
  under the live beds at the real volume curve, rather than judged alone on a store page.
- **Loops must never be audible as loops.** Ambient beds are the worst case: no rhythm or melody for the ear
  to attach to, so the only structure it can latch onto is the loop period. See `StormAudio`'s header — and
  note the measured trap that a short clip needs *more, wider-detuned* voices, not a longer crossfade.
- **Rate/voice count is a performance budget.** Same lesson as the cloud wall: check the numbers back rather
  than trusting the ear.

## Open questions — all answered, 2026-08-20

Settled in [decision 0021](../docs/decisions/0021-audio-direction.md):

| Question | Answer |
|---|---|
| Music in the POC? | **None at all.** If there has never been music, silence is the default state rather than an effect — and music is very good at making a hollow loop feel purposeful, which is exactly the wrong help when the POC's whole job is to test that loop |
| Licence budget? | **Free only** — Pro Sound Effects on the Creator Store, adopted as the primary source. Free, verified, and 30–135 s clips where most Roblox audio is 2–5 |
| Lobby's own bed? | **Deferred to group 08** with the rest of the harbour |
