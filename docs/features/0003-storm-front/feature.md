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
- [x] Danger when caught — `VesselDamage` + `VesselServer`, job 022, decision 0023. Escalating hull
      damage inside The Wall, a four-rung fault ladder, flooding, capsize, and a damage-control station.
      **Measured, not judged:** `Storm -> Survival test`. Not yet run in a session — see the status note
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

**The teeth are now built** (job 022). The Wall inflicts escalating hull damage, fires a designed fault
ladder, floods her, can capsize her and can lose the vessel — and lightning's fault rolls, which had been
published and ignored since job 018, are finally consumed. Decision 0023 records the model.

It is still **not** VERIFIED, for a different reason than before: **none of it has ticked.** Studio Sync was
down for the whole of job 022 (finding 0007), so the damage model is analyzer-clean and its arithmetic is
checked against the storm's own constants, but no line of it has run. The one thing that would settle it is
`Storm -> Survival test`, which measures both halves of decision 0014's claim — that staying is fatal on a
known clock, and that leaving works if you leave now.

Second open item: the storm's forward pressure had **never actually worked**. `WorldTick.vesselZ()` looked for
an instance path that never existed, so `GAIN_PER_STUD` was never applied and distance could only decrease —
outrunning the front was not hard, it was impossible (finding 0020). Fixed in job 022, and it needs the same
session to confirm.

## Still open

- **Danger when caught.** The Wall looks unsurvivable and does nothing. Decision 0014 puts damage at
  escapable-in-30–60s; nothing implements it.
- **Rain and thunder audio.** Slots are addressable and empty on purpose — spec in
  `roblox.workspace/Assets/registry/audio.md`.
- Screen-level rain streaks.
