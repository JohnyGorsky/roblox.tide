# Implementation Plan — Job #009

**Project**: `roblox.tide`
**Created**: 2026-08-20 09:58:42
**Status**: Planning (awaiting go-ahead)

## Analysis

Both places are open over MCP and the flat sync layout plus suffix-to-class rules are known, so the files can be written on disk and land in Studio directly: ServerStorage for the allowlist and tool registry (server-only, never ReplicatedStorage), ServerScriptService for the gate, StarterPlayerScripts for the client. Design decisions taken while implementing, each following from job 008. (1) Tool definitions live SERVER-side, not in ReplicatedStorage: the client asks for the tool list and receives it only after passing the admin check, so a non-admin cannot enumerate the tools. This is the same reasoning as not shipping the UI to everyone and hiding it. (2) Exactly one RemoteFunction is exposed, named plainly rather than obscurely, because obscurity is not security and a misleading name only costs maintainers. (3) Every handler calls one shared isAdmin(player) function - there is no second code path that could drift. (4) Each tool declares scope global or local and the server enforces it. (5) The audit log records userId, action, arguments and place for every accepted call, and also every REJECTED call, since rejections are the interesting ones in production. Testing plan: verify the module syncs, then Play and confirm the panel appears for the owner, then attack it - invoke the authorisation function with a non-admin UserId from a Server-context script and confirm every tool refuses.

## Implementation steps

1. Write ServerStorage/AdminAllowlist.luau - UserId keyed, server-only
2. Write ServerStorage/AdminTools.luau - the tool registry with per-tool scope and handlers
3. Write ServerScriptService/AdminServer.server.luau - the gate, the single remote, per-call re-check, audit log
4. Write StarterPlayerScripts/AdminClient.client.luau - button and panel built only after server confirmation
5. Verify all four files sync into the game place
6. Play test: confirm the panel appears for the owner and a sea state applies
7. ATTACK test: call the authorisation path with a non-admin id and confirm every tool refuses
8. Copy the gate and shell to the lobby place, without the sea tools

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
