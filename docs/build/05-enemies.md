# 05 — Enemies & groups

**Group:** 18 enemies, the groups they arrive in, and the AI that makes them attack *systems and plans*
rather than only health.
**Items:** 18 enemies × (mesh + rig + animation set + sounds + behaviour) ≈ 90 asset units, + 12 group definitions, + 16 system pieces
**Depends on:** 04 (somewhere to live), 02 (something to attack), 11 (animation pipeline).
**Feeds:** 06 (weapons need targets), 07 (night is when they matter).

Systems: [enemies](../systems/enemies/README.md) · [enemy catalog](../content/enemies.md) ·
`roblox-ai` skill · pair with the `roblox-chars` agent for Meshy rigs

---

## The design constraint that shapes every one of these

Pillar 6: **enemies attack systems and plans, not only HP.** An enemy that only reduces player health is
a worse enemy than one that stops the engine, cuts the radar, floods a compartment, steals cargo or slows
the boat so the storm catches up. Every entry below names what it *breaks*, not just what it hits.

Minimum animation set per enemy: idle, move, attack, hit reaction, death (5). Large creatures add surface,
dive, grab, slam, retreat, stunned, special (up to 12).

---

## A. Wildlife — 5 enemies

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Shark | Early | Punishes swimming; bites the hull, can start a leak | 6 | ⚠️ | meshy |
| Hammerhead | Early | Rams the hull — a knock and a breach chance | 6 | ⚠️ | meshy |
| Barracuda swarm | Early | Swimmer denial; makes water lethal, arrives as a group | 5 | ✅ | meshy |
| Giant crab | Early | Island guard; blocks a loot point | 5 | ✅ | meshy |
| Crocodile | Early | Mangrove ambush; drags a player | 7 | ⚠️ | meshy |

## B. Human threats — 3 enemies

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Pirate skiff | Early–Mid | Ranged chase; shoots the engine and crew | 5 + boat | ⚠️ | meshy |
| Boarding pirates | Mid | **Come aboard.** Steal cargo and fuel, damage modules, fight on deck | 8 | ⚠️ | meshy |
| Pirate gunboat | Mid–Late | Heavy vessel duel; out-guns the launch | 5 + boat | ⚠️ | meshy |

Boarding is the most valuable enemy behaviour in the game — it turns the vessel from a platform into a
place to defend. Prioritise it.

## C. Supernatural humanoids — 2 enemies

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Drowned sailor | Mid | Boards from below; silent, ignores lights | 7 | ⚠️ | meshy |
| Siren | Mid–Late | **Corrupts radar and navigation** — false contacts, wrong headings | 6 | ⚠️ | meshy |

## D. Sea monsters — 4 enemies

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Giant eel | Mid | **Fouls the propeller** — the boat stops dead | 8 | ⚠️ | meshy |
| Sea serpent | Late | Rams, wraps, slows; the storm gains ground | 10 | ⚠️ | meshy |
| Tentacle creature | Late | **Grabs modules and players** off the deck | 10 | ⚠️ | meshy |
| The Lure | Late | A false light/radar contact that leads you somewhere fatal | 6 | ⚠️ | meshy |

## E. Encounter-scale threats — 2

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Ghost ship | Mid–Late | A POI that hunts; dread more than damage | 5 + vessel | ⚠️ | meshy |
| Mimic island | Rare | You landed on it. Escape event | 8 | ⚠️ | meshy |

## F. Bosses — 2

| Enemy | Stage | What it breaks | Anims | GB | Source |
|---|---|---|---|---|---|
| Kraken | Boss | Multi-stage: tentacles per side, targets generator, then hull | 14 | ❌ | meshy |
| Abyss Leviathan | Endgame | Not a fight — an escape. Outrun or die | 12 | ❌ | meshy |

Bosses are ❌ for graybox not because a placeholder is impossible but because their whole point is
spectacle and readability — a grey blob teaches nothing about whether the fight works.

## G. Enemy groups — 12 definitions

The user asked specifically about groups. A group is a spawn unit with shared aggro and arrival timing, so
enemies arrive *as a threat* rather than trickling in single file.

| Group | Composition | Behaviour |
|---|---|---|
| Crab cluster | 2–3 giant crabs | Shared leash; arrive together, guard a loot point |
| Barracuda shoal | 6–10 barracuda | Move as one volume; disperse when hurt |
| Shark pair | 2 sharks | Circle, alternate passes |
| Pirate landing party | 3–5 pirates + 1 skiff | Skiff delivers, then covers; they retreat to it |
| Pirate boarding wave | 4–6 boarding pirates | Grapple in waves; second wave while the first is fought |
| Gunboat escort | 1 gunboat + 2 skiffs | Skiffs screen the gunboat |
| Drowned tide | 4–8 drowned | Surface on a timer along the waterline; night only |
| Drowned crew | 3–5 drowned | A specific wreck's former crew; tied to a POI |
| Serpent + shoal | 1 serpent + barracuda | The shoal drives you into the serpent |
| Tentacle set | 3–6 tentacles | One creature, several targets; per-limb health |
| Siren + drowned | 1 siren + 3 drowned | Siren misleads, drowned intercept |
| Kraken phases | Tentacles → head → enraged | Not a group so much as scripted stages |

## H. Systems — 16 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Enemy definition registry | One place per enemy: stats, anims, sounds, drops, spawn rules | ❌ | code |
| Spawn manager | Tag-driven spawning with pooling; respects stage and time of day | ❌ | code |
| Group spawn definitions | The table above, as data | ❌ | code |
| Shared aggro / leash | Group members alerting each other | ❌ | code |
| Detection model | Distance → radius overlap → line-of-sight raycast, in that cheap-to-expensive order | ❌ | code |
| Behaviour loop | Idle / patrol / chase / attack / retreat state machine | ❌ | code |
| Swimming movement | Humanoid-less movers for fish and creatures | ❌ | code |
| Deck pathfinding | Navigating a **moving** vessel — the hard one | ❌ | code |
| Boarding system | Grapple, climb, arrive, fight on a pitching deck | ❌ | code |
| System-attack behaviours | Target engine / radar / generator / cargo rather than players | ❌ | code |
| Theft behaviour | Take an item and *leave with it* | ❌ | code |
| Hull damage from creatures | Bites and rams producing breaches | ❌ | code |
| Per-limb damage | Tentacles, serpent segments | ❌ | code |
| Drop tables | What each enemy yields, feeding group 03 | ❌ | code |
| Enemy audio hooks | Growls, impacts, warning cues — positional | ❌ | code |
| Difficulty scaling | Stage and night number driving counts and stats, not just HP | ❌ | code |

---

## Suggested job split

1. **Enemy foundation** — H's registry, spawn manager, detection, behaviour loop, drop tables. Prove with
   the shark alone.
2. **The shark, properly** — one enemy end to end: mesh, rig, 6 animations, sounds, hull-bite behaviour.
   The reference every later enemy copies.
3. **Island wildlife** — crab, crocodile, barracuda shoal, plus group spawning.
4. **Pirates ashore** — pirate skiff and landing party; ranged combat and retreat.
5. **Boarding** — boarding pirates, the boarding system, deck pathfinding, theft. *The single most
   valuable job in this group.*
6. **Propeller & systems threats** — giant eel, hammerhead; system-attack behaviours.
7. **Supernatural tier 1** — drowned sailor, drowned tide, night behaviour.
8. **Navigation corruption** — siren, The Lure; radar interference. Pairs with feature 0002.
9. **Large creatures** — sea serpent, tentacle creature, per-limb damage.
10. **Ghost ship & mimic island** — encounter-shaped enemies; pairs with 04's rare POIs.
11. **Kraken** — the boss. Its own job.
12. **Abyss Leviathan** — the endgame escape. Its own job.

## Open questions

- **Deck pathfinding on a moving vessel.** Roblox pathfinding assumes a static navmesh. Boarders on a
  pitching deck may need a bespoke solution — investigate early, because boarding depends on it.
- **Do enemies persist between nights?** A wounded serpent that comes back would be memorable.
- **How much does night change existing enemies** versus introducing new ones? Reusing daytime enemies
  with night behaviour is far cheaper than new models.
- **Rig sharing.** Pirates, drowned sailors and NPC crew are all humanoids — one shared R15 rig with
  different clothing and animation sets would save an enormous amount of work. Confirm before job 4.
