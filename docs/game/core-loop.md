# Core Loop

## Moment-to-moment loop

```text
Navigate
→ detect POI
→ choose risk/reward
→ stop and explore
→ loot resources/parts
→ return to boat
→ repair / upgrade / refuel
→ continue forward
```

## Day/night heartbeat

```text
DAWN
repair + choose direction
↓
DAY
explore + loot + upgrade
↓
DUSK
return-to-boat panic
↓
NIGHT
move forward + defend + survive
↓
DAWN
relief + assess damage
```

Initial tuning target:

- Dawn: 30–45 sec
- Day: 4–5 min
- Dusk: ~45 sec
- Night: 3–4 min

These are prototype values, not final balance.

## The run, with numbers (decision 0024)

Measured out of what the storm and the day/night cycle were already tuned to, not chosen:

```text
board            5 min grace, the front visible and STATIONARY
~10 stops        4 deep islands at 5-6 min  +  6 quick sea POIs at 1-2 min
                 ~18 min travelling, ~32 min stopped
make northing    brings the finale
the finale       a hostile vessel; beating it ends the expedition
                 total: ~50 minutes
```

The tension in one line: **two deep visits cost 66% of the storm's cushion, three cost 99%.** So you can
afford two before you must make real northing — and the radar's distance readout is what makes that a
decision rather than a surprise.

Fuel is the spine: 18 minutes of travel burns **six tanks**, i.e. 0.6 of a tank per stop just to break even.
You go ashore to find the fuel that lets you keep going.

⚠️ This run length needs **19,800 studs** of travel — 3.2x the width of the current ocean patch. See
[finding 0018](../../findings/0018-a-crew-can-reach-the-edge-of-the-bounded.md); it gates the design.

## Macro loop

```text
Start expedition
→ move through sea stages
→ storm follows
→ nights escalate
→ boat build diverges
→ rare POIs/events appear
→ boss / extraction / death
→ permanent rewards
→ next expedition
```

## Failure should still progress the account

End-of-run summary should reward:

- expedition XP
- role mastery
- discoveries/codex entries
- recovered blueprints
- cosmetics/achievement progress
- highest sea stage reached

Most in-run boat power resets so later expeditions remain tense.
