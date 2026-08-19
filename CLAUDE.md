# The Last Tide — Claude Instructions

## Purpose

This repository is the canonical design/planning memory for a Roblox co-op ocean survival game.

Roblox Studio is connected through MCP and is the authority for the current instantiated hierarchy and current game code.

## Before changing gameplay

1. Read `docs/INDEX.md`.
2. Read the relevant `docs/systems/<system>/README.md`.
3. Read the active feature under `docs/features/`.
4. Read relevant accepted decisions under `docs/decisions/`.
5. Inspect the real Roblox Studio implementation through MCP.
6. Do not assume documentation means code exists.
7. Do not assume missing documentation means code does not exist.
8. Do not silently overturn an accepted design decision.

## Sources of truth

- Current game-design intent: `docs/game/` and `docs/systems/`
- Feature requirements/work status: `docs/features/`
- Accepted design decisions: `docs/decisions/`
- Content catalogs: `docs/content/`
- Asset status: `assets/registry/assets.yaml`
- Actual Roblox code/hierarchy: Roblox Studio through MCP

## Allowed feature statuses

`IDEA`
`PLANNED`
`READY`
`IN_PROGRESS`
`IMPLEMENTED`
`VERIFIED`
`DEFERRED`
`REMOVED`

`IMPLEMENTED` means code/content exists.

`VERIFIED` requires an actual Roblox Studio/playtest check. Never mark a feature `VERIFIED` because code was merely written.

## Development workflow

For every feature:

1. Read its requirements and dependencies.
2. Inspect current Roblox Studio implementation through MCP.
3. Update or create the implementation plan.
4. Implement the smallest complete step.
5. Test in Studio.
6. Update the feature checklist/status.
7. Update relevant current-state system documentation.
8. Update `assets/registry/assets.yaml` when assets change.
9. Add a decision record if an important design/architecture choice changes.
10. Keep current-state docs clean: do not turn system docs into changelogs.

## Documentation model

- `docs/systems/` = how the current intended system works
- `docs/features/` = individual units of planned or completed work
- `docs/decisions/` = why important choices were made
- `docs/content/` = compact catalogs for enemies, weapons, islands, loot, events, upgrades, vessels and crew
- `docs/roadmap/` = sequencing and release scope

## Asset workflow

Meshy is used for generated 3D assets.

Before creating a new asset:
1. Check `assets/registry/assets.yaml`.
2. Inspect Roblox Studio for an equivalent asset.
3. Reuse or extend an existing asset where reasonable.
4. Record the Meshy prompt and intended Roblox path.
5. Keep gameplay-important moving parts separate where animation/rotation is required.

## Game pillars

Preserve these unless an accepted decision changes them:

1. The vessel is the mobile base and one of the game's main characters.
2. Day is primarily for exploration, looting and preparation.
3. Night is primarily for survival, defense and escape.
4. A chasing storm creates macro forward pressure.
5. Radar is a core progression/navigation system.
6. The normal HUD is minimal; boat information should be diegetic where practical.
7. Major islands are curated templates, not uncontrolled runtime terrain generation.
8. The ocean should feel huge even if the physical map window is reused.
9. Permanent progression unlocks stronger starting vessels, parts, blueprints, role mastery and options without invalidating the in-run upgrade loop.
10. Third-person is the default camera with contextual first-person modes.
11. NPC crew fill missing human roles; they should not replace the value of skilled human players.
12. Permanent fleet progression belongs to each participating player's account; active expedition upgrades belong to the run.
13. Main permanent ship progression is parts/component based, not a single universal token economy.
