# Implementation Plan — Job #023

**Project**: `roblox.tide`
**Created**: 2026-08-21
**Status**: Planning (awaiting go-ahead)

The expedition loop — departure, the run's three endings, and the return. Closes the loop that job 022's
vessel loss currently dead-ends into.

---

## Rulings (2026-08-21)

| Question | Ruling |
|---|---|
| How a run ends successfully | **Northward distance threshold.** Make your northing and the finale begins |
| DataStore persistence | **Out of scope.** Loop only; the summary is real but nothing is saved |
| Where the summary happens | **Split** — a beat in the game place, the detail in the lobby |
| What northing unlocks | **The finale, not the victory.** Decision 0024: the run ends by defeating a vessel, so 023 ships a placeholder finale behind the same trigger |
| Run shape | **[Decision 0024](../../docs/decisions/0024-expedition-shape-and-pacing.md)** — ~50 min, 5-minute boarding grace, ~10 tiered stops, storm gated on boarding |

Both places now sync (verified byte-exact, lobby `AdminTools` 59,246 = disk).

---

## Analysis

### The extraction measure cannot be storm distance

The obvious implementation — "run completes when `StormDistance` exceeds X" — **does not work**, and it is
worth writing down why before someone tries it. `StormFront.advance` ends with:

```lua
distance = math.min(distance, StormFront.START_DISTANCE)   -- never past 4200
```

That cap exists so an early lead cannot become an un-loseable one. It also means distance **stops rising**
once the crew is 4200 studs ahead, so it is useless as a progress measure — a crew could sail north for ten
minutes and the number would not move.

So the run tracks its own measure: **net northing**, `hull.Z - startZ`, captured at arrival.

Net displacement rather than accumulated northward deltas, deliberately. `StormFront` counts only northward
travel (running south does not hand the storm distance twice), and copying that here would let a crew farm
progress by oscillating north and south. Net Z cannot be farmed.

⚠️ If finding 0018 is ever answered by **recentring the world on the vessel**, `startZ` must be shifted by
the same offset at each recentre, or the run's progress resets itself. One line, easy to forget, so it is
called out in the module.

### Northing brings the finale; the boss ends the run

Per [decision 0024](../../docs/decisions/0024-expedition-shape-and-pacing.md), written after this plan's
first draft: the expedition ends by **defeating a hostile vessel**, not by arriving anywhere. The northing
measure survives unchanged — what changes is what it unlocks.

So job 023 ships a **placeholder finale**: reach the threshold and the run resolves as finished. When the boss
lands (groups 05, 06) it slots in behind the same trigger and the loop needs no rework. The seam this avoids
is "arrival = victory", which is exactly the kind of assumption that is expensive to un-pick later.

### New: the storm does not advance until the crew boards

Decision 0024 opens the run on a small island with the front **visible and stationary**; taking the helm
starts its clock. Five minutes of grace.

Small to build — gate `StormFront.advance` on a "run has started" flag rather than calling it unconditionally
every tick — but it needs care in one place: the flag must be **server-owned and one-way**. A crew that leaves
the helm must not pause the storm, or the grace becomes an exploit that switches off the game's only pressure.

The lobby is the same gate held permanently off, which is a better answer than the "pin the distance" approach
this plan originally proposed: one mechanism, two settings.

### The arithmetic, and what it says about difficulty

Shipped target: a tunable constant, **2400 studs** to start with.

```
cruise 18 studs/s          -> 2400 / 18 = 133 s of pure running
fuel 100 at 0.55/s         -> 182 s at full ahead
ocean half-extent 3072     -> the placeholder finish sits well inside the patch
```

1. **It caps how far north a run can reach**, which shrinks
   [finding 0018](../../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md)'s worst case. East–west is
   still open (decision 0002's wrap is unimplemented), so the finding does not close.
2. **Fuel bites for the first time.** 133 s of a 182 s tank spent just travelling leaves almost no detour
   affordable, which makes group 03's fuel cans necessary rather than a nice-to-have.
3. **A bare loop will feel easy, and that is correct.** Run straight north at cruise and the storm nets
   +14.8 studs/s *against* you — you gain distance, cap out at 4200, and arrive untroubled. The storm only
   becomes pressure when there is a reason to stop, which is islands and loot (group 04). Do not "fix" the
   easiness by tuning the storm; the missing ingredient is content, not difficulty.

🔴 **2400 is a placeholder, and decision 0024 says why.** The real run is ~50 minutes and ~19,800 studs of
travelling — **3.2× the width of the ocean patch**. The shipped threshold cannot become the real one until
finding 0018 is answered. Build the measure, make the target a constant, and do not tune it in this job.

### The three endings are two code paths and a cause

- **Finished** — northing ≥ target (placeholder finale).
- **Lost** — job 022's `loseVessel` already produces this (integrity zero, or capsize held past 100°).
- **Out of fuel** — *not a third path.* Adrift, the front still closes at 14 studs/s, reaches the crew, and
  integrity drains to zero: it terminates in `lost` on its own. What it needs is to be **recorded as a
  cause**, so the summary says "ran out of fuel" rather than "hull destroyed". That is the story the design
  wants ("we ran out of fuel just before the storm caught us"), and it is a label, not a mechanism.

🟡 **The dead wait is real, and I am proposing a fix.** At the distance cap, a fuelless crew waits
`4200 / 14 = 300 s` for the front plus ~45 s to die — **up to five and three-quarter minutes of helpless
drifting**. That is not tension, it is a loading screen. So the plan adds an **"abandon ship"** action: a
deliberate, confirmed, player-initiated end that resolves the run immediately as lost. It costs the crew
nothing they were not already going to lose, and it removes the only unbounded wait in the loop.

Flagging rather than assuming: this is a design addition the intake did not ask for. If you would rather the
crew sit and watch it come, say so and I will drop it — but then those five minutes need something to do.

### Arrival is not automatic

The game place runs `CharacterAutoLoads = false` by design (job 004). Admins auto-spawn today via
`AdminServer`; **arriving crew do not**. So arrival has to explicitly spawn each player and place them —
per decision 0024, on the **starting island**, not on the deck, since the run opens with five minutes to
board. `ReplicationFocus` is already handled by `VesselServer.focusOn` on `PlayerAdded`.

### The duplication problem, stated honestly

The lobby's `ReplicatedStorage` is **empty on disk**. Everything the sea needs is new there, and Roblox has no
cross-place `ReplicatedStorage`, so shared modules must be **copied into both sync roots and kept
byte-identical** — the arrangement `AdminTools` already lives with, and which rotted by 12,234 bytes during
job 022 without anyone noticing until it was measured.

Rather than pretend that will not happen again, the plan adds a **parity check** to the tooling: a script that
diffs the shared files between `studio_game/` and `studio_lobby/` and fails loudly. Cheap, and it turns a
silent divergence into a red line.

Modules the lobby needs: `SeaStates`, `WaveField`, `DayNight`, `SkyLibrary`, `CloudWallVFX`, `StormVFX`,
plus `Ambience`/`AudioBed` if the harbour is to have sound. That is a lot of surface — see the phasing note.

### Party pads: reuse Jungle's shape

`roblox.jungle.game/lobby/sync/ServerScriptService/LobbyServer.server.luau` is the reference. What to copy:

- pads are **editor-placed**, discovered at runtime by attribute `Station = "PartyPad"` — no count constant
  (Jungle deleted theirs after it drifted to a lie: 3 declared, 4 placed)
- `PAD_RADIUS = 9` studs to count as standing on it
- sign (`BillboardGui`, `MaxDistance 40`) and `ProximityPrompt` are **script-attached to your geometry**
- launch: countdown → `ReserveServerAsync` → `TeleportAsync`, **3 attempts 1 s apart**
- the launch VFX and audio fire **before** the teleport call, so the party hears it even when the call fails
  or you are in solo Studio Play
- `TeleportOptions:SetTeleportData` carries seed, party size, member UserIds

What **not** to copy: `MAX_PER_PAD = 6`. Tide's crew size is confirmed 6 / 20 (job 004), so the pad cap wants
setting against that deliberately rather than inherited.

---

## 🧱 What is grayboxed

Everything in the lobby except the island you sculpt. Registered up front, because a grey square nobody wrote
down is exactly how placeholder art ships by accident — and `tools/audit-graybox.luau` only catches what the
registry knows about.

| Id | Stands in for | Place | Notes |
|---|---|---|---|
| `GB-LOBBY-ISLAND` | `ASSET-LOBBY-ISLAND` | lobby | **Only if your sculpt is not ready.** A flat disc to stand the pads on, so the job is not blocked on art. Delete it the moment the real island lands, and keep the pad positions |
| `GB-LOBBY-PAD` | `ASSET-LOBBY-PARTY-PAD` | lobby | One entry for all pads, like `GB-STARTER-LAUNCH` is one entry for the whole ship. **Editor-placed by you**, tagged `Graybox`, discovered by `Station = "PartyPad"`. Sign and prompt are script-attached, so replacing the geometry needs no code change |
| `GB-LOBBY-STORM` | `ASSET-CLOUD-WALL` | lobby | The static horizon storm. Reuses the same built-in `smoke_main.dds` particle bank as the game's wall, so it inherits `GB-CLOUD-TEXTURE`'s note rather than restating it; that entry gains `place: game, lobby` |
| `GB-GAME-START-ISLAND` | `ASSET-START-ISLAND` | game | **New, from decision 0024.** The run now opens on a small island with five minutes to board, so the game place needs one too. Graybox until it is worth sculpting |
| `GB-STARTER-LAUNCH` | `ASSET-BOAT-STARTER` | game | Already registered (job 022). Unchanged here |

Unlike `GB-STARTER-LAUNCH`, every entry above is **editor-placed**, so they are *not* `runtime = true` and the
audit sees them in Edit normally.

Two existing entries need a decision as part of this job:

- **`GB-LOBBY-DOCK`** exists only because the lobby has `CharacterAutoLoads = true`, so removing the baseplate
  would drop joining players into the sea. **An island supersedes that reason.** If the island is where players
  spawn, the dock is either retired or becomes real harbour furniture — your call, and it is the kind of
  deletion I will not do unasked (Studio Sync is two-way).
- **`GB-GAME-DECK`**'s own note says to delete it once `GAME-0001` lands, which it has. Decision 0024 may
  retire it outright, since the run now starts on an island rather than needing somewhere to stand.

---

## Implementation steps

Phased, and the phase boundaries are **safe stopping points** — this is a large job and if it wants splitting,
split it at A|B or B|C rather than mid-phase.

### Phase A — the lobby as a place

1. **Parity tool** first: `tools/check-shared-parity.py`, diffing the files that must be byte-identical
   across both sync roots. Written before the duplication exists, not after.
2. Copy the sea and sky modules into `studio_lobby/ReplicatedStorage/`, byte-identical.
3. `studio_lobby/ServerScriptService/LobbyWorld.server.luau` — compose the look and hold the storm's advance
   gate permanently **off**: endless sea, day/night if wanted, the front parked on the horizon. Re-check
   `FogEnd` against `OCEAN_HALF_EXTENT` rather than raising it alone (the hard rule from job 007).
4. Register the lobby grayboxes in `assets/registry/assets.yaml` and in `audit-graybox.luau`'s `REGISTERED`.

### Phase B — departure

5. `LobbyServer.server.luau` — pad discovery by attribute, occupancy, countdown, `ReserveServerAsync` +
   `TeleportAsync` with retries, teleport data. Modelled on Jungle's, with Tide's crew cap.
6. `LobbyClient.local.luau` — pad state on screen, and the arrival summary panel (used in Phase C).
7. **Close findings 0004 and 0005**: the game place is `Fully Open` with Social Slots on, which is precisely
   wrong for a reserved-server expedition — a stranger can deep-link into a running run, and a friend can drop
   into a 6-slot crew mid-expedition. These are place settings, so they need your hands; I will give you the
   exact toggles and verify the result over MCP.

### Phase C — the run's endings and the return

8. `ReplicatedStorage/Expedition.luau` (both places) — the run-state model: `startZ`, northing, target,
   state, cause, the boarding gate, and the summary shape. Pure; no instances.
9. `ServerScriptService/ExpeditionServer.server.luau` — spawn arriving crew on the start island, own the
   boarding gate that starts the storm, watch northing, hook job 022's loss, own **abandon ship**, and resolve
   the run into a summary.
10. `ExpeditionClient.local.luau` — the in-place **beat**: she goes down, or you make your northing, and the
    screen holds before the teleport. The game-place half of the split summary.
11. Return teleport with the summary in `TeleportData`, and the lobby panel that reads it. Failure handling
    both ways: a crew that cannot get home must not be stranded in a dead reserved server.
12. Admin tools: `Expedition → Set northing`, `Force an ending` (finished / lost / abandoned), `Start the
    storm` (skip the boarding grace), `Run report`. Same discipline as job 022 — the loop is not judgeable by
    eye.
13. Docs: a decision recording the extraction measure and why storm distance cannot serve; a systems doc for
    the expedition loop; update `GAME-0013` and whichever feature covers departure; re-run `build-status.py`.

---

## What I need from you

- [ ] **Go-ahead**, and a ruling on **abandon ship** (see the 🟡 note — I am proposing it; it is not in the
      intake).
- [ ] **Place the pads in the editor** when Phase B starts, with attribute `Station = "PartyPad"`. Any number;
      the code counts them. Also say whether the island sculpt will be ready, or whether I stand in
      `GB-LOBBY-ISLAND`.
- [ ] **Findings 0004 / 0005** need your hands on the place's access settings (step 7).
- [ ] Nothing to source. No new asset or audio ID is required; the lobby storm reuses the game's built-in
      particle textures.

---

## Verification

Measured where it can be, and this job has more that cannot be than job 022 did — a teleport cannot be
verified from a probe.

- [ ] **Northing drives the ending** — set the target low, drive north, confirm the run resolves as finished
      at the threshold and not before
- [ ] **Storm distance is *not* the measure** — confirm a run still resolves correctly after `StormDistance`
      has capped at 4200, which is the case the naive implementation gets wrong
- [ ] **The boarding grace holds** — the front does not move for five minutes, then starts on the helm being
      taken; and leaving the helm afterwards does **not** stop it
- [ ] **Loss still ends the run** — job 022's survival test, then confirm the ending fires with cause `lost`
- [ ] **Out of fuel is labelled as such** — drain the tank, let the front arrive, confirm the summary says
      fuel and not hull
- [ ] **Abandon ship** resolves immediately and cannot be triggered accidentally
- [ ] **The lobby storm does not move** — sample `StormDistance` in the lobby over 60 s; it must not change
- [ ] **Lobby fog stays inside the water** — no visible edge; screenshot the horizon
- [ ] **Pads**: add and remove one in the editor with no code change; occupancy respects the cap; the sign and
      prompt attach to new geometry
- [ ] **Teleport** — the one thing needing a real session with a second person. Solo departure, then a party;
      then a forced failure (bad place id) to confirm the retry and fallback rather than a stranded player
- [ ] **Shared-module parity** — `check-shared-parity.py` clean, and re-run after every edit to a shared file
- [ ] **Graybox audit** clean in both places, with every new placeholder registered
- [ ] No new analyzer diagnostics in either place; Play sessions stopped; Studio left in Edit
