--!strict
--[[
	LocalWeather - the day's own weather, which has nothing to do with the storm.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	--------------------------------------------------------------------------------------------------
	WHY THIS EXISTS

	Before this module, sea state was derived ONLY from storm distance. That had two costs:

	  * the world was mechanical - every change in the water was a threat signal, so a day never simply
	    WAS a day, it was a countdown with weather-shaped ticks;
	  * and it diluted the storm - if only the front can raise a wave, the crew reads any wave as the front.

	Making an afternoon breeze ordinary is what lets the real thing be frightening.

	--------------------------------------------------------------------------------------------------
	🔴 WHAT THIS MAY TOUCH, AND WHAT IT MAY NOT

	    ✅  wind      - rain angle, spray, cloth, later the helm
	    ✅  waves     - both the rendered water and our own field, via the wave scale
	    ✅  rain      - showers pass over on perfectly ordinary days
	    ✅  fog       - a bank rolls in and the horizon closes a little

	    ❌  the sky            ❌ brightness            ❌ ambient
	    ❌  severity           ❌ atmosphere density/haze

	The second row is "the darker side", and it stays owned by the hour of the day and by the storm. A
	passing shower must NOT dim the world, because dimming is the storm's language and borrowing it puts
	us straight back to every change reading as a threat. So this module publishes MODIFIERS - it never
	selects a sea state, and it never writes Lighting.

	--------------------------------------------------------------------------------------------------
	DETERMINISTIC, SO NOBODY HAS TO REPLICATE IT

	The drift is a sum of sines over `Workspace:GetServerTimeNow()`. Same input on the server and on every
	client, so all contexts compute the same weather without a single attribute needing to be trusted -
	and gusts land on the same frame for everyone. It also means the weather can be FORECAST, which is
	what `forecast()` below is for: being able to see what is coming is the only practical way to test a
	system whose whole point is that it takes minutes to change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local LocalWeather = {}

--[[
	Published modifiers. Deliberately named for what they DO, not for where they came from, because
	consumers should not care whether the wind blowing on them is the weather's or the storm's.
]]
local ATTR_WIND = "Wind" -- 0..1, combined. StormWind stays separate for threat logic.
local ATTR_PRECIP = "Precipitation" -- 0..1, combined. NOT a storm cue - see decision 0020.
local ATTR_WAVE_SCALE = "WaveScale" -- multiplier on wave amplitude and rendered wave size
local ATTR_FOG_SCALE = "FogScale" -- multiplier on composed fog distance
local ATTR_LABEL = "WeatherLabel" -- human-readable, for the admin panel
local ATTR_OVERRIDE = "WeatherOverride" -- 0..1 pins the drift, for testing

--[[
	Periods in seconds, deliberately mutually awkward so the sum does not visibly repeat.

	The shortest is 91s: weather has to change over MINUTES to read as weather. At 20s it reads as a
	flicker, which is worse than no variation at all because it looks like a bug.
]]
local DRIFT_PERIODS = { 91, 149, 227, 383 }
local SHOWER_PERIODS = { 71, 181, 311 }

--- Sum of sines over `periods`, mapped to 0..1. Phase-offset per term so t=0 is not a shared peak.
local function noise(t: number, periods: { number }): number
	local sum = 0
	for i, p in ipairs(periods) do
		sum += math.sin((t / p) * 2 * math.pi + i * 1.7)
	end
	return math.clamp((sum / #periods) * 0.5 + 0.5, 0, 1)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

--[[
	THE RANGES.

	Wind tops out at 0.45, not 1.0, and that ceiling is the whole safety property: everything sensory
	scales off wind, so a weather ceiling below the storm's range guarantees an ordinary day can never
	LOOK like the front. 0.45 matches Choppy's severity by design - the worst an afternoon gets is a
	working sea.
]]
LocalWeather.WIND_MIN = 0.04
LocalWeather.WIND_MAX = 0.45

--- Below 1 the sea is glassier than its state describes, above 1 steeper. Never flattens it completely.
LocalWeather.WAVE_SCALE_MIN = 0.55
LocalWeather.WAVE_SCALE_MAX = 1.60

--- Fog only ever CLOSES in (and barely opens up on the clearest days).
LocalWeather.FOG_SCALE_MIN = 0.72
LocalWeather.FOG_SCALE_MAX = 1.06

--[[
	A shower needs the channel above this to start, so most of the time it is simply dry.

	Measured: 0.62 left it raining 30% of the time, which is not "showers pass over" - it is a wet climate,
	and frequent rain is exactly what stops rain being noticed. 0.72 lands near 15%.
]]
LocalWeather.SHOWER_THRESHOLD = 0.72
--- Heaviest an ordinary shower gets. Storm rain reaches 1.0; this does not.
LocalWeather.SHOWER_MAX = 0.55

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--- 0 (settled) .. 1 (unsettled). The one number every modifier below is derived from.
function LocalWeather.unsettled(atTime: number?): number
	local override = workspace:GetAttribute(ATTR_OVERRIDE)
	if typeof(override) == "number" then
		return math.clamp(override, 0, 1)
	end
	return noise(atTime or now(), DRIFT_PERIODS)
end

--- 0 (dry) .. SHOWER_MAX. Independent of `unsettled`, so rain can fall on a flat calm.
function LocalWeather.shower(atTime: number?): number
	local raw = noise(atTime or now(), SHOWER_PERIODS)
	if raw <= LocalWeather.SHOWER_THRESHOLD then
		return 0
	end
	local t = (raw - LocalWeather.SHOWER_THRESHOLD) / (1 - LocalWeather.SHOWER_THRESHOLD)
	-- smoothstep, so a shower arrives and leaves rather than switching on
	return (t * t * (3 - 2 * t)) * LocalWeather.SHOWER_MAX
end

--[[
	How much the weather is allowed to matter, given the storm.

	At intensity 0 the weather owns the sea entirely. At intensity 4 it contributes nothing, because
	inside The Wall a pleasant breeze is not a thing that can happen - and more practically, because
	weather variation must never be able to MASK an approaching front. That would be the one genuinely
	dangerous failure of this whole design.
]]
local function weatherWeight(): number
	--[[
		From the BLENDED severity, not from StormIntensity.

		Intensity is an integer, so weighting off it made the weather's whole contribution - waves, wind, fog
		- step in one frame every time the storm crossed a band. Severity comes through
		`SeaStates.currentBlended()`, so it ramps across the crossfade and this ramps with it.

		Reaches zero at severity 0.8 (Storm), rather than only inside The Wall: by the time the front is that
		close, an independent breeze is not a thing that should still be modulating the sea.
	]]
	local sev = SeaStates.currentBlended().severity or 0
	return math.clamp(1 - sev / 0.8, 0, 1)
end

local function stormWind(): number
	local w = workspace:GetAttribute("StormWind")
	return if typeof(w) == "number" then w else 0
end

--- Words for the current weather, for the panel and later for crew dialogue.
function LocalWeather.label(unsettled: number, precip: number): string
	local sea = if unsettled < 0.14 then "Glassy"
		elseif unsettled < 0.34 then "Slight"
		elseif unsettled < 0.58 then "Moderate"
		elseif unsettled < 0.80 then "Fresh"
		else "Rough"
	local wet = if precip <= 0 then ""
		elseif precip < 0.2 then ", drizzle"
		elseif precip < 0.4 then ", showers"
		else ", rain"
	return sea .. wet
end

--[[
	Publish the modifiers. Call once a tick on the SERVER, after the storm has advanced.

	Reads StormWind/StormIntensity, so it must run AFTER `StormFront.advance` and BEFORE
	`DayNight.compose` - the world tick documents that order.
]]
function LocalWeather.step()
	local weight = weatherWeight()
	local u = LocalWeather.unsettled()
	local showerAmount = LocalWeather.shower() * weight

	-- Wind: whichever is stronger. The storm can only ever raise it.
	local weatherWind = lerp(LocalWeather.WIND_MIN, LocalWeather.WIND_MAX, u) * weight
	local wind = math.max(stormWind(), weatherWind)

	--[[
		Rain is NOT wind (decision 0020). Keeping them separate is what allows a windless shower, and a
		windless shower is the single clearest way to teach a player that rain is not the storm.
	]]
	local stormPrecip = stormWind() * stormWind() -- the quadratic the VFX used to compute for itself
	local precip = math.max(stormPrecip, showerAmount)

	-- Waves and fog fade toward neutral as the storm takes over, for the same masking reason as wind.
	local waveScale = lerp(LocalWeather.WAVE_SCALE_MIN, LocalWeather.WAVE_SCALE_MAX, u)
	local fogScale = lerp(LocalWeather.FOG_SCALE_MAX, LocalWeather.FOG_SCALE_MIN, u)

	workspace:SetAttribute(ATTR_WAVE_SCALE, lerp(1, waveScale, weight))
	workspace:SetAttribute(ATTR_FOG_SCALE, lerp(1, fogScale, weight))
	workspace:SetAttribute(ATTR_WIND, math.clamp(wind, 0, 1))
	workspace:SetAttribute(ATTR_PRECIP, math.clamp(precip, 0, 1))
	workspace:SetAttribute(ATTR_LABEL, LocalWeather.label(u, precip))
end

function LocalWeather.waveScale(): number
	local v = workspace:GetAttribute(ATTR_WAVE_SCALE)
	return if typeof(v) == "number" then v else 1
end

function LocalWeather.fogScale(): number
	local v = workspace:GetAttribute(ATTR_FOG_SCALE)
	return if typeof(v) == "number" then v else 1
end

function LocalWeather.wind(): number
	local v = workspace:GetAttribute(ATTR_WIND)
	return if typeof(v) == "number" then v else 0
end

function LocalWeather.precipitation(): number
	local v = workspace:GetAttribute(ATTR_PRECIP)
	return if typeof(v) == "number" then v else 0
end

--- Pin the drift for testing, or pass nil to hand it back to the clock.
function LocalWeather.setOverride(value: number?)
	workspace:SetAttribute(ATTR_OVERRIDE, if value then math.clamp(value, 0, 1) else nil)
	LocalWeather.step()
end

function LocalWeather.isOverridden(): boolean
	return typeof(workspace:GetAttribute(ATTR_OVERRIDE)) == "number"
end

--[[
	What the weather will do over the next `minutes`, sampled every `stepSeconds`.

	Only possible because the drift is a pure function of time. Without this, judging whether the
	variation reads as natural would mean sitting and watching for a quarter of an hour.
]]
function LocalWeather.forecast(minutes: number?, stepSeconds: number?): string
	local span = (minutes or 10) * 60
	local step = stepSeconds or 60
	local t0 = now()
	local lines = { ("weather forecast, next %d min (deterministic):"):format(span / 60) }
	local i = 0
	while i <= span do
		local t = t0 + i
		local u = noise(t, DRIFT_PERIODS)
		local sh = LocalWeather.shower(t)
		local filled = math.floor(u * 20 + 0.5)
		local bar = string.rep("#", filled) .. string.rep(".", 20 - filled)
		table.insert(lines, ("  +%3dm  %s  %.2f  %s"):format(i / 60, bar, u, LocalWeather.label(u, sh)))
		i += step
	end
	return table.concat(lines, "\n")
end

function LocalWeather.report(): string
	local u = LocalWeather.unsettled()
	return table.concat({
		("unsettled   %.2f%s"):format(u, LocalWeather.isOverridden() and "   [OVERRIDDEN]" or ""),
		("label       %s"):format(tostring(workspace:GetAttribute(ATTR_LABEL))),
		("wind        %.2f   (storm %.2f, weather ceiling %.2f)"):format(
			LocalWeather.wind(), stormWind(), LocalWeather.WIND_MAX),
		("precip      %.2f   (shower channel %.2f)"):format(LocalWeather.precipitation(), LocalWeather.shower()),
		("wave scale  %.2f x"):format(LocalWeather.waveScale()),
		("fog scale   %.2f x"):format(LocalWeather.fogScale()),
		("weight      %.2f   (weather influence; 0 = storm owns the sea)"):format(weatherWeight()),
	}, "\n")
end

return LocalWeather
