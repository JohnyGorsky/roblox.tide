# 0019 — The storm advances on a clock; distance is bought by moving

Status: Accepted

## Decision

Three rules, settled together because they only make sense together.

**1. The front creeps forward on a timer, and northward progress buys distance back.**

It advances at a fixed rate regardless of what the crew does. Travelling north gains ground; stopping
loses it. So looting is not free — it is **spent distance**.

**2. Radar owns the number. The HUD only warns at thresholds.**

The storm appears on the radar station as a physical contact with a readable distance. The HUD stays clean
and throws a temporary alert at key distances (`STORM FRONT: 0.8 KM`), then clears.

**3. A shelter slows the front. It never stops it.**

Moored at a storm shelter the front closes at a reduced rate — call it ~30% — but it still closes.

## Why

**The timer-plus-progress model** is the only one where the helm matters. A pure timer makes every
expedition the same length and reduces the wheel to decoration. Rubber-banding — holding the front a fixed
distance astern — guarantees drama but players notice it, and a threat recognised as theatre stops being a
threat. Timer-plus-progress produces the intended player story: *"we ran out of fuel just before it caught
us"* is then a story about a decision, not about a stopwatch.

It also makes **fuel the real currency of the game.** Distance costs fuel, looting costs distance, so every
stop is paid for twice. That is a much better economy than a countdown.

**Radar owning the number** follows decision [0004](0004-radar-no-permanent-minimap.md): information about
the world lives on the instruments. It gives radar another reason to be worth upgrading — and it has a
sharp consequence, because radar **dies inside The Wall** (see the storm system doc). The crew can watch
the front approach right up until the moment they most need to know, and then they are blind. That is a
better arc than a number that never stops working.

Threshold warnings exist because a crew with nobody at the radar would otherwise be caught with no notice
at all, which reads as unfair rather than tense.

**Shelters slowing rather than stopping** keeps the wall a wall. A full stop lets a cautious crew wait
indefinitely, which is precisely the loitering decision [0007](0007-storm-forward-pressure.md) exists to
prevent. Slowing makes the shelter a genuine prize — somewhere to run for repairs when things have gone
wrong — without turning the storm into a puzzle with a solved state.

## Consequences

- The storm needs **two tunable numbers**: base advance rate, and studs-gained-per-stud-travelled. Their
  ratio decides how much looting a run affords, and it is the single most important balance figure in the
  game.
- **Fuel exhaustion becomes a death sentence** by construction: no fuel means no progress means the front
  closes at full rate. That is intended, and it means fuel scarcity must be tuned with the storm, not
  separately.
- Radar must render the front as a contact, not merely a number — group [09](../build/09-ui.md).
- Threshold alerts need choosing: the storm doc's `0.8 KM` is one; the set should be few enough to stay
  meaningful.
- Shelter mooring needs a defined state — the vessel is *at* a shelter, and the rate multiplier applies.
  Island 10 in [the island catalog](../content/islands.md) is the first one.
- The storm sets **intensity**, which selects a sea state, whose `severity` drives the look
  (decision [0018](0018-time-base-weather-override.md)). The storm never writes lighting itself.
