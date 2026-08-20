# Final Summary — Job #012

**Project**: `roblox.tide`
**Completed**: 2026-08-20 13:19:04
**Status**: ✅ Completed

## What was implemented

WaveField built and verified, the debug views built, and the admin panel's sea section rebuilt so one button moves both the look and the physics. VERIFIED: determinism identical across repeat calls; directionDeg on all five states with lerp interpolating it; out-of-bounds returns WATER_Y never nan; normals vertical in Dead Calm (y=1.00000) and tilted in The Wall (y=0.88); measured crest-to-trough 91-99% of amplitude x 2, the shortfall being finite-grid sampling not a normalisation error; 12 HeightAt calls cost 0.0126 ms, 0.08% of a 60fps frame. The admin panel now registers 16 tools and the panel was confirmed building EXACTLY ONCE in Play, which closes the .client.luau to .local.luau double-run fix from job 009. FOUR FINDINGS, all from looking rather than assuming. (0008) Roblox terrain-water waves exist ONLY in the shader: a raycast returns a flat plane at WATER_Y with 0.000000 spread across 450 studs, across time, and even at maximum WaterWaveSize. So exact calibration is impossible in principle, our field is the only non-flat truth, and critically auto-buoyancy will FIGHT a wave-field-driven hull because it pulls toward that flat plane - a direct warning now written onto group 02's buoyancy row. (0009) WaterWaveSize is capped at 1.0; The Wall asked for 1.4 and silently got 1.0, so the rendered water cannot look much rougher than Storm and the extra violence must come from the field, spray and shake. The panel's slider allowed 0..2 and now caps at 1. (0010) The sea colour ramp was non-monotonic - Choppy looked LIGHTER than Dead Calm. Caught by screenshotting two states back to back, then confirmed by computing luminances: 0.185, 0.185, 0.309, 0.106. Cause was using Storm Teal for a rough sea when it is the lightest of the three ocean colours and actually belongs to shallow sheltered water. Fixed to a monotonic 0.185, 0.185, 0.147, 0.106, 0.071, and visual-design.md now lists the ocean colours darkest-first with measured luminances and a note that a colour's name is not a guide to its place on a ramp. (0011, in job 009's file) reopening a place silently drops file sync, and MCP being connected says nothing about it. ARCHITECTURE CHANGE worth flagging: WaveField state moved out of module upvalues onto Workspace attributes. Each context gets its own copy of a module, so a local activeState meant the server and every client could believe in a different sea - which silently destroys the determinism the module exists for. Attributes are read by everyone, replicate for free, and survive a client joining mid-blend. THREE BUGS OF MY OWN, all caught by testing rather than review: showGrid began with hide() so it destroyed the ruler, which is exactly the pairing calibration needs (grid and ruler now have independent subfolders and clears); the ruler labelled only multiples of 5, useless for seas 1.6 studs tall (now every whole stud); and a Lua newline escape collapsed into a literal newline for the third time this session, leaving an unterminated string - the fix is to build escapes from chr(92) rather than writing them through a heredoc.

### Files changed

- `studio_game/ReplicatedStorage/WaveField.luau`
- `studio_game/ReplicatedStorage/WaveFieldDebug.luau`
- `studio_game/ReplicatedStorage/SeaStates.luau`
- `studio_game/ServerStorage/AdminTools.luau`
- `studio_lobby/ServerStorage/AdminTools.luau`
- `docs/features/0014-wave-field/feature.md`
- `docs/build/01-sea.md`
- `docs/build/02-boat-parts.md`
- `docs/game/visual-design.md`

### The Sea panel, as it now stands — 16 tools

| Tool | What it does |
|---|---|
| **Sea state** | Switches **look + wave field**, 4 s blend |
| **Sea state (snap)** | Same, no blend |
| **Cycle all states** | 6 s or 12 s each, plays the whole range as a progression |
| **Wave field markers** | show / show wide / hide — markers riding *our* field |
| **Height ruler** | ±3 or ±10 studs, red at 0, labels every whole stud |
| **What sea am I looking at?** | Spec vs measured, plus blend progress |
| Water / fog sliders | wave size (capped at 1), speed, reflectance, transparency, fog end |
| Atmosphere sliders | density, offset, haze, glare |
| Palette pickers | water, fog, atmosphere colour, atmosphere decay |
| Copy current as Luau | pasteable, including an `atmosphere` block |

**F4** or the **ADM** button, bottom-right.

### ⚠️ Two environment problems, not code

1. **Studio's Play wedges** after a stop/start cycle. It worked right after a Studio restart — long enough
   to confirm the panel builds once — then wedged again. Restarting Studio clears it.
2. **Reopening a place silently drops file sync** (finding 0007). MCP staying connected says nothing about
   it. Check `#Source` against the byte count on disk after any reopen.

## Verification

- [x] Determinism: identical for repeated `(x, z, t)`
- [x] `directionDeg` on all five states; `lerp` interpolates (8 → 22 gives 15)
- [x] State on Workspace attributes; blend tracked; `HeightAt` interpolates mid-blend
- [x] Out-of-bounds returns `WATER_Y`, never `nan`
- [x] Normals: y = 1.00000 in Dead Calm, 0.88 in The Wall
- [x] Cost: 12 `HeightAt` = 0.0126 ms (0.08% of a 60 fps frame)
- [x] 16 tools register; registry validates; superseded visuals-only tools removed
- [x] **Panel builds exactly once in Play** — closes job 009's `.local.luau` check
- [x] Colour ramp now monotonic: 0.185 / 0.185 / 0.147 / 0.106 / 0.071
- [x] No state exceeds the engine's `waveSize` cap of 1.0
- [x] Camera handed back to `Fixed`; sea left on Light Swell
- [ ] **Non-admin refusal end-to-end** — still needs a Play session (job 009's other check)
- [ ] Five-state look approved — **yours to judge**; blocked on sky assets for the storm end
