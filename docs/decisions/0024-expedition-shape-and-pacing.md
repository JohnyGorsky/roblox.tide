# 0024 — The expedition's shape: ~50 minutes, tiered stops, and a storm that is never in a hurry

Status: Accepted

Records the macro loop as specified 2026-08-21, the arithmetic it implies, and the two structural
consequences that fall out of it.

## Decision

An expedition is **~50 minutes**, shaped like this:

```text
board (5 min grace, storm stationary)
→ search  → stop  → search  → stop  → …        ~10 stops
→ make your northing
→ the finale: a hostile vessel
→ win, and the expedition ends
```

**Tiered stops, not uniform islands.** About **4 deep islands** at 5–6 minutes each, plus about **6 quick sea
POIs** at 1–2 minutes — a wreck, a platform, a buoy, a drifting hull. Roughly 18 minutes travelling, 32
minutes stopped.

**The storm does not advance until the crew boards.** The run opens on a small island with the front visible
and stationary; taking the helm starts its clock.

**Islands are found by searching, not by reading a map.** The radar pings; it does not draw. It also carries
the storm's distance, which is what turns "explore or skip" into a decision.

**The run ends by defeating a vessel.** Northing brings the finale, not the victory.

## Why these numbers, and where they came from

Three independent parts of the game already agreed on the pacing before it was written down, which is the
main reason to accept it as stated:

| | |
|---|---|
| The storm | `4200 / 14` = **300 s** to arrival adrift. Exactly the "five minutes if you stay" asked for |
| Shelter | decision [0019](0019-storm-advance-model.md)'s 30% rate makes a moored 5.5-minute island visit cost **1386 of 4200 studs — 33%** of the cushion, paid back by 94 s of driving |
| Day/night | 575 s per cycle with a 4–5 minute day is **one island per day**. A 50-minute run is ~5 cycles |

So the shape was not chosen; it was measured out of what jobs 016–022 already tuned. Nothing in the storm
needs retuning to get it.

### The stop economy

```
deep visit  (330 s moored)  costs  1386 studs   33% of the cushion
quick stop  (90 s moored)   costs   378 studs    9%
travel leg  (110 s at cruise) gains 1628 studs   caps at 4200
```

Which produces the rule of thumb the radar exists to inform:

> **You can afford two deep visits before you must make real northing.** Two costs 66% of the cushion; three
> costs 99% and you do not come back from the third.

That is the whole tension, and it is a *decision* rather than a metronome — which is what "I don't want a
rushed storm" means in mechanical terms. Keep moving and the front sits at its cap, permanently about five
minutes behind and never closer. Stop twice in a row and it is suddenly the only thing that matters.

### Why the island count had to change

As specified it was 10–20 islands at 5–6 minutes each. That is **50–120 minutes of exploring alone**, before
any travel or searching — two to three times the stated run length. A 40–50 minute run holds about five or six
islands at that depth, and the day/night cycle says the same thing independently.

Tiered stops resolve it: **10 stops, of which 4 are real islands.** It reaches the low end of "10–20", keeps
the 5–6 minute island intact, and it is the structure
[group 04](../build/04-islands.md) already plans — 12 curated islands, 9 sea POIs, 6 rare POIs. The quick
stops are what make the sea feel populated between the islands that matter.

## Consequences

### 🔴 Finding 0018 is now a blocker, not a "high"

Eighteen minutes of travelling at cruise 18 is **19,800 studs — 3.2× the full width of the ocean patch**
(6144). A fifty-minute voyage cannot happen inside a 6144-stud box, so the endless sea has to become real:
either decision [0002](0002-horizontal-world-wrap.md)'s east–west wrap, or recentring the world on the vessel.

[Finding 0018](../../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md) has been sitting at "high"
and undecided since 2026-08-20. It now gates the whole design, and no amount of island content will help
until it is answered. **This is the thing to decide next.**

### 🔴 Fuel is the spine, and now it has a number

Eighteen minutes of travel burns **605 fuel against a 100 tank — six tanks per run**. Across ten stops that is
**0.6 of a tank per stop just to break even.**

So refuelling is not an upgrade path, it is the reason to stop at all: you go ashore to find the fuel that
lets you keep going. That closes the loop on itself and hands [group 03](../build/03-items-props.md) a
concrete design target instead of a vibe. It also means the fuel economy cannot ship before finding 0018 —
a crew with six tanks' worth of range reaches the edge of the world several times over.

### Smaller consequences

- **A boarding grace is new work.** The storm's advance must be gated on the crew taking the helm, and the
  five stationary minutes before that are the tutorial-shaped part of the run.
- **The lobby storm never advances at all** — the same gate, permanently off (job 023).
- **Northing triggers the finale, not the victory.** The measure stays; what it unlocks changes. Job 023 ships
  a placeholder finale so the loop is playable end-to-end, and the boss slots in behind the same trigger.
- **The distance cap is load-bearing.** `math.min(distance, START_DISTANCE)` is what stops a fast crew banking
  an hour of safety and makes the threat permanently five minutes away. Do not remove it to "reward" good
  play.
- **Radar Mk1 (`GAME-0002`) is now on the critical path.** Without it there is no pinging search and no storm
  readout, so both halves of the explore-or-skip decision are missing. It also makes job 022's radar fault
  bite for the first time.
- Nothing here changes decision 0014's damage model or job 022's measured curve. A crew caught at a stop
  still dies in 45 seconds of full exposure.

## What is deliberately not decided here

- How the endless sea is achieved (finding 0018).
- What a deep island actually contains for 5–6 minutes — that is group 04, and this decision only fixes the
  time budget it has to fill.
- The finale vessel's design (groups 05, 06).
- Whether the 5 quick-stop types are POIs, platforms or events; the manifest already lists candidates.
