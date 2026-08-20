--!strict
--[[
	StormAudio - the storm you hear.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	The storm doc argues sound carries more dread than visuals do, and it is right: a rising rumble astern
	is more frightening than a cloud, because you cannot look away from it.

	--------------------------------------------------------------------------------------------------
	WHAT IS WIRED, AND WHAT IS AN EMPTY SLOT

	    ✅ WIND    - two layers, ours already (registry: wind-breeze, wind_rush)
	    ✅ RAIN    - ours, uploaded 2026-08-20. Only 1.54 s long, which the voice count below compensates for
	    ✅ THUNDER - ours, uploaded 2026-08-20. 5.49 s

	All four channels are filled. `missing()` still exists and is still printed on start: a channel that
	falls silent because an id was cleared or moderated should announce itself rather than just stop.

	--------------------------------------------------------------------------------------------------
	🔴 A LOOP MUST NEVER BE AUDIBLE AS A LOOP

	The first version simply played each wind clip on `Looped = true` and rode its volume. It read as
	repetitive within about a minute, and that is not a fault of the clip - it is unavoidable. Ambient wind
	is the worst possible case for looping, because there is no rhythm or melody for the ear to attach to,
	so the only structure it CAN latch onto is the loop period itself. Once heard, it cannot be unheard, and
	a game whose whole mood is "you are a long way from land" cannot afford a sound that says "you are in
	a small room with a tape".

	Three techniques stacked, each attacking a different giveaway:

	  1. SEVERAL VOICES PER LAYER, equal-POWER crossfaded so the sum never dips or bulges. This alone
	     removes the seam at the loop point, which is the most recognisable artefact. Count is per layer -
	     see VOICES below, and note why rain needs twice as many as wind.

	  2. RANDOM RE-SEEK. Whenever a voice fades to silence it jumps to a random `TimePosition` before
	     coming back. This is what actually kills the periodicity: the listener never hears the same stretch
	     of the clip follow the same stretch twice, so there is no cycle to learn.

	  3. PITCH: a fixed per-voice detune plus a slow shared drift of ±4%, on a period sharing no factor with
	     the crossfade. Wind genuinely changes pitch as it rises, so this reads as natural rather than as an
	     effect - and detuned voices drift permanently out of phase, so the combined texture never repeats
	     even though each individual voice does.

	Plus GUSTS: short, sharper one-shots layered on top at random intervals, so the bed has events in it and
	not just texture. Their frequency and strength scale with wind, so a calm day gets almost none.

	--------------------------------------------------------------------------------------------------
	WIND IS ALSO TWO LAYERS BY CHARACTER

	Separately from the voice trick above: one clip pushed harder does not sound like more wind, it sounds
	like the same wind turned up. A low layer and a high layer crossfaded by strength give the sense that the
	wind has CHANGED, not merely got louder.

	The registry's note on `wind_rush` is followed here: it must fade in, never start flat.

	--------------------------------------------------------------------------------------------------
	READS `Wind`, WHICH MEANS EVERYDAY WEATHER IS AUDIBLE TOO

	Not `StormWind`. A breezy ordinary afternoon should be audible (decision 0020) - silence on a working sea
	would make quiet mean safe, and then the storm only has to be loud to be legible. Thunder is the one
	channel here that is storm-only.
]]

local SoundService = game:GetService("SoundService")

local StormAudio = {}

--[[
	SLOTS.

	Ids are recorded in the shared registry at roblox.workspace/Assets/registry/audio.md. Both wind assets
	are OURS - already sourced, scanned and logged for the Jungle project - which is why they could be wired
	today with no approval round.
]]
type Slot = {
	id: string,
	looped: boolean,
	maxVolume: number,
	note: string,
}

local SLOTS: { [string]: Slot } = {
	-- 93331028777865: registry "ambient - light wind layer". Carries the low end of the range.
	windLow = {
		id = "rbxassetid://93331028777865",
		looped = true,
		maxVolume = 0.42,
		note = "ours (registry: wind-breeze)",
	},
	--[[
		96421007219531: registry "dive rush - 2D loop, FADE IN, do not play flat".
		Honoured by only ever reaching it through the crossfade below, never at wind 0.
	]]
	windHigh = {
		id = "rbxassetid://96421007219531",
		looped = true,
		maxVolume = 0.55,
		note = "ours (registry: wind_rush) - must fade in",
	},
	rain = {
		id = "rbxassetid://133061174808986",
		looped = true,
		maxVolume = 0.5,
		note = "ours (uploaded 2026-08-20)",
	},
	thunder = {
		id = "rbxassetid://88316151105164",
		looped = false,
		maxVolume = 0.85,
		note = "ours (uploaded 2026-08-20)",
	},
}

StormAudio.SLOTS = SLOTS

local sounds: { [string]: Sound } = {}
local started = false

--[[
	Per layer: how many voices, how fast they cycle, the pitch-drift period, and a fixed detune spread.

	`count` and `spread` are what make a SHORT clip usable.

	Measured 2026-08-20: the rain asset is **1.54 s** long, against 13.4 s and 19.0 s for the two wind clips.
	A 1.5-second loop is about the most audible thing in audio - and re-seeking barely helps, because there
	is only ~1.2 s of material to seek within. Two voices would still cycle the same second and a half over
	and over.

	What rescues it is that rain is broadband NOISE. Noise survives pitch-shifting almost unnoticed (shift
	wind and it sounds like a machine spinning up; shift rain and it sounds like slightly different rain), so
	rain gets FOUR voices at a wide ±13% detune. Detuned copies of the same short clip drift permanently out
	of phase with each other, so the combined texture never repeats even though each voice does. Wind gets
	two voices and a narrow spread, because its clips are already long and it would audibly protest a wide one.

	Periods are deliberately awkward and share no factors, so no two layers hand over together and create a
	combined rhythm of their own - which would reintroduce exactly what all this removes.
]]
local VOICES = {
	windLow = { count = 2, crossfade = 9.3, drift = 23.0, spread = 0.015 },
	windHigh = { count = 2, crossfade = 7.1, drift = 17.0, spread = 0.02 },
	rain = { count = 4, crossfade = 3.7, drift = 29.0, spread = 0.13 },
}
local PITCH_DRIFT = 0.04 -- ±4% slow drift, on top of each voice's fixed detune

type Voice = { parts: { Sound }, phase: number }
local voices: { [string]: Voice } = {}

--[[
	Gusts: sharp one-shots over the bed, so the wind has events in it and not only texture.

	Reuses the wind clips at a raised pitch rather than needing a dedicated asset - a short, fast, loud slice
	of a wind recording is a gust, which is convenient and also true.
]]
local nextGustAt = 0
local GUST_MIN_GAP = 2.4
local GUST_MAX_GAP = 11.0

--- Which slots still have no asset. Printed on start so a silent channel is never a silent surprise.
function StormAudio.missing(): { string }
	local gaps = {}
	for name, slot in pairs(SLOTS) do
		if slot.id == "" then
			table.insert(gaps, name)
		end
	end
	table.sort(gaps)
	return gaps
end

--[[
	Sounds live under SoundService, not on a part.

	Weather has no position - it is everywhere at once - so a positioned emitter would make the storm
	quieter when the player turns their head, which is wrong and also very noticeable. Thunder is the one
	that arguably wants direction, and it deliberately does not get it yet: a directional crack needs the
	bearing to be right or it points the crew the wrong way, and that is worth doing properly rather than
	approximately.
]]
local function ensureSound(name: string): Sound?
	local slot = SLOTS[name]
	if not slot or slot.id == "" then
		return nil
	end
	local existing = sounds[name]
	if existing and existing.Parent then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = "Storm_" .. name
	s.SoundId = slot.id
	s.Looped = slot.looped
	s.Volume = 0
	s.Parent = SoundService
	sounds[name] = s
	return s
end

--- One voice of a layer. Two of these per layer, crossfaded against each other.
local function makeVoice(name: string, tag: string): Sound?
	local slot = SLOTS[name]
	if not slot or slot.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = ("Storm_%s_%s"):format(name, tag)
	s.SoundId = slot.id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return s
end

--[[
	Jump a voice to a random point in the clip.

	Only ever called while that voice is silent, so the jump itself is inaudible. `TimeLength` is 0 until the
	asset has loaded, hence the guard - re-seeking to 0 every tick would pin the voice to the clip's start,
	which is the one place a loop is most recognisable.
]]
local function reseek(s: Sound?)
	if not s or s.TimeLength <= 0 then
		return false
	end
	-- keep away from the very end, so a voice does not immediately wrap while fading up
	s.TimePosition = math.random() * math.max(0.1, s.TimeLength * 0.8)
	return true
end

--[[
	Build every voice for a layer, staggered so they do not all start at the same point in the clip.

	The initial offsets matter as much as the crossfade does: n voices all starting at TimePosition 0 are
	perfectly in phase, and a short clip would then be n copies of exactly the same sound until the first
	re-seek pulled them apart.
]]
function StormAudio.buildVoices(name: string): Voice?
	local cfg = VOICES[name]
	local slot = SLOTS[name]
	if not cfg or not slot or slot.id == "" then
		return nil
	end
	local parts = {}
	for i = 1, cfg.count do
		local s = makeVoice(name, tostring(i))
		if s then
			if s.TimeLength > 0 then
				s.TimePosition = (s.TimeLength / cfg.count) * (i - 1)
			end
			table.insert(parts, s)
		end
	end
	if #parts == 0 then
		return nil
	end
	local v: Voice = { parts = parts, phase = math.random() }
	voices[name] = v
	return v
end

function StormAudio.start()
	StormAudio.stop()
	for name, slot in pairs(SLOTS) do
		if slot.looped and slot.id ~= "" then
			local built = StormAudio.buildVoices(name)
			if built then
				sounds[name] = built.parts[1] -- so report()/setId still have a handle on the layer
			end
		end
	end
	nextGustAt = os.clock() + GUST_MIN_GAP
	started = true
	local gaps = StormAudio.missing()
	if #gaps > 0 then
		print(("[AUDIO] started. SILENT CHANNELS: %s (no asset id yet)"):format(table.concat(gaps, ", ")))
	else
		print("[AUDIO] started, all channels filled.")
	end
	return true
end

function StormAudio.stop()
	for _, v in pairs(voices) do
		for _, s in ipairs(v.parts) do
			if s and s.Parent then s:Destroy() end
		end
	end
	table.clear(voices)
	for _, s in pairs(sounds) do
		if s and s.Parent then
			s:Destroy()
		end
	end
	table.clear(sounds)
	started = false
end

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

--[[
	Crossfade the two wind layers, and level the rain against precipitation.

	The low layer fades OUT as the high layer comes in, rather than both playing at full - two full-volume
	wind loops sum into a wash with no character at all.

	`^0.6` on the volumes: perceived loudness is not linear, and a linear ramp spent most of its range
	sounding like nothing was happening and then arrived all at once near the top.
]]
--[[
	Drive one layer's two voices at a given target level.

	Equal-power crossfade: gains are sin² and cos² of the same angle, which sum to exactly 1 at every phase.
	Linear gains would sum to less than 1 in the middle and the bed would visibly dip at each handover, which
	is a different but equally recognisable artefact to the one we are removing.

	The re-seek is the important half: each voice is jumped to a random position while it is SILENT, so the
	listener never hears the same stretch of clip twice in the same order and there is no period to learn.
]]
local function driveLayer(name: string, level: number, dt: number)
	local v = voices[name]
	local cfg = VOICES[name]
	if not v or not cfg then
		return
	end

	local n = #v.parts
	if n == 0 then
		return
	end

	local previousPhase = v.phase
	v.phase = (v.phase + dt / (cfg.crossfade * n)) % 1

	--[[
		Equal-POWER crossfade across n voices.

		Each voice gets a raised-cosine window, staggered by 1/n of the cycle, and the windows are normalised
		so the sum of SQUARES is 1. Normalising the amplitudes instead would make the bed dip at every
		handover - a quieter but equally recognisable artefact than the loop seam we are removing. For
		uncorrelated material like wind and rain, power is what adds, not amplitude.
	]]
	local weights = table.create(n)
	local total = 0
	for i = 1, n do
		local offset = (i - 1) / n
		local w = 0.5 + 0.5 * math.cos(((v.phase + offset) % 1) * math.pi * 2)
		w = w * w -- sharpen, so at any moment one or two voices dominate rather than all of them mumbling
		weights[i] = w
		total += w
	end
	if total <= 0 then
		total = 1
	end

	local t = workspace:GetServerTimeNow()
	local drift = math.sin((t / cfg.drift) * math.pi * 2) * PITCH_DRIFT

	for i = 1, n do
		local s = v.parts[i]
		local gain = math.sqrt(weights[i] / total)
		s.Volume = level * gain

		--[[
			Fixed detune per voice, plus the shared slow drift. Spread symmetrically around 1.0 so the layer
			does not end up transposed as a whole - only smeared.
		]]
		local detune = if n > 1 then ((i - 1) / (n - 1) - 0.5) * 2 * cfg.spread else 0
		s.PlaybackSpeed = 1 + detune + drift

		--[[
			Re-seek a voice while it is at its quietest, so the jump is inaudible. Each voice's silent point
			is offset by its own stagger, which is why this is checked per voice rather than once per layer.
		]]
		local silentAt = (0.5 + (i - 1) / n) % 1
		local wasBefore = previousPhase < silentAt
		local isAfter = v.phase >= silentAt
		local wrapped = v.phase < previousPhase
		if (wasBefore and isAfter) or (wrapped and silentAt < previousPhase and silentAt >= v.phase) then
			reseek(s)
		end
	end
end

--[[
	A gust: a short, sharper, louder slice over the bed.

	Reuses the wind clip at a raised pitch from a random offset, which is what a gust actually is. Frequency
	and strength both scale with wind, so a calm day gets almost none and a storm is full of them - and the
	gap is randomised within a range rather than fixed, so gusts never become a metronome.
]]
local function maybeGust(wind: number)
	if wind < 0.12 or os.clock() < nextGustAt then
		return
	end
	-- gaps shorten as the wind rises
	local gap = GUST_MAX_GAP - (GUST_MAX_GAP - GUST_MIN_GAP) * wind
	nextGustAt = os.clock() + gap * (0.6 + math.random() * 0.8)

	local slot = if wind > 0.4 then SLOTS.windHigh else SLOTS.windLow
	if slot.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Storm_gust"
	s.SoundId = slot.id
	s.Looped = false
	s.PlaybackSpeed = 1.1 + math.random() * 0.35
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	if s.TimeLength > 0 then
		s.TimePosition = math.random() * math.max(0.1, s.TimeLength * 0.7)
	end

	-- fade the gust in and out by hand; a hard start is a click
	local peak = (0.12 + 0.30 * wind) * (0.7 + math.random() * 0.6)
	local rise, hold, fall = 0.35, 0.4 + math.random() * 0.9, 0.9
	task.spawn(function()
		local steps = 12
		for i = 1, steps do
			s.Volume = peak * (i / steps)
			task.wait(rise / steps)
		end
		task.wait(hold)
		for i = steps, 0, -1 do
			s.Volume = peak * (i / steps)
			task.wait(fall / steps)
		end
		s:Destroy()
	end)
end

function StormAudio.step(dt: number)
	if not started then
		return
	end
	local wind = attr("Wind", 0)
	local precip = attr("Precipitation", 0)

	--[[
		`^0.6` on the levels: perceived loudness is not linear, and a linear ramp spent most of its range
		sounding like nothing was happening and then arrived all at once near the top.
	]]
	-- low layer is loudest in the middle of the range, thinning as the high layer takes over
	local lowWeight = math.clamp(1 - math.max(0, wind - 0.35) / 0.5, 0, 1)
	driveLayer("windLow", SLOTS.windLow.maxVolume * (wind ^ 0.6) * lowWeight, dt)

	-- high layer is silent until 0.35, so it always fades in as the registry note requires
	local highT = math.clamp((wind - 0.35) / 0.65, 0, 1)
	driveLayer("windHigh", SLOTS.windHigh.maxVolume * (highT ^ 0.6), dt)

	driveLayer("rain", SLOTS.rain.maxVolume * (precip ^ 0.6), dt)

	maybeGust(wind)
end

--[[
	Play the thunder for a strike. Wired to `LightningVFX.onThunder`, so it already fires at the right
	moment - `distance / SOUND_STUDS_PER_SECOND` after the flash.

	Volume falls with distance but the floor is not zero: distant thunder is most of what tells you the storm
	is large rather than merely near.
]]
function StormAudio.thunder(distance: number, magnitude: number)
	local slot = SLOTS.thunder
	if slot.id == "" then
		return false
	end
	local s = Instance.new("Sound")
	s.Name = "Storm_thunder_once"
	s.SoundId = slot.id
	local near = math.clamp(1 - distance / 2600, 0, 1)
	s.Volume = slot.maxVolume * (0.25 + 0.75 * near) * (0.5 + 0.5 * magnitude)
	--[[
		Nearer strikes are BRIGHTER, further ones are duller and slower - that is what distance does to
		thunder in the real world, and it is a far stronger distance cue than volume alone.
	]]
	s.PlaybackSpeed = 0.85 + 0.25 * near
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	return true
end

--[[
	Swap an id at runtime, so a candidate can be AUDITIONED before it is committed to code.

	This is the point of the empty slots being addressable: the human finds an id on the Creator Store, we
	hear it in the real storm at the real volume curve, and only then does it get written down and logged in
	the registry. Auditioning in place beats judging a clip on its store page, where it is heard alone rather
	than under wind.
]]
function StormAudio.setId(slot: string, id: string)
	local entry = SLOTS[slot]
	if not entry then
		return false, "unknown slot: " .. slot
	end
	-- accept a bare number as well as a full rbxassetid:// string
	if id ~= "" and not id:match("^rbxassetid://") then
		id = "rbxassetid://" .. (id:match("%d+") or "")
	end
	entry.id = id
	-- tear the layer down and rebuild both voices, so an auditioned id gets the same anti-repetition
	-- treatment as a committed one - otherwise a candidate is judged on a plain loop and sounds worse
	local v = voices[slot]
	if v then
		for _, s in ipairs(v.parts) do
			if s and s.Parent then s:Destroy() end
		end
		voices[slot] = nil
	end
	local existing = sounds[slot]
	if existing and existing.Parent then
		existing:Destroy()
	end
	sounds[slot] = nil
	if entry.looped and id ~= "" and started then
		local built = StormAudio.buildVoices(slot)
		if built then
			sounds[slot] = built.parts[1]
		end
	end
	return true, ("%s -> %s"):format(slot, id == "" and "(cleared)" or id)
end

function StormAudio.report(): string
	local lines = { ("wind %.2f   precipitation %.2f"):format(attr("Wind", 0), attr("Precipitation", 0)), "" }
	local names = {}
	for name in pairs(SLOTS) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local slot = SLOTS[name]
		local v = voices[name]
		local level = 0
		if v then
			for _, snd in ipairs(v.parts) do level += snd.Volume end
		end
		table.insert(lines, ("%-10s %-17s lvl %.2f  %s%s"):format(
			name,
			slot.id == "" and "** NO ASSET **" or slot.id:gsub("rbxassetid://", ""),
			level,
			v and ("[%d voices, phase %.2f, len %.2fs] "):format(
				#v.parts, v.phase, v.parts[1].TimeLength) or "",
			slot.note))
	end
	table.insert(lines, "")
	table.insert(lines, ("next gust in %.1fs  (loops are dual-voice + random re-seek, so no audible period)")
		:format(math.max(0, nextGustAt - os.clock())))
	table.insert(lines, "")
	table.insert(lines, ("started %s   missing: %s"):format(
		tostring(started),
		#StormAudio.missing() > 0 and table.concat(StormAudio.missing(), ", ") or "nothing"))
	return table.concat(lines, "\n")
end

return StormAudio
