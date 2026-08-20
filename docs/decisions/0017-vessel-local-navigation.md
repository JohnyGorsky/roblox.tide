# 0017 — NPCs navigate the vessel in its own local space

Status: Accepted

## Decision

Every vessel carries a **hand-authored waypoint graph** attached to its hull — nodes at the helm, engine
bay, generator, each hardpoint, the ladder, the deck junctions — and NPCs move node to node in the
**vessel's local space**.

Roblox `PathfindingService` is not used aboard a vessel. It may still be used ashore, where the ground
really is static.

## Why

Roblox pathfinding assumes a static navmesh. A vessel is a moving, pitching, rolling platform, so a
computed path is stale the instant it is produced — the failure mode is NPCs lagging the deck and walking
off into the sea.

Navigating in local space makes the vessel's motion **structurally irrelevant** rather than something to
compensate for: the graph moves with the hull because it is part of the hull.

It also composes with the architecture already chosen. Decision
[0009](0009-vessel-class-architecture.md) gives every vessel a socket layout, and a nav node beside each
socket is a natural extension of the same authored data.

## Consequences

- **One graph per vessel class**, authored alongside its socket layout. Seven vessels means seven graphs —
  accepted, because they are small and they double as the station list.
- Boarding enemies use the same graph, so [05](../build/05-enemies.md)'s boarding work and
  [10](../build/10-crew.md)'s crew work share this foundation. **Build it once.**
- Interiors on the larger vessels are just more nodes and links, not a new system — which is what makes
  the Expedition Ship tractable.
- Node positions must be validated against the actual walkable deck, or NPCs will confidently walk through
  railings.
- Ashore, normal pathfinding applies; the two systems meet at the gangway or ladder node.
