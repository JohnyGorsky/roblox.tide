--!strict
-- Place settings drift audit for The Last Tide.
--
-- Spec: docs/systems/places/settings-baseline.md  (that file is the truth; this script only checks it)
-- Run via the Studio MCP (execute_luau, datamodel: Edit) against EITHER place — it detects which one
-- it is from game.PlaceId and applies the matching rows.
--
-- Output: one line per row — OK / DRIFT / FAILED — then a summary and the human-only checklist.
-- Re-run after anyone edits place settings, and after a Studio version bump.

local LOBBY_ID = 91870148721134
local GAME_ID = 100885379547959

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local Terrain = workspace.Terrain

-- { label, instance, property, expected, provisional? }
local shared = {
	{ "StarterGui.ScreenOrientation", StarterGui, "ScreenOrientation", Enum.ScreenOrientation.LandscapeSensor },
	{ "StarterPlayer.DevTouchMovementMode", StarterPlayer, "DevTouchMovementMode", Enum.DevTouchMovementMode.DynamicThumbstick },
	{ "StarterPlayer.AutoJumpEnabled", StarterPlayer, "AutoJumpEnabled", false },
	{ "StarterPlayer.CameraMinZoomDistance", StarterPlayer, "CameraMinZoomDistance", 6 },
	{ "StarterPlayer.EnableMouseLockOption", StarterPlayer, "EnableMouseLockOption", true },
	{ "StarterPlayer.LoadCharacterAppearance", StarterPlayer, "LoadCharacterAppearance", true },
	{ "HttpService.HttpEnabled", Http, "HttpEnabled", false },
	{ "Workspace.Gravity", workspace, "Gravity", 196.2 },
}

local gameRows = {
	{ "Players.MaxPlayers", Players, "MaxPlayers", 6 },
	{ "Players.PreferredPlayers", Players, "PreferredPlayers", 6 },
	{ "Players.CharacterAutoLoads", Players, "CharacterAutoLoads", false },
	{ "Players.RespawnTime", Players, "RespawnTime", 5 },
	{ "Workspace.StreamingEnabled", workspace, "StreamingEnabled", true },
	{ "Workspace.FallenPartsDestroyHeight", workspace, "FallenPartsDestroyHeight", -500 },
	{ "StarterPlayer.CameraMaxZoomDistance", StarterPlayer, "CameraMaxZoomDistance", 60 },
	{ "Terrain.WaterColor", Terrain, "WaterColor", Color3.fromRGB(18, 53, 74), true },
	{ "Terrain.WaterReflectance", Terrain, "WaterReflectance", 0.3, true },
	{ "Terrain.WaterTransparency", Terrain, "WaterTransparency", 0.25, true },
	{ "Terrain.WaterWaveSize", Terrain, "WaterWaveSize", 0.35, true },
	{ "Terrain.WaterWaveSpeed", Terrain, "WaterWaveSpeed", 12, true },
	{ "Lighting.FogEnd", Lighting, "FogEnd", 2500, true },
	{ "Lighting.FogColor", Lighting, "FogColor", Color3.fromRGB(140, 154, 163), true },
	{ "Lighting.OutdoorAmbient", Lighting, "OutdoorAmbient", Color3.fromRGB(70, 82, 92), true },
}

local lobbyRows = {
	{ "Players.MaxPlayers", Players, "MaxPlayers", 20 },
	{ "Players.PreferredPlayers", Players, "PreferredPlayers", 20 },
	{ "Players.CharacterAutoLoads", Players, "CharacterAutoLoads", true },
	{ "Players.RespawnTime", Players, "RespawnTime", 3 },
	{ "Workspace.StreamingEnabled", workspace, "StreamingEnabled", false },
	{ "StarterPlayer.CameraMaxZoomDistance", StarterPlayer, "CameraMaxZoomDistance", 40 },
	{ "Lighting.FogEnd", Lighting, "FogEnd", 5000, true },
}

-- Human-only rows: NotScriptable place properties, and experience-level Creator Hub settings.
local humanTodo = {
	"Lighting.LightingStyle         -> Realistic (user decision 2026-08-19; Properties panel, not scriptable)",
	"   Realistic is the mobile-expensive path - measure on the device emulator before shipping.",
	"Workspace.PhysicsSteppingMethod -> verify only, owned by feature 0001",
	"Players.MaxPlayers / PreferredPlayers -> File > Experience Settings (READ ONLY to scripts, incl. plugin context).",
	"   NOTE: an already-open place keeps reporting the value it loaded with, so this row can read",
	"   DRIFT even after you set it correctly. Reopen the place before trusting it.",
	"Playable devices               -> Phone, Tablet, Computer (Creator Hub)",
	"Avatar type                    -> R15 only (Creator Hub)",
	"Genre Adventure, private, no monetization yet (Creator Hub)",
}

local EPS = 0.001

local function matches(actual: any, expected: any): boolean
	if typeof(expected) == "number" and typeof(actual) == "number" then
		return math.abs(actual - expected) < EPS
	end
	if typeof(expected) == "Color3" and typeof(actual) == "Color3" then
		return math.abs(actual.R - expected.R) < EPS
			and math.abs(actual.G - expected.G) < EPS
			and math.abs(actual.B - expected.B) < EPS
	end
	return actual == expected
end

local function show(v: any): string
	if typeof(v) == "Color3" then
		return string.format("%d,%d,%d", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	end
	return tostring(v)
end

local placeId = game.PlaceId
local placeName, rows
if placeId == GAME_ID then
	placeName, rows = "GAME (The Last Tide Game)", gameRows
elseif placeId == LOBBY_ID then
	placeName, rows = "LOBBY (The Last Tide)", lobbyRows
else
	return ("UNKNOWN PLACE: placeId=%d is neither the lobby (%d) nor the game place (%d). "):format(placeId, LOBBY_ID, GAME_ID)
		.. "If a place was recreated, update the ids in this script and in settings-baseline.md."
end

local out = { ("PLACE SETTINGS AUDIT — %s  placeId=%d"):format(placeName, placeId), "" }
local ok, drift, failed = 0, 0, 0

local function check(row)
	local label, inst, prop, expected, provisional = row[1], row[2], row[3], row[4], row[5]
	local readOk, actual = pcall(function() return inst[prop] end)
	local tag = provisional and " (prov)" or ""
	if not readOk then
		failed += 1
		table.insert(out, ("FAILED  %-40s cannot read%s"):format(label, tag))
	elseif matches(actual, expected) then
		ok += 1
		table.insert(out, ("OK      %-40s %s%s"):format(label, show(actual), tag))
	else
		drift += 1
		table.insert(out, ("DRIFT   %-40s is %s, spec says %s%s"):format(label, show(actual), show(expected), tag))
	end
end

for _, row in ipairs(shared) do check(row) end
table.insert(out, "")
for _, row in ipairs(rows) do check(row) end

table.insert(out, "")
table.insert(out, ("SUMMARY  %d ok, %d drift, %d unreadable"):format(ok, drift, failed))
if drift > 0 then
	table.insert(out, "-> Either re-apply the spec, or change settings-baseline.md if the new value is intended.")
end
table.insert(out, "")
table.insert(out, "HUMAN-TODO (cannot be checked from here):")
for _, t in ipairs(humanTodo) do
	table.insert(out, "  - " .. t)
end

return table.concat(out, "\n")
