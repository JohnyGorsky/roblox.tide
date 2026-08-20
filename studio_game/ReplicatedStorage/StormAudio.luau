--!strict
--[[
	StormAudio - the storm you hear.

	Feature: docs/features/0003-storm-front/  ·  decisions 0020, 0021  ·  jobs 018, 019

	The storm doc argues sound carries more dread than visuals do, and it is right: a rising rumble astern is
	more frightening than a cloud, because you cannot look away from it.

	--------------------------------------------------------------------------------------------------
	SPLIT FROM `Ambience`, AND THE LINE BETWEEN THEM

	    StormAudio   things the STORM does: wind, rain, thunder strikes, gusts
	    Ambience     things the WORLD does: ocean beds, sea birds, the storm's continuous rumble bed

	The line is not perfectly clean - the rumble bed is storm-driven but lives in `Ambience` because it is a
	continuous bed rather than an event - and that is fine. What matters is that both read the same published
	attributes, so they can never disagree about the weather.

	--------------------------------------------------------------------------------------------------
	🔴 THE ANTI-REPETITION MACHINERY LIVES IN `AudioBed`

	It used to live here. Job 019 extracted it, because the ambience beds needed exactly the same thing and
	the alternative was a second, similar, subtly-worse copy. If a loop becomes audible, fix `AudioBed` - and
	read its header first, particularly the part about short clips needing wider detune rather than a longer
	crossfade.

	--------------------------------------------------------------------------------------------------
	WIND IS TWO LAYERS BY CHARACTER

	Separately from the multi-voice trick: one clip pushed harder does not sound like more wind, it sounds
	like the same wind turned up. A low layer and a high layer crossfaded by strength give the sense the wind
	has CHANGED, not merely got louder. The registry note on `wind_rush` - that it must fade in and never
	start flat - is honoured by it being silent below wind 0.35.

	--------------------------------------------------------------------------------------------------
	READS `Wind`, WHICH MEANS EVERYDAY WEATHER IS AUDIBLE TOO

	Not `StormWind`. A breezy ordinary afternoon should be audible (decision 0020) - silence on a working sea
	would make quiet mean safe, and then the storm only has to be loud to be legible. Thunder is the one
	channel here that is storm-only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioBed = require(ReplicatedStorage:WaitForChild("AudioBed"))

local StormAudio = {}

--[[
	SLOTS. Ids recorded in roblox.workspace/Assets/registry/audio.md.

	The two wind clips are OURS, already scanned and logged for Jungle. Rain is Pro Sound Effects from the
	Creator Store (decision 0021).
]]
local SLOTS: { [string]: any } = {
	-- registry "wind-breeze": ambient light wind layer. Carries the low end of the range.
	windLow = {
		id = "93331028777865",
		voices = 2,
		crossfade = 9.3,
		drift = 23,
		spread = 0.015,
		maxVolume = 0.42,
		name = "windLow",
		note = "ours (wind-breeze), 13.4s",
	},
	-- registry "wind_rush": must FADE IN, never play flat. Honoured by being silent below wind 0.35.
	windHigh = {
		id = "96421007219531",
		voices = 2,
		crossfade = 7.1,
		drift = 17,
		spread = 0.02,
		maxVolume = 0.55,
		name = "windHigh",
		note = "ours (wind_rush), 19.0s - must fade in",
	},
	--[[
		🔴 SWAPPED in job 019, and this is the clearest example of "prefer a longer clip to cleverer code".

		This was our own 1.54 s upload, which needed FOUR voices at +/-13% detune to hide the loop - and that
		wide detune was never a preference, it was the price of a short clip. The Pro Sound Effects loop is
		36.01 s ("Rain on Water, Constant, Distant, Muffled, Washing Over, Airy, Soft, Loop"), which brings it
		back to the normal 2 voices at +/-2%.

		That removes a workaround rather than tuning one. The old id `133061174808986` stays in the registry;
		it is not wrong, it is just short.
	]]
	rain = {
		id = "9112855484",
		voices = 2,
		crossfade = 10.7,
		drift = 29,
		spread = 0.02,
		maxVolume = 0.5,
		name = "rain",
		note = "Pro Sound Effects, 36.0s (was our 1.54s clip + 4 voices)",
	},
	--[[
		Thunder is a ONE-SHOT, not a bed, so it has no AudioBed entry - it is fired per strike with a volume
		and pitch derived from that strike's distance.

		🔴 It must NOT have rain baked into it. The continuous storm rumble beds in `Ambience` do have rain in
		them, which is fine for ambience and disqualifying here: a one-shot fires at a moment chosen by the
		flash, so anything baked in arrives at the wrong time relative to its own lightning.
	]]
	thunder = {
		id = "88316151105164",
		oneShot = true,
		maxVolume = 0.85,
		name = "thunder",
		note = "ours, 5.49s one-shot",
	},
}

StormAudio.SLOTS = SLOTS

local beds: { [string]: any } = {}
local started = false

--- Gusts: sharp one-shots over the bed, so the wind has events in it and not only texture.
local nextGustAt = 0
local GUST_MIN_GAP = 2.4
local GUST_MAX_GAP = 11.0

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

function StormAudio.keys(): { string }
	local keys = {}
	for k in pairs(SLOTS) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

--- Slots with no asset. Printed on start so a silent channel is never a silent surprise.
function StormAudio.missing(): { string }
	local gaps = {}
	for _, k in ipairs(StormAudio.keys()) do
		if SLOTS[k].id == "" then
			table.insert(gaps, k)
		end
	end
	return gaps
end

function StormAudio.start()
	StormAudio.stop()
	for key, slot in pairs(SLOTS) do
		if not slot.oneShot and slot.id ~= "" then
			local bed = AudioBed.new(slot)
			if bed then
				beds[key] = bed
				bed:prime()
			end
		end
	end
	nextGustAt = os.clock() + GUST_MIN_GAP
	started = true
	local gaps = StormAudio.missing()
	if #gaps > 0 then
		print(("[AUDIO] storm started. SILENT CHANNELS: %s"):format(table.concat(gaps, ", ")))
	else
		print("[AUDIO] storm started, all channels filled.")
	end
	return true
end

function StormAudio.stop()
	for _, bed in pairs(beds) do
		bed:destroy()
	end
	table.clear(beds)
	for _, s in ipairs(SoundService:GetChildren()) do
		if s:IsA("Sound") and (s.Name == "Storm_gust" or s.Name == "Storm_thunder_once") then
			s:Destroy()
		end
	end
	started = false
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
	local gap = GUST_MAX_GAP - (GUST_MAX_GAP - GUST_MIN_GAP) * wind
	nextGustAt = os.clock() + gap * (0.6 + math.random() * 0.8)

	local slot = if wind > 0.4 then SLOTS.windHigh else SLOTS.windLow
	if slot.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Storm_gust"
	s.SoundId = "rbxassetid://" .. slot.id
	s.Looped = false
	s.PlaybackSpeed = 1.1 + math.random() * 0.35
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	if s.TimeLength > 0 then
		s.TimePosition = math.random() * math.max(0.1, s.TimeLength * 0.7)
	end

	-- fade by hand; a hard start is a click
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

--[[
	Level the beds and roll for gusts. Call ~10 Hz on the client.

	`^0.6` on the levels: perceived loudness is not linear, and a linear ramp spends most of its range
	sounding like nothing is happening and then arrives all at once near the top.
]]
function StormAudio.step(dt: number)
	if not started then
		return
	end
	local wind = attr("Wind", 0)
	local precip = attr("Precipitation", 0)
	local serverTime = workspace:GetServerTimeNow()

	-- low layer is loudest in the middle of the range, thinning as the high layer takes over
	local lowWeight = math.clamp(1 - math.max(0, wind - 0.35) / 0.5, 0, 1)
	local levels = {
		windLow = (wind ^ 0.6) * lowWeight,
		-- high layer silent until 0.35, so it always fades in as the registry note requires
		windHigh = (math.clamp((wind - 0.35) / 0.65, 0, 1)) ^ 0.6,
		rain = precip ^ 0.6,
	}

	for key, bed in pairs(beds) do
		bed:setLevel(levels[key] or 0)
		bed:step(dt, serverTime)
	end

	maybeGust(wind)
end

--[[
	Play the thunder for a strike. Wired to `LightningVFX.onThunder`, so it already fires at the right
	moment - `distance / SOUND_STUDS_PER_SECOND` after the flash.

	Volume falls with distance but the floor is not zero: distant thunder is most of what tells you the storm
	is large rather than merely near. Nearer strikes are also BRIGHTER - that is what distance does to thunder
	in the real world, and it is a far stronger distance cue than volume alone.
]]
function StormAudio.thunder(distance: number, magnitude: number)
	local slot = SLOTS.thunder
	if slot.id == "" then
		return false
	end
	local s = Instance.new("Sound")
	s.Name = "Storm_thunder_once"
	s.SoundId = "rbxassetid://" .. slot.id
	local near = math.clamp(1 - distance / 2600, 0, 1)
	s.Volume = slot.maxVolume * (0.25 + 0.75 * near) * (0.5 + 0.5 * magnitude)
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

	The point of addressable slots: the human finds an id, we hear it under the live beds at the real volume
	curve, and only then does it get written down and logged. Auditioning in place beats judging a clip on its
	store page, where it is heard alone rather than under wind.
]]
function StormAudio.setId(slot: string, id: string)
	local entry = SLOTS[slot]
	if not entry then
		return false, "unknown slot: " .. slot
	end
	entry.id = if id == "" then "" else (id:match("%d+") or "")
	if beds[slot] then
		beds[slot]:destroy()
		beds[slot] = nil
	end
	if not entry.oneShot and entry.id ~= "" and started then
		-- rebuilt through AudioBed, so an auditioned clip gets the same anti-repetition treatment as a
		-- committed one; otherwise a candidate is judged on a plain loop and sounds worse than it is
		local bed = AudioBed.new(entry)
		if bed then
			beds[slot] = bed
			bed:prime()
		end
	end
	return true, ("%s -> %s"):format(slot, entry.id == "" and "(cleared)" or entry.id)
end

function StormAudio.report(): string
	local lines = {
		("wind %.2f   precipitation %.2f"):format(attr("Wind", 0), attr("Precipitation", 0)),
		"",
	}
	local voices = 0
	for _, k in ipairs(StormAudio.keys()) do
		local slot = SLOTS[k]
		if slot.oneShot then
			table.insert(lines, ("  %-11s %-16s one-shot          %s"):format(
				k, slot.id == "" and "** NO ASSET **" or slot.id, slot.note))
		elseif beds[k] then
			table.insert(lines, "  " .. beds[k]:describe())
			voices += #beds[k].parts
		else
			table.insert(lines, ("  %-11s %-16s no bed            %s"):format(
				k, slot.id == "" and "** NO ASSET **" or slot.id, slot.note))
		end
	end
	table.insert(lines, "")
	table.insert(lines, ("%d live voices   next gust in %.1fs"):format(voices, math.max(0, nextGustAt - os.clock())))
	local missing = StormAudio.missing()
	table.insert(lines, ("missing: %s"):format(#missing > 0 and table.concat(missing, ", ") or "nothing"))
	return table.concat(lines, "\n")
end

return StormAudio
