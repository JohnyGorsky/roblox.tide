# Final Summary — Job #020

**Project**: `roblox.tide`
**Completed**: 2026-08-20
**Status**: ✅ Completed

## What was implemented

Three things, and the first was a bug found while answering "how do I test the new sounds?".

**`scope` WAS METADATA, NOT AN EXECUTION CONTEXT.** Every tool declares `scope` as `"global"` or `"local"`,
documented as *global changes the world for everyone, local affects only the caller*. That is a statement
about what a tool AFFECTS, and it had been quietly read as though it also controlled WHERE the handler runs.
It does not: `AdminClient` always calls `remote:InvokeServer`, and `AdminServer` invokes `tool.run` itself, so
**every handler executes on the server**.

So the tools that inspect client-side state — *Rain / spray / wall / lightning status* and *Audio status* —
required `StormVFX`, `CloudWallVFX`, `LightningVFX`, `StormAudio` and `Ambience` on the *server*, where those
modules have never been started, because only `WeatherClient` requires them. They returned a truthful report
about a context in which nothing exists: no rigs, no beds, `running=false`. Confidently, silently wrong.

It went unnoticed for exactly the reason [finding 0011](../../findings/0011-job-017-shipped-storm-vfx-that-nothing-e.md)
did: my checks ran inside one Studio Edit context that had *itself* started those modules moments earlier, so
the state the handler looked for happened to be there. **A test that constructs the thing it verifies proves
nothing about production.** [Finding 0017](../../findings/0017-admin-tool-scope-was-metadata-not-an-exe.md), high.

Fixed with a `CLIENT_HANDLERS` table in `AdminClient`, keyed by tool id: if a client handler exists, it runs
locally and never touches the network. Definitions stay in `ServerStorage`, so labels and options still come
from the server, and **everything that changes the world still goes through the server's authorisation** —
that boundary is untouched. Only read-only diagnostics and client-local audio moved. Four tools: `vfxReport`,
`audioReport`, `audioSolo`, `audioAudition`.

The general rule worth keeping: ask where the STATE lives, not what the tool affects. State built on the
client can only be inspected on the client, and no `scope` field can fix that.

**THE PANEL WAS TOO CROWDED** at 33 tools in one flat scrolling list — you scrolled past four sections to
reach the one you wanted, and the sheer length read as complicated rather than capable. Sections are now
**collapsible**, everything collapsed except the first, so it opens as **six headers you can read at a
glance** instead of 35 controls in a row. The caret is the whole affordance; without it a header reads as a
label rather than a control.

Sections are also ordered **deliberately rather than alphabetically**, which had put Audio first and Sea in
the middle — meaningless to anyone using the panel. Now by how often a section is reached for while working:
**Storm → Weather → Sea → Audio → Diagnostics**. The order lives in `AdminTools` (server-side, one place),
and the client opens *whichever section comes first* rather than a named one, so the two cannot drift apart.
`currentParent` is what kept this small: the build helpers parent into the live section, so adding a tool
needs no knowledge of sections at all.

**TWO MISSING TEST CONTROLS**, both thin wrappers over functions that already existed and neither exposed
anywhere:

- **Time of day** (Dawn / Day / Dusk / Night / pause / resume). `DayNight.jumpTo` has existed since job 016
  and was reachable from nothing, so changing the hour meant waiting up to 9.5 minutes for a phase to come
  round. That blocked judging the **night look at all**, not just whether the gulls go quiet. Server-side,
  correctly — the clock is shared state. It composes immediately, because a control that appears to do
  nothing for a beat reads as broken.
- **Solo one channel**, muting every bed except one. Nine beds play at once and picking one out by ear is
  genuinely hard: `deadCalm` is near-subsonic by design and `birds` peaks at 0.22.

**Solo lives in `AudioBed` as a module-level setting**, so one implementation covers both `StormAudio` and
`Ambience` — and it is applied **inside** the step that computes the volumes, not written over the top. That
is not stylistic: every bed rewrites its voices' `Volume` every tick, so an external write is clobbered
within 100 ms. It is the same trap the Studio guidance flags for any continuously-written value. Verified by
soloing and then running **20 further mix ticks**: `birds` went 0.213 → 0.000 and stayed there.

Gusts and thunder are one-shots that never pass through a bed, so they check `AudioBed.audible` by hand. The
gust timer advances *before* that check, or a muted gust would never reschedule and one would fire the
instant solo lifted — which reads as the panel making a noise.

**CORRECTED AFTER TESTING — solo did nothing for most channels.** The user soloed `thunder` and got dead
silence, and reported that a lot of the buttons did nothing. Both true, and it was my design being wrong
rather than the audio.

The first version only *muted the others*. The soloed channel kept whatever level the world was asking for —
and at default conditions (Light Swell, daylight, no storm, low wind) **six of the nine channels are
legitimately at zero**: measured `oceanHeavy`, `deadCalm`, `stormBed`, `windHigh` and `rain` all silent, plus
`thunder`, which is a one-shot that only exists when lightning strikes. So soloing any of those muted
everything and left nothing, which is indistinguishable from a broken control.

Three fixes:

1. **Solo now forces the channel to its own `maxVolume`**, regardless of conditions. The question a tester is
   asking is "what does this clip sound like", not "what is the mix doing with it". Verified: all eight beds
   audible when soloed (0.227–0.703) where five were previously 0.000, with no leakage from the others.
2. **`naturalLevel()` keeps the honest number**, and the readout shows both — `◀ SOLO (forced; mix wants 0.00)`
   — so forcing it up does not hide what the mix would really do.
3. **Soloing `thunder` fires a strike**, because it has no bed to force up. It also says so, and points at
   *Storm → Force a lightning strike* for hearing it in context.

The panel also tells you what each channel is *driven by* (`deadCalm` → "severity below 0.15 only. Sea → Sea
state → DeadCalm"). Without that, "this channel is quiet because conditions are wrong" and "this channel is
broken" look identical — which is exactly the confusion that produced this report.

**AND THE CHOICE CONTROL WAS ITSELF A WALL.** Ten full-width stacked buttons for the solo control
reintroduced, inside one section, precisely the crowding the collapsible sections were meant to fix. Controls
with more than five options now wrap into **two columns**. Two rather than three because the labels here are
words like `oceanHeavy` and `0.15 km THE WALL`, which truncate at a third of the width; tap targets stay 32px
so the mobile guidance is still satisfied.

### Files changed

- `studio_game/ReplicatedStorage/AudioBed.luau` — `setSolo` / `solo` / `audible` / `naturalLevel`, folded
  into the mix; solo forces the channel audible
- `studio_game/ReplicatedStorage/StormAudio.luau` — one-shots honour solo; report shows it
- `studio_game/ReplicatedStorage/Ambience.luau` — report shows solo
- `studio_game/StarterPlayerScripts/AdminClient.local.luau` — `CLIENT_HANDLERS`, collapsible sections,
  two-column choice controls, per-channel "driven by" text
- `studio_game/ServerStorage/AdminTools.luau` — `timeOfDay`, `audioSolo`, `SECTION_ORDER`
- both `studio_lobby/` copies kept byte-identical
- `findings/0017`

### The panel now

```text
▾ STORM         8 tools
▸ WEATHER       3
▸ SEA          15   (+ Time of day)
▸ AUDIO         3   (+ Solo one channel)
▸ DIAGNOSTICS   6
▸ AUDIT
```

### Open

- `Sea` is now the fat section at 15 tools. If it gets worse it wants splitting — the colour pickers
  (water / fog / atmosphere / decay) are one obvious sub-group.
- The non-admin refusal test still needs a stable Play session. Note it now needs re-running against the
  client-side path too: those four tools no longer pass through the server's gate at all, which is correct
  because they change nothing shared, but it is a change to the surface being attacked.
