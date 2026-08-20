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
	Apply time-of-day blended with the active sea state's weather, weighted by severity (decision 0018).

	Call this every second or so from the server. It is the only writer of Lighting.
]]
function DayNight.compose(): string
	local base = timeBase()
	local state = SeaStates.get(workspace:GetAttribute("SeaState") or "LightSwell") or SeaStates.LightSwell
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
	local ABSOLUTE_ABOVE = 0.9
	local useAbsolute = sev >= ABSOLUTE_ABOVE

	Lighting.ClockTime = base.clockTime
	if useAbsolute then
		Lighting.Brightness = state.sky.brightness
		Lighting.FogEnd = state.sky.fogEnd
		Lighting.FogStart = state.sky.fogStart
		Lighting.FogColor = state.sky.fogColor
	else
		Lighting.Brightness = base.brightness * lerpN(1, brightFactor, sev)
		Lighting.FogEnd = base.fogEnd * lerpN(1, fogFactor, sev)
		Lighting.FogStart = Lighting.FogEnd * 0.06
		Lighting.FogColor = base.fogColor:Lerp(state.sky.fogColor, sev)
	end

	local baseAmb = base.outdoorAmbient
	local weatherAmb = SeaStates.BASE_AMBIENT
	local m = state.sky.outdoorAmbient
	weatherAmb = Color3.new(
		math.clamp(weatherAmb.R * m, 0, 1),
		math.clamp(weatherAmb.G * m, 0, 1),
		math.clamp(weatherAmb.B * m, 0, 1)
	)
	Lighting.OutdoorAmbient = if useAbsolute then weatherAmb else baseAmb:Lerp(weatherAmb, sev)

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and state.atmosphere then
		atm.Density = if useAbsolute then state.atmosphere.density else lerpN(base.atmDensity, state.atmosphere.density, sev)
		atm.Haze = if useAbsolute then state.atmosphere.haze else lerpN(base.atmHaze, state.atmosphere.haze, sev)
		atm.Color = if useAbsolute then state.atmosphere.color else base.atmColor:Lerp(state.atmosphere.color, sev)
		atm.Decay = if useAbsolute then state.atmosphere.decay else base.atmDecay:Lerp(state.atmosphere.decay, sev)
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
