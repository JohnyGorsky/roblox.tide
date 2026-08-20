# Job #013: Admin panel: atmosphere and palette colour controls

**Project**: `roblox.tide`
**Created**: 2026-08-20 12:24:01
**Status**: Requirements Gathering (intake)

## Requirements / goal

The panel already tunes terrain water and fog distance, but job 007 established that Atmosphere and the sky dominate the sea's apparent colour while WaterColor is a weak lever - so the most important half of sea tuning is not yet reachable from the panel. Add live Atmosphere sliders (Density, Offset, Haze, Glare) and palette-constrained colour pickers for Atmosphere colour, Atmosphere decay, fog colour and water colour. Colours are chosen from the visual-design palette rather than freeform RGB, so tuning by eye cannot drift off-palette and so the UI stays thumb-friendly instead of needing nine numeric fields. Also extend Copy-as-Luau to emit Atmosphere as real pasteable fields rather than comments, which is what makes a value found by dragging a slider survive the session. This is the tool that unblocks judging the sea look as far as it can be judged before the overcast sky assets arrive.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
