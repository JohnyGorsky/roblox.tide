# FINDING 0021: The vessel spec labels +Z as the bow, but the hull drives toward -Z

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-21 09:15:48

**Symptom:** Vessel.luau's data treats local +Z as FORWARD: buoyancyPoints call z=+16 'port bow' and z=-16 'port quarter', sockets put helm at z=+8, hardpointFwd at z=+15 and engine at z=-14. VesselServer drives the hull along CFrame.LookVector, which in Roblox is local -Z, and its heel comment states this explicitly ('forward is LookVector, which is the hull's -Z'). The TRIM comment in the same file contradicts it ('hull +Z is forward, +X is starboard').

So every part the spec calls forward is at the end the vessel is travelling AWAY from: the helm console sits at the stern, the damage-control station (job 022) sits at the bow, and hardpointFwd faces astern.

Invisible today, which is why it survived: the hull is a symmetric box, the buoyancy points are symmetric about both axes (+/-16, +/-5.5), and the trim lever is |z| so it is sign-independent. Nothing measured in job 021 is wrong. A helm somewhat aft is even plausible for a launch.

It bites the moment real geometry arrives - a modelled wheelhouse, a bow gun, a visible engine box - because the socket offsets place them all at the wrong end, and the symptom will be 'the boat drives backwards' rather than 'the labels are reversed'.

NOT fixed in job 022. Flipping the convention moves every socket and re-opens the heel and trim figures that were measured against the current geometry (heel 9/12 deg, trim 2.5/3.5 deg, pitch stiffness 1,022,683 N-stud/deg), and the job that changes it should be the one that measures it again.

Fix options when it is addressed: (a) negate every Z in the spec's sockets and keep LookVector as forward - smallest diff, matches the engine; or (b) keep the spec's labels and drive along -LookVector - smaller conceptual change but fights the engine's own convention everywhere else, which is how the job 021 thrust sign bug happened in the first place. Prefer (a).
**Where:** studio_game/ReplicatedStorage/Vessel.luau (STARTER_LAUNCH sockets, buoyancyPoints) vs VesselServer force aiming
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
