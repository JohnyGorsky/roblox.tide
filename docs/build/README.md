# The Build Manifest

**The list of everything that has to be made**, split into groups sized to be taken one at a time.

This answers a different question from the rest of `docs/`:

| Question | Where |
|---|---|
| What should the game *be*, and why | `docs/game/`, `docs/decisions/` |
| How a system is *intended to work* | `docs/systems/` |
| What *unit of work* delivers it, and its status | `docs/features/` |
| **What concrete things must be made, and how many** | **here** |
| Where everything stands right now | [BUILD-STATUS.md](../../BUILD-STATUS.md) (generated) |

The content catalogs in `docs/content/` list *what exists in the fiction* (18 enemies, 16 weapons, 12
islands). This manifest lists *what must be built to put them on screen* — which is a much longer list,
because one enemy is a mesh, a rig, five animations, a sound set, an AI behaviour and a spawn entry.

## Groups

Each file is one work package. They are ordered so that each group can be judged as soon as it lands,
and so nothing waits on something that does not exist yet.

| # | Group | Why here in the order |
|---|---|---|
| [01](01-sea.md) | Sea & horizon | Everything else floats on it. Judgeable immediately, and it decides how big the world feels |
| [02](02-boat-parts.md) | Boat parts | The mobile base. The single biggest item count in the project |
| [03](03-items-props.md) | Items & props | Small, reusable, needed by every island and the whole loot loop |
| [04](04-islands.md) | Islands & sea POIs | Needs 01 (water line) and 03 (props to put on them) |
| [05](05-enemies.md) | Enemies & groups | Needs 04 to have somewhere to live |
| [06](06-weapons.md) | Weapons | Needs 05 to have something to shoot |
| [07](07-atmosphere.md) | Atmosphere, storm, day/night | Layers on top of 01; the storm is the macro pressure |
| [08](08-lobby-shipyard.md) | Lobby & shipyard | Separate place; can proceed in parallel any time |
| [09](09-ui.md) | UI & HUD | Needs the systems it reports on to exist first |
| [10](10-crew.md) | NPC crew | Needs 02 (stations) and 11 (animations) |
| [11](11-animations.md) | Animations | Cross-cutting; the player set is needed early, enemy sets follow 05 |
| [12](12-audio.md) | Audio | Cross-cutting; cheapest big win once scenes exist |

Parallel-safe: **01 + 08** (different places), **03 + 11** (assets vs rigs), **12** with anything.

## How an item becomes done

```text
manifest item          you are reading it now
  -> feature           docs/features/NNNN-*/ owns requirements + status
  -> job               Jobs/NNN/ owns doing it (intake -> plan -> summary)
  -> asset entry       assets/registry/assets.yaml if it is art
  -> BUILD-STATUS.md   generated; never edited by hand
```

A group is usually **several** features, not one. Group 02 alone is nine features.

## Columns used in the item tables

| Column | Meaning |
|---|---|
| **Item** | The thing to make |
| **What it is** | Enough detail to build it without re-deciding the design |
| **GB** | ✅ = a graybox stands in fine for playtesting · ⚠️ = graybox distorts the feel, build it properly · ❌ = pure code/data, nothing to graybox |
| **Source** | `meshy` · `studio` (built from parts/terrain) · `code` · `store` (Creator Store, needs the approval + script-scan flow) · `sound` |

**GB ⚠️ is the important one.** A grey block is fine for a crate and misleading for a hull: wrong size
teaches wrong sightlines, wrong mass teaches wrong handling. See
[assets/README.md](../../assets/README.md) for the graybox register — every placeholder is recorded with
what it stands in for, and [`tools/audit-graybox.luau`](../../tools/audit-graybox.luau) catches the ones
nobody wrote down.

## Counts are estimates

Item counts are honest planning numbers, not contracts. They exist so a group can be sized before it is
started. Where a count depends on an undecided design question, the table says so rather than inventing
a number.

## Not in scope here

Balance numbers (damage, prices, health curves) belong in a balance skill, not this manifest — this is
*what to build*, not *how strong it is*. The one exception is where a dimension changes what gets built,
e.g. vessel length driving deck-space item counts.
