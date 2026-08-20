# Documentation Index

## Where we left off

- **[HANDOFF.md](HANDOFF.md)** — current state, what is unsaved, what is waiting on the user, and the
  recommended next move. Read this first when resuming.

## What to build, and where it stands

- **[The build manifest](build/README.md)** — everything that has to be made, in 12 groups sized to take
  one at a time. Start here when asking "what do we build next?"
- **[BUILD-STATUS.md](../BUILD-STATUS.md)** — generated board: every feature by area, asset and graybox
  counts, delivered jobs. Never edit it; run `python tools/build-status.py`.

## Read first

- [Game vision](game/vision.md)
- [Core gameplay loop](game/core-loop.md)
- [Game pillars](game/game-pillars.md)
- [Visual design](game/visual-design.md)
- [UI/GUI direction](game/gui.md)
- [Typography/fonts](game/fonts.md)
- [Progression](game/progression.md)
- [Monetization](game/monetization.md)
- [Naming / branding ideas](game/naming.md)

## Systems

- [Places (lobby + game)](systems/places/README.md)
- [Vessels](systems/vessels/README.md)
- [Boat baseline](systems/boat/README.md)
- [Boat physics](systems/boat/physics.md)
- [Boat upgrades](systems/boat/upgrades.md)
- [Shipyard / permanent fleet progression](systems/shipyard/README.md)
- [NPC crew](systems/crew/README.md)
- [Ocean/world](systems/ocean/README.md)
- [World wrapping](systems/ocean/wrapping.md)
- [Storm](systems/storm/README.md)
- [Day/night](systems/day-night/README.md)
- [Radar](systems/radar/README.md)
- [Combat](systems/combat/README.md)
- [Enemies](systems/enemies/README.md)
- [Animations](systems/animations/README.md)
- [Islands](systems/islands/README.md)
- [UI](systems/ui/README.md)

## Content catalogs

- [Vessels](content/vessels.md)
- [NPC crew roles](content/crew.md)
- [Enemies](content/enemies.md)
- [Weapons](content/weapons.md)
- [Boat upgrades](content/boat-upgrades.md)
- [Permanent parts/components](content/parts-components.md)
- [Islands and POIs](content/islands.md)
- [Loot/resources](content/loot.md)
- [Events](content/events.md)
- [Encounters](content/encounters.md)

## Current features

- `0001-boat-controller` — PLANNED
- `0002-radar` — PLANNED
- `0003-storm-front` — PLANNED
- `0004-day-night` — PLANNED
- `0005-island-library` — PLANNED
- `0006-basic-combat` — PLANNED
- `0007-player-task-animations` — PLANNED
- `0008-vessel-class-foundation` — PLANNED
- `0009-npc-crew` — PLANNED
- `0010-shipyard-parts-progression` — PLANNED

These statuses describe design planning only. Claude must inspect Roblox Studio through MCP before changing them.

## Accepted decisions

See `docs/decisions/INDEX.md`.

## Roadmap

- [POC](roadmap/poc.md)
- [Roadmap](roadmap/roadmap.md)
- [Release 1](roadmap/release-1.md)
