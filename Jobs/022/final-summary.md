# Final Summary — Job #022

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ Implemented and measured in a running session. Two items need a hands-on look (below).

The storm's teeth — hull damage and system faults inside The Wall. Implements
[decision 0014](../../docs/decisions/0014-storm-consequence.md); the model is recorded as
[decision 0023](../../docs/decisions/0023-storm-damage-model.md) and mapped in
[systems/vessels/damage.md](../../docs/systems/vessels/damage.md).

## What it does

The Wall now inflicts escalating hull damage, fires a designed fault ladder, floods her, can capsize her, and
can lose the vessel. A crew that reacts immediately gets out at a real cost; a crew that lingers does not get
out. The storm has stopped being a spectacle.

Everything derives from **one new spec field**: `survivability = 45`, the seconds of continuous full exposure
the hull survives. Integrity pool, damage rate and every fault threshold fall out of that plus the hull's own
mass, so decision 0009's promise — nothing tuned per hull — still holds. A trawler declares 90 and is tougher;
no second set of constants.

| Piece | Where |
|---|---|
Damage model, pure maths | `ReplicatedStorage/VesselDamage.luau` (new) |
Exposure + escape arithmetic | `StormFront.exposure()`, `wallAt()`, `secondsToEscape()`, `minEscapeSpeed()` |
`survivability`, `damageControl` socket | `Vessel.luau` |
Applying it all, the station, the compass | `VesselServer.server.luau` |
Compass animation | `VesselClient.local.luau` |
5 new admin tools | `AdminTools.luau` (both places) |

Faults: **engine cut** (8 s, self-relighting — permanent would make escape impossible by definition), **hull
breach** → flooding costs up to 35% of lift, **steering damage** → 45% rudder authority. Radar and generator
ship as honest flags, labelled "(stub)" in the panel, until there is a radar to lose and a light to go out.

## Measured, not asserted

| Check | Result |
|---|---|
Hold position at full exposure | **lost at 45.5 s** against 45 declared — 101% |
Fault ladder | radar 20% · generator 40% · engine 60% · breach 75% — **exact** |
Engine cut is transient | fired 27.6 s, relit ~8 s later unaided |
Escape run from distance 0 | **cleared the front at 27.9 s**, 74% of the hull left |
Northward travel buys distance | **+12.84 studs/s** against +12.94 theory — **99.2%** |
Buoyancy converges under flooding | 62 s at 100% flooding in a Storm sea: amplitude 4.28 → 4.27 (growth 0.999), waterline held, max tilt 15° |
Waterline at full flooding | 0.31 studs lower in Light Swell, 1.15 lower in a Storm sea |
Loss path | engine dead, helm released, all four float forces zeroed, sinks upright, `ExpeditionOver` set |
Lightning consumer | `[VESSEL] lightning raised generator -> generator` |
Compass | tracked a heading sweeping 78.7°, `rotation = -heading` throughout |
No heading on the wire | `VesselHeading` nil from a client, full client attribute list audited |
Admin panel | 44 tools, all scopes valid, **built exactly once** |

Three of those measurements were **wrong on the first attempt** and are worth recording as method:

1. The flooding stability test passed a hull that was **sinking** — a sinking hull bobs less, so amplitude
   alone read as "converged". The verdict now checks mean drift too.
2. The next attempt was confounded by the **sea state changing mid-sample** (Light Swell → Choppy, amplitude
   0.8 → 2.0), which read as energy gain.
3. The one after that was confounded by **the front closing back in** over four minutes of sampling and
   killing her at 25% integrity. Only with `TimeScale = 0` freezing the world did the measurement mean
   anything.

The compass "passed" a vacuous test too: the server owns the hull and corrected every client-side heading I
set, so `rotation = -heading` held trivially for a constant heading. It took turning her from the server to
make the check real.

## Bugs found and fixed

**🔴 The storm had never been outrunnable** ([finding 0020](../../findings/0020-a-hardcoded-instance-path-between-two-sy.md)).
`WorldTick.vesselZ()` looked for `workspace.Vessels.Hull`; the model is parented under the spec id, so the
folder never existed. It returned `nil` every tick from job 021 onward, `GAIN_PER_STUD` was never once
applied, and `StormDistance` could only fall. The comment beside it was true when written at job 017 and
stopped being true one job later, so the symptom read as a design choice. Now reads the server-side handle and
warns after 30 s of no vessel.

**🔴 Fixing that published the vessel's position to every client**
([finding 0023](../../findings/0023-fixing-the-storm-published-the-vessel-s-.md)). `StormFront` kept the
previous measurement in a Workspace attribute, `StormLastVesselZ`, and Workspace attributes replicate — so a
client watching it rise knew it was heading north. The same leak `VesselHeading` was deleted for in this job,
arriving through the storm's own bookkeeping, and my own comment in `WorldTick` argues against exactly this.
Caught only by enumerating every attribute visible from the **client**, not by re-reading what I had changed.
Now a module upvalue.

**🔴 `StormFront.reset()` was a distance cheat.** It zeroed the last position instead of clearing it, so the
first tick after any reset credited the hull's whole Z coordinate as travel — a vessel 500 studs north gets
800 studs of free cushion from the panel's storm-distance button. Latent only because `vesselZ` never worked.

**🟡 The client does not render while Studio is backgrounded**
([finding 0022](../../findings/0022-a-backgrounded-studio-play-session-simul.md)). Measured: `Heartbeat` and
`Stepped` fired 120 times in 2 s, `RenderStepped` **zero**. The compass looked broken and was not; the code
was fine and the context was not. Moved the compass to `Heartbeat` (a GUI rotation needs no render timing),
which is finding 0012's own rule applied. Job 021's helm loop has the same blind spot and was left alone —
it was signed off by feel and changing input timing is not this job's call.

**Missing tool.** Once lost, the vessel stays lost by design, which meant testing a loss ended the session.
Added `Vessel → Rebuild the vessel`, exposing `_G.TideVessel.rebuild` (present since job 021, wired to
nothing) and clearing the expedition flags with it.

**Corrected my own estimate.** The `MAX_FLOODING_LIFT_LOSS` comment claimed "roughly 0.6 studs deeper". The
measured figures are 0.31 (Light Swell) and 1.15 (Storm), because the float points spend part of each wave out
of the water where there is no lift to lose. The comment now carries the measurements.

## Also delivered

**`tools/luau-analyze.sh`** — adapted from Defender's. Studio Sync was dead for the first half of this job, and
this is what caught two malformed string literals that would otherwise have failed at `require` time in a Play
session. Both places: no syntax errors; `VesselServer`'s three remaining diagnostics are byte-identical to the
committed baseline.

**Finding 0007 sharpened.** Sync was down and my detection missed it: I counted children (16/4/3), they matched
disk, and I called sync live. Child counts only prove instances exist, which the saved `.rbxl` guarantees. The
finding now says content beats inventory, and notes that the handoff's "there should be 14 modules" style of
check is weak for the same reason — and rots (14 was right at job 019; job 021 made it 16).

### ✅ Auto-synced files

- `studio_game/ReplicatedStorage/VesselDamage.luau` *(new)*
- `studio_game/ReplicatedStorage/StormFront.luau`
- `studio_game/ReplicatedStorage/Vessel.luau`
- `studio_game/ServerScriptService/VesselServer.server.luau`
- `studio_game/ServerScriptService/WorldTick.server.luau`
- `studio_game/ServerStorage/AdminTools.luau`
- `studio_game/StarterPlayerScripts/VesselClient.local.luau`
- `studio_lobby/ServerStorage/AdminTools.luau`
- `tools/luau-analyze.sh` *(new, tooling — not synced)*

### ⚠️ Manual Studio copy required

- _none_

## Verification

- [x] Sync confirmed by **content**, all seven game-place files byte-identical to disk
- [x] Hold-position survival: lost at 45.5 s against 45 declared
- [x] Escape run: cleared the front at 27.9 s with 74% of the hull
- [x] Fault ladder fires at its exact thresholds, engine cut relights unaided
- [x] Northward travel buys distance — 99.2% agreement with theory
- [x] Buoyancy converges at 100% flooding in a Storm sea
- [x] Loss path: sinks upright, forces zeroed, `ExpeditionOver` set
- [x] Compass card tracks a sweeping heading
- [x] `VesselHeading` unreadable from a client; client attribute list audited
- [x] No new analyzer diagnostics in either place; no runtime errors or warnings
- [x] Play session stopped, Studio left in Edit
- [ ] **Compass orientation by eye** — does "up" on the binnacle point at the bow? `COMPASS_SIGN` and
      `COMPASS_OFFSET_DEG` exist for the correction
- [ ] **Damage-control hold** — the prompt is present and configured, but `Triggered` cannot be fired from a
      script, so the repair path has never been exercised
- [ ] **Compass readability at The Wall's brightness 0.30** — `LightInfluence = 0` should make it immune,
      which is the kind of "should" worth one screenshot
- [ ] **A hands-on run** — a full five-minute approach steered by a person. Everything above went through the
      `VesselTestDrive` hook, because the helm loop cannot run unfocused (finding 0022)
- [ ] **Lobby place sync** — its `AdminTools` reads 47,012 chars against 57,845 on disk. Nothing in job 022
      needs it, but the two copies are meant to stay byte-identical

## Still owed

- todo 0005 — should lightning be able to damage steering?
- todo 0006 — the real end-of-expedition flow; vessel loss is a placeholder
- todo 0007 — `PlayerRemoving` connected inside `buildVessel` leaks a connection per rebuild
- finding 0021 — the spec labels `+Z` as the bow but she drives toward `-Z`, so the helm and the
  damage-control locker sit at the opposite ends from their names. Fixing it re-opens job 021's measured heel
  and trim, so it belongs to the job that measures them again
- Radar and generator faults stay flags until `GAME-0002` and deck lighting exist
- Damage control has no resource cost until group 03
