---
id: GAME-0001
name: Boat Controller
area: boat
status: PLANNED
priority: P0
last_verified: null
---

# Boat Controller

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [ ] Rigid/stable multiplayer boat
- [ ] Throttle and steering
- [ ] Fuel consumption
- [ ] Wave response
- [ ] Driver authority strategy
- [ ] Set each player's `ReplicationFocus` to the vessel, not the character — the game place runs
      with `StreamingEnabled = true` (job 004), so crew far from spawn will watch the deck stream out
      without it
- [ ] Studio multiplayer verification

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.
