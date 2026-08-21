---
id: GAME-0002
name: Radar Mk1
area: navigation
status: IMPLEMENTED
priority: P0
last_verified: 2026-08-21
---

# Radar Mk1

## Goal

Implement the smallest production-worthy version of this system while preserving the accepted game decisions.

## Requirements

- [x] Physical radar station — a vertical screen on its own `radarConsole` socket, away from the helm, plus a
      turning aerial on the `radar` socket. Job 026
- [x] Nearby generic POI contacts — discovered by the `RadarContact` tag. Six real contacts today (start
      island, four barrels, the tender); group 04's islands only have to tag themselves
- [x] Range limit — 1,800 studs from one constant, with an **uncertain band** at 1,080–1,800 that draws
      hollow amber circles instead of fixes
- [x] Storm contact — astern-relative, appearing once the front closes to 1,800 and swelling as it nears
- [x] No permanent minimap — nothing is on screen; the scope is a `SurfaceGui` on a part
- [x] Studio verification — sweep gating, head-up transform, both dead states and the maths all measured
- [ ] Skills change the range — the hook exists (`Radar.RANGE`); progression does not (decisions 0008, 0012)

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

### Three more, added 2026-08-21

**It pings, like the real thing.** Two meanings and both are wanted:

- *the behaviour* — a real PPI only refreshes a contact when the beam sweeps over it, and the blip then decays
  until the next pass. That is buildable today, costs nothing, and it is what makes the instruction "someone
  must watch rada constantly" mechanically true rather than just thematic: look away and your picture is
  already stale.
- *the sound* — a sweep tick and a contact ping. **Needs an asset**; nothing in either registry has one.
  Positional, mounted at the station, so it is audible at the radar and not across the deck.

**Range grows with skills.** So range is **one value read from one place**, not a constant sprinkled through
the drawing code. Then progression changes a number and nothing else has to move. The upgrade path itself is
decisions [0008](../../decisions/0008-progression-model.md) (role mastery) and
[0012](../../decisions/0012-parts-progression.md) (parts as the primary fleet progression) — neither exists
yet, so Mk1 ships with the hook and a fixed value.

**Uncertain contacts at the edge.** *"probably rada will show at the edge small circles where something
potentially is."*

That is the best idea in the pile, because it makes the instrument honest about its own limits:

    inside the confident radius   a shaped blip, with a distance
    out near the edge             a small hollow circle, no label - something is THERE
    beyond range                  nothing

Confidence falls with distance, so the same contact resolves as you close on it. It also gives the crew a
reason to steer *towards* an unknown rather than only away from the storm, which is the exploration loop in
one gesture.

### The legend is part of the instrument

*"radar must have explanations with colors."*

The scope is unreadable without a key, and the key has to be **on the console** for the same reason the scope
is — no screen UI. That is authentic rather than a compromise: real radar consoles carry their legend
silkscreened around the display.

From the mockup, and this fixes the palette:

| Colour | Means |
|---|---|
| 🟢 green | island / landmass |
| 🔴 red, with a hotter core | the storm |
| 🟠 amber | unknown contact — the edge circles |
| 🔵 blue | range rings |
| teal / pale | your own boat |

Two consequences worth writing down:

- **The colours must survive The Wall's darkness.** The scope is self-lit like the compass
  (`LightInfluence = 0`), or the one instrument you need at brightness 0.30 is the one you cannot read. Same
  rule, same reason.
- ⚠️ **This effectively sets the radar's palette before the game has a style guide** (todo 0001, the
  `tide-style` skill). Amber and green here are the mockup's, not a system's, so they are a second thing to
  reconcile when that guide lands. Noting it now so it is a known debt rather than a surprise.

## 🔴 What is ready to implement TODAY

Asked directly, so here is the honest split. The answer is: **nearly all of it**, because the storm is real
and — unexpectedly — there are already three things worth plotting.

| Ready now | Where the data comes from |
|---|---|
| The physical station | the vessel spec already has `radar = { kind = "radar", offset = (0, 6, 6) }` |
| Scope: rings, own-ship marker, sweeping beam | ours to draw |
| Sweep-refresh and decay | ours to draw |
| **The storm arc on the astern edge, closing live** | `StormDistance`, ticking |
| Storm strength | the band label — Calm / Incoming / Storm / Severe / The Wall |
| Arrival estimate | `StormDistance / ADVANCE_RATE` — the honest version of the mockup's `02:35` |
| Visibility % | derived from the live sea state's `fogEnd` against the calmest |
| **It dies inside The Wall** | `StormIntensity == 4` (decision 0019) |
| **The radar fault kills it** | `VesselFault_radar` — job 022 shipped this as an honest stub, and lightning already rolls it on close strikes. This is the feature that gives it teeth |
| Contact registry + the edge circles | the mechanism is ours, and see below |
| Range as one upgradeable value | ours |

**There are already three real contacts to plot**, which means the contact system ships *verified* rather than
stubbed:

- the **start island** (job 024) — a fixed landmass
- the **four fuel barrels** at 200–400 studs (job 023) — small, unlabelled, and at exactly the range where the
  edge-circle treatment applies. They are the demo
- the **tender**, when it is away from the launch

### Not ready, and what each waits on

| Not yet | Waits on |
|---|---|
| Islands beyond the start island, sea POIs, rare POIs | group [04](../../build/04-islands.md) |
| **Nearest shelter** | no shelter exists to moor at — decision 0019 has the shelter *rate*, not the place |
| Named contacts (`PALM ROCK`) | island identity, group 04 |
| Skills actually changing the range | progression, decisions 0008 / 0012. The hook ships; the upgrade does not |
| The audible ping | one sourced sound — see the asset note |

⚠️ **The mockup's range of 6.0 km will not fit.** The corridor is 5,500 studs long
(`SeaStates.OCEAN_EXTENT_Z`), so a 6 km scope would see past the end of the world. Mk1's range has to be well
inside that, which is fine — a radar that shows everything removes the searching.

## Verification rule

Do not mark `VERIFIED` until tested in Roblox Studio. Inspect existing code through MCP before implementation; the feature may already partially exist.
