# Vessel damage & the storm's teeth

Implementation reference for [decision 0023](../../decisions/0023-storm-damage-model.md), which implements
[0014](../../decisions/0014-storm-consequence.md). Built in job 022.

For the *why* behind every number, read the decision. This is the map: what lives where, what the numbers
currently are, and what will break if you change the wrong one.

## Where it lives

| File | Owns |
|---|---|
`ReplicatedStorage/VesselDamage.luau` | the damage model. Pure maths — integrity, rates, the fault ladder, flooding, capsize, repair. No instances, no attribute writes
`ReplicatedStorage/StormFront.luau` | `exposure()`, `wallAt()`, `secondsToEscape()`, `minEscapeSpeed()` — all storm constants, so they belong to the storm
`ReplicatedStorage/Vessel.luau` | `spec.survivability`, and the `damageControl` station socket
`ServerScriptService/VesselServer.server.luau` | the only thing that touches instances: applies damage, fires faults, holds the capsize timer, sinks her, builds the station and the compass
`StarterPlayerScripts/VesselClient.local.luau` | animates the compass card. Reads geometry, sends nothing
`ServerStorage/AdminTools.luau` | `Damage report`, `Set hull integrity`, `Inflict fault` (Vessel) and `Survival test` (Storm)

The split to keep: **the storm says how bad it is out there; the vessel says what that does to this hull.**
Folding exposure into `VesselDamage` would let it disagree with the storm's own band, which produces "the sky
says Wall and nothing is taking damage".

## The numbers, as they stand

| | Value | Set in |
|---|---|---|
Starter launch survivability | 45 s of full exposure | `Vessel.luau` spec
Integrity pool | mass × 0.25 = **1,050** | `VesselDamage.INTEGRITY_PER_MASS`
Rate at full exposure | 1050 / 45 = **23.3 /s** | derived
Exposure | 0 at distance ≥ 260, 1 at distance ≤ 0, squared into the rate | `StormFront.exposure`
Fault ladder | radar 20% · generator 40% · engine 60% · breach 75% | `VesselDamage.LADDER`
Engine cut | 8 s, self-relighting | `ENGINE_CUT_SECONDS`
Steering damage | rudder authority × 0.45 | `STEERING_AUTHORITY`
Flooding | +0.06/s open, −0.02/s closed, max 35% lift lost | `FLOODING_RATE` / `FLOODING_DRAIN_RATE` / `MAX_FLOODING_LIFT_LOSS`
Capsize | past 100° held 4 s | `CAPSIZE_DEGREES` / `CAPSIZE_SECONDS`
Repair | 12% of the pool per action, 3 s hold | `REPAIR_FRACTION`

Escape arithmetic, from the storm's own constants — this is what the survivability is tuned against:

```
net at cruise 18 due north = 18 × 1.6 − 14 = +14.8 studs/s
17.6 s to clear the front from distance 0 · 48.0 s from 450 deep
8.75 studs/s = the slowest speed that gains any ground at all
```

## Published state

All on `Workspace`, all server-written. A crew may know the state of their own vessel — a hull gauge and a
BREACH lamp are diegetic instruments (group 09).

`VesselIntegrity` · `VesselIntegrityMax` · `VesselFlooding` · `VesselLost` ·
`VesselFault_radar` / `_generator` / `_engine` / `_breach` / `_steering` · `ExpeditionOver` ·
`ExpeditionOverReason`

**`VesselHeading` is gone and must not come back** — see decision 0023.

## Testing it

`Storm → Survival test (measured)`, two modes. Both drive the real loop; neither simulates anything.

- **hold position** — should die at about `survivability` (45 s). Checks the curve against the spec.
- **escape run** — should clear the front in the high teens with real integrity gone. Checks the curve against
  the storm's constants.

It refuses to run with `TimeScale ≠ 1`, because the world tick scales the front's advance but not the
vessel's travel, so every number would be wrong in a direction that looks like a damage bug.

Faster loops: `Vessel → Inflict fault` for one fault at a time, `Set hull integrity` to park the hull at a
level without firing the ladder, `Damage report` for the full picture including seconds-to-loss and
seconds-to-escape.

## Traps

🔴 **Never mutate a derived constant to model damage.** Steering damage is a flag read at the point of use.
Scaling `state.rudderAuthority` would make the damage permanent and would silently de-tune the heel, which was
solved against the undamaged value when the vessel was built.

🔴 **Flooding scales the float force *after* the clamp.** The clamp is the divergence guard that stopped the
hull destroying itself in job 021; scaling its result down can never breach a ceiling. Reducing the stiffness
that feeds it would move the equilibrium the whole kit is solved for.

🔴 **`state.lost` is checked before `recoverIfLost`.** That function exists to rebuild a hull the *engine*
removed after a divergence, and it cannot tell that apart from one we sank on purpose. Reverse the order and a
lost vessel is quietly replaced with a fresh one.

🔴 **`fired` and `faults` are separate sets.** `faults` is what is wrong now and repairable; `fired` records
which rungs have gone off. Merge them and repairing a breach while integrity is still below its threshold
re-breaks it on the next frame — damage control becomes a button that does nothing.

🔴 **The compass takes no fault, ever.** It is the floor beneath pillar 6. Threaten the chart instead.

## Verified 2026-08-21 (job 022)

Measured in a running session, not judged by eye.

| Check | Result |
|---|---|
Hold position at full exposure | **lost at 45.5 s** against 45 declared (101%) |
Fault ladder thresholds | radar 9.6 s/20% · generator 18.5 s/40% · engine 27.6 s/60% · breach 34.4 s/75% — exact |
Engine cut is transient | fired at 27.6 s, relit ~8 s later on its own |
Escape run from distance 0 | **cleared the front at 27.9 s** with 74% of the hull left (26% spent) |
Northward travel buys distance | steady state **+12.84 studs/s** measured against +12.94 theory — **99.2%** |
Buoyancy converges under flooding | 62 s at 100% flooding in a Storm sea: amplitude 4.28 → 4.27 (growth 0.999), waterline held, max tilt 15° |
Waterline at full flooding | 0.31 studs lower in Light Swell, 1.15 lower in a Storm sea |
Loss path | engine dead, helm released, all four float forces zeroed, sinks upright, `ExpeditionOver` set |
Lightning consumer | `[VESSEL] lightning raised generator -> generator` — job 018's dead fault rolls now bite |
Compass tracks heading | card counter-rotated a heading sweeping 78.7°, `rotation = -heading` throughout |
No heading on the wire | `VesselHeading` nil from a client; full client-visible attribute list audited |
Admin panel | 44 tools, all scopes valid, **built exactly once** |

### Still needs your eyes

Two things a probe cannot answer, both because a backgrounded Studio window does not render
(finding 0022):

1. ~~Compass orientation.~~ **Approved by eye 2026-08-21** — it reads correctly, so `COMPASS_SIGN = -1`
   and `COMPASS_OFFSET_DEG = 0` stand. Approved as a reading, not as a look: the vessel is a graybox
   (`GB-STARTER-LAUNCH`) and gets restyled with the real boat. The rules that must survive that restyle are
   in the registry entry's `survives_the_restyle` block — read it before redrawing the binnacle.
2. **The damage-control prompt.** Present and configured (3 s hold, 10-stud range), but `Triggered` cannot be
   fired from a script, so the repair path has never been exercised by a hold.

Also unmeasured: readability of the compass at The Wall's brightness of 0.30. `LightInfluence = 0` should
make it immune, and that is exactly the kind of "should" worth one screenshot.

## Still owed

- todo 0005 — should lightning be able to damage steering?
- todo 0006 — the real end-of-expedition flow; vessel loss is a placeholder
- finding 0021 — the spec's forward labels are reversed, so the station and the helm are at opposite ends
  from the ones their names imply
- radar and generator faults are flags until `GAME-0002` and deck lighting exist
- repair has no resource cost until group 03
