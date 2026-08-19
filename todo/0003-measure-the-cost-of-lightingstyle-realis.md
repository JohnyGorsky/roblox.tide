# TODO 0003: Measure the cost of LightingStyle=Realistic on a phone

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-19 23:21:40

Both places were set to LightingStyle=Realistic on 2026-08-19 (user decision, overriding the Soft recommendation). Realistic is the high-quality lighting path and suits the night/storm art direction, but it is the expensive one on mobile and its cost here is completely unmeasured. Measure before shipping: ask permission first, then Test > Device with a phone preset, and compare frame timing with Realistic vs Soft on the same scene - ideally once there is real geometry, water and night lighting rather than a baseplate. Also test PrioritizeLightingQuality true vs false at the same time, since it trades shadow range against view distance and open water cares about view distance. If Realistic proves too expensive, the fallback is Soft plus stronger Atmosphere/fog work rather than losing the mood.
