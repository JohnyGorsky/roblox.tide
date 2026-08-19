# The Last Tide — Design & AI Development Pack v2

This repository is the long-term design memory for a Roblox co-op ocean survival game developed with Claude + Roblox Studio MCP, with Meshy used for generated 3D assets.

## Core rule

- Git documentation says what the game should be and why.
- Roblox Studio says what actually exists.
- Claude must inspect Studio through MCP before assuming implementation state.
- `IMPLEMENTED` is not the same as `VERIFIED`.

## Start here

1. `CLAUDE.md`
2. `docs/INDEX.md`
3. `docs/game/vision.md`
4. `docs/game/core-loop.md`
5. Relevant `docs/systems/<system>/README.md`
6. Active feature under `docs/features/`

## Current design direction

A 1–6 player co-op ocean survival roguelite.

Players begin each expedition with a vessel from their persistent fleet. New players start with a battered motor launch; later progression unlocks larger vessels such as patrol boats, trawlers, research vessels, cutters and eventually large expedition ships.

The crew explores curated islands, wrecks and sea POIs during the day, hunts permanent upgrade parts and rare components, improves the active vessel during the run, and survives increasingly dangerous nights while a massive supernatural storm advances from behind.

The physical ocean may be bounded, but horizontal wrapping, logical sea progression and curated POI spawning make it feel much larger.

## Latest progression direction

Permanent progression is primarily **parts/component based**, not a single token grind.

Examples:
- Engine Parts
- Hull Parts
- Electronic Parts
- Weapon Parts
- rare named components such as Military Radar Core or Twin Engine Assembly

The player gradually improves starting vessels and constructs new ship classes in the Shipyard.

NPC crew can fill empty roles when fewer than six human players are present.
