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
	righting = nil :: AlignOrientation?,
	yaw = nil :: AngularVelocity?,
	stiffness = 0,
	damping = 0,
	drag = 0,
	maxDepth = 0,
	seat = nil :: Seat?,
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
	--[[
		Cap the lift a single fully-submerged point can make at roughly twice the draft's worth. The spring is
		linear, so a hull thrown 7 studs deep by a storm wave would otherwise be launched back out like a
		beach ball.
	]]
	state.maxDepth = spec.draft * 2.5
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
	drive.Name = "Drive"
	drive.Attachment0 = driveAt
	drive.RelativeTo = Enum.ActuatorRelativeTo.Attachment0 -- follows the heading; +Z is forward
	drive.ApplyAtCenterOfMass = true
	drive.Force = Vector3.zero
	drive.Parent = hull
	state.drive = drive

	--[[
		The righting moment. `PrimaryAxisOnly` keeps the deck level-ish while leaving YAW completely free, so
		steering is not fighting it.

		`Responsiveness` low on purpose: a boat should right itself over a second or two, not snap. This is
		the dial decision 0022 calls the most important feel number - too low capsizes, too high makes the
		storm a light show.
	]]
	local righting = Instance.new("AlignOrientation")
	righting.Name = "Righting"
	righting.Attachment0 = driveAt
	righting.Mode = Enum.OrientationAlignmentMode.OneAttachment
	righting.PrimaryAxisOnly = true
	righting.PrimaryAxis = Vector3.yAxis -- hull's up, toward world up
	righting.MaxTorque = spec.rightingTorque
	righting.Responsiveness = 12
	righting.RigidityEnabled = false -- a hard lock ignores force limits; never for a vehicle
	righting.Parent = hull
	state.righting = righting

	--[[
		Yaw. `RelativeTo = World` about Y, so momentum carries the hull through a turn and it drifts rather
		than pivoting - which is what makes it read as a boat. `Attachment0` is explicitly unsupported here.
	]]
	local yaw = Instance.new("AngularVelocity")
	yaw.Name = "Yaw"
	yaw.Attachment0 = driveAt
	yaw.RelativeTo = Enum.ActuatorRelativeTo.World
	yaw.MaxTorque = spec.rightingTorque * 0.35
	yaw.AngularVelocity = Vector3.zero
	yaw.ReactionTorqueEnabled = false
	yaw.Parent = hull
	state.yaw = yaw

	--[[
		THE HELM SEAT.

		🔴 A plain `Seat`, NOT a `VehicleSeat` (decision 0022).

		`VehicleSeat` would hand throttle and steering to us for free, and on mobile it would supply the touch
		controls too. It also hands NETWORK OWNERSHIP to the driver on sit - which is exactly the condition
		that makes a server-side buoyancy loop pump energy instead of removing it, and is why the Jungle boat
		bounced higher and higher while driven. So we take the plain seat and build the input ourselves.

		WELDED, never anchored. Anchoring any part of an assembly splits it and disables its welds. `Massless`
		so a seat bolted high on the deck cannot shift the centre of mass and make the hull list.
	]]
	local helmSocket = (hull:FindFirstChild("Sockets") :: Folder):FindFirstChild("helm") :: Attachment
	local seat = Instance.new("Seat")
	seat.Name = "Helm"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = hull.CFrame * CFrame.new(helmSocket.Position + Vector3.new(0, 0.5, 0))
	seat.Anchored = false
	seat.CanCollide = false -- crew walk through it rather than tripping over it
	seat.Massless = true
	seat.Material = Enum.Material.Metal
	seat.Color = Color3.fromRGB(46, 70, 88)
	seat.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = seat
	weld.Parent = seat
	state.seat = seat

	--[[
		Track the occupant, and accept input from nobody else.

		Cheap server-side authority: the remote arrives from a client, so without this any player could steer
		the vessel from anywhere on the map. Checking the seat rather than a flag means it cannot get out of
		sync with who is actually sitting there.
	]]
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		state.driver = player
		if not player then
			-- releasing the helm must not leave the throttle open
			state.throttle, state.steer = 0, 0
			print("[VESSEL] helm released")
		else
			print(("[VESSEL] %s took the helm"):format(player.Name))
		end
		workspace:SetAttribute("VesselDriver", player and player.Name or "")
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

	-- DRIVE
	local forward = hull.CFrame.LookVector
	local forwardSpeed = hull.AssemblyLinearVelocity:Dot(forward)
	local hasFuel = state.fuel > 0 and state.engineOn
	local throttle = if hasFuel then state.throttle else 0
	local net = VesselPhysics.driveForce(throttle, forwardSpeed, state.spec.thrust, state.drag)
	if state.drive then
		-- Attachment0-relative, so +Z is the hull's own forward
		state.drive.Force = Vector3.new(0, 0, net)
	end

	-- STEER
	if state.yaw then
		local rate = VesselPhysics.yawRate(
			if hasFuel then state.steer else 0,
			forwardSpeed,
			state.spec.cruise,
			state.spec.turnRate
		)
		state.yaw.AngularVelocity = Vector3.new(0, rate, 0)
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
