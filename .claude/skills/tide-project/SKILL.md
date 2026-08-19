---
name: tide-project
description: The Last Tide (roblox.tide) project context — a 1–6 player co-op ocean survival roguelite. Points at the repo's design pack (vision, pillars, systems, accepted decisions, content catalogs, features, roadmap) and carries the game's non-negotiable rules: inspect Studio via MCP before claiming implementation state, IMPLEMENTED is not VERIFIED, and never silently overturn an accepted decision. Consult this before ANY work in roblox.tide.
---

# The Last Tide — project context

**This skill is the entry point for The Last Tide (`roblox.tide`).** Read it before touching anything
in that repo.

> All games' skills load at once in this multi-root workspace. This one is for **The Last Tide**
> (ocean survival roguelite) — *not* Defender and *not* Jungle/Last River. Note the similar names:
> **Last River** is Jungle; **The Last Tide** is this game.

Use the shared `roblox-dev` skill for engine APIs and the workspace `GROUND-RULES.md` above all else.

## What the game is

A **1–6 player co-op ocean survival roguelite**. Each expedition starts with a vessel from the
player's persistent fleet (new players get a battered motor launch). The crew explores curated
islands, wrecks and sea POIs by **day**, upgrades the active vessel, and **survives** escalating
nights while a massive supernatural storm advances from behind. Permanent progression is
**parts/component based** — collected parts and rare named components improve starting vessels and
construct new vessel classes in the Shipyard.

Full vision: [docs/game/vision.md](../../../docs/game/vision.md).

## The repo is design memory; Studio is the code

This repo currently holds **no game code** — it is the long-term design/planning memory. The split is
load-bearing:

| Question | Authority |
|---|---|
| What the game **should** be, and **why** | this git repo (`docs/`) |
| What **actually exists** right now | the live Roblox Studio session, via MCP |

Therefore:

- **Inspect Studio through MCP before claiming implementation state.** Documentation existing does not
  mean code exists; documentation missing does not mean code doesn't exist.
- **`IMPLEMENTED` is not `VERIFIED`.** `IMPLEMENTED` = code/content exists. `VERIFIED` requires a real
  Studio/playtest check with a recorded result. Never mark `VERIFIED` because code was merely written.
- **Never silently overturn an accepted decision** in [docs/decisions/](../../../docs/decisions/INDEX.md).
  If a decision needs to change, add a new decision record saying so.

## Two places — check which one you are in

The experience is **two Roblox places**. Confirm which one owns a file **before** editing it:

| Role | Place | Id | Sync root | Rojo project |
|---|---|---|---|---|
| Lobby (start place) | The Last Tide | `91870148721134` | `studio_lobby/` | `lobby.project.json` |
| Game | The Last Tide Game | `100885379547959` | `studio_game/` | `game.project.json` |

Lobby = between runs (Shipyard, fleet, parts inventory, loadout, crew roster, party forming).
Game = one expedition (vessel, ocean, storm, islands, enemies, in-run upgrades).

`studio_lobby/` and `studio_game/` are separate worlds that share a repo. Both places are named in
their paths on purpose so no path is ambiguous about its owner. Permanent progression crosses the
boundary as account data through DataStores; in-run power does not cross back.

Detail: [docs/systems/places/README.md](../../../docs/systems/places/README.md) ·
why: [decision 0013](../../../docs/decisions/0013-two-places-lobby-and-game.md).

## Where to read (start here)

1. [docs/INDEX.md](../../../docs/INDEX.md) — the map of everything below.
2. [docs/game/vision.md](../../../docs/game/vision.md) and
   [core-loop.md](../../../docs/game/core-loop.md) — what the game is and how a session feels.
3. The relevant `docs/systems/<system>/README.md` — how that system is *intended* to work now.
4. The active feature under [docs/features/](../../../docs/features/) — requirements + status.
5. The relevant accepted decisions in [docs/decisions/](../../../docs/decisions/INDEX.md).
6. Then inspect the real Studio implementation via MCP.

| Area | Doc |
|---|---|
| Vision, core loop, pillars, progression, monetization, naming | `docs/game/` |
| Visual/UI direction (palette, typography, HUD rules) | [visual-design.md](../../../docs/game/visual-design.md), [gui.md](../../../docs/game/gui.md), [fonts.md](../../../docs/game/fonts.md) |
| Intended behavior of each system (17 of them) | `docs/systems/` |
| Why an important choice was made (13 accepted) | `docs/decisions/` |
| Compact catalogs — enemies, weapons, vessels, islands, loot, events, encounters, upgrades, parts, crew | `docs/content/` |
| The two places and what lives in each | [systems/places/README.md](../../../docs/systems/places/README.md) |
| Sequencing and release scope | `docs/roadmap/` (start with [poc.md](../../../docs/roadmap/poc.md)) |
| Asset status | [assets/registry/assets.yaml](../../../assets/registry/assets.yaml) |
| The game's own full instruction text | [CLAUDE.md](../../../CLAUDE.md) (does **not** auto-load — see below) |

## The pillars are load-bearing

Thirteen pillars in [docs/game/game-pillars.md](../../../docs/game/game-pillars.md) and
[CLAUDE.md](../../../CLAUDE.md). Preserve them unless an accepted decision changes them. The ones most
often violated by well-meaning implementation:

- **The vessel is the mobile base**, not transportation — it holds navigation, storage, power, repair,
  weapons, lighting and progression.
- **Radar creates decisions; there is no permanent minimap.** Do not add a minimap that leaks
  equivalent information (decision 0004).
- **Minimal HUD, diegetic instruments.** Boat information belongs on the boat where practical; player
  information belongs on the HUD.
- **Curated proceduralism.** Major islands are approved templates, not uncontrolled runtime terrain
  generation (decision 0003).
- **Enemies attack systems and plans, not only HP** — stop engines, disable radar, create leaks, board,
  steal cargo.
- **Permanent progression is parts/components**, not one universal token currency (decision 0012), and
  it is credited to **every** participating player, not just the host (decision 0011).
- **Third-person default**, contextual first-person only (decision 0001).

## Repo layout

```text
roblox.tide/
  CLAUDE.md            game's own instruction text (does not auto-load — see below)
  README.md            design pack overview
  docs/                design memory: game/ systems/ decisions/ content/ features/ roadmap/
  assets/              registry/assets.yaml, meshy/ records + template, references/palette/
  studio_lobby/        sync root for the LOBBY place (The Last Tide, 91870148721134)
  studio_game/         sync root for the GAME place (The Last Tide Game, 100885379547959)
  lobby.project.json   Rojo mapping: DataModel -> studio_lobby/<Service>
  game.project.json    Rojo mapping: DataModel -> studio_game/<Service>
  .jobconfig.json      synced vs manual-copy paths, for job.py final summaries
  Jobs/                worked jobs (workspace lifecycle)
  Planned/             one file per queued idea
  todo/  findings/     quick capture queues
```

## Workflow: features are memory, Jobs are execution

The repo's feature pack and the workspace job lifecycle both apply, at different layers:

- **[docs/features/](../../../docs/features/)** owns *what* and *why*: requirements, dependencies,
  acceptance criteria, and the status ladder
  `IDEA → PLANNED → READY → IN_PROGRESS → IMPLEMENTED → VERIFIED` (plus `DEFERRED` / `REMOVED`). See
  [docs/development-workflow.md](../../../docs/development-workflow.md).
- **`Jobs/`** owns *doing it*: `intake.md` → `implementation-plan.md` → implement →
  `final-summary.md` + `changelog.md`. Scaffold with
  `python ../roblox.workspace/tools/job.py new --project tide "Title" "Requirements"`.

A job that advances a feature should name the feature id (`GAME-000N`) and update its status and
`last_verified` when it lands. New feature folders copy [docs/features/_template/](../../../docs/features/_template/)
(`feature.md`, `plan.md`, `test.md`).

Per-feature checklist when implementing:

1. Read the feature's requirements and dependencies, its system docs, and the relevant decisions.
2. Inspect the current Studio implementation via MCP and record what's actually there.
3. Implement the smallest complete step.
4. Test in Studio — a human presses Play and judges feel.
5. Update the feature checklist/status (`VERIFIED` only after a real check).
6. Update the system doc if intended behavior changed. **Keep system docs as current-state
   descriptions — never turn them into changelogs.**
7. Update `assets/registry/assets.yaml` if assets changed.
8. Add a decision record if an important design/architecture choice changed.

## Assets

Meshy for generated 3D. Before creating anything new: check
[assets/registry/assets.yaml](../../../assets/registry/assets.yaml), then inspect Studio for an
equivalent, then reuse or extend. Record the Meshy prompt and the intended Roblox path
([assets/meshy/_template.md](../../../assets/meshy/_template.md)). Lifecycle:
`IDEA → PROMPT_READY → GENERATED → CLEANUP → IMPORTED → INTEGRATED → VERIFIED`.

**Keep gameplay-important moving parts separate** before import — the radar antenna must rotate, so it
cannot be baked into the mast.

The workspace asset policy still governs: our inventory and registry first, present candidates for
human approval before use, scan every inserted model for scripts, and maintain the shared registry at
`roblox.workspace/Assets/registry/`. See the `roblox-assets` skill.

## Visual direction (short form)

"Bermuda military expedition + supernatural ocean survival" — believable at first, increasingly
strange. Roughly **70%** dark blues/greys, **20%** muted support colors, **10%** accents. Avoid a
bright cheerful tropical-blue Roblox look.

Key accents: Radar Green `#52FF9A` · Warning Amber `#F2B544` · Danger Red `#D94B4B` ·
Loot Gold `#D9B65C`. Base: Abyss Navy `#0B1E2D` · Deep Ocean Blue `#12354A` · Fog Grey `#8C9AA3`.

Typography is maritime/military/industrial, never playful. Verify which font faces actually exist in
Studio before implementing. Full palette and rules:
[docs/game/visual-design.md](../../../docs/game/visual-design.md),
[gui.md](../../../docs/game/gui.md), [fonts.md](../../../docs/game/fonts.md), and
[assets/references/palette/palette.md](../../../assets/references/palette/palette.md).

## Note on CLAUDE.md

`roblox.tide/CLAUDE.md` holds the game's own full instruction text, but **it does not auto-load** —
in this multi-root workspace only the primary directory's `CLAUDE.md` loads, while skills load from
every game folder. That is why this skill exists. When a rule changes, update **both** so they don't
drift.
