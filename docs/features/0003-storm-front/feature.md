---
id: GAME-0003
name: Advancing Storm Front
area: atmosphere
status: IMPLEMENTED
priority: P0
last_verified: 2026-08-20
---

# Advancing Storm Front

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [x] Logical storm position — `StormFront`, five uneven bands, job 017
- [x] Visible storm wall — `CloudWallVFX` astern + the built-in `Clouds` layer, job 018. **Approved by eye
      2026-08-20** after four attempts; see the job summary for why the first three failed
- [x] Rain/wind/lightning layers — `StormVFX`, `Lightning`/`LightningVFX`, `StormAudio` (wind live; rain
      and thunder clips still unsourced), job 018
- [ ] Danger when caught — no damage model yet; The Wall currently only *looks* unsurvivable
- [x] Server authoritative storm progression — `WorldTick` at 1 Hz, fixed order, job 017
- [x] Client-only expensive visuals — every emitter is camera-local; the server publishes numbers only

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.

## What everyday weather is allowed to do (decision 0020)

The storm's legibility rests on a restriction, so it belongs in this feature and not only in the decision:

| | |
|---|---|
| Everyday weather may move | wind, wave height, rain, fog distance |
| Everyday weather may NOT move | sky, brightness, ambient, atmosphere density/haze, severity |

The bottom row is the storm's alone. Making rain ordinary is what lets darkness mean something — and it
promotes the cloud wall from decoration to **the diagnostic**, because it is the one tell weather cannot
counterfeit.

Two safety properties, both verified numerically in job 018 and both worth re-checking after any change here:

1. Pinning weather Glassy → Rough leaves brightness, haze, atmosphere density, ambient and the sky
   **byte-identical**.
2. At storm intensity 4 every weather modifier reads exactly `1.0`, so a calm spell can never **mask** an
   approaching front. This is the dangerous one.

## Status note — why IMPLEMENTED and not VERIFIED

Approved by eye for the POC on 2026-08-20: the approach reads, the wall grows and engulfs, lightning lights
the sea at range, and the audio bed does not loop audibly. Everything sensory is done.

It is **not** VERIFIED because one requirement is genuinely unbuilt: **the storm cannot hurt you.** The Wall
looks unsurvivable and does nothing at all. Decision 0014 puts damage at escapable-in-30-60s. Until that
exists the storm is a spectacle rather than a threat, and the macro loop decision 0007 describes does not
close.

## Still open

- **Danger when caught.** The Wall looks unsurvivable and does nothing. Decision 0014 puts damage at
  escapable-in-30–60s; nothing implements it.
- **Rain and thunder audio.** Slots are addressable and empty on purpose — spec in
  `roblox.workspace/Assets/registry/audio.md`.
- Screen-level rain streaks.
