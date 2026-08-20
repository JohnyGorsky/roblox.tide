# Job #018: Finish the storm's presence: time scale, lightning, cloud wall, audio

**Project**: `roblox.tide`
**Created**: 2026-08-20 14:42:16
**Status**: ✅ Completed

## Requirements / goal

Group 07's remaining pieces, chosen over the boat so the storm is finished before moving on. Four parts. (1) TIME SCALE first, because it is a testing gap that blocks judging everything else: the panel's distance buttons jump the front instantly, so what a tester sees is five separate looks rather than an approach, and watching the real thing close 4200 studs at 14 studs/s takes five real minutes. A speed multiplier lets the approach be watched compressed, which is the only way to judge whether the escalation actually builds. (2) LIGHTNING: server-authoritative strike events with position, intensity and timing, clients rendering bolt, sky flash, delayed thunder and camera response, plus the rare gameplay effects the storm doc lists - radar disruption, generator surge, system fault. Needs no assets. (3) CLOUD WALL: the biggest missing piece of the approach, because right now nothing is visibly coming. Needs art, so it follows the same source-scan-approve flow as the skies. (4) AUDIO: rumble, wind and rain tracking the same wind value the visuals use - the storm doc argues sound carries more dread than visuals, and a rising rumble astern is more frightening than a cloud. Needs sourcing and licensing per clip.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed — **plus** everyday weather (decision 0020, added mid-job by the user), the
      missing Terrain-water writer, the never-started client, and a smoothness pass
- [x] Final summary + changelog written

**Not delivered:** the rain and thunder clips (the user is sourcing them; spec in
`roblox.workspace/Assets/registry/audio.md`) and screen-level rain streaks. Thunder *timing* is live and
testable without a clip.
