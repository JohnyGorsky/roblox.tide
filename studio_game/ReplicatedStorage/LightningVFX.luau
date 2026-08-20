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
	Our flash sits ON TOP of whatever exposure the place already had, and is restored to it rather than to
	zero.

	The baseline is captured on first use instead of assumed to be 0, because a place, a future colour-grade
	pass, or a player accessibility setting may legitimately have set it. Writing `baseline + ours` means
	lightning brightens whatever it finds and hands it back untouched when the storm passes.
]]
local baselineExposure: number? = nil
local ourExposure = 0

local function applyExposure()
	if baselineExposure == nil then
		baselineExposure = Lighting.ExposureCompensation
	end
	Lighting.ExposureCompensation = (baselineExposure :: number) + ourExposure
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
type LiveFlash = { peak: number, startedAt: number, up: number, down: number }

local liveFlashes: { LiveFlash } = {}
local flashConnection: RBXScriptConnection? = nil

local function stepFlashes()
	local nowClock = os.clock()
	local strongest = 0
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
			strongest = math.max(strongest, contribution)
			i += 1
		end
	end

	ourExposure = strongest
	applyExposure()

	if #liveFlashes == 0 and flashConnection then
		flashConnection:Disconnect()
		flashConnection = nil
		-- Leave the property exactly as we found it once the sky is quiet again.
		if baselineExposure ~= nil then
			Lighting.ExposureCompensation = baselineExposure :: number
		end
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
