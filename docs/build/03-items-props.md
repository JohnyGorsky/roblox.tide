# 03 — Items & props

**Group:** the small stuff — resources you pick up, containers you open, and the scenery that dresses
every island, wreck and deck.
**Items:** ~92 (23 pickups, 10 containers, 44 scenery props, 15 systems)
**Depends on:** nothing. Deliberately early — everything downstream needs props to exist.
**Feeds:** 04 (islands are mostly props), 08 (shipyard displays parts), 09 (inventory icons).

Systems: [loot catalog](../content/loot.md) · [parts & components](../content/parts-components.md) ·
decisions [0011](../decisions/0011-shared-expedition-rewards.md), [0012](../decisions/0012-parts-progression.md)

---

## Why this group is early and cheap

Props are the highest-leverage work in the project: one crate mesh dresses twelve islands, a wreck, a
pirate camp and the player's own deck. They graybox well, they are small Meshy jobs, and nothing else can
be dressed until they exist.

Keep the economy legible (from the loot catalog): **scrap / fuel / ammo = this expedition. Ship parts and
rare components = permanent progress.** Two visual languages, never blurred — a player must know at a
glance whether a pickup matters after the run ends.

---

## A. In-run resources — 6 items

Consumed during a run; mostly reset afterwards.

| Item | What it is | GB | Source |
|---|---|---|---|
| Fuel can / jerry can | The pressure resource. Also usable at the boat's filler | ✅ | meshy |
| Scrap pile | Generic repair/upgrade currency for the run | ✅ | meshy |
| Ammo box | Ammunition. Scarcity is deliberate | ✅ | meshy |
| Food crate | Hunger/stamina if adopted; otherwise a minor heal | ✅ | meshy |
| Medical supplies | Healing and revive material | ✅ | meshy |
| Repair material bundle | Patches a breach; distinct from generic scrap | ✅ | meshy |

## B. Permanent parts — 4 items

The core of decision 0012. These must look *valuable and mechanical*.

| Item | What it is | GB | Source |
|---|---|---|---|
| Hull Part | Plate, rib, weld stock. Found at wrecks, dockyards, cargo vessels | ⚠️ | meshy |
| Engine Part | Pistons, gearing. Found in engine rooms, tankers, repair stations | ⚠️ | meshy |
| Electronic Part | Boards, valves, cabling. Found at radar towers, research stations | ⚠️ | meshy |
| Weapon Part | Barrels, mounts, mechanisms. Found on pirates, military islands | ⚠️ | meshy |

Graybox ⚠️ because these are the emotional payload of the whole progression loop — four indistinguishable
grey lumps make the reward feel like nothing. Even placeholders should differ in silhouette and colour.

## C. Rare named components — 10 items

Targeted expedition goals. Each should be individually recognisable and slightly awe-inspiring.

| Item | What it is | GB | Source |
|---|---|---|---|
| Military Radar Core | The prize from a military wreck | ⚠️ | meshy |
| Twin Engine Assembly | Bulky; visibly a two-person carry | ⚠️ | meshy |
| Heavy Diesel Block | Heaviest carry in the game | ⚠️ | meshy |
| Marine Gearbox | Precise, oily, mechanical | ⚠️ | meshy |
| Reinforced Hull Plans | A document, not a machine — different visual language | ✅ | studio |
| Experimental Generator | Faintly wrong-looking; hints at the supernatural tier | ⚠️ | meshy |
| Navigation Array | Antenna cluster | ⚠️ | meshy |
| Patrol Boat Blueprint | Document | ✅ | studio |
| Cutter Blueprint | Document | ✅ | studio |
| Heavy Harpoon Winch | Weapon-adjacent machinery | ⚠️ | meshy |

## D. Special run resources — 3 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Creature Sample | From killed sea monsters | ✅ | meshy |
| Navigation Data | Recovered charts/logs; may reveal POIs | ✅ | studio |
| Experimental Material | Late-tier crafting input | ✅ | meshy |

## E. Containers — 10 items

What loot lives inside. Opening one should have a beat.

| Item | What it is | GB | Source |
|---|---|---|---|
| Wooden crate | The default. Breakable | ✅ | meshy |
| Metal crate | Tougher; military | ✅ | meshy |
| Barrel | Fuel or water; explodes if fuel | ✅ | meshy |
| Oil drum | Rusted, stackable, scenery *and* container | ✅ | meshy |
| Locker | Wall-mounted, in cabins and stations | ✅ | meshy |
| Toolbox | Small, repair materials | ✅ | meshy |
| Cooler / icebox | Food | ✅ | meshy |
| Ammo case | Military ammunition | ✅ | meshy |
| Safe | Rare components; needs time or a tool to open | ✅ | meshy |
| Supply cache | Hidden; the reward for exploring properly | ✅ | studio |

## F. Scenery props — 44 items

The dressing kit. Reused endlessly across islands and POIs.

**Coastal & natural (12):** palm tree ×3 variants · mangrove · scrub bush ×2 · dune grass · beach rock ×3
sizes · coral outcrop · driftwood log · dead tree · boulder ×2 · seaweed clump · tidal pool

**Maritime (12):** mooring buoy · marker buoy · fishing net · crab pot ×2 · rope coil · anchor (prop) ·
dock piling · dock plank section · small jetty · rowboat (derelict) · outboard motor (loose) · life ring
(prop)

**Wreck & debris (8):** hull fragment ×3 · shipping container (intact/crushed) · floating pallet · torn
sail/tarp · twisted metal sheet · propeller (broken)

**Military & industrial (8):** sandbag ×2 · ammo crate stack · radio antenna · generator (prop) ·
concrete bunker section · watchtower frame · pipe run · floodlight tower

**Habitation (8):** tent · campfire (lit/out) · fish-drying rack · shack wall/roof kit · wooden sign ·
lantern · washing line · chair/table set

*Counts inside each line are one item each in the table above; the totals per line are the item counts.*

| Line | Items | GB | Source |
|---|---|---|---|
| Coastal & natural | 12 | ✅ | meshy / store |
| Maritime | 12 | ✅ | meshy |
| Wreck & debris | 8 | ✅ | meshy |
| Military & industrial | 8 | ✅ | meshy |
| Habitation | 8 | ✅ | meshy |

## G. Systems — 15 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Item definition registry | One place defining every item: id, type, stack, weight, icon, value | ❌ | code |
| Pickup interaction | Look, prompt, collect. Must work on touch | ❌ | code |
| Carry system | Big components as a visible two-hand carry that slows you | ❌ | code |
| Two-person carry | For the heaviest components — a genuine co-op moment | ❌ | code |
| Drop / throw | Including passing something aboard from the water | ❌ | code |
| Inventory model | Server-authoritative; per-player and per-vessel | ❌ | code |
| Vessel storage model | Shared crew storage with capacity, separate from personal | ❌ | code |
| Weight / capacity | Encumbrance so hauling has a cost | ❌ | code |
| Loot table system | Weighted spawns per POI type, stage and time of day | ❌ | code |
| Loot spawn points | Tagged markers island templates declare | ❌ | code |
| Container open/loot flow | Animation, timing, interruption if attacked | ❌ | code |
| Shared reward crediting | Permanent drops credited to **every** eligible player (decision 0011) | ❌ | code |
| Item icons | One per item for inventory/shop UI | ⚠️ | store |
| Pickup VFX + sound | Distinct feedback for common vs rare | ⚠️ | studio |
| Rare-drop moment | A stronger beat for a rare component — light, sound, callout | ⚠️ | studio |

---

## Suggested job split

1. **Item foundation** — G's registry, pickup, inventory, storage, weight. Test with two placeholder items.
2. **Run resources** — A, plus the loot table system and spawn points.
3. **Parts & components** — B + C + D, plus shared crediting. The progression loop becomes real.
4. **Container kit** — E, plus the open/loot flow.
5. **Scenery kit** — F. One job, batched by Meshy category; the payoff lands in group 04.
6. **Carry & haul** — carry, two-person carry, drop/throw. Needs animations from 11.
7. **Feedback polish** — icons, VFX, sounds, the rare-drop moment.

## Open questions

- **Is there a hunger/thirst system?** Food is in the loot catalog but no system claims it. If not, food
  becomes a minor heal and the food locker loses its point.
- **Personal vs vessel inventory split.** Does a player carry much at all, or is nearly everything vessel
  storage? Affects capacity design and every UI screen.
- **Do rare components need to be *carried* to the boat**, vulnerable the whole way? That is a great
  tension source and a real amount of work.
- **Store-bought vs Meshy for the scenery kit.** Creator Store is much faster for palms and rocks but
  needs the approval + script-scan flow and may not match the art direction. Probably mixed — decide per
  category before starting job 5.
