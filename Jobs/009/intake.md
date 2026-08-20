# Job #009: Build the admin gate, panel shell and sea tools

**Project**: `roblox.tide`
**Created**: 2026-08-20 09:58:42
**Status**: Requirements Gathering (intake)

## Requirements / goal

Implement group 13 jobs 1 and 2 in the game place. Security model first: a server-only allowlist keyed on UserId 5025640608, a single authorisation function used by every handler, and a trivial logging tool behind it to prove the authorisation path before any real power exists. Then the sea tools: state picker, blend, live water and fog sliders, and Copy-as-Luau so values found by eye survive the session. Decisions already settled in job 008 - ships in production, one permission level, per-tool scope enforced by the server, allowlist hard-coded server-side. Key architectural consequence of the shipped-in-production decision: tool DEFINITIONS stay server-side and are sent to the client only after it is confirmed admin, so a non-admin never learns the tool list. Only one RemoteFunction is exposed. Must be verified by actually attacking it: call the authorisation path as a non-admin id and confirm nothing happens.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
