# 0022 — Vessel physics: dense hull, server authority, four-point buoyancy

Status: Accepted (2026-08-20)

## Decision

Five parts, settled together because each one depends on the others.

**1. The hull is DENSE, and engine buoyancy is switched off.**

`CustomPhysicalProperties` with density **> 1**, so terrain water does not lift it at all. Every stud of lift
comes from our own force sampling `WaveField.HeightAt`.

**2. The hull stays SERVER-OWNED, and there is no `VehicleSeat`.**

A plain `Seat` plus our own throttle/steer `RemoteEvent`. The server owns the assembly at all times and never
has to take ownership back.

**3. Buoyancy is FOUR POINTS, not one.**

Bow, stern, port and starboard, each applying its own upward force. Pitch and roll fall out of the offsets.

**4. A WEAK righting moment, not an orientation lock.**

`AlignOrientation` with `PrimaryAxisOnly`, `MaxTorque` tuned so weather visibly pitches and rolls the boat but
it always recovers, and a crew member walking the deck can never capsize it.

**5. The starter launch is 40 × 14 studs with 3 studs of freeboard.**

## Why

### The hull must be dense, or two systems fight over Y

Roblox terrain water buoys anything with density < 1 — toward a **flat Y = 0 plane.** Our wave field puts the
surface somewhere else entirely ([finding 0008](../../findings/0008-roblox-terrain-water-waves-exist-only-in.md):
terrain-water waves exist only in the shader and move nothing).

Two systems driving the same axis toward different targets is the classic oscillation, and the symptom is
**jitter that looks like a tuning problem rather than a conflict** — which is how it eats a day. Making the
hull sink removes the argument instead of balancing it: there is exactly one thing lifting the boat.

### Server ownership, because the force loop reads the body it pushes

This is the single most expensive lesson available to us, already paid for on the Jungle boat and recorded in
the `roblox-physics` skill: **a server loop computing force from a client-owned body's position pumps energy
instead of removing it.** The boat was rock-stable while idle and bounced *higher and higher while driven*,
because the server read a lagged position and applied a spring-damper force one round-trip late.

`VehicleSeat` is what causes it — it hands network ownership to the driver on sit. The skill's fix is a
per-frame `if GetNetworkOwner() ~= nil then SetNetworkOwner(nil)` guard, which works but is fighting the
engine every frame, and is one missed guard away from the same failure.

Using a plain `Seat` means the fight never starts.

Three further reasons beyond stability, all specific to this game:

- **The storm reads the vessel's Z on the server.** `StormFront.advance` buys distance from northward
  progress, so a client-owned hull would feed the game's central mechanic a lagged position.
- Fuel, damage, upgrades and inventory are already server-authoritative (the boat system doc requires it).
- Helm latency on a heavy boat in a co-op game is far less noticeable than on a car. This is not a racer.

The cost is real and accepted: **we build the mobile touch controls ourselves**, where `VehicleSeat` would
have supplied them. Mobile is a first-class target here, so that is a genuine debt, not a freebie.

> A tempting third option was client-owned with client-side buoyancy — genuinely available to us, because
> `WaveField.HeightAt(x, z, t)` is deterministic from `GetServerTimeNow()` and identical in every context, so
> the driver's client can compute exactly what the server would. Rejected for the storm-position reason above,
> but worth remembering: if helm feel turns out to be the thing that kills it, this is the escape hatch, and
> the wave field being deterministic is what keeps it open.

### Four points, because pitch and roll should be free

One buoyancy point at the centre of mass gives heave and nothing else — the boat rides up and down a wave
without ever tilting, which reads as an object stuck to a surface rather than a boat.

Four points at the extremities produce pitch and roll from the **wave field's own shape**, with no extra
system: the bow lifts on a crest while the stern is still in the trough, and that is a torque. It also means
the boat responds to the *direction* it meets a wave, which is what makes heading matter.

### A righting moment, not a lock — and this is the dial that decides the feel

The boat system doc asks for two things at once: *"enough wave motion for atmosphere but enough stabilization
for multiplayer"*, and explicitly *"avoid realistic capsizing caused by trivial avatar movement."*

So the righting moment deliberately touches the same axes the four-point buoyancy does. The
`roblox-physics` skill warns that two constraints on one DOF fight and oscillate — that warning is accepted
here with open eyes, because the alternatives are worse: no righting moment means capsizing, and a hard
`AlignOrientation` lock means the sea does nothing.

**`AlignOrientation.MaxTorque` is therefore the most important feel number on the vessel.** Too low and it
capsizes; too high and the storm is a light show. It wants tuning against `Choppy` *and* `TheWall`, not
against `LightSwell`.

### 40 × 14 with 3 studs of freeboard

| | |
|---|---|
| **40 long** | ~11 m at Roblox's rough scale — a believable ex-military utility launch, and small enough that the Patrol Boat and Trawler above it in the class ladder have room to feel bigger |
| **14 beam** | a character is ~5 studs wide, so two crew can pass each other on deck. The manifest names this as the real constraint, not looks |
| **3 freeboard** | chosen against the sea states, not by eye |

Freeboard 3 against the wave amplitudes is what makes weather *mean* something:

| Sea | Amplitude | At the deck |
|---|---|---|
| Light Swell | 0.8 | dry |
| Choppy | 2.0 | spray aboard |
| Storm | 4.5 | green water on deck |
| The Wall | 7.5 | swamped |

## Consequences

- **We owe mobile touch controls.** Throttle and steer need a touch UI, and the bottom-left quadrant belongs
  to Roblox's thumbstick (`mobile` skill), so the helm controls go elsewhere. Unbuilt debt from day one.
- **`ReplicationFocus` must point at the vessel**, not the character — streaming is on, so crew far from
  spawn would otherwise watch the deck stream out (already a `GAME-0001` requirement).
- Never anchor the assembly to park it. Mooring holds it with an `AlignPosition` and keeps it dynamic — the
  skill records that un-anchoring with a rider aboard **deletes the parts**, with no `Destroying` event.
- Anchoring any part of the assembly splits it and disables the welds. No exceptions for "just the deck".
- Buoyancy damping must be applied **separately** from the up-only clamp, or it disappears exactly when the
  boat rises and the boat bounces forever while driven. Second Jungle lesson, same bug family.
- Four sample points per hull per frame fits the wave field's 8–12 budget, leaving room for debris and a
  second vessel. It does not leave room for twenty floating crates on the same tick.
- The class ladder in [vessels](../systems/vessels/README.md) inherits all of this: a Trawler is the same
  chassis with different numbers and more sockets, not a new physics implementation.
- **Buoyancy stiffness is DERIVED from mass and draft, never authored per hull** — `K = mass × g / (draft ×
  points)`. This is what makes the kit real rather than nominal: the moment a bigger vessel needs its float
  hand-tuned, decision 0009's promise is broken and we have one boat with six copies. Each vessel declares
  how deep it should *sit*, which is a design statement from a reference photo, and the physics follows.
- **Buoyancy point COUNT comes from the spec too, not fixed at four.** Four suits a 40-stud launch; four on a
  200-stud hull makes it a rigid plank, because a long vessel must feel the wave along its length. Six to
  eight there.
- The abstraction is not total, and the limit is worth stating: a very large vessel with interiors and
  multiple decks is a different physics problem, and a 200-stud rigid body carrying six players is not
  obviously the same one. The kit covers **launch through cutter**; the expedition ship needs revisiting.
