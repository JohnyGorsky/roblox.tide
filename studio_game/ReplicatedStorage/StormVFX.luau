--!strict
--[[
	StormVFX - the approach, felt rather than measured.

	Feature: docs/features/0003-storm-front/  ·  job 017

	--------------------------------------------------------------------------------------------------
	EVERYTHING HERE READS ONE NUMBER: wind (0..1)

	StormFront publishes `StormWind` on the Workspace. Rain, spray, debris, the cloud wall and the audio
	level all scale off it, which is why they can never disagree about how bad it is. Add a new effect by
	reading wind - never by reading the distance directly, or it will drift out of step with the rest.

	Wind is published at 1 Hz by the world tick, so everything here interpolates TOWARD it rather than
	snapping. A storm that arrives in one-second steps reads as a bug.

	--------------------------------------------------------------------------------------------------
	CLIENT-SIDE, AND LOCAL TO THE CAMERA

	Rain and spray follow the camera rather than existing across 6 km of ocean - the player only ever sees
	their own few hundred studs, and filling the world with emitters would cost everything and show
	nothing. This is a client module: the server publishes wind, each client renders its own weather.

	--------------------------------------------------------------------------------------------------
	MOBILE

	Every emitter here has a rate that scales with wind AND a quality tier. `LightingStyle = Realistic` is
	already the expensive path (todo 0003), so the storm is exactly where a phone will fall over. Tier
	down by cutting RATE first and emitter COUNT second - never by cutting the wind response, or the storm
	stops communicating.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local StormVFX = {}

local RADAR_GREEN = Color3.fromRGB(82, 255, 154)
local COLD_MIST = Color3.fromRGB(110, 142, 153)
local LIGHTNING_PALE = Color3.fromRGB(220, 234, 242)

-- Smoothed wind. The published value steps once a second; this chases it.
local smoothWind = 0
local WIND_SMOOTH = 0.8 -- seconds to close most of a gap

--[[
	Smoothed rain, chased separately from wind.

	Rain is its OWN channel, not a function of wind (decision 0020). That separation is what allows a
	windless shower on an ordinary afternoon - and a windless shower is the clearest way to teach a player
	that rain is not the storm. Deriving rain from wind, as this module used to, made every drop a threat.

	It smooths slower than wind because rain arrives as a front rather than as a gust.
]]
local smoothPrecip = 0
local PRECIP_SMOOTH = 2.5

local root: Folder? = nil
local rain: ParticleEmitter? = nil
local spray: ParticleEmitter? = nil
local debris: ParticleEmitter? = nil
local connection: RBXScriptConnection? = nil

--[[
	`Wind` is the COMBINED value - the stronger of the storm's and the day's own (decision 0020). Read that
	rather than `StormWind`, or an ordinary breezy afternoon renders dead flat while the water moves.

	`StormWind` still exists and is still storm-only; it is for threat logic (alerts, radar), not for senses.
]]
local function publishedWind(): number
	local w = workspace:GetAttribute("Wind")
	if typeof(w) ~= "number" then
		w = workspace:GetAttribute("StormWind") -- before the first weather tick
	end
	return if typeof(w) == "number" then w else 0
end

local function publishedPrecip(): number
	local p = workspace:GetAttribute("Precipitation")
	return if typeof(p) == "number" then p else 0
end

--[[
	One attachment that follows the camera, carrying every emitter.

	Parented to the camera rather than to the boat: weather is not attached to the vessel, and a player who
	falls overboard should still be rained on.
]]
local function ensureRig(): Folder
	if root and root.Parent then
		return root
	end
	local f = Instance.new("Folder")
	f.Name = "StormVFX"
	f.Parent = workspace.CurrentCamera
	root = f
	return f
end

local function emitterPart(name: string, parent: Instance): Attachment
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.one
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	local a = Instance.new("Attachment")
	a.Name = "At"
	a.Parent = p
	return a
end

--[[
	Build the emitters once. Their RATE is what changes with wind, not their existence - creating and
	destroying emitters as the storm rises would hitch, and a hitch is exactly what you do not want at
	the moment the storm arrives.
]]
function StormVFX.start()
	StormVFX.stop()
	local rig = ensureRig()

	-- RAIN: a column above the camera, falling and angled by wind
	local rainAt = emitterPart("Rain", rig)
	rainAt.WorldPosition = Vector3.zero
	local r = Instance.new("ParticleEmitter")
	r.Name = "Rain"
	r.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	r.Color = ColorSequence.new(COLD_MIST)
	r.Transparency = NumberSequence.new(0.35)
	r.Size = NumberSequence.new(0.08, 0.16)
	r.Lifetime = NumberRange.new(0.5, 0.8)
	r.Rate = 0
	r.Speed = NumberRange.new(90, 130)
	r.SpreadAngle = Vector2.new(12, 12)
	r.Acceleration = Vector3.new(0, -60, 0)
	r.LightEmission = 0.15
	r.LockedToPart = false
	r.EmissionDirection = Enum.NormalId.Bottom
	r.Shape = Enum.ParticleEmitterShape.Box
	r.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	r.ShapeInOut = Enum.ParticleFlipbookLayout.None ~= nil and Enum.ParticleEmitterShapeInOut.Outward or nil
	r.Parent = rainAt
	rain = r

	-- SPRAY: sea being torn off the surface, rising rather than falling
	local sprayAt = emitterPart("Spray", rig)
	local s = Instance.new("ParticleEmitter")
	s.Name = "Spray"
	s.Texture = "rbxasset://textures/particles/smoke_main.dds"
	s.Color = ColorSequence.new(LIGHTNING_PALE)
	s.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	s.Size = NumberSequence.new(2, 7)
	s.Lifetime = NumberRange.new(0.8, 1.6)
	s.Rate = 0
	s.Speed = NumberRange.new(8, 22)
	s.SpreadAngle = Vector2.new(40, 40)
	s.Acceleration = Vector3.new(0, -14, 0)
	s.LightEmission = 0.25
	s.Parent = sprayAt
	spray = s

	-- DEBRIS: torn spume and junk crossing the view. Rare, and only when it is genuinely bad.
	local debrisAt = emitterPart("Debris", rig)
	local d = Instance.new("ParticleEmitter")
	d.Name = "Debris"
	d.Texture = "rbxasset://textures/particles/smoke_main.dds"
	d.Color = ColorSequence.new(Color3.fromRGB(150, 150, 145))
	d.Transparency = NumberSequence.new(0.5)
	d.Size = NumberSequence.new(0.6, 1.4)
	d.Lifetime = NumberRange.new(0.6, 1.1)
	d.Rate = 0
	d.Speed = NumberRange.new(70, 120)
	d.SpreadAngle = Vector2.new(8, 8)
	d.Parent = debrisAt
	debris = d

	connection = RunService.RenderStepped:Connect(function(dt)
		StormVFX.step(dt)
	end)
	return true
end

function StormVFX.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local existing = workspace.CurrentCamera and workspace.CurrentCamera:FindFirstChild("StormVFX")
	if existing then
		existing:Destroy()
	end
	root, rain, spray, debris = nil, nil, nil, nil
end

--[[
	Per-frame update.

	Rain angle is the readable cue: at wind 0 it falls straight, at wind 1 it is nearly horizontal. That
	single rotation communicates severity faster than any amount of density, because a player reads
	direction instantly and has to *compare* densities.
]]
function StormVFX.step(dt: number)
	local target = publishedWind()
	smoothWind += (target - smoothWind) * math.clamp(dt / WIND_SMOOTH, 0, 1)
	local w = smoothWind

	local rainTarget = publishedPrecip()
	smoothPrecip += (rainTarget - smoothPrecip) * math.clamp(dt / PRECIP_SMOOTH, 0, 1)
	local p = smoothPrecip

	local cam = workspace.CurrentCamera
	if not cam or not root or not root.Parent then
		return
	end

	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis

	-- wind blows broadly northward, with the storm (see the following-sea note in WaveField)
	local windDir = Vector3.new(0.25, 0, 1).Unit

	if rain then
		local part = rain.Parent and rain.Parent.Parent
		if part and part:IsA("BasePart") then
			part.Position = cam.CFrame.Position + Vector3.new(0, 45, 0)
			part.Size = Vector3.new(120, 6, 120)
		end
		--[[
			DENSITY from precipitation, ANGLE from wind. Two channels, and keeping them apart is what makes
			the sky readable: vertical rain is a shower, slanted rain is weather, near-horizontal rain is
			the front. A player reads that angle instantly, where they would have to *compare* densities.

			Linear in precip, because the curve already lives upstream - storm rain is published as wind
			squared, and showers as a smoothstep - so squaring here would double-apply it.
		]]
		rain.Rate = 900 * p
		-- horizontal push grows with wind; at w=1 the vertical fall is nearly overwhelmed
		rain.Acceleration = Vector3.new(0, -60, 0) + windDir * (220 * w)
		rain.Enabled = p > 0.02
	end

	if spray then
		local part = spray.Parent and spray.Parent.Parent
		if part and part:IsA("BasePart") then
			part.Position = Vector3.new(cam.CFrame.Position.X, 1, cam.CFrame.Position.Z) + flat * 30
			part.Size = Vector3.new(90, 2, 90)
		end
		spray.Rate = 60 * w * w
		spray.Acceleration = Vector3.new(0, -14, 0) + windDir * (90 * w)
		spray.Enabled = w > 0.25 -- no spray on a working sea; it means the tops are coming off
	end

	if debris then
		local part = debris.Parent and debris.Parent.Parent
		if part and part:IsA("BasePart") then
			part.Position = cam.CFrame.Position - windDir * 40 + Vector3.new(0, 6, 0)
		end
		debris.Rate = math.max(0, (w - 0.6) / 0.4) * 14 -- nothing below wind 0.6
		debris.Acceleration = windDir * 40
		debris.Enabled = w > 0.6
	end
end

--- Current smoothed wind, for anything that wants to match (audio, camera shake, cloth).
function StormVFX.currentWind(): number
	return smoothWind
end

function StormVFX.report(): string
	return table.concat({
		("published wind  %.3f  (combined; storm-only %.3f)"):format(
			publishedWind(), workspace:GetAttribute("StormWind") or 0),
		("smoothed wind   %.3f"):format(smoothWind),
		("precipitation   %.3f  -> smoothed %.3f"):format(publishedPrecip(), smoothPrecip),
		("rain rate       %.0f  (linear in precipitation, NOT wind)"):format(rain and rain.Rate or -1),
		("spray rate      %.0f  (off below wind 0.25)"):format(spray and spray.Rate or -1),
		("debris rate     %.0f  (off below wind 0.60)"):format(debris and debris.Rate or -1),
		("running         %s"):format(tostring(connection ~= nil)),
	}, "\n")
end

return StormVFX
