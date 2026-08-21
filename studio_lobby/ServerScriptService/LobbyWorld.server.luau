--!strict
--[[
	LobbyWorld - a harbour that is always daylight, with weather that never settles.

	Feature: GAME-0013  ·  decisions 0018, 0020, 0024  ·  job 025

	--------------------------------------------------------------------------------------------------
	🔴 THE LOBBY PAINTS A STORM. IT DOES NOT RUN ONE.

	`StormFront` is deliberately NOT copied into this place. Every sensory system - the cloud wall, the rain,
	the lightning, the audio bed - reads WORKSPACE ATTRIBUTES rather than the module, so the lobby sets those
	directly and never ships the clock at all.

	"The storm never arrives" is therefore true BY CONSTRUCTION rather than by a flag somebody could flip:
	there is no advance function in this place to call by accident.

	--------------------------------------------------------------------------------------------------
	ALWAYS DAY

	`DayNight.pause()` freezes the clock where it stands, so starting at Day and pausing gives permanent
	daylight with the full composer still running. The alternative - deleting the day/night cycle from the
	lobby - would also have meant losing the weather composition that hangs off it.

	Night belongs to the expedition. A lobby that goes dark is a lobby where players cannot see the boat they
	are about to sail, and the harbour's job is to be legible.

	--------------------------------------------------------------------------------------------------
	WEATHER THAT CYCLES, AND THE DECISION IT BENDS

	`LocalWeather` already does the hard part: `unsettled()` is a slow drift derived from server time, so it
	looks random, repeats on no obvious period, and every client computes the same value without a remote.
	It publishes wind, precipitation, wave scale and fog scale on each `step()`.

	⚠️ **A SCOPED EXCEPTION TO DECISION 0020.** That decision says everyday weather may move wind, waves,
	rain and fog and may NOT touch the sky, brightness, ambient or severity. The lobby breaks the second
	half, on purpose, and the reason the rule exists is why it can:

	    decision 0020 protects the STORM'S LEGIBILITY - a calm spell must never be able to mask an
	    approaching front, because the front is the thing that kills you.

	The lobby has no approaching front. Nothing here can be masked, so there is nothing to protect, and a
	harbour whose sky never changes is a screensaver. **The game place still obeys 0020 in full** - this file
	is the only exception and it must stay that way.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNight = require(ReplicatedStorage:WaitForChild("DayNight"))
local LocalWeather = require(ReplicatedStorage:WaitForChild("LocalWeather"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))
local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))

--[[
	The storm on the horizon. Static: distance places the cloud wall, and intensity 2 is
	`Lightning.MIN_INTENSITY` - the floor at which strikes are rolled at all. Below it the horizon goes
	quiet, so 2 is what keeps distant lightning in the harbour's sky.
]]
local HORIZON = { distance = 1000, intensity = 2 }

--[[
	THE WEATHER BAND. Calm to moderate, and deliberately no further.

	    unsettled     sea         field amplitude   render waves   brightness
	    0.00 - 0.30   DeadCalm    0.08 - 0.24       0.02           2.6   glassy, best light
	    0.30 - 0.68   LightSwell  0.44 - 1.28       0.18           3.0   the everyday harbour
	    0.68 - 1.00   Choppy      1.10 - 3.20       0.45           2.4   "almost bad" - whitecaps, grey
	                                                                     light, rain on the wind

	The amplitude ranges are the sea state's own figure multiplied by `LocalWeather.waveScale()`, which runs
	0.55 to 1.60 - so the two sources of variation compound and the water is rarely doing the same thing
	twice.

	🔴 IT STOPS AT CHOPPY. Storm (amplitude 4.5, brightness 1.6) and The Wall (7.5, 0.30) are the STORM'S
	language, not the weather's, and a harbour that reaches them is no longer a safe place to stand - it is
	the thing the expedition is running away from. "Almost bad" is the brief and Choppy is where that lands.

	This also answers "increase max waves": the ceiling went from LightSwell's 1.28 studs to Choppy's 3.20,
	two and a half times higher, and the render waves from 0.18 to 0.45.
]]
local BANDS = {
	{ upTo = 0.30, sea = "DeadCalm" },
	{ upTo = 0.68, sea = "LightSwell" },
	{ upTo = math.huge, sea = "Choppy" },
}

--- Seconds to blend between sea states. Long, because the whole point is weather that turns rather than snaps.
local SEA_BLEND = 25

--[[
	The lobby's ocean is its own patch and much SMALLER than the game's corridor - about 2044 studs across
	against 6144 x 6500. The job-007 rule still applies: fog must stay inside the water or the sea visibly
	stops and the map reads as a box.

	⚠️ This is also what currently limits how dramatic the harbour can look: a 900-stud view washes the
	horizon out, including the storm wall it exists to show. Growing the lobby's ocean is the fix, and it is
	a saved-place change - see the job 025 intake.
]]
local LOBBY_FOG_END = 900

local currentSea: string? = nil

local function seaFor(unsettled: number): string
	for _, band in ipairs(BANDS) do
		if unsettled <= band.upTo then
			return band.sea
		end
	end
	return "LightSwell"
end

local function paintHorizon()
	--[[
		Re-asserted every tick rather than set once: anything that writes these - a stray admin tool, a
		copied script, a future job - would otherwise change the harbour permanently and silently.

		Wind is no longer a fixed number here - it is bridged from the weather just below, which is what makes
		the rain and spray rise and fall with the cycle instead of sitting at one value forever.
	]]
	workspace:SetAttribute("StormDistance", HORIZON.distance)
	workspace:SetAttribute("StormIntensity", HORIZON.intensity)
	workspace:SetAttribute("StormSheltered", true) -- the harbour IS shelter
	--[[
		🔴 `StormWind` HAS TO BE PUBLISHED HERE, and forgetting it made the lobby windless.

		There are two wind attributes and they are not the same one:

		    `Wind`       what `LocalWeather.step()` publishes - the weather's own figure
		    `StormWind`  what `StormVFX` and `StormAudio` actually READ - the master sensory control

		In the game place `StormFront.apply()` bridges them. The lobby has no `StormFront`, so when the
		static pin was removed to let the weather cycle, nothing set `StormWind` at all: it read nil, and the
		rain emitters and the high-wind audio bed sat at exactly zero while everything else worked. Measured -
		`Bed_rain_1` and `Bed_windHigh_1` were playing at volume 0.000.

		So the lobby does the bridging itself, which is also what makes the rain and the wind rise and fall
		with the weather cycle rather than being decoration.
	]]
	workspace:SetAttribute("StormWind", LocalWeather.wind())
	--[[
		`SeaOverride` is CLEARED, not set. The first version of this file pinned it to hold the sea calm -
		which then blocked this file's own weather cycle from changing it. Nothing in the lobby competes for
		`SeaState` (there is no `StormFront` here), so the override has no job and would only get in the way.
	]]
	if workspace:GetAttribute("SeaOverride") ~= nil then
		workspace:SetAttribute("SeaOverride", nil)
	end
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

-- seed the sea so the wave field has something to blend from
local startSea = seaFor(LocalWeather.unsettled())
local startState = SeaStates.get(startSea)
if startState then
	WaveField.setState(startState, 0)
	workspace:SetAttribute("SeaState", startSea)
	currentSea = startSea
end

LocalWeather.step()
DayNight.start("Day")
DayNight.pause() -- always day; the clock is frozen and the composer keeps running

local TICK = 1
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	accumulated = 0

	paintHorizon()

	--[[
		Order matters here exactly as it does in the game's `WorldTick`: the weather publishes its modifiers
		FIRST, then the sea is chosen, then the composer reads both. Compose first and the look lags the
		weather by a tick.
	]]
	local okWeather, weatherErr = pcall(LocalWeather.step)
	if not okWeather then
		warn("[LOBBY] weather step failed: " .. tostring(weatherErr))
	end

	local want = seaFor(LocalWeather.unsettled())
	if want ~= currentSea then
		local state = SeaStates.get(want)
		if state then
			--[[
				ONE blend drives everything - the water, the light, the fog and the cloud layer all follow
				from the sea state, which is why this is a single call and not four.
			]]
			WaveField.setState(state, SEA_BLEND)
			workspace:SetAttribute("SeaState", want)
			print(("[LOBBY] weather turning: %s -> %s (unsettled %.2f, %s)")
				:format(tostring(currentSea), want, LocalWeather.unsettled(),
					LocalWeather.label(LocalWeather.unsettled(), LocalWeather.precipitation())))
			currentSea = want
		end
	end

	local okLook, lookErr = pcall(DayNight.compose)
	if not okLook then
		warn("[LOBBY] compose failed: " .. tostring(lookErr))
	end

	--[[
		Clamp the fog AFTER the composer, which sets it from the sea state and would otherwise put the game
		place's much longer view distance on the lobby's much smaller pond.
	]]
	Lighting.FogEnd = math.min(Lighting.FogEnd, LOBBY_FOG_END)
end)

print(("[LOBBY] world started. always day, storm painted at %d studs (intensity %d), weather cycles %s, fog <= %d")
	:format(HORIZON.distance, HORIZON.intensity, "DeadCalm -> LightSwell -> Choppy", LOBBY_FOG_END))
