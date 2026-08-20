# 12 — Audio

**Group:** the sound of a cold ocean at night — ambience, machinery, weather, creatures, and the music that
knows when to stop.
**Items:** ~96 sounds + 12 system pieces
**Depends on:** the scenes it dresses. **Cross-cutting** — cheapest large improvement in the project once
any scene exists.

Systems: [storm audio](../systems/storm/README.md) · `roblox-audio` skill ·
sourcing: Pixabay (per the workspace asset policy) — every asset presented for approval before use

---

## Why this group punches above its weight

A boat at night with the right audio is frightening with almost no visual work. Hull creaks, a distant
thunder roll, an engine you can hear straining, and then silence where there was noise — that is most of the
horror budget, for a fraction of the cost of art.

The storm doc gets this exactly right: **serious storms should use less music and more environmental
sound.** The scariest thing the mixer can do is take the music away.

Positioning matters throughout: an engine you hear from the stern, a growl from the port side, a radar ping
that stays at its station. That is what the spatial audio system is for.

---

## A. Ocean & ambience — 14 sounds

| Sound | Note |
|---|---|
| Calm sea loop | The baseline bed |
| Light swell loop | |
| Choppy sea loop | |
| Heavy sea loop | |
| Waves on hull | Positional, scaling with sea state and speed |
| Waves on shore | Near islands; a navigation cue |
| Waves on rocks | Danger cue — you hear the reef before you see it |
| Underwater ambience | Muffled, pressured |
| Wind (light / moderate / gale) | 3 clips, crossfaded |
| Rigging & cloth flapping | |
| Distant sea birds | Day, near land |
| Dead calm "silence" | Not literal silence — a subtle wrong-sounding bed |

## B. Vessel machinery — 18 sounds

| Sound | Note |
|---|---|
| Engine idle / low / cruise / max | 4 clips, crossfaded by throttle |
| Engine start (catch) | The cough-and-catch that says "old diesel" |
| Engine start (fail) | Dread, when fuel is low |
| Engine shutdown | |
| Engine damaged loop | Knocking, wrong-sounding |
| Propeller in water | |
| Propeller fouled | Grinding — the eel moment |
| Generator loop | Plus a strained variant under load |
| Generator surge / fault | |
| Pump (manual) | Rhythmic, effortful |
| Pump (electric) | |
| Hull creak (light / stressed / severe) | 3 clips. The best cheap tension in the game |
| Water ingress | Positional at a breach |
| Metal impact | Collisions |
| Wheel turn | |
| Switch / lever | Every panel interaction |
| Radar sweep ping | The signature sound of the game |
| Alarm / siren | Storm and emergency |

## C. Weather & storm — 12 sounds

| Sound | Note |
|---|---|
| Rain on water | |
| Rain on metal | Distinct, and much more evocative aboard |
| Rain on canvas | |
| Distant thunder | 3 variants |
| Close thunder crack | 2 variants |
| Deep storm rumble | The approach bed; heard long before it arrives |
| Wind howl (storm) | |
| Spray impacts | |
| Lightning strike (direct) | |

## D. Creatures — ~20 sounds

Roughly 1–2 per enemy from group 05, plus shared impacts.

| Category | Sounds |
|---|---|
| Shark / fish | Surface break, bite, thrash |
| Crab / crocodile | Skitter, snap, hiss |
| Drowned | Wet breathing, groan, waterlogged movement |
| Siren | The call — must be genuinely unsettling |
| Serpent / tentacle | Deep bellow, wet drag, slam |
| Kraken / Leviathan | Signature roars; these should be *events* |
| Shared | Flesh impact, death rattle, underwater movement |

## E. Human & UI — 16 sounds

| Category | Sounds |
|---|---|
| Weapons | Fire ×5 families, reload ×3, dry fire, impacts ×2 |
| Player | Hurt, downed, revive, exertion when carrying |
| UI | Confirm, cancel, pickup (common), pickup (rare), warning toast |

## F. Music — 8 pieces

| Piece | When |
|---|---|
| Harbour / lobby theme | Calm, safe, a little melancholy |
| Departure | The run begins |
| Day exploration bed | Sparse; mostly ambience |
| Dusk cue | The warning. Should raise the pulse |
| Night tension bed | Minimal, layered, mostly texture |
| Combat layer | Additive over the night bed |
| Boss theme | The one place to be loud |
| Dawn relief | The reward for surviving |

## G. Systems — 12 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Audio registry | Ids, groups, volumes, priorities in one place | ❌ | code |
| Modern audio-object setup | AudioPlayer / AudioEmitter / AudioListener / Wire graph | ❌ | code |
| Spatial emitter placement | Engine at the stern, generator in its bay, breach at the hole | ❌ | code |
| Ambience manager | Crossfading beds by sea state, phase and stage | ❌ | code |
| Layered music system | Add and remove layers instead of switching tracks | ❌ | code |
| **Music duck / drop-out** | Removing music at the right moment — the storm doc's rule | ❌ | code |
| Reverb zones | Cabin, cave island, below deck, open sea | ❌ | code |
| Engine sound driver | Pitch and crossfade from actual throttle and damage | ❌ | code |
| Creature audio hooks | Positional cues tied to AI state | ❌ | code |
| Mix buses & master | Music / SFX / ambience / voice, with player volume settings | ❌ | code |
| Mobile audio budget | Concurrent sound limits; what gets culled first | ❌ | code |
| Subtitles / captions | Accessibility, and for muted play | ❌ | code |

---

## Suggested job split

1. **Audio foundation** — G's registry, audio-object graph, spatial placement, mix buses. Prove with the
   engine and one hull creak.
2. **Ocean ambience** — A, plus the ambience manager crossfading by sea state. Pairs with group 01.
3. **Vessel machinery** — B. The single most atmospheric batch; do it early.
4. **Storm audio** — C, plus the music duck. Pairs with group 07.
5. **Creature audio** — D, following group 05's enemy order.
6. **Weapons & player** — E's combat half; pairs with group 06.
7. **UI audio** — E's interface half; pairs with group 09.
8. **Music** — F, plus the layered system. Last, when the game's tone is settled.
9. **Accessibility** — subtitles and captions.

## Open questions

- **Modern audio API or legacy `Sound`?** The audio-object graph is more capable and the right long-term
  choice; confirm its mobile cost before committing everything to it.
- **Voice or text for crew dialogue?** Group 10 lists dialogue lines. Voiced NPCs are enormously
  atmospheric and a large sourcing job; text plus a non-verbal vocal cue is a good middle path.
- **Who makes the music?** Pixabay-sourced tracks will struggle to give a coherent score. Worth deciding
  early whether this is licensed or commissioned.
- **How many concurrent sounds can a phone take** with a storm, an engine, a creature and combat all
  going? Measure before designing the mix, not after.
