# Final Summary — Job #025

**Project**: `roblox.tide`
**Completed**: 2026-08-21
**Status**: ✅ Delivered and measured. One structural limit found and recorded (below).

The lobby's atmosphere: a harbour sky, a sea that never settles, and a storm that never arrives. Promoted from
[Planned 0002](../../Planned/0002-lobby-place-and-departure.md)'s Phase A at the user's request.

## What it does

The lobby had no sky, no sea, no weather and no sound — an empty water patch. It now shares the game's entire
atmosphere layer, always in daylight, with weather that drifts and a storm parked on the horizon.

| | |
|---|---|
Modules copied | 12 into `studio_lobby/ReplicatedStorage`, plus the generic `WeatherClient` and `LightningServer` — 15 instances, all byte-identical to the game's |
Always day | `DayNight.pause()` freezes the clock; the composer keeps running |
Weather | DeadCalm → LightSwell → Choppy off `LocalWeather.unsettled()` |
Waves | ceiling **1.28 → 3.20 studs**, render waves 0.18 → 0.45 |
The horizon storm | static at 1,000 studs, intensity 2 so lightning stays armed |
New tooling | `tools/check-shared-parity.py` — 18 shared files tracked |

## Two design decisions

**`StormFront` is deliberately not copied.** The plan was to ship it with its advance gated off. The better
answer turned out to be simpler: every sensory system reads Workspace **attributes**, not the module — so the
lobby sets those directly and never ships the clock at all. *The storm never arrives* is now true **by
construction** rather than by a flag somebody could flip; there is no advance function in the place to call by
accident.

**The sea is pinned separately from the storm.** In the game place one number drives everything — distance
picks a band, the band picks a sea state — and that coupling cannot express what a lobby wants, because a
distance close enough to *draw* a cloud wall also selects a Storm sea. So distance and intensity are static
while the sea cycles on its own. Only possible because job 020 separated the sea override from the storm's
bookkeeping.

### A scoped exception to decision 0020

That decision says everyday weather may move wind, waves, rain and fog and may **not** touch sky, brightness,
ambient or severity. The lobby's cycle moves all of them, on purpose — and the reason the rule exists is why it
can: **0020 protects the storm's legibility**, so a calm spell can never mask an approaching front. The lobby
has no approaching front, so there is nothing to mask, and a harbour whose sky never changes is a screensaver.

Recorded in `LobbyWorld`'s header as the only exception. **The game place still obeys 0020 in full.**

## The bug the user's question surfaced

Asking for "all environment sounds" is what caught it. There are **two wind attributes**:

    Wind        what LocalWeather.step() publishes — the weather's own figure
    StormWind   what StormVFX and StormAudio actually READ — the master sensory control

`StormFront.apply()` bridges them in the game place. The lobby has none, so when the static wind pin was
removed to let the weather cycle, **nothing set `StormWind` at all.** It read nil, and the rain emitters and
high-wind audio bed sat at exactly `0.000` while everything else worked. Now bridged in `LobbyWorld`, which is
also what makes rain and spray rise and fall with the cycle rather than being decoration.

## Two corrections to my own measurements

Both worth recording, because both would mislead the next person the same way:

1. **The audio beds live in `SoundService`, not `Workspace`.** My first probe scanned Workspace, found the
   *character's* default sounds (Climbing, Jumping, Splash) sitting silent, and I reported "the lobby has no
   audio". It had 16 voices playing the whole time.
2. **Requiring a module in a probe gives a fresh copy.** `execute_luau` is a separate Luau VM, so
   `Ambience.report()` printed "** NO BED **" for five channels that were in fact playing. Read the instances,
   not the module.

## Measured

| Check | Result |
|---|---|
Always day | clock **13.50 → 13.50**, zero movement over 48 s |
Weather drifts | unsettled 0.24 → 0.69; it walked the **whole band** in 48 s |
Seas reached | DeadCalm, LightSwell, Choppy — all three |
The storm does not move | **0.00 drift** over 15 s |
Fog inside the water | 900 against the ~1,022 half-extent — no visible map edge |
Lightning | armed and firing; thunder logged at 394 and 523 studs |
Audio | 17 voices, 7–9 audible, **8 changed volume** over 30 s |
Shared-file parity | 18 identical, 0 differing |

## 🔴 The structural limit this job found

The harbour reads hazier and flatter than it should, and it is **not a tuning miss**. The lobby's water is only
~2,044 studs across against the game's 6,144 × 6,500. The job-007 rule forces fog inside the water, so fog is
capped at **900** — which washes out the horizon, *including the storm wall it exists to show*.

Growing the lobby's ocean, the same way decision 0025 grew the game's, is the fix. It is also what delivers the
"same endless sea" originally asked for. A saved-place change.

### ✅ Auto-synced files

- `studio_lobby/ReplicatedStorage/` — 12 modules *(new, copies)*
- `studio_lobby/ServerScriptService/LobbyWorld.server.luau` *(new)*
- `studio_lobby/ServerScriptService/LightningServer.server.luau` *(new, copy)*
- `studio_lobby/StarterPlayerScripts/WeatherClient.local.luau` *(new, copy)*
- `tools/check-shared-parity.py` *(new, tooling — not synced)*

### ⚠️ Manual Studio action required

- **Save the lobby place** — the `Clouds` layer is created at runtime and will be recreated, but saving keeps
  the place consistent with what has been verified.

## Verification

- [x] Always day; the clock does not advance
- [x] Weather drifts through all three seas, and the mix follows it
- [x] The painted storm does not move
- [x] Fog stays inside the water
- [x] Lightning fires; audio audible and moving
- [x] 18 shared files byte-identical
- [x] No syntax errors or new analyzer diagnostics; Play stopped; camera restored; Studio in Edit
- [ ] **Judge the look** — the horizon is limited by the ocean's size, not by the numbers
