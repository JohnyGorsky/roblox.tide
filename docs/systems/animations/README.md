# Animation System

## Goal

Basic tasks should visibly animate. Do not rely on generic idle poses plus progress bars.

## Player task animation set

Initial target:
- idle/walk/run/swim
- steering
- repair hull
- repair engine
- carry crate
- pick up/loot
- refuel
- mounted MG
- reload
- stumble
- fall
- get up
- manual pump
- revive
- climb ladder
- pull player aboard

## Storm reaction

- wider stance
- balancing
- lean against boat movement
- stumble
- grab railing
- fall/recover on special impacts

## Interaction points

Interactable objects should define alignment/targets where useful:

```text
InteractionPoint
- character position
- facing direction
- animation type
- left/right hand target
```

Use IK where practical for:
- wheel
- weapon grips
- repair tools
- handles

## Enemy minimum animation set

At minimum:
- idle
- movement
- attack
- hit reaction
- death

Larger enemies may need:
- surface
- dive
- grab
- slam
- retreat
- stunned
- special attack
