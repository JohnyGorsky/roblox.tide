# Final Summary — Job #005

**Project**: `roblox.tide`
**Completed**: 2026-08-19 23:49:23
**Status**: ✅ Completed

## What was implemented

Two tracking mechanisms, both built so they cannot quietly go stale. BUILD BOARD: all 10 features gained an area field (boat, navigation, atmosphere, islands, combat, character, crew, lobby) and so did the template; tools/build-status.py generates BUILD-STATUS.md from four sources that each already own their fact - feature frontmatter for planned work and status, assets.yaml for asset and graybox counts, the Jobs folder for delivered work (a job with a final-summary.md counts as delivered), and docs/build for the manifest. Nothing is hand-maintained, so the board cannot disagree with the features; it carries a do-not-edit banner and a --check mode that exits non-zero when stale, ready for a pre-commit hook. GRAYBOX REGISTER: assets/README.md now documents the convention - status GRAYBOX plus a MANDATORY represents field naming the real asset, a CollectionService Graybox tag on the instance, and the rule that the entry disappearing is the record of replacement. tools/audit-graybox.luau diffs the live place against the registry and reports TRACKED, UNTRACKED (tagged in Studio but unregistered - the failure the convention exists to catch), MISSING (registered but absent) and UNTAGGED suspects found by heuristic. Verified against the live game place: it correctly found nothing tagged and flagged the default Baseplate as a suspect, but also flagged Terrain and SpawnLocation, so the heuristic now ignores engine-owned and functional classes. Also recorded the sizing lesson in the convention: a graybox of the wrong size teaches wrong sightlines, collision and deck space, so intended dimensions go in notes. TWO BUGS HIT AND FIXED: a heredoc-mangled backslash wrote chr(1) into all 10 feature frontmatters instead of a newline, silently destroying the status line - caught by re-parsing every file rather than assuming the edit worked, and the files turned out to be CRLF, which the repair preserved. A second parser bug truncated the manifest summaries at their line wrap.

### Files changed

_Tooling and docs; no game code._

- `tools/build-status.py`
- `tools/audit-graybox.luau`
- `BUILD-STATUS.md`
- `assets/README.md`
- `docs/INDEX.md`
- `.claude/skills/tide-project/SKILL.md`

### How to use it

```text
python tools/build-status.py           regenerate the board
python tools/build-status.py --check   fail if stale (pre-commit / CI)
tools/audit-graybox.luau               run over MCP against either place
```

Change a feature's status in its own `feature.md`, then re-run the generator. Never edit
BUILD-STATUS.md.

## Verification

- [x] All 10 features re-parsed after the area edit: id, name, area, status, priority, last_verified present
- [x] `chr(1)` corruption from the heredoc bug found and repaired; CRLF endings preserved
- [x] `build-status.py` runs clean; `--check` reports current immediately after a write
- [x] Board renders all 8 areas, the roll-up, 12 manifest groups with item counts, and 6 jobs
- [x] Graybox audit run live against the game place; heuristic tuned after false positives
- [x] Every relative link in the repo resolves
- [ ] Graybox audit against a place that actually contains a tagged graybox — **nothing tagged yet**
