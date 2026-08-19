# FINDING 0004: Game place Direct Access Control is Fully Open, contradicting decision 0013

**Project:** `roblox.tide`
**Status:** open
**Severity:** med
**Created:** 2026-08-19 23:29:03

**Symptom:** Creator Hub > Places > The Last Tide Game > Access > Direct Access Control is set to 'Fully Open', and the page notes 'You've made an exception for this place'. Fully Open means the place is joinable by ALL means - insecure client teleports from any universe, deep links, game invites, and joining a user from their profile. Decision 0013 says players arrive in the lobby and reach an expedition only by teleporting as a crew, so a stranger deep-linking straight into a running 6-slot expedition breaks the design. Recommended: 'Secure within Universe only' - joinable only via secure SERVER teleports within the universe - which is exactly the lobby-to-game flow, and also blocks a client-side exploit from spoofing a join. Set 'Limited to same Universe' instead only if we end up needing client-initiated teleports. The lobby place should stay Fully Open since it is the start place players are meant to enter directly. Human-only setting.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
