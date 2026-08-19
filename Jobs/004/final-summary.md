# Final Summary — Job #004

**Project**: `roblox.tide`
**Completed**: 2026-08-19 23:07:50
**Status**: ✅ Completed

## What was implemented

Configured the engine baseline for both places and made it auditable instead of hand-clicked. Applied over MCP and read back correct: game place 21 rows ok, lobby 13 rows ok. Game place: CharacterAutoLoads false so the expedition owns death and a downed player cannot respawn mid-revive, RespawnTime 5, StreamingEnabled true, FallenPartsDestroyHeight -500, CameraMaxZoomDistance 60, plus provisional ocean and fog values from the palette (WaterColor 18/53/74 = Deep Ocean Blue, Reflectance 0.3, Transparency 0.25, WaveSize 0.35, WaveSpeed 12, FogEnd 2500, FogColor 140/154/163 = Fog Grey, OutdoorAmbient 70/82/92). Lobby: CharacterAutoLoads true, RespawnTime 3, StreamingEnabled false, CameraMaxZoomDistance 40, FogEnd 5000. Both places: ScreenOrientation LandscapeSensor, DevTouchMovementMode DynamicThumbstick, AutoJumpEnabled false, CameraMinZoomDistance 6 to keep third person per decision 0001, EnableMouseLockOption true, LoadCharacterAppearance true, HttpEnabled false, Gravity left at default. Every Lighting and Terrain row is marked provisional in the spec and handed to features 0003 and 0004 to own, so this job did not turn into the visual design pass. DISCOVERY: Players.MaxPlayers and PreferredPlayers are read-only to scripts even under the MCP's plugin capability - the assignment fails outright - so crew size cannot be set from code and moved to the human checklist (File > Experience Settings; the 'Game Settings' name I first used does not exist in current Studio - corrected in workspace job 012). The audit reports them as DRIFT until that is done, which is the correct behavior rather than a bug. Deliverables: docs/systems/places/settings-baseline.md is the version-controlled spec, split into scriptable / NotScriptable / experience-level because each class is applied differently; tools/audit-place-settings.luau detects its place from PlaceId, checks every row with float and Color3 tolerance, and prints OK / DRIFT / HUMAN-TODO. Two decided constraints were propagated so they cannot be forgotten: feature 0001 gained a requirement to set ReplicationFocus to the vessel because streaming is on, and both the places README and the tide-project skill now carry the streaming, death-ownership and landscape/thumbstick consequences.

### Files changed

_Docs, spec and one tool script. The place property writes themselves live in the
`.rbxl` — which is exactly why the spec table and audit script exist._

- `docs/systems/places/settings-baseline.md`
- `tools/audit-place-settings.luau`
- `docs/systems/places/README.md`
- `docs/features/0001-boat-controller/feature.md`
- `.claude/skills/tide-project/SKILL.md`

### ⚠️ Required from you — the settings are not saved yet

1. **Save both places** (`Ctrl+S` in each). Everything I applied is an unsaved Edit-mode change; if
   you close Studio without saving, all of section 1 is lost and the audit will report drift.
2. **`File → Experience Settings`** → Max Players, per place. (Current Studio has no "Game Settings" —
   my earlier instruction was wrong; corrected in workspace job 012):
   - The Last Tide Game → **Max Players 6**
   - The Last Tide → **Max Players 20**
   (read-only to scripts, so I cannot do these)
3. **Lighting** — Explorer → select `Lighting` → Properties. `Lighting.Technology` does not exist in
   current Studio; the properties are `LightingStyle` (currently `Soft` — **leave it**, `Realistic` is
   the mobile-expensive one) and `PrioritizeLightingQuality` (currently `true`). Nothing to change here
   for now, so this step is just "confirm the values".
   `Future` would suit the night/storm look better but costs too much on phones — revisit with
   measurements.
4. **Creator Hub → experience settings** (once for the whole experience):
   - Playable devices: **Phone, Tablet, Computer** (leave Console and VR off)
   - Avatar type: **R15 only** — via `File → Avatar Settings`, its own entry. The Meshy rigging pipeline
     targets R15, and allowing R6 doubles the animation work
   - Genre: **Adventure**; keep the experience **private**; no monetization yet
5. Note what `Workspace.PhysicsSteppingMethod` currently reads, but **don't change it** — feature 0001
   (boat controller) owns that decision.

Then ask me to re-run the audit and it should come back clean.

## Verification

- [x] Every scriptable row applied and read back correct — game place 21 ok, lobby 13 ok
- [x] Audit script run against both places; output matches the spec table
- [x] The only DRIFT rows are `MaxPlayers`/`PreferredPlayers`, correctly flagged as human-only
- [x] `MaxPlayers` write genuinely refused (`Property is read only`) — confirmed, not assumed
- [x] Studio API access already enabled in both places, so DataStore work is testable
- [x] Every relative link in the repo resolves
- [ ] Settings persisted — **requires you to save both places**
- [ ] `Lighting.Technology`, crew size, and Creator Hub settings — **human-only, not yet done**
