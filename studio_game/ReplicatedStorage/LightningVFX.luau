--!strict
--[[
	LightningVFX - drawing a strike the server has already decided on.

	Feature: docs/features/0003-storm-front/  ·  job 018

	Client module. `Lightning` holds the shared rules and numbers; this is the rendering half, kept separate
	so the server can require the rules without pulling in anything that touches the camera.

	Four channels per strike, and they are deliberately staged rather than simultaneous:

	    1. the BOLT      - instant, brief, in the direction the server chose
	    2. the FLASH     - exposure spike, ~150 ms, brightest for near strikes
	    3. the SHAKE     - close strikes only
	    4. the THUNDER   - seconds later, distance / SOUND_STUDS_PER_SECOND

	The gap between 2 and 4 is the effect. A player who counts it is reading the storm's distance off the
	sky, which is exactly the kind of instrument-free knowledge this game wants.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Lightning = require(ReplicatedStorage:WaitForChild("Lightning"))

local LightningVFX = {}

local BOLT_PALE = Color3.fromRGB(226, 238, 250)

--[[
	🔴 THREE LIGHT CHANNELS, AND WHY IT TAKES THREE.

	Exposure alone was not enough. `ExposureCompensation` is a TONEMAP - it rescales the frame that was
	already rendered, so everything brightens by the same proportion and nothing is actually *lit*. A dark
	deck stays a flat dark shape, just a paler one. The eye reads that as the gamma being nudged, not as the
	sky having gone off.

	So a strike now drives all three of these together:

	  1. ExposureCompensation  the frame-wide response. Fast, cheap, and the wrong tool on its own.
	  2. Lighting.Ambient      REAL global illumination, including into shadow. This is the one that makes
	                           the world look struck rather than merely brighter.
	  3. a PointLight          local falloff near the camera, so surfaces closest to the crew catch it
	                           hardest and the deck and water get a highlight that moves with the strike's
	                           direction. Falloff is what sells it as a light source having a position.

	Plus PointLights on the bolt itself, so it glows into the fog around it instead of being a flat bright
	shape drawn on top of the murk.

	--------------------------------------------------------------------------------------------------
	WHY `Ambient` IS SAFE TO TAKE

	`DayNight.compose()` writes Brightness, ClockTime, Fog*, and **OutdoorAmbient**. It does not write
	`Ambient` - verified by grep, and they are genuinely different properties: OutdoorAmbient is the
	sky-lit term, Ambient is the floor applied everywhere including shadow. So lightning can own Ambient
	outright, the same way it owns ExposureCompensation, and there is still exactly one writer per property.

	If you ever need Ambient for something else, route it through the composer instead of adding a second
	writer - two writers on a Lighting property produce a flicker that looks like anything except two
	systems disagreeing.

	Both baselines are captured on FIRST USE rather than assumed, because a place, a colour-grade pass, or a
	player accessibility setting may legitimately have set them. `baseline + ours` means lightning brightens
	whatever it finds and hands it back untouched.
]]
local baselineExposure: number? = nil
local baselineAmbient: Color3? = nil
local ourExposure = 0

--- How much Ambient a full-strength flash adds. Tuned so a close strike lights the deck without flattening it.
local AMBIENT_GAIN = 0.55
--- PointLight brightness at full strength. Roblox lights cap their Range at 120 studs.
local LIGHT_GAIN = 14
local LIGHT_RANGE = 120

local flashLight: PointLight? = nil
local flashLightPart: BasePart? = nil

--[[
	The local light rides a part near the camera rather than being parented to the camera directly, because a
	Light must sit on a BasePart or Attachment to exist at all. Offset ABOVE and toward the strike, so the
	falloff runs down onto the deck and the water the way skylight would.
]]
local function ensureFlashLight(): PointLight?
	if flashLight and flashLight.Parent and flashLightPart and flashLightPart.Parent then
		return flashLight
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = "LightningLight"
	p.Size = Vector3.one
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = camera
	local light = Instance.new("PointLight")
	light.Name = "Flash"
	light.Color = BOLT_PALE
	light.Range = LIGHT_RANGE
	light.Brightness = 0
	light.Shadows = true -- shadows are most of why this reads as a light rather than a wash
	light.Enabled = false
	light.Parent = p
	flashLight, flashLightPart = light, p
	return light
end

local function applyLight(amount: number, direction: Vector3?)
	if baselineExposure == nil then
		baselineExposure = Lighting.ExposureCompensation
	end
	if baselineAmbient == nil then
		baselineAmbient = Lighting.Ambient
	end
	Lighting.ExposureCompensation = (baselineExposure :: number) + amount

	-- Ambient: real illumination, clamped so a double strike cannot wash the scene to white.
	local lift = math.clamp(amount, 0, 1.5) * AMBIENT_GAIN
	local base = baselineAmbient :: Color3
	Lighting.Ambient = Color3.new(
		math.clamp(base.R + BOLT_PALE.R * lift, 0, 1),
		math.clamp(base.G + BOLT_PALE.G * lift, 0, 1),
		math.clamp(base.B + BOLT_PALE.B * lift, 0, 1)
	)

	local light = ensureFlashLight()
	if light and flashLightPart then
		light.Brightness = amount * LIGHT_GAIN
		light.Enabled = amount > 0.01
		local camera = workspace.CurrentCamera
		if camera then
			local toward = direction or Vector3.new(0, 0, -1)
			flashLightPart.Position = camera.CFrame.Position + Vector3.new(0, 42, 0) + toward * 26
		end
	end
end

local function restoreLight()
	if baselineExposure ~= nil then
		Lighting.ExposureCompensation = baselineExposure :: number
	end
	if baselineAmbient ~= nil then
		Lighting.Ambient = baselineAmbient :: Color3
	end
	if flashLight then
		flashLight.Brightness = 0
		flashLight.Enabled = false
	end
end

--[[
	A jagged bolt, built from a handful of thin neon segments.

	Crude on purpose. Every strike happens at 200-2600 studs through storm fog thick enough to hide the bow
	of the vessel, so what actually reaches the player is a bright vertical tear in the murk - detail spent
	on the bolt's shape is detail nobody can see. Segments are Anchored, collisionless and unqueryable so a
	bolt can never be hit by a raycast or push anything.
]]
local function drawBolt(strike: Lightning.Strike, origin: Vector3)
	local dir = Lightning.directionOf(strike)
	local base = origin + dir * strike.distance
	local model = Instance.new("Model")
	model.Name = "Bolt"
	model.Parent = workspace

	local segments = 5
	local topHeight = 520 + 380 * strike.magnitude
	local width = 2.2 + 5 * strike.magnitude
	-- Nearer strikes look wider simply by being nearer; scale the geometry only with magnitude.
	local drift = math.max(18, strike.distance * 0.04)

	local previous = base + Vector3.new(0, topHeight, 0)
	for i = 1, segments do
		local t = i / segments
		local nextPoint = base
			+ Vector3.new(0, topHeight * (1 - t), 0)
			+ Vector3.new((math.random() - 0.5) * drift, 0, (math.random() - 0.5) * drift)
		local delta = nextPoint - previous
		local part = Instance.new("Part")
		part.Name = "Segment" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = BOLT_PALE
		part.Size = Vector3.new(width, width, delta.Magnitude)
		part.CFrame = CFrame.lookAt(previous + delta * 0.5, nextPoint)
		part.Parent = model

		--[[
			Light ON the bolt, brightest at the bottom.

			Without this a bolt is a bright shape drawn *on top of* the fog rather than a light source
			inside it. A PointLight makes the surrounding murk glow, which is what gives the strike a
			position in the world instead of on the screen.

			Only the lower half gets lights: the top of a bolt is far above anything that could catch the
			light, so those would cost frames and illuminate nothing. Range caps at 120 studs engine-side,
			so this lights the strike's immediate surroundings and the water under it, not the whole sea.
		]]
		if i > segments // 2 then
			local glow = Instance.new("PointLight")
			glow.Color = BOLT_PALE
			glow.Range = LIGHT_RANGE
			-- brightest at the waterline, where there is actually something to light
			glow.Brightness = (6 + 10 * strike.magnitude) * (i / segments)
			glow.Shadows = false -- the bolt is inside its own light; shadows here only produce artefacts
			glow.Parent = part
		end

		previous = nextPoint
	end

	-- Two frames, then gone. A bolt that lingers reads as a prop.
	task.delay(0.09 + 0.06 * math.random(), function()
		model:Destroy()
	end)
end

--[[
	The flash.

	Fast up, slow down. That asymmetry is what makes it read as lightning rather than as a light being
	switched on - equal times looked like a fade.

	ONE connection walks a list of live flashes rather than each strike owning its own tween. Two tweens on
	the same Lighting property would fight, and the visible result was the second strike CANCELLING the
	first's flash part-way through, which read as the sky stuttering. Taking the strongest live contribution
	each frame instead means overlapping strikes at intensity 4 blend into one continuous storm-lit sky
	rather than summing and clipping to white.
]]
type LiveFlash = { peak: number, startedAt: number, up: number, down: number, direction: Vector3 }

local liveFlashes: { LiveFlash } = {}
local flashConnection: RBXScriptConnection? = nil

local function stepFlashes()
	local nowClock = os.clock()
	local strongest = 0
	local strongestDir: Vector3? = nil
	local i = 1
	while i <= #liveFlashes do
		local f = liveFlashes[i]
		local elapsed = nowClock - f.startedAt
		if elapsed >= f.up + f.down then
			table.remove(liveFlashes, i)
		else
			local contribution
			if elapsed < f.up then
				contribution = f.peak * (elapsed / f.up)
			else
				local t = (elapsed - f.up) / f.down
				contribution = f.peak * (1 - t) * (1 - t) -- eased out, so the tail lingers slightly
			end
			if contribution > strongest then
				strongest = contribution
				-- the light points from whichever strike is currently dominant, so overlapping strikes
				-- swing the highlight around rather than averaging into a directionless wash
				strongestDir = f.direction
			end
			i += 1
		end
	end

	ourExposure = strongest
	applyLight(strongest, strongestDir)

	if #liveFlashes == 0 and flashConnection then
		flashConnection:Disconnect()
		flashConnection = nil
		restoreLight() -- leave every property exactly as we found it once the sky is quiet again
	end
end

--[[
	Driven by Heartbeat, NOT RenderStepped.

	Two reasons, and the second one is the one that cost time. First, this writes a Lighting property rather
	than a camera transform, so it does not need render-time precision - Heartbeat is already per-frame.

	Second: RenderStepped does not fire in Studio's Edit context, which is where this project's automated
	checks run. On RenderStepped the flash was silently untestable - the bolt geometry verified fine while
	the exposure channel never moved, and there is no way to tell that apart from a broken flash without
	entering Play. A channel that cannot be checked is a channel that quietly rots.

	The camera SHAKE below stays on RenderStepped, because that one genuinely must run at render time or the
	camera script overwrites it the same frame.
]]
local function flash(strike: Lightning.Strike)
	table.insert(liveFlashes, {
		peak = Lightning.flashExposure(strike),
		startedAt = os.clock(),
		up = 0.035,
		down = 0.16 + 0.12 * strike.magnitude,
		direction = Lightning.directionOf(strike),
	})
	if not flashConnection then
		flashConnection = RunService.Heartbeat:Connect(stepFlashes)
	end
end

--- Camera shake, close strikes only. Additive on top of whatever the camera is already doing.
local function shake(strike: Lightning.Strike)
	if strike.distance > Lightning.CLOSE_DISTANCE then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local strength = (1 - strike.distance / Lightning.CLOSE_DISTANCE) * (0.6 + 0.4 * strike.magnitude)
	local duration = 0.45
	local startedAt = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startedAt
		if elapsed >= duration or not camera.Parent then
			conn:Disconnect()
			return
		end
		local decay = 1 - elapsed / duration
		local amount = strength * decay * 0.9
		camera.CFrame = camera.CFrame * CFrame.Angles(
			(math.random() - 0.5) * amount * 0.03,
			(math.random() - 0.5) * amount * 0.03,
			(math.random() - 0.5) * amount * 0.05
		)
	end)
end

--[[
	Thunder.

	🔨 AUDIO IS NOT SOURCED YET (group 12), so this fires a signal and plays nothing. It is wired up now
	rather than later because the DELAY is the part worth getting right, and the delay is testable without a
	single sound file - `LightningVFX.onThunder` is called at the correct moment, and the audio job only has
	to attach a clip to it.

	Deliberately NOT a silent Sound instance with a placeholder id: a wrong rumble is harder to notice than
	no rumble, and a placeholder that ships is how a game ends up with the wrong sound in it.
]]
local thunderListeners: { (Lightning.Strike) -> () } = {}

function LightningVFX.onThunder(callback: (Lightning.Strike) -> ())
	table.insert(thunderListeners, callback)
end

local function thunder(strike: Lightning.Strike)
	task.delay(Lightning.thunderDelay(strike.distance), function()
		for _, listener in ipairs(thunderListeners) do
			task.spawn(listener, strike)
		end
	end)
end

--[[
	Render one strike. Called from the client's remote handler.

	`origin` is where the crew is - the camera position, flattened to sea level, so a bolt is placed
	relative to the viewer rather than to the world origin. On an empty ocean the two are indistinguishable
	until you have travelled, and then a world-origin bolt would be kilometres away.
]]
function LightningVFX.render(strike: Lightning.Strike)
	local camera = workspace.CurrentCamera
	local origin = if camera then Vector3.new(camera.CFrame.Position.X, 0, camera.CFrame.Position.Z) else Vector3.zero
	drawBolt(strike, origin)
	flash(strike)
	shake(strike)
	thunder(strike)
end

--- Put ExposureCompensation back, for a clean handover if the storm system is ever torn down.
function LightningVFX.reset()
	ourExposure = 0
	table.clear(liveFlashes)
	if baselineExposure ~= nil then
		Lighting.ExposureCompensation = baselineExposure :: number
	end
end

return LightningVFX
