# Job #004: Configure the settings baseline for both places

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:55:21
**Status**: Requirements Gathering (intake)

## Requirements / goal

First real game job (001-003 were repo scaffolding). Both places are stock Roblox defaults today, measured over MCP: StreamingEnabled=true, Gravity=196.2, FallenPartsDestroyHeight=-500, MaxPlayers=60, PreferredPlayers=60, RespawnTime=3, CharacterAutoLoads=true, ClockTime=14.5, Brightness=3, GlobalShadows=true, FogEnd=100000, Terrain water at the default teal with WaterWaveSize=0.15 and WaterWaveSpeed=10, StarterGui.ScreenOrientation=Sensor, CameraMaxZoomDistance=128, DevTouchMovementMode=UserChoice, HttpService.HttpEnabled=false. Each place contains only a Baseplate, SpawnLocation, Terrain, Camera, and the default Lighting set (Sky, Atmosphere, SunRays, Bloom, DepthOfField). Already correct and needing no change: Studio access to API services is ENABLED in both places, so DataStore work can be tested. Goal: agree and apply the configuration baseline that later work cannot cheaply retrofit - crew size, streaming strategy per place, who owns death/respawn, mobile orientation, the ocean water and lighting baseline - and make it reproducible rather than hand-clicked, because place settings live in the .rbxl and are invisible to git. Settings that are NotScriptable (for example Lighting.Technology) or experience-level (Creator Hub) become an explicit human checklist.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
