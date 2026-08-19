# GUI / HUD Direction

## Principle

**If information belongs to the boat, show it on the boat.  
If it belongs to the player, show it on the HUD.**

The normal screen should remain minimal.

## Normal HUD

Show only information needed immediately:

- player health
- equipped item
- ammo when weapon is active
- contextual interaction prompt
- temporary emergency warning
- optional compact crosshair when needed

Avoid:

- permanent minimap
- giant quest list
- permanent boat-stat dashboard
- large resource counters

## Diegetic boat instruments

### Helm cluster

Physical gauges/displays can show:

```text
SPEED
FUEL
ENGINE CONDITION
HULL CONDITION
COMPASS / HEADING
```

### Radar station

Dedicated physical display:

```text
          N
          ↑

    ?            ◇

         ● BOAT

   △ HOSTILE

████ STORM █████
```

Radar answers: **what is around us?**

### Map/chart

A separate chart/map answers: **where are we going overall?**

It can be opened at a chart table or through a dedicated interaction. It should show broad route/sea-stage progression and discovered POIs, not every object.

## Warning language

Prefer world feedback:

- red emergency lamp = hull critical / severe fault
- amber lamp = low fuel / warning
- radar screen interference = radar affected
- siren = storm/emergency
- generator panel = power status

HUD warnings should appear temporarily, for example:

```text
HULL BREACH
RADAR OFFLINE
STORM FRONT: 0.8 KM
ENGINE DAMAGED
```

## Quick status overlay

Hold a button/key to temporarily show:

```text
BOAT STATUS

Hull       72%
Fuel       41%
Engine     OK
Generator  5/8
Radar      ACTIVE
Storm      1.2 km
```

Release the button and it disappears.

## Mobile

- All critical interactions require touch targets.
- Do not rely only on tiny diegetic text.
- Allow a compact accessible status overlay.
- Context prompts must be readable without covering the center of the screen.
