--!strict
--[[
	WaveFieldDebug - make the invisible sea visible.

	Two views, for two different questions:

	  showGrid()   Where does OUR field think the surface is? A lattice of markers sitting at
	               WaveField.SurfaceAt. Watch it move; it is the physical sea, drawn.

	  showRuler()  How high does ROBLOX'S RENDERED water actually reach? A vertical ladder of markers at
	               known Y values. Screenshot it from water level and read off which rung the crests
	               touch.

	The ruler exists because the rendered amplitude is not readable from anything. `WaterWaveSize` is a
	dimensionless dial, not studs - so the only way to learn that "WaterWaveSize 0.18 looks like about N
	studs" is to hold a measuring stick up against it and look.

	--------------------------------------------------------------------------------------------------
	WHAT CALIBRATION CAN AND CANNOT ACHIEVE

	Roblox does not expose its water's wave phase, so our field can NEVER be phase-aligned to the render.
	Markers will not sit on visible crests, and chasing that is wasted effort.

	What must match is the ENVELOPE: crest-to-trough range, and the apparent distance between crests.
	Get those right and the boat's motion reads as belonging to the water the player is looking at.

	Feature: docs/features/0014-wave-field/
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WaveField = require(ReplicatedStorage:WaitForChild("WaveField"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local WaveFieldDebug = {}

local FOLDER_NAME = "_WaveFieldDebug"
local RADAR_GREEN = Color3.fromRGB(82, 255, 154)
local WARNING_AMBER = Color3.fromRGB(242, 181, 68)

local connection: RBXScriptConnection? = nil

--[[
	Grid and ruler live in SEPARATE subfolders, and each view clears only its own.

	This was a bug worth remembering: `showGrid` originally began by wiping the whole debug folder, so
	showing the grid destroyed the ruler - and grid-plus-ruler is precisely the combination calibration
	needs. A "clear everything" default is the wrong default for a tool whose views are meant to overlay.
]]
local function root(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	f.Parent = workspace
	return f
end

local function folder(sub: string): Folder
	local r = root()
	local existing = r:FindFirstChild(sub)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = sub
	f.Parent = r
	return f
end

local function clearSub(sub: string)
	local r = workspace:FindFirstChild(FOLDER_NAME)
	local existing = r and r:FindFirstChild(sub)
	if existing then
		existing:Destroy()
	end
end

--[[
	Markers are deliberately bright Radar Green and named with a `_` prefix: they are DEBUG, not graybox
	placeholders standing in for art, and the graybox audit's heuristic looks for large untextured grey
	parts. Keeping them obviously-not-grey stops them polluting that report.
]]
local function marker(name: string, size: Vector3, colour: Color3, sub: string): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Shape = Enum.PartType.Ball
	p.Parent = folder(sub)
	return p
end

--- Remove the grid only, and stop updating it.
function WaveFieldDebug.hideGrid()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	clearSub("Grid")
end

--- Remove the ruler only.
function WaveFieldDebug.hideRuler()
	clearSub("Ruler")
end

--- Remove every debug object and stop updating.
function WaveFieldDebug.hide()
	WaveFieldDebug.hideGrid()
	WaveFieldDebug.hideRuler()
	local f = workspace:FindFirstChild(FOLDER_NAME)
	if f then
		f:Destroy()
	end
end

--[[
	A lattice of markers riding our field.

	`count` per side, `spacing` studs apart, centred on `origin`. 16 x 16 at 12 studs covers ~190 studs,
	which is roughly a starter vessel's length several times over - enough to see the swell shape without
	thousands of parts.
]]
function WaveFieldDebug.showGrid(count: number?, spacing: number?, origin: Vector3?)
	WaveFieldDebug.hideGrid() -- NOT hide(): that would take the ruler with it
	local n = count or 16
	local step = spacing or 12
	local centre = origin or Vector3.zero
	local half = (n - 1) * step * 0.5

	local parts: { BasePart } = {}
	local xs: { number } = {}
	local zs: { number } = {}
	for i = 1, n do
		for j = 1, n do
			local x = centre.X - half + (i - 1) * step
			local z = centre.Z - half + (j - 1) * step
			local p = marker(("_g%d_%d"):format(i, j), Vector3.one * 1.6, RADAR_GREEN, "Grid")
			table.insert(parts, p)
			table.insert(xs, x)
			table.insert(zs, z)
		end
	end

	local function update()
		for k, p in ipairs(parts) do
			p.Position = WaveField.SurfaceAt(xs[k], zs[k])
		end
	end
	update()
	connection = RunService.Heartbeat:Connect(update)
	return #parts
end

--[[
	A vertical measuring stick.

	Rungs every `step` studs from `from` to `to`, each labelled with its height. Amber, so it never gets
	confused with the green field markers. Screenshot this from water level and read off where the
	rendered crests reach - that number is the rendered amplitude, in studs, which is the thing no
	property will tell you.
]]
function WaveFieldDebug.showRuler(at: Vector3?, from: number?, to: number?, step: number?)
	local pos = at or Vector3.new(0, 0, 0)
	local lo = from or -10
	local hi = to or 10
	local inc = step or 1

	WaveFieldDebug.hideRuler()
	local f = folder("Ruler")
	local made = 0
	local y = lo
	while y <= hi do
		-- Label EVERY whole stud, not every fifth: the seas we care about are 1-15 studs crest-to-trough,
		-- so a 5-stud label spacing leaves the calm states with a single labelled rung and no scale.
		local isWhole = math.abs(y - math.floor(y + 0.5)) < 0.001
		local isFifth = isWhole and math.abs(y % 5) < 0.001
		local rung = Instance.new("Part")
		rung.Name = ("_ruler_%+.1f"):format(y)
		rung.Size = Vector3.new(isFifth and 10 or (isWhole and 6 or 3), 0.18, 0.18)
		rung.Position = Vector3.new(pos.X, y, pos.Z)
		rung.Anchored = true
		rung.CanCollide = false
		rung.CanQuery = false
		rung.CanTouch = false
		rung.CastShadow = false
		rung.Material = Enum.Material.Neon
		rung.Color = isWhole and WARNING_AMBER or Color3.fromRGB(150, 120, 60)
		if isFifth then
			rung.Color = Color3.fromRGB(217, 75, 75) -- Danger Red every 5 studs, for a coarse read
		end
		rung.Parent = f
		if isWhole then
			local label = Instance.new("BillboardGui")
			label.Size = UDim2.fromOffset(48, 18)
			label.AlwaysOnTop = true
			label.Parent = rung
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.Code
			text.TextSize = 14
			text.TextColor3 = WARNING_AMBER
			text.Text = ("%+d"):format(math.floor(y + 0.5))
			text.Parent = label
		end
		made += 1
		y += inc
	end
	return made
end

--[[
	Numbers rather than pictures: what our field is doing right now, for the console.
	Pair it with a screenshot of the ruler to compare against the render.
]]
function WaveFieldDebug.report(): string
	local state = WaveField.getState()
	local lo, hi, range = WaveField.measureRange(30)
	local w = state.wave
	return table.concat({
		("state          %s"):format(state.name),
		("spec amplitude %.2f  -> crest-to-trough %.2f"):format(w.amplitude, w.amplitude * 2),
		("measured       %.2f .. %.2f  (range %.2f, %.0f%% of spec)"):format(lo, hi, range, range / (w.amplitude * 2) * 100),
		("wavelength     %.0f studs   speed %.1f   dir %d deg   spread %.1f   chop %.1f"):format(
			w.length, w.speed, w.directionDeg, w.directionSpread, w.choppiness),
		("rendered water WaterWaveSize=%.2f WaterWaveSpeed=%.1f  <- dimensionless; measure with the ruler")
			:format(workspace.Terrain.WaterWaveSize, workspace.Terrain.WaterWaveSpeed),
	}, "\n")
end

return WaveFieldDebug
