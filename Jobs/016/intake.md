# Job #016: Day/night cycle with severity-based weather composition

**Project**: `roblox.tide`
**Created**: 2026-08-20 14:17:56
**Status**: Requirements Gathering (intake)

## Requirements / goal

Group 07 job 1, and the next P0 task after the sea. Build the server-authoritative phase clock - dawn 30-45s, day 4-5min, dusk ~45s, night 3-4min, a ~9-10 minute cycle giving a ~28 minute three-cycle expedition - plus the composition rule from decision 0018 that stops day/night and sea state fighting over Lighting. Time of day sets the baseline light, sky, ambient, fog and atmosphere; each sea state carries a severity from 0 to 1 and its values are blended over that base by that amount, so a calm night still looks like night while The Wall is identical at noon and midnight. The sky switches rather than blends, since six discrete image ids cannot mix. Critically this means NOTHING may write Lighting except the composer - a system that sets FogEnd on its own gets overwritten next tick and the bug presents as a flicker rather than as a conflict, so SeaStates.apply has to stop touching Lighting directly and hand its values to the composer instead. Clock state goes on Workspace attributes like the wave field, for the same reason: each context gets its own module copy, so a local phase variable would let server and clients disagree about what time it is.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
