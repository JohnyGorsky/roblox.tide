# TODO 0009: Intro loading screens and an in-transit teleport screen, as the Jungle game has

**Project:** `roblox.tide`
**Status:** open
**Created:** 2026-08-21 22:45:13

Requested by the user 2026-08-21: 'we need intro loading and loading between teleports like we have in jungle game'. Roadmap entry added under Stage 3.

TWO SEPARATE PIECES, and Jungle has both - copy the shape rather than inventing one.

1. INTRO LOADING, one per place. Reference: roblox.jungle.game/lobby/sync/ReplicatedFirst/LobbyLoading.local.luau (269 lines) and its game-place twin sync/ReplicatedFirst/GameLoading.local.luau. Both places in tide already have a synced ReplicatedFirst folder holding only a .gitkeep.

   The sequence Jungle uses: ReplicatedFirst:RemoveDefaultLoadingScreen() as early as possible, show a screen built in code, wait for game:IsLoaded(), ContentProvider:PreloadAsync in batches behind a progress bar, hold MIN_SHOWN 1.5s so it never just flickers, then SETTLE 2.5s after preload so texture streaming and lighting/shadows finish BEHIND the screen, then fade out over 0.6s.

   That settle step is the one worth keeping: it is what stops the player arriving to watch textures pop in and shadows resolve.

2. IN-TRANSIT TELEPORT SCREEN. Reference: roblox.jungle.game/lobby/sync/StarterPlayer/StarterPlayerScripts/UI/TeleportGui.local.luau, mirrored in the game place. Built and handed to TeleportService:SetTeleportGui(gui). The engine RE-PARENTS that GUI into the destination's loading context, so it must be entirely self-contained - no requires, no dependence on anything in the source place.

   This matters for tide specifically because the whole departure flow is a reserved-server teleport (Planned 0002), and a teleport with no screen is a black gap.

🔴 THE GOTCHA THAT SHAPES BOTH FILES: a ReplicatedFirst script runs BEFORE the rest of the game replicates - that is its entire purpose. So it CANNOT require a theme or component module out of ReplicatedStorage: the WaitForChild would block on exactly the replication the screen exists to hide. Jungle's own finding #0005 records this, and their solution is to hand-copy the palette values into the loading script with each one tagged with the token it mirrors, accepting that they must be kept in step by hand. Tide has no style guide yet (todo 0001, the tide-style skill), so whatever values go in here become a second thing to reconcile when it lands.

Sequencing: the teleport screen only earns its keep once the departure teleport exists (Planned 0002), so the intro screens are the half that can ship any time. Neither is blocked on anything else.
