# Implementation Plan — Job #006

**Project**: `roblox.tide`
**Created**: 2026-08-19 23:50:18
**Status**: Planning (awaiting go-ahead)

## Analysis

Source material was the existing design pack: 13 pillars, 13 decisions, 17 system docs and 10 content catalogs, plus the engine skills for what is actually cheap or expensive to build. The manifest deliberately does NOT restate the fiction - docs/content already lists 18 enemies and 16 weapons. It lists what must be MADE to put them on screen, which is much longer, because one enemy is a mesh plus a rig plus five animations plus a sound set plus a behaviour plus a spawn entry. Three editorial rules: no balance numbers, because this is what-to-build not how-strong; every item carries a graybox verdict, because the wrong grey block actively teaches the wrong thing (a hull that is the wrong size teaches wrong sightlines and deck space); and every group ends with its open questions rather than inventing answers to undecided design.

## Implementation steps

1. docs/build/README.md - how the manifest relates to systems/features/content, the group order and why, the column conventions, the graybox rule
2. 01-sea.md - sea states, surface detail, the infinite-horizon techniques, boundaries. Leads with the engine fact that terrain-water waves do not move objects
3. 02-boat-parts.md - the module-kit-then-hulls approach, ~118 items across 12 sections, the seven hulls with dimensions
4. 03-items-props.md - resources, parts, rare components, containers, a 44-item scenery kit, and the carry/inventory systems
5. 04-islands.md - a fully worked small island (props, loot, enemies, groups, weapons, six variants) as the reference build, then 12 islands, 9 sea POIs, 6 rare POIs and the template machinery
6. 05-enemies.md - 18 enemies each named by what SYSTEM it breaks, 12 enemy group definitions, and the AI systems
7. 06-weapons.md through 12-audio.md - weapons, atmosphere/storm/day-night, lobby/shipyard, UI, crew, animations, audio
8. Regenerate BUILD-STATUS.md so the board lists the groups with their item counts; link the manifest from docs/INDEX.md and the skill

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
