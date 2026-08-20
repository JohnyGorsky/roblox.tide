# Implementation Plan — Job #021

**Project**: `roblox.tide`
**Feature**: GAME-0001 (boat controller) · group [02](../../docs/build/02-boat-parts.md)
**Decisions**: 0005 (mobile base), 0009 (vessel classes), **0022 (physics + authority)**, 0014 (compass never fails)

## Modules

```text
ReplicatedStorage/
  Vessel.luau          the KIT: chassis spec, socket definitions, build/spawn. Data, not behaviour
  VesselPhysics.luau   buoyancy / thrust / steer maths. Pure functions of (state, wave field, input)
  VesselHelm.luau      gauge rendering. Client
ServerScriptService/
  VesselServer.server.luau   the loop: owns the hull, applies force, burns fuel, publishes state
StarterPlayerScripts/
  VesselClient.local.luau    input (desktop + touch), gauge updates
```

`VesselPhysics` is deliberately **pure** — it takes state and returns forces, and touches no instances. Two
reasons: it can be unit-checked by feeding it numbers and reading the answers back, which is the only honest
way to verify a spring-damper; and if helm feel ever forces the move to client-side buoyancy (decision 0022's
escape hatch), the maths moves without being rewritten.

## Build order, and why it is this order

1. **The chassis, floating, no input.** A dense hull dropped on the sea with four-point buoyancy and nothing
   else. Everything downstream is untunable until this is stable — you cannot judge thrust on a boat that
   is still bouncing.
2. **Prove it is stable, numerically.** Not by eye. Log vertical position over 60 s in every sea state and
   confirm the bob amplitude settles rather than growing. The Jungle bug was *energy gain*, which looks fine
   for ten seconds.
3. **The righting moment.** Tune `MaxTorque` against `Choppy` and `TheWall`. This is the feel dial.
4. **Thrust and steering.** Force-based, `ApplyAtCenterOfMass`, never teleporting.
5. **Seat + input remote**, then `ReplicationFocus`.
6. **Fuel**, server-authoritative.
7. **The gauges**, compass last because it is the fussiest.
8. **Sockets.** Last, because by now the chassis has told us where things actually fit.

## The number that decides the game

`StormFront`'s own comments already assume a **12 studs/s** cruise: `12 × 1.6 − 14 = +5.2 studs/s`, so a
moving crew slowly pulls away and a stopped crew loses 14/s.

But 12 studs/s is **~6.5 knots** at Roblox's rough scale — a trawler's speed, not a launch's. A player *runs*
at 16. So the boat will feel heavy and slow, and "fast/light" is how [decision 0009](../../docs/decisions/0009-vessel-class-architecture.md)
describes this hull.

The resolution is that **only the ratio matters**, and the two numbers are coupled:

```text
net gain  =  cruise × GAIN_PER_STUD  −  ADVANCE_RATE
time to arrival, stationary  =  START_DISTANCE / ADVANCE_RATE   (unchanged by any of this)
```

| Cruise | `GAIN_PER_STUD` for net ≈ +5/s | Feels like |
|---|---|---|
| 12 studs/s | 1.6 *(current)* | trawler, ~6.5 kn |
| 18 studs/s | 1.06 | working launch |
| 24 studs/s | 0.80 | fast launch, ~13 kn |

So: **pick the cruise speed by feel once the hull moves, then solve `GAIN_PER_STUD` for it.** The 5-minute
stationary arrival is untouched either way, because it depends only on `START_DISTANCE / ADVANCE_RATE`.

⚠️ Do not tune this with `TimeScale` set — it scales the front's advance but not the vessel's travel, which
is exactly the wrong distortion for this measurement (noted in `WorldTick`).

## Four-point buoyancy

```text
        bow (+Z)
          ●
   port ●   ● starboard          each point:
          ●                        submersion = WaveField.HeightAt(p.x, p.z) − p.y
        stern (−Z)                 spring     = max(submersion, 0) × FLOAT_K
                                   damping    = −velocityAt(p).Y × FLOAT_D   ← SEPARATE term
                                   force      = spring + damping, applied at p
```

🔴 **`damping` is added outside the `max(spring, 0)` clamp.** Inside it, damping vanishes the moment the boat
rises above the surface — spring goes negative, clamps to zero, and takes the damping with it. Energy then
never leaves the system and the boat limit-cycles: rock-stable at rest, bouncing forever once driven. This is
the Jungle bug and it is the single easiest thing to get wrong here.

`FLOAT_D` must not be much smaller than `FLOAT_K`, or damping has no authority.

## The compass is not a gauge

[Decision 0014](../../docs/decisions/0014-storm-consequence.md) makes it the one system that can never fail —
indestructible, untargetable, and one of only two instruments left inside The Wall. The manifest is blunt that
graybox is unacceptable here: *if it cannot be read in the dark it fails its most important job.*

The Wall composes `Brightness = 0.30` with fog ending at 330 studs, so anything relying on scene light is
unreadable. It therefore needs to be **self-lit**: a `SurfaceGui` (unaffected by `Brightness`) or `Neon`, plus
its own small light so it reads as lit rather than as glowing. Worth testing *in* The Wall, not in daylight.

## Verification

Numbers read back, not impressions — the last three jobs all had bugs that looked fine and measured wrong.

- [ ] Hull sinks with buoyancy disabled (proves engine buoyancy is genuinely off, not merely balanced)
- [ ] Bob amplitude **settles** over 60 s in all five sea states, driven and idle. Growth = the damping bug
- [ ] `GetNetworkOwner()` on the hull is `nil` at all times, including with a driver seated
- [ ] Pitch and roll respond to heading — meeting a wave bow-on differs from beam-on
- [ ] A character walking the deck cannot capsize it, in `Storm`
- [ ] Deck carries riders with no manual carry code (native moving-platform behaviour)
- [ ] `ReplicationFocus` is the hull; deck does not stream out 3 km from spawn
- [ ] Fuel burns from the server and survives a client trying to lie about it
- [ ] Compass legible inside The Wall at night, screenshotted
- [ ] Multiplayer: two clients, one driving, one on deck

## Out of scope

The other ~110 manifest items · weapons · radar · generator and power allocation · crew stations · upgrades ·
**the storm's hull damage**, which is deferred group 07 work that needs a hull to damage and should be the
next job after this one.
