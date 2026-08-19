# FINDING 0005: Social Slots enabled on the game place may admit uninvited joins mid-expedition

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-19 23:29:03

**Symptom:** Creator Hub > Places > The Last Tide Game > Access > Server Settings > Social Slots is 'Roblox optimized'. Social slots reserve capacity so a player's friends can join their server, which is right for a harbour lobby and wrong for a 6-slot expedition: an expedition is a closed run with defined crew roles, and a friend dropping in mid-run undermines both the crew composition and the reserved-server model in decision 0013. Recommended: set the GAME place to 'Disable' and leave the LOBBY on 'Roblox optimized'. Worth re-checking once matchmaking/party flow is actually built (feature 0009 / roblox-multiplayer), since reserved servers may make this moot. Human-only setting.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
