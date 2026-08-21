--!strict
--[[
	VesselServer - owns the hull, applies the forces, burns the fuel.

	Feature: GAME-0001  ·  decision 0022  ·  job 021

	--------------------------------------------------------------------------------------------------
	🔴 THE HULL IS SERVER-OWNED, ALWAYS. THIS IS NOT NEGOTIABLE.

	The `roblox-physics` skill records this as a paid-for lesson from the Jungle boat: a server loop computing
	force from a CLIENT-owned body's position pumps energy instead of removing it. The body's state arrives
	one round-trip late, so the spring-damper pushes on stale information and the vessel bounces higher and
	higher WHILE DRIVEN - while being rock-stable at rest, which makes it look like anything but a network
	problem.

	`VehicleSeat` is what causes it, by handing ownership to the driver on sit. So this vessel does not use
	one: input arrives over a RemoteEvent and the server never gives the assembly away. `enforceOwnership`
	below re-takes it every tick anyway, cheaply, because something else may eventually try.

	Two further reasons this game specifically needs server ownership:
	  * `StormFront.advance` reads the vessel's Z to buy distance from northward progress - the game's central
	    mechanic. A client-owned hull would feed it a lagged position.
	  * Fuel, damage and upgrades are already server-authoritative (the boat system doc requires it).

	Accepted cost: we owe the mobile touch controls that `VehicleSeat` would have given us free.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Vessel = require(ReplicatedStorage:WaitForChild("Vessel"))
local VesselPhysics = require(ReplicatedStorage:WaitForChild("VesselPhysics"))
local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))
local VesselDamage = require(ReplicatedStorage:WaitForChild("VesselDamage"))
local StormFront = require(ReplicatedStorage:WaitForChild("StormFront"))
local Expedition = require(ReplicatedStorage:WaitForChild("Expedition"))

local SPEC_ID = "StarterLaunch"

--[[
	Where the launch spawns. Clear of the observation deck, which sits at the origin.

	Deliberately NOT on top of anything: a hull intersecting geometry at spawn is a physics explosion, and the
	skill notes that a buried edge blows up the moment it is released.
]]
local SPAWN_OFFSET = Vector3.new(70, 0, 0)

local state = {
	model = nil :: Model?,
	hull = nil :: BasePart?,
	spec = nil :: any,
	floats = {} :: { { attachment: Attachment, force: VectorForce } },
	drive = nil :: VectorForce?,
	grip = nil :: VectorForce?,
	righting = nil :: AlignOrientation?,
	rudder = nil :: Torque?,
	heel = nil :: Torque?,
	trim = nil :: Torque?,
	stiffness = 0,
	damping = 0,
	drag = 0,
	linearDrag = 0,
	yawDamping = 0,
	rudderAuthority = 0,
	heelIn = 0,
	heelOut = 0,
	planingTrim = 0,
	inertialTrim = 0,
	maxDepth = 0,
	console = nil :: BasePart?,
	prompt = nil :: ProximityPrompt?,
	driver = nil :: Player?,
	throttle = 0,
	steer = 0,
	engineOn = true,
	fuel = 0,
	--[[
		DAMAGE (job 022, decision 0014). All of it derived - see `VesselDamage`.

		`faults` is what is wrong RIGHT NOW and can be repaired. `fired` is a separate record of which rungs
		of the ladder have already gone off, and the two must not be merged: without `fired`, repairing a
		breach while integrity is still below its threshold would re-break it on the very next frame, and
		damage control would be a button that does nothing.
	]]
	integrity = 0,
	integrityMax = 0,
	flooding = 0,
	faults = {} :: { [string]: boolean },
	fired = {} :: { [string]: boolean },
	engineCutUntil = 0,
	capsizedFor = 0,
	lost = false,
	station = nil :: BasePart?,
	repairing = false,
}

local remote = ReplicatedStorage:FindFirstChild("VesselInput")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "VesselInput"
	remote.Parent = ReplicatedStorage
end
local input = remote :: RemoteEvent

--[[
	Clear a stale `VesselHeading` if one was ever saved into the place. Cheap, and it means the attribute
	cannot survive as a leftover for a future HUD to find - see the note in `publish` and decision 0014.
]]
if workspace:GetAttribute("VesselHeading") ~= nil then
	workspace:SetAttribute("VesselHeading", nil)
end

--[[
	Publish to Workspace attributes, for the same reason every other system here does: the helm gauges, the
	storm and the admin panel all read them, and attributes replicate without a bespoke remote each.
]]
local function publish()
	local hull = state.hull
	workspace:SetAttribute("VesselFuel", state.fuel)
	workspace:SetAttribute("VesselFuelMax", state.spec and state.spec.fuelCapacity or 0)
	workspace:SetAttribute("VesselEngineOn", state.engineOn)
	workspace:SetAttribute("VesselThrottle", state.throttle)
	--[[
		DAMAGE STATE. Published because the crew is allowed to know the state of their own vessel - a hull
		integrity gauge and a "BREACH" lamp are diegetic instruments (group 09), not the free heading readout
		decision 0014 forbids. Knowing you are holed tells you nothing about which way is out.
	]]
	workspace:SetAttribute("VesselIntegrity", state.integrity)
	workspace:SetAttribute("VesselIntegrityMax", state.integrityMax)
	workspace:SetAttribute("VesselFlooding", state.flooding)
	workspace:SetAttribute("VesselLost", state.lost)
	for _, fault in ipairs(VesselDamage.LADDER) do
		workspace:SetAttribute("VesselFault_" .. fault.id, state.faults[fault.id] == true)
	end
	workspace:SetAttribute("VesselFault_steering", state.faults.steering == true)
	if hull then
		local forward = hull.CFrame.LookVector
		local vel = hull.AssemblyLinearVelocity
		workspace:SetAttribute("VesselSpeed", vel:Dot(forward))
		--[[
			🔴 HEADING IS NOT PUBLISHED. Removed in job 022; do not put it back.

			It used to be here as `VesselHeading`, in degrees, and nothing read it. Workspace attributes
			replicate, so the hull's heading was sitting on the wire waiting for the first HUD element that
			wanted a cheap compass - and decision 0014 is explicit that inside The Wall *"the HUD must never
			show a heading, or the blindness is free"*. The Wall's whole mechanic is that the crew steers by
			the instrument on the console, not by a number on the screen.

			Being straight about what this does and does not achieve: the hull is a replicated part, so any
			client can read `hull.CFrame` and work out the heading regardless. This is a DESIGN rule, not a
			secrecy mechanism - it removes the tempting shortcut, not the underlying information. The helm
			compass reads the hull's own orientation for exactly that reason, which is also what a real
			compass does.

			Speed stays published. A speed readout does not tell you which way is out.
		]]
	end
end

-- ---------------------------------------------------------------------------
-- DAMAGE (job 022, decision 0014)
-- ---------------------------------------------------------------------------

--[[
	🔴 THE FAULT SIDE-EFFECTS LIVE IN ONE PLACE, AND NONE OF THEM MUTATE A DERIVED CONSTANT.

	Steering damage is the temptation: the obvious implementation is `state.rudderAuthority *= 0.45`, and it
	works perfectly until the fault is repaired, at which point the hull is permanently soft because the
	original value is gone. Worse, `state.heelIn` was solved against that authority when the vessel was built,
	so scaling it would quietly de-tune the heel as well.

	So faults are FLAGS, read at the point of use, and every derived constant stays exactly as `buildVessel`
	computed it. Nothing here is destructive, which is what makes repair possible at all.
]]
local function faultLabel(id: string): string
	for _, f in ipairs(VesselDamage.LADDER) do
		if f.id == id then
			return f.label
		end
	end
	return if id == "steering" then "Steering damaged" else id
end

local function applyFault(id: string)
	state.faults[id] = true
	if id == "engine" then
		--[[
			The engine cut is TRANSIENT - it relights on its own after `ENGINE_CUT_SECONDS`.

			Deliberate, and it is the one rung that does not wait for damage control. A permanent engine loss
			inside The Wall is not a consequence, it is a death sentence: with no thrust the crew cannot buy
			any distance at all, so decision 0014's "escapable in 30-60 seconds" becomes unachievable by
			definition. What the cut does instead is spend the crew's margin - eight seconds of the front
			closing at 14 studs/s is 112 studs they now have to win back.
		]]
		state.engineCutUntil = os.clock() + VesselDamage.ENGINE_CUT_SECONDS
	end
	print(("[VESSEL] FAULT: %s"):format(faultLabel(id)))
end

--[[
	Fire the ladder's rungs, once each, as integrity falls.

	`fired` rather than `faults` is what gates this - see the note on the state table. A rung that has gone
	off stays gone off for the run, so repairing a breach does not hand the storm a free second one.
]]
local function updateFaultLadder()
	local lost = 1 - (state.integrity / math.max(state.integrityMax, 1))
	for _, fault in ipairs(VesselDamage.faultsAt(lost)) do
		if not state.fired[fault.id] then
			state.fired[fault.id] = true
			applyFault(fault.id)
		end
	end
end

--[[
	🟡 VESSEL LOSS IS A PLACEHOLDER, AND SAYING SO IS THE POINT.

	Decisions 0008 and 0011 settle what a crew KEEPS after a run - permanent progression is credited per
	player, run power resets - but nothing implements an expedition end, and the lobby is a separate place
	with no `TeleportService` flow built (todo 0006). So there is nothing correct to hand off to.

	What happens instead: the engine dies, the helm is released, buoyancy stops and she goes down, and
	`ExpeditionOver` is set for whatever eventually reads it. No progression is granted or taken, because
	inventing progression rules inside a storm-damage job is how two systems end up disagreeing about what a
	run is worth.

	Do not build on this. Build the expedition end, then delete the placeholder.
]]
local function loseVessel(reason: string)
	if state.lost then
		return
	end
	state.lost = true
	state.throttle, state.steer = 0, 0
	state.engineOn = false
	if state.driver then
		state.driver = nil
	end
	if state.prompt then
		state.prompt.Enabled = false
	end
	--[[
		ZERO EVERY FORCE, ONCE, HERE - rather than letting `step` keep writing zeros.

		Buoyancy included: the hull's density is 1.5 (see the spec), so with no lift she goes down on her own
		weight and needs nothing simulating her descent. Killing the forces at the source also means `step`
		can bail out immediately from now on, which is the difference between a wreck and a boat that is
		still being driven at the bottom of the sea.
	]]
	for _, entry in ipairs(state.floats) do
		entry.force.Force = Vector3.zero
	end
	if state.drive then state.drive.Force = Vector3.zero end
	if state.grip then state.grip.Force = Vector3.zero end
	if state.trim then state.trim.Torque = Vector3.zero end
	if state.rudder then state.rudder.Torque = Vector3.zero end
	if state.heel then state.heel.Torque = Vector3.zero end
	workspace:SetAttribute("VesselDriver", "")
	--[[
		🔴 `ExpeditionOver` IS NOT SET HERE ANY MORE (job 023).

		Job 022 set it directly, as an admitted placeholder for an expedition flow that did not exist. It
		exists now: `ExpeditionServer` watches `VesselLost` and decides that the RUN is over, which is a
		different statement from *the vessel is lost*. Two writers for one flag is how a run ends twice.

		The reason string stays, because it carries detail only this file knows - notably whether she
		capsized, which is how the run's cause is told apart from a plain hull failure.
	]]
	workspace:SetAttribute("ExpeditionOverReason", reason)
	local faults = {}
	for id, on in pairs(state.faults) do
		if on then
			table.insert(faults, id)
		end
	end
	table.sort(faults)
	warn(("[VESSEL] 🔴 VESSEL LOST - %s. distance %.0f, flooding %.0f%%, faults: %s. "
		.. "(ExpeditionServer resolves the run; the teleport home is still Planned 0002.)")
		:format(reason, StormFront.distance(), state.flooding * 100,
			#faults > 0 and table.concat(faults, ", ") or "none"))
	publish()
end

--[[
	DAMAGE CONTROL. One completed action clears the OLDEST outstanding fault and returns a slice of hull.

	Oldest-first rather than a menu, because a menu at the worst moment of the game is a menu nobody reads -
	and because the ladder's order already encodes what matters most. It also means a crew fighting a breach
	has to work the station repeatedly rather than cherry-picking, which is what makes a second pair of hands
	worth more than a bigger engine.

	⚠️ FREE, for now. Group 03's repair kits give it a resource cost; this is the mechanism, not the economy.
]]
local FAULT_REPAIR_ORDER = { "breach", "steering", "generator", "radar" }

local function repairOne(player: Player): (boolean, string)
	if state.lost then
		return false, "she is gone"
	end
	for _, id in ipairs(FAULT_REPAIR_ORDER) do
		if state.faults[id] then
			state.faults[id] = false
			state.integrity = math.min(state.integrityMax,
				state.integrity + state.integrityMax * VesselDamage.REPAIR_FRACTION)
			print(("[VESSEL] %s repaired: %s (integrity %.0f/%.0f)"):format(
				player.Name, faultLabel(id), state.integrity, state.integrityMax))
			publish()
			return true, faultLabel(id)
		end
	end
	--[[
		Nothing broken still returns integrity, at half rate. A crew that works the station while the storm
		grinds at the hull should not be told "nothing to do here" - shoring up a sound hull is exactly what
		damage control is, and it gives the second crew member something useful in the gap before the first
		fault lands.
	]]
	if state.integrity < state.integrityMax then
		state.integrity = math.min(state.integrityMax,
			state.integrity + state.integrityMax * VesselDamage.REPAIR_FRACTION * 0.5)
		publish()
		return true, "shored up"
	end
	return false, "she is sound"
end

local function buildVessel()
	local spec = Vessel.spec(SPEC_ID)
	if not spec then
		warn("[VESSEL] unknown spec " .. SPEC_ID)
		return
	end
	local mass = Vessel.massOf(spec)
	local points = #spec.buoyancyPoints
	local gravity = workspace.Gravity

	state.spec = spec
	state.stiffness = VesselPhysics.stiffness(mass, spec.draft, points, gravity)
	state.damping = VesselPhysics.damping(state.stiffness, mass, points)
	state.drag = VesselPhysics.dragCoefficient(spec.thrust, spec.cruise)
	state.linearDrag = VesselPhysics.linearDrag(spec.thrust, spec.cruise)
	--[[
		Cap the lift a single fully-submerged point can make at roughly twice the draft's worth. The spring is
		linear, so a hull thrown 7 studs deep by a storm wave would otherwise be launched back out like a
		beach ball.
	]]
	state.maxDepth = spec.draft * 2.5
	--[[
		Rudder authority and yaw damping, DERIVED from the hull's own moment of inertia and the desired lag.

		    inertiaY  = m/12 * (beam^2 + length^2)
		    damping   = inertiaY / rudderLag        -> sets the time constant
		    authority = turnRate * damping          -> sets the steady rate that damping settles at

		So a cutter with five times the inertia gets five times both numbers and behaves identically. This is
		the same principle as deriving buoyancy stiffness from mass and draft: the spec states intent, the
		physics derives the constants, and nothing is hand-tuned per hull.
	]]
	local inertiaY = mass / 12 * (spec.size.X ^ 2 + spec.size.Z ^ 2)
	state.yawDamping = inertiaY / math.max(spec.rudderLag, 0.1)
	state.rudderAuthority = spec.turnRate * state.yawDamping
	--[[
		Heel moments, converted from DEGREES to torque against the hull's own measured roll stiffness.

		Roll stiffness is `2 * K * lever^2` per radian for the two float points either side, which for this
		hull is 120,844 N-stud per degree. Deriving it means the spec can say "4 degrees" and mean it.
	]]
	--[[
		Pitch stiffness fore-and-aft, from the float geometry, so the trim angles in the spec mean degrees.
		Same derivation as the roll stiffness below, using the fore-aft lever instead of the beam.
	]]
	local pitchLever = math.abs(spec.buoyancyPoints[1].Z)
	local pitchPerDeg = 2 * state.stiffness * (pitchLever * math.sin(math.rad(1))) * pitchLever
	state.planingTrim = spec.planingTrimDeg * pitchPerDeg
	-- scaled by force, so full thrust gives the full angle and drag-only gives it bow-down
	state.inertialTrim = (spec.inertialTrimDeg * pitchPerDeg) / math.max(spec.thrust, 1)

	local lever = math.abs(spec.buoyancyPoints[1].X)
	local rollStiffnessPerDeg = 2 * state.stiffness * (lever * math.sin(math.rad(1))) * lever
	state.heelIn = (spec.heelInDeg * rollStiffnessPerDeg) / math.max(state.rudderAuthority, 1)
	state.heelOut = (spec.heelOutDeg * rollStiffnessPerDeg) / math.max(spec.turnRate * spec.cruise, 0.01)
	state.fuel = spec.fuelCapacity
	--[[
		DAMAGE, derived like everything else: the pool from the hull's own mass, the rate from the spec's
		`survivability`. Reset on every build so a rebuilt hull is a sound one - a vessel that came back from
		`recoverIfLost` still holed would be indistinguishable from a bug.
	]]
	state.integrityMax = VesselDamage.integrityFor(mass)
	state.integrity = state.integrityMax
	state.flooding = 0
	state.faults = {}
	state.fired = {}
	state.engineCutUntil = 0
	state.capsizedFor = 0
	state.lost = false

	local restingY = Vessel.restingY(spec, SeaStates.WATER_Y)
	local model = Vessel.build(spec, CFrame.new(SPAWN_OFFSET + Vector3.new(0, restingY, 0)))
	model.Parent = workspace
	--[[
		🔴 THE WHOLE SHIP IS A GRAYBOX, and it says so out loud.

		The hull is one DiamondPlate box and every fitting is another box welded to it. Registered as
		`GB-STARTER-LAUNCH` so `tools/audit-graybox.luau` reports it rather than letting a grey block quietly
		ship - the registry entry also records WHAT MUST SURVIVE the restyle, which matters more than the
		boxes do: the compass rules are decisions 0014 and 0023 wearing the appearance of styling.

		Tagged on the MODEL rather than on each part: it is one placeholder, not four.

		The audit knows this one is `runtime = true`, so it will not report it missing when run in Edit.
	]]
	CollectionService:AddTag(model, "Graybox")
	model:SetAttribute("GrayboxId", "GB-STARTER-LAUNCH")
	local hull = model.PrimaryPart :: BasePart
	state.model, state.hull = model, hull

	-- One VectorForce per buoyancy point, applied AT that point so the offsets create pitch and roll.
	local floatFolder = hull:FindFirstChild("BuoyancyPoints") :: Folder
	for _, attachment in ipairs(floatFolder:GetChildren()) do
		local force = Instance.new("VectorForce")
		force.Name = "Float_" .. attachment.Name
		force.Attachment0 = attachment :: Attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World -- buoyancy is always straight up, whatever the heel
		force.ApplyAtCenterOfMass = false -- the whole point: off-centre lift is what makes it tilt
		force.Force = Vector3.zero
		force.Parent = hull
		table.insert(state.floats, { attachment = attachment :: Attachment, force = force })
	end

	-- Thrust, along the hull's heading, through the centre of mass so it does not induce spin.
	local driveAt = hull:FindFirstChild("Drive") :: Attachment
	local drive = Instance.new("VectorForce")
	--[[
		Named distinctly from the `Drive` ATTACHMENT it hangs off. They were both called "Drive", so
		`hull:FindFirstChild("Drive")` returned whichever came first - and a diagnostic asking for the force
		got the attachment and errored on `.Force`. Cheap confusion, easily avoided.
	]]
	drive.Name = "DriveForce"
	drive.Attachment0 = driveAt
	--[[
		🔴 WORLD-RELATIVE, aimed explicitly along the hull's LookVector every frame.

		This was `Attachment0`-relative with `Force = (0, 0, net)`, on the assumption that local +Z is forward.
		It is NOT: `CFrame.LookVector` in Roblox is **-Z**. So thrust pushed the boat BACKWARD while
		`forwardSpeed` was measured forward - which made drag come out with the wrong sign and ADD to thrust
		instead of opposing it.

		That is a positive feedback loop. Speed rose without limit and flung the driver to their death. It read
		as "it speeds up fast and I die", which is exactly what it was.

		Aiming the force explicitly costs one vector multiply per frame and removes the entire class of
		sign-convention error. Worth it.
	]]
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ApplyAtCenterOfMass = true
	drive.Force = Vector3.zero
	drive.Parent = hull
	state.drive = drive

	--[[
		LATERAL GRIP - a second force, opposing sideways motion.

		This is the keel. Without it the hull turned on the spot and carried straight on, crabbing sideways
		with its nose pointed elsewhere, because nothing resisted sideways travel at all.

		Separate from the drive force rather than folded into it, so each force does one thing and can be read
		off in the Explorer while running. Applied at the centre of mass: a keel force applied aft would also
		yaw her, and yaw already has an owner.
	]]
	local grip = Instance.new("VectorForce")
	grip.Name = "LateralGrip"
	grip.Attachment0 = driveAt
	grip.RelativeTo = Enum.ActuatorRelativeTo.World -- aimed explicitly each frame; no sign conventions
	grip.ApplyAtCenterOfMass = true
	grip.Force = Vector3.zero
	grip.Parent = hull
	state.grip = grip

--[[
		🔴 NO AlignOrientation. REMOVED after auditing against the physics reference.

		There was one here, `PrimaryAxisOnly`, to keep the deck level. It is gone, and the reference says why:
		**"Don't stack two constraints controlling the same DOF (they oscillate)."**

		Three separate things were acting on PITCH:
		  1. the four-point buoyancy, whose whole purpose is to pitch and roll with the wave
		  2. `AlignOrientation`, which with `PrimaryAxisOnly` corrects pitch AND roll
		  3. the trim `Torque`, which deliberately pitches the bow up under power

		And the measurements make the choice obvious. Hydrostatic righting from the float geometry alone is
		120,844 N-stud per DEGREE of heel, rising to 3.4M at 30 degrees; a crew member standing right at the
		gunwale heels the hull 0.13 degrees. The trim torque is 4,090,732 - sixteen times the AlignOrientation's
		250,000. So the constraint was not stabilising anything and could not win any argument it entered. It
		was purely a fight, and it is most of what made the hull feel dead.

		The reference does recommend `AlignOrientation` for keeping a boat level - but that advice pairs with
		its single-point buoyancy pattern, where nothing else provides righting. With four points, hydrostatics
		IS the righting mechanism, and it is both stronger and more physical.

		⚠️ KNOWN LIMIT, accepted: past roughly 90 degrees of heel the float points leave the water and
		hydrostatics loses its lever, so a full capsize is unrecoverable. That is arguably correct for a small
		craft in The Wall, and capsizing belongs to the storm-damage job as a real failure state rather than
		being papered over by a constraint here.
	]]
	state.righting = nil

	--[[
		TRIM: the bow-up moment under power, and it has to be an explicit torque.

		Measured: pitch stiffness fore-aft is 1,022,683 N-stud per DEGREE. Applying thrust below the centre of
		mass - the obvious way to get a bow-up moment - yields at most 68,000, i.e. 0.07 degrees. Invisible. No
		arrangement of a 34,000 N thrust against a hull this stiff will lift the bow.

		That is a missing phenomenon rather than a failed approach: a real hull rises because of HYDRODYNAMIC
		lift at the stern as speed builds, and nothing here simulates that. So it is modelled directly.

		`RelativeTo = Attachment0` so the axis follows the hull - a bow-up torque must stay bow-up as she
		turns, which a world-relative torque would not.
	]]
	local trim = Instance.new("Torque")
	trim.Name = "Trim"
	trim.Attachment0 = driveAt
	--[[
		🔴 WORLD-relative, aimed along a HORIZONTAL axis each frame. This was `Attachment0`-relative about
		local X, and it was the single worst bug in the vessel.

		Measured: wheel dead amidships, flat water, throttle open - she yawed 178 degrees in 8 seconds.

		The trim torque is 4,090,732, by far the largest force on the hull. Applied about the hull's LOCAL X,
		it only takes a few degrees of roll for local X to gain a world-Y component, and a fraction of a
		4-million torque is an enormous yaw moment. At 5.6 degrees of roll that is ~400,000 of unintended yaw -
		nearly three times the rudder's entire authority.

		And it closes a loop: yaw -> centrifugal heel -> roll -> local X tilts further -> more yaw leaks.

		Exactly the same failure as the heel torque, which I fixed without realising trim had it too. The
		lesson worth keeping: a large torque applied in a body-relative frame leaks into every other axis the
		body rotates about. If a torque should only ever act about one world axis, aim it in world space.
	]]
	trim.RelativeTo = Enum.ActuatorRelativeTo.World
	trim.Torque = Vector3.zero
	trim.Parent = hull
	state.trim = trim

--[[
		🔴 THE RUDDER IS A TORQUE, NOT AN `AngularVelocity`.

		There was an `AngularVelocity` here. It is a SERVO - it drives to a commanded yaw rate, so the hull was
		already rotating at full rate the instant the wheel moved. No build-up, no lag, no dependence on the
		hull's own resistance to turning. The rotation was imposed rather than earned, and that is exactly what
		"it just rotates on the spot" is.

		A `Torque` plus yaw damping gives the balance a real rudder has, and the lag comes free: the time
		constant is inertia / damping, so the yaw builds over about a second.

		`RelativeTo = World` about Y, so momentum carries her through the turn - the drift is real, not scripted.
	]]
	local rudder = Instance.new("Torque")
	rudder.Name = "Rudder"
	rudder.Attachment0 = driveAt
	rudder.RelativeTo = Enum.ActuatorRelativeTo.World
	rudder.Torque = Vector3.zero
	rudder.Parent = hull
	state.rudder = rudder

	--[[
		HEEL. A separate torque about the hull's own forward axis, so it rolls with her at any heading.

		Two opposing moments live in here (see `VesselPhysics.heelMoment`): the rudder's inward flick and the
		centrifugal outward settle. Researched, not invented - a real hull does both, in that order.
	]]
	local heel = Instance.new("Torque")
	heel.Name = "Heel"
	heel.Attachment0 = driveAt
	--[[
		🔴 WORLD-relative, and aimed along a HORIZONTAL axis each frame. This was `Attachment0`-relative
		about local Z, and it made the boat SPIN UP TO 1.77 rad/s.

		The failure is a positive feedback loop, and it is worth spelling out:

		    heel torque about the hull's LOCAL Z
		      -> hull rolls
		      -> a rolled hull's local Z now has a world-Y COMPONENT
		      -> the roll torque leaks into YAW
		      -> more yaw raises the centrifugal heel term
		      -> more heel torque -> more yaw ...

		Aiming it along the hull's forward direction FLATTENED INTO THE HORIZONTAL PLANE makes it a pure roll
		about a horizontal axis, with no world-Y component to leak, however far she is heeled. The loop cannot
		close.
	]]
	heel.RelativeTo = Enum.ActuatorRelativeTo.World
	heel.Torque = Vector3.zero
	heel.Parent = hull
	state.heel = heel

	--[[
		🔴 THE HELM IS A STATION YOU STAND AT, NOT A SEAT YOU SIT IN. THIS IS THE SECOND REWRITE.

		The first version welded a `Seat` into the hull. Sitting in it DESTROYED THE BOAT, every time:

		    [VESSEL] johnygorsky10 took the helm
		    [VESSEL] hull ownership was taken by a client and has been reclaimed
		    [VESSEL] hull was LOST (removed by the engine) - rebuilding

		Sitting welds the character into the hull's assembly. Roblox then hands that assembly to the sitting
		player's client, because it contains their character - and `enforceOwnership` yanked it straight back,
		every single frame. A per-frame ownership tug-of-war over a body containing a client-simulated
		character tears it apart.

		The physics guidance says a per-frame re-grab "settles instantly and does not thrash", and that is true
		for a `VehicleSeat` which hands over ONCE. A seated character keeps asking, so it never settles.

		A `ProximityPrompt` on the helm avoids the whole problem: the driver stays their own assembly, standing
		on a moving platform - which already works, and which is how every other crew station in this game will
		have to work anyway, because you do not "sit" at a radar screen. The hull stays server-owned with
		nothing to fight over.
	]]
	local helmSocket = (hull:FindFirstChild("Sockets") :: Folder):FindFirstChild("helm") :: Attachment
	local console = Instance.new("Part")
	console.Name = "HelmConsole"
	console.Size = Vector3.new(3, 3, 1.5)
	console.CFrame = hull.CFrame * CFrame.new(helmSocket.Position + Vector3.new(0, 1.5, 0))
	console.Anchored = false
	console.CanCollide = false -- crew walk through it rather than tripping over it in a storm
	console.Massless = true -- must not shift the centre of mass and make the hull list
	console.Material = Enum.Material.Metal
	console.Color = Color3.fromRGB(46, 70, 88)
	console.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = console
	weld.Parent = console

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeHelm"
	prompt.ActionText = "Take the helm"
	prompt.ObjectText = spec.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false -- a wheelhouse wall should not stop you reaching the wheel
	prompt.Parent = console
	state.console = console
	state.prompt = prompt

	--[[
		🔴 THE COMPASS. The one instrument decision 0014 requires, and the only one nothing may ever break.

		The storm doc is unambiguous: *"the compass cannot be destroyed, and nothing targets it"* — it is the
		floor beneath pillar 6, the guarantee that being lost inside The Wall is always the crew's decision
		rather than the dice's. So it takes no fault, is not on the ladder, and no future enemy or event may
		acquire one. If threatening navigation ever looks tempting, threaten the CHART instead.

		It is also what makes The Wall a navigation problem rather than a guess. Fog closes at 330 studs
		against a black void sky, so every visual heading cue is gone; without a compass the crew cannot
		deliberately steer north and decision 0014's 30-60 second escape is unmeasurable.

		--------------------------------------------------------------------------------------------------
		WHY IT IS A BINNACLE ON THE CONSOLE AND NOT A SCREEN

		Decision 0014: *"the HUD must never show a heading, or the blindness is free."* A `SurfaceGui` on a
		part is the difference — it is a physical object bolted to the vessel, readable only by a crew member
		standing at the helm looking at it. The information is in the world, not on the player's screen.

		TOP face, deliberately. A card lying flat is how a real binnacle reads, and it dodges the question of
		which vertical face the driver happens to be standing at — which is not a settled question on this
		hull (see finding 0021: the spec's forward labels are reversed relative to `LookVector`).

		SELF-LIT via `LightInfluence = 0`: unaffected by lighting, so The Wall's brightness of 0.30 cannot
		dim it. Decision 0014 spells that out too — indestructible is useless if unreadable.

		The card is animated CLIENT-side (see `VesselClient`) and found by TAG rather than by path, because a
		hardcoded instance path between two systems is exactly what finding 0020 was.
	]]
	--[[
		Its own part, and not for decoration: the console's top face is 3 x 1.5 studs, so a round card drawn on
		it would be stretched into a stadium shape. A `SurfaceGui` maps to the face it is on, so a compass that
		is meant to read as a circle needs a SQUARE face to sit on.
	]]
	local binnacleBox = Instance.new("Part")
	binnacleBox.Name = "Binnacle"
	binnacleBox.Size = Vector3.new(1.8, 0.6, 1.8)
	binnacleBox.CFrame = console.CFrame * CFrame.new(0, console.Size.Y * 0.5 + 0.3, 0)
	binnacleBox.Anchored = false
	binnacleBox.CanCollide = false
	binnacleBox.Massless = true -- furniture must not shift the centre of mass; see the console's note
	binnacleBox.Material = Enum.Material.Metal
	binnacleBox.Color = Color3.fromRGB(46, 70, 88)
	binnacleBox.Parent = model

	local binnacleWeld = Instance.new("WeldConstraint")
	binnacleWeld.Part0 = console
	binnacleWeld.Part1 = binnacleBox
	binnacleWeld.Parent = binnacleBox

	local binnacle = Instance.new("SurfaceGui")
	binnacle.Name = "Compass"
	binnacle.Face = Enum.NormalId.Top
	--[[
		`LightInfluence = 0` is the self-lit requirement decision 0014 attaches to the compass: unaffected by
		lighting, so The Wall's brightness of 0.30 cannot dim it. Indestructible is useless if unreadable.
	]]
	binnacle.LightInfluence = 0
	binnacle.Brightness = 2
	binnacle.PixelsPerStud = 120
	binnacle.AlwaysOnTop = false
	binnacle.Parent = binnacleBox

	local bezel = Instance.new("Frame")
	bezel.Name = "Bezel"
	bezel.Size = UDim2.fromScale(1, 1)
	bezel.BackgroundColor3 = Color3.fromRGB(11, 30, 45) -- Abyss, per the palette
	bezel.BorderSizePixel = 0
	bezel.Parent = binnacle

	--[[
		The CARD rotates; the lubber line does not. That is the whole mechanic of a compass and it has to be
		this way round - a rotating needle over a fixed card tells you where north is, while a rotating card
		under a fixed line tells you where YOU are pointing, which is the question a helmsman is asking.
	]]
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.86, 0.86)
	card.BackgroundColor3 = Color3.fromRGB(20, 46, 62)
	card.BorderSizePixel = 0
	card.Parent = bezel
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(1, 0) -- a round card
	cardCorner.Parent = card

	--[[
		Cardinal marks, placed by angle rather than by four hardcoded positions, so the ordinals can be added
		later by extending the table rather than by working out corner coordinates again.

		NORTH IS THE ONE THAT MATTERS. The storm chases from astern and progress is broadly northward, so on
		this vessel the compass does not merely report a heading - it reports which way is AWAY. Hence north
		gets the radar-green treatment and the rest are dimmed: the crew needs to find one mark in the dark,
		fast, while being thrown about.
	]]
	local MARKS = {
		{ text = "N", angle = 0, color = Color3.fromRGB(82, 255, 154), size = 0.30 },
		{ text = "E", angle = 90, color = Color3.fromRGB(150, 175, 190), size = 0.20 },
		{ text = "S", angle = 180, color = Color3.fromRGB(150, 175, 190), size = 0.20 },
		{ text = "W", angle = 270, color = Color3.fromRGB(150, 175, 190), size = 0.20 },
	}
	for _, mark in ipairs(MARKS) do
		local label = Instance.new("TextLabel")
		label.Name = mark.text
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		-- 0.36 of the card's radius out from centre, at the mark's own bearing
		local rad = math.rad(mark.angle)
		label.Position = UDim2.fromScale(0.5 + math.sin(rad) * 0.36, 0.5 - math.cos(rad) * 0.36)
		label.Size = UDim2.fromScale(mark.size, mark.size)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = mark.text
		label.TextColor3 = mark.color
		label.TextScaled = true
		label.Rotation = mark.angle -- so each mark reads upright from the centre outwards
		label.Parent = card
	end

	--[[
		THE LUBBER LINE - fixed to the bezel, not the card. It is the vessel's own head, and the reading is
		whatever the card has brought under it.
	]]
	local lubber = Instance.new("Frame")
	lubber.Name = "LubberLine"
	lubber.AnchorPoint = Vector2.new(0.5, 0)
	lubber.Position = UDim2.fromScale(0.5, 0.02)
	lubber.Size = UDim2.fromScale(0.03, 0.20)
	lubber.BackgroundColor3 = Color3.fromRGB(226, 122, 63) -- Rust, per the palette: reads against the green
	lubber.BorderSizePixel = 0
	lubber.Parent = bezel

	--[[
		Tagged so the client can find it without knowing where the vessel lives in Workspace, and so it keeps
		working after `recoverIfLost` rebuilds the hull - the tag arrives with the new instance and the
		client's `GetInstanceAddedSignal` picks it up.
	]]
	CollectionService:AddTag(card, "VesselCompassCard")

	--[[
		Toggle: the same prompt takes and releases the helm, so there is never a state where the player is
		steering and cannot work out how to stop.
	]]
	prompt.Triggered:Connect(function(player)
		if state.driver == player then
			state.driver = nil
			state.throttle, state.steer = 0, 0 -- releasing must not leave the throttle open
			prompt.ActionText = "Take the helm"
			workspace:SetAttribute("VesselDriver", "")
			print(("[VESSEL] %s released the helm"):format(player.Name))
			return
		end
		if state.driver then
			return -- someone else has it; one helm, one driver
		end
		state.driver = player
		prompt.ActionText = "Release the helm"
		workspace:SetAttribute("VesselDriver", player.Name)
		print(("[VESSEL] %s took the helm"):format(player.Name))
		--[[
			🔴 THIS IS WHERE THE STORM'S CLOCK STARTS (decision 0024, job 023).

			The run opens with the front stationary and five minutes to get aboard. Taking the helm ends the
			grace - and it is ONE-WAY: releasing the helm below does not clear it, and nothing else may.
			Clearing it would turn the grace into a switch that stops the game's only pressure, so a crew
			could park, stand up, and loot in perfect safety forever.

			Raised here rather than in `ExpeditionServer` because this is the moment itself, and the flag has
			exactly one writer.
		]]
		if workspace:GetAttribute(Expedition.ATTR.runStarted) ~= true then
			workspace:SetAttribute(Expedition.ATTR.runStarted, true)
			print("[VESSEL] the run has begun - the storm is moving")
		end
	end)

	--[[
		Walking away, dying or leaving must all release it, or the vessel is stuck under the command of
		somebody who is not there. Distance is checked in the main step.
	]]
	Players.PlayerRemoving:Connect(function(player)
		if state.driver == player then
			state.driver = nil
			state.throttle, state.steer = 0, 0
			workspace:SetAttribute("VesselDriver", "")
		end
	end)


	--[[
		THE DAMAGE-CONTROL STATION. Built from the `station` socket, not from a magic offset.

		Same pattern as the helm: a `ProximityPrompt` on a massless, non-colliding part welded to the hull.
		Massless matters - a 3-stud box with real density bolted 11 studs aft and 4 to starboard would list
		her, and a permanent list on a hull whose heel is tuned to fractions of a degree would read as a
		physics bug rather than as furniture.

		`HoldDuration` 3: long enough that it cannot be spammed through a storm, short enough to be worth
		leaving the helm for. It is the whole crew-coordination mechanic in one number.
	]]
	local stationSocket = (hull:FindFirstChild("Sockets") :: Folder):FindFirstChild("damageControl") :: Attachment
	local station = Instance.new("Part")
	station.Name = "DamageControl"
	station.Size = Vector3.new(2.5, 2.5, 2.5)
	station.CFrame = hull.CFrame * CFrame.new(stationSocket.Position + Vector3.new(0, 1.25, 0))
	station.Anchored = false
	station.CanCollide = false
	station.Massless = true
	station.Material = Enum.Material.CorrodedMetal
	station.Color = Color3.fromRGB(120, 78, 46)
	station.Parent = model

	local stationWeld = Instance.new("WeldConstraint")
	stationWeld.Part0 = hull
	stationWeld.Part1 = station
	stationWeld.Parent = station

	local repairPrompt = Instance.new("ProximityPrompt")
	repairPrompt.Name = "DamageControl"
	repairPrompt.ActionText = "Damage control"
	repairPrompt.ObjectText = "Repair locker"
	repairPrompt.HoldDuration = 3
	repairPrompt.MaxActivationDistance = 10
	repairPrompt.RequiresLineOfSight = false
	repairPrompt.Parent = station
	state.station = station

	repairPrompt.Triggered:Connect(function(player)
		--[[
			Re-entrancy guard. The prompt can fire again while the previous call is still in `repairOne`, and
			without this a held prompt on a laggy client could clear two faults for one action.
		]]
		if state.repairing then
			return
		end
		state.repairing = true
		local ok, what = repairOne(player)
		state.repairing = false
		if ok then
			print(("[VESSEL] damage control: %s"):format(what))
		end
	end)

	print(("[VESSEL] %s built. mass %.0f, %d float points, K %.0f, D %.0f, drag %.1f, equilibrium %.4f")
		:format(spec.name, mass, points, state.stiffness, state.damping, state.drag,
			VesselPhysics.equilibriumRatio(mass, spec.draft, points, gravity)))
	publish()
end

--[[
	Re-take ownership if anything gave it away.

	Cheap, and it settles instantly rather than thrashing, because it only writes when the owner is actually
	wrong. Without a `VehicleSeat` nothing should ever take it - this is a belt to the braces, and it logs the
	first time so a future regression announces itself instead of manifesting as a mysterious bounce.
]]
local warnedOwnership = false
local function enforceOwnership(hull: BasePart)
	if hull:GetNetworkOwner() ~= nil then
		hull:SetNetworkOwner(nil)
		if not warnedOwnership then
			warnedOwnership = true
			warn("[VESSEL] hull ownership was taken by a client and has been reclaimed - see decision 0022")
		end
	end
end

--[[
	🔴 NOTICE WHEN THE HULL IS GONE, AND BRING IT BACK.

	An exploding assembly is REMOVED by the engine - `Parent` becomes nil with no `Destroying` event fired, so
	nothing is notified and the boat simply is not there any more. That happened once (see the force clamp in
	`VesselPhysics`), and the failure mode was silently having no vessel and no explanation.

	The clamp should prevent it recurring. This exists because "should" is not "does": a session that loses
	its boat with a clear warning is recoverable, and one that loses it in silence wastes an afternoon.

	Deliberately rate-limited. If something is destroying the hull continuously, respawning it sixty times a
	second would make the place unusable and bury the warning.
]]
local lastRebuildAt = 0
local REBUILD_COOLDOWN = 5

local function hullIsLost(): boolean
	local hull = state.hull
	if not hull or not hull.Parent then
		return true
	end
	-- a non-finite position means the solver has already lost it, even if the instance still exists
	local p = hull.Position
	return p.Y ~= p.Y or p.X ~= p.X
end

local function recoverIfLost(): boolean
	if not hullIsLost() then
		return false
	end
	if os.clock() - lastRebuildAt < REBUILD_COOLDOWN then
		return true -- lost, but too soon to try again
	end
	lastRebuildAt = os.clock()
	warn("[VESSEL] hull was LOST (removed by the engine or non-finite) - rebuilding. "
		.. "If this repeats, a force is diverging: see VesselPhysics.MAX_FORCE_WEIGHTS")
	if state.model then
		state.model:Destroy()
	end
	state.floats = {}
	buildVessel()
	for _, player in ipairs(Players:GetPlayers()) do
		if state.hull then
			player.ReplicationFocus = state.hull
		end
	end
	return true
end

local function step(dt: number)
	--[[
		SHE IS GONE. Nothing to simulate - `loseVessel` already zeroed every force.

		🔴 This check must come BEFORE `recoverIfLost`, which exists to rebuild a hull the ENGINE removed
		after a physics divergence. It cannot tell that apart from a hull we sank on purpose, so without this
		ordering a lost vessel would be quietly replaced with a fresh one and the consequence decision 0014
		exists to create would be free.
	]]
	if state.lost then
		local hull = state.hull
		if hull and hull.Parent and hull.Position.Y < SeaStates.WATER_Y - 200 then
			-- stop a wreck falling forever; there is nothing down there to see
			if state.model then
				state.model:Destroy()
			end
			state.model, state.hull = nil, nil
			state.floats = {}
			print("[VESSEL] the wreck has gone below; hull removed")
		end
		return
	end
	if recoverIfLost() then
		return
	end
	local hull = state.hull
	if not hull then
		return
	end
	enforceOwnership(hull)

	local now = workspace:GetServerTimeNow()

	--[[
		DAMAGE (job 022, decision 0014). Runs before the forces, so a hull that dies this frame stops being
		driven this frame rather than one frame later.
	]]
	local exposure = StormFront.exposure()
	if exposure > 0 then
		state.integrity = math.max(0,
			state.integrity - VesselDamage.damageRate(state.integrityMax, state.spec.survivability, exposure) * dt)
		updateFaultLadder()
	end

	-- Flooding rises while a breach is open and pumps out slowly once it is closed. Never symmetric.
	if state.faults.breach then
		state.flooding = math.min(1, state.flooding + VesselDamage.FLOODING_RATE * dt)
	elseif state.flooding > 0 then
		state.flooding = math.max(0, state.flooding - VesselDamage.FLOODING_DRAIN_RATE * dt)
	end

	-- The engine relights by itself; see `applyFault`.
	if state.faults.engine and os.clock() >= state.engineCutUntil then
		state.faults.engine = false
		print("[VESSEL] engine relit")
	end

	--[[
		CAPSIZE - the second failure state, and the one job 021 explicitly left here.

		Held for `CAPSIZE_SECONDS` rather than triggered instantly, because a Storm-state wave can throw her
		past 100 degrees and she does come back from that. Four seconds still there means hydrostatics has
		lost its lever for good.
	]]
	local tilt = VesselDamage.tiltDegrees(hull.CFrame.UpVector.Y)
	if tilt > VesselDamage.CAPSIZE_DEGREES then
		state.capsizedFor += dt
		if state.capsizedFor >= VesselDamage.CAPSIZE_SECONDS then
			loseVessel(("capsized - %.0f degrees held for %.1fs"):format(tilt, state.capsizedFor))
			return
		end
	else
		state.capsizedFor = 0
	end

	if state.integrity <= 0 then
		loseVessel("hull integrity reached zero")
		return
	end

	-- BUOYANCY: one force per point, each from its own submersion and its own vertical velocity.
	local weight = hull:GetMass() * workspace.Gravity
	local points = #state.floats
	for _, entry in ipairs(state.floats) do
		local worldPos = entry.attachment.WorldPosition
		local surface = WaveField.HeightAt(worldPos.X, worldPos.Z, now)
		local pointVelocity = hull:GetVelocityAtPosition(worldPos)
		--[[
			CLAMPED, and this guard is load-bearing rather than defensive.

			The vessel destroyed itself once: a zero-blend sea change moved the wave amplitude 30-fold in one
			frame, the stiff spring spiked, the integration diverged and the engine removed the assembly. The
			ceiling is 3x weight per point - far more than needed to right a swamped hull, and small enough
			that no single frame can impart a velocity the next cannot absorb.
		]]
		local f = VesselPhysics.clampedFloatForce({
			submersion = surface - worldPos.Y,
			verticalVelocity = pointVelocity.Y,
		}, state.stiffness, state.damping, state.maxDepth, weight, points)
		--[[
			FLOODING = LOST LIFT, applied AFTER the clamp on purpose.

			The clamp is the divergence guard that stopped the hull destroying itself in job 021, and scaling
			the result DOWN can never breach a ceiling. Doing it the other way round - reducing the stiffness
			that feeds the clamp - would change a derived constant and put the equilibrium the whole kit is
			solved for out by 35%.
		]]
		f *= VesselDamage.floodingLiftFactor(state.flooding)
		entry.force.Force = Vector3.new(0, f, 0)
	end

	--[[
		TEST-DRIVE HOOK.

		Exists so this can be driven and measured WITHOUT a human at the helm - and it is a Workspace attribute
		rather than a `_G` entry because `_G` is not shared between the running server scripts and an
		`execute_luau` probe (they are separate Luau VMs). Attributes live on the Instance, so both see them.

		The driver's own input is ignored while it is set, so the two cannot fight. Harmless in production: it
		does nothing unless somebody with Studio access sets the attribute.
	]]
	if workspace:GetAttribute("VesselTestDrive") == true then
		local t = workspace:GetAttribute("VesselTestThrottle")
		local st = workspace:GetAttribute("VesselTestSteer")
		state.throttle = if typeof(t) == "number" then math.clamp(t, -1, 1) else 0
		state.steer = if typeof(st) == "number" then math.clamp(st, -1, 1) else 0
	end

	-- DRIVE
	local forward = hull.CFrame.LookVector
	local forwardSpeed = hull.AssemblyLinearVelocity:Dot(forward)
	local hasFuel = state.fuel > 0 and state.engineOn
	--[[
		An engine cut removes THRUST, not fuel and not steering. She keeps her way on and still answers the
		wheel, which is what makes the eight seconds survivable and frightening rather than simply fatal.
	]]
	local throttle = if hasFuel and not state.faults.engine then state.throttle else 0
	local net = VesselPhysics.driveForce(throttle, forwardSpeed, state.spec.thrust, state.drag, state.linearDrag)
	if state.drive then
		--[[
			Aimed along the actual heading, and CAPPED.

			The cap is a safety net rather than a tuning device: drag already settles the hull at `cruise`, so
			this only ever engages if something has gone wrong. It engages BEFORE the speed becomes lethal,
			which is the lesson from the runaway above - a vehicle should not be able to kill its driver
			through a sign error.
		]]
		local overspeed = forwardSpeed > state.spec.cruise * 1.6
		state.drive.Force = forward * (if overspeed then math.min(net, 0) else net)
	end

	--[[
		LATERAL GRIP. Kills the sideways component of velocity so a heading change becomes a course change.

		`RightVector` is the hull's own starboard direction, so this works at any heading without a sign
		convention to get wrong - the lesson from the thrust runaway.
	]]
	if state.grip then
		local right = hull.CFrame.RightVector
		local lateralSpeed = hull.AssemblyLinearVelocity:Dot(right)
		local f = VesselPhysics.lateralForce(lateralSpeed, hull:GetMass(), state.spec.lateralGrip)
		state.grip.Force = right * f
	end

	--[[
		TRIM. Positive X torque pitches the bow UP (hull +Z is forward, +X is starboard, so a positive moment
		about X lifts the nose).

		Scaled by throttle so she settles bow-up under power and levels off when the throttle closes - and only
		forward throttle, because backing down should squat the stern, not lift it.
	]]
	if state.trim then
		--[[
			TWO terms (see the spec):
			  planing  - sustained bow-up while the engine pushes. Throttle-driven, holds at cruise.
			  inertial - the reaction to CHANGING speed. Net-force-driven, so it lifts the bow under
			             acceleration and DIGS IT IN under deceleration, which is the half that was missing.
		]]
		local planing = state.planingTrim * math.max(throttle, 0)
		local inertial = state.inertialTrim * net
		local moment = planing + inertial
		--[[
			Aimed along the hull's STARBOARD direction flattened to horizontal, so it is a pure pitch about a
			horizontal axis and cannot leak into yaw at any angle of heel (finding 0019). Bow-up is a positive
			moment about starboard.
		]]
		local right = hull.CFrame.RightVector
		local flatRight = Vector3.new(right.X, 0, right.Z)
		if flatRight.Magnitude > 0.01 then
			state.trim.Torque = flatRight.Unit * moment
		else
			state.trim.Torque = Vector3.zero
		end
	end

	--[[
		Release the helm if the driver has wandered off, died, or lost their character. Otherwise the vessel
		stays under the command of somebody who is not there, with the throttle where they left it.
	]]
	if state.driver then
		local character = state.driver.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local gone = not root
			or (humanoid and humanoid.Health <= 0)
			or (state.console and (root :: BasePart).Position:FuzzyEq((root :: BasePart).Position) and
				((root :: BasePart).Position - state.console.Position).Magnitude > 40)
		if gone then
			print(("[VESSEL] helm released - %s is no longer at it"):format(state.driver.Name))
			state.driver = nil
			state.throttle, state.steer = 0, 0
			if state.prompt then
				state.prompt.ActionText = "Take the helm"
			end
			workspace:SetAttribute("VesselDriver", "")
		end
	end

	--[[
		STEER. Rudder torque plus yaw damping - a balance, not a commanded rate.

		The damping is what limits the turn and what gives the rudder its lag. Both scale with v^2, which is
		why the turn radius grows with speed instead of shrinking.
	]]
	local steer = if hasFuel then state.steer else 0
	local yawRate = hull.AssemblyAngularVelocity.Y
	--[[
		Steering damage scales the authority HERE, at the point of use. See the note above `applyFault`:
		mutating `state.rudderAuthority` would make the damage permanent and would silently de-tune the heel,
		which was solved against the undamaged value when the vessel was built.
	]]
	local authority = state.rudderAuthority
		* (if state.faults.steering then VesselDamage.STEERING_AUTHORITY else 1)
	local rudderT = VesselPhysics.rudderTorque(steer, forwardSpeed, state.spec.cruise, authority)
	local dampT = VesselPhysics.yawDamping(yawRate, forwardSpeed, state.spec.cruise, state.yawDamping)
	if state.rudder then
		--[[
			🔴 HARD YAW CAP. Insurance, exactly like the thrust cap and the buoyancy force ceiling.

			A coupling bug in the heel torque spun this hull to 1.77 rad/s - roughly 100 degrees a second,
			six times its designed rate - and collapsed its speed. The loop is fixed, but a vehicle that CAN
			run away is one bug from doing it again, and the driver pays.

			Above 1.5x the designed rate the rudder stops helping and heavy extra damping is applied instead.
		]]
		local cap = state.spec.turnRate * 1.5
		local total = rudderT + dampT
		if math.abs(yawRate) > cap then
			total = -math.sign(yawRate) * state.yawDamping * (math.abs(yawRate) - cap) * 4
		end
		state.rudder.Torque = Vector3.new(0, total, 0)
	end

	--[[
		HEEL. Inward as the wheel goes over, outward once the turn settles. See VesselPhysics.heelMoment.

		Applied about the hull's own forward axis (local -Z is forward, so a roll is about Z), hence
		Attachment0-relative.
	]]
	if state.heel then
		local moment = VesselPhysics.heelMoment(
			rudderT, yawRate, forwardSpeed, state.heelIn, state.heelOut)
		--[[
			Aimed along the hull's forward direction FLATTENED to horizontal. A pure roll axis with no
			world-Y component, so it cannot leak into yaw at any angle of heel - see the note on the
			constraint. Forward is -Z, so rolling to starboard is a positive moment about the flattened
			forward axis.
		]]
		--[[
			🔴 SIGN. This was negated, and it had the heel exactly backwards.

			Convention, written out because getting it wrong twice is easy:
			  forward is `LookVector`, which is the hull's -Z
			  a POSITIVE torque about the forward axis, by the right-hand rule, sends starboard (+X) DOWN
			  starboard down = leaning to starboard = INTO a starboard turn

			For a turn to starboard the rudder term makes `moment` positive, so applying `flat.Unit * moment`
			puts starboard down - into the turn - which is the transient the research describes. Once the turn
			settles the centrifugal term (larger) drives `moment` negative and she leans out. Both phases, in
			the right order.

			With the negation it did the opposite: leaned OUT as the wheel went over and INTO the turn once
			settled. The user spotted it from the deck before my own test did - because my test labelled
			positive `asin(RightVector.Y)` as "in", when starboard-up is in fact leaning to PORT.
		]]
		local flat = Vector3.new(forward.X, 0, forward.Z)
		if flat.Magnitude > 0.01 then
			state.heel.Torque = flat.Unit * moment
		else
			state.heel.Torque = Vector3.zero
		end
	end

	-- FUEL
	local used = VesselPhysics.fuelUsed(throttle, dt, state.spec.fuelBurn, state.engineOn)
	if used > 0 then
		state.fuel = math.max(0, state.fuel - used)
		if state.fuel <= 0 then
			state.engineOn = false
			print("[VESSEL] out of fuel")
		end
	end
end

--[[
	Input. Validated, because a client sends it.

	Only two numbers cross the network, both clamped. There is nothing here worth exploiting - the server
	decides what force those numbers become, and the fuel they cost.
]]
input.OnServerEvent:Connect(function(player, throttle, steer)
	--[[
		🔴 ONLY THE DRIVER STEERS.

		The remote arrives from a client, so without this check any player could steer the vessel from
		anywhere on the map - or from the lobby. Comparing against the SEAT's occupant rather than a flag
		means the authority cannot drift out of sync with who is actually sitting at the helm.
	]]
	if state.driver ~= player then
		return
	end
	-- NaN would propagate straight into a force; `x == x` is false only for NaN
	if typeof(throttle) == "number" and throttle == throttle then
		state.throttle = math.clamp(throttle, -1, 1)
	end
	if typeof(steer) == "number" and steer == steer then
		state.steer = math.clamp(steer, -1, 1)
	end
end)

--[[
	ReplicationFocus on the VESSEL, not the character.

	`StreamingEnabled` is true in this place (job 004), so without this a crew member standing on a deck 3 km
	from the origin watches the deck stream out from under them. Already a GAME-0001 requirement.
]]
local function focusOn(player: Player)
	if state.hull then
		player.ReplicationFocus = state.hull
	end
end

Players.PlayerAdded:Connect(function(player)
	focusOn(player)
end)

--[[
	CONSUME THE LIGHTNING FAULT.

	`LightningServer` has rolled `radar` / `generator` / `lights` faults on close strikes since job 018 and
	published them to `LightningFault`, and nothing has ever read them - the admin panel even says so out
	loud: *"fault raised: radar (nothing consumes it yet)"*. Now that the vessel owns a fault set, it can.

	Listening to `LightningFaultAt` rather than `LightningFault`: the timestamp changes on every strike, while
	the fault NAME often repeats, and `GetAttributeChangedSignal` does not fire when a value is rewritten
	unchanged. Watching the name would silently drop every second radar strike in a row.

	`lights` maps to the generator, because the deck lighting is on the generator's circuit and there is no
	lighting system yet to fault independently (build group 02). One fault id per thing that actually exists.

	⚠️ Not `steering` - see todo 0005. Lightning's fault pool is job 018's tuning and adding a rung that
	hampers escape belongs to whoever judges that balance, not to a wiring change.
]]
local LIGHTNING_FAULT_MAP: { [string]: string } = {
	radar = "radar",
	generator = "generator",
	lights = "generator",
}

workspace:GetAttributeChangedSignal("LightningFaultAt"):Connect(function()
	if state.lost then
		return
	end
	local raised = workspace:GetAttribute("LightningFault")
	local mapped = typeof(raised) == "string" and LIGHTNING_FAULT_MAP[raised] or nil
	if not mapped or state.faults[mapped] then
		return
	end
	state.fired[mapped] = true
	applyFault(mapped)
	print(("[VESSEL] lightning raised %s -> %s"):format(tostring(raised), mapped))
	publish()
end)

buildVessel()
for _, player in ipairs(Players:GetPlayers()) do
	focusOn(player)
end

local publishAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(step, dt)
	if not ok then
		warn("[VESSEL] step failed: " .. tostring(err))
	end
	-- publish at ~10 Hz; the gauges do not need 60
	publishAccumulator += dt
	if publishAccumulator >= 0.1 then
		publishAccumulator = 0
		pcall(publish)
	end
end)

--[[
	Exposed for tests and for the admin panel. Reading these grants nothing - they are numbers about a boat
	that is already visible.
]]
_G.TideVessel = {
	state = state,
	rebuild = function()
		if state.model then
			state.model:Destroy()
		end
		state.floats = {}
		buildVessel()
	end,
	setFuel = function(v: number)
		state.fuel = math.clamp(v, 0, state.spec and state.spec.fuelCapacity or 100)
		state.engineOn = state.fuel > 0
	end,
	--[[
		DAMAGE CONTROLS for the admin panel (job 022). Server-side, like everything else on this table.

		`setIntegrity` deliberately does NOT fire the fault ladder. Dropping the hull to 20% to look at a
		gauge should not also cut the engine and open a breach - the panel has a separate tool for inflicting
		a named fault, and conflating the two makes both untestable in isolation. The ladder still fires
		normally from storm exposure on the next frame if the integrity is genuinely low, which is correct:
		the panel sets state, the storm causes events.
	]]
	setIntegrity = function(fraction: number)
		state.integrity = math.clamp(fraction, 0, 1) * state.integrityMax
		--[[
			Mark every rung at or above the new level as already fired, so lowering integrity by hand does not
			cause the ladder to go off all at once on the next frame. Raising it back up re-arms them.
		]]
		local lost = 1 - math.clamp(fraction, 0, 1)
		for _, fault in ipairs(VesselDamage.LADDER) do
			state.fired[fault.id] = lost >= fault.at
		end
		publish()
	end,
	inflict = function(id: string)
		state.fired[id] = true
		applyFault(id)
		publish()
	end,
	repairAll = function()
		state.faults = {}
		state.flooding = 0
		state.engineCutUntil = 0
		state.integrity = state.integrityMax
		--[[
			Re-arm the ladder. Without this a repaired hull would never fault again for the rest of the run,
			which turns one repair into permanent immunity.
		]]
		state.fired = {}
		state.capsizedFor = 0
		publish()
	end,
	damageReport = function(): string
		local spec = state.spec
		if not spec then
			return "no vessel"
		end
		local exposure = StormFront.exposure()
		local rate = VesselDamage.damageRate(state.integrityMax, spec.survivability, exposure)
		local toLoss = VesselDamage.secondsToLoss(state.integrity, rate)
		local speed = workspace:GetAttribute("VesselSpeed")
		local escape = StormFront.secondsToEscape(StormFront.distance(), typeof(speed) == "number" and speed or 0)
		local active = {}
		for _, fault in ipairs(VesselDamage.LADDER) do
			if state.faults[fault.id] then
				table.insert(active, fault.label .. (fault.real and "" or " (stub)"))
			end
		end
		if state.faults.steering then
			table.insert(active, "Steering damaged")
		end
		local lines = {
			("integrity   %.0f / %.0f  (%.0f%%)%s"):format(
				state.integrity, state.integrityMax,
				state.integrity / math.max(state.integrityMax, 1) * 100,
				state.lost and "   🔴 VESSEL LOST" or ""),
			("survivability %ds declared -> %.1f/s at full exposure"):format(
				spec.survivability, VesselDamage.damageRate(state.integrityMax, spec.survivability, 1)),
			("storm       distance %.0f, exposure %.2f -> %.1f integrity/s"):format(
				StormFront.distance(), exposure, rate),
			("time left   %s"):format(toLoss and ("%.1f s at this rate"):format(toLoss) or "not taking damage"),
			("escape      %s  (min escape speed %.1f studs/s)"):format(
				escape and ("%.1f s at the current %.1f studs/s"):format(escape,
					typeof(speed) == "number" and speed or 0)
					or "NOT GAINING GROUND at the current speed",
				StormFront.minEscapeSpeed()),
			("flooding    %.0f%%  -> lift x%.3f"):format(
				state.flooding * 100, VesselDamage.floodingLiftFactor(state.flooding)),
			("tilt        %.1f deg  (capsize past %d for %ds; held %.1fs)"):format(
				state.hull and VesselDamage.tiltDegrees(state.hull.CFrame.UpVector.Y) or 0,
				VesselDamage.CAPSIZE_DEGREES, VesselDamage.CAPSIZE_SECONDS, state.capsizedFor),
			("faults      %s"):format(#active > 0 and table.concat(active, ", ") or "none"),
		}
		return table.concat(lines, "\n")
	end,
	report = function(): string
		local hull = state.hull
		if not hull then
			return "no hull"
		end
		local spec = state.spec
		local mass = Vessel.massOf(spec)
		local vel = hull.AssemblyLinearVelocity
		local forward = hull.CFrame.LookVector
		local lines = {
			("%s  mass %.0f  %d float points"):format(spec.name, mass, #spec.buoyancyPoints),
			("K %.0f   D %.0f   drag %.2f   equilibrium %.4f (want 1.0000)"):format(
				state.stiffness, state.damping, state.drag,
				VesselPhysics.equilibriumRatio(mass, spec.draft, #spec.buoyancyPoints, workspace.Gravity)),
			("hull Y %.2f   resting Y %.2f   draft %.2f"):format(
				hull.Position.Y, Vessel.restingY(spec, SeaStates.WATER_Y), spec.draft),
			("speed %.2f fwd (%.2f total)   heading %.0f deg"):format(
				vel:Dot(forward), vel.Magnitude,
				math.deg(math.atan2(forward.X, forward.Z)) % 360),
			("throttle %.2f  steer %.2f  fuel %.1f/%.0f  engine %s"):format(
				state.throttle, state.steer, state.fuel, spec.fuelCapacity, tostring(state.engineOn)),
			("owner %s (must be nil)"):format(tostring(hull:GetNetworkOwner())),
			("driver %s"):format(state.driver and state.driver.Name or "nobody at the helm"),
			("integrity %.0f/%.0f  flooding %.0f%%  exposure %.2f%s"):format(
				state.integrity, state.integrityMax, state.flooding * 100, StormFront.exposure(),
				state.lost and "   🔴 LOST" or ""),
			("tilt %.1f deg from level"):format(math.deg(math.acos(math.clamp(hull.CFrame.UpVector.Y, -1, 1)))),
		}
		return table.concat(lines, "\n")
	end,
}

print("[VESSEL] server ready")
