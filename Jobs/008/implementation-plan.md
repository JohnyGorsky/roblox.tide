# Implementation Plan — Job #008

**Project**: `roblox.tide`
**Created**: 2026-08-20 09:42:44
**Status**: Planning (awaiting go-ahead)

## Analysis

Planning only - nothing implemented. Recorded as manifest group 13 plus feature GAME-0012 (area infra) so it appears on the generated board like any other work. The substance of this job is the two things that were implicit in the request and are load-bearing if left implicit. First, the user said 'for my username', but Roblox usernames are MUTABLE: a username allowlist breaks silently when the account is renamed, and if the old name is later claimed by someone else, admin access transfers to a stranger. UserId is permanent, so the allowlist keys on UserId with the username kept only as a readability comment. Second, an admin panel is the largest exploit surface a Roblox game can add, so the security model is written as the first job rather than assumed: the allowlist is server-only and never replicated; the button and panel are created client-side only AFTER the server confirms admin status, rather than shipped to everyone and hidden, because a hidden Frame is trivially unhidden and reading it teaches an exploiter every remote name; every remote handler re-checks the allowlist on EVERY call, not once at join; and the client never asserts its own admin status in any form. The acceptance criterion is written as an attack, not a review: a non-admin firing every admin remote with every plausible argument must achieve nothing, and it must be tested by actually firing them, because the code looks fine either way.

## Implementation steps

1. Write docs/build/13-admin-tools.md - the security rules first, then gate/shell, sea tools, time and weather, world and spawning, player and inventory, diagnostics
2. Create feature GAME-0012 with the security requirements as explicit checkboxes and an attack-shaped acceptance criterion
3. Note that the panel is needed in BOTH places, since lobby and game place have different things worth poking
4. Call out Copy-as-Luau as the highest-value item: without it, every good-looking value found by dragging a slider dies with the session
5. Regenerate the board

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
