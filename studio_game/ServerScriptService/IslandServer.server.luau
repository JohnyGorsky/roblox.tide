--!strict
--[[
	IslandServer - pastes the captured island templates into the sea, then seats things on them.

	Feature: GAME-0005  ·  decisions 0016, 0024, 0025  ·  job 027

	--------------------------------------------------------------------------------------------------
	WHY THE ISLANDS ARE NOT IN THE SAVED PLACE

	Decision 0016: an island is stored as a `TerrainRegion` template in `ServerStorage` and pasted at
	runtime. So the saved place contains the TEMPLATE and no islands, and this script is what makes the
	sea have land in it. `tools/author-island.luau` is what puts the template there in the first place.

	`TerrainRegion` does not replicate server -> client, which is why the paste has to happen here rather
	than on each client.

	--------------------------------------------------------------------------------------------------
	PASTED AT BOOT, NOT AT RUN START

	Job 027's plan said "at run start". Boot is better, and the difference matters:

	  * a 240,000-cell paste is expensive. At boot nobody is playing; mid-run it is a hitch at exactly the
	    moment the crew is being chased.
	  * the first island is then already on the radar from the start island, which TEACHES the instrument
	    during the five minutes before departure instead of leaving the scope empty.

	Positions are fixed for this first slice. Decision 0016's point is that they are not fixed FOREVER -
	the template is placeable anywhere, and per-run selection is the next step, not a rewrite.

	--------------------------------------------------------------------------------------------------
	🔴 VERIFY THE GROUND, THEN SEAT. NEVER THE OTHER WAY ROUND.

	Decision 0016's own consequence: terrain must exist before anything is seated on it - probe for ground,
	never assume, and validate across the whole footprint rather than with one raycast. Both failures have
	happened in this workspace, so:

	  * the paste is verified by reading VOXELS, which are authoritative and do not depend on physics
	  * markers are seated by RAYCAST, because that is what every later system will use
	  * the two must agree, and a mismatch is reported rather than smoothed over

	If the ground is not there, the island is skipped and says so. A missing island is a bug you can see;
	props floating over open water is a bug that ships.

	--------------------------------------------------------------------------------------------------
	⚠️ A TERRAIN WRITE IS NOT READABLE IN THE SAME BREATH

	Voxels need a frame or two to settle before a raycast will hit them. Seating immediately after the
	paste finds nothing, and everything lands at the fallback height instead.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local IslandTemplates = require(ReplicatedStorage:WaitForChild("IslandTemplates"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local Terrain = workspace.Terrain

local TAG_MARKER = "IslandMarker"
local TAG_CONTACT = "RadarContact"
local GRAYBOX_ID = "GB-ISLAND-PROPS"

--[[
	Four islands up the corridor. Every coordinate is a MULTIPLE OF 4, because `PasteRegion` takes CELL
	coordinates - a 502 would be quantised silently and the island would not be where its markers say.

	The one at 1300 off the centreline is deliberate: at that offset it first appears as the radar's
	uncertain amber circle rather than a labelled fix, so the crew has to decide whether to go and look.
	That is the entire point of the edge treatment, and it needs something real out there to point at.

	Names are placeholders - evocative enough to read on a scope, not content. Groups 03/05 own the real ones.
]]
local PLACEMENTS = {
	{ template = "Cay", x = 600, z = 500, name = "Gull Rock" },
	{ template = "Cay", x = -900, z = 1100, name = "The Spit" },
	{ template = "Cay", x = 1300, z = 1700, name = "Anvil Cay" },
	{ template = "Cay", x = -500, z = 2200, name = "Long Shoal" },
}

--- How much of the plateau must actually be there before anything is seated on it.
local GROUND_SAMPLES = 5 -- a 5x5 grid across the plateau, so up to 25 probes
local GROUND_REQUIRED = 0.9
local GROUND_TOLERANCE = 0.6 -- studs. Tight on purpose: see verifyPlateau for why 2 was hiding a bug

local state = {
	islands = {} :: { [string]: any },
	pasted = 0,
	skipped = 0,
}

-- ---------------------------------------------------------------------------
-- Probing
-- ---------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Terrain }
rayParams.IgnoreWater = true -- we want the land under the sea, not the sea

--- Terrain surface height at a world XZ, or nil for open water.
local function groundAt(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), rayParams)
	return hit and hit.Position.Y or nil
end

--[[
	Did the plateau actually arrive? Sampled on a GRID across the footprint, not at the centre.

	One raycast at the centre passes for an island that pasted only its middle column, and "validate the
	footprint, not a point" is a rule this workspace learned the hard way on a 43-218 stud model.
]]
local function verifyPlateau(centre: Vector3, template: any): (boolean, string)
	--[[
		⚠️ Compare against the SURFACE, not the band height. Smooth terrain's collision surface sits RES/2
		above the height you sculpt (measured in job 027, mean absolute error 0.087 studs across 73 columns).

		Comparing raw gave "worst error 2.0 studs" on all four islands with the tolerance at exactly 2 - a
		pass that a 1.9 tolerance would have failed, which is a test agreeing with a bug rather than checking
		anything. With the conversion the tolerance can be tight enough to catch a real problem.
	]]
	local plateau = IslandTemplates.surfaceOf(template.band.plateau)
	local reach = template.band.rp * 0.7 -- inside the plateau even at the noise's smallest radius
	local hits, total, worst, lowest = 0, 0, 0, math.huge
	for ix = 0, GROUND_SAMPLES - 1 do
		for iz = 0, GROUND_SAMPLES - 1 do
			local fx = (ix / (GROUND_SAMPLES - 1)) * 2 - 1
			local fz = (iz / (GROUND_SAMPLES - 1)) * 2 - 1
			if fx * fx + fz * fz <= 1 then
				total += 1
				local h = groundAt(centre.X + fx * reach, centre.Z + fz * reach)
				if h then
					if math.abs(h - plateau) <= GROUND_TOLERANCE then
						hits += 1
					end
					lowest = math.min(lowest, h)
					worst = math.max(worst, math.abs(h - plateau))
				end
			end
		end
	end
	local fraction = total > 0 and hits / total or 0
	if fraction < GROUND_REQUIRED then
		return false, ("plateau %d/%d probes at Y=%d (%.0f%%, need %.0f%%); lowest hit %s")
			:format(hits, total, plateau, fraction * 100, GROUND_REQUIRED * 100,
				lowest == math.huge and "none" or ("%.1f"):format(lowest))
	end
	return true, ("plateau %d/%d probes at Y=%d, worst error %.1f studs"):format(hits, total, plateau, worst)
end

--- Cross-check the raycasts against the voxels, so a physics-only or voxel-only failure cannot hide.
local function voxelSurfaceAt(x: number, z: number): number?
	local region = Region3.new(Vector3.new(x - 2, -60, z - 2), Vector3.new(x + 2, 24, z + 2)):ExpandToGrid(4)
	local ok, data = pcall(function()
		return Terrain:ReadVoxelChannels(region, 4, { "SolidOccupancy" })
	end)
	if not ok then
		warn("[IslandServer] ReadVoxelChannels failed: " .. tostring(data))
		return nil
	end
	local occ = (data :: any).SolidOccupancy
	local base = region.CFrame.Position - region.Size / 2
	--[[
		Topmost NON-EMPTY voxel, then `centre + occupancy * RES`. Both details matter: the partial cell is
		what shapes the surface, and `centre + RES/2` (the terrain skill's rule) is off by up to 2 studs, which
		would make this cross-check disagree with the raycast on every single column.
	]]
	for yi = #occ[1], 1, -1 do
		local o = occ[1][yi][1]
		if o > 0.01 then
			return base.Y + (yi - 0.5) * 4 + o * 4
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------

local function marker(parent: Folder, islandId: string, name: string, kind: string, pos: Vector3, note: string?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(2, 2, 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Position = pos
	part:SetAttribute("IslandId", islandId)
	part:SetAttribute("MarkerKind", kind)
	if note then
		part:SetAttribute("Note", note)
	end
	CollectionService:AddTag(part, TAG_MARKER)
	part.Parent = parent
	return part
end

--- A graybox block. Obviously placeholder, registered, and cheap to delete when the real prop lands.
--- Returns `Part`, not `BasePart`: `Shape` is a `Part` property and callers set it.
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Material = Enum.Material.Slate
	p.Color = colour
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local GREY = Color3.fromRGB(126, 126, 126)
local DARK = Color3.fromRGB(74, 70, 64)
local WOOD = Color3.fromRGB(104, 86, 62)

--[[
	Graybox props at the manifest's three dry zones, so the island is not a bare table and groups 03 and 05
	have something to attach to. Shapes only - a wreck reads as a wreck because it is a tilted slab, not
	because it is detailed.
]]
local function buildProps(parent: Folder, islandId: string, zones: { [string]: Vector3 }): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = parent

	local wreck = zones.Wreck
	if wreck then
		local g = Instance.new("Model")
		g.Name = "GB_Wreck"
		g.Parent = folder
		block(g, "Hull", Vector3.new(18, 7, 6),
			CFrame.new(wreck + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(28), math.rad(-34)), WOOD)
		block(g, "Rib", Vector3.new(1, 6, 5),
			CFrame.new(wreck + Vector3.new(7, 2, 3)) * CFrame.Angles(math.rad(18), 0, math.rad(-12)), WOOD)
		block(g, "Tarp", Vector3.new(9, 0.4, 7),
			CFrame.new(wreck + Vector3.new(-8, 0.6, -2)) * CFrame.Angles(0, math.rad(-20), math.rad(6)), GREY)
	end

	local camp = zones.Camp
	if camp then
		local g = Instance.new("Model")
		g.Name = "GB_Camp"
		g.Parent = folder
		local tent = block(g, "Tent", Vector3.new(9, 6, 7), CFrame.new(camp + Vector3.new(0, 3, 0)), GREY)
		tent.Material = Enum.Material.Fabric
		-- 🔴 a cylinder's axis is its LOCAL X, so the THICKNESS goes in Size.X and the diameter in Y/Z.
		-- Size (3.5, 0.8, 3.5) rotated upright gave a 3.5-tall tower with a squashed 0.8 x 3.5 section.
		local fire = block(g, "Firepit", Vector3.new(0.8, 3.5, 3.5),
			CFrame.new(camp + Vector3.new(7, 0.4, 2)) * CFrame.Angles(0, 0, math.rad(90)), DARK)
		fire.Shape = Enum.PartType.Cylinder
		block(g, "Rack", Vector3.new(0.6, 4, 6), CFrame.new(camp + Vector3.new(-6, 2, -3)), WOOD)
	end

	local rise = zones.Rise
	if rise then
		local g = Instance.new("Model")
		g.Name = "GB_Rise"
		g.Parent = folder
		-- the rise is a PROP, not terrain: the plateau stays provably flat (see IslandTemplates)
		-- 6 studs THICK and 26 across: axis length in Size.X, diameter in Y/Z, then stood upright.
		-- The first version was Size (26, 6, 26), which built a 26-stud tower instead of a low mound.
		local mound = block(g, "Mound", Vector3.new(6, 26, 26),
			CFrame.new(rise + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), GREY)
		mound.Shape = Enum.PartType.Cylinder
		mound.Material = Enum.Material.Ground
		block(g, "DeadTree", Vector3.new(1.4, 12, 1.4),
			CFrame.new(rise + Vector3.new(3, 9, -2)) * CFrame.Angles(math.rad(7), 0, math.rad(9)), DARK)
		block(g, "Boulder", Vector3.new(6, 5, 5), CFrame.new(rise + Vector3.new(-8, 5, 4)), GREY)
	end

	for _, model in ipairs(folder:GetChildren()) do
		CollectionService:AddTag(model, "Graybox")
		model:SetAttribute("GrayboxId", GRAYBOX_ID)
		model:SetAttribute("IslandId", islandId)
	end
	return folder
end

-- ---------------------------------------------------------------------------
-- One island, end to end
-- ---------------------------------------------------------------------------

local function place(spec: any): boolean
	local template = IslandTemplates.get(spec.template)
	if not template then
		warn(("[IslandServer] no template '%s'"):format(tostring(spec.template)))
		return false
	end

	local store = ServerStorage:FindFirstChild("Islands")
	local entry = store and store:FindFirstChild(spec.template)
	local region = entry and entry:FindFirstChild("Terrain") :: TerrainRegion?
	local meta = entry and entry:FindFirstChild("Meta")
	if not region or not meta then
		warn(("[IslandServer] ServerStorage/Islands/%s/{Terrain,Meta} missing. Run tools/author-island.luau "
			.. "in EDIT and SAVE THE PLACE - the template lives in the saved file, not in code.")
			:format(spec.template))
		return false
	end

	if not SeaStates.insideOcean(spec.x, spec.z) then
		warn(("[IslandServer] %s at (%d, %d) is outside the ocean corridor"):format(spec.name, spec.x, spec.z))
		return false
	end
	if spec.x % 4 ~= 0 or spec.z % 4 ~= 0 then
		warn(("[IslandServer] %s at (%d, %d) is not cell-aligned; the paste would quantise it")
			:format(spec.name, spec.x, spec.z))
		return false
	end

	local halfCells = meta:GetAttribute("HalfCells") :: number
	local minCellY = meta:GetAttribute("MinCellY") :: number
	local corner = Vector3int16.new(spec.x / 4 - halfCells, minCellY, spec.z / 4 - halfCells)

	local okp, err = pcall(function()
		-- false OVERLAYS solid cells; true would clear every empty cell and punch square holes in the ocean
		Terrain:PasteRegion(region, corner, false)
	end)
	if not okp then
		warn(("[IslandServer] PasteRegion failed for %s: %s"):format(spec.name, tostring(err)))
		return false
	end

	-- voxels need a frame or two before a raycast will hit them
	task.wait()
	task.wait()

	local centre = Vector3.new(spec.x, template.band.plateau, spec.z)
	local ok, detail = verifyPlateau(centre, template)
	if not ok then
		warn(("[IslandServer] %s FAILED verification and was NOT seated: %s"):format(spec.name, detail))
		state.skipped += 1
		return false
	end
	local voxel = voxelSurfaceAt(spec.x, spec.z)
	local ray = groundAt(spec.x, spec.z)
	if voxel and ray and math.abs(voxel - ray) > GROUND_TOLERANCE then
		warn(("[IslandServer] %s: voxel surface %.1f disagrees with raycast %.1f"):format(spec.name, voxel, ray))
	end

	local folder = Instance.new("Folder")
	folder.Name = spec.name
	folder:SetAttribute("TemplateId", spec.template)
	folder:SetAttribute("IslandCentre", centre)
	folder.Parent = workspace

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = folder

	local zones: { [string]: Vector3 } = {}
	local seated, groundless = 0, 0
	for _, m in ipairs(template.markers) do
		local off = IslandTemplates.markerOffset(template, m)
		local wx, wz = spec.x + off.X, spec.z + off.Y
		local y: number
		local found = true
		if m.ground then
			local h = groundAt(wx, wz)
			if h then
				y = h + (m.lift or 0)
			else
				-- refuse to invent a height: park it at the water and flag it
				y = SeaStates.WATER_Y
				found = false
			end
		else
			y = SeaStates.WATER_Y -- offshore by design: the dock, the reef, the swimmer's shark
		end
		local part = marker(markers, spec.name, m.name, m.kind, Vector3.new(wx, y, wz), m.note)
		if found then
			seated += 1
		else
			groundless += 1
			part:SetAttribute("NoGround", true)
		end
		zones[m.name] = Vector3.new(wx, y, wz)
	end

	buildProps(folder, spec.name, zones)

	-- the radar sees the island through its POI marker, by TAG (finding 0020) - no registry to edit
	local poi = markers:FindFirstChild("POI")
	if poi then
		poi:SetAttribute("RadarKind", "land")
		poi:SetAttribute("RadarLabel", spec.name)
		CollectionService:AddTag(poi, TAG_CONTACT)
	end

	state.islands[spec.name] = {
		name = spec.name,
		template = spec.template,
		centre = centre,
		folder = folder,
		seated = seated,
		groundless = groundless,
		detail = detail,
	}
	state.pasted += 1
	if groundless > 0 then
		warn(("[IslandServer] %s: %d marker(s) found no ground and sit at the waterline")
			:format(spec.name, groundless))
	end
	print(("[IslandServer] %s at (%d, %d) - %s, %d markers seated")
		:format(spec.name, spec.x, spec.z, detail, seated))
	return true
end

-- ---------------------------------------------------------------------------

local function run()
	for _, spec in ipairs(PLACEMENTS) do
		place(spec)
	end
	print(("[IslandServer] %d island(s) placed, %d skipped"):format(state.pasted, state.skipped))
end

;(_G :: any).TideIslands = {
	state = state,
	placements = PLACEMENTS,
	groundAt = groundAt,
}

task.spawn(run)
