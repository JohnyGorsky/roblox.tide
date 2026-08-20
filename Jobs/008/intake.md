# Job #008: Add admin panel to the build plan

**Project**: `roblox.tide`
**Created**: 2026-08-20 09:40:39
**Status**: Requirements Gathering (intake)

## Requirements / goal

New planned item, not an implementation. An admin button visible only to authorised developers, opening a panel of dev tools - starting with sea state switching, and extending to time of day, storm level, spawning, item granting and the existing audit scripts. Add it as one manifest group (13) plus one feature (GAME-0012) so it is tracked like everything else. Two design points to record rather than leave implicit: the allowlist must key on UserId and not username, because Roblox usernames are mutable and a renamed account would silently lose or transfer access; and every action must be validated server-side against that allowlist, because an admin panel is the single largest exploit surface a Roblox game can add - a client-trusted one hands every player god powers. The panel is needed in BOTH places, since the lobby and the game place have different things worth poking.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
