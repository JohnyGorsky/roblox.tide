# Radar Mk1

Implementation reference for `GAME-0002`, built in job 026. Design and its five corrections live in the
[feature doc](../../features/0002-radar/feature.md); decisions
[0004](../../decisions/0004-radar-no-permanent-minimap.md) (no permanent minimap) and
[0019](../../decisions/0019-storm-advance-model.md) (the radar owns the storm's number, and dies inside The
Wall) govern it.

## Where it lives

| File | Owns |
|---|---|
`ReplicatedStorage/Radar.luau` | the maths. Range, confidence, sweep, bearings, the legend palette. Pure |
`ServerScriptService/RadarServer.server.luau` | the console, the aerial, and the contact registry |
`StarterPlayerScripts/RadarClient.local.luau` | draws the scope and plays the sounds |

## The numbers

```
range              1800 studs   ONE constant - the skills hook
confident inside   1080         (0.6 x range) -> shaped blip with a distance
uncertain          1080..1800   -> small hollow amber circle, no label
off scope          > 1800       -> nothing
rings              600 / 1200 / 1800
sweep              4 s per revolution
blip decay         4 s, so a contact fades just as the beam returns
```

The storm appears on the scope only once it closes to 1,800 — 171 seconds of a stationary crew from its 4,200
start, so its arrival is an event rather than furniture.

## The five things that define it

**On the boat, not on the screen.** A physical station, so watching the radar is a job somebody takes rather
than a glance at a HUD. The console sits on a `radarConsole` station socket, deliberately away from the helm.

**The scope is HEAD-UP, and decision 0014 decides that.** A north-up scope *is* a heading readout — the boat
marker's rotation against a fixed north — which 0014 forbids. So contacts plot at `bearing − ownHeading` with
the bow at the top.

> The tension that follows is intended: head-up plus a storm arc tells you where the front is relative to your
> bow, which is a soft compass. Decision 0019 gives the radar that number on purpose, and the blindness clause
> bites inside The Wall — *where the radar dies*. Do not "fix" this.

**The storm comes from one side.** It draws astern-relative, always. Drawn as a wandering cell it would imply
the crew could steer around it, which is the opposite of the mechanic.

**Contacts refresh on the sweep and decay between passes.** Look away and your picture is genuinely stale.

**A colour legend on the console**, built from `Radar.LEGEND` so a swatch can never disagree with the blips it
explains.

## Two failure states, and they must look BROKEN

🔴 **An empty scope and a dead scope must not look the same.** A blank display reads as "nothing out there",
the crew sails on, and the instrument has lied by omission. So both stop the sweep and show a message:

| Cause | Shows |
|---|---|
`StormIntensity == 4` — inside The Wall | `NO RETURN` |
`VesselFault_radar` — job 022's fault | `RADAR FAULT` |

That second one is why this feature matters beyond itself: job 022 published that fault and **nothing consumed
it** until now. Lightning already rolls it on close strikes.

## Contacts

Any instance tagged `RadarContact`, carrying `RadarKind` (`land` / `object` / `unknown`) and an optional
`RadarLabel`. Never discovered by path — finding 0020. Group 04's islands only have to tag themselves.

Registered today: the **start island**, the **four fuel barrels**, and the **tender**. The island is the good
demo on its own — as the vessel sails north it recedes past 1,080 and then 1,800, so one contact walks the
whole resolution curve.

Honest about "server-authoritative": the server owns the *registry*, so a client cannot invent a contact. It
does not make the sea secret — tagged instances replicate. Same honesty as the `VesselHeading` note in job 022.

## Sounds

| Slot | Asset | Role |
|---|---|---|
`radar_sweep_1` | `9126138070` | tick as the beam passes |
`radar_sweep_2` | `9126138068` | variant, alternated |
`radar_contact` | `75886285262316` | a contact appearing |

Mounted **positionally on the console**, so they come from the station and not across the deck. Two sweep
variants because the tick fires every four seconds for a fifty-minute run — the worst case for audible
repetition. The contact ping is a different clip and fires only for a contact that was **not on the scope
before**: pinging every re-illumination would be constant noise and teach the operator to ignore it.

## Testing it

`Radar` section in the admin panel, ordered second:

- **Radar status** — range, whether the scope is live, and every registered contact with its distance and
  resolution
- **Break / repair the radar** — reaches the dead state on demand, which is otherwise only reachable by sailing
  into The Wall or waiting for lightning

## Traps

🔴 **`GuiObject.Rotation` rotates about the object's CENTRE, not its `AnchorPoint`.** The sweep beam is a bar
inside a full-dial **pivot container**; the container rotates. Rotating an anchored bar directly makes it orbit
its own midpoint and read as a detached line beside the scope.

🔴 **A child with a lower `ZIndex` than its parent can draw beneath that parent's background.** The storm mass
was `ZIndex = 0` inside a dial of `ZIndex = 1` and rendered nowhere at all, with every property correct.
"Behind its siblings" is ZIndex 1 plus earlier creation, never 0.

🔴 **`scopeOffset` returns −1…1**, so plotting is `0.5 + offset * 0.5`. Anything larger pushes a contact's
centre past the dial edge — which drew over the bezel before clipping, and vanished after it.

🔴 **A text-bearing display cannot go on a Top face.** A top-face `SurfaceGui` maps its "up" to one of the
part's horizontal axes, so the readouts come out sideways. The compass gets away with it only because a
compass card is rotationally symmetric. The scope is vertical and its facing is set by rotating the *part*.

⚠️ **Range must stay well inside the corridor.** `SeaStates.OCEAN_EXTENT_Z` runs to 5,500; the mockup's 6 km
would see past the end of the world.

## Still owed

- The **storm mass is clipped flat** at the bottom rather than following the circular bezel —
  `ClipsDescendants` clips to the rectangle. Cosmetic
- **Skills do not change the range yet.** `Radar.RANGE` is the single hook; progression is decisions 0008/0012
- **Named island contacts, sea POIs and nearest shelter** all wait on group 04
- The scope's palette came from the concept mockup, and the game has no style guide yet (todo 0001)
