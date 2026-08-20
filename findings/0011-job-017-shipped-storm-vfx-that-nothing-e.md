# FINDING 0011: Job 017 shipped storm VFX that nothing ever started, and the storm still looked like it worked

**Project:** `roblox.tide`
**Status:** open
**Severity:** high
**Created:** 2026-08-20 15:13:20

**Symptom:** StormVFX was written in job 017 with rain, spray and wind-blown debris, and NO client script ever required it. The game place had no StarterPlayerScripts entry except AdminClient, so those emitters had never run a single time. It went unnoticed through a full manual test because the storm's other four channels - sky, fog, brightness, atmosphere - are composed on the SERVER by DayNight.compose and replicate on their own. Walking the front in from 4.2 km therefore produced a visibly changing world with zero particles, and nothing about it read as broken. Two lessons. (1) A client module is not wired up until something in StarterPlayerScripts requires it; 'the module exists and its API is correct' is not the same as 'the effect happens', and a server-composed world will hide the difference. (2) Verification has to name the CHANNEL, not the feature: 'the storm changes the look' was true and useless. Fixed in job 018 by adding WeatherClient.local.luau (which also starts the cloud wall and audio, and rebuilds both rigs when the camera is replaced on respawn) plus an admin tool 'Rain / spray / cloud wall status' with scope=local, so the question 'is the client half actually running' can be asked directly rather than inferred.
**Where:** studio_game/StarterPlayerScripts (was empty of everything but AdminClient)
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
