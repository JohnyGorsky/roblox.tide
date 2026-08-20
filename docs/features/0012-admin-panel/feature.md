---
id: GAME-0012
name: Admin Panel & Dev Tools
area: infra
status: PLANNED
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

- [ ] Allowlist keyed on **`UserId`**, not username — usernames are mutable and would silently break
      or transfer access
- [ ] Allowlist is **server-only**; never replicated to clients
- [ ] The button and panel are created client-side **only after the server confirms** the player is an
      admin — not shipped-to-everyone-and-hidden
- [ ] **Every remote handler re-checks the allowlist on every call**, not once at join
- [ ] The client never asserts its own admin status in any form
- [ ] Admin actions are logged server-side with who, what, when and which place
- [ ] Works in **both places** (lobby and game)
- [ ] Usable on mobile: landscape, thumb-reachable, clear of the reserved touch rects
- [ ] Sea tools first: state picker, blend slider, live water sliders, wave overlay
- [ ] **Copy-as-Luau** — export current values as a `SeaStates` entry so tuning survives the session

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

Never mark VERIFIED without a real Studio/playtest check. The security criteria must be tested by
*actually firing the remotes from a non-admin client*, not by reading the code — the whole point is that
the code looks fine either way.
