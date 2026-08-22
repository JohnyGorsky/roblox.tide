# FINDING 0026: A gentle shore cannot avoid the shelf artifact at all - only a discontinuity can

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-22 01:04:14

**Symptom:** The terrain skill says no land surface may sit between the water level and WATER_Y+8, and job 024 measured 240 offending columns of a 400-column shoreline as the floor for a gentle bank. That framing hides the real conclusion: any CONTINUOUS profile crossing the waterline must put some column's surface inside the forbidden band, so steepening the ramp only reduces the count and can never reach zero. Job 027's first sculpt measured 335 offending columns, visible as flat sheets on the sea. Making the drop a DISCONTINUITY - jump straight from beachTop to faceBottom with nothing generated between - took it to exactly 0 off the landing arc, because no column's surface can land in a band no column targets. The renderer bridges the two adjacent columns with a ~72 degree face, which is still walkable.
**Where:** IslandTemplates.heightAt, roblox-terrain skill section 4
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
