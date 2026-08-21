--!strict
--[[
	TenderServer - the rescue loop: a fuel-free boat, floating barrels, and a way to pour them in.

	Feature: GAME-0001  ·  decision 0024  ·  job 023

	--------------------------------------------------------------------------------------------------
	🔴 WHY THIS IS A SEPARATE FILE AND NOT A SECOND VESSEL IN `VesselServer`

	`VesselServer` holds ONE `state` table for ONE hull, referenced 203 times across 1,501 lines, and it is
	the only code in the project whose physics has been measured end to end: survival 45.5 s against 45
	declared, escape 27.9 s, distance-gain 99.2% of theory, buoyancy converging at full flooding in a Storm
	sea. Turning that into a list of vessels is a large refactor of exactly the file where a regression is
	most expensive and least visible.

	So the tender gets its own driver, deliberately much simpler, reusing the PURE modules - `Vessel.build`
	for construction and `VesselPhysics` for buoyancy, so it inherits the force clamp that stopped the launch
	destroying itself in job 021 rather than reimplementing it.

	Accepted cost: the buoyancy loop exists twice. See the todo for unifying them - the right time is when a
	THIRD vessel needs one, because two implementations that agree are cheaper than a refactor that might not.

	--------------------------------------------------------------------------------------------------
	NO TORQUES EXCEPT YAW, AND ALL FORCES WORLD-RELATIVE

	Finding 0019: a large torque applied in a body-relative frame leaks into every axis the body rotates
	about - it spun the launch 178 degrees in eight seconds with the wheel amidships. `VesselServer` fixed
	that by aiming every force in world space with an explicit direction.

	A rowboat needs neither heel nor trim, so this driver simply does not have them. The failure class is
	ABSENT rather than guarded against, which is the better of the two.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vessel = require(ReplicatedStorage:WaitForChild("Vessel"))
local VesselPhysics = require(ReplicatedStorage:WaitForChild("VesselPhysics"))
local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local SPEC_ID = "Tender"

--- Alongside the launch, a little to port, close enough to board and clear enough not to collide.
local TENDER_OFFSET = Vector3.new(-26, 0, 0)

--[[
	Barrels drift 200-400 studs out. Decision 0024's table, from the tender's 6 studs/s against the storm's
	14: a round trip costs 22% of the cushion at 200 and 44% at 400. Expensive enough to hurt, survivable
	enough to be worth trying.
]]
local BARREL_MIN, BARREL_MAX = 200, 400
local BARREL_COUNT = 4
local BARREL_FUEL = 35 -- of the launch's 100 capacity, so two barrels is most of a tank

local state = {
	model = nil :: Model?,
	hull = nil :: BasePart?,
	spec = nil :: any,
	floats = {} :: { { attachment: Attachment, force: VectorForce } },
	drive = nil :: VectorForce?,
	grip = nil :: VectorForce?,
	rudder = nil :: Torque?,
	stiffness = 0,
	damping = 0,
	drag = 0,
	linearDrag = 0,
	yawDamping = 0,
	rudderAuthority = 0,
	maxDepth = 0,
	driver = nil :: Player?,
	throttle = 0,
	steer = 0,
	barrels = {} :: { BasePart },
	carrying = {} :: { [Player]: boolean },
}

local remote = ReplicatedStorage:FindFirstChild("TenderInput")
if not remote then
	local r = Instance.new("RemoteEvent")
	r.Name = "TenderInput"
	r.Parent = ReplicatedStorage
	remote = r
end
local input = remote :: RemoteEvent

local function launchHull(): BasePart?
	local V = (_G :: any).TideVessel
	return V and V.state and V.state.hull or nil
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

local function buildTender()
	local spec = Vessel.spec(SPEC_ID)
	if not spec then
		warn("[TENDER] unknown spec " .. SPEC_ID)
		return
	end
	local mass = Vessel.massOf(spec)
	local points = #spec.buoyancyPoints
	local gravity = workspace.Gravity

	state.spec = spec
	--[[
		Every constant DERIVED, exactly as the launch's are (decision 0009). The tender is the kit's second
		customer, and it is the first real test that the derivations hold at a twentieth of the mass: 216
		against 4,200.
	]]
	state.stiffness = VesselPhysics.stiffness(mass, spec.draft, points, gravity)
	state.damping = VesselPhysics.damping(state.stiffness, mass, points)
	state.drag = VesselPhysics.dragCoefficient(spec.thrust, spec.cruise)
	state.linearDrag = VesselPhysics.linearDrag(spec.thrust, spec.cruise)
	state.maxDepth = spec.draft * 2.5
	local inertiaY = mass / 12 * (spec.size.X ^ 2 + spec.size.Z ^ 2)
	state.yawDamping = inertiaY / math.max(spec.rudderLag, 0.1)
	state.rudderAuthority = spec.turnRate * state.yawDamping

	local base = launchHull()
	local origin = base and base.Position or Vector3.new(70, 0, 0)
	local restingY = Vessel.restingY(spec, SeaStates.WATER_Y)
	local model = Vessel.build(spec, CFrame.new(Vector3.new(origin.X, 0, origin.Z) + TENDER_OFFSET + Vector3.new(0, restingY, 0)))
	model.Name = "Tender"
	model.Parent = workspace
	local hull = model.PrimaryPart :: BasePart
	hull.Color = Color3.fromRGB(120, 84, 48) -- wooden
	hull.Material = Enum.Material.WoodPlanks
	state.model, state.hull = model, hull
	state.floats = {}

	local floatFolder = hull:FindFirstChild("BuoyancyPoints") :: Folder
	for _, attachment in ipairs(floatFolder:GetChildren()) do
		local force = Instance.new("VectorForce")
		force.Name = "Float_" .. attachment.Name
		force.Attachment0 = attachment :: Attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = false
		force.Force = Vector3.zero
		force.Parent = hull
		table.insert(state.floats, { attachment = attachment :: Attachment, force = force })
	end

	local driveAt = hull:FindFirstChild("Drive") :: Attachment
	local function vectorForce(name: string): VectorForce
		local f = Instance.new("VectorForce")
		f.Name = name
		f.Attachment0 = driveAt
		f.RelativeTo = Enum.ActuatorRelativeTo.World -- aimed explicitly each frame; no sign conventions
		f.ApplyAtCenterOfMass = true
		f.Force = Vector3.zero
		f.Parent = hull
		return f
	end
	state.drive = vectorForce("DriveForce")
	state.grip = vectorForce("LateralGrip")

	local rudder = Instance.new("Torque")
	rudder.Name = "Rudder"
	rudder.Attachment0 = driveAt
	rudder.RelativeTo = Enum.ActuatorRelativeTo.World -- about world Y only; nothing to leak into
	rudder.Torque = Vector3.zero
	rudder.Parent = hull
	state.rudder = rudder

	-- the oars: a station you stand at, same reasoning as the helm (decision 0022 - sitting destroys the boat)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeOars"
	prompt.ActionText = "Take the oars"
	prompt.ObjectText = spec.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hull
	prompt.Triggered:Connect(function(player)
		if state.driver == player then
			state.driver, state.throttle, state.steer = nil, 0, 0
			prompt.ActionText = "Take the oars"
			workspace:SetAttribute("TenderDriver", "")
			return
		end
		if state.driver then
			return
		end
		state.driver = player
		prompt.ActionText = "Ship the oars"
		workspace:SetAttribute("TenderDriver", player.Name)
	end)

	print(("[TENDER] built. mass %.0f, cruise %d (break-even is %.2f), no fuel")
		:format(mass, spec.cruise, 14 / 1.6))
end

-- ---------------------------------------------------------------------------
-- Fuel barrels
-- ---------------------------------------------------------------------------

--[[
	Barrels are ANCHORED props positioned onto the wave surface each frame, not floating physics bodies.

	Deliberate: terrain water buoys unanchored parts toward a FLAT Y=0 plane (finding 0008), which would
	fight the wave field and read as jitter. Nothing about a barrel needs to be simulated - it needs to look
	like it is bobbing and to be reachable - so it is driven, not floated.
]]
local function buildBarrels()
	local base = launchHull()
	local origin = base and base.Position or Vector3.zero
	for i = 1, BARREL_COUNT do
		-- spread around the vessel, deterministic so a session is repeatable
		local angle = (i / BARREL_COUNT) * math.pi * 2 + 0.6
		local dist = BARREL_MIN + (BARREL_MAX - BARREL_MIN) * ((i - 1) / math.max(BARREL_COUNT - 1, 1))
		local pos = Vector3.new(origin.X + math.sin(angle) * dist, 0, origin.Z + math.cos(angle) * dist)

		local barrel = Instance.new("Part")
		barrel.Name = "FuelBarrel"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(3.4, 2.2, 2.2)
		barrel.Anchored = true
		barrel.CanCollide = false
		barrel.Material = Enum.Material.CorrodedMetal
		barrel.Color = Color3.fromRGB(196, 92, 54)
		barrel.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
		barrel:SetAttribute("Fuel", BARREL_FUEL)
		barrel.Parent = workspace

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TakeBarrel"
		prompt.ActionText = "Take the barrel"
		prompt.ObjectText = ("Diesel (%d)"):format(BARREL_FUEL)
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = barrel

		prompt.Triggered:Connect(function(player)
			if state.carrying[player] then
				return -- one at a time; the round trip is the cost
			end
			state.carrying[player] = true
			barrel:Destroy()
			for idx, b in ipairs(state.barrels) do
				if b == barrel then
					table.remove(state.barrels, idx)
					break
				end
			end
			print(("[TENDER] %s has a barrel - pour it in at the launch"):format(player.Name))
		end)

		table.insert(state.barrels, barrel)
	end
	print(("[TENDER] %d barrels at %d..%d studs, %d fuel each"):format(
		BARREL_COUNT, BARREL_MIN, BARREL_MAX, BARREL_FUEL))
end

--[[
	Pouring in. A prompt on the LAUNCH, so the barrel has to come back - which is where the time actually
	goes, and what decision 0024's cost table assumes.
]]
local function attachFiller()
	local hull = launchHull()
	if not hull or hull:FindFirstChild("Filler") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Filler"
	prompt.ActionText = "Pour in the fuel"
	prompt.ObjectText = "Fuel filler"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = hull
	prompt.Triggered:Connect(function(player)
		if not state.carrying[player] then
			return
		end
		local V = (_G :: any).TideVessel
		if not V then
			return
		end
		state.carrying[player] = false
		local now = workspace:GetAttribute("VesselFuel")
		V.setFuel((typeof(now) == "number" and now or 0) + BARREL_FUEL)
		print(("[TENDER] %s poured in %d fuel"):format(player.Name, BARREL_FUEL))
	end)
end

-- ---------------------------------------------------------------------------
-- Step
-- ---------------------------------------------------------------------------

local function step(dt: number)
	local hull = state.hull
	if not hull or not hull.Parent then
		return
	end
	if hull:GetNetworkOwner() ~= nil then
		hull:SetNetworkOwner(nil) -- server-owned, same rule as the launch (decision 0022)
	end

	local now = workspace:GetServerTimeNow()
	local weight = hull:GetMass() * workspace.Gravity
	local points = #state.floats
	for _, entry in ipairs(state.floats) do
		local worldPos = entry.attachment.WorldPosition
		local surface = WaveField.HeightAt(worldPos.X, worldPos.Z, now)
		local pointVelocity = hull:GetVelocityAtPosition(worldPos)
		local f = VesselPhysics.clampedFloatForce({
			submersion = surface - worldPos.Y,
			verticalVelocity = pointVelocity.Y,
		}, state.stiffness, state.damping, state.maxDepth, weight, points)
		entry.force.Force = Vector3.new(0, f, 0)
	end

	-- the same measurement hook the launch has, for the same reason: the client loop cannot be driven
	-- from a probe (finding 0022), so the speed cap has to be testable without a human at the oars
	if workspace:GetAttribute("TenderTestDrive") == true then
		local t = workspace:GetAttribute("TenderTestThrottle")
		local st = workspace:GetAttribute("TenderTestSteer")
		state.throttle = if typeof(t) == "number" then math.clamp(t, -1, 1) else 0
		state.steer = if typeof(st) == "number" then math.clamp(st, -1, 1) else 0
	end

	local forward = hull.CFrame.LookVector
	local forwardSpeed = hull.AssemblyLinearVelocity:Dot(forward)
	local net = VesselPhysics.driveForce(state.throttle, forwardSpeed, state.spec.thrust, state.drag, state.linearDrag)
	if state.drive then
		-- capped like the launch's: a boat must not be able to kill its crew through a sign error
		local overspeed = forwardSpeed > state.spec.cruise * 1.6
		state.drive.Force = forward * (if overspeed then math.min(net, 0) else net)
	end
	if state.grip then
		local right = hull.CFrame.RightVector
		state.grip.Force = right * VesselPhysics.lateralForce(
			hull.AssemblyLinearVelocity:Dot(right), hull:GetMass(), state.spec.lateralGrip)
	end
	if state.rudder then
		local yawRate = hull.AssemblyAngularVelocity.Y
		local rudderT = VesselPhysics.rudderTorque(state.steer, forwardSpeed, state.spec.cruise, state.rudderAuthority)
		local dampT = VesselPhysics.yawDamping(yawRate, forwardSpeed, state.spec.cruise, state.yawDamping)
		state.rudder.Torque = Vector3.new(0, rudderT + dampT, 0)
	end

	-- keep the barrels riding the swell
	for _, barrel in ipairs(state.barrels) do
		if barrel.Parent then
			local p = barrel.Position
			local y = WaveField.HeightAt(p.X, p.Z, now)
			barrel.CFrame = CFrame.new(p.X, y + 0.6, p.Z) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	workspace:SetAttribute("TenderSpeed", forwardSpeed)
end

input.OnServerEvent:Connect(function(player, throttle, steer)
	if state.driver ~= player then
		return -- only whoever has the oars
	end
	if typeof(throttle) == "number" and throttle == throttle then
		state.throttle = math.clamp(throttle, -1, 1)
	end
	if typeof(steer) == "number" and steer == steer then
		state.steer = math.clamp(steer, -1, 1)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if state.driver == player then
		state.driver, state.throttle, state.steer = nil, 0, 0
		workspace:SetAttribute("TenderDriver", "")
	end
	state.carrying[player] = nil
end)

task.defer(function()
	--[[
		Deferred so `VesselServer` has published `_G.TideVessel` - the tender and the barrels are both placed
		relative to the launch, and the filler prompt attaches to its hull. Waiting on the handle rather than
		on a fixed delay, because a delay that is usually long enough is the worst kind.
	]]
	for _ = 1, 200 do
		if launchHull() then
			break
		end
		task.wait(0.1)
	end
	buildTender()
	buildBarrels()
	attachFiller()
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[TENDER] step failed: " .. tostring(err))
		end
	end)
	print("[TENDER] rescue loop ready")
end)

_G.TideTender = {
	state = state,
	report = function(): string
		local hull = state.hull
		local spec = state.spec
		if not hull or not spec then
			return "no tender"
		end
		local forward = hull.CFrame.LookVector
		return table.concat({
			("%s  mass %.0f  cruise %d"):format(spec.name, hull:GetMass(), spec.cruise),
			("speed %.2f fwd   break-even %.2f  -> %s"):format(
				hull.AssemblyLinearVelocity:Dot(forward), 14 / 1.6,
				spec.cruise < 14 / 1.6 and "cannot outrun the storm" or "🔴 CAN OUTRUN THE STORM"),
			("driver %s   barrels left %d"):format(
				state.driver and state.driver.Name or "nobody at the oars", #state.barrels),
			("owner %s (must be nil)"):format(tostring(hull:GetNetworkOwner())),
		}, "\n")
	end,
}
