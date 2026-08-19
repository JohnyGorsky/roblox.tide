# 0013 — Lobby place and game place

Status: Accepted

## Decision

The experience is split into **two Roblox places**:

| Role | Place | Id |
|---|---|---|
| Lobby (start place) | The Last Tide Lobby | `91870148721134` |
| Game | The Last Tide Game | `100885379547959` |

Players arrive in the **lobby**. Between-run activity lives there: the Shipyard, the permanent fleet,
parts/component inventory, loadout, crew roster and party forming. An expedition runs in the **game**
place, which players teleport into as a crew and return from when the run ends.

## Why

The two halves of the game want opposite things from a server.

- Permanent fleet progression (decision 0012) is a calm, persistent, browse-and-spend activity. It
  needs no ocean, no storm and no combat simulation.
- An expedition is a bounded, seeded, 1–6 player physics-heavy run with a wrapping ocean (decision
  0002) and a chasing storm (decision 0007). It benefits from a fresh server per run.

Keeping them in one place would mean loading the whole ocean world for a player who only wants to spend
Engine Parts, and would make "the run ended" a state reset rather than a clean server boundary.

A separate lobby also gives party forming a natural home and lets an expedition run on a reserved
server without strangers joining mid-run.

## Consequences

- Permanent progression must persist **across places** — it is account data (decision 0011), so it is
  read and written through DataStores, never handed between places in memory.
- Run state belongs to the game place and is not expected to survive the return trip (decision 0008).
- Scripts, assets and GUIs belong to exactly one place. Never edit across the boundary without
  confirming which place owns the file.

See `docs/systems/places/README.md` for how it works.
