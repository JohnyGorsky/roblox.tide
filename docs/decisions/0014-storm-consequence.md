# 0014 — The storm damages, it does not instantly end the run

Status: Accepted

## Decision

Entering the storm front (sea state **The Wall**) inflicts **escalating consequences**, not immediate
failure:

- mounting hull damage the longer the vessel stays inside
- forced system faults — engine cuts, radar loss, breaches, generator trouble
- near-zero visibility and violent water

A crew that reacts — full throttle, repairs, pumps, power triage — can **fight its way out**. A crew that
stays loses the vessel.

## Why

Decision [0007](0007-storm-forward-pressure.md) makes the storm the game's macro pressure, but pressure
needs a defined consequence or it is a bluff.

A run-ending wall was the alternative, and it was rejected because it deletes the moment the whole game is
built around. The intended player stories are "we ran out of fuel just before the storm caught us" and
"we barely got out" — both require that being caught is survivable at a cost. An instant-kill wall turns
twenty-five minutes of play into one unrecoverable mistake, and teaches players to keep a wide safety
margin, which removes the very tension the storm exists to create.

Escalating damage also gives every other system something to do at the worst possible moment: the engineer
has breaches, the generator cannot power everything, the helm needs full throttle. That is the game at its
most alive.

## Consequences

- The Wall must be tuned to be survivable for roughly **30–60 seconds** of competent play, not longer. If
  it is survivable indefinitely the storm stops being a wall; the target is that a good crew escapes and a
  slow one does not.
- Vessel loss needs a defined outcome: what happens to the crew, and what permanent progress is kept —
  see [0008](0008-progression-model.md) and [0011](0011-shared-expedition-rewards.md).
- The damage curve must be steep enough that lingering is never a shortcut for extra looting.
- Manifest group [07](../build/07-atmosphere.md) owns the implementation.
