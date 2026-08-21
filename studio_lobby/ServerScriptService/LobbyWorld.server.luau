--!strict
--[[
	LobbyWorld - the harbour's sky, sea and the storm that never arrives.

	Feature: GAME-0013  ·  decisions 0018, 0024  ·  job 025

	--------------------------------------------------------------------------------------------------
	🔴 THE LOBBY PAINTS A STORM. IT DOES NOT RUN ONE.

	`StormFront` is deliberately NOT copied into this place. It was going to be, with its advance gated off -
	but the better answer turned out to be simpler: every sensory system (the cloud wall, the rain, the
	lightning, the audio bed) reads WORKSPACE ATTRIBUTES, not the module. So the lobby sets those attributes
	statically and never ships the clock at all.

	The result is that "the storm never arrives" is true BY CONSTRUCTION rather than by a flag somebody could
	flip. There is no advance function in this place to call by accident.

	--------------------------------------------------------------------------------------------------
	WHY THE SEA IS PINNED SEPARATELY FROM THE STORM

	In the game place one number drives everything: distance picks a band, the band picks a sea state. That
	coupling is right at sea and wrong here - the lobby wants a CALM harbour with a DRAMATIC horizon, and the
	game's model cannot express that, because a distance close enough to draw a cloud wall also selects a
	Storm sea.

	So the two are set independently:

	    StormDistance   1000   places the wall on the horizon and arms the lightning (intensity 2)
	    StormIntensity  2      the lightning floor - Lightning.MIN_INTENSITY
	    StormWind       0.12   LOW, deliberately: wind is what drives rain and spray, and a rainy harbour
	                           is not what "storm in the distance" means
	    SeaState        LightSwell   calm water, chosen directly rather than derived

	That is the whole trick, and it is only available because job 020 separated the sea override from the
	storm's own bookkeeping.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNight = require(ReplicatedStorage:WaitForChild("DayNight"))
local LocalWeather = require(ReplicatedStorage:WaitForChild("LocalWeather"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))
local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))

--[[
	The static picture. Re-asserted on every tick rather than set once, because anything that writes these
	attributes - a stray admin tool, a copied script, a future job - would otherwise change the harbour
	permanently and silently. Cheap, and it makes the lobby's look immune to drift.
]]
local HORIZON = {
	distance = 1000,
	intensity = 2,
	wind = 0.12,
	sea = "LightSwell",
}

--[[
	The lobby's ocean is its own patch and SMALLER than the game's corridor: ~2044 studs across against
	6144 x 6500. So its fog has to be tighter, and the job-007 rule still applies - fog must stay inside the
	water or the sea visibly stops and the map reads as a box.

	Measured in the survey: the lobby's water runs to about +/-1022, so 1900 was already too generous. 900
	keeps the horizon comfortably inside it while still showing the wall at 1000... which is the trade: the
	wall sits just BEYOND the fog, so it reads as a mass in the haze rather than as a wall with a visible
	base. That is the look, and it is why the numbers are these numbers.
]]
local LOBBY_FOG_END = 900

local function paintHorizon()
	workspace:SetAttribute("StormDistance", HORIZON.distance)
	workspace:SetAttribute("StormIntensity", HORIZON.intensity)
	workspace:SetAttribute("StormWind", HORIZON.wind)
	workspace:SetAttribute("StormSheltered", true) -- the harbour IS shelter; nothing reads it here, but it is true
	--[[
		`SeaOverride` rather than `SeaState` alone. Job 020 added it so a manual choice survives a system that
		rewrites the value every tick; here it is the mechanism that keeps the sea calm no matter what else
		decides to have an opinion.
	]]
	workspace:SetAttribute("SeaOverride", HORIZON.sea)
	workspace:SetAttribute("SeaState", HORIZON.sea)
end

--[[
	The cloud layer has to exist before the composer can drive it, and it is not in the place by default.
	Same reasoning as the game's `WorldTick`: a place with no `Clouds` child composes perfectly happily with
	no clouds at all - no error, just a permanently clear sky, which reads as a design choice.
]]
if not workspace.Terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
	print("[LOBBY] created the Clouds layer (the place had none)")
end

paintHorizon()

-- the wave field needs a state to blend from, or HeightAt has nothing to work with
local state = SeaStates.get(HORIZON.sea)
if state then
	WaveField.setState(state, 0)
end

LocalWeather.step()
DayNight.start("Day") -- the harbour opens in daylight; the game place is where night means something

--[[
	1 Hz, matching the game's tick. The look changes over minutes and `compose()` writes a dozen properties
	plus six sky ContentIds, so per-frame would be waste for no visible gain.
]]
local TICK = 1
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	accumulated = 0

	paintHorizon()

	local okWeather, weatherErr = pcall(LocalWeather.step)
	if not okWeather then
		warn("[LOBBY] weather step failed: " .. tostring(weatherErr))
	end
	local okLook, lookErr = pcall(DayNight.compose)
	if not okLook then
		warn("[LOBBY] compose failed: " .. tostring(lookErr))
	end

	--[[
		Clamp the fog AFTER the composer, because the composer sets it from the sea state and would otherwise
		put the game place's much longer view distance on the lobby's much smaller pond.
	]]
	Lighting.FogEnd = math.min(Lighting.FogEnd, LOBBY_FOG_END)
end)

print(("[LOBBY] world started. storm painted at %d studs, intensity %d, wind %.2f, sea %s, fog <= %d")
	:format(HORIZON.distance, HORIZON.intensity, HORIZON.wind, HORIZON.sea, LOBBY_FOG_END))
