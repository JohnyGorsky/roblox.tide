# FINDING 0003: Players.MaxPlayers is not observable from Studio

**Project:** `roblox.tide`
**Status:** fixed (2026-08-19) — CONFIRMED CORRECT by the user's Creator Hub screenshots 2026-08-19: The Last Tide Game shows Maximum Visitor Count = 6, The Last Tide Lobby shows 20. So the cloud values match the spec and Studio's persistent 60 reading is purely a Studio-side blind spot, as suspected. Verified path is Creator Hub: Creations > The Last Tide > Places > <place> > Access > Basic Settings > Maximum Visitor Count. Note the Creator Hub calls it 'Maximum Visitor Count', not 'Max Players'. The audit correctly no longer asserts this row.
**Severity:** med
**Created:** 2026-08-19 23:26:52

**Symptom:** Reads 60 in Edit and 60 in a Play Server context regardless of what Experience Settings holds. Verified three ways on 2026-08-19: fresh Edit session, Edit session after a full place reopen, and a Play Server datamodel - all reported 60 while the spec calls for 6 (game) and 20 (lobby). Studio's local playtest server does not allocate from the cloud experience config, so the value simply cannot be checked from inside Studio. Consequence: tools/audit-place-settings.luau no longer asserts MaxPlayers/PreferredPlayers, because a permanently-DRIFT row trains people to ignore the whole audit; it is reported as a human-verify item instead. Still open: nobody has confirmed the cloud value is actually 6/20. Confirm by reading File > Experience Settings, or on a live published server, and close this.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
