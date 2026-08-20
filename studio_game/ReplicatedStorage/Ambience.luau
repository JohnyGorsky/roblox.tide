--!strict
--[[
	Ambience - the world's own sound. What makes the sea feel inhabited rather than rendered.

	Feature: docs/features/0003-storm-front/  ·  decisions 0020, 0021  ·  job 019

	--------------------------------------------------------------------------------------------------
	WHY THIS EXISTS

	The ocean, the wind, the weather and the storm all existed and all ticked, and the world was almost
	silent - job 018 wired four channels and nothing else. A sea that is visually alive and acoustically dead
	does not feel live; it reads as a screensaver.

	--------------------------------------------------------------------------------------------------
	NO MUSIC. AT ALL. (decision 0021)

	Not a reduced score, not a menu theme. The storm doc argues serious weather wants *less* music and *more*
	environmental sound, and taken to its conclusion the cleanest answer is that there is nothing to take
	away: if there has never been music, silence is the default state rather than an effect, and every sound
	the player hears is something in the world with them.

	It also protects the POC's own question. Music is very good at making a boring middle feel purposeful,
	which is exactly the wrong help when the thing being tested is whether the loop is fun.

	--------------------------------------------------------------------------------------------------
	🔴 LEVELS COME FROM THE SAME ATTRIBUTES THE COMPOSER USES

	Every channel is driven by `SeaStates.currentBlended()` and the storm attributes - never by its own copy
	of the weather. That is what makes sound and look incapable of disagreeing: when the sea crossfades over
	its 9 seconds, the audio crossfades on exactly the same curve, because it is reading the same number.

	--------------------------------------------------------------------------------------------------
	EVERY BED IS NON-POSITIONAL, DELIBERATELY

	Ocean and weather are everywhere at once. A positioned emitter would get quieter when the player turns
	their head, which is both wrong and very noticeable. Anything that genuinely has a position - an engine,
	a growl, a radar at its station - wants an `AudioEmitter` instead, and that arrives with the boat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioBed = require(ReplicatedStorage:WaitForChild("AudioBed"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))
local DayNight = require(ReplicatedStorage:WaitForChild("DayNight"))

local Ambience = {}

--[[
	THE CHANNELS.

	Every id is from Pro Sound Effects on the Creator Store - free, verified, and chosen because the clips are
	LONG (28-110 s where most Roblox audio is 2-5). Length is what defeats audible looping, so a long clip
	needs far less of `AudioBed`'s machinery than a short one. All verified loaded and length-checked.

	🔴 TWO CANDIDATES WERE REJECTED ON THEIR DESCRIPTIONS, which is what the "what must it NOT contain" step
	exists for:
	    Ocean Surf 1     9117143192 - "...Roar of White Noise, PROP PLANE FLY BY"
	    San Pedro Harbor 9112870008 - "...Seagulls, HEAVY HELICOPTER FLY BY"
	A vehicle baked into an ocean bed would be glaring, and on a loop it would recur forever. Read the
	description, not just the category.
]]
local CHANNELS = {
	--[[ The working sea. Loudest at mid severity, thinning at both ends. ]]
	oceanCalm = {
		id = "9120621776", -- Waves Rolling 2, 33.13s: "Waves, Distant Ocean, Rolling, Coast, Seaside"
		voices = 2,
		crossfade = 11.3,
		drift = 27,
		spread = 0.02,
		maxVolume = 0.42,
		name = "oceanCalm",
	},
	--[[ The sea coming apart. Turbulent, hissing; takes over as severity rises. ]]
	oceanHeavy = {
		id = "9120610116", -- Water Wake Constant 2, 28.77s: "Water - Turbulent, Airy Rushing, Hissing Roar"
		voices = 2,
		crossfade = 8.7,
		drift = 19,
		spread = 0.025,
		maxVolume = 0.5,
		name = "oceanHeavy",
	},
	--[[
		A CONTINUOUS storm layer, and not the same thing as the per-strike thunder.

		These clips are 80-110 s of rolling distant rumble with light rain baked in. The baked-in rain
		DISQUALIFIES them from the one-shot `thunder` slot in StormAudio - where anything baked in fires at
		the wrong moment relative to its own flash - and makes them ideal as ambience, where a continuous
		rumble under the weather is exactly what is wanted.
	]]
	stormBed = {
		id = "9120018692", -- Thunder Distant Rumble 1, 109.74s
		voices = 2,
		crossfade = 21,
		drift = 37,
		spread = 0.015,
		maxVolume = 0.55,
		name = "stormBed",
	},
	--[[ Daylight, calm, no storm. The clearest signal in the game that nothing is currently wrong. ]]
	birds = {
		id = "9112870863", -- Seagulls And Crows 1, 70.37s, marked Loop by its author
		voices = 2,
		crossfade = 17,
		drift = 31,
		spread = 0.02,
		maxVolume = 0.22, -- distant. Loud gulls on open ocean would be a lie
		name = "birds",
	},
	--[[
		DEAD CALM, and it needs no asset of its own.

		Dead Calm is meant to be the *most* unsettling state - glass water and a long clear horizon in a game
		built on weather means something is wrong. Silence would read as a bug, so it needs a bed; but
		"unsettling ocean" is not a thing that can be searched for.

		So this is the calm ocean bed ITSELF, pitched down to 0.35 until it stops sounding like water: a slow,
		low surge with no identifiable source. Measured that PlaybackSpeed accepts values down to 0.05, so
		there is plenty of headroom. It is literally the sea, slowed until it is wrong - a better answer than
		anything a search would have returned.

		Two voices at a wide, slow crossfade. At this pitch the 33 s clip stretches to about 95 s, so it needs
		very little anti-repetition help - but it gets two voices rather than one anyway, because a lone voice
		has nothing to cross to and so keeps an audible loop seam. `AudioBed` handles n=1 correctly now, but
		correct-and-seamed is still worse than two voices for a bed meant to be unnerving rather than noticed.
	]]
	deadCalm = {
		id = "9120621776",
		voices = 2,
		crossfade = 30,
		drift = 41,
		spread = 0,
		pitch = 0.35,
		maxVolume = 0.34,
		name = "deadCalm",
	},
}

Ambience.CHANNELS = CHANNELS

local beds: { [string]: any } = {}
local started = false

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

function Ambience.start()
	Ambience.stop()
	for key, config in pairs(CHANNELS) do
		local bed = AudioBed.new(config)
		if bed then
			beds[key] = bed
			bed:prime()
		end
	end
	started = true
	local missing = Ambience.missing()
	if #missing > 0 then
		print(("[AMBIENCE] started. SILENT CHANNELS: %s"):format(table.concat(missing, ", ")))
	else
		print(("[AMBIENCE] started, %d channels."):format(#Ambience.keys()))
	end
	return true
end

function Ambience.stop()
	for _, bed in pairs(beds) do
		bed:destroy()
	end
	table.clear(beds)
	started = false
end

function Ambience.keys(): { string }
	local keys = {}
	for k in pairs(CHANNELS) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

--- Channels with no asset behind them. A channel that falls silent should announce itself, never just stop.
function Ambience.missing(): { string }
	local gaps = {}
	for _, k in ipairs(Ambience.keys()) do
		if CHANNELS[k].id == "" or not beds[k] then
			table.insert(gaps, k)
		end
	end
	return gaps
end

--[[
	Perceptual curve.

	Loudness is not linear in amplitude. A linear ramp spends most of its range sounding like nothing is
	happening and then arrives all at once near the top, which is exactly the wrong shape for weather.
]]
local function perceptual(x: number): number
	return math.clamp(x, 0, 1) ^ 0.6
end

--[[
	Level every channel from the world's own state.

	Reads `SeaStates.currentBlended()`, so during a 9-second sea transition the audio moves on precisely the
	same curve as the light and the water - they are reading one number, not three similar ones.
]]
function Ambience.step(dt: number)
	if not started then
		return
	end
	local state = SeaStates.currentBlended()
	local severity = math.clamp(state.severity or 0, 0, 1)
	local intensity = attr("StormIntensity", 0)
	local serverTime = workspace:GetServerTimeNow()

	--[[
		The two ocean beds crossfade against each other rather than both rising. Two full ocean beds sum into
		a wash with no character; handing over gives the sense the sea has CHANGED rather than got louder -
		the same reasoning as the two wind layers in StormAudio.
	]]
	local heavy = perceptual(math.clamp((severity - 0.2) / 0.6, 0, 1))
	local calm = perceptual(1 - math.clamp((severity - 0.1) / 0.55, 0, 1))

	--[[
		Dead Calm's bed rises only as the sea approaches actual glass, and it is deliberately loudest when
		everything else has gone quiet - that is the point of it. Severity 0 is Dead Calm; by 0.15 (Light
		Swell) it is gone.
	]]
	local calmness = math.clamp(1 - severity / 0.15, 0, 1)

	--[[
		Birds need daylight AND a calm sea AND no storm. Three conditions multiplied, so the gulls disappear
		for any of the three reasons - which makes their absence meaningful rather than arbitrary.
	]]
	local phase = DayNight.currentPhase()
	local daylight = if phase == "Day" then 1 elseif phase == "Dawn" then 0.6 elseif phase == "Dusk" then 0.3 else 0
	local birdCalm = math.clamp(1 - severity / 0.5, 0, 1)
	local stormFree = math.clamp(1 - intensity / 2, 0, 1)

	-- The storm bed is storm-only. Everyday weather must never raise it (decision 0020).
	local stormLevel = perceptual(math.clamp((intensity - 0.5) / 3.5, 0, 1))

	local levels = {
		oceanCalm = calm,
		oceanHeavy = heavy,
		deadCalm = calmness,
		birds = daylight * birdCalm * stormFree,
		stormBed = stormLevel,
	}

	for key, bed in pairs(beds) do
		bed:setLevel(levels[key] or 0)
		bed:step(dt, serverTime)
	end
end

function Ambience.report(): string
	local state = SeaStates.currentBlended()
	local lines = {
		("sea %s  severity %.2f   storm intensity %d   phase %s"):format(
			state.id or "?", state.severity or 0, attr("StormIntensity", 0), tostring((DayNight.currentPhase()))),
		"",
	}
	local voices = 0
	for _, k in ipairs(Ambience.keys()) do
		local bed = beds[k]
		if bed then
			table.insert(lines, "  " .. bed:describe())
			voices += #bed.parts
		else
			table.insert(lines, ("  %-11s ** NO BED **"):format(k))
		end
	end
	table.insert(lines, "")
	table.insert(lines, ("%d channels, %d live voices   (StormAudio adds its own on top)"):format(
		#Ambience.keys(), voices))
	local missing = Ambience.missing()
	table.insert(lines, ("missing: %s"):format(#missing > 0 and table.concat(missing, ", ") or "nothing"))
	return table.concat(lines, "\n")
end

return Ambience
