# Assets

## Asset sources

- Meshy for generated 3D concepts/models
- Roblox Studio for final import/hierarchy/configuration
- Custom/manual modeling where Meshy output is insufficient

## Asset status source

`registry/assets.yaml`

## Asset lifecycle

```text
IDEA
→ PROMPT_READY
→ GENERATED
→ CLEANUP
→ IMPORTED
→ INTEGRATED
→ VERIFIED
```

For animated/mechanical assets, ensure important moving pieces are separable before import.

## Graybox placeholders

A graybox is a grey block standing in for real art so the game can be played through before the art
exists. The danger is forgetting what it was standing in for. So every placeholder is recorded **twice**,
and the two are diffed:

**1. In this registry** — an entry with `status: GRAYBOX` and a `represents:` field naming the real asset
it will become:

```yaml
- id: GB-BOAT-HULL
  type: graybox
  status: GRAYBOX
  represents: ASSET-BOAT-STARTER
  place: game
  roblox_path: Workspace.Vessels.StarterBoat.Hull
  notes: 20 x 8 x 4 grey block, correct mass and buoyancy volume. Silhouette only.
```

`represents` is mandatory. A graybox without it is a mystery block, which is the exact failure this
convention exists to prevent. If it stands in for something not yet in the registry, add the real asset
as `status: IDEA` first and point at it.

**2. In Studio** — tag the instance `Graybox` via CollectionService:

```lua
game:GetService("CollectionService"):AddTag(instance, "Graybox")
```

**Then diff them.** [`tools/audit-graybox.luau`](../tools/audit-graybox.luau), run over MCP, reports:

| | |
|---|---|
| `TRACKED` | tagged in Studio and registered here — good |
| `UNTRACKED` | tagged in Studio, missing from the registry — **someone forgot** |
| `UNTAGGED?` | suspicious grey/placeholder-looking parts with no tag — candidates to tag |
| `MISSING` | registered here, absent from the place — either stale or not built yet |

Registry-only tracking relies on memory; the tag scan catches what memory misses.

**Replacing one:** build the real asset, swap it in, delete the `GB-` entry, and move the real asset
along its own lifecycle. The graybox entry disappearing *is* the record that it was replaced — the job
`final-summary.md` carries the detail.

**Sizing matters more than looks.** A graybox that is the wrong size teaches the wrong thing about
sightlines, collision and deck space. Record intended dimensions in `notes` and match them.

