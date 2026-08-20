# 11 — Animations

**Group:** every animation in the game — the player's working set, storm reactions, and the per-enemy sets.
**Items:** ~44 player/shared clips + ~90 enemy clips + 9 system pieces
**Depends on:** 02 (stations to animate at). **Cross-cutting** — the player set is needed early.

Systems: [animations](../systems/animations/README.md) · `roblox-animation` skill ·
pair with the `roblox-chars` agent for Meshy rigs and Adaptive Animation

---

## The standard this group must meet

From the animation doc: **basic tasks must visibly animate. Do not rely on a generic idle pose plus a
progress bar.** A player repairing a hull breach should look like someone repairing a hull breach — that is
most of what makes the crew fantasy work, and it is what a progress bar cannot buy.

Interaction points declare, per station: character position, facing direction, animation, and left/right
hand IK targets. Use IK for the wheel, weapon grips, repair tools and handles so hands actually land on
geometry rather than near it.

---

## A. Player locomotion — 7 items

| Clip | Note |
|---|---|
| Idle | Plus a subtle sea-legs sway variant |
| Walk | On deck and ashore |
| Run | |
| Swim | Plus swim-idle (treading water) |
| Jump / fall | |
| Land | |
| Climb ladder | Boarding from water |

## B. Player task animations — 15 items

The heart of the group.

| Clip | Where it plays |
|---|---|
| Steer (wheel) | Helm; IK hands on the wheel, turning with input |
| Throttle adjust | Helm |
| Repair hull | At a breach; tool in hand |
| Repair engine | Engine bay, crouched |
| Repair generator | Power area |
| Manual pump | Sustained, tiring, two hands |
| Refuel | Jerry can into the filler |
| Pick up / loot | Container and floor variants |
| Carry crate | Locomotion override while carrying |
| Two-person carry | Synchronised with another player — the co-op moment |
| Man mounted MG | Sit/stand at the gun, traverse |
| Reload (mounted) | Ammo box swap |
| Revive | Kneeling over a downed crewmate |
| Pull player aboard | Hauling someone from the water |
| Operate radar | At the station, hand on the dial |

## C. Storm & motion reactions — 8 items

What makes the sea feel real without touching physics.

| Clip | Note |
|---|---|
| Wide stance | Rough-sea idle |
| Balance sway | Layered with the boat's roll |
| Lean into movement | Walking against pitch |
| Stumble | Triggered by a wave impact |
| Grab railing | Reflex on a hard hit |
| Fall (from impact) | Distinct from a normal fall |
| Get up | After a fall |
| Brace | Anticipating a big wave |

## D. Combat — 8 items

| Clip | Note |
|---|---|
| Hold (one-handed) | Revolver, flare gun |
| Hold (two-handed) | Rifle, shotgun, SMG |
| Hold (melee) | Machete |
| Fire (per family ×3) | Recoil differing by family |
| Melee swing | Plus a heavy variant |
| Reload (per family ×2) | |
| Hit reaction | Player taking damage |
| Downed / crawl | The downed state before revive or death |

## E. Emotes & misc — 6 items

| Clip | Note |
|---|---|
| Point | Crew communication without voice |
| Wave | |
| Sit | Benches, bunks |
| Shiver / cold | Atmosphere in later stages |
| Look through binoculars | Contextual first-person pose |
| Celebrate | End of run |

## F. Enemy animation sets — ~90 clips

Five clips minimum per enemy (idle, move, attack, hit, death); large creatures need up to 14. Across the
18 enemies in group 05 that is roughly 90 clips. They are listed per enemy there rather than duplicated
here.

## G. NPC crew — reuse, don't rebuild

NPC crew should use the **same clips as players** (section B especially). If crew and players share a
humanoid R15 rig, the crew animation cost is close to zero — which is the single biggest saving available
in this group. Confirm the shared-rig decision before commissioning any crew-specific work.

## H. Systems — 9 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Animation registry | One place mapping ids to assets, with priorities | ❌ | code |
| Priority & blending | AnimationPriority so a task overrides locomotion cleanly | ❌ | code |
| Interaction point spec | Position, facing, clip, hand IK targets per station | ❌ | code |
| IK control setup | IKControl for wheel, grips, tools, handles | ❌ | code |
| Sea-motion layer | Additive sway driven by the boat's actual pitch and roll | ❌ | code |
| Task animation driver | Start, loop, interrupt, complete, and *validate* the action | ❌ | code |
| Two-person sync | Keeping a shared carry in step across clients | ❌ | code |
| Custom rig support | Adaptive Animation for imported Meshy creatures | ❌ | code |
| Animation upload pipeline | Publishing clips and recording ids in the registry | ❌ | code |

⚠️ Publishing animations and supplying asset ids is a human step — Claude writes the code and the
checklist, the human uploads.

---

## Suggested job split

1. **Animation foundation** — H's registry, priority/blending, interaction point spec, IK. Prove with one
   clip: repair hull.
2. **Player task set** — B. Feature 0007. *The highest-value job in this group.*
3. **Locomotion & swim** — A, including the sea-legs variants.
4. **Sea-motion layer** — C plus the additive sway driven by real boat motion. Needs group 02 floating.
5. **Combat set** — D; pairs with group 06.
6. **Two-person carry** — the sync problem; pairs with group 03.
7. **Emotes & misc** — E. Cheap character.
8. **Enemy sets** — one job per enemy tier, following group 05's order.

## Open questions

- **Buy or author?** Roblox's animation library and marketplace packs could cover locomotion cheaply; task
  animations almost certainly must be authored. Decide per section before job 2.
- ~~Is the shared humanoid rig confirmed?~~ **Decided: yes** — one R15 skeleton for players, crew,
  pirates and drowned, decision [0015](../decisions/0015-shared-humanoid-rig.md). The clip counts in this
  group assume it, and crew reuse the player task set.
- **How much does the sea-motion layer cost** on mobile, with several characters swaying additively?
  Measure before committing to it everywhere.
- **Do we need first-person arm animations** for the contextual first-person modes, or is the third-person
  body enough?
