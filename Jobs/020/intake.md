# Job #020: Admin panel: collapsible sections, client-side tools, time-of-day and audio solo

**Project**: `roblox.tide`
**Created**: 2026-08-20 21:31:39
**Status**: ✅ Completed

## Requirements / goal

Three things, one of which is a bug found while answering how to test the new audio. (1) THE BUG: every tool runs on the SERVER. AdminClient always calls remote:InvokeServer, and AdminServer's handle() invokes tool.run directly, so 'scope' is only metadata about what a tool AFFECTS - it does not control where the handler EXECUTES. That means every tool which inspects CLIENT state is reporting from a context where nothing was ever started: 'Rain / spray / wall / lightning status' and 'Audio status' both require client modules on the server, where StormVFX, CloudWallVFX, StormAudio and Ambience have no rigs and no beds, so they truthfully report nothing running. It went unnoticed because my own tests ran in a single Edit context where the modules HAD been started by the test itself. Fix: give AdminClient a client-side execution path for tools that inspect or affect client state. The tool definitions stay in ServerStorage for everything that changes the world - that security property is untouched - but read-only client diagnostics and client-local audio control need to run where the state actually lives. (2) THE PANEL IS TOO CROWDED at 33 tools in one flat scrolling list. Make the sections COLLAPSIBLE, collapsed by default except the one in use, so the panel opens as a short list of section headers rather than a wall. Section order should follow how often a section is actually reached for. (3) TWO MISSING TEST CONTROLS, both thin wrappers over functions that already exist and neither exposed anywhere: a TIME OF DAY control (DayNight.jumpTo for Dawn/Day/Dusk/Night plus pause and resume) which today means waiting up to 9.5 minutes for a phase to come round and which blocks judging the night look at all, not just the birds; and a SOLO CHANNEL control that mutes every audio bed except one, because nine beds play at once and picking one out by ear is genuinely hard - deadCalm is deliberately near-subsonic and birds peak at 0.22. Solo belongs in AudioBed as a module-level setting so one implementation covers both StormAudio and Ambience, and it must also suppress the gust and thunder one-shots, which do not go through a bed. NOTE the studio-skill gotcha that applies directly here: a system which rewrites a value every tick will clobber a manual override, so solo must be applied INSIDE the step that sets the volumes, not written over the top of them.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed (small job; scope settled in the intake itself)
- [x] Implementation completed
- [x] Final summary + changelog written
