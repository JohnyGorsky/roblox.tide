# FINDING 0020: A hardcoded instance path between two systems rotted silently and made the storm unbeatable

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-21 09:05:56

**Symptom:** WorldTick.vesselZ() looked for workspace.Vessels.Hull. VesselServer parents the model straight to Workspace under the spec id, so the real path is workspace.StarterLaunch.Hull - the folder Vessels never existed. The lookup returned nil on every tick from job 021 until job 022, StormFront.advance never received a vesselZ, and GAIN_PER_STUD was never once applied. StormDistance could therefore only ever DECREASE: outrunning the storm was not hard, it was arithmetically impossible.

Why it hid so well: the comment beside it said 'There is no vessel yet, so this returns nil and the front simply closes - which is the correct behaviour for a crew that cannot move'. That was TRUE when written at job 017 and stopped being true at job 021. So the symptom read as a deliberate design choice rather than a defect, in a system nobody had reason to re-read.

It also could not be caught by eye: the storm closing steadily is exactly what the game is supposed to look like, and the whole macro loop was untestable without anyone knowing.

Fix (job 022): read the server-side handle _G.TideVessel.state.hull instead of guessing an instance path, and WARN ONCE if no vessel has appeared within 30 seconds, so the next occurrence announces itself.

Deliberately NOT fixed by publishing a VesselZ Workspace attribute, which was the obvious option: attributes replicate, and a client watching its own northward coordinate rise knows it is heading north - the free heading oracle decision 0014 forbids inside The Wall. Server-side state stays in _G.

Generalisable lesson: when one system reaches into another by instance path, the path is an undeclared contract with nothing enforcing it. Prefer the owner's own exported handle, and make absence loud.
**Where:** studio_game/ServerScriptService/WorldTick.server.luau (vesselZ)
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
