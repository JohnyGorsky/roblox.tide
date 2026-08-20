--!strict
--[[
	StormAudio - the storm you hear.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	The storm doc argues sound carries more dread than visuals do, and it is right: a rising rumble astern
	is more frightening than a cloud, because you cannot look away from it.

	--------------------------------------------------------------------------------------------------
	WHAT IS WIRED, AND WHAT IS AN EMPTY SLOT

	    ✅ WIND   - two layers, both assets we already own and have already scanned
	    🔨 RAIN   - EMPTY. No id yet.
	    🔨 THUNDER- EMPTY. No id yet. The timing is already correct and testable without a clip.

	The empty slots hold `""` rather than a placeholder id, deliberately. A placeholder that plays is worse
	than silence: a wrong rumble is much harder to notice than a missing one, and placeholders are how the
	wrong sound ends up shipping. `missing()` below lists what is still unfilled so it cannot be forgotten.

	--------------------------------------------------------------------------------------------------
	WIND IS TWO LAYERS, CROSSFADED

	One wind loop pushed harder does not sound like more wind - it sounds like the same wind turned up, which
	is exactly what it is. Two layers with different character, crossfaded, gives the sense that the wind
	has CHANGED rather than merely got louder.

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
		id = "",
		looped = true,
		maxVolume = 0.5,
		note = "EMPTY - needs a rain-on-water loop",
	},
	thunder = {
		id = "",
		looped = false,
		maxVolume = 0.85,
		note = "EMPTY - needs a thunder crack + roll",
	},
}

StormAudio.SLOTS = SLOTS

local sounds: { [string]: Sound } = {}
local started = false

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

function StormAudio.start()
	StormAudio.stop()
	for name, slot in pairs(SLOTS) do
		if slot.looped and slot.id ~= "" then
			local s = ensureSound(name)
			if s then
				s:Play()
			end
		end
	end
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
function StormAudio.step(_dt: number)
	if not started then
		return
	end
	local wind = attr("Wind", 0)
	local precip = attr("Precipitation", 0)

	local low = sounds.windLow
	if low then
		-- loudest in the middle of the range, thinning out as the high layer takes over
		local weight = math.clamp(1 - math.max(0, wind - 0.35) / 0.5, 0, 1)
		low.Volume = SLOTS.windLow.maxVolume * (wind ^ 0.6) * weight
	end

	local high = sounds.windHigh
	if high then
		-- silent until 0.35, so it always fades in as the registry note requires
		local t = math.clamp((wind - 0.35) / 0.65, 0, 1)
		high.Volume = SLOTS.windHigh.maxVolume * (t ^ 0.6)
	end

	local rain = sounds.rain
	if rain then
		rain.Volume = SLOTS.rain.maxVolume * (precip ^ 0.6)
	end
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
	local existing = sounds[slot]
	if existing then
		existing:Destroy()
		sounds[slot] = nil
	end
	if entry.looped and id ~= "" and started then
		local s = ensureSound(slot)
		if s then
			s:Play()
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
		local s = sounds[name]
		table.insert(lines, ("%-10s %-28s vol %.2f  %s"):format(
			name,
			slot.id == "" and "** NO ASSET **" or slot.id:gsub("rbxassetid://", ""),
			s and s.Volume or 0,
			slot.note))
	end
	table.insert(lines, "")
	table.insert(lines, ("started %s   missing: %s"):format(
		tostring(started),
		#StormAudio.missing() > 0 and table.concat(StormAudio.missing(), ", ") or "nothing"))
	return table.concat(lines, "\n")
end

return StormAudio
