# Implementation Plan — Job #001

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:19:30
**Status**: Planning (awaiting go-ahead)

## Analysis

The repo is docs-only: CLAUDE.md, README.md, docs/ (game, systems, decisions, content, features, roadmap), assets/ (registry, meshy templates, palette). It is already in roblox.workspace.code-workspace and now registered in tools/job.py (workspace Job #010). Three real gaps: (a) all 10 feature.md files were written with 4-space indentation, so the --- frontmatter block is invalid YAML and the entire body renders as a fenced code block; (b) tide's CLAUDE.md cannot load in the multi-root workspace - only the primary dir's does - so its rules and the IMPLEMENTED-is-not-VERIFIED discipline are invisible without a skill; (c) no Jobs/Planned/todo/findings, no Rojo project, no sync tree. User decisions via wizard: keep docs/features as design memory with Jobs for execution; sync root is a top-level studio/ folder; dedent only (no frontmatter field additions, no INDEX edits); tide-project skill only (no tide-style skill yet, no CLAUDE.md header note).

## Implementation steps

1. Dedent all 10 docs/features/*/feature.md by 4 spaces; verify frontmatter parses and no content bytes change apart from leading whitespace
2. Create .claude/skills/tide-project/SKILL.md - thin pointer naming The Last Tide in its description, carrying the hard rules and pointing at docs/INDEX.md rather than duplicating the docs tree
3. Create Jobs/ (exists), Planned/, todo/, findings/ with .gitkeep where empty
4. Create .jobconfig.json listing studio/ service paths as synced_paths / non_synced_paths
5. Create default.project.json mapping the DataModel to studio/<Service> (name roblox.tide)
6. Create the studio/ service folders: ReplicatedFirst, ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer/StarterPlayerScripts, StarterPlayer/StarterCharacterScripts
7. Verify: frontmatter parses on all 10 features, git status shows no modifications to design docs, tide job tooling round-trips

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification

- [ ] _TODO: how we confirm it works_
