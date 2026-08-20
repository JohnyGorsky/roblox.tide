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

| P | # | Group | First job | Note |
|---|---|---|---|---|
| **P0** | [01](01-sea.md) | Sea & horizon | Wave field (`HeightAt`/`NormalAt`) | Ocean built; this is the maths everything floats on. Look **blocked on sky assets** |
| **P0** | [07](07-atmosphere.md) | Atmosphere & storm | Day/night cycle, then storm core | Judgeable with no boat at all. Defines the *full range* of sea before anything is tuned to it |
| **P0** | [02](02-boat-parts.md) | Boat parts | Vessel foundation — hull at real size, floats, steers | Arrives into a finished world, so buoyancy is tuned once against calm *and* The Wall |
| **P0** | [03](03-items-props.md) | Items & props | Item foundation + run resources | Fuel/scrap/ammo *is* the loop |
| **P0** | [04](04-islands.md) | Islands & POIs | Template pipeline + the small island | Somewhere to go |
| **P0** | [11](11-animations.md) | Animations | Foundation + player task set | Repair must look like repair |
| **P0** | [09](09-ui.md) | UI & HUD | Design system, then minimal HUD | You must be able to read fuel and hull |
| **P0** | [05](05-enemies.md) | Enemies | Foundation + the shark | The first night threat |
| **P0** | [06](06-weapons.md) | Weapons | The signature trio: MG, harpoon, flare | Something to fight with |
| **P1** | [08](08-lobby-shipyard.md) | Lobby & shipyard | Persistence foundation | The reason to play a *second* run |
| **P1** | [12](12-audio.md) | Audio | Foundation + vessel machinery | Cheapest large gain in mood |
| **P1** | [10](10-crew.md) | NPC crew | Crew foundation (one Engineer) | Makes solo and small parties work |
| **P2** | [13](13-admin-tools.md) | Admin panel | *gate + sea tools done* | Accelerator; grows with the systems |

**P0 = the POC loop.** These nine are exactly what [roadmap/poc.md](../roadmap/poc.md) needs to answer the
only question that matters yet: *is `explore → dusk → survive → dawn` fun with other people?* Build the
**first job** of each, not the whole group — group 02 alone is nine jobs.

**P1** is what makes people come back — persistence above all. **P2** is depth and support.

### Why sea and atmosphere come before the boat

Both are judgeable with no boat in the world, and between them they define the **full range of sea** the
vessel has to cope with. Building the boat first means tuning buoyancy against Light Swell, then re-tuning
it when Storm and The Wall appear; doing it after means tuning once, against everything.

⚠️ **One part of group 07 cannot precede the boat.** Decision
[0014](../decisions/0014-storm-consequence.md) makes the storm inflict hull damage and system faults — and
there is no hull and no system to fault until group 02 exists. So 07 splits:

| Before the boat | After the boat |
|---|---|
| Day/night cycle, storm position and intensity, sea-state coupling, cloud wall, rain, wind, lightning, fog | The caught-by-storm consequence: damage rate, forced faults, the 30–60s escape window |

Tuning that escape window is the last thing to do, not the first.

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
