--!strict
--[[
	DayNight - the heartbeat, and the single owner of Lighting.

	Two jobs in one module because they cannot be separated:

	  1. The CLOCK. Dawn -> Day -> Dusk -> Night, server-driven, ~9-10 minutes per cycle.
	  2. The COMPOSER. Decision 0018: time of day is the base look, and the active sea state overrides it
	     in proportion to its `severity`.

	Feature: docs/features/0004-day-night/  ·  decision 0018  ·  job 016

	--------------------------------------------------------------------------------------------------
	🔴 NOTHING ELSE MAY WRITE Lighting

	Both the clock and the weather want the same properties. Whoever writes last wins, and the resulting
	bug looks like a flicker rather than like two systems disagreeing - which is a horrible thing to debug.
	So there is exactly one writer: `DayNight.compose()`.

	SeaStates still owns the *values* for each weather - it just hands them over instead of applying them.
	If you find yourself setting Lighting.FogEnd anywhere else, you are creating that flicker.

	--------------------------------------------------------------------------------------------------
	WHY THE STATE LIVES ON THE WORKSPACE

	Same reason as WaveField: every context gets its own copy of this module with its own upvalues, so a
	`local phase` would let the server and each client disagree about what time it is. The clock is a set
	of Workspace attributes - the server writes, everyone reads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))
local SkyLibrary = require(ReplicatedStorage:WaitForChild("SkyLibrary"))
local LocalWeather = require(ReplicatedStorage:WaitForChild("LocalWeather"))

local DayNight = {}

local ATTR_STARTED = "DayNightStartedAt"
local ATTR_PAUSED = "DayNightPausedAt"
local ATTR_OFFSET = "DayNightOffset" -- seconds pushed into the cycle, for jumping

--[[
	Phase durations, in seconds. ~9.5 minutes per cycle, so a three-cycle expedition runs ~28 minutes
	(confirmed 2026-08-20 against roadmap/poc.md).

	Dawn and dusk are deliberately SHORT. They are punctuation, not phases you live in - dusk especially
	is a warning that the night is coming, and a warning that lasts four minutes is not a warning.
]]
local PHASES = {
	{ id = "Dawn", label = "Dawn", duration = 40 },
	{ id = "Day", label = "Day", duration = 280 }, -- 4m40
	{ id = "Dusk", label = "Dusk", duration = 45 },
	{ id = "Night", label = "Night", duration = 210 }, -- 3m30
}

local CYCLE = 0
for _, p in ipairs(PHASES) do
	CYCLE += p.duration
end
DayNight.CYCLE_SECONDS = CYCLE
DayNight.PHASES = PHASES

--[[
	The base look per phase: what the sky and light do when the weather is calm.

	`clockTime` drives Roblox's own sun/moon position, which is what actually moves shadows. The rest is
	our palette. Dusk has no warm sky available - we own no warm skybox - so its warmth comes entirely
	from ambient and fog colour, which turns out to be enough.
]]
type PhaseLook = {
	clockTime: number,
	brightness: number,
	outdoorAmbient: Color3,
	fogColor: Color3,
	fogEnd: number,
	skyId: string,
	atmDensity: number,
	atmHaze: number,
	atmColor: Color3,
	atmDecay: Color3,
}

local LOOKS: { [string]: PhaseLook } = {
	Dawn = {
		clockTime = 6.6,
		brightness = 2.0,
		outdoorAmbient = Color3.fromRGB(84, 92, 104),
		fogColor = Color3.fromRGB(150, 152, 150), -- faint warmth, no warm sky needed
		fogEnd = 2200,
		skyId = "SunlessBlue",
		atmDensity = 0.42,
		atmHaze = 1.2,
		atmColor = Color3.fromRGB(150, 155, 160),
		atmDecay = Color3.fromRGB(80, 86, 96),
	},
	Day = {
		clockTime = 13.5,
		brightness = 2.6,
		outdoorAmbient = Color3.fromRGB(78, 90, 100),
		fogColor = Color3.fromRGB(140, 154, 163),
		fogEnd = 2800,
		skyId = "SnowGrey",
		atmDensity = 0.45,
		atmHaze = 1.4,
		atmColor = Color3.fromRGB(132, 145, 154),
		atmDecay = Color3.fromRGB(58, 68, 80),
	},
	Dusk = {
		clockTime = 17.8,
		brightness = 1.7,
		outdoorAmbient = Color3.fromRGB(96, 84, 78), -- the only warmth in the game
		fogColor = Color3.fromRGB(148, 126, 116),
		fogEnd = 1800,
		skyId = "SunlessBlue",
		atmDensity = 0.50,
		atmHaze = 1.5,
		atmColor = Color3.fromRGB(150, 132, 124),
		atmDecay = Color3.fromRGB(70, 62, 64),
	},
	Night = {
		clockTime = 0.4,
		brightness = 0.7,
		outdoorAmbient = Color3.fromRGB(34, 42, 54),
		fogColor = Color3.fromRGB(22, 28, 38),
		fogEnd = 1100,
		skyId = "NightFog",
		atmDensity = 0.55,
		atmHaze = 1.3,
		atmColor = Color3.fromRGB(46, 54, 66),
		atmDecay = Color3.fromRGB(16, 20, 26),
	},
}
DayNight.LOOKS = LOOKS

--[[
	Above this severity the weather's sky replaces the time's sky.

	0.4 puts the switch between Light Swell (0.15) and Choppy (0.45), which is the right place: a working
	sea already looks like weather, whereas a light swell should still let you see what time it is.
]]
local SKY_SWITCH_SEVERITY = 0.4

local function now(): number
	return workspace:GetServerTimeNow()
end

--- Seconds elapsed into the current cycle, honouring pause and any jump offset.
function DayNight.cycleSeconds(): number
	local started = workspace:GetAttribute(ATTR_STARTED)
	if typeof(started) ~= "number" then
		return 0
	end
	local offset = workspace:GetAttribute(ATTR_OFFSET)
	offset = if typeof(offset) == "number" then offset else 0
	local pausedAt = workspace:GetAttribute(ATTR_PAUSED)
	local reference = if typeof(pausedAt) == "number" then pausedAt else now()
	return ((reference - started) + offset) % CYCLE
end

--- Which phase, and how far through it (0..1).
function DayNight.currentPhase(): (string, number)
	local t = DayNight.cycleSeconds()
	local acc = 0
	for _, p in ipairs(PHASES) do
		if t < acc + p.duration then
			return p.id, (t - acc) / p.duration
		end
		acc += p.duration
	end
	local last = PHASES[#PHASES]
	return last.id, 1
end

function DayNight.isPaused(): boolean
	return typeof(workspace:GetAttribute(ATTR_PAUSED)) == "number"
end

--[[
	Start (or restart) the clock. Server only.
	`atPhase` optionally jumps straight to the start of a named phase.
]]
function DayNight.start(atPhase: string?)
	workspace:SetAttribute(ATTR_STARTED, now())
	workspace:SetAttribute(ATTR_PAUSED, nil)
	local offset = 0
	if atPhase then
		local acc = 0
		for _, p in ipairs(PHASES) do
			if p.id == atPhase then
				offset = acc
				break
			end
			acc += p.duration
		end
	end
	workspace:SetAttribute(ATTR_OFFSET, offset)
end

--- Freeze the clock where it is, so a look can be judged without it moving under you.
function DayNight.pause()
	if not DayNight.isPaused() then
		workspace:SetAttribute(ATTR_PAUSED, now())
	end
end

function DayNight.resume()
	local pausedAt = workspace:GetAttribute(ATTR_PAUSED)
	if typeof(pausedAt) == "number" then
		-- shift the start so no cycle time passed while frozen
		local started = workspace:GetAttribute(ATTR_STARTED)
		if typeof(started) == "number" then
			workspace:SetAttribute(ATTR_STARTED, started + (now() - pausedAt))
		end
		workspace:SetAttribute(ATTR_PAUSED, nil)
	end
end

--- Jump to a phase without restarting the cycle.
function DayNight.jumpTo(phaseId: string)
	local acc = 0
	local found = false
	for _, p in ipairs(PHASES) do
		if p.id == phaseId then
			found = true
			break
		end
		acc += p.duration
	end
	if not found then
		return false
	end
	local started = workspace:GetAttribute(ATTR_STARTED)
	if typeof(started) ~= "number" then
		DayNight.start(phaseId)
		return true
	end
	-- choose the offset that lands the current elapsed time at the phase start
	local elapsed = (DayNight.isPaused() and (workspace:GetAttribute(ATTR_PAUSED) :: number) or now()) - started
	workspace:SetAttribute(ATTR_OFFSET, (acc - elapsed) % CYCLE)
	return true
end

-- ---------------------------------------------------------------------------
-- The composer: the ONE place Lighting is written
-- ---------------------------------------------------------------------------

local function lerpN(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--[[
	The phase look, interpolated across the boundary into the next phase.

	Without this the sky would step at each boundary and dusk would arrive as a jump cut. Blending over
	the last 25% of a phase means the change is felt rather than seen.
]]
local function timeBase(): PhaseLook
	local phaseId, progress = DayNight.currentPhase()
	local look = LOOKS[phaseId]
	local BLEND_FROM = 0.75
	if progress < BLEND_FROM then
		return look
	end
	-- find the next phase
	local nextId = PHASES[1].id
	for i, p in ipairs(PHASES) do
		if p.id == phaseId then
			nextId = PHASES[(i % #PHASES) + 1].id
			break
		end
	end
	local nxt = LOOKS[nextId]
	local t = (progress - BLEND_FROM) / (1 - BLEND_FROM)
	return {
		-- ClockTime must not lerp across the midnight wrap (0.4 <- 17.8 would run backwards through noon),
		-- so it snaps at the halfway point instead. Nobody notices; shadows are already long at dusk.
		clockTime = if t < 0.5 then look.clockTime else nxt.clockTime,
		brightness = lerpN(look.brightness, nxt.brightness, t),
		outdoorAmbient = look.outdoorAmbient:Lerp(nxt.outdoorAmbient, t),
		fogColor = look.fogColor:Lerp(nxt.fogColor, t),
		fogEnd = lerpN(look.fogEnd, nxt.fogEnd, t),
		skyId = if t < 0.5 then look.skyId else nxt.skyId,
		atmDensity = lerpN(look.atmDensity, nxt.atmDensity, t),
		atmHaze = lerpN(look.atmHaze, nxt.atmHaze, t),
		atmColor = look.atmColor:Lerp(nxt.atmColor, t),
		atmDecay = look.atmDecay:Lerp(nxt.atmDecay, t),
	}
end

--[[
	The rendered water, composed from the active sea state.

	🔴 THIS WAS MISSING ENTIRELY until job 018, and it is worth recording because the symptom was so
	misleading. `StormFront` set the sea state and the wave FIELD followed it, but nothing wrote Terrain -
	so as the front closed, the sky darkened and the fog shut while the water kept whatever colour and wave
	size the last admin-panel click had left on it. Walking the storm in *looked* like it was working,
	because four of the five channels were changing.

	Terrain water lives here for the same reason Lighting does: exactly one writer, so two systems cannot
	disagree and leave a flicker to debug.

	The blend is read straight off the shared attributes rather than through WaveField, to avoid making the
	composer depend on the wave field just to smooth a colour.
]]
local function composeWater(state: any)
	local Terrain = workspace.Terrain
	-- `state` already arrives blended, via SeaStates.currentBlended() in compose().
	local water = state.water
	Terrain.WaterColor = water.color
	Terrain.WaterReflectance = water.reflectance
	Terrain.WaterTransparency = water.transparency

	--[[
		Everyday weather scales the visible sea alongside the wave field (decision 0020), so the rendered
		water and the field the hull floats on never disagree about how big the sea is.

		WaterWaveSize is CAPPED AT 1.0 by the engine - it silently clamps rather than erroring, which is
		how The Wall's original 1.4 went unnoticed. The clamp is explicit here so the cap is visible in the
		code rather than discovered by read-back.
	]]
	local scale = LocalWeather.waveScale()
	Terrain.WaterWaveSize = math.clamp(water.waveSize * scale, 0, 1)
	Terrain.WaterWaveSpeed = math.max(water.waveSpeed * scale, 0)
end

--[[
	The built-in cloud layer.

	`Clouds` is real volumetric cloud, it ships with the engine, and it costs no assets - measured
	2026-08-20: Cover and Density both accept 0..1 and clamp silently above it, and there is NO bearing or
	direction control of any kind. It is a whole-sky layer.

	That limitation is why it is only half the storm's sky. It thickens everything overhead, which is what
	this does; the DIRECTIONAL wall astern - the part a crew can turn round and look at - is
	`CloudWallVFX` on the client.

	🔴 DRIVEN BY SEVERITY, WHICH MEANS STORM-ONLY.

	Everyday weather deliberately has no say here (decision 0020). Cloud cover changes the light and the
	mood, which is the storm's language, and letting a passing shower black out the sky is exactly the
	false alarm that decision exists to prevent. Weather gets wind, waves, rain and fog. Not this.
]]
local CLOUD_PALE = Color3.fromRGB(196, 203, 210)
local CLOUD_BLACK = Color3.fromRGB(26, 30, 36)

local function composeClouds(sev: number)
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		return
	end
	--[[
		Cover rises FASTER than severity (the 0.7 power), so the sky is already meaningfully overcast at
		Choppy. A linear ramp left intensity 2 looking like a pleasant day with a dark sea, which read as
		the two systems disagreeing rather than as weather.
	]]
	clouds.Cover = math.clamp(0.15 + 0.85 * (sev ^ 0.7), 0, 1)
	clouds.Density = math.clamp(0.35 + 0.65 * sev, 0, 1)
	clouds.Color = CLOUD_PALE:Lerp(CLOUD_BLACK, sev)
end

--[[
	Apply time-of-day blended with the active sea state's weather, weighted by severity (decision 0018).

	Call this every second or so from the server. It is the only writer of Lighting, of Terrain water, and
	of the cloud layer.
]]
function DayNight.compose(): string
	local base = timeBase()
	--[[
		BLENDED, not the target state.

		Reading the target directly is what made band crossings snap: severity is the blend weight for
		brightness, fog, ambient, the atmosphere and the clouds, so a discrete severity meant all five
		stepped at once while the water eased. Coming through `currentBlended()` makes severity itself ramp,
		and everything derived from it follows for free.
	]]
	local state = SeaStates.currentBlended()
	local sev = math.clamp(state.severity or 0, 0, 1)

	--[[
		Weather MULTIPLIES the time base. It does not replace it.

		This was a bug worth recording: blending toward the sea state's absolute brightness made the night
		BRIGHTER as the weather worsened - clear night 0.70, Light Swell night 1.04, Choppy night 1.47 -
		because those brightness values were authored for daytime and were being used as blend targets at
		any hour. Same for fog: a stormy night let you see FURTHER than a clear one.

		So each state's numbers are read as a RATIO against the reference sea (Light Swell), and that ratio
		is what blends in. A storm then darkens whatever hour it lands on, instead of dragging every hour
		toward the same daytime number.

		Dead Calm's ratio is deliberately slightly above 1 for fog: it is the unnervingly clear sea, and it
		should extend visibility at any hour.
	]]
	local REF = SeaStates.LightSwell
	local brightFactor = state.sky.brightness / REF.sky.brightness
	local fogFactor = state.sky.fogEnd / REF.sky.fogEnd

	--[[
		Two properties are wanted, and they live at opposite ends of the severity range:

		  * weather must never BRIGHTEN the hour  -> a ratio against the time base (below)
		  * The Wall must be TIMELESS             -> the state's absolute values, ignoring the hour

		A ratio cannot deliver timelessness, because it always multiplies whatever base it lands on: The
		Wall came out 0.87 by day and 0.23 at night. And blending toward absolutes reintroduces the
		brightening bug, because those absolutes are daytime numbers.

		So it is a SWITCH, not a curve. Above ABSOLUTE_ABOVE the state's own values are used outright;
		below it, the ratio. The threshold only ever catches The Wall - which is precisely the one state
		that should not know what time it is.
	]]
	--[[
		A narrow CROSSFADE between the two rules, not a hard switch.

		It used to be `sev >= 0.9`, an if/else. That was correct in intent and visibly wrong in practice: at
		the crossing, brightness, fog, ambient and the whole atmosphere all changed rule in a single frame,
		which read as the sky glitching rather than as weather worsening. The gap between the two rules is
		not small - a ratio against a bright afternoon and The Wall's own near-black absolutes are far apart.

		Fading over 0.85..0.95 keeps both properties intact: below the window the hour still governs, above
		it The Wall is still timeless, and the handover happens gradually enough not to be seen. Smoothstep
		rather than linear so the fade has no corners at either end.
	]]
	local ABSOLUTE_FROM, ABSOLUTE_TO = 0.85, 0.95
	local aw = math.clamp((sev - ABSOLUTE_FROM) / (ABSOLUTE_TO - ABSOLUTE_FROM), 0, 1)
	aw = aw * aw * (3 - 2 * aw) -- smoothstep
	local useAbsolute = aw > 0.5 -- only for the sky, which cannot be cross-faded at all

	Lighting.ClockTime = base.clockTime

	-- ratio rule (weather darkens whatever hour it lands on) ... and absolute rule (The Wall is timeless)
	local ratioBright = base.brightness * lerpN(1, brightFactor, sev)
	local ratioFogEnd = base.fogEnd * lerpN(1, fogFactor, sev)
	local ratioFogColor = base.fogColor:Lerp(state.sky.fogColor, sev)

	Lighting.Brightness = lerpN(ratioBright, state.sky.brightness, aw)
	Lighting.FogEnd = lerpN(ratioFogEnd, state.sky.fogEnd, aw)
	Lighting.FogStart = lerpN(Lighting.FogEnd * 0.06, state.sky.fogStart, aw)
	Lighting.FogColor = ratioFogColor:Lerp(state.sky.fogColor, aw)

	--[[
		Everyday weather closes the horizon a little (decision 0020).

		Fog is the ONE lighting property weather may touch, and the reason it is allowed is that distance
		is not darkness: a fog bank on a bright afternoon still reads as a bright afternoon. Brightness,
		ambient, haze and the sky stay out of reach, because dimming is the storm's vocabulary.

		The clamp is not optional. `FOG_SCALE_MAX` is above 1, and Dead Calm already sits at fogEnd 2900,
		so a clear spell would push it to 3074 - past the edge of the filled ocean at 3072, which shows the
		player the water simply stopping (see SeaStates.OCEAN_HALF_EXTENT).
	]]
	Lighting.FogEnd = math.min(Lighting.FogEnd * LocalWeather.fogScale(), SeaStates.OCEAN_HALF_EXTENT - 1)
	Lighting.FogStart = math.min(Lighting.FogStart, Lighting.FogEnd * 0.5)

	composeWater(state)
	composeClouds(sev)

	local baseAmb = base.outdoorAmbient
	local weatherAmb = SeaStates.BASE_AMBIENT
	local m = state.sky.outdoorAmbient
	weatherAmb = Color3.new(
		math.clamp(weatherAmb.R * m, 0, 1),
		math.clamp(weatherAmb.G * m, 0, 1),
		math.clamp(weatherAmb.B * m, 0, 1)
	)
	-- Same crossfade as the fog and brightness above: ratio result, then eased toward the absolute one.
	Lighting.OutdoorAmbient = baseAmb:Lerp(weatherAmb, sev):Lerp(weatherAmb, aw)

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and state.atmosphere then
		atm.Density = lerpN(lerpN(base.atmDensity, state.atmosphere.density, sev), state.atmosphere.density, aw)
		atm.Haze = lerpN(lerpN(base.atmHaze, state.atmosphere.haze, sev), state.atmosphere.haze, aw)
		atm.Color = base.atmColor:Lerp(state.atmosphere.color, sev):Lerp(state.atmosphere.color, aw)
		atm.Decay = base.atmDecay:Lerp(state.atmosphere.decay, sev):Lerp(state.atmosphere.decay, aw)
		atm.Offset = state.atmosphere.offset
		atm.Glare = state.atmosphere.glare * sev
	end

	-- Sky switches rather than blends: six discrete ContentIds cannot mix.
	local skyId = if sev >= SKY_SWITCH_SEVERITY then state.skyId else base.skyId
	SkyLibrary.apply(skyId)

	local phaseId = DayNight.currentPhase()
	return ("%s + %s (severity %.2f) -> sky %s, fog %.0f, brightness %.2f")
		:format(phaseId, state.name, sev, skyId, Lighting.FogEnd, Lighting.Brightness)
end

--- One-line status, for the admin panel.
function DayNight.report(): string
	local phaseId, progress = DayNight.currentPhase()
	local t = DayNight.cycleSeconds()
	local state = SeaStates.get(workspace:GetAttribute("SeaState") or "LightSwell") or SeaStates.LightSwell
	return table.concat({
		("phase      %s  %.0f%% through"):format(phaseId, progress * 100),
		("cycle      %.0f / %d s%s"):format(t, CYCLE, DayNight.isPaused() and "  [PAUSED]" or ""),
		("weather    %s  severity %.2f"):format(state.name, state.severity or 0),
		("sky        %s"):format(tostring(SkyLibrary.current())),
		("composed   fog %.0f  brightness %.2f  clockTime %.2f"):format(
			Lighting.FogEnd, Lighting.Brightness, Lighting.ClockTime),
	}, "\n")
end

return DayNight
