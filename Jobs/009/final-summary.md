# Final Summary — Job #009

**Project**: `roblox.tide`
**Completed**: 2026-08-20 10:16:44
**Status**: ✅ Completed

## What was implemented

Built the gate, the panel and the sea tools, in both places. Four files, duplicated byte-identically because Roblox has no cross-place ReplicatedStorage: the tool registry is place-aware instead, registering sea tools only where SeaStates exists, so the copies never diverge into a game variant and a lobby variant - 7 tools in the game place, 3 in the lobby. THE GATE: allowlist keyed on UserId 5025640608 in ServerStorage, never ReplicatedStorage; one isAdmin function with no caching and no second path; authorisation happens before the action is even inspected, so a non-admin cannot learn whether an action name exists; the tool manifest is only reachable past that check, so the tool list cannot be enumerated; a rate limit of 20 calls/sec; and an audit log that records rejections as warnings, since in production the rejections are the interesting ones. THE ATTACK TEST PASSED: isAdmin returns false for nil, the raw UserId as a number, the username string, a table spoof {UserId=5025640608}, a table with both Name and UserId, a Part, the Workspace, a boolean and a function - nothing but a real allowlisted Player passes. Tool handlers verified too: a bogus sea state is refused, fogEnd 9999 clamps to 3071 with the reason given rather than silently creating the visible-ocean-edge artifact from job 007, and Copy-as-Luau emits paste-ready output including the Atmosphere values as comments. TWO ENGINE FINDINGS, both from things going wrong. (1) A .client.luau in StarterPlayerScripts becomes a Script with RunContext=Client, which Roblox runs TWICE - once in place and once as the PlayerScripts copy - and it built two panels. Probed the alternatives: .local.luau gives a LocalScript (correct), .legacy.luau gives a Script/Legacy, and .localscript.luau is not recognised at all. Renamed the client script and documented the rule that StarterPlayerScripts wants .local.luau. (2) A failed or stale require is cached for the whole Edit session: after fixing a syntax error the module kept reporting the old failure, and worse, the game place kept serving the PRE-EDIT module and reported success while the lobby's first load surfaced the real bug. Cloning the ModuleScript and requiring the clone bypasses the cache; both findings are now in the places doc and the skill. The syntax error itself is worth noting: a Lua newline escape was collapsed into a literal newline by the heredoc, leaving an unterminated string - written now as chr(92) to survive the layers. NOT DONE: the Play test. Studio's start-play wedged - the MCP reports 'start play hasn't finished yet' while Studio still reports Edit mode, across several attempts and 40 seconds of waiting - so the two runtime checks remain open: that the panel now builds exactly once, and that a non-admin is refused end to end.

### Files changed

_All eight script files sync into their places automatically._

- `studio_game/ServerStorage/AdminAllowlist.luau`
- `studio_game/ServerStorage/AdminTools.luau`
- `studio_game/ServerScriptService/AdminServer.server.luau`
- `studio_game/StarterPlayerScripts/AdminClient.local.luau`
- `studio_lobby/ServerStorage/AdminAllowlist.luau`
- `studio_lobby/ServerStorage/AdminTools.luau`
- `studio_lobby/ServerScriptService/AdminServer.server.luau`
- `studio_lobby/StarterPlayerScripts/AdminClient.local.luau`
- `docs/features/0012-admin-panel/feature.md`
- `docs/systems/places/README.md`
- `.claude/skills/tide-project/SKILL.md`

### ⚠️ Blocked: the Play test

Studio's start-play is wedged — the MCP reports *"start play hasn't finished yet"* while Studio still
reports Edit mode, across several attempts and ~40s of waiting. Check for a modal dialog in Studio, or
restart it. Two runtime checks are still open:

1. **The panel builds exactly once.** It built twice before the `.client.luau` → `.local.luau` fix. The
   fix is confirmed at the instance level (it is now a `LocalScript`) but not yet observed at runtime.
2. **A non-admin is refused end to end.** Point the allowlist at a different UserId, Play, and confirm no
   button appears and every tool is refused.

### Using it

Press **F4** or tap the **ADM** button (bottom-right, clear of the thumbstick quadrant).

## Verification

- [ ] _TODO: confirmed working_
