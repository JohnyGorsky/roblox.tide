---
id: GAME-0001
name: Boat Controller
area: boat
status: READY
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

## Settled before implementation — job 021, decision 0022

| | |
|---|---|
| Hull | **40 × 14 studs, freeboard 3.** Dry at Light Swell, spray at Choppy, green water at Storm, swamped in The Wall |
| Buoyancy | **Four points** (bow/stern/port/starboard) on `WaveField.HeightAt`. Hull density **> 1** so terrain water lifts nothing |
| Authority | **Server-owned, always.** Plain `Seat` + our own input remote — **no `VehicleSeat`** |
| Wave response | Visible pitch and roll, **always recovers**. Weak `AlignOrientation` righting moment |
| Cruise speed | Chosen by feel, then `GAIN_PER_STUD` solved for it. Break-even is **8.75 studs/s** |

**Why no `VehicleSeat`:** it hands network ownership to the driver on sit, and a server force loop reading a
client-owned body pumps energy instead of removing it — the Jungle boat bounced higher and higher *while
driven* and was stable at rest. Server ownership also matters because `StormFront` reads the vessel's Z on the
server to buy distance from northward progress, so a client-owned hull would feed the game's central mechanic
a lagged position.

**The debt this creates:** mobile touch controls for throttle and steer, which `VehicleSeat` would have
supplied. The bottom-left quadrant belongs to Roblox's thumbstick, so they go elsewhere.
