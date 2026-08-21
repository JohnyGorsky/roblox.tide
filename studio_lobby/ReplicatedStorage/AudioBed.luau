--!strict
--[[
	AudioBed - a looping ambient layer that never sounds like a loop.

	Feature: docs/features/0003-storm-front/  ·  decision 0021  ·  jobs 018, 019

	--------------------------------------------------------------------------------------------------
	🔴 A LOOP MUST NEVER BE AUDIBLE AS A LOOP

	This is the single hardest problem in ambient audio and it is why this module exists. Ambient sound is
	the WORST case for looping: there is no rhythm or melody for the ear to attach to, so the only structure
	it *can* latch onto is the loop period itself. Once heard it cannot be unheard, and a game whose whole
	mood is "you are a long way from land" cannot afford a bed that says "you are in a small room with a tape".

	The user heard it in job 018 within about a minute of a single looped wind clip. Three techniques stacked,
	each attacking a different giveaway:

	  1. SEVERAL VOICES per bed, equal-POWER crossfaded. Removes the seam at the loop point, which is the
	     most recognisable artefact. Power, not amplitude - see the note on `weights` below.

	  2. RANDOM RE-SEEK. Each voice jumps to a random `TimePosition` while it is silent. THIS is what kills
	     the periodicity: the listener never hears the same stretch of clip follow the same stretch twice, so
	     there is no cycle to learn. The crossfade alone only hides the seam.

	  3. PITCH - a fixed per-voice detune plus a slow shared drift. Detuned voices drift permanently out of
	     phase with each other, so the combined texture never repeats even though each voice does.

	--------------------------------------------------------------------------------------------------
	WHY THIS IS ITS OWN MODULE

	Extracted from `StormAudio` in job 019 because the ambience beds needed exactly the same machinery, and
	the alternative was a second, similar, subtly-worse copy. One implementation means one place to fix when
	an artefact turns up, and one place for the reasoning to live.

	--------------------------------------------------------------------------------------------------
	SHORT CLIPS NEED MORE VOICES AND WIDER DETUNE, NOT A LONGER CROSSFADE

	Measured, and counter-intuitive enough to be worth stating. A 1.5 s clip has almost nowhere to re-seek
	within, so re-seek stops helping and the crossfade just cycles the same second and a half. What rescues a
	short clip is DETUNE: several copies at different pitches have different effective loop periods, so they
	drift apart permanently and the combined texture never realigns.

	It works far better on noise-like material (rain, surf, wind) than on anything tonal - shift rain and it
	sounds like slightly different rain; shift a tonal drone and it sounds like a machine spinning up.

	Prefer a longer clip to a cleverer configuration. Wide detune is compensation, not a preference.

	--------------------------------------------------------------------------------------------------
	⚠️ VOICE COUNT IS A PERFORMANCE BUDGET

	voices x beds = concurrent Sound instances, and the mobile guidance is explicit about limiting
	simultaneous audio. Two voices is the default for a reason. Reach for four only when the clip is short
	AND noise-like.
]]

local SoundService = game:GetService("SoundService")

local AudioBed = {}
AudioBed.__index = AudioBed

export type Config = {
	id: string, -- rbxassetid://... or a bare number
	voices: number?, -- default 2. See the performance note above.
	crossfade: number?, -- seconds one voice holds before handing over. Default 9.
	drift: number?, -- period of the shared pitch drift, seconds. Default 23.
	spread: number?, -- fixed per-voice detune, +/- this fraction. Default 0.02.
	pitch: number?, -- base playback speed. 1 = as recorded. Used by Dead Calm at 0.35.
	maxVolume: number?, -- ceiling; `setLevel(1)` reaches exactly this. Default 0.5.
	name: string?, -- for the readout and for naming the Sound instances
}

export type Bed = {
	config: Config,
	parts: { Sound },
	phase: number,
	level: number,
	seeded: boolean, -- has the initial voice stagger run? See the note in `new()`
}

--- ±4% slow drift, on top of each voice's fixed detune. Shared so voices never beat against each other.
local PITCH_DRIFT = 0.04

--[[
	SOLO - a testing affordance, module-level so one implementation covers every bed in the game.

	Nine beds play at once and picking one out by ear is genuinely hard: `deadCalm` is deliberately
	near-subsonic and `birds` peaks at 0.22. Solo mutes everything except the named channel.

	🔴 APPLIED INSIDE `step`, NOT WRITTEN OVER THE TOP.

	That is not a style choice. Every bed rewrites its voices' `Volume` on every tick, so anything that sets
	Volume from outside is clobbered within 100 ms - the same trap the Studio guidance warns about for any
	system that continuously writes a value. The override has to live where the value is computed.

	🔴 SOLO ALSO FORCES THE CHANNEL AUDIBLE. This is the correction that made it useful.

	The first version only muted the others, leaving the soloed channel at whatever level the world happened
	to be asking for. At default conditions - Light Swell, daylight, no storm, low wind - SIX of the nine
	channels are legitimately at zero, so soloing any of them produced dead silence and the control appeared
	to do nothing. `thunder` was the worst case: it is a one-shot that only fires on a lightning strike, so it
	is silent by definition until one happens.

	Solo is a testing affordance, and the question a tester is asking is "what does this clip sound like",
	not "what is the mix currently doing with it". So a soloed bed is driven to its own `maxVolume` regardless
	of conditions. `naturalLevel()` still reports what the mix WOULD be asking for, so the honest number is
	not lost - it is just not what you hear while auditioning.
]]
local soloChannel: string? = nil

--- Solo one channel by name, or nil for normal mixing. Names are the `name` field of each config.
function AudioBed.setSolo(name: string?)
	soloChannel = if name == "" then nil else name
end

function AudioBed.solo(): string?
	return soloChannel
end

--- Should this channel be heard right now? Also consulted by one-shots, which have no bed of their own.
function AudioBed.audible(name: string): boolean
	return soloChannel == nil or soloChannel == name
end

local function normaliseId(id: string): string
	if id == "" then
		return ""
	end
	if not id:match("^rbxassetid://") then
		return "rbxassetid://" .. (id:match("%d+") or "")
	end
	return id
end

--[[
	Build the bed. The voices are created and played here, but NOT positioned - see `seeded` below.

	Their offsets matter as much as the crossfade does, because n voices all at TimePosition 0 are perfectly
	in phase and a short clip is then n copies of the same sound. That staggering happens on the first `step`
	that finds a loaded clip, because the length is not known yet at this point.
]]
function AudioBed.new(config: Config): Bed?
	local id = normaliseId(config.id)
	if id == "" then
		return nil
	end
	local count = math.max(1, math.floor(config.voices or 2))
	local self: any = setmetatable({}, AudioBed)
	self.config = {
		id = id,
		voices = count,
		crossfade = config.crossfade or 9,
		drift = config.drift or 23,
		spread = config.spread or 0.02,
		pitch = config.pitch or 1,
		maxVolume = config.maxVolume or 0.5,
		name = config.name or "bed",
	}
	self.parts = {}
	self.phase = math.random()
	self.level = 0
	--[[
		Has the initial voice stagger actually happened yet?

		🔴 It cannot be done at construction, and assuming it can is a silent failure. `TimeLength` is 0 until
		the asset has streamed in, and every position operation here is guarded on `TimeLength > 0` - so a bed
		built before its clip loaded got NO stagger and NO re-seeks, leaving all its voices perfectly in phase
		and playing the same stretch of clip forever. Which is precisely the artefact this module exists to
		prevent, arriving through the back door.

		Caught by a readout showing `0.0s clip`: the length was visible in the diagnostics long before it
		would ever have been audible. Worth keeping the clip length in `describe()` for exactly that reason.

		So the stagger is deferred to the first `step` that finds a real length.
	]]
	self.seeded = false

	for i = 1, count do
		local s = Instance.new("Sound")
		s.Name = ("Bed_%s_%d"):format(self.config.name, i)
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		--[[
			Parented to SoundService, i.e. non-positional.

			Deliberate for every bed in this game: weather and ocean are everywhere at once, so a positioned
			emitter would get quieter when the player turns their head - wrong, and very noticeable. Anything
			that genuinely has a position (an engine, a growl) wants an AudioEmitter instead, not this.
		]]
		s.Parent = SoundService
		s:Play()
		table.insert(self.parts, s)
	end
	return self
end

--- Jump a voice to a random point. Only ever called while that voice is silent, so the jump is inaudible.
local function reseek(s: Sound)
	if s.TimeLength <= 0 then
		return
	end
	-- keep away from the very end, so a voice does not immediately wrap while fading up
	s.TimePosition = math.random() * math.max(0.1, s.TimeLength * 0.8)
end

--- Target level, 0..1. Scaled by `maxVolume`. Perceptual curve applied by the caller if wanted.
function AudioBed.setLevel(self: Bed, level: number)
	self.level = math.clamp(level, 0, 1)
end

--[[
	Advance the crossfade. Call every tick.

	`weights` uses the SUM OF SQUARES, not the sum. Normalising amplitudes instead makes the bed dip at every
	handover - a quieter, but equally recognisable, artefact to the loop seam being removed. For uncorrelated
	material like wind, rain and surf it is POWER that adds, not amplitude, so equal-power is the correct
	crossfade and it is verifiable: the squared gains sum to exactly 1.0 at every phase.
]]
function AudioBed.step(self: Bed, dt: number, serverTime: number)
	local cfg = self.config
	local n = #self.parts
	if n == 0 then
		return
	end

	--[[
		The deferred initial stagger. Spread the voices evenly through the clip the moment its length is known.

		Without this the voices sit in perfect phase and play identical audio - see the `seeded` note in
		`new()`. Runs once, and only when there is a real length to divide up.
	]]
	if not self.seeded then
		local length = self.parts[1].TimeLength
		if length > 0 then
			for i = 1, n do
				self.parts[i].TimePosition = (length / n) * (i - 1)
			end
			self.seeded = true
		end
	end

	local previousPhase = self.phase
	self.phase = (self.phase + dt / ((cfg.crossfade :: number) * n)) % 1

	--[[
		🔴 ONE VOICE IS A SPECIAL CASE, and getting it wrong is silent-and-subtle.

		The crossfade window is `0.5 + 0.5*cos(...)`, which reaches ZERO once per cycle. With two or more
		voices that is fine and is the whole point - as one voice fades out another is fading in, and the
		squared gains still sum to 1. With ONE voice there is nothing to cross to: the total collapses to
		zero, gets clamped to 1 to avoid a divide, and the gain becomes sqrt(0/1) = 0.

		So a single-voice bed went FULLY SILENT once per crossfade period. Caught by checking the
		sum-of-squares invariant across the phase range (it read 0.000000 .. 1.000000 for n=1, where n=2 and
		n=4 both read exactly 1.0), which is a good argument for testing an invariant rather than listening.

		A lone voice needs no crossfade at all - it just plays. It still gets the pitch drift and, being
		looped, still repeats; that is the cost of one voice and the reason 2 is the default.
	]]
	local weights = table.create(n)
	local total = 0
	if n == 1 then
		weights[1] = 1
		total = 1
	else
		for i = 1, n do
			local w = 0.5 + 0.5 * math.cos(((self.phase + (i - 1) / n) % 1) * math.pi * 2)
			-- sharpened, so at any moment one or two voices dominate rather than all of them mumbling
			w = w * w
			weights[i] = w
			total += w
		end
		if total <= 0 then
			total = 1
		end
	end

	local drift = math.sin((serverTime / (cfg.drift :: number)) * math.pi * 2) * PITCH_DRIFT

	--[[
		Solo folded into the target, so it cannot be clobbered by the next tick. See `soloChannel`.

		Three cases: soloed (forced to full, so it can actually be heard), muted by someone else's solo, or
		normal mixing.
	]]
	local name = cfg.name :: string
	local target
	if soloChannel == name then
		target = cfg.maxVolume :: number
	elseif soloChannel ~= nil then
		target = 0
	else
		target = self.level * (cfg.maxVolume :: number)
	end

	for i = 1, n do
		local s = self.parts[i]
		s.Volume = target * math.sqrt(weights[i] / total)

		-- symmetric detune, so the bed is smeared rather than transposed as a whole
		local detune = if n > 1 then ((i - 1) / (n - 1) - 0.5) * 2 * (cfg.spread :: number) else 0
		s.PlaybackSpeed = (cfg.pitch :: number) * (1 + detune + drift)

		-- re-seek as this voice passes its own silent point; offset per voice, hence checked per voice
		local silentAt = (0.5 + (i - 1) / n) % 1
		local crossed = (previousPhase < silentAt and self.phase >= silentAt)
		local wrapped = self.phase < previousPhase and silentAt < previousPhase and silentAt >= self.phase
		if crossed or wrapped then
			reseek(s)
		end
	end
end

--[[
	Fill the bed immediately.

	Not a nicety. A bed whose voices are still fading in reads as absent, and "absent" is indistinguishable
	from "not wired up" to anyone testing - a confusion that cost real time twice in job 018.
]]
function AudioBed.prime(self: Bed)
	for _, s in ipairs(self.parts) do
		if not s.IsPlaying then
			s:Play()
		end
		reseek(s)
	end
end

function AudioBed.destroy(self: Bed)
	for _, s in ipairs(self.parts) do
		if s and s.Parent then
			s:Destroy()
		end
	end
	table.clear(self.parts)
end

--[[
	Summed voice volume, for readouts.

	⚠️ This can exceed `maxVolume` by up to sqrt(n) and that is CORRECT, not a bug to chase. Equal-power
	crossfading keeps the sum of SQUARED gains at 1, so with two voices at equal gain each is 0.707 and they
	sum to 1.414. Power is what adds for uncorrelated material, which is why the crossfade is built that way -
	so a readout that sums amplitudes will read high mid-handover and settle when one voice dominates.
]]
function AudioBed.currentVolume(self: Bed): number
	local v = 0
	for _, s in ipairs(self.parts) do
		v += s.Volume
	end
	return v
end

--[[
	What the mix would be asking for, ignoring solo.

	Kept separate from what you can hear, so a solo readout can say "this is forced up; normally it would be
	silent right now, because <reason>". Losing the honest number would make the panel lie in a different way.
]]
function AudioBed.naturalLevel(self: Bed): number
	return self.level
end

function AudioBed.clipLength(self: Bed): number
	local s = self.parts[1]
	return if s then s.TimeLength else 0
end

--- One line, for the panel. `AudioBed` owns this so every channel reports identically.
function AudioBed.describe(self: Bed): string
	local cfg = self.config
	local length = self:clipLength()
	-- when soloed, show BOTH: what you hear, and what the mix would be asking for
	if soloChannel == cfg.name then
		return ("%-11s %-16s lvl %.2f  ◀ SOLO (forced; mix wants %.2f)"):format(
			cfg.name :: string,
			(cfg.id :: string):gsub("rbxassetid://", ""),
			self:currentVolume(),
			self.level * (cfg.maxVolume :: number))
	end
	return ("%-11s %-16s lvl %.2f  [%d voices, %s, +/-%.0f%% detune%s]%s"):format(
		cfg.name :: string,
		(cfg.id :: string):gsub("rbxassetid://", ""),
		self:currentVolume(),
		#self.parts,
		length > 0 and ("%.1fs clip"):format(length) or "NOT LOADED",
		(cfg.spread :: number) * 100,
		(cfg.pitch :: number) ~= 1 and (", pitch %.2f"):format(cfg.pitch :: number) or "",
		-- flags the failure mode that hid itself: voices in phase because the length was never known
		self.seeded and "" or "  <-- voices NOT staggered yet")
end

return AudioBed
