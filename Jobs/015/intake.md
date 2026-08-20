# Job #015: Source and vet overcast/storm skies

**Project**: `roblox.tide`
**Created**: 2026-08-20 13:47:06
**Status**: Requirements Gathering (intake)

## Requirements / goal

Finding 0006 is the ceiling on the whole sea look: job 007 proved neither Fog nor Atmosphere can make Roblox's clear-day sky overcast, so the art direction is unreachable without real sky assets. Checked our own inventory and both registries first per the asset policy - nothing. Creator Store search surfaced mostly farm-grade junk: several results shared identical boilerplate descriptions with enormous keyword-stuffed tag lists, one title appeared under two different creator names (re-upload farming), and searching the word 'atmosphere' pulled bank-heist script packs with 'Script' literally in the name. Seven candidates presented and approved by the user: Fog on the water 15876671760, Angry Heavens Sky 2670935816, Black Skybox 582303304, Night Fog Skybox 1864839162, Sunless Blue Sky 591067775, Snow Skybox 4604073339, Classic Roblox Sky 339406852. Note that no true flat-grey overcast exists free in the store, so the day end may still need commissioning. Every asset goes into an isolated ServerStorage quarantine, gets scanned for scripts before anything runs, and has every non-authored LuaSourceContainer deleted - a precedent exists in the shared registry where a nature pack was rejected for shipping a script called CoreSkyboxSystem, so skybox-adjacent Models demonstrably do carry code.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
