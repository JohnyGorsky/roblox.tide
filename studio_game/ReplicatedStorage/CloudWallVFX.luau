--!strict
--[[
	CloudWallVFX - the thing you turn round and look at.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	--------------------------------------------------------------------------------------------------
	THIS IS THE STORM'S DIAGNOSTIC, NOT DECORATION

	Decision 0020 makes rain, chop, wind and closing fog ORDINARY - they happen on afternoons that mean
	nothing. That was right for making the world feel natural, and it left the storm needing one signal that
	weather can never counterfeit. This is it: a dark mass astern that only ever grows.

	So the rule that matters most is about the INPUT, not the look:

	    🔴 driven by StormIntensity / StormDistance - NEVER by Wind or Precipitation.

	Wind and precipitation are shared with everyday weather. Drive the wall off either and a breezy afternoon
	grows a wall, destroying the one unambiguous cue the crew has.

	--------------------------------------------------------------------------------------------------
	🔴 GEOMETRY FIRST, PARTICLES SECOND. THIS WAS REWRITTEN FOR A REASON.

	The first version was particles alone, and the user could not see it at all. Two causes, and the second
	is the lesson:

	  1. It was placed at 82% of `FogEnd`, which is ~81% OCCLUDED, so the fog in front erased it
	     (finding 0014). Fixed by placing at a target occlusion instead.

	  2. The emitter part was parented to `workspace.CurrentCamera` at ~1000 studs. Camera-parenting is a
	     VIEWMODEL technique - it is for things a few studs from the lens, like the rain rig. Using it for a
	     distant world-scale object put the wall's rendering into a path it was never meant for.

	The deeper mistake was betting the whole feature on one uncertain mechanism. A silhouette this important
	should not depend on particle rendering behaving a particular way at a kilometre. So now:

	    SLABS      real anchored geometry in Workspace, arranged as an arc. GUARANTEED to render.
	    PARTICLES  churn along the top edge only, so the silhouette is ragged instead of a clean rectangle.

	If the particles fail for any reason the wall is still there. That is the property that was missing.

	These are created on the CLIENT and live in Workspace, so they are never replicated to the server and
	never touch anyone else's session.

	--------------------------------------------------------------------------------------------------
	FOG IS THE CONSTRAINT THAT SHAPES ALL OF THIS

	At intensity 2 the composed fog ends near 2280 while the front may still be 2500 away, so a wall drawn at
	its true distance would be invisible and the crew's warning would arrive far too late.

	It is therefore drawn at a fixed target OCCLUSION and made to GROW. What the player reads is "the horizon
	astern is darkening and rising", which is honest - that is exactly what an approaching front looks like
	from a small boat - while staying visible at every stage.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local CloudWallVFX = {}

--- Bearing the front lies on. Matches Lightning.ASTERN_BEARING: progress runs +Z, the storm chases from -Z.
local ASTERN_BEARING = 180

--[[
	How wide an arc the wall covers, in degrees.

	Deliberately very wide. `Part.Size` silently CLAMPS AT 2048 studs (measured - asking for 3000 returned
	2048), so one slab cannot span the horizon; and a narrow wall means a player who turns slightly the wrong
	way sees an empty sky and concludes there is nothing there. Which is exactly what happened.

	200° means it is behind you and well round both sides, so any glance backwards finds it.
]]
local ARC_DEGREES = 200
local SEGMENTS = 9

--[[
	Presence floor, and the curve from intensity to presence.

	The wall must be clearly visible at PHASE 1, not merely present - it is the crew's early tell, and the
	first version showed almost nothing until the front was already close. The power curve front-loads it:
	intensity 1 lands at ~0.55 rather than the 0.34 a linear ramp gave.
]]
local PRESENCE_FLOOR = 0.18
local PRESENCE_CURVE = 0.55

--- Target fraction of the fog between camera and wall. Above ~0.6 the fog erases it (finding 0014).
local TARGET_OCCLUSION = 0.35

local PALE = Color3.fromRGB(126, 133, 142)
local NEAR_BLACK = Color3.fromRGB(17, 19, 23)

local root: Folder? = nil
local slabs: { BasePart } = {}
local emitters: { ParticleEmitter } = {}
local connection: RBXScriptConnection? = nil

local smoothPresence = 0
local PRESENCE_SMOOTH = 3.0 -- slow. A wall that snaps into being is a wall nobody believes.

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

--- 0..1. From INTENSITY, so it steps with the same bands as the sea state and the lighting.
local function presence(): number
	local intensity = math.clamp(attr("StormIntensity", 0), 0, 4)
	return PRESENCE_FLOOR + (1 - PRESENCE_FLOOR) * ((intensity / 4) ^ PRESENCE_CURVE)
end

--- Where the wall sits, and how much air is in front of it. Shared by `step` and `report`.
local function placement(): (number, number)
	local fogStart, fogEnd = Lighting.FogStart, Lighting.FogEnd
	local span = math.max(1, fogEnd - fogStart)
	local wanted = fogStart + span * TARGET_OCCLUSION
	-- never draw it FURTHER than the front actually is; a wall ahead of the storm would be a lie
	local distance = math.max(120, math.min(attr("StormDistance", 4200), wanted))
	local occlusion = math.clamp((distance - fogStart) / span, 0, 1)
	return distance, occlusion
end

function CloudWallVFX.start()
	CloudWallVFX.stop()

	local f = Instance.new("Folder")
	f.Name = "CloudWall"
	f.Parent = workspace -- WORLD, not the camera. See the header.
	root = f

	for i = 1, SEGMENTS do
		local slab = Instance.new("Part")
		slab.Name = "Slab" .. i
		slab.Anchored = true
		slab.CanCollide = false
		slab.CanQuery = false -- must never be hit by a raycast; the wave field and buoyancy both raycast
		slab.CanTouch = false
		slab.CastShadow = false
		slab.Material = Enum.Material.SmoothPlastic -- flat and unlit-looking; cloud has no specular
		slab.Color = PALE
		slab.Transparency = 1
		slab.Size = Vector3.new(400, 300, 24)
		slab.Parent = f
		table.insert(slabs, slab)

		--[[
			Churn on the TOP EDGE only.

			A slab alone reads as a wall of card, and the giveaway is its perfectly straight top. Particles
			are spent entirely on breaking that line - which is cheap, because only the silhouette needs
			them, and it means the body of the wall never depends on particle rendering.
		]]
		if i % 2 == 1 then
			local e = Instance.new("ParticleEmitter")
			e.Name = "Churn"
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Rate = 0
			e.Lifetime = NumberRange.new(9, 15)
			e.Speed = NumberRange.new(1, 4)
			e.SpreadAngle = Vector2.new(30, 12)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-3, 3)
			e.LightEmission = 0
			e.LightInfluence = 1
			e.Size = NumberSequence.new(160, 320)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.EmissionDirection = Enum.NormalId.Top
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(0.7, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Parent = slab
			table.insert(emitters, e)
		end
	end

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
	-- named exactly, and only under Workspace, so this can never reach a ReplicatedStorage module
	local existing = workspace:FindFirstChild("CloudWall")
	if existing and existing:IsA("Folder") then
		existing:Destroy()
	end
	root = nil
	table.clear(slabs)
	table.clear(emitters)
	smoothPresence = 0
end

function CloudWallVFX.step(dt: number)
	local target = presence()
	smoothPresence += (target - smoothPresence) * math.clamp(dt / PRESENCE_SMOOTH, 0, 1)
	local p = smoothPresence

	local camera = workspace.CurrentCamera
	if not camera or not root or not root.Parent or #slabs == 0 then
		return
	end

	local distance = placement()
	local camPos = camera.CFrame.Position
	local centre = Vector3.new(camPos.X, 0, camPos.Z)

	--[[
		Height rises as it closes, so the wall GROWS in the frame rather than only darkening. Angular size is
		what a person reads as "approaching" - a mass that darkens without growing reads as nightfall.
	]]
	local height = 340 + 1150 * p
	--[[
		Slab width from the arc length, so the segments meet edge to edge at any distance. The 1.25 overlap
		factor hides the seams: nine flat slabs on a curve leave visible gaps at the joins otherwise, and a
		gap in a cloud bank looks like a hole in the sky.
	]]
	local arcLength = 2 * math.pi * distance * (ARC_DEGREES / 360)
	local width = math.min(2048, (arcLength / SEGMENTS) * 1.25)

	local shade = PALE:Lerp(NEAR_BLACK, p)
	-- more opaque as it closes; never fully solid, so fog and sky still read through it
	local transparency = 0.62 - 0.42 * p

	for i, slab in ipairs(slabs) do
		local offset = ((i - 0.5) / SEGMENTS - 0.5) * ARC_DEGREES
		local bearing = math.rad(ASTERN_BEARING + offset)
		local dir = Vector3.new(math.sin(bearing), 0, math.cos(bearing))
		local position = centre + dir * distance + Vector3.new(0, height * 0.38, 0)

		slab.Size = Vector3.new(width, height, 24)
		-- face the camera's ground position, so every segment is seen flat-on rather than edge-on
		slab.CFrame = CFrame.lookAt(position, Vector3.new(centre.X, position.Y, centre.Z))
		slab.Color = shade
		slab.Transparency = transparency
	end

	for _, e in ipairs(emitters) do
		e.Rate = 3 + 9 * p
		e.Size = NumberSequence.new(140 + 120 * p, 280 + 260 * p)
		e.Color = ColorSequence.new(shade)
		local floor = 0.66 - 0.36 * p
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, floor),
			NumberSequenceKeypoint.new(0.7, floor),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Enabled = p > 0.02
	end
end

--- Bearing to look along to see the wall. There is no vessel or compass yet, so this is how you find it.
function CloudWallVFX.bearing(): number
	return ASTERN_BEARING
end

function CloudWallVFX.report(): string
	local distance, occlusion = placement()
	local slab = slabs[1]
	return table.concat({
		("intensity      %d"):format(attr("StormIntensity", 0)),
		("presence       %.2f -> smoothed %.2f  (phase 1 lands at %.2f)"):format(
			presence(), smoothPresence,
			PRESENCE_FLOOR + (1 - PRESENCE_FLOOR) * ((1 / 4) ^ PRESENCE_CURVE)),
		("true distance  %.0f studs"):format(attr("StormDistance", 4200)),
		("drawn at       %.0f studs"):format(distance),
		--[[
			🔴 THE NUMBER THAT MATTERS. Above ~0.6 the wall is erased by the fog in front of it, which is
			exactly how the first version came to be invisible while every other value read correct.
		]]
		("fog occlusion  %.0f%%  (target %.0f%%)  %s"):format(
			occlusion * 100, TARGET_OCCLUSION * 100,
			occlusion > 0.6 and "<-- TOO FOGGY, cannot be seen" or "ok"),
		("geometry       %d slabs across %d deg, %s"):format(
			#slabs, ARC_DEGREES, slab and ("%.0f x %.0f each, transparency %.2f"):format(
				slab.Size.X, slab.Size.Y, slab.Transparency) or "not built"),
		("churn          %d emitters, rate %.1f"):format(#emitters, emitters[1] and emitters[1].Rate or -1),
		("in Workspace   %s  (NOT camera-parented - see the header)"):format(
			tostring(workspace:FindFirstChild("CloudWall") ~= nil)),
		("look toward    bearing %d (0 = +Z north, so this is -Z)"):format(ASTERN_BEARING),
		("running        %s"):format(tostring(connection ~= nil)),
	}, "\n")
end

return CloudWallVFX
