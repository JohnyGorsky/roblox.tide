# Job #001: Scaffold roblox.tide for the multi-root workspace

**Project**: `roblox.tide`
**Created**: 2026-08-19 22:19:13
**Status**: Requirements Gathering (intake)

## Requirements / goal

Fit the existing The Last Tide design pack into workspace conventions without changing its documents. (1) Fix the generator bug that left all 10 docs/features/*/feature.md indented 4 spaces, breaking their YAML frontmatter and rendering their bodies as code blocks - formatting only, content preserved word-for-word. (2) Create the tide-project skill (thin pointer) so the game's rules actually load, since a game CLAUDE.md does not auto-load in the multi-root workspace. (3) Add the shared job/capture folders: Jobs, Planned, todo, findings. (4) Add .jobconfig.json and default.project.json for a top-level studio/ Rojo sync root. Do NOT touch docs/INDEX.md, CLAUDE.md, README.md, or any design content.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
