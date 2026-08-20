# Job #005: Build tracking board and graybox register

**Project**: `roblox.tide`
**Created**: 2026-08-19 23:31:37
**Status**: Requirements Gathering (intake)

## Requirements / goal

Give the project a single at-a-glance answer to 'what needs building, what is built', and a way to never lose track of a placeholder. Agreed via wizard. (1) Add an area field to every feature's frontmatter - sea, boat, atmosphere, islands, lobby, navigation, combat, crew, character - and to the feature template, so the flat numbered list gains the grouping the user thinks in. (2) Generate BUILD-STATUS.md from the feature files plus assets.yaml plus the Jobs folder, rather than hand-maintaining it, so status can never disagree with the features that own it: features supply planned work and their status ladder, assets.yaml supplies asset and graybox counts, and a job with a final-summary.md counts as delivered foundation work. This is only possible because job 001 fixed the feature frontmatter into valid YAML. (3) Graybox register: assets.yaml gains status GRAYBOX plus a represents field naming the eventual real asset, placeholders get a CollectionService 'Graybox' tag in Studio, and tools/audit-graybox.luau diffs the live places against the registry so an untracked grey block is caught rather than trusted to be listed. Document the convention in assets/README.md.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
