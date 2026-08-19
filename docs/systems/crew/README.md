# NPC Crew System

## Goal

Allow small parties to operate larger vessels without making NPCs better than coordinated human players.

## Core roles

- Engineer
- Navigator
- Gunner
- Deckhand
- Medic
- Mechanic
- Lookout
- later Quartermaster/Cook if useful

## Behavior principle

NPCs physically perform tasks using the same world interaction concepts as players.

Example:

```text
Hull breach
→ Engineer runs to breach
→ aligns to interaction point
→ plays repair animation
→ performs validated repair
```

Do not represent crew work only as invisible stat bonuses.

## Priority model example

1. critical flooding
2. disabled engine
3. disabled generator
4. severe hull damage
5. radar failure
6. minor repairs

A human can make better contextual choices.

## Orders

Keep commands simple:
- AUTO
- REPAIR
- COMBAT
- ENGINE
- DEFEND DECK
- MAN GUN
- FOLLOW
- RETURN TO SHIP

## Ownership

Initial recommendation:
- expedition leader/captain provides the available NPC roster
- NPCs fill unused crew roles
- with six humans, NPCs may remain ashore unless the vessel supports extra crew

Potential future extension:
- allow other players to nominate one specialist NPC each

## NPC progression

NPC crew may have:
- level
- role
- traits
- cosmetic appearance
- injury/availability state

Avoid permanent death initially.

Possible traits:
- Storm Veteran
- Sharp Eyes
- Grease Monkey
- Ammo Saver
- Old Sailor
- Nervous

## Dialogue

Use authored event-driven lines for atmosphere:
- radar contacts
- generator problems
- storm warnings
- unknown sounds
- low fuel
- flooding
