# FINDING 0018: A crew can reach the edge of the bounded ocean inside a single expedition - the sea does not actually feel infinite once something can cross it

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-20 23:20:41

**Symptom:** Found by driving the vessel rather than by reading anything. The ocean is a bounded terrain patch with OCEAN_HALF_EXTENT 3072, so 6144 studs across. The starter launch cruises at 18 studs per second. Centre to edge is therefore 171 seconds, or 2.8 minutes. For comparison the storm arrives in 300 seconds and a full tank lasts 182 seconds at full ahead. So the ONLY thing currently hiding the edge of the world is the fuel tank, and it hides it by twelve seconds. Any fuel upgrade, any drum of spare fuel, or any vessel faster than the starter launch immediately exposes a hard wall of nothing at the horizon - and group 02 explicitly plans faster vessels, while group 03 plans jerry cans as loot. This matters because 'make the sea feel infinite' is a stated design goal for group 01 and the reason the fog and horizon work exists at all. The memory rule about never leaving a visible map edge is about the same problem from the visual side. Options, none yet chosen: grow the terrain patch (cheap - 36 FillRegion tiles took 0.68s in job 007, and OCEAN_HALF_EXTENT is a single constant, but it scales as the square and fog must stay inside it); recentre the world on the vessel periodically so the patch follows the boat, which is the standard endless-ocean trick and makes the sea genuinely unbounded but complicates absolute positions and the storm's Z-based distance model; or fence it in-fiction with a soft boundary that turns the crew back, which is cheapest and weakest. This needs a decision before any faster vessel or fuel upgrade ships, not after.
**Where:** docs/systems/places/settings-baseline.md + SeaStates.OCEAN_HALF_EXTENT vs the vessel's cruise speed
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
