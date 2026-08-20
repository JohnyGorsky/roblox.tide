# Final Summary — Job #008

**Project**: `roblox.tide`
**Completed**: 2026-08-20 09:42:44
**Status**: ✅ Completed

## What was implemented

Added as one planned item: manifest group 13 (~34 items) plus feature GAME-0012, area infra, on the board as PLANNED/P1. Sections are the gate and shell (9), sea tools (5), time and weather (4), world and spawning (7), player and inventory (5) and diagnostics (4), with sections C-E explicitly meant to grow as their systems land rather than being built ahead of them. TWO CORRECTIONS TO THE REQUEST, both recorded rather than silently applied. (1) Gate on UserId, not username: Roblox usernames are mutable, so a username allowlist breaks on rename and can transfer access to whoever later claims the old name. The spec shows the wrong and right forms side by side. (2) The security model is job 1, not an afterthought: allowlist server-only and never replicated, UI created only after server confirmation rather than shipped-and-hidden (a hidden Frame is trivially unhidden and reading it hands an exploiter every remote name), every handler re-checking on every call rather than once at join, the client never asserting its own status, and server-side logging of who did what where. The acceptance criterion is written as an attack - a non-admin firing every remote with every plausible argument must achieve nothing - and must be verified by actually firing them, since code that trusts the client looks fine on inspection. Also flagged Copy-as-Luau as the highest-value item in the group: it exports the current live values as a SeaStates entry, which is the difference between tuning the sea by eye once and losing every good setting when the session ends. Four open questions left for the user rather than answered: whether the panel ships in production (leaning yes, gated hard and logged), whether there are multiple permission levels, whether each tool replicates globally or locally (sea state must be global to judge, noclip must be local), and whether the allowlist is hard-coded or DataStore-driven.

### Files changed

_Documentation only — nothing implemented._

- `docs/build/13-admin-tools.md`
- `docs/features/0012-admin-panel/feature.md`

### Needed from you before this can be built

**Your Roblox UserId.** Not your username — the numeric id. Find it in the URL of your own profile
(`roblox.com/users/<UserId>/profile`), or I can read it over MCP next time you are in a Play session.

## Verification

- [x] Group 13 and GAME-0012 appear on the generated board (area `infra`, PLANNED, P1)
- [x] Every relative link in the repo resolves
- [ ] Nothing implemented — **planning only, by design**

## Follow-up: the four open questions were answered (2026-08-20)

Asked interactively and settled the same day, so the group is no longer blocked on design:

- **Ships in production**, gated hard and fully logged. This promotes the audit log from nicety to hard
  requirement, and means the attack test must be run against a *published* server rather than only Studio.
- **One permission level** — owner only. No tester or streamer tiers until there is someone to add.
- **Scope declared per tool**, enforced by the server, with no default. A per-tool scope table is now in
  the manifest group; world tools are global (a sea state nobody else sees cannot be judged), player tools
  are local.
- **Allowlist hard-coded in a server-only module** — not `ReplicatedStorage`, not a DataStore. Changing who
  has god powers should require repo access and a publish, and should be visible in `git diff`.

One consequence worth carrying into every future admin job: **adding a tool means adding its authorisation
check**. Because the panel ships live, a new tool with a missing re-check is a production vulnerability
rather than a bug.

Still needed: the owner's numeric **UserId**.
