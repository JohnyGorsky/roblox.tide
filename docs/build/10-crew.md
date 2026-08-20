# 10 — NPC crew

**Group:** the AI crew who fill empty roles so a small party can sail a big ship, without making human
players redundant.
**Items:** ~40
**Depends on:** 02 (stations to work at), 11 (animations to work with), 05 (the AI foundation is shared).

Systems: [crew](../systems/crew/README.md) · [crew catalog](../content/crew.md) ·
decision [0010](../decisions/0010-npc-crew.md) · `roblox-ai` skill

---

## The line this group must not cross

Decision 0010: NPCs **fill unused roles**; they are useful and predictable, but a skilled human is better
at prioritising and coordinating. If an NPC engineer outperforms a human engineer, the co-op game is dead.

The way to keep that true: NPCs are **competent at execution, poor at judgement**. They will repair the
breach they are told about, correctly and reliably. They will not notice that the generator matters more
right now, or that the storm makes the whole repair pointless.

And critically — from the crew doc — **NPC work is physical**. An NPC who repairs must walk to the breach,
align to the interaction point, play the animation and effect a validated repair. Invisible stat bonuses
are explicitly not acceptable; a crew you cannot see working is not a crew.

---

## A. Roles — 7 items

| Role | Does | Would break if absent |
|---|---|---|
| Engineer | Repairs hull, engine, generator | Damage accumulates unattended |
| Navigator | Reads radar, calls contacts | You sail blind |
| Gunner | Mans a hardpoint | Nothing shoots back |
| Deckhand | Cargo, leaks, reload support | Small jobs pile up |
| Medic | Heals and revives | A downed player stays down |
| Mechanic | Mechanical specialisation, deeper repairs | Complex failures go unfixed |
| Lookout | Spots POIs and threats visually | You miss things radar cannot see |

Later, if useful: Quartermaster, Cook.

## B. Behaviour — 14 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Crew AI foundation | Shared with the enemy behaviour loop from group 05 | ❌ | code |
| Task queue | What needs doing aboard, prioritised | ❌ | code |
| Priority model | Flooding > engine > generator > hull > radar > minor | ❌ | code |
| Interaction point alignment | Walk to, face correctly, hand IK onto the tool | ❌ | code |
| Deck navigation | Pathfinding on a **moving, pitching** vessel — the hard problem, shared with boarding | ❌ | code |
| Task execution | Play the animation and *actually* perform the validated action | ❌ | code |
| Task interruption | Stop when something more urgent happens, resume sensibly | ❌ | code |
| Station occupancy | Two crew must not fight over one wheel | ❌ | code |
| Order system | AUTO / REPAIR / COMBAT / ENGINE / DEFEND DECK / MAN GUN / FOLLOW / RETURN TO SHIP | ❌ | code |
| Order UI | Issuing orders without a menu maze; must work on touch | ⚠️ | code |
| Combat behaviour | Firing a mounted weapon, defending the deck, taking cover | ❌ | code |
| Downed / injured state | NPCs can be hurt and need help; **no permadeath initially** | ❌ | code |
| Going ashore | Whether and how NPCs leave the boat | ❌ | code |
| Idle life | Doing something plausible when there is nothing to do | ❌ | code |

## C. Character & identity — 10 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Crew rig | **Share the humanoid R15 rig** with pirates and drowned — huge saving | ⚠️ | meshy |
| Role outfits | 7 visually distinct working outfits | ⚠️ | meshy |
| Face/head variation | So the crew are individuals, not clones | ⚠️ | meshy |
| Name generation | Plausible maritime names | ❌ | code |
| Level & progression | Crew improve across expeditions | ❌ | code |
| Traits | Storm Veteran, Sharp Eyes, Grease Monkey, Ammo Saver, Old Sailor, Nervous | ❌ | code |
| Trait effects | Small, legible modifiers — never a replacement for a human | ❌ | code |
| Cosmetics | Uniforms, hats, themes (a monetization surface) | ⚠️ | meshy |
| Availability state | Injured crew unavailable for a run or two | ❌ | code |
| Roster persistence | Owned crew saved per account | ❌ | code |

## D. Dialogue & presence — 9 items

Authored, event-driven lines. This is what makes a crew feel alive for very little cost.

| Item | What it is | GB | Source |
|---|---|---|---|
| Line trigger system | Event → eligible lines → pick, with cooldowns | ❌ | code |
| Radar contact lines | "Contact, bearing zero-four-seven." | ⚠️ | sound |
| Damage & repair lines | "Taking water in the aft compartment." | ⚠️ | sound |
| Generator/power lines | "We can't run radar and pumps both." | ⚠️ | sound |
| Storm lines | Rising alarm as it closes | ⚠️ | sound |
| Low fuel lines | The nag that saves runs | ⚠️ | sound |
| Unknown-sound lines | Dread. The most valuable category | ⚠️ | sound |
| Trait-flavoured variants | Nervous crew say it differently to a veteran | ⚠️ | sound |
| Subtitles | Accessibility, and readable on mute | ❌ | code |

---

## Suggested job split

1. **Crew foundation** — B's task queue, priority model, interaction alignment, deck navigation. One
   Engineer NPC that repairs one breach, properly. Feature 0009.
2. **Deck navigation** — if it proves hard (likely), its own job. Shared with boarding in group 05.
3. **Core roles** — Navigator, Gunner, Deckhand, using the foundation.
4. **Medic & revive** — pairs with the downed/death model from group 02/09.
5. **Orders** — the order set and its touch-friendly UI.
6. **Crew identity** — C's rig, outfits, names, traits.
7. **Dialogue** — D. Cheap, and transformative for atmosphere.
8. **Crew progression & roster** — levels, injury, persistence; pairs with group 08.

## Open questions

- **Who supplies the crew?** The crew doc's initial recommendation is the captain provides the roster. An
  alternative lets each player nominate one specialist. The second is fairer and more work.
- **With six humans, what happens to the NPCs?** Stay ashore, or does a big ship support extra hands?
- **Do NPCs go ashore to loot?** Very useful, and it means island pathfinding and carry behaviour too.
- **How smart is too smart?** Needs a concrete rule — e.g. NPCs react only to *reported* problems and
  never anticipate — or the "humans are better" promise will erode feature by feature.
