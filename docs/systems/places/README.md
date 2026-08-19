# Places / Experience Structure

The Last Tide is **two Roblox places** in one experience. See decision
[0013](../../decisions/0013-two-places-lobby-and-game.md) for why.

| Role | Place name | Place id | Sync root | Rojo project |
|---|---|---|---|---|
| Lobby (start place) | The Last Tide | `91870148721134` | `studio_lobby/` | `lobby.project.json` |
| Game | The Last Tide Game | `100885379547959` | `studio_game/` | `game.project.json` |

Players always arrive in the lobby. An expedition is played in the game place.

## What lives where

### Lobby — between runs

- Shipyard: part/component spending, vessel upgrades, vessel construction projects
- permanent fleet: owned vessels, selecting the expedition vessel
- parts/component inventory and rare-component progress
- loadout and departure point selection
- NPC crew roster: owned crew, assignment, cosmetics
- role mastery, discoveries/codex, cosmetics
- party forming and the expedition launch
- end-of-run summary presentation, if shown after the return trip

### Game — one expedition

- the active vessel and all of its systems (hull, engine, fuel, generator, radar, lights, weapons)
- the ocean, horizontal wrapping and logical sea progression
- day/dusk/night and the advancing storm
- islands, wrecks, sea POIs, encounters and events
- enemies and combat
- in-run upgrades, loot and resources
- NPC crew actually performing tasks aboard

## Crossing the boundary

```text
LOBBY                                    GAME
choose vessel + loadout
form party
        ──── teleport (reserved server) ────>
                                         run the expedition
                                         collect parts/components
        <──── return + end-of-run ─────────
credit permanent progress
```

**Carried forward into the run:** the chosen vessel and its permanent configuration, the crew roster,
the departure point, and the party.

**Carried back out:** permanent progression only — parts/components, rare components, blueprints,
expedition XP, role mastery, discoveries/codex entries and highest sea stage reached. Per decision
[0011](../../decisions/0011-shared-expedition-rewards.md) this is credited to **every** eligible
participant, not just the host.

**Not carried back:** in-run vessel upgrades, in-run resources (fuel, scrap, ammo) and run state.
Most run power resets — decision [0008](../../decisions/0008-progression-model.md).

Permanent progression is **account data**. It crosses the boundary through DataStores, never by being
passed between places in memory. A player who joins a friend's expedition still earns their own
progression in their own account data.

## Rules

1. **Every script, asset and GUI belongs to exactly one place.** Confirm which place owns a file before
   editing it. `studio_lobby/` and `studio_game/` are separate worlds that happen to share a repo.
2. Both places are named in their sync paths on purpose. Neither is an unnamed default, so a path is
   never ambiguous about its owner.
3. Shared *code* is not shared automatically across places — Roblox has no cross-place
   ReplicatedStorage. If a module genuinely must exist in both, it is duplicated deliberately and that
   duplication is documented, or it is packaged so both places pull the same source.
4. The server is authoritative for permanent progression in both places. The lobby must validate part
   spending server-side exactly as the game place validates run actions.
5. Never trust a client's claim about what it earned in the game place.

## Current state

Both places exist and are **empty** — created 2026-08-19, no content or scripts yet. The
what-lives-where split above is *intent* derived from `docs/systems/shipyard/README.md` and
`docs/game/progression.md`, not an observation. Inspect Studio through MCP before treating any of it as
implemented, and correct this document when the real structure exists.
