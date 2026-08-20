# 04 — Islands & sea POIs

**Group:** the places you stop at — 12 curated islands, 9 sea POIs, 6 rare POIs, plus the template
machinery that spawns and varies them.
**Items:** ~27 locations + 18 system pieces
**Depends on:** 01 (water line), 03 (props to dress them with).
**Feeds:** 05 (enemies need somewhere to live), 06, and the whole loot loop.

Systems: [islands](../systems/islands/README.md) · [encounters](../content/encounters.md) ·
[island catalog](../content/islands.md) · decision [0003](../decisions/0003-curated-islands.md)

---

## Curated, not generated

Decision 0003: islands are **authored templates**, reviewed and hand-improved, then stored and reused.
Procedural generation may produce *candidates* during development, but runtime does not invent terrain.

So an island is: terrain snapshot + prop set + metadata (dock points, loot points, enemy spawns, POI
markers, stage tags, encounter weights). Runtime picks a template, pastes it, then picks an
**encounter variant** — which is where replay value actually comes from. Twelve islands × six variants
reads as far more than twelve places.

⚠️ **Terrain streaming caution.** The game place has `StreamingEnabled = true`. Terrain must exist before
anything is placed on it — probe for ground before seating props, or they end up buried or floating. The
`roblox-terrain` skill records this exact failure.

---

## A. Worked example: the small resource island

The user asked what is actually *on* a small island. This is the smallest template, and the shape every
other island follows.

**Size:** ~180 × 140 studs of land. Two minutes to loot if unopposed. One dock point.

**Terrain:** low sand spit rising to a scrub-covered rise ~14 studs, one rocky outcrop, a shallow reef
shelf offshore that forces careful approach.

**Props (~24 placements from the group-03 kit):**

| Zone | What is placed |
|---|---|
| Beach | 3 palms, driftwood log, 2 beach rocks, tidal pool, marker buoy offshore |
| Wreck corner | Small derelict rowboat, hull fragment, torn tarp, 2 oil drums |
| Camp | Tent, dead campfire, fish-drying rack, wooden crate ×2, rope coil, lantern |
| Rise | Scrub ×3, dead tree, boulder, wooden sign (weathered, unreadable) |
| Reef | Coral outcrop ×2, crab pot |

**Loot: 5–7 points**

| Point | Contents |
|---|---|
| Camp crates ×2 | Scrap, food, sometimes ammo |
| Barrel by the wreck | Fuel — the reason to stop |
| Rowboat | Repair materials, occasionally an Engine Part |
| Cache under the rise | Hidden; rewards actually exploring. Rare-ish: Hull Part or Electronic Part |
| Crab pot | Food, minor |

**Enemies: light. This is the tutorial-grade island.**

| Enemy | Count | Where |
|---|---|---|
| Giant crab | 2–3 | Beach and reef; slow, telegraphed, a safe first fight |
| Shark | 1 | Offshore; punishes swimming rather than landing |
| *(night variant)* Drowned sailor | 2–3 | Emerges from the water line; the same island becoming unsafe |

**Enemy groups:** a "crab cluster" (2–3 crabs sharing an aggro leash so they arrive together rather than
in single file) and, at night, a "drowned tide" (a group surfacing on a timer at the water's edge).

**Weapons that matter here:** machete (melee, cuts scrub and rope), flare gun (night visibility and
signalling), double-barrel shotgun if boarding pressure begins. No mounted-weapon relevance — this island
is a landing, not a battle.

**Encounter variants for this one template:**

| Variant | What changes |
|---|---|
| Untouched | Base loot, crabs only |
| Fuel cache | Extra fuel drums, but a pirate skiff patrolling offshore |
| Storm-damaged | Debris everywhere, richer scrap, unstable terrain |
| Occupied | 3–4 pirates camped; the camp is *theirs* |
| Drowned (night) | Drowned sailors, dimmer, better rare-part odds |
| Trader | A lone survivor who trades instead of fighting |

That is **one** template producing six meaningfully different stops. Every island below gets the same
treatment.

---

## B. The 12 curated islands

| # | Island | Scale | Signature content | Parts it favours |
|---|---|---|---|---|
| 1 | Tiny resource island | Small | The worked example above | Engine, Hull |
| 2 | Fishing village | Medium | Shacks, jetties, drying racks, a bell | Hull, Electronic |
| 3 | Lighthouse island | Medium | Working beam, spiral climb, keeper's log | Electronic |
| 4 | Pirate camp | Medium | Palisade, watchtower, loot pile, prisoners | Weapon |
| 5 | Military outpost | Large | Bunkers, radio mast, ammo stores, gun emplacement | Weapon, Electronic |
| 6 | Cargo depot | Medium | Container stacks, crane, forklift wreck | Hull, Engine |
| 7 | Abandoned research station | Large | Labs, generators, unsettling notes, first real supernatural hint | Electronic, Experimental |
| 8 | Rocky cave island | Medium | Interior cave, needs a light, echo audio | Rare components |
| 9 | Shipwreck beach | Medium | A large broken hull to climb through | Hull, Engine |
| 10 | Storm shelter | Small | A safe-ish harbour; shelter from the storm at a cost | Fuel, repair |
| 11 | Strange / cursed island | Large | Wrong geometry, wrong sounds, high risk | Rare, Experimental |
| 12 | Large fortress island | Very large | Multi-stage assault; the set-piece | Everything, boss-tier |

## C. Sea POIs — 9 items

Floating stops needing no terrain. Cheaper than islands and excellent early content.

| POI | What it is |
|---|---|
| Fishing boat | Derelict or occupied; small and quick |
| Cargo wreck | Half-sunk; climbable, Engine and Hull parts |
| Container debris | Floating field; light salvage, navigation hazard |
| Oil rig | Vertical structure, multi-level, big landmark |
| Floating platform | Military or research; a helipad-scale flat stop |
| Buoy field | Navigation puzzle; something tangled in one |
| Submarine wreck | Partly surfaced; claustrophobic interior |
| Ghost ship | Encounter as much as place; appears and does not stay |
| Lifeboat | Survivor rescue; tiny, high emotional value |

## D. Rare POIs — 6 items

Rare enough to be talked about. Each should produce a story.

| POI | The hook |
|---|---|
| Mimic island | Looks like an island; it is not. Escape event |
| Ghost lighthouse | A beam from a lighthouse that is not there |
| Research vessel | Intact and running, crew absent |
| Aircraft wreck | Out of place; military cargo |
| Sea temple | Ancient, submerged, the deep supernatural tier |
| Unknown radar signal | A contact that resolves into something never catalogued |

## E. Template & spawning systems — 18 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Island template format | Terrain region + props + metadata, saved and versioned | ❌ | code |
| Terrain save/paste | Capture a region and paste it at runtime, reliably | ❌ | code |
| Streaming-safe placement | Wait for terrain, probe the ground, then seat props | ❌ | code |
| Footprint validation | Validate across the whole footprint, not one raycast — a 200-stud island is not a point | ❌ | code |
| Dock point marker | Where a vessel can safely moor; approach depth matters | ❌ | code |
| Loot point marker | Tagged spawn positions with tier weights | ❌ | code |
| Enemy spawn marker | Position, enemy type pool, count range | ❌ | code |
| POI marker | What radar sees and how it classifies (feature 0002) | ❌ | code |
| Stage tags | Which sea stages a template may appear in | ❌ | code |
| Encounter variant system | Pick and apply a variant to a pasted template | ❌ | code |
| Time-of-day variant | Night versions: different enemies, lighting, audio | ❌ | code |
| POI selection & placement | Choose what appears ahead, at what spacing, without repetition | ❌ | code |
| Radar contact registration | Register each POI so radar can report it at its class level | ❌ | code |
| Approach & landing | Getting off the boat and back on; the boat must still be there | ❌ | code |
| Despawn & cleanup | Remove a POI once left behind, without leaking instances | ❌ | code |
| Island Forge tooling | Dev-time workflow: generate candidate → keep → sculpt → mark up → save | ❌ | code |
| Template validation | Check a template has dock/loot/spawn markers before approving it | ❌ | code |
| Global water reconciliation | Templates contribute land only; the ocean stays shared | ❌ | code |

---

## Suggested job split

1. **Template pipeline** — E's format, terrain paste, streaming-safe placement, markers, validation.
   Prove it with island 1 only.
2. **Small island, fully dressed** — island 1 with all six variants. The reference build every other
   island copies. *Do this before building any other island.*
3. **Sea POI kit** — C's cheap floaters: fishing boat, cargo wreck, container debris, buoy field.
4. **Island Forge tooling** — the dev workflow, once we know from jobs 1–2 what it must support.
5. **Islands 2–6** — one job per island, or two per job once the pattern is proven.
6. **Islands 7–11** — the larger and stranger ones; each wants its own job.
7. **Fortress island** — island 12 alone; a set-piece with boss-tier content.
8. **Rare POIs** — D. Each is partly an event; pairs with group 07.

## Open questions

- **How is a template stored?** Terrain regions are large binary data. Serialised terrain in
  ServerStorage, or a hand-built place per island loaded via another mechanism? This decides the whole
  pipeline — answer in job 1.
- **Do islands persist while you are near them, or reset?** If a player returns to a looted island,
  is it still looted?
- **Can the boat be attacked while the crew is ashore?** Enormously good tension, and it means the
  vessel needs autonomous defence and the crew needs a reason to leave someone aboard.
- **How many islands are visible at once?** Affects streaming budget and how busy the sea feels.
