--!strict
--[[
	WorldTick - the one heartbeat that drives the world's look.

	Job 016 built `DayNight.compose()` and nothing called it, so the sky only changed when something
	happened to poke it. This is that caller.

	It is deliberately ONE loop rather than one per system, because the order matters:

	    1. advance the storm      -> sets distance, intensity, StormWind, and picks a sea state
	    2. step everyday weather  -> reads the storm, publishes Wind / Precipitation / WaveScale / FogScale
	    3. compose the look       -> reads time of day, the sea state, and those modifiers; writes the world

	Each step reads the one before it, so the order is load-bearing in two places, not one. Run the storm
	after the weather and the weather combines against a stale wind; run the composer first and the sky lags
	the storm by a second. One loop, fixed order, no ambiguity.

	Feature: docs/features/0003-storm-front/  ·  decisions 0018, 0020  ·  jobs 017, 018
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNight = require(ReplicatedStorage:WaitForChild("DayNight"))
local StormFront = require(ReplicatedStorage:WaitForChild("StormFront"))
local LocalWeather = require(ReplicatedStorage:WaitForChild("LocalWeather"))

--[[
	1 Hz.

	The look changes over minutes, not frames, and `compose()` writes a dozen properties plus six sky
	ContentIds - doing that every frame would be waste for no visible gain. The phase blend interpolates
	continuously, so a 1-second step is invisible.

	Wind is the exception: sensory systems want it smoother than 1 Hz, so they should interpolate toward
	the published value rather than snapping to it.
]]
local TICK = 1

--[[
	TIME SCALE - a testing affordance, and the reason job 018 exists at all.

	The front closes 4200 studs at 14 studs/s, so watching a real approach takes FIVE MINUTES. The admin
	panel's distance buttons sidestep that by teleporting the front, which is fine for checking that a look
	is correct and useless for judging whether the escalation *builds* - jumping between five distances
	shows five separate looks, not an approach. This is what lets the approach be watched compressed.

	It scales the STORM only. Everyday weather is a pure function of server time and cannot be sped up the
	same way, so it has `forecast()` and `setOverride()` instead.

	⚠️ It scales the front's ADVANCE but not the vessel's travel, because travel is measured from real
	positions. So at scale 10 a moving crew loses ground ten times faster than they should. That is correct
	for looking at the approach and wrong for balancing it - never tune ADVANCE_RATE with a scale set.

	Read from an attribute every tick rather than cached, so it can be changed mid-session from the panel.
	Clamped: a scale high enough to close the whole distance inside one tick would skip every band between
	here and The Wall, which is exactly the escalation we are trying to look at.
]]
local ATTR_TIME_SCALE = "TimeScale"
local MAX_TIME_SCALE = 60

local function timeScale(): number
	local s = workspace:GetAttribute(ATTR_TIME_SCALE)
	if typeof(s) ~= "number" then
		return 1
	end
	return math.clamp(s, 0, MAX_TIME_SCALE)
end

local function vesselZ(): number?
	--[[
		Northward progress buys distance from the storm (decision 0019). There is no vessel yet, so this
		returns nil and the front simply closes - which is the correct behaviour for a crew that cannot
		move, and exactly what a fuel-less crew will experience.

		When GAME-0001 lands, return the hull's Z here.
	]]
	local vessels = workspace:FindFirstChild("Vessels")
	local hull = vessels and vessels:FindFirstChild("Hull")
	if hull and hull:IsA("BasePart") then
		return hull.Position.Z
	end
	return nil
end

--[[
	The cloud layer has to EXIST before the composer can drive it, and it is not in the place by default.

	Created here rather than left to a manual Studio step, because a place that silently has no `Clouds`
	child composes perfectly happily with no clouds at all - there is no error, just a permanently clear sky
	while every other channel of the storm works. That is a bad failure: it looks like a design choice.
]]
if not workspace.Terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
	print("[WORLD] created the Clouds layer (the place had none)")
end

StormFront.reset()
LocalWeather.step() -- publish the modifiers before the first compose, or it reads nil and falls back to 1
DayNight.start("Dawn")

print(("[WORLD] tick started. cycle %ds, storm %.0f studs astern, advance %.1f studs/s, weather %s")
	:format(DayNight.CYCLE_SECONDS, StormFront.distance(), StormFront.ADVANCE_RATE,
		tostring(workspace:GetAttribute("WeatherLabel"))))

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	local step = accumulated
	accumulated = 0

	-- order is load-bearing at every step: see the header
	local okStorm, stormErr = pcall(StormFront.advance, step * timeScale(), vesselZ())
	if not okStorm then
		warn("[WORLD] storm advance failed: " .. tostring(stormErr))
	end

	local okWeather, weatherErr = pcall(LocalWeather.step)
	if not okWeather then
		warn("[WORLD] weather step failed: " .. tostring(weatherErr))
	end

	local okLook, lookErr = pcall(DayNight.compose)
	if not okLook then
		warn("[WORLD] compose failed: " .. tostring(lookErr))
	end
end)
