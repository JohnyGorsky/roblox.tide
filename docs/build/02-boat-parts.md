# 02 — Boat parts

**Group:** every physical part of a vessel, from the hull to the fuse box, plus the module system that
lets seven vessel classes share one parts library.
**Items:** ~118 (78 for the starter launch and its upgrade paths, 12 module/system pieces, 7 hulls, ~21 shared fittings)
**Depends on:** 01 (wave field, to float on).
**Feeds:** 09 (instruments the HUD deliberately does *not* duplicate), 10 (crew stations).

Systems: [boat](../systems/boat/README.md) · [physics](../systems/boat/physics.md) ·
[upgrades](../systems/boat/upgrades.md) · [vessels](../systems/vessels/README.md) ·
decisions [0005](../decisions/0005-boat-mobile-base.md), [0009](../decisions/0009-vessel-class-architecture.md)

---

> **First job delivered — [021](../../Jobs/021/final-summary.md), MVP signed off 2026-08-21.** The kit exists
> (`Vessel` specs + 8 sockets), the starter launch floats on the wave field with four-point buoyancy, and she
> steers, trims, heels, burns fuel and holds her course. Server-owned throughout, no `VehicleSeat`
> ([decision 0022](../decisions/0022-vessel-physics-and-authority.md)).
>
> **Nothing in the kit is tuned per hull** — buoyancy stiffness, drag, rudder authority and yaw damping are all
> derived from the spec's statements of intent (`draft`, `cruise`, `rudderLag`) plus the hull's own mass and
> inertia. Verified exact across hulls from 4,200 to 90,000 mass. That property is the whole promise of
> decision 0009 and must not be broken by a later vessel.
>
> ⚠️ Read [finding 0019](../../findings/0019-a-large-torque-applied-in-a-body-relativ.md) before touching any
> force on a vessel: a large torque in a body-relative frame leaks into every axis the body rotates about, and
> it spun this hull 178 degrees in 8 seconds with the wheel amidships.

## Build the module kit once, then the hulls

The trap here is building a boat. Decision 0009 says build a **Vessel**: a hull plus sockets, and a
library of modules that fit any socket. Seven vessel classes then cost one hull each instead of seven
boats.

```text
Vessel
├── PhysicsChassis        one rigid assembly - hull collision, buoyancy points, propulsion points
├── Sockets               named attachment points: helm, engine, radar, hardpoint x N, light x N, storage x N
└── Modules               everything below, each fitting a socket type
```

So: **the starter launch is the first customer of the kit, not the thing being built.**

⚠️ **Graybox warning for the hull.** A grey box floats and steers, and it will teach you the wrong thing
about everything else: deck space decides how many crew can work without colliding, freeboard decides
whether waves come aboard, and length decides how the chase camera frames it. Build the starter hull to
its intended dimensions early, even if it is untextured. Everything bolted *onto* it grayboxes fine.

---

## A. Hull & structure — 16 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Hull (collision) | The physics chassis. One rigid part or welded assembly, low centre of mass | ⚠️ | studio |
| Hull (visual) | The shell, weathered ex-military utility launch | ❌ | meshy |
| Deck | Walkable surface. Sized so 2–3 crew can pass each other | ⚠️ | studio |
| Gunwale / railing | Edge you grab in rough sea; stops casual falls | ⚠️ | studio |
| Bow section | Forward deck, anchor mount, spray origin | ⚠️ | meshy |
| Stern section | Aft deck, boarding point, outboard/drive mount | ⚠️ | meshy |
| Cabin / wheelhouse | Encloses the helm. Shelter and a silhouette | ⚠️ | meshy |
| Cabin door | Openable; a boarding chokepoint at night | ✅ | studio |
| Windscreen / windows | Glass, cracked variants for damage states | ✅ | studio |
| Cabin roof | Mount point for radar mast and lights | ✅ | studio |
| Ladder | Climb aboard from water. Needs a climb animation (11) | ✅ | studio |
| Boarding platform | Aft swim step; where a rescued player comes aboard | ✅ | studio |
| Cleats & bollards | Rope attachment; used by mooring and by boarding enemies | ✅ | studio |
| Fenders | Hanging bumpers. Pure character, very cheap | ✅ | studio |
| Anchor + chain | Holds position. Never anchor the assembly to park it — hold with a constraint | ✅ | meshy |
| Bilge hatch | Floor access to the flooding volume below deck | ✅ | studio |

## B. Helm & instruments — 12 items

Decision: boat information lives **on the boat**, not the HUD. These are the readouts.

| Item | What it is | GB | Source |
|---|---|---|---|
| Helm console | The station itself; a crew position | ⚠️ | meshy |
| Wheel | Steering, visibly turning with input. IK hand targets | ⚠️ | meshy |
| Throttle lever | Forward/neutral/reverse, animated | ✅ | studio |
| Speed gauge | Needle or digital, in knots | ✅ | studio |
| Fuel gauge | The most-watched dial in the game | ✅ | studio |
| Engine condition gauge | Health as a dial, not a bar | ✅ | studio |
| Hull condition gauge | Ditto | ✅ | studio |
| Compass | Heading. Physical, readable from the wheel. **The one system that can never fail** — indestructible and untargetable by design, because it is the only way out of The Wall. ⚠️ **Must be self-lit and legible in total darkness** — inside The Wall it is one of only two navigation instruments left (decision 0014). Graybox is *not* fine here: if it cannot be read in the dark it fails its most important job | ⚠️ | studio |
| Ignition / starter | Start sequence with a cough-and-catch sound | ✅ | studio |
| Horn / siren | Signalling, and the storm alarm | ❌ | sound |
| Red emergency lamp | Hull critical / severe fault. World feedback over HUD text | ✅ | studio |
| Amber warning lamp | Low fuel / minor fault | ✅ | studio |

## C. Propulsion & fuel — 9 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Engine block | Visible in the bay; the thing you repair | ⚠️ | meshy |
| Engine hatch | Opens to expose it | ✅ | studio |
| Propeller | Spins with throttle; fouls on eels and nets | ✅ | meshy |
| Rudder | Turns with steering | ✅ | studio |
| Drive shaft | Connects them; a damage target | ✅ | studio |
| Exhaust stack | Smoke output scaling with throttle and damage | ✅ | studio |
| Fuel tank | Capacity is a real stat; upgradeable | ✅ | studio |
| Fuel filler | Where a jerry can is used; a refuel interaction point | ✅ | studio |
| Jerry can | Portable fuel. Also a lootable item (03) | ✅ | meshy |

## D. Power & electrical — 5 items

The generator is the shared power budget. Crew turning systems off under pressure is a core moment.

| Item | What it is | GB | Source |
|---|---|---|---|
| Generator | The unit itself; noisy, repairable | ⚠️ | meshy |
| Power panel | Where power is allocated. Radar vs pumps vs lights vs weapons | ⚠️ | studio |
| Battery | Reserve when the generator is down | ✅ | studio |
| Wiring / conduit | Runs along the hull; visibly damaged by strikes | ✅ | studio |
| Breaker switches | Physical per-system on/off | ✅ | studio |

## E. Navigation & radar — 7 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Radar mast | Carries the antenna high | ⚠️ | studio |
| **Radar antenna** | **Must be a separate rotating part** — already noted in the asset registry | ⚠️ | meshy |
| Radar screen / station | The sweep display. A crew position | ⚠️ | studio |
| Chart table | Where the wider map is read. ⚠️ **Needs its own lamp**: with the radar degraded inside The Wall, the chart is the other half of blind navigation | ⚠️ | studio |
| Nautical chart prop | The physical chart on it | ✅ | studio |
| Binoculars | Tool; contextual first-person (decision 0001) | ✅ | meshy |
| Radio set | Distress calls, story signals, ghost transmissions | ✅ | meshy |

## F. Lighting — 6 items

Night is half the game. Lights are gameplay, not decoration.

| Item | What it is | GB | Source |
|---|---|---|---|
| Deck lamp | Weak starting light | ✅ | studio |
| Searchlight | Aimable, a crew job. Range up to 120 studs is available | ⚠️ | studio |
| Twin searchlights | Upgrade | ✅ | studio |
| Military floodlights | Upgrade; wide wash | ✅ | studio |
| Navigation lights | Port red / starboard green / stern white. Reads as a real vessel at distance | ✅ | studio |
| Anti-creature light | Late experimental; repels specific enemies | ⚠️ | studio |

## G. Damage & repair — 8 items

Damage must create *tasks*, not just subtract numbers.

| Item | What it is | GB | Source |
|---|---|---|---|
| Breach / leak point | Attachment where water enters. Decal + spray particle + sound | ⚠️ | studio |
| Flooding volume | Below-deck water level rising; the thing pumps fight | ❌ | code |
| Repair point | Where the repair animation plays and validates | ✅ | studio |
| Workbench | Upgrade/repair station | ⚠️ | meshy |
| Manual bilge pump | Hand pump — costs a crew member's whole attention | ✅ | meshy |
| Electric bilge pump | Upgrade; costs generator power instead of a person | ✅ | studio |
| Toolbox | Repair kit source | ✅ | meshy |
| Fire extinguisher | Generator fires, electrical faults | ✅ | meshy |

## H. Storage & cargo — 8 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Storage crate | The starting container | ✅ | meshy |
| Cargo rack | More capacity, visible cargo | ✅ | studio |
| Tool locker | Repair materials | ✅ | studio |
| Ammo locker | Ammunition; a boarding target | ✅ | studio |
| Food locker | Food and medical | ✅ | studio |
| Rare-item safe | Protects rare components from theft | ✅ | meshy |
| Fuel drum rack | Deck fuel — capacity at the cost of fire risk | ✅ | studio |
| Cargo net | Holds deck cargo; visibly strains in rough sea | ✅ | studio |

## I. Weapons & hardpoints — 6 items

Weapons themselves are group 06; these are the mounts.

| Item | What it is | GB | Source |
|---|---|---|---|
| Hardpoint socket | Generic mount any weapon module fits | ❌ | code |
| MG mount | Pintle mount with traverse limits | ⚠️ | studio |
| Harpoon mount | Heavier, slower traverse | ⚠️ | studio |
| Mounted ammo box | Feeds the gun; reload interaction | ✅ | studio |
| Depth-charge rack | Stern rack, roll-off animation | ✅ | studio |
| Gunner position | Where the gunner stands; contextual first-person | ❌ | code |

## J. Crew fittings — 5 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Seats / benches | Rest points, passenger positions | ✅ | studio |
| Bunk | Below-deck sleep/respite point | ✅ | studio |
| Medkit station | Healing and revives | ✅ | studio |
| Life ring | Rescue a player in the water | ✅ | studio |
| Life raft | Emergency; possibly a run-failure escape | ⚠️ | meshy |

## K. The module system itself — 12 items

Not art. The machinery that makes the above swappable.

| Item | What it is | GB | Source |
|---|---|---|---|
| Vessel definition schema | Data describing a class: dimensions, sockets, capacities, handling | ❌ | code |
| Socket type registry | Which module kinds fit which sockets | ❌ | code |
| Module mount/unmount | Attach, weld, wire up, tear down cleanly | ❌ | code |
| Module state replication | Server-authoritative module state to clients | ❌ | code |
| Visual upgrade swapping | A late-run vessel must look dramatically different | ❌ | code |
| Buoyancy config per hull | Volume, density, righting moment. ⚠️ **Hull parts must be non-buoyant to the engine** (or its contribution explicitly accounted for): terrain-water auto-buoyancy pulls toward a flat Y=0 plane and will fight the wave field, and the symptom looks like jitter rather than a conflict — finding 0008 | ❌ | code |
| Mass & COM management | Massless decor, low COM, cargo affecting trim | ❌ | code |
| Network ownership policy | Server-owned while the server computes buoyancy — a known trap | ❌ | code |
| **ReplicationFocus on the vessel** | Streaming is on; without this the deck streams out for distant crew | ❌ | code |
| Damage model | Per-module condition, failure states, cascades | ❌ | code |
| Interaction point spec | Character position, facing, animation, hand IK targets per station | ❌ | code |
| Vessel spawn / despawn | Bring the chosen vessel into the run and clean it up after | ❌ | code |

## L. The seven hulls — 7 items

Each is one hull plus a socket layout; modules come from the kit above. Sizes are for planning.

| Vessel | Crew | Rough length | Distinguishing build work |
|---|---|---|---|
| Old Launch | 1–4 | ~22 studs | The starter. Minimal sockets, open deck |
| Reinforced Launch | 1–4 | ~24 studs | Armour plating variants, one extra socket |
| Patrol Boat | 2–6 | ~45 studs | Multiple hardpoints, real bridge, more deck |
| Trawler | 2–6 | ~55 studs | Winch, net gear, big cargo hold |
| Research Vessel | 2–6 | ~50 studs | Antenna array, lab interior, sensor gear |
| Cutter | 4–6 | ~70 studs | Heavy hull, larger generator room, several stations |
| Expedition Ship | 4–6+NPC | ~110 studs | **Multi-deck interior** — bridge, engine room, generator room, cargo/workshop. Sectional damage. Effectively its own group |

Bigger must not simply be better (decision 0009): each trades speed, fuel, turning, cargo, armour,
power, crew need.

---

## Suggested job split

Nine jobs. Not one — "all boat parts in one job" is roughly 118 items, which is a month, not a sitting.

1. **Vessel foundation** — K, plus the starter hull at correct dimensions. Floats, steers, nothing else.
2. **Helm & instruments** — B. First diegetic-information pass.
3. **Propulsion & fuel** — C, plus fuel as a real resource.
4. **Damage & repair** — G, plus the flooding model. The first real crew emergency.
5. **Power & electrical** — D. Makes the radar/pumps/lights tradeoff live.
6. **Nav & radar hardware** — E. Pairs with feature 0002.
7. **Lighting** — F. Pairs with the night half of 07.
8. **Storage, cargo & crew fittings** — H + J.
9. **Hardpoints** — I, timed with group 06.

Then one job per additional hull, in progression order, reusing the kit.

## Open questions

- **Interiors: when?** The Expedition Ship needs walkable interiors and sectional damage. Cheapest path is
  no interiors before the Cutter — confirm before designing hull internals.
- **Below-deck flooding: real space or abstract volume?** A visible flooding compartment is far more
  dramatic and far more work than a rising number.
- **How much of the launch is one mesh?** One hull mesh is cheaper to draw; separate bow/stern/cabin
  allow damage states and modular upgrades. Leaning separate, for the "looks different by the end" rule.
- **Do NPC crew need different station geometry** than players (pathfinding clearance, standing room)?
  Answer before finalising deck layouts.
