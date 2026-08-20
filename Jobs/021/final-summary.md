# Final Summary — Job #021

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ Completed — **signed off as MVP by the user**

## What was implemented

**A VESSEL, not a boat.** Decision 0009's kit: a chassis plus named sockets, with the starter launch as its
first customer rather than the thing being built. `Vessel` holds specs and construction; `VesselPhysics` holds
pure maths; `VesselServer` owns the hull and applies the forces; `VesselClient` reads input. Eight sockets
exist from the first build so "where does the radar go" is answered by data.

**The kit is real, not nominal, and that rests on one principle: nothing is tuned per hull.** Every constant
is derived from a statement of intent:

| Spec says | Physics derives |
|---|---|
| `draft` — how deep she sits | buoyancy stiffness `K = mass·g / (draft × points)` |
| `cruise` — where she settles | drag, split quadratic + linear so she actually stops |
| `rudderLag` — how long the yaw takes to build | rudder authority and yaw damping, from the hull's own inertia |
| `heelInDeg` / `planingTrimDeg` — angles | moments, against the measured roll and pitch stiffness |

Verified across five hypothetical hulls from 4,200 to 90,000 mass: **equilibrium ratio 1.000000, exact, every
time.** The moment any of those is hand-tuned per vessel there is no kit — there is one boat and six copies.

**Server-owned, no `VehicleSeat`, and the helm is a station you stand at.** Decision 0022 rejected
`VehicleSeat` because it hands network ownership to the driver on sit, and a server force loop reading a
client-owned body pumps energy instead of removing it. Then a plain `Seat` turned out to have the same problem
for a worse reason: sitting welds the character *into* the hull's assembly, so Roblox handed the assembly to
the client and the ownership guard yanked it back every frame. That tug-of-war **destroyed the boat every
time** somebody took the helm. The helm is now a `ProximityPrompt` station — the driver stays their own
assembly standing on a moving platform, which already worked, and which is how every other crew station will
have to work anyway because you do not *sit* at a radar screen.

**Steering is a rudder, not a servo.** It began as an `AngularVelocity`, which *commands* a yaw rate — so the
hull was already rotating at full rate the instant the wheel moved, with no build-up and no dependence on the
hull's own resistance. The user's words were "it just rotates on the spot", and that is exactly what an
imposed rotation feels like. It is now a `Torque` balanced against yaw damping, both scaling with v², which
gives three things for free: rudder lag (yaw builds over ~1.3 s), **zero authority at rest** so she cannot
pivot on the spot and must have way on, and a rudder that reverses when going astern.

**Heel through a turn — researched, not guessed.** From MARIN's *Heel Angles in Turn and Passenger Safety* and
ScienceDirect: a hull does *both*. The rudder force acts before the hull's side force builds, so she first
heels **into** the turn — and that transient is the largest heel of the manoeuvre. Once the rate of turn
settles, centrifugal force at the centre of gravity takes over and she heels **out**. Modelling both moments
honestly reproduced the order for free, because the rudder torque appears instantly while the yaw rate takes a
second to build. It also reproduced something I did not write: **centring the wheel produces a bigger outward
lurch than the turn itself**, because the rudder's inward moment vanishes while the turn's outward moment
remains. The source notes ships have capsized from exactly that.

**Trim is two effects.** Planing trim holds the bow up while the engine pushes; inertial trim is the reaction
to *changing* speed, so opening up lifts the bow and **chopping the throttle digs it in and lifts the stern**.
The second half was missing until the user asked for it. Neither can emerge from a thrust lever arm — measured
pitch stiffness is 1,022,683 N·stud per degree, so the best a low, aft drive point offers is **0.07 degrees**.
That is a missing phenomenon (hydrodynamic stern lift), not a failed approach, so it is modelled directly.

### The bug that cost the most, and the rule that came out of it

[Finding 0019](../../findings/0019-a-large-torque-applied-in-a-body-relativ.md), high. The trim torque —
4,090,732 N·stud, by far the largest force on the hull — was applied in a **body-relative** frame about local
X. That is the intuitive choice: bow-up should stay bow-up as she turns. But a few degrees of roll gives local
X a world-Y component, and a fraction of a four-million torque is an enormous unintended **yaw** moment: at
5.6° of heel, ~400,000, which is nearly three times the rudder's entire authority. And it closed a loop —
yaw → centrifugal heel → roll → more leak → more yaw.

Measured symptom: **wheel dead amidships, flat water, throttle open — she yawed 178° in 8 seconds.**

The same failure was in the heel torque, which I fixed first without checking whether trim had it too. So the
fix appeared not to work, and the remaining spin got misattributed to wave physics and gyroscopic coupling. It
produced a string of false leads — turn rate reading 34%, then 59%, then 252% of design, yaw exceeding its
cap, dead calm turning the wrong way — and crucially **measurements that disagreed between runs**, because the
leak's size depended on how rolled she happened to be when sampled.

**The rule:** if a torque should act about one world axis, aim it in **world space** and recompute the axis
every frame. Every force and torque on this vessel is now `RelativeTo = World` with an explicit direction, and
that audit is worth repeating on any constrained assembly. **The diagnostic corollary is worth as much:** when
repeated measurements of the same quantity disagree run to run, suspect an attitude-dependent cross-axis leak
rather than assuming noise.

### Other real bugs, each found only by driving

- **Runaway speed that killed the driver.** `CFrame.LookVector` is **−Z**, and thrust was applied as `+Z`.
  Drag was computed for the opposite direction and therefore *added* to thrust: positive feedback, unbounded
  speed. Now aimed explicitly along the real `LookVector`, with a speed cap so a sign error cannot be lethal.
- **Steering inverted.** Positive rotation about +Y is counter-clockwise from above, so `+rate` turned to port
  while `steer = +1` meant right.
- **Turned on the spot but carried straight on.** There was *no lateral resistance at all* — a missing system,
  not a bad number. That is what a keel is: it converts a change of heading into a change of course. Modelled
  as a grip time-constant, and slip now holds at a steady ~8.7° instead of growing.
- **Heel was backwards**, and my own test labelled it wrongly, so the instrumentation hid it. Starboard-up is
  leaning to *port*. The user spotted it from the deck.
- **`AlignOrientation` was pure deadness.** Three constraints acted on pitch, which the physics reference
  explicitly warns against. Hydrostatic righting from the float geometry alone is 120,844 N·stud per degree —
  a crew member at the gunwale heels her 0.13° — so the constraint's 250,000 could not win any argument it
  entered. Removed; hydrostatics is the righting mechanism.
- **Yaw torque was derived from `rightingTorque`.** Softening the righting for unrelated reasons silently cut
  steering from 315,000 to 87,500, below the 94,290 needed to turn at all. Two unrelated feel dials must never
  share one number.
- **The vessel destroyed itself** on a zero-blend sea change: amplitude went 30-fold in one frame, the stiff
  spring spiked to 6 g, the integration diverged and the engine removed the assembly. Now ceilinged at 3 g
  with a velocity clamp and NaN rejection, plus `recoverIfLost` to rebuild with a warning rather than in
  silence.
- **A name collision** — the drive `Attachment` and drive `VectorForce` were both called `Drive`, so a
  diagnostic asking for the force got the attachment.

### Files changed

- `studio_game/ReplicatedStorage/Vessel.luau` *(new)* — the kit
- `studio_game/ReplicatedStorage/VesselPhysics.luau` *(new)* — pure maths
- `studio_game/ServerScriptService/VesselServer.server.luau` *(new)* — the loop
- `studio_game/StarterPlayerScripts/VesselClient.local.luau` *(new)* — input, desktop + touch
- `studio_game/ServerScriptService/AdminServer.server.luau` — auto-spawns admins on join
- `studio_game/ReplicatedStorage/StormFront.luau` — `SeaOverride`, so a pinned sea survives the world tick
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/…` — Vessel section, sea tools now pin
- `docs/decisions/0022-vessel-physics-and-authority.md` *(new)*
- `docs/systems/vessels/README.md` — the class ladder is a triangle, not a ladder
- `findings/0018` (the ocean has an edge), `findings/0019` (cross-axis torque leak)

## The MVP numbers, as signed off

```text
hull            40 x 14 x 5, density 1.5, mass 4200, draft 1.8, freeboard 3.2
cruise          18 studs/s   0-90% in 3.6s   coast to rest 22s / 70 studs
turn            60-stud radius at cruise, 542 at 1 stud/s. 180 deg in ~10s
rudder lag      1.3s to build the yaw
heel            ~3.6 deg into the turn, crossing to out; bigger lurch on centring
trim            ~2.9 deg bow-up opening up; ~1.1 deg bow-down on chopping the throttle
lateral slip    ~8.7 deg, steady
fuel            100 units, 182s at full ahead, idle burn 15%
```

Verified in the engine, not simulated: holds course with the wheel amidships (0° drift), turns 80–94% of the
designed rate in every sea, boat/sea bob ratio steady at 0.38–0.46 with no energy gain, hull ownership `nil`
throughout, survives every sea state including the snap that once destroyed it.

## Open

- **Visible angles are smaller than the spec asks for** — bow-up peaks at 2.9° where the maths says 5.7°, heel
  at 3.6° where it says 7.4°. The four-point buoyancy is genuinely that stiff. The angle fields are pure dials
  if more is wanted.
- **[Finding 0018](../../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md), unresolved and high:**
  centre-to-edge is 2.8 minutes at cruise, fuel lasts 3.0. **The fuel tank is the only thing hiding the edge
  of the world, by twelve seconds** — and faster vessels (group 02) and jerry cans (group 03) are both planned.
  Needs a decision before either ships.
- **Mobile touch controls are written but never tested on a touch canvas.** The debt decision 0022 took on.
- **The break-even helm speed is 8.75 studs/s** against the storm's advance. Cruise 18 comfortably outruns it;
  whether that is the right margin is a balance question for when islands exist.
- Sockets are positioned provisionally. No modules fit them yet.
- Capsize past ~90° is unrecoverable by design — hydrostatics loses its lever. Belongs to the storm-damage job
  as a real failure state.
