---
id: GAME-0012
name: Admin Panel & Dev Tools
area: infra
status: IN_PROGRESS
priority: P1
depends_on: []
assets: []
last_verified: null
---

# Admin Panel & Dev Tools

## Goal

An admin button, visible only to authorised developers, opening a panel that drives the game's systems
directly — starting with sea state, growing to time, storm, spawning and item granting.

## Player value

None directly, and that is the point: this is a tool for the people building the game. Its value is
indirect and large — it turns "restart Studio and wait for night" into a button, which is the difference
between tuning something ten times and tuning it once.

## Requirements

- [x] Allowlist keyed on **`UserId`**, not username — usernames are mutable and would silently break
      or transfer access
- [x] Allowlist is **server-only**; never replicated to clients
- [x] The button and panel are created client-side **only after the server confirms** the player is an
      admin — not shipped-to-everyone-and-hidden
- [x] **Every remote handler re-checks the allowlist on every call**, not once at join
- [x] The client never asserts its own admin status in any form
- [x] Admin actions are logged server-side with who, what, when and which place
- [x] Works in **both places** (lobby and game) — one place-aware file, byte-identical copies
- [ ] Usable on mobile: landscape, thumb-reachable, clear of the reserved touch rects
- [x] Sea tools first: state picker, blend slider, live water sliders, wave overlay
- [x] **Copy-as-Luau** — export current values as a `SeaStates` entry so tuning survives the session
- [x] Ships in the **published** game (decided) — so the audit log is a hard requirement, and the attack
      test must be run against a published server, not only Studio
- [x] **One permission level** (owner only). No tester/streamer tiers until there is someone to add
- [x] Every tool definition declares `scope = "global" | "local"`, and **the server enforces it** — the
      client never chooses. No default: a new tool without a declared scope is a bug
- [x] Allowlist is a **hard-coded table in a server-only module** — not `ReplicatedStorage`, not a
      DataStore. Changing it requires a publish, and shows up in `git diff`
- [x] Owner's **UserId** obtained: `5025640608` (`johnygorsky10`), verified by reverse name lookup

## Decided

Four questions were settled on 2026-08-20 — see [the manifest group](../../build/13-admin-tools.md)
for the reasoning and the per-tool scope table.

## Out of scope

The systems the panel drives; each tool section follows its own group. This feature owns the gate, the
shell, and the sea tools.

## Roblox touchpoints

`Players`, `RemoteFunction`/`RemoteEvent`, `ScreenGui`, `ReplicatedStorage.SeaStates`, `Lighting`,
`Terrain`.

## Assets

None. Icons may come from the group 09 icon set.

## Acceptance criteria

- [ ] A non-admin player sees no button, and cannot find the panel in their client
- [ ] A non-admin firing every admin remote with every plausible argument achieves **nothing**
- [ ] An admin can switch sea state and see it apply immediately
- [ ] Copy-as-Luau output pastes into `SeaStates.luau` and works unedited
- [ ] Every admin action appears in the server log

## Verification

Never mark VERIFIED without a real Studio/playtest check.

**Verified in Edit (job 009, 2026-08-20):**
- All four files sync with the right classes: two ModuleScripts in `ServerStorage`, a `Script`/Server in
  `ServerScriptService`, a `LocalScript` in `StarterPlayerScripts`
- Tool registry validates; 7 tools in the game place, 3 in the lobby (sea tools correctly absent)
- **Attack test on the gate passed:** `isAdmin()` returns false for nil, the raw UserId number, the
  username string, `{UserId = 5025640608}`, `{Name = ..., UserId = ...}`, a Part, the Workspace, a
  boolean and a function. Nothing but a real allowlisted `Player` passes
- Tool handlers work: bogus state id refused, `fogEnd 9999` clamped to 3071 with the reason given,
  blend applied, Copy-as-Luau produced paste-ready output

**Still outstanding — needs a Play session:**
- Panel builds exactly **once** (it built twice before the `.client.luau` → `.local.luau` fix; the fix is
  confirmed at the instance level but not yet observed at runtime)
- End-to-end refusal for a non-admin: temporarily point the allowlist at a different UserId, Play, and
  confirm no button appears and every tool is refused The security criteria must be tested by
*actually firing the remotes from a non-admin client*, not by reading the code — the whole point is that
the code looks fine either way.
