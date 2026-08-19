# Island System

## Decision

Major islands should be **curated templates**, not uncontrolled runtime procedural terrain.

Procedural generation may be used during development to produce candidates, which are then selected and manually improved.

## Island Forge workflow

```text
generate candidate
→ reject or keep
→ sculpt/fix
→ add rocks/trees/buildings
→ add gameplay markers
→ save approved template
```

## Template concept

Each island should have:

- terrain snapshot/region
- object model collection
- metadata
- dock points
- loot points
- enemy spawn points
- POI markers
- difficulty/stage tags
- encounter weights

## Runtime

```text
choose approved template
→ paste terrain / clone props
→ choose encounter variant
→ spawn loot
→ spawn enemies/events
```

## Variation

Reuse terrain with different states:
- pirates
- abandoned
- trader
- drowned enemies
- storm damaged
- rare loot
- nighttime variant

## Global water

Prefer a shared/global ocean. Island templates should primarily contribute land/materials and their local props.
