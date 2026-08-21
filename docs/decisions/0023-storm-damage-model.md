# 0023 — How the storm damages: one pool, a designed fault ladder, two failure states

Status: Accepted

Implements [0014](0014-storm-consequence.md), which decided *that* the storm damages. This records *how*,
and the four scope calls made while building it (job 022).

## Decision

**One integrity pool per hull, derived from a declared survivability.** A vessel spec states
`survivability` — the seconds of continuous full exposure it survives, unrepaired. The integrity pool, the
damage rate and every fault threshold derive from that plus the hull's own mass. Nothing about damage is
authored per hull.

**Exposure is squared, and sharp at the band edge.** Exposure is 0 outside sea state The Wall and ramps to 1
at storm distance 0, saturating below it. Damage rate is `(integrityMax / survivability) * exposure²`.

**A deterministic fault ladder**, fired once each as integrity falls: radar at 20% lost, generator at 40%,
engine cut at 60%, hull breach at 75%. Steering damage exists as a fault but is not on the ladder — it is a
lightning and collision fault.

**Two failure states**: integrity zero, and capsize (past 100° held for 4 s).

**One repair interaction**: a damage-control station on the aft deck, 3-second hold, clears the oldest
outstanding fault and returns 12% of the pool.

## Why

### Seconds, not hit points

`survivability` is a statement of intent in the same family as `draft` and `rudderLag` — the fields
[0009](0009-vessel-kit.md) requires a spec to carry. Stating the number in SECONDS is what keeps it honest:
the number a designer writes is the number the stopwatch reads, because the rate is defined as
`pool / survivability`. A trawler declares 90 and is tougher; a raider declares 25 and is not. No second set
of constants, no per-hull tuning, which is exactly the promise `VesselPhysics` protects for buoyancy.

The pool itself is mass-scaled and its absolute size is arbitrary — it cancels out of every rate. It exists
to be read in a diagnostic, not tuned.

### Squared, because linear rewards skimming

[0014](0014-storm-consequence.md) requires the curve be *"steep enough that lingering is never a shortcut for
extra looting"*. Under a linear curve, half penetration costs half damage, which makes cutting a corner
through the front's edge strictly better than going round it. Squared, half penetration costs a quarter rate:
the edge is a real tactical option and the inside is not.

The band edge is sharp for the same reason the front exists at all. A crew in a Severe sea is being
**threatened**, not damaged. Bleeding a little attrition into the approach would turn a deadline into a war
of attrition and remove the thing the whole macro loop is built on — a line you can be on the right side of.

Exposure saturates at distance 0 as a deliberate mercy: 400 studs inside the wall is not meaningfully worse
than 200. Making it worse would mean a late reaction is unrecoverable however well the crew then drove, and
0014 wants a crew punished for lingering, not for being slow to understand.

### The ladder is designed, not randomised

Each rung removes a different sense, in an order that escalates:

| At | Fault | What the crew loses |
|---|---|---|
| 20% | Radar | the number. The storm becomes something you feel, not something you read |
| 40% | Generator | the light. The dark gets darker |
| 60% | Engine cut | the ability to run, briefly. Now they find out what margin they left |
| 75% | Hull breach | the floor. Flooding starts and does not stop until somebody works it |

Randomising the order was rejected twice over. It makes 0014's 30–60 second target **unmeasurable** — the
same run ends at wildly different times depending on whether the engine cut early — and it makes the failure
**unlearnable**, so a crew cannot get better at The Wall. A seeded per-run shuffle is the escalation if this
ever reads as too scripted; it is not the default.

The engine cut is transient (8 s, relights itself) and that is not a softening. A permanent engine loss
inside The Wall is not a consequence, it is a death sentence — with no thrust the crew cannot buy any
distance at all, so "escapable in 30–60 seconds" becomes unachievable by definition. What the cut costs is
margin: 8 seconds of the front closing at 14 studs/s is 112 studs to win back.

### Flooding is lost lift, capped well below total

A breach scales each buoyancy point's lift by up to 0.65, rather than adding water mass. Added mass would
change the assembly weight that every derived constant — stiffness, damping, the force ceiling — was solved
for. Scaling the lift leaves all of them intact and still does the visible thing: she sits lower, and the
3-stud freeboard the sea states were chosen against starts letting green water aboard.

It is capped because **at full flooding the hull must still float**. A vessel that sank from flooding alone
would take the loss decision away from the integrity pool, leaving two systems racing to end the run with the
tuned one usually losing. Flooding makes her wallow; integrity decides whether she is lost, and it is the
only thing that does.

### Capsize, because job 021 left it owed

`VesselServer` records the debt explicitly: past ~90° the float points leave the water, hydrostatics loses
its lever, and *"capsizing belongs to the storm-damage job as a real failure state rather than being papered
over by a constraint here."* 100° rather than 90, held 4 seconds rather than instantly — 90 is reachable by a
Storm-state wave she does recover from, and an instant trigger would end a run on one frame of solver noise.

### The escape must be checkable, so it is a tool

The storm's existing constants already produce the answer, and this is the arithmetic the tuning rests on:

```
net at cruise 18 due north = 18 × 1.6 − 14 = +14.8 studs/s
band edge = distance 260

from distance    0  →  17.6 s to clear the front
from distance −450  →  48.0 s
minimum speed that gains any ground = 14 / 1.6 = 8.75 studs/s
```

So 45 s of survivability means a crew reacting immediately gets out having spent ~40% of the hull, and a crew
that spends twenty seconds working out what is happening does not get out at all. Both are the intended
stories. None of it is visible by eye, so it is measured: `Storm → Survival test` runs the real loop in two
modes — hold position (should die at `survivability`) and escape run (should clear the front with real
integrity left) — and states a verdict against this decision rather than printing numbers for someone to
interpret.

## The four scope calls

1. **Steering damage was added** to the intake's fault list. Two of the four faults it named cannot bite yet
   — `GAME-0002 Radar Mk1` is `PLANNED` and the vessel's `light` socket is empty — so steering is the fault
   that proves the machinery does something a driver can feel. At 45% authority she still answers the wheel,
   but the turn takes over twice as long to build.
2. **Radar and generator ship as flags**, with `real = false` on the ladder and the admin panel labelling
   them "(stub)". Building them as flags that pretend to bite would have been worse. They are honoured the
   moment there is a radar to lose and a light to go out.
3. **Vessel loss is a placeholder** — see todo 0006. Decisions [0008](0008-progression-model.md) and
   [0011](0011-shared-expedition-rewards.md) say what a crew keeps, but no expedition end exists and the
   lobby is a separate place with no `TeleportService` flow. So loss kills the engine and helm, zeroes every
   force so she sinks, sets `ExpeditionOver`, and prints a run summary. No progression is granted or taken;
   inventing progression rules inside a storm-damage job is how two systems end up disagreeing about what a
   run is worth.
4. **A minimal compass was built**, which 0014 requires and the intake did not name. Fog closes at 330 studs
   against a black void sky, so without one The Wall is a guess rather than a navigation problem and the
   escape is unmeasurable. It is a `SurfaceGui` binnacle on the helm console — top face, self-lit
   (`LightInfluence = 0`), readable only by someone standing at the wheel. Never a screen overlay, because
   0014 is explicit that *"the HUD must never show a heading, or the blindness is free."* Nothing faults it,
   and nothing ever may.

## Consequences

- **`VesselHeading` was removed** from the published Workspace attributes. It replicated the hull's heading in
  degrees to every client and nothing read it — one `GetAttribute` from voiding the blind-navigation clause.
  Being straight about the limit: the hull is a replicated part, so a client can always derive heading from
  its `CFrame`. This is a design rule that removes the tempting shortcut, not a secrecy mechanism.
- **A hull must never declare an integrity figure or a damage-per-second.** That breaks 0009 exactly as a
  hand-tuned spring constant would.
- **Faults are flags read at the point of use**, never mutations of a derived constant. Scaling
  `state.rudderAuthority` in place would make steering damage permanent and would silently de-tune the heel,
  which was solved against the undamaged value.
- **The compass may never be given a failure state**, and no future enemy or event may acquire one. If
  threatening navigation looks tempting, threaten the chart.
- Flooding drains slower than it fills (0.02 against 0.06), so a breach outlives the fixing of it.
- Damage control is free of resource cost. Group [03](../build/03-items-props.md)'s repair kits add the
  economy; this is the mechanism.
