# Final Summary — Job #026

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ Built, measured, and approved by the user.

Radar Mk1 — a station you stand at, a storm from astern, and circles where something might be. `GAME-0002`
is now `IMPLEMENTED`. Mapped in [systems/radar/README.md](../../docs/systems/radar/README.md).

## What it does

A physical radar station on the vessel: a vertical screen on its own socket away from the helm, a turning
aerial on the mast, a head-up PPI with range rings and a sweeping beam, contacts that resolve from question
marks into fixes as you close on them, the storm as a mass astern, four live readouts, and a colour legend.

| Piece | |
|---|---|
Range | **1,800 studs**, from one constant — the skills hook |
Confident / uncertain | inside 1,080 a labelled blip; 1,080–1,800 a hollow amber circle, no label |
Sweep | 4 s per revolution; blips refresh on the pass and decay over 4 s |
The storm | astern-relative, appears at 1,800, swells as it closes |
Readouts | distance, arrival estimate, strength, visibility |
Dead states | `NO RETURN` inside The Wall · `RADAR FAULT` on job 022's fault |
Sounds | two alternating sweep ticks + a distinct contact ping, positional at the console |

**It gives job 022's radar fault teeth.** That fault has been published and consumed by nothing since it
shipped as an honest stub, and lightning already rolls it on close strikes.

## The design decisions worth keeping

**The scope is head-up because decision 0014 says so, not because it looks better.** A north-up scope *is* a
heading readout — the boat marker's rotation against a fixed north — and 0014 forbids one. So contacts plot at
`bearing − ownHeading`.

The tension that follows is deliberate and documented in the module: head-up plus a storm arc tells you where
the front is relative to your bow, which is a soft compass. Decision 0019 gives the radar that number on
purpose, and the blindness clause bites inside The Wall — *where the radar dies*. Someone will otherwise
"fix" it.

**The aerial and the console are two different things.** The existing `radar` socket sits 3.5 studs above the
deck — too high to read, exactly right for a scanner. So the aerial turns up there and a new `radarConsole`
station socket carries the display at deck level, deliberately away from the helm. The sweep is then legible
to the whole crew from outside, not just to the operator.

**An empty scope and a dead scope must not look the same.** A blank display reads as "nothing out there", the
crew sails on, and the instrument has lied by omission. Both failure states stop the sweep and name themselves.

**Contacts are discovered by tag.** Group 04's islands will only have to tag themselves — no registry to edit.
Six real contacts today, so the system shipped verified rather than stubbed.

## Four bugs, and how each was found

**1. The sweep beam orbited its own midpoint — caught by the user.** `GuiObject.Rotation` rotates about the
object's **centre, not its `AnchorPoint`**. A bar anchored at its bottom edge and rotated directly traces a
circle offset from the scope, which on screen read as a detached line floating beside the dial. Fixed with a
full-dial pivot container; the bar lives inside it. Measured after: the bar's centre holds a constant **124 px
from the dial centre across a full revolution, spread 0**.

**2. The readouts came out sideways — also caught by the user.** The scope was on the console's *top* face,
and a top-face `SurfaceGui` maps its "up" to one of the part's horizontal axes, which no player can predict.
The compass got away with the same choice in job 022 only because a compass card is rotationally symmetric; a
display with four readouts and a legend has a reading direction. Now a vertical screen whose facing is set by
**rotating the part** so its LookVector points aft, with the GUI always on `Front` — gravity fixes "up".

**3. One wrong constant, two opposite symptoms.** The storm plotted at `offset * 0.75` when `scopeOffset`
returns −1…1 and contacts correctly use `* 0.5`. Before clipping was added, the mass drew out over the bezel
and into the sky; after clipping, it vanished entirely.

**4. The storm rendered nowhere with every property correct** — and this one is only findable by measuring.
Visible, 49% opacity, a 422 px circle with **50% of its area overlapping the dial**, and nothing on screen. The
cause was `ZIndex = 0` inside a dial of `ZIndex = 1`: under Global ZIndex behaviour a descendant with a lower
ZIndex than its parent draws *beneath that parent's own background*, and the dial's background is opaque. So
`0` put the storm behind the very frame it lives in.

> The general lesson: **"behind its siblings" is ZIndex 1 plus earlier creation, never ZIndex 0.**

Worth noting how #4 was caught. Three rounds of reasoning about clipping and geometry produced nothing; dumping
the instance's actual properties and computing the overlap took one call and made the answer obvious.

## Measured

| Check | Result |
|---|---|
Pure maths | **44 of 45 checks passed** on first run — bearings, head-up transform, scope offsets, the confidence curve, the sweep wrap, readouts, both dead states |
The one failure | **my test, not the code**: `(x + 540) % 360 − 180` yields a half-open range, so dead astern is canonically −180, not +180. Documented in the function |
Sweep gating | blip opacity sawtooths **0.99 → 0.10** and snaps back, on a 4 s period |
Beam pivot | bar centre constant at **124 px** from the dial centre, spread 0 |
Head-up | bow north → storm at the bottom (y = 0.889); bow east → storm swings to the side. Turned **from the server**, because the server owns the hull and corrects a client-side turn — which is what made the first attempt a false negative |
Aerial | **90°/s**, exactly a 4 s sweep |
Contacts | 6 registered — start island, 4 barrels, tender — all resolving correctly |
Legend | all five rows fit inside the face (554 px against 600) |
Readouts | 0.90 km · 01:04 · STORM · 64% — arrival matches `900 / 14` |

## Deferred

- **Skills do not change the range.** `Radar.RANGE` is the single hook; progression is decisions 0008 / 0012
- **Named island contacts, sea POIs, nearest shelter** — all group 04. The mockup's "Nearest shelter" row is
  deliberately absent rather than showing a readout with nothing behind it
- **The storm mass is clipped flat** at the bottom rather than following the circular bezel —
  `ClipsDescendants` clips to the rectangle. Cosmetic; flagged and left
- **Instrument positions are provisional.** The user places all instruments once the real hull exists

### ✅ Auto-synced files

- `studio_game/ReplicatedStorage/Radar.luau` *(new)*
- `studio_game/ReplicatedStorage/Vessel.luau` — the `radarConsole` socket
- `studio_game/ServerScriptService/RadarServer.server.luau` *(new)*
- `studio_game/StarterPlayerScripts/RadarClient.local.luau` *(new)*
- `studio_game/ServerStorage/AdminTools.luau` + `studio_lobby/` copy — a new **Radar** section

### ⚠️ Manual Studio action required

- _none_ — everything here is runtime-built from source. No place save needed.

## Verification

- [x] Pure maths checked against hand-computed values before anything drew with them
- [x] Sweep gating, beam pivot, head-up transform, aerial rate — all measured
- [x] Both dead states reachable and visibly broken; `Radar → Break / repair the radar` added because the
      honest routes are sailing into The Wall or waiting for lightning
- [x] Contacts register by tag; newly spawned barrels are picked up
- [x] Legend fits; readouts correct
- [x] Approved by the user by eye
- [x] No new analyzer diagnostics; 18 shared files identical; Play stopped; Studio in Edit
- [ ] **Sounds have never been heard in place** — they were auditioned through the storm's `thunder` slot, not
      through the radar's own positional emitters
- [ ] Never seen on a phone (todo 0003 territory)
