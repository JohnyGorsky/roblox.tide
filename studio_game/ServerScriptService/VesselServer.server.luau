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

local Vessel = require(ReplicatedStorage:WaitForChild("Vessel"))
local VesselPhysics = require(ReplicatedStorage:WaitForChild("VesselPhysics"))
local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

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
	maxDepth = 0,
	console = nil :: BasePart?,
	prompt = nil :: ProximityPrompt?,
	driver = nil :: Player?,
	throttle = 0,
	steer = 0,
	engineOn = true,
	fuel = 0,
}

local remote = ReplicatedStorage:FindFirstChild("VesselInput")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "VesselInput"
	remote.Parent = ReplicatedStorage
end
local input = remote :: RemoteEvent

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
	if hull then
		local forward = hull.CFrame.LookVector
		local vel = hull.AssemblyLinearVelocity
		workspace:SetAttribute("VesselSpeed", vel:Dot(forward))
		-- heading in degrees, 0 = +Z north, matching the wave field and the storm's bearing convention
		workspace:SetAttribute("VesselHeading", math.deg(math.atan2(forward.X, forward.Z)) % 360)
	end
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
	local lever = math.abs(spec.buoyancyPoints[1].X)
	local rollStiffnessPerDeg = 2 * state.stiffness * (lever * math.sin(math.rad(1))) * lever
	state.heelIn = (spec.heelInDeg * rollStiffnessPerDeg) / math.max(state.rudderAuthority, 1)
	state.heelOut = (spec.heelOutDeg * rollStiffnessPerDeg) / math.max(spec.turnRate * spec.cruise, 0.01)
	state.fuel = spec.fuelCapacity

	local restingY = Vessel.restingY(spec, SeaStates.WATER_Y)
	local model = Vessel.build(spec, CFrame.new(SPAWN_OFFSET + Vector3.new(0, restingY, 0)))
	model.Parent = workspace
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
	if recoverIfLost() then
		return
	end
	local hull = state.hull
	if not hull then
		return
	end
	enforceOwnership(hull)

	local now = workspace:GetServerTimeNow()

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
	local throttle = if hasFuel then state.throttle else 0
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
		local t = math.max(throttle, 0)
		--[[
			Aimed along the hull's STARBOARD direction flattened to horizontal, so it is a pure pitch about a
			horizontal axis and cannot leak into yaw at any angle of heel. Bow-up is a positive moment about
			starboard.
		]]
		local right = hull.CFrame.RightVector
		local flatRight = Vector3.new(right.X, 0, right.Z)
		if flatRight.Magnitude > 0.01 then
			state.trim.Torque = flatRight.Unit * (state.spec.trimTorque * t)
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
	local rudderT = VesselPhysics.rudderTorque(steer, forwardSpeed, state.spec.cruise, state.rudderAuthority)
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
		local flat = Vector3.new(forward.X, 0, forward.Z)
		if flat.Magnitude > 0.01 then
			state.heel.Torque = flat.Unit * -moment
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
			("tilt %.1f deg from level"):format(math.deg(math.acos(math.clamp(hull.CFrame.UpVector.Y, -1, 1)))),
		}
		return table.concat(lines, "\n")
	end,
}

print("[VESSEL] server ready")
