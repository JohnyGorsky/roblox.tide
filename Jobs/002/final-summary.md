# Final Summary — Job #002

**Project**: `roblox.tide`
**Completed**: 2026-08-19 22:30:42
**Status**: ✅ Completed

## What was implemented

The experience now exists with two places, so job 001's single studio/ sync root was replaced. Sync roots: studio_lobby/ = 'The Last Tide' (91870148721134, start place, lobby) and studio_game/ = 'The Last Tide Game' (100885379547959, game), each with the six service folders and its own Rojo project (lobby.project.json, game.project.json). default.project.json was deleted deliberately - with two places an unnamed default is a trap, and Jungle's asymmetric sync/ vs lobby/sync/ is exactly what has caused a cross-place edit mistake before, so both places are named in their paths. Knowledge captured in four places: decision 0013 records WHY the split exists and its three consequences (permanent progression crosses only as DataStore account data, run state does not cross back, every file belongs to exactly one place); docs/systems/places/README.md records HOW it works - id table, what-lives-where, the boundary diagram, what is carried each way, and five rules; the tide-project skill gained a Places section plus a corrected repo-layout block so the split loads automatically; and all six entries in assets/registry/assets.yaml gained a place qualifier, since bare service paths like ServerStorage.Assets.Boats.StarterBoat became ambiguous - four assets are game+lobby because the Shipyard and crew roster need display copies. Two index lines were added (docs/decisions/INDEX.md, docs/INDEX.md systems list) so the new docs are not orphaned from the pack's own indexes; the broader INDEX cleanup declined in job 001 is still untouched. Also corrected two counts in the skill that the new docs made stale (13 decisions, 17 systems). IMPORTANT: the what-lives-where split is design intent derived from docs/systems/shipyard and docs/game/progression, NOT an observation - both places are empty, and the system doc says so explicitly.

### Files changed

_None of these are Studio-synced scripts — this job touched docs, the skill and
configuration only. (See workspace finding 0000 for the mislabelling.)_

- `docs/decisions/0013-two-places-lobby-and-game.md`
- `docs/decisions/INDEX.md`
- `docs/systems/places/README.md`
- `docs/INDEX.md`
- `.claude/skills/tide-project/SKILL.md`
- `assets/registry/assets.yaml`
- `lobby.project.json`
- `game.project.json`
- `.jobconfig.json`

### Structure changed

- created `studio_lobby/` and `studio_game/`, each with `ReplicatedFirst/`, `ReplicatedStorage/`,
  `ServerScriptService/`, `ServerStorage/`, `StarterPlayer/StarterPlayerScripts/`,
  `StarterPlayer/StarterCharacterScripts/`
- deleted the single `studio/` tree and `default.project.json` from job 001
- created `docs/systems/places/`

### ⚠️ Manual Studio steps still required (human)

- Point Studio Sync / Rojo at `lobby.project.json` for The Last Tide and `game.project.json` for
  The Last Tide Game — one at a time, per place.
- Confirm the sync arrows in each place's Explorer against `.jobconfig.json` (todo 0000).
- Confirm whether `studio_game/StarterCharacterScripts/` and `studio_game/StarterPlayerScripts/`
  (empty, at the wrong level, appeared 22:27) were intentional — left in place, see finding 0000.

## Verification

- [x] `lobby.project.json`, `game.project.json` and `.jobconfig.json` are valid JSON
- [x] Each Rojo project maps `DataModel` to its own `studio_<place>/<Service>` paths only
- [x] Every relative link in every markdown file in the repo resolves (repo-wide check)
- [x] All 22+ links in `tide-project/SKILL.md` resolve
- [x] `assets.yaml` parses; all 6 assets carry a `place` qualifier
- [x] Decision 0013 is listed in `docs/decisions/INDEX.md`; places doc is listed in `docs/INDEX.md`
- [x] Design content untouched apart from the two index lines and the registry qualifiers
- [ ] Rojo actually serves each place — **cannot be checked until the places have content**
- [ ] The what-lives-where split matches reality — **intent only; both places are empty**
