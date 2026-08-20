--!strict
--[[
	Vessel - the KIT. Specs and construction, no behaviour.

	Feature: GAME-0001  ·  decisions 0005, 0009, 0022  ·  job 021

	--------------------------------------------------------------------------------------------------
	🔴 BUILD A VESSEL, NOT A BOAT

	Decision 0009: architect around a generic `Vessel` - a chassis plus named sockets, with a library of
	modules that fit those sockets. The starter launch is the kit's FIRST CUSTOMER, not the thing being built.

	The manifest is blunt that building a boat instead is the trap, because seven vessel classes then cost
	seven boats rather than one hull each. Everything in this file is therefore DATA about a hull; nothing
	here knows how to float, steer or burn fuel.

	--------------------------------------------------------------------------------------------------
	WHAT MAKES THE KIT REAL: NOTHING IS TUNED PER HULL

	A spec declares how deep the vessel should SIT (`draft`) - a design statement anyone can make from a
	reference photo - and `VesselPhysics` derives the buoyancy stiffness from it. See that module's header.

	The moment a bigger vessel needs its float hand-tuned, decision 0009's promise is broken and we have one
	boat with six copies. So specs carry dimensions, mass, draft, thrust and sockets. They never carry spring
	constants.

	--------------------------------------------------------------------------------------------------
	THE CLASS LADDER IS A TRIANGLE, NOT A LADDER

	    speed (Cutter)  --  capacity (Trawler)  --  agility (Launch)

	Larger vessels are SLOWER TO ACCELERATE and FASTER once going, because acceleration is `thrust/mass` while
	top speed is where thrust meets drag - independent numbers. That makes size a trade rather than an
	upgrade: more endurance, less opportunism. And the Trawler is deliberately slower than the smaller Patrol
	Boat, because it takes the cargo corner.

	Consequence for THIS hull: the launch must leave headroom. It sits at ~60-70% of the eventual top speed
	and wins on ACCELERATION, not speed. See docs/systems/vessels/README.md.
]]

local Vessel = {}

--[[
	Socket types. A module fits a socket of its own type and no other.

	Named rather than positional so a Trawler can have six storage sockets and no hardpoints without any code
	knowing that a Trawler exists.
]]
export type SocketType = "helm" | "engine" | "generator" | "radar" | "hardpoint" | "light" | "storage" | "station"

export type Socket = {
	kind: SocketType,
	offset: Vector3, -- relative to the hull's centre
	facing: number?, -- degrees of yaw, for things that should not face forward
}

export type Spec = {
	id: string,
	name: string,
	--- X = beam, Y = height, Z = length. The deck is the top face.
	size: Vector3,
	--[[
		Density, NOT mass - and it must be > 1.

		Terrain water buoys anything under 1.0 toward a FLAT Y=0 plane, which would fight the wave field and
		show up as jitter that reads like a tuning problem (decision 0022, finding 0008). A dense hull sinks,
		and every stud of lift then comes from one place.

		Mass follows from density x volume, so it can never disagree with the part that was actually built.
	]]
	density: number,
	--- How deep the hull bottom sits below the surface at rest. Buoyancy stiffness is derived from this.
	draft: number,
	--- Where buoyancy is sampled, relative to centre. COUNT MATTERS - see the note below.
	buoyancyPoints: { Vector3 },
	--- Newtons-ish at full throttle. Acceleration is this over mass, which is what "heavy" means.
	thrust: number,
	--- Studs/second the hull settles at under full throttle. Drag is derived to make this true.
	cruise: number,
	--- Radians/second of yaw at full steer, at cruise.
	turnRate: number,
	--- How hard it resists heeling. THE feel dial (decision 0022).
	rightingTorque: number,
	fuelCapacity: number,
	--- Litres-ish per second at full throttle.
	fuelBurn: number,
	sockets: { [string]: Socket },
}

--[[
	THE STARTER LAUNCH. 40 x 14 studs, freeboard 3 (decision 0022).

	Sizing reasoning, because it is not arbitrary:
	  40 long   ~11 m at Roblox's rough scale. A believable ex-military utility launch, and small enough that
	            the Patrol Boat and Trawler above it have room to feel bigger.
	  14 beam   a character is ~5 studs wide, so two crew can pass on deck. The manifest names this as the
	            real constraint, not looks.
	  5 tall    1.8 of draft below the waterline + 3.2 of freeboard above it.

	Freeboard 3 is chosen against the sea states, which is what makes weather MEAN something:
	    Light Swell  amp 0.8  ->  dry
	    Choppy       amp 2.0  ->  spray aboard
	    Storm        amp 4.5  ->  green water on deck
	    The Wall     amp 7.5  ->  swamped
]]
local STARTER_LAUNCH: Spec = {
	id = "StarterLaunch",
	name = "Old Launch",
	size = Vector3.new(14, 5, 40),
	--[[
		1.5, so it sinks decisively rather than hovering near neutral. Volume 14x5x40 = 2800, so mass
		lands at 4200 - which is what the storm's balance figures assume.
	]]
	density = 1.5,
	draft = 1.8,
	--[[
		FOUR CORNERS, at the bottom face.

		Corners rather than a bow/stern/port/starboard diamond: a corner point produces pitch AND roll
		together, which is what makes meeting a wave at an angle feel different from meeting it head-on. A
		diamond decouples the two and reads more mechanically.

		⚠️ The COUNT is part of the spec and must never be hardcoded in the physics. Four suits 40 studs.
		Four on a 200-stud hull makes it a rigid plank, because a long vessel has to feel the wave along its
		length - that wants six to eight.
	]]
	buoyancyPoints = {
		Vector3.new(-5.5, -2.5, 16), -- port bow
		Vector3.new(5.5, -2.5, 16), -- starboard bow
		Vector3.new(-5.5, -2.5, -16), -- port quarter
		Vector3.new(5.5, -2.5, -16), -- starboard quarter
	},
	--[[
		Thrust and cruise are separate numbers on purpose. Thrust over mass is ACCELERATION (how heavy it
		feels); cruise is where thrust meets drag (how fast it ends up). The launch is meant to win on the
		first and lose on the second.

		Cruise 18 rather than 24: ~60-70% of the eventual maximum, leaving the class ladder somewhere to go.
	]]
	thrust = 34000,
	cruise = 18,
	turnRate = 0.55,
	--[[
		Righting torque. THE dial that decides whether this feels like a boat or a bathtub toy.

		Deliberately touches the same axes the four-point buoyancy does, which the physics guidance warns
		about - accepted with open eyes, because no righting moment means capsizing from a crew member
		walking the deck, and a hard orientation lock means the sea does nothing. Tune against Choppy AND
		The Wall, never against Light Swell.
	]]
	rightingTorque = 900000,
	fuelCapacity = 100,
	fuelBurn = 0.55,
	--[[
		Sockets. Positions are provisional until the hull exists and can be walked on - which is exactly why
		the plan builds the chassis first and fits sockets last.
	]]
	sockets = {
		helm = { kind = "helm", offset = Vector3.new(0, 2.5, 8) },
		engine = { kind = "engine", offset = Vector3.new(0, 1.5, -14) },
		generator = { kind = "generator", offset = Vector3.new(-3, 1.5, -10) },
		radar = { kind = "radar", offset = Vector3.new(0, 6, 6) },
		hardpointFwd = { kind = "hardpoint", offset = Vector3.new(0, 3, 15) },
		hardpointAft = { kind = "hardpoint", offset = Vector3.new(0, 3, -15), facing = 180 },
		lightMast = { kind = "light", offset = Vector3.new(0, 7, 6) },
		storageAft = { kind = "storage", offset = Vector3.new(0, 3, -6) },
	},
}

Vessel.Specs = {
	StarterLaunch = STARTER_LAUNCH,
}

function Vessel.spec(id: string): Spec?
	return (Vessel.Specs :: any)[id]
end

--- Mass the spec implies. Derived rather than declared, so it can never disagree with the built part.
function Vessel.massOf(spec: Spec): number
	local v = spec.size
	return spec.density * (v.X * v.Y * v.Z)
end

--[[
	The Y offset at which the hull floats at its declared draft.

	`draft` measures from the WATERLINE to the hull's bottom, so the centre sits half a hull-height above the
	bottom, minus the draft. Stated once here rather than recomputed at every call site, because getting it
	wrong puts the boat's spawn point underwater and looks like a buoyancy failure.
]]
function Vessel.restingY(spec: Spec, waterY: number): number
	return waterY - spec.draft + spec.size.Y * 0.5
end

--[[
	Build the chassis.

	🔴 ONE PART for the whole physics assembly at this stage, deliberately.

	Anchoring any part of an assembly SPLITS it and disables its welds - the classic "my vehicle fell apart"
	bug - and every extra welded part is another chance to make that mistake. Visual modules will be welded
	on later and marked `Massless` so they cannot shift the centre of mass; the collision hull stays one box.

	The returned model has the hull as its `PrimaryPart`, so `PivotTo` places the vessel by the hull rather
	than by a bounding-box centre that includes a radar mast.
]]
function Vessel.build(spec: Spec, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = spec.id

	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = spec.size
	hull.CFrame = cframe
	hull.Anchored = false -- NEVER anchor this. See above, and decision 0022.
	hull.CanCollide = true
	hull.Material = Enum.Material.DiamondPlate
	hull.Color = Color3.fromRGB(75, 89, 100) -- Wet Steel, per the palette
	hull.TopSurface = Enum.SurfaceType.Smooth
	hull.BottomSurface = Enum.SurfaceType.Smooth
	hull.CustomPhysicalProperties = PhysicalProperties.new(
		spec.density,
		0.4, -- friction: crew should not slide off a wet deck at the slightest heel
		0.1, -- elasticity: a hull does not bounce off things
		1,
		1
	)
	hull.Parent = model
	model.PrimaryPart = hull

	--[[
		Attachments for the buoyancy points and the thrust point.

		Attachments rather than bare offsets so the forces can be inspected in the Explorer while running,
		which is most of how a physics bug gets diagnosed.
	]]
	local floats = Instance.new("Folder")
	floats.Name = "BuoyancyPoints"
	floats.Parent = hull
	for i, offset in ipairs(spec.buoyancyPoints) do
		local a = Instance.new("Attachment")
		a.Name = "Float" .. i
		a.Position = offset
		a.Parent = floats
	end

	local com = Instance.new("Attachment")
	com.Name = "Drive"
	com.Position = Vector3.new(0, 0, 0)
	com.Parent = hull

	--[[
		Sockets as named attachments. Empty for now - a module attaches to one later.

		They exist from the first build so that "where does the radar go" is answered by data rather than by
		a magic number in whatever script eventually needs it.
	]]
	local sockets = Instance.new("Folder")
	sockets.Name = "Sockets"
	sockets.Parent = hull
	for name, socket in pairs(spec.sockets) do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = socket.offset
		if socket.facing then
			a.Axis = Vector3.new(math.sin(math.rad(socket.facing)), 0, math.cos(math.rad(socket.facing)))
		end
		a:SetAttribute("SocketKind", socket.kind)
		a.Parent = sockets
	end

	model:SetAttribute("VesselSpec", spec.id)
	return model
end

return Vessel
