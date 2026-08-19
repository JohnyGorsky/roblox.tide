# Vessel System

## Architecture rule

Design the game around a generic `Vessel` concept from the beginning, even if the first release contains only one actual boat.

Avoid hard-coding core systems around a single fixed starter boat.

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
