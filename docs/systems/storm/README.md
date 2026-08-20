# Storm System

## Role

The storm is the macro-pressure pushing the crew forward.

It should feel like a character chasing the boat, not a timer bar.

## Visual layers

- dark cloud wall
- changing Lighting/Atmosphere
- wind
- rain around player/camera
- sea spray
- lightning
- fog/rain curtain
- audio
- increasing gameplay wave intensity

## Intensity concept

### Level 0 — Calm
Small waves, good visibility.

### Level 1 — Incoming
Dark horizon, wind, distant thunder.

### Level 2 — Storm
Rain, lightning, radar interference.

### Level 3 — Severe
Heavy horizontal rain, strong wind, larger waves.

### Level 4 — The Wall
Near-zero visibility, extreme danger, strong pressure to escape.

**The Wall is a blind-navigation state, not just a dark one.** Inside it the world is a black void: the
sky is featureless black and fog closes at ~330 studs, so the horizon, the sun, landmarks, wake direction
and any visual cue for heading are all gone.

What survives is **instruments**. You steer by **compass and chart**, and nothing else.

This is the moment the diegetic-instrument pillar pays off. For the whole game the compass is flavour —
here it is the only thing standing between the crew and driving in circles until the hull fails. It is
also the sharpest possible argument for pillar 7: information that lives on the boat keeps working when
the world goes away, and information that lives on the horizon does not.

The escalation ladder that makes it land:

| Sea | What you navigate by |
|---|---|
| Calm → Choppy | The horizon, landmarks, the sun, radar |
| Storm | Radar, with interference beginning |
| **The Wall** | **Compass and chart only. Radar is OUT, not degraded** (confirmed 2026-08-20) |

Radar being *reliably dead* inside the front is what forces the compass. A flickering radar would let the
crew squint through the blindness and the moment would collapse into a lesser version of Storm.

### Why a compass is enough to escape

The escape direction is **constant**: the storm chases from astern and progress is broadly northward
(decision [0002](../../decisions/0002-horizontal-world-wrap.md)). So the compass does not merely report a
heading — it reports **which way is away**. Hold north and you leave.

The chart carries the other half: where you are in the sea stage and what lies ahead, so the crew escapes
*toward* something instead of only fleeing.

There is a quiet third cue worth preserving even though nothing displays it. The swell runs **with** the
storm — a following sea, arriving from astern (feature 0014). So the vessel's own motion tells a
paying-attention crew where the storm is even blind. Do not "fix" that by randomising swell direction
inside The Wall; it is the last honest cue in the game.

⚠️ **This mechanic is void if the HUD shows a heading.** Decision
[0004](../../decisions/0004-radar-no-permanent-minimap.md) forbids a permanent minimap; The Wall extends
that to a permanent compass readout. A number on screen that survives the dark makes the dark free.
See [group 09](../../build/09-ui.md).

### Decided: the compass is indestructible

**The compass cannot be destroyed, and nothing targets it** (2026-08-20).

Nothing singles it out — not lightning, not the Siren, not a boarder. It does not even fail as collateral
from helm or electrical damage. Inside The Wall it always works.

**Why, given pillar 6 says enemies attack systems rather than health.** The compass is the single point of
failure for escaping the storm, and the storm is already the game's hardest pressure. Stacking an
unpreventable instrument failure on top of a state the crew is fighting to survive turns the best moment in
the game into the most resented one — a 25-minute expedition lost to something that could not be
anticipated or repaired in time.

So the compass is deliberately the **one instrument with no stakes attached**. Everything else on the
vessel can fail: engine, generator, radar, pumps, lights, hull, weapons. That is where pillar 6 does its
work. The compass is the floor beneath it — the guarantee that being lost is always the crew's decision
rather than the dice's.

Consequences:

- **Do not add a "compass destroyed" state**, and do not let a future enemy or event acquire one. If it
  ever looks tempting, the answer is to threaten the *chart* instead, which costs the crew knowledge of
  where they are without costing them the ability to leave.
- The Siren's navigation corruption (from the enemy catalog) must therefore work on **radar and charts**,
  not the compass. A lying compass was considered and rejected on the same grounds.
- The compass still needs to be **self-lit** — see group 02. Indestructible is useless if unreadable.

## Lightning

Server chooses authoritative strike event/position/intensity.

Clients render:
- bolt
- flash
- particles
- delayed thunder
- local camera effects

Rare gameplay effects:
- radar disruption
- generator surge
- system fault
- dangerous strike

## Audio

Layer:
- ocean
- wind
- rain on water
- rain on metal
- hull creaks
- distant thunder
- close thunder
- deep storm rumble

Serious storms should use less music and more environmental sound.
