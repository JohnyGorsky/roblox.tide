--!strict
--[[
	RadarServer - builds the station, turns the aerial, and owns what counts as a contact.

	Feature: GAME-0002  ·  decisions 0004, 0014, 0019  ·  job 026

	--------------------------------------------------------------------------------------------------
	CONTACTS ARE DISCOVERED BY TAG, NEVER BY PATH

	A contact is any instance tagged `RadarContact`, carrying:

	    RadarKind    "land" | "object" | "unknown"     what colour and shape it draws as
	    RadarLabel   optional string                    shown only when the contact is CONFIDENT

	Finding 0020 is the story of a hardcoded instance path between two systems rotting silently and making the
	storm unbeatable. So group 04's islands will only have to tag themselves - no registry to edit, no list to
	keep in step, and nothing here needs to know that islands exist.

	--------------------------------------------------------------------------------------------------
	WHAT "SERVER-AUTHORITATIVE" HONESTLY MEANS HERE

	The server owns the REGISTRY: it decides what is a contact and what kind it is, so a client cannot invent
	one. It does not make the sea secret - tagged instances are replicated, so a determined client could
	enumerate them regardless.

	Same honesty as the `VesselHeading` note in job 022: this removes the tempting shortcut, not the underlying
	information. Worth stating so nobody builds a security claim on top of it.

	--------------------------------------------------------------------------------------------------
	THE AERIAL AND THE CONSOLE ARE TWO DIFFERENT THINGS

	The `radar` socket sits three and a half studs above the deck - too high to read, exactly right for a
	scanner. So the aerial turns up there and the console stands at deck level on the new `radarConsole`
	socket. It also means the sweep is legible to the whole crew from outside the wheelhouse, not just to
	whoever is at the scope.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Radar = require(ReplicatedStorage:WaitForChild("Radar"))

local TAG = "RadarContact"

local state = {
	console = nil :: BasePart?,
	aerial = nil :: BasePart?,
	built = false,
}

local function launchModel(): Model?
	local V = (_G :: any).TideVessel
	local hull = V and V.state and V.state.hull
	return hull and hull.Parent :: Model? or nil
end

--- Tag an instance as a contact. The only way anything gets on the scope.
local function register(instance: Instance, kind: Radar.Kind, label: string?)
	instance:SetAttribute("RadarKind", kind)
	if label then
		instance:SetAttribute("RadarLabel", label)
	end
	CollectionService:AddTag(instance, TAG)
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

local function build()
	local model = launchModel()
	local hull = model and model.PrimaryPart
	if not hull or not model then
		return false
	end
	local sockets = hull:FindFirstChild("Sockets") :: Folder?
	if not sockets then
		return false
	end

	--[[
		THE AERIAL, on the `radar` socket. A plain bar that turns at the sweep period.

		Massless and non-colliding for the same reason every other fitting is: a 4-stud bar with real density
		six studs up would shift the centre of mass, and this hull's heel is tuned to fractions of a degree.
	]]
	local radarSocket = sockets:FindFirstChild("radar") :: Attachment?
	if radarSocket and not model:FindFirstChild("RadarAerial") then
		local mast = Instance.new("Part")
		mast.Name = "RadarMast"
		mast.Size = Vector3.new(0.4, 3, 0.4)
		mast.CFrame = hull.CFrame * CFrame.new(radarSocket.Position - Vector3.new(0, 1.5, 0))
		mast.Anchored = false
		mast.CanCollide = false
		mast.Massless = true
		mast.Material = Enum.Material.Metal
		mast.Color = Color3.fromRGB(46, 70, 88)
		mast.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hull
		weld.Part1 = mast
		weld.Parent = mast

		local aerial = Instance.new("Part")
		aerial.Name = "RadarAerial"
		aerial.Size = Vector3.new(4.5, 0.25, 0.6)
		aerial.CFrame = hull.CFrame * CFrame.new(radarSocket.Position)
		--[[
			🔴 ANCHORED, and that is deliberate rather than lazy.

			The aerial has to SPIN, and spinning a welded part means either a HingeConstraint with a motor or
			rewriting its CFrame every frame. Rewriting the CFrame of a part welded into a moving physics
			assembly fights the solver - the exact class of problem the physics guidance warns about, and job
			021 already lost a hull to a fight over one assembly.

			So the aerial is its own anchored part, repositioned from the hull's CFrame each frame. It is
			cosmetic: nothing collides with it and nothing stands on it.
		]]
		aerial.Anchored = true
		aerial.CanCollide = false
		aerial.CanQuery = false
		aerial.Material = Enum.Material.Metal
		aerial.Color = Color3.fromRGB(196, 204, 208)
		aerial.Parent = model
		state.aerial = aerial
	end

	local consoleSocket = sockets:FindFirstChild("radarConsole") :: Attachment?
	if consoleSocket and not model:FindFirstChild("RadarConsole") then
		--[[
			🔴 A VERTICAL SCREEN, FACING AFT. The first version put the scope on a horizontal plot
			table and it was wrong for a reason worth recording.

			A `SurfaceGui` on the TOP face maps its 2D "up" to one of the part's horizontal axes - and which one
			is not something a player standing at the console can predict. The compass got away with it in job
			022 because a compass card is rotationally symmetric: turn it any way and it still reads. A display
			with four text readouts and a legend has a READING DIRECTION, so on a top face the text came out
			sideways.

			So the screen is vertical, and its facing is set BY CONSTRUCTION rather than by picking a NormalId
			and hoping: the part is rotated so its own LookVector points AFT, and the GUI always goes on
			`Front`. Gravity then fixes "up", and an operator standing between the screen and the stern reads it
			the right way round while facing forward - which is how a real bridge console is arranged.

			Oriented against the hull's measured `LookVector`, never against a spec label: finding 0021 records
			that this spec calls +Z the bow while the hull drives toward -Z.
		]]
		local aft = -hull.CFrame.LookVector
		local basePosition = (hull.CFrame * CFrame.new(consoleSocket.Position)).Position

		local pedestal = Instance.new("Part")
		pedestal.Name = "RadarPedestal"
		pedestal.Size = Vector3.new(2.4, 2.2, 1.6)
		pedestal.CFrame = CFrame.lookAt(basePosition + Vector3.new(0, 1.1, 0), basePosition + Vector3.new(0, 1.1, 0) + aft)
		pedestal.Anchored = false
		pedestal.CanCollide = false
		pedestal.Massless = true
		pedestal.Material = Enum.Material.Metal
		pedestal.Color = Color3.fromRGB(32, 48, 60)
		pedestal.Parent = model
		local pedWeld = Instance.new("WeldConstraint")
		pedWeld.Part0 = hull
		pedWeld.Part1 = pedestal
		pedWeld.Parent = pedestal

		--[[
			The screen itself: 4 wide by 2.8 tall, so the GUI has a known landscape aspect and can be laid out
			like the concept mockup - scope on the left, conditions on the right - instead of guessing.
		]]
		local screenCentre = basePosition + Vector3.new(0, 3.3, 0)
		local console = Instance.new("Part")
		console.Name = "RadarConsole"
		console.Size = Vector3.new(4, 2.8, 0.3)
		console.CFrame = CFrame.lookAt(screenCentre, screenCentre + aft)
		console.Anchored = false
		console.CanCollide = false
		console.Massless = true
		console.Material = Enum.Material.Metal
		console.Color = Color3.fromRGB(24, 34, 42)
		console.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hull
		weld.Part1 = console
		weld.Parent = console
		state.console = console

		--[[
			Self-lit like the compass: `LightInfluence = 0` so The Wall's brightness of 0.30 cannot dim it. Even
			though the radar is DEAD in there, the legend and the failure message still have to be readable - an
			instrument you cannot read is indistinguishable from one that is off.
		]]
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Scope"
		surface.Face = Enum.NormalId.Front -- always Front; the PART is what gets rotated
		surface.LightInfluence = 0
		surface.Brightness = 2
		surface.PixelsPerStud = 140
		surface.Parent = console

		CollectionService:AddTag(surface, "RadarScope") -- the client finds it by tag, not by path
	end

	--[[
		Register what already exists, so the contact system ships VERIFIED rather than stubbed.

		The start island is the good demo on its own: as the vessel travels north it recedes past 1,080 and
		then 1,800, so a single contact walks the whole resolution curve - labelled blip, amber circle, gone.
	]]
	local islandMarker = workspace:FindFirstChild("GB_StartIslandMarker")
	if islandMarker and not CollectionService:HasTag(islandMarker, TAG) then
		register(islandMarker, "land", "Start Island")
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "FuelBarrel" and not CollectionService:HasTag(child, TAG) then
			register(child, "object", "Fuel")
		end
	end
	local tender = workspace:FindFirstChild("Tender")
	if tender and tender:IsA("Model") and tender.PrimaryPart and not CollectionService:HasTag(tender.PrimaryPart, TAG) then
		register(tender.PrimaryPart, "object", "Tender")
	end

	state.built = true
	return true
end

-- ---------------------------------------------------------------------------
-- Step: turn the aerial, keep it on the mast
-- ---------------------------------------------------------------------------

local function step()
	local model = launchModel()
	local hull = model and model.PrimaryPart
	local aerial = state.aerial
	if not (hull and aerial and aerial.Parent) then
		return
	end
	local sockets = hull:FindFirstChild("Sockets") :: Folder?
	local socket = sockets and sockets:FindFirstChild("radar") :: Attachment?
	if not socket then
		return
	end
	--[[
		Follow the hull and spin. Derived from server time rather than accumulated, so the aerial and the
		client's beam are computing the same angle from the same clock and cannot drift apart - which they
		would, visibly, within a minute of accumulating separately.
	]]
	local angle = Radar.sweepAngle(workspace:GetServerTimeNow())
	aerial.CFrame = hull.CFrame * CFrame.new(socket.Position) * CFrame.Angles(0, math.rad(-angle), 0)
end

task.defer(function()
	-- wait on the launch's own handle rather than a fixed delay; a delay that is usually long enough is worse
	for _ = 1, 300 do
		if build() then
			break
		end
		task.wait(0.1)
	end
	if not state.built then
		warn("[RADAR] no vessel after 30 s - the station was not built")
		return
	end
	--[[
		Newly spawned barrels and the tender have to be picked up too - `TenderServer` builds them on its own
		deferred pass, and a barrel taken and later re-spawned would otherwise never appear on the scope.
	]]
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "FuelBarrel" then
			register(child, "object", "Fuel")
		end
	end)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[RADAR] step failed: " .. tostring(err))
		end
	end)
	local contacts = #CollectionService:GetTagged(TAG)
	print(("[RADAR] station built. range %d studs, sweep %.1fs, %d contacts registered")
		:format(Radar.RANGE, Radar.SWEEP_PERIOD, contacts))
end)

_G.TideRadar = {
	state = state,
	register = register,
	report = function(): string
		local model = launchModel()
		local hull = model and model.PrimaryPart
		local lines = {
			("range %d   sweep %.1fs   confident inside %d"):format(
				Radar.RANGE, Radar.SWEEP_PERIOD, Radar.RANGE * Radar.CONFIDENT_FRACTION),
			("station %s   aerial %s"):format(
				state.console and "built" or "MISSING", state.aerial and "built" or "MISSING"),
		}
		local dead, why = Radar.isDead(
			workspace:GetAttribute("StormIntensity") or 0,
			workspace:GetAttribute("VesselFault_radar") == true)
		table.insert(lines, ("scope   %s"):format(dead and ("DEAD - " .. tostring(why)) or "live"))
		if hull then
			for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
				local part = inst:IsA("BasePart") and inst or nil
				if part then
					local d = Radar.distanceTo(hull.Position, part.Position)
					table.insert(lines, ("  %-22s %6.0f studs  %s"):format(
						tostring(inst:GetAttribute("RadarLabel") or inst.Name), d, Radar.classify(d)))
				end
			end
		end
		return table.concat(lines, "\n")
	end,
}
