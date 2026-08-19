# POC Scope

## Goal

Prove that the core emotional loop is fun before building a large content set.

## Prototype scenario

```text
1–6 players
→ spawn battered starter vessel
→ Day 1: radar/visual navigation to 2 POIs
→ loot fuel + scrap + one permanent part
→ install one in-run upgrade
→ Night 1: shark attack + repairable leak
→ Day 2: wreck / mounted weapon
→ Night 2: fog + pirate attack
→ Day 3: lighthouse/rare POI
→ Night 3: large creature / mini-boss
→ end-of-run summary
→ permanent part appears in Shipyard inventory
```

## POC systems

- generic Vessel abstraction
- starter boat controller
- fuel
- hull health/leak
- basic repair interaction + animation
- basic radar
- one island template
- one wreck POI
- day/night
- simple advancing storm
- one shark enemy
- one pirate encounter
- one mounted MG or harpoon
- basic loot/resources
- one permanent part category
- minimal HUD
- end-of-run summary

## Not required for first POC

- large ships
- full NPC crew
- complex Shipyard projects
- many vessel classes

## Success test

The cycle `explore → dusk pressure → night survival → dawn relief` must be fun with multiple players.
