---
id: GAME-0001
name: Boat Controller
area: boat
status: IMPLEMENTED
priority: P0
last_verified: 2026-08-21
---

# Boat Controller

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [x] Rigid/stable multiplayer boat — one rigid assembly, server-owned throughout, ownership verified `nil`
- [x] Throttle and steering — force-based; rudder torque against yaw damping, not a commanded rate
- [x] Fuel consumption — server-authoritative, burns at idle, 182 s at full ahead
- [x] Wave response — four-point buoyancy on the wave field; boat/sea bob ratio steady 0.38-0.46, no energy gain
- [x] Driver authority strategy — decision 0022: server-owned, plain station + input remote, no `VehicleSeat`
- [ ] Set each player's `ReplicationFocus` to the vessel, not the character — the game place runs
      with `StreamingEnabled = true` (job 004), so crew far from spawn will watch the deck stream out
      without it
- [ ] Studio multiplayer verification — **still open**: driven and measured single-player only

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

## MVP signed off — 2026-08-21

Not `VERIFIED`, deliberately: everything below was driven and measured, but **never with two players**, and
the mobile touch controls have never run on a touch canvas. Both are in the acceptance list above for a reason.

What the hull does, measured in the engine rather than simulated:

| | |
|---|---|
| Holds course, wheel amidships | 0° drift, yaw peak 0.000 |
| Turn rate vs designed | 91% calm · 91% swell · 94% choppy · 80% storm |
| Turn radius | 60 studs at cruise, 542 at 1 stud/s — she needs way on |
| Heel | into the turn first, crossing to out; bigger lurch on centring the wheel |
| Trim | bow up opening up, bow down on chopping the throttle |
| Bob vs the sea | ratio 0.38–0.46, flat across all five states |

The largest lesson is [finding 0019](../../findings/0019-a-large-torque-applied-in-a-body-relativ.md): a large
torque in a body-relative frame leaks into every axis the body rotates about. It spun the hull 178° in 8
seconds with the wheel amidships, and produced measurements that contradicted each other between runs.
