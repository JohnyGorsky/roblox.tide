---
id: GAME-0002
name: Radar Mk1
area: navigation
status: PLANNED
priority: P0
last_verified: null
---

# Radar Mk1

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [ ] Physical radar station
- [ ] Nearby generic POI contacts
- [ ] Range limit
- [ ] Storm contact
- [ ] No permanent minimap
- [ ] Studio verification

## The design, as specified 2026-08-21

From a concept mockup plus two corrections the user made about it. Recorded now because the mockup is
**direction, not spec** — several things on it do not exist in the code and must not be built from the picture
alone.

### 🔴 It lives ON THE BOAT, not on the screen

*"I think it must be on boat, not on screen, so someone must watch rada constantly."*

That is the whole feature. A physical station means someone has to **stand there and look at it** — which is
what makes radar a crew ROLE rather than a HUD element, and it is why the mockup's right-hand "LIVE
CONDITIONS" panel cannot be built as drawn: it is screen UI, and the instruction is no screen. Those readouts
belong on the console beside the scope.

It also lands exactly where decision [0004](../../decisions/0004-radar-no-permanent-minimap.md) already
pointed (no permanent minimap) and decision [0019](../../decisions/0019-storm-advance-model.md) (the radar
owns the storm's number, and it dies inside The Wall).

The vessel spec already has the socket: `radar = { kind = "radar", offset = Vector3.new(0, 6, 6) }`.

### 🔴 The storm comes from ONE SIDE

*"of course storm comes from one side"*

The mockup draws the storm as a cell that could be anywhere on the scope. It cannot be. The front chases from
**astern** and progress is northward — `Lightning.ASTERN_BEARING` is 180, and the storm doc's whole
"a compass is enough to escape" argument rests on the escape direction being constant.

So on the scope the storm is an **arc across the astern edge that closes inward**, not a drifting blob. Drawn
as a wandering cell it would imply the crew could steer around it, which is the opposite of the mechanic.

### The scope itself

| Element | Source |
|---|---|
| Range rings, boat at centre, sweeping beam | cosmetic, ours to draw |
| Storm arc on the astern edge, closing | `StormDistance` — **real today** |
| Island contacts, green, labelled with distance | group 04 — **nothing to show yet** |
| Unknown contacts, orange, unlabelled (`??? • 2.4 km`) | needs a contact registry — **new** |
| Range 6.0 km on the mockup | ours to set. Note the corridor is 5,500 studs long, so 6 km of range would see past the world |

### What the mockup shows that does NOT exist

Worth listing so nobody builds a readout with nothing behind it:

- **Nearest shelter** — no shelters or POIs exist (group 04). Decision 0019's shelter *rate* exists; a shelter
  to moor at does not.
- **Island contacts** — group 04.
- **Visibility %** — derivable from the sea state's `fogEnd`, but currently nothing publishes it.
- **Arrival estimate** — computable today: `StormDistance / ADVANCE_RATE`, and it is the honest version of the
  mockup's `02:35`.
- **Storm strength** — real: the band label (Calm / Incoming / Storm / Severe / The Wall).

### Two things that make it bite

- **It dies inside The Wall** (decision 0019). The crew watches the front approach right up to the moment they
  most need the number, then goes blind and steers by the compass alone.
- **Job 022's radar fault becomes real.** That fault currently sets `VesselFault_radar` and nothing consumes
  it — it was shipped as an honest stub. This is the feature that gives it teeth, and lightning already rolls
  it on close strikes.

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.
