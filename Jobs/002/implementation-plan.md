# Implementation Plan — Job #002

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:27:08
**Status**: Planning (awaiting go-ahead)

## Analysis

Job 001 built a single studio/ sync root because no Roblox place existed yet. The place now exists with two places, confirmed from the Studio Asset Manager: 'The Last Tide' id 91870148721134 (start place, role = lobby, per the user) and 'The Last Tide Game' id 100885379547959 (role = game). A single root would therefore be wrong and misleading. User decisions via wizard: the game place lives in a folder named studio_game (user's wording); lobby gets studio_lobby for symmetry so neither place is the unnamed default - Jungle's asymmetric sync/ vs lobby/sync/ is precisely what has caused a cross-place editing mistake before. All four knowledge targets approved: decision record, system doc, skill section, asset registry place qualifiers. Two index lines are in scope so the new docs are not orphaned from the pack's own indexes; no other index cleanup (declined in job 001) is touched. Nothing is known yet about the lobby's actual contents - the system doc states intent derived from docs/systems/shipyard and docs/game/progression (Shipyard/fleet/loadout are between-run, therefore lobby) and must be corrected against Studio via MCP once either place has content.

## Implementation steps

1. Delete the empty studio/ tree; create studio_lobby/ and studio_game/ service folders with .gitkeep
2. Replace default.project.json with lobby.project.json and game.project.json (explicit names, no misleading default)
3. Update .jobconfig.json for both trees; keep the PROVISIONAL note since sync arrows are still unobserved
4. Add docs/decisions/0013-two-places-lobby-and-game.md and one line in docs/decisions/INDEX.md
5. Add docs/systems/places/README.md with the place id table, what-lives-where, boundary state rules, and one line in docs/INDEX.md systems list
6. Add a Places section to .claude/skills/tide-project/SKILL.md and correct its repo-layout block
7. Add a place: qualifier to all six entries in assets/registry/assets.yaml plus a header comment defining the convention
8. Verify: JSON valid, all skill links resolve, no design content altered beyond the two index lines and the registry qualifiers

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
