# FINDING 0023: Fixing the storm published the vessel's position to every client as a side effect

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-21 19:04:38

**Symptom:** Job 022 fixed WorldTick.vesselZ (finding 0020) so northward travel finally buys distance. StormFront.advance stores the previous measurement in order to compute travel, and it stored it in a WORKSPACE ATTRIBUTE - StormLastVesselZ. Workspace attributes replicate, so from the moment the fix landed every client could read the hull's northward Z coordinate, updated once a second.

That is the same leak VesselHeading was deleted for in the same job, arriving by a different door. A client watching StormLastVesselZ rise knows it is heading north, which is exactly the free heading oracle decision 0014 forbids inside The Wall - and the WorldTick comment written in this very job argues against publishing a VesselZ attribute for that reason, while the storm's own bookkeeping was already doing it.

Caught by listing every Vessel/Storm-prefixed attribute visible from the CLIENT datamodel, rather than by checking the one attribute I had just removed. Reading back only what you changed would not have found it.

Why it was harmless before: vesselZ never resolved, so the attribute was written once as 0 by reset() and never updated. The value was meaningless, so nobody looked at it.

Fixed in job 022: the last position is now a module-level upvalue in StormFront, and reset() clears the retired attribute if a session or saved place still carries it. An upvalue is also strictly more correct - the other storm attributes are shared because clients read them and must agree with the server, whereas nothing outside advance() has ever read this one and only the server calls advance().

Generalisable lesson: when a fix makes a previously dead code path live, audit what that path WRITES, not just what it returns. And check leaks from the client's side - enumerate the attributes a client can actually see, because the wire is the thing being audited, not the diff.
**Where:** studio_game/ReplicatedStorage/StormFront.luau (ATTR_LAST_POS)
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
