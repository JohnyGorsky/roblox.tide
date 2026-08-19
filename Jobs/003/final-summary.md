# Final Summary — Job #003

**Project**: `roblox.tide`
**Completed**: 2026-08-19 22:44:16
**Status**: ✅ Completed

## What was implemented

Tested the sync instead of assuming it, and the job 002 layout turned out to be wrong. Studio Sync uses a FLAT layout: studio_game/StarterPlayerScripts/ reaches StarterPlayer.StarterPlayerScripts, while the Rojo-style studio_game/StarterPlayer/StarterPlayerScripts/ never arrives - so Jungle's nested sync/StarterPlayer/ shape must not be copied here. Both sync roots were flattened and the dead nested trees deleted. Observed sync scope for the game place: ReplicatedFirst, ReplicatedStorage, ServerStorage, StarterPlayerScripts and StarterCharacterScripts all sync; ServerScriptService, StarterGui, StarterPack and Workspace do not. Observed class mapping: .luau gives a ModuleScript, .client.luau gives a Script with RunContext=Client, and .module.luau is NOT a recognised suffix - it produces a ModuleScript literally named Name.module, which would have been a silent trap. Deletions propagate and left no residue, verified by MCP after cleanup. .jobconfig.json and both Rojo project files were rewritten from these observations rather than convention, and the facts are recorded in a new 'Studio Sync - verified behavior' section of docs/systems/places/README.md plus a short form in the tide-project skill. Finding 0000 was resolved as not-a-defect with the corrected diagnosis: the folders I had called stray were created by Studio Sync and are canonical, while the nested pair I created were the dead ones. Two blockers remain, both Studio-side and not fixable from disk: finding 0001, ServerScriptService does not sync in the game place, which leaves nowhere on disk for server logic; finding 0002, the lobby place is not connected to sync at all, which blocks all Shipyard/fleet/loadout work.

### Files changed

_Docs and configuration only — no game code exists yet.
(See workspace finding 0000 for why the heading said "auto-synced".)_

- `.jobconfig.json`
- `lobby.project.json`
- `game.project.json`
- `docs/systems/places/README.md`
- `.claude/skills/tide-project/SKILL.md`

### Structure changed

- deleted `studio_lobby/StarterPlayer/` and `studio_game/StarterPlayer/` (proven dead — never sync)
- both roots now flat: `ReplicatedFirst/`, `ReplicatedStorage/`, `ServerScriptService/`,
  `ServerStorage/`, `StarterPlayerScripts/`, `StarterCharacterScripts/`
- all probe files removed; game place verified clean over MCP

### Both blockers fixed and re-verified (second probe round)

The user fixed both Studio-side, and a second probe round confirmed it: **all six folders now sync in
both places**, and the two places behave identically. Findings 0001 and 0002 resolved, todo 0000
resolved as superseded.

The re-probe also settled what the first round could not, because `ServerScriptService` was dead then:

- `.server.luau` → `Script` with `RunContext = Server`; `.client.luau` → `RunContext = Client`
  **even inside `ServerScriptService/`** — the suffix decides run context, not the folder.
- A folder containing `init.luau` becomes that script itself, with its siblings parented under it;
  other subfolders become `Folder` instances.

`.jobconfig.json` was rewritten a second time from these observations (12 synced paths, 6 non-synced),
and the places doc and skill were corrected. Still unverified: `StarterGui/`, `StarterPack/` and
`Workspace/` were not re-probed, to avoid pulling place world content onto disk — todo 0002.

## Verification

- [x] Flat layout confirmed by probe: `studio_game/StarterPlayerScripts/_ProbeFlat.luau` →
      `StarterPlayer.StarterPlayerScripts._ProbeFlat`
- [x] Nested layout disproven: `studio_game/StarterPlayer/StarterPlayerScripts/_ProbeNested.luau`
      never arrived
- [x] Per-folder sync scope mapped with 9 simultaneous probes, one per service folder
- [x] Class mapping confirmed: `.luau` → ModuleScript, `.client.luau` → Script/RunContext=Client,
      `.module.luau` → ModuleScript named `_ProbeD.module`
- [x] Deletion propagation confirmed — file removed, instance gone
- [x] Probe residue removed; `game:GetDescendants()` scan returns clean
- [x] `.jobconfig.json`, `lobby.project.json`, `game.project.json` valid JSON, paths match disk
- [x] Every relative link in the repo still resolves
- [ ] Rojo serve — **not exercised**; the live sync is Studio Sync, so the project files are
      unverified against Rojo itself
- [x] Lobby sync — all six folders verified after the fix
- [x] `ServerScriptService` verified in both places after the fix
- [x] `.server.luau` / `.client.luau` / `init.luau` behavior confirmed by probe
- [x] Both places re-verified clean of probe residue after cleanup
- [ ] `StarterGui/`, `StarterPack/`, `Workspace/` — not re-probed (todo 0002)
