# 13 — Admin panel & dev tools

**Group:** an admin button visible only to authorised developers, opening a panel that can drive the
game's systems directly — sea state, time, storm, spawning, item granting.
**Items:** ~34
**Depends on:** nothing to start. Each tool section depends on the system it drives, so the panel grows
alongside the game.
**Feeds:** every other group — this is the tool that makes them testable by hand.

Feature: [GAME-0012](../features/0012-admin-panel/feature.md) · needed in **both places**

---

## 🔴 Read this before writing a line of it

**An admin panel is the largest exploit surface a Roblox game can add.** Get it wrong and every player
gets god powers. Two rules, neither optional:

### 1. Gate on `UserId`, never on username

Roblox usernames are **mutable**. A username allowlist breaks the moment the developer renames — and if
the old name is later claimed by someone else, access transfers to a stranger. `UserId` is permanent.

```lua
-- WRONG - usernames change
local ADMINS = { ["johnygorsky10"] = true }

-- RIGHT - UserId is stable; keep the name only as a comment for readability
local ADMINS = {
    [123456789] = "johnygorsky10",  -- owner
}
```

### 2. The server decides everything

The client may *ask*; only the server may *act*. This means:

- The panel UI is built **only after** the server confirms the player is an admin. Do not ship the UI to
  everyone and hide it — a hidden `Frame` is trivially unhidden, and an exploiter reading it learns every
  remote name.
- **Every remote handler re-checks the allowlist**, on every call. Not once at join; every call. A client
  that was never an admin can still fire the remote.
- Never send "I am an admin" from the client, in any form. No boolean, no token, no flag.
- Log admin actions server-side. When something inexplicable happens in a live server, you want to know
  whether it was a person.

A useful test: *if a player fired every admin remote with every plausible argument, what could they do?*
The answer must be "nothing."

---

## A. The gate & shell — 9 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Admin allowlist | `UserId → label` table, server-only module. Not in `ReplicatedStorage` | ❌ | code |
| Server admin check | One function, one source of truth, used by every handler | ❌ | code |
| Admin button | Small, unobtrusive, created client-side **only** on server confirmation | ⚠️ | code |
| Panel shell | Draggable/resizable window, tabbed by tool section | ⚠️ | code |
| Remote surface | One `RemoteFunction` with an action name, or one remote per tool — pick and document | ❌ | code |
| Per-call authorisation | The re-check on every handler. The load-bearing piece | ❌ | code |
| Action audit log | Who did what, when, in which place | ❌ | code |
| Keyboard shortcut | Open/close without hunting for the button | ❌ | code |
| Mobile layout | Landscape, thumb-reachable, avoiding the reserved touch rects | ⚠️ | code |

## B. Sea tools — 5 items

The first section to build, since [group 01](01-sea.md) already has a state table to drive.

| Item | What it is | GB | Source |
|---|---|---|---|
| Sea state picker | Buttons for Dead Calm → The Wall, applying instantly | ❌ | code |
| State blend slider | Scrub between two states to find intermediate looks | ❌ | code |
| Live water sliders | `WaveSize`, `WaveSpeed`, `Reflectance`, `Transparency`, fog start/end | ❌ | code |
| Copy-as-Luau | Export the current values as a `SeaStates` entry, so tuning by eye becomes code | ❌ | code |
| Wave field overlay | Toggle the debug markers that show the maths against the visual water | ❌ | code |

**Copy-as-Luau is the highest-value item in this group.** Without it, every good-looking setting found by
dragging a slider is lost the moment the session ends.

## C. Time & weather — 4 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Phase jump | Dawn / Day / Dusk / Night instantly | ❌ | code |
| Clock scrub | `ClockTime` slider, plus pause the cycle | ❌ | code |
| Storm level | Force intensity 0–4, and force the distance | ❌ | code |
| Trigger lightning | Fire a strike on demand, including the rare system-fault variants | ❌ | code |

## D. World & spawning — 7 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Teleport to POI | Jump to any spawned island or POI | ❌ | code |
| Spawn POI | Force a specific island template or sea POI to appear | ❌ | code |
| Spawn vessel | Any vessel class, at any upgrade configuration | ❌ | code |
| Spawn enemy / group | Any enemy or group definition, at a chosen position | ❌ | code |
| Kill all enemies | The panic button during a test | ❌ | code |
| Advance sea stage | Force the forward progression beat | ❌ | code |
| Free camera | Detach and fly, to inspect from outside | ❌ | code |

## E. Player & inventory — 5 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Grant items | Any item, resource, part or rare component | ❌ | code |
| Grant weapon | Any weapon with ammunition | ❌ | code |
| Heal / damage / down / revive | Exercise the whole health and revive path | ❌ | code |
| Toggle invulnerability | Observe a fight without dying in it | ❌ | code |
| Speed & noclip | Cross 6 km of ocean without sailing it | ❌ | code |

## F. Diagnostics — 4 items

Surface the audits we already have, plus live numbers.

| Item | What it is | GB | Source |
|---|---|---|---|
| Perf readout | FPS, ping, physics step, instance count, memory | ⚠️ | code |
| Run the settings audit | `tools/audit-place-settings.luau` from in-game | ❌ | code |
| Run the graybox audit | `tools/audit-graybox.luau` from in-game | ❌ | code |
| System state dump | Fuel, hull, generator load, storm distance, sea state — one screen | ⚠️ | code |

---

## Suggested job split

1. **Gate & shell** — A. Build the security model first, with one trivial tool behind it (a button that
   prints to the server log) to prove the authorisation path before any real power exists.
2. **Sea tools** — B, including Copy-as-Luau. Immediately useful: it is how the sea look gets finished.
3. **Time & weather** — C, once [group 07](07-atmosphere.md) has a cycle and a storm.
4. **World & spawning** — D, as the things to spawn come into existence.
5. **Player & inventory** — E, alongside [group 03](03-items-props.md) and [group 06](06-weapons.md).
6. **Diagnostics** — F. Cheap, and it makes the existing audit scripts reachable without MCP.

Sections C–E should grow as their systems land, rather than being built ahead of them.

## Open questions

- **Does this ship in the live game?** A panel present in production is a permanent risk but invaluable for
  live debugging. The alternative is stripping it at publish, which means it is never tested in the
  environment that matters. Leaning: ship it, gate it hard, log everything.
- **More than one permission level?** Owner vs tester vs streamer-safe (cosmetic tools only)?
- **Should tool changes replicate to everyone or only the admin?** Sea state must be global to be judged;
  noclip must be local. Each tool needs to declare which it is.
- **Where does the allowlist live?** Hard-coded is simplest and safest; a DataStore-driven list allows
  granting access without a publish, at the cost of another attack surface.
