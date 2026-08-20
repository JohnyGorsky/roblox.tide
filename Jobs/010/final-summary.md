# Final Summary — Job #010

**Project**: `roblox.tide`
**Completed**: 2026-08-20 10:29:37
**Status**: ✅ Completed

## What was implemented

The lobby is now a sheltered harbour and both places are free of the default baseplate. Filled 4096x4096 studs of water over a sand seabed at -48..-40 in 16 tile pairs with no failures, verified by voxel read-back at three points (sand -46..-42, water -38..-2, air above, nothing past 2048). Deliberately unlike the open sea: shallower, Storm Teal rather than Deep Ocean, transparency 0.42 so the bottom shows, and wave size 0.06 against the ocean's 0.18, so the lobby reads as a bay rather than the sea. THE GRAYBOX REGISTER WORKED END TO END for the first time: GB_SpawnDock exists because CharacterAutoLoads is true in the lobby and removing the baseplate would otherwise drop every joining player into the water, so it was built as a 64x4x40 slab, tagged Graybox with attribute GrayboxId=GB-LOBBY-DOCK, entered in assets.yaml with represents=ASSET-LOBBY-HARBOUR-DOCK, and added to tools/audit-graybox.luau - the audit then reported 1 tracked, 0 untracked, which closes the last open verification item from job 005. TWO THINGS CAUGHT BY LOOKING RATHER THAN ASSUMING. First, the initial screenshot showed the dock floating in featureless grey with no water visible at all. Rather than assume Studio's Edit render quality (the obvious suspect, and what the roblox-studio skill warns about), I raycasted: the water was present and hit at Y=0 at every distance. The real cause was FogColor still being Roblox's default bright grey 192,192,192, which I had never set for the lobby - only FogEnd. Setting it to Cold Sea Mist from the palette, with FogStart 260 and FogEnd 1900, produced a correct harbour immediately. The lesson is that fog has TWO properties that matter and setting only the distance leaves the colour at a default that can erase the scene. Second, the fog-inside-the-water rule now has a second instance, so the settings baseline records it as a general constraint rather than a game-place quirk. Also confirmed: the harbour suffers the same clear-day sky problem as the ocean (finding 0006) - brighter is more forgivable for a safe lobby than for a storm sea, but it is still not the art direction. Camera released to Fixed and confirmed in a separate call, per the correction from the earlier camera bug.

### Files changed

_Docs and registry. The terrain, dock and lighting live in the `.rbxl`._

- `assets/registry/assets.yaml`
- `tools/audit-graybox.luau`
- `docs/systems/places/settings-baseline.md`

### ⚠️ Save both places

Everything built here is unsaved Edit-mode state, in **both** places. `Ctrl+S` in each.

### Still the same blocker

The harbour has the clear-day sky problem too (finding 0006). It matters less for a safe lobby than for a
storm sea, but it is still not the art direction.

## Verification

- [x] Voxel read-back at centre, near-edge and outside: sand −46…−42, water −38…−2, nothing past 2048
- [x] Baseplate gone from **both** places; `Workspace` now holds only Terrain, Camera, SpawnLocation, GB_SpawnDock
- [x] Graybox audit: **1 tracked, 0 untracked** — the register works end to end
- [x] Water confirmed present by raycast at 40, 120 and 400 studs before diagnosing the grey screen
- [x] Screenshot after the fog fix shows a correct harbour
- [x] Camera released to `Fixed` and re-confirmed in a separate call
- [ ] Judgement on the harbour look — **yours**
- [ ] Persisted — **requires saving both places**
