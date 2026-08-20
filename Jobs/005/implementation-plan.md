# Implementation Plan — Job #005

**Project**: `roblox.tide`
**Created**: 2026-08-19 23:49:23
**Status**: Planning (awaiting go-ahead)

## Analysis

Agreed via wizard. The repo already had four separate places status could live; what it lacked was one place to read it from, and any record of placeholders. Approach: derive, never duplicate. Feature frontmatter already owns feature status (and job 001 made it valid YAML, which is what makes parsing possible); assets.yaml owns asset status; a job with a final-summary.md is delivered work. BUILD-STATUS.md is generated from those three plus the new docs/build manifest, and carries a do-not-edit banner. For graybox, the registry alone would rely on memory, so it is paired with a CollectionService tag and an audit that diffs live places against the registry - the duplication between the two is deliberate and self-correcting, because a mismatch is reported rather than hidden.

## Implementation steps

1. Add area to all 10 feature frontmatters and to the template
2. Write tools/build-status.py generating BUILD-STATUS.md from features, assets.yaml, Jobs and docs/build; support --check for staleness
3. Document the graybox convention in assets/README.md: status GRAYBOX, mandatory represents field, CollectionService tag, and the replacement flow
4. Write tools/audit-graybox.luau reporting TRACKED / UNTRACKED / MISSING / UNTAGGED suspects
5. Run the audit against a live place and tune the heuristic so engine objects are not false positives
6. Link the board and manifest from docs/INDEX.md and the tide-project skill

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
