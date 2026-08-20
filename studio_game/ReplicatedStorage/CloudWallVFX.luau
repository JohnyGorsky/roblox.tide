--!strict
--[[
	CloudWallVFX - the thing you turn round and look at.

	Feature: docs/features/0003-storm-front/  ·  decision 0020  ·  job 018

	--------------------------------------------------------------------------------------------------
	THIS IS THE STORM'S DIAGNOSTIC, NOT DECORATION

	Decision 0020 makes rain, chop, wind and closing fog ORDINARY - they happen on afternoons that mean
	nothing. That left the storm needing one signal weather can never counterfeit. This is it: a dark mass
	astern that only ever grows.

	The rule that matters most is about the INPUT, not the look:

	    🔴 driven by StormIntensity / StormDistance - NEVER by Wind or Precipitation.

	Drive it off either of those and a breezy afternoon grows a wall, destroying the one unambiguous cue the
	crew has.

	--------------------------------------------------------------------------------------------------
	🔴 FOUR ATTEMPTS. THE HISTORY IS THE DOCUMENTATION.

	  1. Particles parented to the CAMERA at ~1000 studs, placed at 82% of FogEnd. Invisible twice over:
	     camera-parenting is a viewmodel technique meant for things a few studs from the lens (finding 0016),
	     and 82% of FogEnd is ~81% occluded so the fog erased it anyway (finding 0014).

	  2. Anchored slab geometry in an arc. This DID render - and read as flat grey cards with hard vertical
	     lines between them. The segments overlapped, and two surfaces at 39% transparency composite into a
	     visibly DARKER strip, so the gap-hiding factor became the artefact; and on an arc, adjacent slabs
	     face 22° apart, catch the directional light differently, and every boundary becomes a crease.
	     Lesson: a flat transparent surface ALWAYS reads as a card. Not tunable.

	  3. Particles only, in Workspace, at their true ~1000 studs. Nothing visible at all - while the slabs
	     from attempt 2 had rendered fine at that exact distance. So the failure is specific to particles at
	     range, with two plausible causes I could not distinguish without eyes on the scene: Roblox culling
	     distant emitters, or a cap on rendered particle size well below the ~1000 studs the property accepts.

	  4. This one. DRAWN NEAR, MADE TO LOOK FAR - which defeats both candidate causes at once instead of
	     gambling on picking the right one.

	--------------------------------------------------------------------------------------------------
	HOW "DRAWN NEAR, LOOKS FAR" WORKS

	The bank sits at a fixed 340 studs with modest particle sizes, so nothing can cull it and no plausible
	size cap applies. Apparent distance is then produced the way it actually reaches the eye:

	    ANGULAR SIZE   width and height are authored as ANGLES and converted at the render distance, so the
	                   bank subtends exactly what it would have if drawn a kilometre away
	    HAZE           colour is blended toward the fog colour, and opacity reduced, by the occlusion the
	                   TRUE distance would have produced - since real fog cannot do that from 340 studs

	This is the trick every skybox uses, and it has a real bonus: fog can no longer erase the wall, because
	haze is now applied deliberately rather than suffered.

	What it gives up is parallax - the bank does not shift as the player moves. At a simulated kilometre that
	is imperceptible, and it is the same compromise a skybox makes.

	Everything lives in a Workspace folder. Client-created, so never replicated.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local CloudWallVFX = {}

--- Bearing the front lies on. Matches Lightning.ASTERN_BEARING: progress runs +Z, the storm chases from -Z.
local ASTERN = Vector3.new(0, 0, -1)

--[[
	Near enough that no culling or size cap can apply. Everything below is authored against this.

	🔴 IT CANNOT BE A CONSTANT, and that bug is worth recording: the wall VANISHED at the last phase.

	Inside The Wall the composed fog closes to `FogEnd = 330`, so a bank pinned at 340 studs was being drawn
	BEYOND the fog and erased completely - at exactly the moment it should be swallowing the crew. The same
	class of mistake as finding 0014, just from the other side: there, the wall was too far into the fog;
	here, the fog came in past the wall.

	So the render distance follows the fog, and because every dimension below is authored as an ANGLE, the
	bank's apparent size is unaffected by it moving. That is the property that makes this safe to change.
]]
local RENDER_DISTANCE_MAX = 340

local function renderDistance(): number
	-- always comfortably inside the fog, however tight the fog gets
	return math.clamp(math.min(RENDER_DISTANCE_MAX, Lighting.FogEnd * 0.5), 45, RENDER_DISTANCE_MAX)
end

--[[
	The bank's apparent size, in DEGREES rather than studs.

	Authoring angles is what makes the near-field trick honest: these are what the player actually perceives,
	and they stay correct no matter what `RENDER_DISTANCE` is set to.

	140° wide is deliberate. A narrow wall is indistinguishable from a missing one to anyone without a
	compass, and that ambiguity alone cost a full round of debugging.
]]
--[[
	The arc WIDENS as the front closes, from a band astern to something wrapped most of the way round.

	Emitters are placed on an arc of bearings rather than along a straight line, which is only safe because
	particles are camera-facing billboards - there are no facets to catch the light differently, so the
	crease problem that killed the slab version cannot happen here. It also means the arc can exceed 180°,
	which a straight line could never do.
]]
local ARC_MIN_DEG = 140
local ARC_MAX_DEG = 230 -- wrapped past the sides; inside the front there is no clear horizon left

--[[
	Elevation, and this is the "come more and more" ramp.

	14° is a smudge on the horizon. 76° is very nearly overhead - at the last phase the front should be
	ENGULFING rather than standing off as a tall band, because that is the moment the crew is inside it.
	It was 42°, which topped out looking like a distant wall no matter how close the storm actually got.
]]
local ELEVATION_MIN_DEG = 14
local ELEVATION_MAX_DEG = 76

--[[
	Several emitters across the width rather than one.

	One emitter is a single clump with a recognisable centre. Spaced emitters read as a continuous bank, and
	being independently seeded they never form a pattern. Odd count so one sits dead astern.
]]
local EMITTER_COUNT = 9

--[[
	Particle size, in studs at the render distance.

	Kept modest on purpose - this is the number attempt 3 got wrong, asking for 560-1000. Small enough that
	no plausible engine cap bites, and density comes from having several rather than from each being vast.
]]
local PARTICLE_MIN = 70
local PARTICLE_MAX = 190

--[[
	Presence: clearly visible at PHASE 1, on the user's instruction.
	The power curve front-loads it - intensity 1 lands at ~0.56 where a linear ramp gave 0.34.
]]
local PRESENCE_FLOOR = 0.18
local PRESENCE_CURVE = 0.55

--[[
	The particle texture.

	`smoke_main` is a soft radial alpha blob, which is the whole reason this can work where geometry could
	not: every particle fades to nothing at its own edge, so the mass has no silhouette line anywhere, and
	overlapping particles build density instead of banding.
]]
local CLOUD_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

--[[
	The two ends of the bank's colour ramp.

	Both were far too light: the pale end at 158,166,176 was practically white, and once the haze blend had
	lifted it further the wall read as a light grey mist rather than as weather. Even the "far" end of a
	storm front is dark - that is what makes it a front and not a cloud.

	`STORM_GREY` is the calm-day end, and it is still a dark slate. `BLACK` is genuinely near-black, because
	The Wall is supposed to look like the world has stopped existing.
]]
local STORM_GREY = Color3.fromRGB(78, 84, 92)
local BLACK = Color3.fromRGB(6, 7, 9)

local root: Folder? = nil
local emitters: { ParticleEmitter } = {}
local parts: { BasePart } = {}
local connection: RBXScriptConnection? = nil

local smoothPresence = 0
local PRESENCE_SMOOTH = 3.0 -- slow. A wall that snaps into being is a wall nobody believes.

local function attr(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

local function presence(): number
	local intensity = math.clamp(attr("StormIntensity", 0), 0, 4)
	return PRESENCE_FLOOR + (1 - PRESENCE_FLOOR) * ((intensity / 4) ^ PRESENCE_CURVE)
end

--[[
	The distance the bank is PRETENDING to be at, and how hazy that implies it should look.

	Not where it is drawn. Used only to derive the haze, so a front still 3 km out looks washed out and a
	front on top of you looks hard-edged.
]]
local function simulated(): (number, number)
	local fogStart, fogEnd = Lighting.FogStart, Lighting.FogEnd
	local span = math.max(1, fogEnd - fogStart)
	local distance = math.max(200, math.min(attr("StormDistance", 4200), fogStart + span * 0.55))
	local haze = math.clamp((distance - fogStart) / span, 0, 0.85)
	return distance, haze
end

function CloudWallVFX.start()
	CloudWallVFX.stop()

	local f = Instance.new("Folder")
	f.Name = "CloudWall"
	f.Parent = workspace -- WORLD, not the camera. See the header.
	root = f

	for i = 1, EMITTER_COUNT do
		local p = Instance.new("Part")
		p.Name = "Bank" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false -- must never be raycast; the wave field and buoyancy both raycast
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1 -- the PART is never visible. Only its particles are. No card, ever.
		p.Size = Vector3.new(120, 120, 60)
		p.Parent = f
		table.insert(parts, p)

		local e = Instance.new("ParticleEmitter")
		e.Name = "Cloud"
		e.Texture = CLOUD_TEXTURE
		e.Rate = 0
		--[[
			Long lifetimes, low rate: the bank ACCUMULATES into a standing mass rather than streaming past.
			Anything fast enough to see moving reads as smoke from a fire, not as weather.
		]]
		e.Lifetime = NumberRange.new(12, 20)
		e.Speed = NumberRange.new(0.2, 1.2)
		e.SpreadAngle = Vector2.new(40, 25)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-2, 2) -- slow churn
		e.LightEmission = 0
		--[[
			Mostly unlit.

			At 1 the bank went almost black under a storm sky and vanished against it; at 0 it ignores the
			scene entirely and floats free of the lighting. It sat at 0.5, which in bright daylight meant the
			sun was washing the wall out - a third source of the "too light" problem, alongside the pale
			palette and the haze blend.

			0.25 keeps a little response to the weather while letting the authored dark colour dominate. The
			front should look dark AT NOON; that is the whole point of it.
		]]
		e.LightInfluence = 0.25
		e.Size = NumberSequence.new(PARTICLE_MIN, PARTICLE_MAX)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Transparency = NumberSequence.new(0.5)
		e.Parent = p
		table.insert(emitters, e)
	end

	connection = RunService.RenderStepped:Connect(function(dt)
		CloudWallVFX.step(dt)
	end)
	CloudWallVFX.prime()
	return true
end

function CloudWallVFX.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	--[[
		Scoped to Workspace and matched exactly. A previous cleanup matched names across containers and
		destroyed ReplicatedStorage.StormVFX - and because Studio Sync is two-way, the source FILE with it
		(finding 0015). Never widen this.
	]]
	local existing = workspace:FindFirstChild("CloudWall")
	if existing and existing:IsA("Folder") then
		existing:Destroy()
	end
	root = nil
	table.clear(emitters)
	table.clear(parts)
	smoothPresence = 0
end

function CloudWallVFX.step(dt: number)
	local target = presence()
	smoothPresence += (target - smoothPresence) * math.clamp(dt / PRESENCE_SMOOTH, 0, 1)
	local p = smoothPresence

	local camera = workspace.CurrentCamera
	if not camera or not root or not root.Parent or #emitters == 0 then
		return
	end

	local _, haze = simulated()
	local distance = renderDistance()

	-- Angles converted to studs AT THE RENDER DISTANCE, so apparent size is what was authored.
	local arc = ARC_MIN_DEG + (ARC_MAX_DEG - ARC_MIN_DEG) * p
	local elevation = ELEVATION_MIN_DEG + (ELEVATION_MAX_DEG - ELEVATION_MIN_DEG) * p
	local height = distance * math.tan(math.rad(elevation))

	--[[
		Particle sizes scale with the render distance, so they keep a constant APPARENT size as the bank
		moves in to stay inside the fog. Without this, the tightening fog would silently make every particle
		look bigger, and the bank would bloat into a few enormous blobs at the last phase.
	]]
	local sizeScale = distance / RENDER_DISTANCE_MAX

	local camPos = camera.CFrame.Position
	local ground = Vector3.new(camPos.X, 0, camPos.Z)

	--[[
		HAZE, applied by hand.

		Real fog cannot do this from 340 studs, so the bank is blended toward the fog colour and thinned by
		the occlusion its pretend distance implies. This is what stops a near-drawn bank looking like a
		near object - and it is why fog can no longer erase it.
	]]
	--[[
		HAZE LIGHTENS, SO IT IS KEPT ON A SHORT LEASH.

		This factor was 0.75, and it was the main reason the wall read as a pale mist: at 55% haze it dragged
		the colour 41% of the way toward the fog colour, which in fair weather is a LIGHT grey. So the more
		distant the front, the whiter it went - the opposite of what a front should look like.

		0.28 keeps just enough atmospheric lift to sell the distance without bleaching it.
	]]
	local shade = STORM_GREY:Lerp(BLACK, p):Lerp(Lighting.FogColor, haze * 0.28)
	--[[
		Opacity per particle.

		Was (0.46 - 0.20p) + haze*0.28, which came out around 0.51 at phase 1 - half transparent, on top of
		a colour that was already too light. Roughly doubled now.

		It is still not opaque, and that is deliberate: density has to come from MANY overlapping soft
		sprites, because that is what produces a cloud edge. Push individual particles to solid and each one
		becomes legible AS a blob, which is the particle equivalent of the flat-card problem from attempt 2.
	]]
	local alpha = (0.24 - 0.13 * p) + haze * 0.12

	--[[
		Chord between neighbouring emitters, so each part is wide enough to meet the next with no gap. Uses
		`sin` of the half-step rather than a flat division, because on a wide arc the straight-line distance
		between two bearings is noticeably less than the arc length between them.
	]]
	local stepDeg = arc / EMITTER_COUNT
	local chord = 2 * distance * math.sin(math.rad(stepDeg / 2))

	for i, part in ipairs(parts) do
		local bearing = math.rad(180 + ((i - 0.5) / EMITTER_COUNT - 0.5) * arc)
		local dir = Vector3.new(math.sin(bearing), 0, math.cos(bearing))
		-- a little depth variation, so the bank has thickness rather than reading as one flat layer
		local depth = 1 + ((i % 3) - 1) * 0.10
		part.Size = Vector3.new(chord * 1.35, height, 70 * sizeScale)
		part.Position = ground + dir * (distance * depth) + Vector3.new(0, height * 0.32, 0)
		-- face the crew, so the emission box is seen broadside rather than edge-on
		part.CFrame = CFrame.lookAt(part.Position, Vector3.new(ground.X, part.Position.Y, ground.Z))

		local e = emitters[i]
		--[[
			⚠️ RATE IS AN OVERDRAW BUDGET, NOT A DENSITY DIAL.

			rate x lifetime x emitters = particles alive, and each of these sprites subtends ~40° of view at
			the render distance. Getting this wrong is how the storm kills a phone, and the storm is already
			this game's most expensive moment.

			An earlier setting here read 2.5 + 5.5p, which came out at 500-1100 alive - roughly four times
			the overdraw of the version before it, in the name of density. Held to ~150-260 instead. If the
			bank looks thin, raise PARTICLE_MIN/MAX (one draw each) before raising this (a draw per particle).
		]]
		e.Rate = 0.7 + 1.1 * p
		e.Size = NumberSequence.new(
			(PARTICLE_MIN + 30 * p) * sizeScale,
			(PARTICLE_MAX + 70 * p) * sizeScale)
		e.Color = ColorSequence.new(shade)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, alpha),
			NumberSequenceKeypoint.new(0.82, alpha),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Enabled = p > 0.02
	end
end

--- Bearing to look along to see the wall. No vessel or compass yet, so this is how you find it.
function CloudWallVFX.bearing(): number
	return 180
end

--[[
	Fill the bank NOW instead of waiting for particles to accumulate.

	Necessary, not a nicety: with 12-20 second lifetimes a freshly started bank is nearly empty for the first
	half-minute, which to anyone testing is indistinguishable from a wall that is not being drawn. That is
	exactly the confusion this feature has already caused twice.

	A fixed burst, deliberately NOT scaled by presence - the previous version multiplied by `smoothPresence`,
	which is 0 on the frame `start()` runs, so it emitted 2 particles and did nothing useful.
]]
function CloudWallVFX.prime()
	for _, e in ipairs(emitters) do
		e:Emit(26)
	end
end

function CloudWallVFX.report(): string
	local distance, haze = simulated()
	local p = smoothPresence
	local elevation = ELEVATION_MIN_DEG + (ELEVATION_MAX_DEG - ELEVATION_MIN_DEG) * p
	local alive = 0
	for _, e in ipairs(emitters) do
		alive += e.Rate * ((e.Lifetime.Min + e.Lifetime.Max) / 2)
	end
	local e1 = emitters[1]
	return table.concat({
		("intensity      %d"):format(attr("StormIntensity", 0)),
		("presence       %.2f -> smoothed %.2f  (phase 1 lands at %.2f)"):format(
			presence(), p, PRESENCE_FLOOR + (1 - PRESENCE_FLOOR) * ((1 / 4) ^ PRESENCE_CURVE)),
		("DRAWN AT       %d studs  (fixed - near enough that nothing can cull it)"):format(RENDER_DISTANCE),
		("pretending     %.0f studs, haze %.0f%% applied by hand"):format(distance, haze * 100),
		("apparent size  %d deg wide, %.0f deg tall"):format(ARC_DEGREES, elevation),
		("particles      ~%.0f alive, %.0f..%.0f studs each, alpha %.2f"):format(
			alive,
			e1 and e1.Size.Keypoints[1].Value or 0,
			e1 and e1.Size.Keypoints[2].Value or 0,
			e1 and e1.Transparency.Keypoints[2].Value or 0),
		("colour         %s"):format(e1 and tostring(e1.Color.Keypoints[1].Value) or "?"),
		("emitting       %s"):format(tostring(e1 and e1.Enabled)),
		("NO GEOMETRY    every part is Transparency 1; only particles are visible"),
		("look toward    bearing 180 (0 = +Z north, so this is -Z)"),
		("running        %s"):format(tostring(connection ~= nil)),
	}, "\n")
end

return CloudWallVFX
