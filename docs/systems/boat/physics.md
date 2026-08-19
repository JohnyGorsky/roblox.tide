# Boat Physics

## Goal

Responsive, readable boat handling with enough wave motion for atmosphere but enough stabilization for multiplayer gameplay.

## Architecture direction

Use a rigid physics chassis with visual modules attached.

```text
Boat
├── PhysicsChassis
│   ├── root
│   ├── collision hull
│   ├── propulsion points
│   └── stabilization/wave sampling
└── VisualModules
    ├── radar
    ├── guns
    ├── crates
    ├── lights
    └── armor
```

Gameplay modules should not accidentally destabilize the physics assembly.

## Propulsion

Prefer a controlled force-based boat controller rather than manually teleporting the boat every frame.

Engine upgrades may affect:

- thrust
- acceleration
- maximum speed
- reverse
- fuel use
- reliability

## Steering

Desired characteristics:

- poor turning while nearly stationary
- reasonable turn at cruise
- wider turns at high speed
- optional emergency reverse/overdrive behavior later

## Stabilization

The boat should normally recover from waves.

Avoid realistic capsizing caused by trivial avatar movement.

Storm waves can increase:
- vertical motion
- pitch
- roll
- occasional impact impulse

## Wave model

Separate:
1. visual water
2. gameplay wave field
3. boat physics response

A mathematical wave field can provide sampled height/normal under multiple chassis points.

## Multiplayer

Define one clear network/authority strategy for the boat. Server remains authoritative for gameplay-critical state such as fuel, damage, upgrades and inventory.
