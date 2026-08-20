# 08 — Lobby & shipyard

**Group:** the harbour you return to — the Shipyard, your fleet, your parts, your crew roster, and the
departure that starts an expedition.
**Items:** ~54
**Depends on:** nothing structural. **Can be built in parallel with everything else** — it is a separate
place (`studio_lobby/`).
**Feeds:** the entire reason to finish a run.

Systems: [shipyard](../systems/shipyard/README.md) · [progression](../game/progression.md) ·
[places](../systems/places/README.md) · decisions [0011](../decisions/0011-shared-expedition-rewards.md),
[0012](../decisions/0012-parts-progression.md), [0013](../decisions/0013-two-places-lobby-and-game.md)

---

## What the lobby is for

Between runs, calm and persistent: spend parts, build ships, dress your crew, form a party, depart. It has
no ocean simulation, no storm and no combat — which is exactly why it is a separate place, and why
`StreamingEnabled` is **off** here so the Shipyard UI never waits.

The emotional job of the lobby is **making progress visible**. A player who has done ten runs should be
able to *see* it — a bigger ship at their dock, a fuller parts shelf, a crew who look like veterans.

⚠️ The harbour is hand-placed in the editor, not generated at runtime. Scripts should find objects by name
and attach behaviour — the same convention used in the other games here.

---

## A. Harbour environment — 14 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Harbour terrain & water | Sheltered bay; calm water, visibly *not* the open sea | ⚠️ | studio |
| Main dock | Where the player's active vessel sits | ⚠️ | studio |
| Fleet berths | Additional berths, filling as the fleet grows | ⚠️ | studio |
| Shipyard building | Where construction projects happen | ⚠️ | meshy |
| Dry dock / slipway | A ship under construction, visibly progressing | ⚠️ | studio |
| Parts warehouse | Where the parts inventory lives, physically | ⚠️ | meshy |
| Crew quarters | Where the NPC roster is managed | ⚠️ | meshy |
| Harbour master's office | Departure, sea-stage selection | ⚠️ | meshy |
| Departure gate | The literal way out to sea | ⚠️ | studio |
| Notice board | Dailies, seasonal content, patch notes | ⚠️ | studio |
| Lighting rig | Warm, safe, contrasting with the game place | ❌ | code |
| Harbour props | Reuses the group-03 kit heavily | ✅ | meshy |
| Cosmetics display | Where paint, flags and lanterns are previewed | ⚠️ | studio |
| Skybox & mood | Overcast but safe; the storm not visible here | ⚠️ | store |

## B. Fleet & vessel display — 8 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Vessel display rig | Show any owned vessel at a berth, correctly dressed | ❌ | code |
| Active vessel selection | Choose which ship you sail | ❌ | code |
| Vessel inspection view | Walk around it, see its modules | ❌ | code |
| Upgrade preview | See a module fitted before committing parts | ❌ | code |
| Construction progress display | A hull visibly assembling as parts are contributed | ⚠️ | code |
| Cosmetic application | Paint, flags, lantern styles, weathering, trim | ❌ | code |
| Vessel stat comparison | Class tradeoffs, readably (not "bigger = better") | ❌ | code |
| Locked-vessel display | Show what you have not earned — aspiration | ⚠️ | code |

## C. Shipyard progression — 12 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Parts inventory model | Persistent, per account (DataStore) | ❌ | code |
| Upgrade tree per system | Hull, engine, fuel, generator, radar, lights, storage, hardpoints | ❌ | code |
| Upgrade cost tables | Parts + rare components per tier | ❌ | code |
| Construction projects | Multi-session builds toward a new vessel class | ❌ | code |
| Rare component slots | The `✗ / ✓` requirements that create targeted goals | ❌ | code |
| Duplicate handling | Roll into next tier, or convert to Salvage — no dead rewards | ❌ | code |
| Salvage side-currency | Minor costs, cosmetics, crew hiring | ❌ | code |
| Blueprint unlocks | Recovered plans enabling new projects | ❌ | code |
| Departure point unlocks | Deeper starts: harder, richer | ❌ | code |
| Starting-config presets | Save a loadout you like | ❌ | code |
| **Server-side spend validation** | Parts spending validated server-side, exactly like in-run actions | ❌ | code |
| Progression persistence | Save/load with session locking; the dupe-protection story | ❌ | code |

## D. Crew & identity — 8 items

| Item | What it is | GB | Source |
|---|---|---|---|
| NPC roster model | Owned crew, levels, traits, availability | ❌ | code |
| Crew hiring | Where new NPCs come from | ❌ | code |
| Crew assignment | Which roles they will fill on the next expedition | ❌ | code |
| Crew cosmetics | Uniforms, hats, themes | ❌ | code |
| Role mastery display | Captain / Engineer / Navigator / Gunner / Scavenger / Medic | ❌ | code |
| Codex / discoveries | What you have found; the collection drive | ❌ | code |
| Achievements | Long-tail goals | ❌ | code |
| Player cosmetics | Captain outfits, raincoats, diving gear | ❌ | code |

## E. Party & departure — 12 items

| Item | What it is | GB | Source |
|---|---|---|---|
| Party formation | Group up in the lobby | ❌ | code |
| Party UI | Who is in, who is captain, who is ready | ❌ | code |
| Role claiming | Pick your station before departure | ❌ | code |
| Loadout selection | Weapons and supplies you bring | ❌ | code |
| Sea-stage selection | Which departure point, with its tradeoffs | ❌ | code |
| Reserved-server teleport | Party → a private expedition server | ❌ | code |
| Teleport failure handling | Retries and a graceful fallback — this *will* fail sometimes | ❌ | code |
| Return handling | Coming back from a run, into the summary | ❌ | code |
| End-of-run summary | XP, mastery, parts found, discoveries, highest stage | ❌ | code |
| Reward crediting | Every eligible participant, individually (decision 0011) | ❌ | code |
| Solo departure | One player + NPC crew; must not feel like a penalty | ❌ | code |
| Rejoin protection | What happens if someone disconnects mid-run | ❌ | code |

---

## Suggested job split

1. **Harbour greybox** — A as a walkable blockout with named anchor objects. Judge the space before art.
2. **Persistence foundation** — C's inventory model and progression persistence, with session locking.
   *Nothing else in this group is real without it.*
3. **Parts & upgrades** — the upgrade tree, cost tables, server-side spend validation. Feature 0010.
4. **Fleet display** — B. Making progress visible.
5. **Construction projects** — multi-session builds, rare component slots, blueprints.
6. **Party & departure** — E, including reserved-server teleport and its failure handling.
7. **End-of-run summary** — the return trip and reward crediting.
8. **Crew & identity** — D. Pairs with group 10.
9. **Harbour art pass** — replace the greybox with real art once the layout is proven.

## Open questions

- **Is the lobby persistent-world or per-party?** A shared harbour with 20 players is social; a private
  one is calmer and simpler. Max players is set to 20, which implies shared.
- **Can you see other players' ships?** Powerful aspiration, and a meaningful amount of work.
- **Does the lobby have any gameplay** beyond menus-in-3D? A fishing spot, a test-drive circuit and a
  firing range would make it somewhere to *be*, not just pass through.
- **Where does the end-of-run summary happen** — in the game place before teleporting back, or in the
  lobby on arrival? The lobby is safer: if the teleport fails, the rewards are already banked.
