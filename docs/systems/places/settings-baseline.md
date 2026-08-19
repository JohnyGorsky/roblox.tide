# Place Settings Baseline

**This table is the spec.** Place settings live inside the `.rbxl`, which git cannot see, so a setting
that only exists as a click in Studio is invisible and will drift. This file is the version-controlled
truth; [tools/audit-place-settings.luau](../../../tools/audit-place-settings.luau) re-reads the live
places and reports anything that no longer matches.

Places: lobby = The Last Tide Lobby `91870148721134`, game = The Last Tide Game `100885379547959`.
See [README.md](README.md) for what each place is for.

Agreed in tide job 004. Rows marked **prov.** are provisional starting values owned by a later
feature — change them there, and update this table when you do.

---

## 1. Scriptable — applied over MCP

Claude can write these. **They only persist once you save the place.**

All rows below were applied and read back correct in both places on 2026-08-19
(21 ok in the game place, 13 ok in the lobby). `MaxPlayers`/`PreferredPlayers` are *not* here — they
turned out to be read-only to scripts; see section 2.

### Both places

| Property | Value | Why |
|---|---|---|
| `StarterGui.ScreenOrientation` | `LandscapeSensor` | A boat HUD with diegetic instruments needs a wide canvas; portrait would break every layout |
| `StarterPlayer.DevTouchMovementMode` | `DynamicThumbstick` | Makes the reserved bottom-left touch rect predictable, so HUD layout can avoid it |
| `StarterPlayer.AutoJumpEnabled` | `false` | A deck is full of small ledges; auto-jump makes players hop constantly |
| `StarterPlayer.CameraMinZoomDistance` | `6` | Keeps the camera in third person (decision 0001). Contextual first-person is scripted, not zoomed into |
| `StarterPlayer.EnableMouseLockOption` | `true` | Shift-lock is useful for aiming from a moving deck |
| `StarterPlayer.LoadCharacterAppearance` | `true` | Character cosmetics are a monetization surface |
| `HttpService.HttpEnabled` | `false` | No external service is needed; leave the attack surface closed |
| `Workspace.Gravity` | `196.2` | Roblox default, deliberately unchanged |

### Game place only

| Property | Value | Why |
|---|---|---|
| `Players.CharacterAutoLoads` | `false` | **The expedition owns death.** Nothing may respawn behind the run's back, or a downed player pops back up mid-revive |
| `Players.RespawnTime` | `5` | Unused while auto-load is off; set so it is not a surprise if it is ever turned on |
| `Workspace.StreamingEnabled` | `true` | The ocean is a long world with curated POIs — this is what streaming is for |
| `Workspace.FallenPartsDestroyHeight` | `-500` | Default; well below any planned seabed |
| `StarterPlayer.CameraMaxZoomDistance` | `60` | The default 128 lets players zoom so far out the vessel stops reading as a base |
| `Terrain.WaterColor` | `18, 53, 74` | prov. — Deep Ocean Blue `#12354A` from the palette |
| `Terrain.WaterReflectance` | `0.3` | prov. — default `1` is a mirror; a cold sea is not |
| `Terrain.WaterTransparency` | `0.25` | prov. — murky, not a swimming pool |
| `Terrain.WaterWaveSize` | `0.35` | prov. — default `0.15` is flat for an ocean. Owned by boat physics |
| `Terrain.WaterWaveSpeed` | `12` | prov. |
| `Lighting.FogEnd` | `2500` | prov. — default `100000` means infinite visibility, which kills both the storm and the map-edge concealment rule. Owned by features 0003/0004 |
| `Lighting.FogColor` | `140, 154, 163` | prov. — Fog Grey `#8C9AA3` |
| `Lighting.OutdoorAmbient` | `70, 82, 92` | prov. — cold ambient instead of neutral grey |

### Lobby place only

| Property | Value | Why |
|---|---|---|
| `Players.CharacterAutoLoads` | `true` | You need a body to walk the harbour |
| `Players.RespawnTime` | `3` | Default |
| `Workspace.StreamingEnabled` | `false` | Small bounded space; the Shipyard UI must never wait on streaming |
| `StarterPlayer.CameraMaxZoomDistance` | `40` | Tighter than the game place — the lobby is an interior-scale space |
| `Lighting.FogEnd` | `5000` | prov. — finite, but generous enough not to hide the harbour |

---

## 2. NotScriptable — you must click these

Probing confirmed these cannot be written from Luau — the assignment fails even under the MCP's plugin
capability. They are Properties-panel or Experience-Settings values, so they need your click.

| Setting | Recommended | Why |
|---|---|---|
| `Players.MaxPlayers` | **6** game / **20** lobby | Read-only to scripts, so `File → Experience Settings` only. ⚠️ **Not observable from Studio at all** — Edit *and* Play both report `60` whatever you set (verified after a reopen and in a Play Server context). The audit deliberately does not assert it; confirm in the dialog or on a live server |
| `Players.PreferredPlayers` | **6** game / **20** lobby | Same — set in the dialog, not checkable from Studio |
| `Lighting.LightingStyle` | **Realistic** — set by the user 2026-08-19, both places | `Lighting.Technology` **does not exist** in current Studio; `LightingStyle` replaced it. `Realistic` is the high-quality path, which suits the night/storm look. It is also the expensive one on phones — my recommendation had been `Soft`, and this is a deliberate override. **Its mobile cost is unmeasured**: measure on the device emulator before shipping (todo 0003) |
| `Lighting.PrioritizeLightingQuality` | `true` (default, unchanged) | Trades shadow range against view distance under load. On open water, view distance may matter more than shadow detail — untested; revisit alongside the `Realistic` measurement |
| `Workspace.PhysicsSteppingMethod` | verify, don't change yet | Owned by feature 0001 (boat controller). Note what it currently reads before touching it |
| `Workspace.StreamOutBehavior` | verify | Only meaningful in the game place |
| `Workspace.StreamingIntegrityMode` | verify | Only meaningful in the game place |

## 3. Experience-level — Experience Settings / Creator Hub

**Where:** current Studio has **no "Game Settings"** — it was split into `File → Experience Settings`
and `File → Avatar Settings`. Verified against live Studio 2026-08-19.

| What | Where exactly |
|---|---|
| Max players ("**Maximum Visitor Count**") | **Creator Hub** → Creations → The Last Tide → Places → *place* → **Access** → Basic Settings. ✅ verified 6 / 20 on 2026-08-19. (Studio's Experience Settings dialog may also expose it — unverified) |
| Avatar type (R15) | `File → **Avatar Settings**` — its own File-menu entry, *not* inside Experience Settings |
| API services | Experience Settings → Security (already enabled) |
| Playable devices | Creator Hub → experience → Settings |
| **Direct Access Control** | Creator Hub → Places → *place* → **Access**. Game place should be **Secure within Universe only** (currently *Fully Open* — finding 0004). Lobby stays Fully Open |
| **Social Slots** | Same page. Game place → **Disable**; lobby → Roblox optimized (finding 0005) |
| `LightingStyle` / `PrioritizeLightingQuality` | **not** a dialog — Explorer → select `Lighting` → Properties. Per place, so do both |

Web equivalent: [create.roblox.com](https://create.roblox.com/dashboard/creations) → experience →
Places → the place.

Set once for the whole experience, not per place.

| Setting | Value | Why |
|---|---|---|
| Playable devices | **Phone, Tablet, Computer** | Mobile-first. Leave Console and VR off until someone tests them |
| Avatar type | **R15 only** | The Meshy rigging and animation pipeline targets R15. Allowing R6 doubles the animation work |
| Avatar animation | Player choice | Cosmetic; revisit if custom animations conflict |
| Genre | Adventure | |
| Monetization | none yet | Roadmap stage 12 — after the core loop and retention are proven |
| Private / Public | keep **private** | Until there is something playable |

Teleporting between places inside one experience needs no setting; "third-party teleports" stays off.

---

## Applying and checking

```text
1. Claude writes section 1 over MCP          [done 2026-08-19]
2. YOU save both places                      <- without this, section 1 is lost
3. YOU click sections 2 and 3
4. Claude runs tools/audit-place-settings.luau against each place
   -> OK / DRIFT / HUMAN-TODO per row
```

Current audit result (2026-08-19, after both places were reopened): **everything in section 1 reads
OK** — 21 rows in the game place, 13 in the lobby. The settings survived a full reopen, so they are
genuinely saved into the `.rbxl`, not just live in an unsaved session.

`CharacterAutoLoads = false` was additionally confirmed **live in a Play session**: the player joined
the game place and their `Character` was `nil`, so nothing respawns unless the run says so.

Re-run the audit after anyone edits place settings, and after any Studio version bump.
