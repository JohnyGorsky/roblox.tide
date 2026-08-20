# 0015 — One shared humanoid R15 rig

Status: Accepted

## Decision

Players, NPC crew, pirates and drowned sailors all use the **same R15 skeleton**. Clothing, materials,
proportion tweaks within the rig, and separate animation sets do the differentiating.

## Why

NPC crew must physically perform tasks (decision [0010](0010-npc-crew.md)) — repair, steer, man a gun,
carry cargo. Those are the same actions players perform. On a shared rig the crew reuse the player task
animation set essentially for free.

This is the single largest saving available in the project. It removes roughly a third of the animation
work in manifest group [11](../build/11-animations.md), and it compounds: every new task animation authored
for players immediately works for crew and for humanoid enemies.

The alternative — a separate skeleton for the drowned so they read as genuinely inhuman — is a real
artistic loss, accepted on the grounds that movement style, shading and audio can carry most of that
difference at a fraction of the cost.

## Consequences

- The rig is decided **before** any humanoid is commissioned. Retrofitting a shared rig after several
  bespoke characters exist is expensive.
- Wrongness in the drowned must come from **animation, shading and sound**, not skeleton proportions. If
  that proves insufficient in play, revisit with a new decision rather than quietly adding a rig.
- Meshy generation and rigging must target this one skeleton — see the `roblox-chars` agent and the
  `meshy` skill.
- Groups [05](../build/05-enemies.md), [10](../build/10-crew.md) and
  [11](../build/11-animations.md) all depend on this.
