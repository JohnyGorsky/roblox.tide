# Job #023: The expedition loop: departure, the run's three endings, and the return

**Project**: `roblox.tide`
**Created**: 2026-08-21 20:12:36
**Status**: Requirements Gathering (intake)

## Requirements / goal

Close the loop. Today the game has a sea, a storm with teeth and a drivable vessel, but no way to START a run and no way to FINISH one - and job 022's vessel loss dead-ends: she sinks, ExpeditionOver is set, and nothing reads it. The two places exist with no route between them (decision 0013).

Scope:
1. DEPARTURE, lobby side. A departure point the crew leaves from, party assembly, and a reserved-server teleport into the game place. Solo departure must work and must not feel like a penalty (group 08 section E).
2. ARRIVAL, game side. Crew spawn aboard the vessel, the storm resets to its start distance, the run begins from a known state.
3. THE RUN'S THREE ENDINGS, all of which must be real states rather than a stuck session:
   - finished: the crew chooses to end the expedition and gets out
   - vessel lost: job 022 already produces this (integrity zero, or capsize) and it currently goes nowhere
   - out of fuel: adrift with the front still closing - a slow version of lost, and it needs a defined outcome rather than an indefinite wait
4. RETURN. Teleport back to the lobby and show a run summary.
5. TELEPORT FAILURE HANDLING. The manifest is explicit that this WILL fail sometimes: retries plus a graceful fallback, never a player stranded in a dead session.
6. Close findings 0004 and 0005 as part of this: the game place is Fully Open with Social Slots on, which is exactly the wrong setting for a reserved-server expedition - a stranger could deep-link into a running run, or a friend could drop into a 6-slot crew mid-expedition.

Hard constraints:
- Server-authoritative throughout. A client may request a departure or an extraction; it never decides one.
- Decision 0013 owns the two-place split; decision 0008 says run power resets and permanent progression unlocks options; decision 0011 says permanent progression is credited individually to EVERY eligible participant.
- Do not break the storm's 5-minute arrival or job 022's measured damage curve. StormFront.reset on arrival must not hand out free distance (see the reset note in StormFront).
- Consult the roblox-multiplayer skill before designing the teleport: reserved servers, party teleport, and what happens to a player who rejoins.

Open questions to settle in the plan, not now:
- Does this job include DataStore persistence, or is the summary display-only with persistence deferred? Nothing decision 0008 lists as permanent progression (blueprints, role mastery, discoveries, cosmetics) exists yet, so there may be nothing real to credit.
- Where does the run summary happen: in the game place before teleporting back, or in the lobby after arriving? The manifest lists this as open (group 08).
- What does 'the crew chooses to finish' actually look like in the fiction - a departure point they return to, a radio call, or a course north off the map edge? This one interacts with finding 0018, which is still undecided.

Prerequisite: LOBBY STUDIO SYNC IS NOT DELIVERING. Its AdminTools is 12,234 bytes behind disk and missing every tool added in jobs 020 and 022. This job is half lobby-side, so sync must be reconnected before implementation starts.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written

## The lobby, as specified 2026-08-21

The departure side is a **place, not a menu**:

- the **same endless sea** as the game place
- a **small island** to stand on
- a **storm on the horizon that never arrives** — the threat visible from safety
- **party pads**, like the Jungle game's
- everything **graybox for now except the island**, which gets sculpted
- **every object placed in the editor.** Scripts add the effects and the behaviour, never the geometry.

### 🔴 The storm in the lobby must never advance

This is the trap in the whole idea, and it is one line away from shipping wrong. Reusing `StormFront` gets a
front that **closes at 14 studs/s** and eventually engulfs the harbour, because that is what the module is
for. The lobby wants the *look* of the storm and none of its clock:

- port the sea (`SeaStates`, `WaveField`) and the cloud wall / sky, and **pin** the distance
- do **not** call `StormFront.advance`, and do not run the game's `WorldTick`
- the lobby currently has an **empty `ReplicatedStorage`** on disk, so all of this is new there, and the
  duplication needs a deliberate answer: Roblox has no cross-place `ReplicatedStorage`, so a shared module
  gets copied into both sync roots and must stay byte-identical — the same arrangement `AdminTools` already
  lives with, and the same way it can rot

Also: the lobby's water is currently tuned as a sheltered bay (`WaveSize 0.06`, `FogEnd 1900`) against the
open sea's `0.18`. An endless sea in the lobby changes that on purpose, so re-check it against the
`OCEAN_HALF_EXTENT` fog rule rather than raising `FogEnd` alone.

### Party pads: reuse the Jungle pattern, do not invent a second one

`roblox.jungle.game/lobby/sync/ServerScriptService/LobbyServer.server.luau` already does this and is worth
copying in shape:

| | |
|---|---|
Discovery | pads are **editor-placed** and found at runtime by attribute `Station = "PartyPad"` |
No count constant | Jungle deliberately deleted its `PAD_COUNT` — it was read by nothing and had drifted to a lie (3 vs the 4 pads actually placed). Add or remove a pad in the editor and no code changes |
Occupancy | `MAX_PER_PAD = 6`, `PAD_RADIUS = 9` studs to count as standing on it |
Runtime-attached | the floating pad sign (`BillboardGui`, `MaxDistance 40`) and the `ProximityPrompt` are built by script onto editor geometry — exactly the division of labour asked for here |
Launch | party → countdown → `ReserveServerAsync` → `TeleportAsync` with **3 attempts, 1 s apart**, and the launch audio/VFX fire **before** the teleport call so the party hears it even when the teleport fails or you are in solo Studio Play |
Teleport data | seed, party size and member UserIds passed via `TeleportOptions:SetTeleportData` |

That last detail is the one to keep: Jungle fires the launch effect before the call precisely because the
call is the part that fails. Crew size for Tide is 6 / 20 (confirmed job 004), so `MAX_PER_PAD` wants
checking against that rather than copied.

### What this means for graybox discipline

The island is the only thing being sculpted, so **everything else on the lobby island is a registered
graybox**, the same way `GB-STARTER-LAUNCH` now is. Pads especially: a grey square that nobody wrote down is
how placeholder art ships by accident, and `tools/audit-graybox.luau` exists to catch it.
