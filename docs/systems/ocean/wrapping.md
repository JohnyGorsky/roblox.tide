# World Wrapping

## Horizontal wrap

Treat the ocean as cylindrical:

```text
left edge  <------>  right edge
          progress north
```

Crossing one horizontal boundary repositions the boat to the opposite side while logical longitude continues.

## Logical position

Keep logical coordinates separate from physical Roblox coordinates.

Example data:

```text
physical_x
physical_z
logical_longitude
logical_distance
sea_stage
sector_seed
```

Gameplay progression, POI generation, achievements and storm progress should use logical progression rather than recycled coordinates.

## Forward progression

Do not visibly wrap north → south with identical content.

Instead:
1. detect progression boundary
2. advance sea stage/sector
3. reposition/recycle behind visual cover if necessary
4. populate new approved POIs
5. change weather/lighting/content pool

Possible transition covers:
- heavy fog
- storm curtain
- night
- giant wave
- narrow rock passage/current
