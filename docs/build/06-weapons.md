# 06 — Weapons

**Group:** 16 hand weapons and 3 mounted weapons, built so each solves a *different problem* rather than
forming a damage ladder.
**Items:** 19 weapons + 14 system pieces + ~12 ammo/VFX assets
**Depends on:** 05 (targets), 02 section I (hardpoints for the mounted ones), 11 (hold/fire animations).

Systems: [combat](../systems/combat/README.md) · [weapon catalog](../content/weapons.md) ·
[avatar/tools](../../.claude/skills) → `roblox-avatar` for Tool setup

---

## The rule

From the combat doc: **weapons solve problems, they do not rank.** A pump shotgun is not "better" than a
flare gun; it is the answer to a different question. Ammo scarcity is what keeps that true — an
unlimited-ammo shooter collapses every weapon into damage-per-second.

The **signature trio** the game should be known for: **mounted MG, harpoon, flare gun.** If only three
weapons ever feel great, make them these.

---

## A. Starting weapons — 4

| Weapon | Solves | GB | Source |
|---|---|---|---|
| Machete | Melee, cutting rope/scrub/nets, island utility | ✅ | meshy |
| Flare gun | **Light, signalling, creature reaction.** Not really a gun | ⚠️ | meshy |
| Old revolver | A last resort; deliberately weak | ✅ | meshy |
| Double-barrel shotgun | Boarding defence at contact range | ⚠️ | meshy |

## B. Early–mid — 4

| Weapon | Solves | GB | Source |
|---|---|---|---|
| Pump shotgun | Sustained close defence | ✅ | meshy |
| Hunting rifle | Targets ashore, from the boat | ⚠️ | meshy |
| Harpoon | **Large creatures + utility** (tethering, hauling) | ⚠️ | meshy |
| Grenades / dynamite | Groups, and blowing open wreck sections | ✅ | meshy |

## C. Mid–late — 5

| Weapon | Solves | GB | Source |
|---|---|---|---|
| SMG | Mobile human combat on deck | ✅ | meshy |
| Military rifle | The general-purpose mid/late answer | ✅ | meshy |
| Heavy harpoon | Bigger creatures; slower | ✅ | meshy |
| Electric harpoon | Supernatural targets; costs generator power | ⚠️ | meshy |
| Experimental arc weapon | Late supernatural defence; strange | ⚠️ | meshy |

## D. Mounted — 3

These are crew stations as much as weapons.

| Weapon | Solves | GB | Source |
|---|---|---|---|
| Mounted MG | Swarms, skiffs, boarders. Traverse limits matter | ⚠️ | meshy |
| Heavy MG | Armoured targets, gunboats | ⚠️ | meshy |
| Depth charges | **Underwater threats** — nothing else answers them | ⚠️ | meshy |

## E. Support — 3

| Weapon | Solves | GB | Source |
|---|---|---|---|
| Searchlight (as a weapon) | Repels selected creatures; blinds boarders | ⚠️ | studio |
| Fire extinguisher | Generator fires; improvised melee | ✅ | meshy |
| Anti-creature light | Late; area denial | ⚠️ | studio |

## F. Systems — 14 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Weapon definition registry | Per weapon: damage, ammo type, fire mode, anims, sounds, VFX | ❌ | code |
| Tool equip/unequip | Backpack, StarterGear, hotbar | ❌ | code |
| **Server-authoritative hit validation** | Client requests, server decides. Never trust a reported hit | ❌ | code |
| Ammo model | Types, reserves, reloading, per-weapon scarcity | ❌ | code |
| Recoil & spread | Worse on a pitching deck — sea state affecting accuracy | ❌ | code |
| Mounted weapon station | Enter, aim within traverse limits, fire, exit | ❌ | code |
| Contextual first-person | For sights and mounted guns (decision 0001) | ❌ | code |
| Harpoon tether physics | Rope constraint to a creature or object; the utility half | ❌ | code |
| Depth-charge mechanics | Drop, sink, timed detonation, underwater damage volume | ❌ | code |
| Weak-point damage | Per-limb and per-component targeting | ❌ | code |
| Flare mechanics | Arc, burn duration, light source, creature reaction | ❌ | code |
| Weapon condition | Jams and damage as repair tasks, not just downtime | ❌ | code |
| Muzzle flash / tracer / impact VFX | ~9 assets across weapon families | ⚠️ | studio |
| Weapon audio set | Fire, reload, dry-fire, impact per family (~12 sounds) | ⚠️ | sound |

---

## Suggested job split

1. **Weapon foundation** — F's registry, equip, server-authoritative hits, ammo. Prove with the machete
   and revolver.
2. **The signature trio** — flare gun, harpoon (with tether), mounted MG. *Highest value in the group.*
3. **Boarding defence** — both shotguns, recoil/spread including the sea-state effect.
4. **Ranged** — hunting rifle, military rifle, SMG, contextual first-person sights.
5. **Anti-underwater** — depth charges; pairs with the eel and serpent.
6. **Heavy & experimental** — heavy MG, heavy/electric harpoon, arc weapon, power draw.
7. **Support & utility** — searchlight-as-weapon, extinguisher, anti-creature light.
8. **Feedback pass** — VFX and audio across all families.

## Open questions

- **Is there a melee combat system at all**, or is the machete a tool that happens to hurt? Full melee
  (blocking, stamina) is a large system; a swing-with-damage is small.
- **Does aiming use the mouse/touch reticle or a shoulder-aim mode?** Decides the camera work in 09.
- **How does a touch player aim a mounted MG?** Must be designed for thumbs from the start, not retrofitted.
- **Ammo types: how many?** Every distinct type is another loot entry, another UI row, another scarcity
  curve. Fewer is almost certainly better.
