# Job #025: The lobby's atmosphere: a harbour sky, a calm sea, and a storm that never arrives

**Project**: `roblox.tide`
**Created**: 2026-08-21 22:26:54
**Status**: Requirements Gathering (intake)

## Requirements / goal

Promoted from Planned 0002 (its Phase A) at the user's request on 2026-08-21: 'one thing we need to copy all atmospheric clouds lightning etc to this lobby'.

Delivered:
1. Twelve shared modules copied into studio_lobby/ReplicatedStorage - SeaStates, WaveField, SkyLibrary, LocalWeather, DayNight, StormVFX, CloudWallVFX, Lightning, LightningVFX, AudioBed, StormAudio, Ambience - plus the generic WeatherClient and LightningServer, all byte-identical to the game's.
2. tools/check-shared-parity.py, written BEFORE the copying rather than after. Roblox has no cross-place ReplicatedStorage, so every shared module now exists twice with nothing in the engine, the sync tool or git to notice when they drift - which is exactly how the lobby's AdminTools fell 12,234 bytes behind during job 022 without anyone noticing for a whole job. 18 files tracked; --fix copies game -> lobby, never the reverse.
3. studio_lobby/ServerScriptService/LobbyWorld.server.luau - paints a static storm on the horizon and drives the day/night composer.

The key design decision: STORMFRONT IS DELIBERATELY NOT COPIED. The original plan was to ship it with its advance gated off, but every sensory system (cloud wall, rain, lightning, audio) reads Workspace ATTRIBUTES rather than the module - so the lobby sets those statically and never ships the clock at all. 'The storm never arrives' becomes true by construction rather than by a flag somebody could flip: there is no advance function in the place to call by accident.

The second decision: the sea is pinned SEPARATELY from the storm. In the game place one number drives everything - distance picks a band, the band picks a sea state - and that coupling cannot express what the lobby wants, because a distance close enough to draw a cloud wall also selects a Storm sea. So distance 1000 (places the wall, arms the lightning at intensity 2), wind 0.12 (LOW - wind drives rain, and a rainy harbour is not 'storm in the distance'), and SeaOverride LightSwell for calm water. Only possible because job 020 separated the sea override from the storm's own bookkeeping.

Measured in a live session: the painted distance does not drift at all over 15 s; wave height swings 1.42 studs (calm); fog 900 stays inside the lobby's ~1022-stud water half-extent so there is no visible map edge; lightning armed and firing with thunder logged at 394 and 523 studs; audio and ambience started with all channels filled; 49 admin tools valid.

STILL OPEN - the finding this job produced: the lobby's atmosphere reads flat and hazy rather than dramatic, and the cause is structural rather than a tuning miss. Its water patch is only ~2044 studs across against the game's 6144 x 6500, and the job-007 rule forces fog inside the water - so fog is capped at 900, which washes out any horizon drama including the storm wall it exists to show. Getting the 'same endless sea' the user originally asked for means growing the lobby's ocean the way decision 0025 grew the game's. That is the next step, and it is a saved-place change.

Out of scope, still in Planned 0002: the party pads, the departure teleport, the return, and the run summary panel.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
