# Vessel System

## Architecture rule

Design the game around a generic `Vessel` concept from the beginning, even if the first release contains only one actual boat.

Avoid hard-coding core systems around a single fixed starter boat.

## 🔴 Who places what: the user places, the code wires

**Decided 2026-08-21.** Once a real ship model exists, **the user places every fitting where it must go, in
Studio's editor.** Code finds those placements by name and attaches behaviour to them. It does not position
them.

Same rule as the Last River lobby, and it matters more on a vessel: a fitting's position is read against the
*hull's shape*. A console 8 studs forward of centre is meaningful on a modelled wheelhouse and arbitrary on a
box.

### What exists today is scaffolding, not the target

`Vessel.build` currently creates the hull, a `Sockets` folder of named attachments from `spec.sockets`
Vector3 offsets, and a welded box per fitting. The whole vessel is registered as the graybox
`GB-STARTER-LAUNCH` for exactly this reason.

### The seam, and how to keep it clean

The consumer side is **already correct** and must stay that way — everything looks its socket up by name:

```lua
local sockets = hull:FindFirstChild("Sockets")
local helm = sockets:FindFirstChild("helm")          -- never a hardcoded offset
```

So the migration when a real hull lands is small, and it is one rule:

> **Read the attachments the model already carries. Do not create them from spec offsets, and do not add a
> second positioning path.**

After that, `spec.sockets` declares only **which sockets a class has** — names and `kind` — not where they
sit. Offsets survive as a fallback for a hull with no authored attachments, which is what keeps the graybox
working.

⚠️ Two traps when interpreting authored positions:

- **Finding 0021**: the spec labels `+Z` as the bow while the hull drives toward `-Z` (`LookVector`). Authored
  positions will mean what the *artist* saw, so settle the convention before reading them.
- Before redrawing any fitting, read `survives_the_restyle` on `GB-STARTER-LAUNCH` in
  `assets/registry/assets.yaml`. Several compass properties look like styling and are decisions
  [0014](../../decisions/0014-storm-consequence.md) and [0023](../../decisions/0023-storm-damage-model.md).

### What this does NOT change

Physics stays **derived from stated intent** — `draft`, `cruise`, `rudderLag`, `survivability` — per decision
[0009](../../decisions/0009-vessel-class-architecture.md). This rule is about **placement**, not tuning. A
hand-authored spring constant is still the thing that breaks the kit.

## How the classes differ, mechanically

Three independent numbers, so "bigger" is not one dial:

```text
acceleration  =  thrust / mass            how HEAVY it feels
top speed     =  where thrust meets drag  how FAST it ends up
turn rate     =  torque / inertia         how SLUGGISH it is
```

Scaling thrust *faster* than drag raises top speed; scaling it *slower* than mass lowers acceleration. Doing
both gives a larger vessel that is **slower to get going and faster once going** — which is how real ships
behave, and which produces a real trade rather than a strict upgrade.

| | Launch | Patrol | Cutter |
|---|---|---|---|
| Mass | 4,200 | ~12,000 | ~30,000 |
| Top speed | 18 | 22 | 24 |
| Time to cruise | ~3 s | ~7 s | ~12 s |
| Stopping distance | short | long | very long |
| Turn radius | tight | wide | very wide |

### Why this matters to the storm

It plugs directly into the front's advance model ([decision 0019](../../decisions/0019-storm-advance-model.md)).
A higher top speed buys more distance, so more looting time — but lower acceleration makes **stopping cost
more**, because the vessel bleeds speed approaching an island and takes many seconds to recover it.

So a large vessel is *more endurance, less opportunism*: fewer stops, longer legs. A launch can dart in and
out of a POI that a cutter would not bother with.

### 🔴 It is a triangle, not a ladder

The Trawler is deliberately **slower** than the Patrol Boat despite being larger, because it takes the cargo
corner instead of the speed corner:

```text
              speed
             (Cutter)
              /                 /            capacity ---- agility
      (Trawler)     (Launch)
```

Each class picks a corner. That keeps the whole roster useful — the "best" vessel depends on how a crew plays,
rather than being whichever they unlocked most recently. A pure ladder would make the launch worthless the
moment anything else existed, and would waste six hulls' worth of content.

### What this constrains about the starter launch

**The launch must leave headroom above it.** Give it the top speed and the handling of a cutter and the whole
ladder compresses into nothing.

So it should sit at roughly **60-70% of the eventual maximum** and feel light and twitchy - fragile and nimble,
which is exactly how decision [0009](../../decisions/0009-vessel-class-architecture.md) already describes it.
That is the argument for cruise **18** rather than 24, and it also lands in the band that reads as a working
boat rather than a speedboat.

## Vessel classes

### Old Launch
- 1–4 players comfortable
- fast/light
- low fuel use
- fragile
- small storage
- few hardpoints

### Reinforced Launch
- improved survivability
- basic permanent electronics
- larger storage
- still agile

### Patrol Boat
- balanced combat vessel
- 2–6 players
- multiple hardpoints
- radar/generator baseline
- more deck space

### Trawler
- storage/salvage focused
- high cargo
- efficient
- slower
- fewer weapons

### Research Vessel
- radar/discovery focused
- stronger electronics
- special signal detection potential
- lighter armor

### Cutter
- heavy survival/combat
- stronger hull
- larger generator
- more weapons
- high fuel consumption
- lower maneuverability

### Expedition Ship
- large endgame vessel
- multiple decks
- bridge
- engine room
- generator room
- cargo/workshop
- several weapon stations
- more complex emergencies
- benefits strongly from full human/NPC crew

## Bigger is not simply better

Every class must have tradeoffs:
- speed
- fuel use
- turning
- cargo
- armor
- power
- crew needs
- weapon capacity
- radar capability

## Ship sections

Larger ships may have sectional damage:

- bow
- stern
- port
- starboard
- bridge
- engine room
- generator room

This allows localized emergencies:
- engine room flooding
- stern boarding
- radar mast disabled
- generator fire
