--!strict
--[[
	CloudWallVFX - the thing you turn round and look at.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	--------------------------------------------------------------------------------------------------
	THIS IS THE STORM'S DIAGNOSTIC, NOT DECORATION

	Decision 0020 makes rain, chop, wind and closing fog ORDINARY - they happen on afternoons that mean
	nothing. That was the right call for making the world feel natural, and it left the storm needing one
	signal that weather can never counterfeit. This is it: a dark mass astern that only ever grows.

	So the rule that matters most here is about the INPUT, not the look:

	    🔴 driven by StormIntensity / StormDistance - NEVER by Wind or Precipitation.

	Wind and precipitation are shared with everyday weather. Drive the wall off either and a breezy
	afternoon grows a wall, which destroys the one unambiguous cue the crew has.

	--------------------------------------------------------------------------------------------------
	WHY PARTICLES RATHER THAN GEOMETRY

	The built-in `Clouds` instance is real volumetric cloud and free, but it is a SKY-WIDE layer - Cover and
	Density clamp to 0..1 and there is no bearing control at all (measured 2026-08-20). It can thicken the
	whole sky, which the composer does, but it cannot put anything in one direction. A sky that thickens is
	not something you can turn round and look at.

	So the directional half is a bank of very large, very slow particles sitting astern. Chosen over a
	textured geometry arc because it needs no sourced art, which meant it could be judged against the real
	approach today instead of against a mockup. If it reads as smoke rather than as weather, an arc with a
	real cloud texture is the escalation.

	--------------------------------------------------------------------------------------------------
	FOG IS THE CONSTRAINT THAT SHAPES ALL OF THIS

	At intensity 2 the composed fog ends around 2260 studs while the front may still be 2500 away - so a
	wall drawn at its true distance would be completely invisible, and the crew would get their warning only
	once it was nearly too late.

	It is therefore drawn at `min(true distance, just inside the fog)` and made to GROW. What the player
	reads is "the horizon astern is darkening and rising", which is honest - it is exactly what an
	approaching front looks like from a small boat - while staying visible at every stage.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local CloudWallVFX = {}

local WALL_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

--- Bearing the front lies on. Matches Lightning.ASTERN_BEARING: progress runs +Z, the storm chases from -Z.
local ASTERN = Vector3.new(0, 0, -1)

--- Nothing at all at intensity 0. The first band is where a horizon smudge appears.
local MIN_INTENSITY = 1

--- Fraction of the fog distance the wall is pinned inside, so it is never swallowed whole.
local INSIDE_FOG = 0.82

local root: Folder? = nil
local emitter: ParticleEmitter? = nil
local wallPart: BasePart? = nil
local connection: RBXScriptConnection? = nil

-- Smoothed, for the same reason the storm VFX smooth wind: the source steps once a second.
local smoothPresence = 0
local PRESENCE_SMOOTH = 3.0 -- slow. A wall that snaps into being is a wall nobody believes.

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

--[[
	How present the wall is, 0..1.

	From INTENSITY rather than from distance, so it steps with the bands the rest of the storm uses and
	cannot drift out of agreement with the sea state and the lighting.
]]
local function presence(): number
	local intensity = attr("StormIntensity", 0)
	if intensity < MIN_INTENSITY then
		return 0
	end
	return math.clamp((intensity - MIN_INTENSITY + 1) / (4 - MIN_INTENSITY + 1), 0, 1)
end

function CloudWallVFX.start()
	CloudWallVFX.stop()

	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local f = Instance.new("Folder")
	f.Name = "CloudWall"
	f.Parent = camera
	root = f

	--[[
		A box volume rather than a flat plane. Particles emitted into a deep box overlap each other at
		different depths, which is what gives the mass any sense of thickness - a single plane of large
		sprites reads as a painted backdrop the moment the camera moves.
	]]
	local part = Instance.new("Part")
	part.Name = "Wall"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(3000, 900, 400)
	part.Parent = f
	wallPart = part

	local e = Instance.new("ParticleEmitter")
	e.Name = "Mass"
	e.Texture = WALL_TEXTURE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Lifetime = NumberRange.new(11, 17)
	e.Speed = NumberRange.new(1, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4) -- slow churn; faster looks like smoke from a fire
	e.LightEmission = 0
	e.LightInfluence = 1 -- lit by the scene, so the wall darkens with the sky rather than fighting it
	e.ZOffset = -2 -- sit behind anything else the camera rig is drawing
	--[[
		Faded at both ends of life. A particle that appears at full opacity pops, and on a bank this large a
		single pop is very visible - the sprite is hundreds of studs across.
	]]
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(0.75, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new(420, 700)
	e.Parent = part
	emitter = e

	connection = RunService.RenderStepped:Connect(function(dt)
		CloudWallVFX.step(dt)
	end)
	return true
end

function CloudWallVFX.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local camera = workspace.CurrentCamera
	local existing = camera and camera:FindFirstChild("CloudWall")
	if existing then
		existing:Destroy()
	end
	root, emitter, wallPart = nil, nil, nil
	smoothPresence = 0
end

function CloudWallVFX.step(dt: number)
	local target = presence()
	smoothPresence += (target - smoothPresence) * math.clamp(dt / PRESENCE_SMOOTH, 0, 1)
	local p = smoothPresence

	local camera = workspace.CurrentCamera
	if not camera or not wallPart or not emitter or not root or not root.Parent then
		return
	end

	if p < 0.01 then
		emitter.Enabled = false
		return
	end
	emitter.Enabled = true

	--[[
		Pin the wall just inside the fog, or at the front's true distance if that is nearer.

		The `min` is what keeps it visible. Fog at intensity 2 ends near 2260 while the front can still be
		2500 out, and drawing it truthfully would mean drawing nothing at all.
	]]
	local trueDistance = attr("StormDistance", 4200)
	local visibleLimit = Lighting.FogEnd * INSIDE_FOG
	local distance = math.min(trueDistance, visibleLimit)

	local camPos = camera.CFrame.Position
	local flatCam = Vector3.new(camPos.X, 0, camPos.Z)

	--[[
		Height rises as it closes, so the wall grows in the frame rather than merely darkening. Angular
		size is what a person actually reads as "approaching" - a mass that gets darker without getting
		bigger reads as nightfall.
	]]
	local height = 260 + 900 * p
	wallPart.Size = Vector3.new(3000 + 1200 * p, height, 400 + 300 * p)
	wallPart.CFrame = CFrame.new(flatCam + ASTERN * distance + Vector3.new(0, height * 0.35, 0))

	emitter.Rate = 4 + 22 * p
	emitter.Size = NumberSequence.new(360 + 260 * p, 620 + 420 * p)

	--[[
		Darkens toward black as it closes, and opens up as it recedes. Tied to presence rather than to the
		sea state's colours so the wall keeps its identity even while the sky is still bright - which is the
		whole point at intensity 1, when the sky has barely changed and the horizon astern has not.
	]]
	local shade = 0.42 - 0.34 * p
	emitter.Color = ColorSequence.new(Color3.new(shade, shade * 1.04, shade * 1.12))
	local floor = 0.62 - 0.34 * p -- more opaque as it closes
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, floor),
		NumberSequenceKeypoint.new(0.75, floor),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function CloudWallVFX.report(): string
	return table.concat({
		("intensity      %d  (silent below %d)"):format(attr("StormIntensity", 0), MIN_INTENSITY),
		("presence       %.2f -> smoothed %.2f"):format(presence(), smoothPresence),
		("true distance  %.0f studs"):format(attr("StormDistance", 4200)),
		("drawn at       %.0f studs  (fog ends %.0f, pinned to %.0f%% of it)"):format(
			math.min(attr("StormDistance", 4200), Lighting.FogEnd * INSIDE_FOG),
			Lighting.FogEnd, INSIDE_FOG * 100),
		("emitting       %s  rate %.0f"):format(
			tostring(emitter and emitter.Enabled), emitter and emitter.Rate or -1),
		("running        %s"):format(tostring(connection ~= nil)),
	}, "\n")
end

return CloudWallVFX
