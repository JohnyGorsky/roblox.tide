# Build Status - The Last Tide

> **Generated file - do not edit.** Run `python tools/build-status.py`.
> Status lives in each feature's own frontmatter; this board only reports it, so the two
> cannot disagree. Change a status in `docs/features/<id>/feature.md` and re-run.

`VERIFIED` requires a real Studio/playtest check - never award it for code merely written.

## Features by area

### sea

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `###..` | [Sea & Sea States](docs/features/0011-sea-states/feature.md) | GAME-0011 | IN_PROGRESS | P0 |
| `##...` | [Wave Field](docs/features/0014-wave-field/feature.md) | GAME-0014 | READY | P0 |

### boat

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Boat Controller](docs/features/0001-boat-controller/feature.md) | GAME-0001 | PLANNED | P0 |
| `#....` | [Vessel Class Foundation](docs/features/0008-vessel-class-foundation/feature.md) | GAME-0008 | PLANNED | P1 |

### atmosphere

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Advancing Storm Front](docs/features/0003-storm-front/feature.md) | GAME-0003 | PLANNED | P0 |
| `#....` | [Day / Dusk / Night](docs/features/0004-day-night/feature.md) | GAME-0004 | PLANNED | P0 |

### islands

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Curated Island Library](docs/features/0005-island-library/feature.md) | GAME-0005 | PLANNED | P0 |

### lobby

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Shipyard Parts Progression](docs/features/0010-shipyard-parts-progression/feature.md) | GAME-0010 | PLANNED | P1 |
| `###..` | [Harbour Environment](docs/features/0013-harbour-environment/feature.md) | GAME-0013 | IN_PROGRESS | P1 |

### navigation

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Radar Mk1](docs/features/0002-radar/feature.md) | GAME-0002 | PLANNED | P0 |

### combat

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Basic Combat](docs/features/0006-basic-combat/feature.md) | GAME-0006 | PLANNED | P0 |

### crew

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [NPC Crew Foundation](docs/features/0009-npc-crew/feature.md) | GAME-0009 | PLANNED | P1 |

### character

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `#....` | [Player Task Animations](docs/features/0007-player-task-animations/feature.md) | GAME-0007 | PLANNED | P0 |

### infra

| | Feature | Id | Status | Pri |
|---|---|---|---|---|
| `###..` | [Admin Panel & Dev Tools](docs/features/0012-admin-panel/feature.md) | GAME-0012 | IN_PROGRESS | P1 |

## Roll-up

| Status | Features |
|---|---|
| PLANNED | 10 |
| READY | 1 |
| IN_PROGRESS | 3 |
| **total** | **14** |

## The build manifest - what actually needs making

Groups are sized to be taken one at a time. See [docs/build/README.md](docs/build/README.md).

| Group | Covers | Items |
|---|---|---|
| [01 — Sea & horizon](docs/build/01-sea.md) | the water itself, sea states from dead calm to the storm wall, and every trick that makes a bounded map feel like open ocean. | ~34 |
| [02 — Boat parts](docs/build/02-boat-parts.md) | every physical part of a vessel, from the hull to the fuse box, plus the module system that lets seven vessel classes share one parts library. | ~118 (78 for the starter launch and its upgrade paths, 12 module/system pieces, 7 hulls, ~21 shared fittings) |
| [03 — Items & props](docs/build/03-items-props.md) | the small stuff — resources you pick up, containers you open, and the scenery that dresses every island, wreck and deck. | ~92 (23 pickups, 10 containers, 44 scenery props, 15 systems) |
| [04 — Islands & sea POIs](docs/build/04-islands.md) | the places you stop at — 12 curated islands, 9 sea POIs, 6 rare POIs, plus the template machinery that spawns and varies them. | ~27 locations + 18 system pieces |
| [05 — Enemies & groups](docs/build/05-enemies.md) | 18 enemies, the groups they arrive in, and the AI that makes them attack *systems and plans* rather than only health. | 18 enemies × (mesh + rig + animation set + sounds + behaviour) ≈ 90 asset units, + 12 group definitions, + 16 system pieces |
| [06 — Weapons](docs/build/06-weapons.md) | 16 hand weapons and 3 mounted weapons, built so each solves a *different problem* rather than forming a damage ladder. | 19 weapons + 14 system pieces + ~12 ammo/VFX assets |
| [07 — Atmosphere, storm & day/night](docs/build/07-atmosphere.md) | the chasing storm, the day→night heartbeat, and the lighting/weather layer that carries most of the game's mood. | ~58 |
| [08 — Lobby & shipyard](docs/build/08-lobby-shipyard.md) | the harbour you return to — the Shipyard, your fleet, your parts, your crew roster, and the departure that starts an expedition. | ~54 |
| [09 — UI & HUD](docs/build/09-ui.md) | the deliberately minimal HUD, the diegetic instruments that replace it, and every screen the player actually opens. | ~48 |
| [10 — NPC crew](docs/build/10-crew.md) | the AI crew who fill empty roles so a small party can sail a big ship, without making human players redundant. | ~40 |
| [11 — Animations](docs/build/11-animations.md) | every animation in the game — the player's working set, storm reactions, and the per-enemy sets. | ~44 player/shared clips + ~90 enemy clips + 9 system pieces |
| [12 — Audio](docs/build/12-audio.md) | the sound of a cold ocean at night — ambience, machinery, weather, creatures, and the music that knows when to stop. | ~96 sounds + 12 system pieces |
| [13 — Admin panel & dev tools](docs/build/13-admin-tools.md) | an admin button visible only to authorised developers, opening a panel that can drive the game's systems directly — sea state, time, storm, spawning, item granting. | ~34 |

## Assets

| Status | Count |
|---|---|
| GRAYBOX | 1 |
| IDEA | 8 |
| IMPLEMENTED | 2 |

### Graybox placeholders awaiting real art

| Placeholder | Stands in for | Place | Note |
|---|---|---|---|
| `GB-LOBBY-DOCK` | ASSET-LOBBY-HARBOUR-DOCK | lobby | 64 x 4 x 40 WoodPlanks slab at Y=2, Weathered Wood colour. Exists because the lobby has |

Verify against the live places with `tools/audit-graybox.luau` - it catches placeholders
that exist in Studio but were never registered.

## Delivered (jobs with a final summary)

- [x] **001** Scaffold roblox.tide for the multi-root workspace
- [x] **002** Record the two-place architecture (lobby + game)
- [x] **003** Align the sync layout with what Studio Sync actually does
- [x] **004** Configure the settings baseline for both places
- [x] **005** Build tracking board and graybox register
- [x] **006** Write the build manifest
- [x] **007** Build the sea: ocean terrain and sea-state presets
- [x] **008** Add admin panel to the build plan
- [x] **009** Build the admin gate, panel shell and sea tools
- [x] **010** Give the lobby water and remove both baseplates
- [x] **011** Record decisions 0014-0017: storm consequence, shared rig, island storage, deck navigation
- [ ] **012** Wave field: HeightAt / NormalAt for the sea surface
- [x] **013** Admin panel: atmosphere and palette colour controls

An unchecked job is still in flight.

