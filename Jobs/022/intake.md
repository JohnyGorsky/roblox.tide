# Job #022: The storm's teeth: hull damage and system faults inside The Wall

**Project**: `roblox.tide`
**Created**: 2026-08-21 00:14:49
**Status**: Requirements Gathering (intake)

## Requirements / goal

Implement decision 0014 — entering the storm front inflicts escalating consequences rather than instant failure.

Scope:
1. Hull integrity on the vessel: a damage pool that mounts the longer the vessel is inside The Wall, steep enough that lingering is never a shortcut. Vessel loss has a defined outcome.
2. Forced system faults escalating with exposure: engine cut, radar loss, hull breach, generator trouble. Each must be something the crew can act on.
3. Tuned so a competent crew escapes in roughly 30-60 seconds and a slow one does not; not survivable indefinitely.
4. The Wall is a blind-navigation state: fog closes at ~330 studs, no visual heading cue. The HUD must never show a heading. Self-lit compass/chart readable in darkness (diegetic instrument, group 02).
5. Admin panel tools to drive it: force exposure, inflict a named fault, repair all, report hull integrity.

Hard constraints:
- Every force on the vessel stays RelativeTo = World with an explicitly aimed direction (finding 0019).
- Nothing tuned per hull: derive from the spec's statements of intent plus the hull's own mass/inertia (decision 0009).
- Server-authoritative damage and faults; client only renders.
- The 5-minute storm arrival timing must not change.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation written — analyzer-clean, arithmetic checked, **not yet run** (Studio Sync was down
      for the whole job, finding 0007)
- [ ] Verified in a session — `Storm → Survival test`, both modes. This is what the job is answerable to
- [ ] Final summary + changelog written (held until it has ticked)
