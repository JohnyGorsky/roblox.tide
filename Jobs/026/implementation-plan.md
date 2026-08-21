# Implementation Plan — Job #026

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Status**: ✅ Complete — all steps landed and measured. See [final-summary.md](final-summary.md)

Radar Mk1 — a station you stand at, a storm from astern, and circles where something might be.

---

## Rulings and assets

| | |
|---|---|
Range | **1,800 studs**, as one constant (the skills hook) |
Contacts between sweeps | **refresh on sweep, then decay** |
Sounds | `9126138070` + `9126138068` (sweep variants), `75886285262316` (contact) — approved, logged |

---

## Analysis

### 🔴 The scope must be HEAD-UP, and decision 0014 decides that, not taste

A PPI can be drawn north-up (north always at the top) or head-up (your own bow at the top). This is not a
style choice here:

> **A north-up scope is a compass.** The boat marker's rotation against a fixed north *is* a heading readout,
> and decision 0014 forbids one.

So contacts are plotted at **relative** bearing — `bearing − ownHeading` — with the bow at the top. Which is
also what small-craft radar actually does.

### The tension that follows, and why it is fine

Head-up plus a storm arc means the arc's position on the scope tells you where the storm is *relative to your
bow* — and since the front is always astern in absolute terms, that is a soft compass.

**That is acceptable, and it is the whole point of the instrument.** Decision 0019 gives the radar the storm's
number deliberately, and the storm doc's argument is that knowing where the front is *is* knowing which way is
away. The blindness clause only bites inside The Wall — **where the radar dies**. So:

- outside The Wall: the radar tells you where the storm is. Intended.
- inside The Wall: no radar, and the compass is all you have. Intended.

Writing this down because it looks like a leak and is not, and someone will otherwise "fix" it.

### The aerial and the console are two different things

The vessel spec's `radar` socket is at `(0, 6, 6)` — 3.5 studs above the deck. That is too high to read a
display, and it is the right height for a **scanner**. So:

- the **aerial** goes on the existing `radar` socket: a small rotating bar, turning at the sweep period, so
  the scope's sweep is visible from outside the wheelhouse
- the **console** gets a new `radarConsole` socket of kind `station`, at deck level

Which follows job 022's pattern exactly (`damageControl` was added the same way), and it means the sweep is
legible to the whole crew, not just the operator.

**Where the console goes matters.** Far enough from the helm that one person cannot comfortably drive and watch
— the same reasoning that put the damage-control locker aft. Proposed `(-4.5, 2.5, 2)`: port side, a few studs
abaft the helm at `(0, 2.5, 8)`. Close enough to shout across, too far to do both.

### ~~The scope is a plot table, not a screen~~ — **WRONG, and superseded during the build**

The plan argued for the console's **top face**, like a bridge plotting table: partly authenticity, mostly
because it dodged which *vertical* face the operator stands at (finding 0021 — the spec labels `+Z` as the bow
while the hull drives toward `-Z`). The compass took that way out in job 022.

**It does not work for a display carrying text.** A top-face `SurfaceGui` maps its "up" to one of the part's
horizontal axes, so the four readouts and the legend came out sideways — the user spotted it immediately. The
compass gets away with it only because a compass card is *rotationally symmetric*: turn it any way and it still
reads.

Replaced by a **vertical screen whose facing is set by construction**: the part is rotated so its own
`LookVector` points aft and the GUI always goes on `Front`. Gravity then fixes "up", and the ambiguity finding
0021 describes never enters into it, because nothing reads a spec label — the orientation comes from the hull's
measured `LookVector`.

Self-lit (`LightInfluence = 0`), like the compass. The one instrument you need at The Wall's brightness of 0.30
must not be the one you cannot read — even though the radar is dead there, the *legend* and the failure state
still have to be legible.

### The numbers

```
range              1800 studs
confident inside   1080  (0.6 x range) -> shaped blip with a distance
uncertain          1080..1800          -> small hollow amber circle, no label
off scope          > 1800              -> nothing
rings              600 / 1200 / 1800
sweep              4 s per revolution (marine radar is 2-6)
blip decay         4 s, so a contact fades just as the beam returns
```

**The storm appears on the scope when it closes to 1,800** — 171 seconds of a stationary crew from its 4,200
start. So the arc arriving is itself an event, rather than something present from the first second.

Visibility % is derived from the live sea state's `fogEnd` against the calmest:

| Sea | fogEnd | Visibility |
|---|---|---|
DeadCalm | 2,900 | 100% |
LightSwell | 2,600 | 90% |
Choppy | 1,800 | 62% |
Storm | 1,100 | 38% |
The Wall | 330 | 11% |

### There are already three real contacts

So the contact system ships **verified**, not stubbed — and the start island demonstrates the whole resolution
curve on its own as the vessel travels north:

| Contact | Distance | Renders as |
|---|---|---|
Start island, at spawn | 70 | confident, labelled |
Fuel barrels (job 023) | 200–400 | confident, labelled |
Start island, 1,200 north | 1,200 | **uncertain amber circle** |
Start island, 1,900 north | 1,900 | off scope |

### 🔴 An empty scope and a dead scope must not look the same

If the radar reads blank when it fails, the crew reads "nothing out there" and sails on. So the two failure
states are drawn as **visibly broken** — the sweep stops, the rings dim, and the console says `NO RETURN`:

- `StormIntensity == 4` — inside The Wall (decision 0019)
- `VesselFault_radar` — job 022's fault, which has been published and consumed by nothing since. **This is the
  feature that gives it teeth**, and lightning already rolls it on close strikes

### Contacts are discovered by tag

`CollectionService` tag `RadarContact`, with attributes `RadarKind` (`land` / `object` / `unknown`) and an
optional `RadarLabel`. Never by instance path — finding 0020 is the story of a hardcoded path between two
systems rotting silently. Group 04's islands then only have to tag themselves.

Being straight about what "server-authoritative" means here: the server owns the *registry*, but tagged
instances are replicated, so a determined client can enumerate them regardless. This stops a client
*inventing* contacts; it does not make the sea secret. Same honesty as the `VesselHeading` note in job 022.

---

## Implementation steps

1. **`ReplicatedStorage/Radar.luau`** — pure. Range and the skills hook, the confidence curve, sweep angle
   from server time, "did the beam cross this bearing since the last frame", relative-bearing maths, the
   legend palette, kind→colour. No instances, testable from a probe like `VesselDamage`.
2. **`Vessel.luau`** — add the `radarConsole` station socket, with the reasoning for its distance from the helm.
3. **`ServerScriptService/RadarServer.server.luau`** — build the console and the aerial; own the contact
   registry; tag what exists today (start island marker, the four barrels, the tender). Publish nothing the
   client can compute for itself.
4. **`StarterPlayerScripts/RadarClient.local.luau`** — draw the scope on **Heartbeat** (finding 0022): rings,
   own-ship, sweeping beam, blips with decay, the storm arc, the readouts, the legend. Play the sweep tick and
   contact ping **positionally at the console**, alternating the two sweep variants.
5. **Admin tools** — `Radar → Status` (range, contacts in range with their confidence), `Radar → Kill the
   radar` (toggles the fault so the dead state is reachable without waiting for lightning).
6. **Docs** — feature `GAME-0002` to `IMPLEMENTED`, a systems doc, register the console/aerial as grayboxes,
   re-run `build-status.py`.

---

## What I need from you

- [ ] **Go-ahead**, and a view on the console's position — `(-4.5, 2.5, 2)`, port side just abaft the helm. It
      is deliberately not *at* the helm, so watching the radar is a job somebody takes.
- [ ] Nothing to source. The sounds are approved and logged.

---

## Verification

- [ ] **Pure maths first**, from a probe: bearing and distance against hand-computed values; the confidence
      curve at 0 / 1,079 / 1,081 / 1,799 / 1,801; sweep angle wrapping through 360°
- [ ] **The sweep gates the blips** — a contact's blip must brighten only as the beam passes it, and decay
      between passes. Sampled over two full revolutions
- [ ] **Resolution changes with distance** — drive north and confirm the start island goes labelled →
      amber circle → off scope, at 1,080 and 1,800
- [ ] **The barrels appear** as confident labelled contacts at 200–400
- [ ] **The storm arc appears at 1,800 and not before**, and sits astern-relative — turn the boat and confirm
      the arc swings round the scope rather than staying put
- [ ] **Two dead states, and they look dead** — force `VesselFault_radar`, then drive into The Wall. Sweep
      stopped, `NO RETURN` shown, and visibly different from an empty sea
- [ ] **The legend is readable at brightness 0.30** — screenshot inside The Wall
- [ ] **No heading anywhere** — the scope is head-up, and `VesselHeading` still returns nil on a client
- [ ] Sounds fire positionally at the console, alternating variants; slots log the gap if an id is cleared
- [ ] No new analyzer diagnostics; Play stopped; camera restored; Studio in Edit
