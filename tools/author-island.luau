--!strict
--[[
	author-island.luau - build an island TEMPLATE and store it in the saved place.

	Job 027  ·  decision 0016  ·  feature GAME-0005

	================================================================================================
	HOW TO RUN IT

	Via the Studio MCP, `execute_luau`, datamodel **Edit**. Set `STEP` below and run ONE step per call:

	    1. STEP = "sculpt"          sculpt the template into a clear patch of ocean
	    2. STEP = "verify"          check it. MUST be a separate call - see below
	    3. STEP = "capture"         CopyRegion it into ServerStorage/Islands/<id>/{Terrain,Props,Meta}
	    4. STEP = "restore"         put the sculpt site back to plain ocean
	    5. STEP = "verify-restore"  check nothing was left behind
	    6. **SAVE THE PLACE** - the template lives in the saved file, not in code

	🔴 Steps 2 and 5 exist as separate steps on purpose. Re-reading terrain in the SAME script as the write
	can return pre-write data: a Jungle repair once reported "45 columns fixed" and printed a byte-identical
	histogram because the write had not applied at all. Only a fresh call reveals it.

	================================================================================================
	WHY IT SCULPTS IN THE OCEAN AND NOT ON DRY LAND

	The runtime paste uses `pasteEmptyCells = false`, which overlays solid cells and leaves the destination's
	other cells alone. That is only safe because the island's solid runs from below the seabed up through
	every water cell it occupies, so no water is left stranded above land.

	Sculpt this on dry ground, or at a different sea level, and that reasoning collapses. Hence: same place,
	same water datum, a clear patch of the same ocean.

	================================================================================================
	WHAT THIS DOES NOT DO

	It does not place islands. `ServerScriptService/IslandServer` pastes them at boot, so the saved place
	carries the TEMPLATE and no islands - which is decision 0016 working as intended.
]]

local STEP: string = "verify-restore"

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
local RES = 4

local IslandTemplates = require((RS :: any).IslandTemplates:Clone())
local SeaStates = require((RS :: any).SeaStates:Clone())

--[[
	🔴 `:Clone()` on both requires is not decoration. The `execute_luau` context CACHES modules, so a plain
	`require` returns the copy from before the file last synced - which is how one run of this got a nil
	`faceRun` after the template gained a landing arc.
]]

local TEMPLATE_ID = "Cay"

--[[
	The sculpt site: a far corner of the corridor, clear of the start island, the vessel and the barrels.
	Cell-aligned, because every terrain coordinate here is quantised to 4 studs.
]]
local SCULPT = Vector3.new(-2400, 0, 4600)

--[[
	The donor patch used by "restore": clean ocean, far enough that its box cannot overlap the sculpt's.
	600 studs south of the sculpt, which leaves a 176-stud gap between two 424-wide boxes.
]]
local DONOR = Vector3.new(-2400, 0, 4000)

--- Y is ABSOLUTE, never relative to the island: the water level is global, so it pastes back at its own height.
local MIN_CELL_Y, MAX_CELL_Y = -15, 5 -- -60..+20 studs. -60 reaches below the ambient seabed at -54.

local template = IslandTemplates.get(TEMPLATE_ID)
if not template then
	return ("no template '%s'"):format(TEMPLATE_ID)
end
if type((IslandTemplates :: any).faceRun) ~= "function" then
	return "STALE MODULE: IslandTemplates has no faceRun - Studio has not synced the current file yet"
end

local band = template.band
local WATER_Y = SeaStates.WATER_Y
local halfStuds = math.ceil(IslandTemplates.footprint(template) / RES) * RES
local halfCells = halfStuds // RES

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

--- Surface paint noise. Deterministic, so a re-sculpt is identical.
local function noise(x: number, z: number, scale: number, phase: number): number
	return math.sin(x * scale + phase) * math.cos(z * scale * 0.83 + phase * 1.7)
		+ 0.5 * math.sin((x + z) * scale * 0.61 + phase * 2.3)
end

local function boxAround(centre: Vector3): Region3
	return Region3.new(
		centre - Vector3.new(halfStuds, 0, halfStuds) + Vector3.new(0, MIN_CELL_Y * RES, 0),
		centre + Vector3.new(halfStuds, 0, halfStuds) + Vector3.new(0, MAX_CELL_Y * RES, 0)
	):ExpandToGrid(RES)
end

--[[
	Column surface height, by the rule MEASURED in job 027:

	    topmost NON-EMPTY voxel centre + occupancy * RES        (mean absolute error 0.087 studs)

	Both details matter. The partial cell is what shapes the surface, and the `roblox-terrain` skill's
	"centre + RES/2" is off by up to 2 studs - which is exactly the off-by-2 that skill warns about.
]]
local function surfaceOfColumn(occ: any, xi: number, zi: number, baseY: number, ny: number): number?
	for yi = ny, 1, -1 do
		local o = occ[xi][yi][zi]
		if o > 0.01 then
			return baseY + (yi - 0.5) * RES + o * RES
		end
	end
	return nil
end

local function cellCorner(centre: Vector3): Vector3int16
	return Vector3int16.new(centre.X / RES - halfCells, MIN_CELL_Y, centre.Z / RES - halfCells)
end

local function cellRegion(centre: Vector3): Region3int16
	return Region3int16.new(
		Vector3int16.new(centre.X / RES - halfCells, MIN_CELL_Y, centre.Z / RES - halfCells),
		-- 🔴 Region3int16's max is INCLUSIVE. Measured: SizeInCells came back as max-min+1.
		Vector3int16.new(centre.X / RES + halfCells, MAX_CELL_Y, centre.Z / RES + halfCells)
	)
end

-- ---------------------------------------------------------------------------
-- STEP 1 - sculpt
-- ---------------------------------------------------------------------------

local function doSculpt(): string
	-- 🔴 BOUND THE EDIT. The code must be physically unable to reach outside these.
	local MAX_R = band.ro * 1.15
	local MIN_Y, MAX_Y = MIN_CELL_Y * RES, band.plateau + RES

	local region = boxAround(SCULPT)
	local voxels = (region.Size.X / RES) * (region.Size.Y / RES) * (region.Size.Z / RES)
	if voxels >= 4194304 then
		return ("ABORT: %d voxels is over the 4,194,304 limit"):format(voxels)
	end

	local ok, data = pcall(function()
		return Terrain:ReadVoxelChannels(region, RES, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	end)
	if not ok then
		return "ReadVoxelChannels FAILED: " .. tostring(data) -- never swallow this: it is how a size violation becomes a silent no-op
	end
	local mat, solid, liquid = (data :: any).SolidMaterial, (data :: any).SolidOccupancy, (data :: any).LiquidOccupancy
	local base = region.CFrame.Position - region.Size / 2

	local AIR, SAND, ROCK = Enum.Material.Air, Enum.Material.Sand, Enum.Material.Rock
	local GRASS, LEAFY = Enum.Material.Grass, Enum.Material.LeafyGrass
	local PAINT_DEPTH = 6
	local filled, carved, landingColumns, guard = 0, 0, 0, 0

	for xi = 1, #solid do
		local wx = base.X + (xi - 0.5) * RES
		for zi = 1, #solid[xi][1] do
			local wz = base.Z + (zi - 0.5) * RES
			local lx, lz = wx - SCULPT.X, wz - SCULPT.Z
			if math.sqrt(lx * lx + lz * lz) <= MAX_R then
				local h = IslandTemplates.heightAt(template, lx, lz)
				if h then
					if IslandTemplates.faceRun(template, lx, lz) > 0 then
						landingColumns += 1
					end
					--[[
						Material is chosen ONCE for the whole column, from the column's SURFACE height, and
						then applied down `PAINT_DEPTH` studs.

						Choosing it per voxel from that voxel's own height is what made the first sculpt come
						out 707 sand to 101 grass on a plateau that should be green.
					]]
					local grassLine = math.min(template.grassLine + 1.2 * noise(wx, wz, 0.02, 0.4), band.plateau - 1)
					local surfaceMat
					if h >= grassLine then
						surfaceMat = (noise(wx, wz, 0.035, 2.9) > 0.35) and LEAFY or GRASS
					elseif h >= -12 and noise(wx, wz, 0.05, 5.1) > 0.85 then
						surfaceMat = ROCK
					else
						surfaceMat = SAND
					end

					for yi = 1, #solid[xi] do
						local wy = base.Y + (yi - 0.5) * RES
						if wy > MAX_Y or wy < MIN_Y then
							guard += 1
						else
							--[[
								Every voxel in the band is written EXPLICITLY - carved to air above the
								surface, water rebuilt from the ocean datum - so the sculpt is idempotent.
								A fill-only version cannot lower a band, and leaves the old surface behind.
							]]
							local bottom = wy - RES / 2
							local sOcc = math.clamp((h - bottom) / RES, 0, 1)
							local wOcc = math.clamp((WATER_Y - bottom) / RES, 0, 1)
							solid[xi][yi][zi] = sOcc
							liquid[xi][yi][zi] = math.min(wOcc, 1 - sOcc)
							if sOcc > 0 then
								mat[xi][yi][zi] = ((h - wy) <= PAINT_DEPTH) and surfaceMat or SAND
								filled += 1
							else
								mat[xi][yi][zi] = AIR
								carved += 1
							end
						end
					end
				end
			end
		end
	end

	local okw, err = pcall(function()
		Terrain:WriteVoxelChannels(region, RES, {
			SolidMaterial = mat,
			SolidOccupancy = solid,
			LiquidOccupancy = liquid,
		})
	end)
	if not okw then
		return "WriteVoxelChannels FAILED: " .. tostring(err)
	end

	return table.concat({
		("sculpted %s at %s, water datum Y=%d"):format(template.name, tostring(SCULPT), WATER_Y),
		("bounds r<=%.0f, Y %d..%d; guard skips %d"):format(MAX_R, MIN_Y, MAX_Y, guard),
		("wrote %d solid, carved %d to air; %d columns on the landing arc"):format(filled, carved, landingColumns),
		("plateau %d (walked on at %d) -> beach floor %d (%d) | drop to %d (%d) -> shelf %d")
			:format(band.plateau, IslandTemplates.surfaceOf(band.plateau),
				band.beachTop, IslandTemplates.surfaceOf(band.beachTop),
				band.faceBottom, IslandTemplates.surfaceOf(band.faceBottom), band.shelfBottom),
		"",
		'NEXT: set STEP = "verify" and run it as a SEPARATE call.',
	}, "\n")
end

-- ---------------------------------------------------------------------------
-- STEP 2 - verify
-- ---------------------------------------------------------------------------

local function doVerify(): string
	local region = boxAround(SCULPT)
	local ok, data = pcall(function()
		return Terrain:ReadVoxelChannels(region, RES, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	end)
	if not ok then
		return "read failed: " .. tostring(data)
	end
	local mat, solid, liquid = (data :: any).SolidMaterial, (data :: any).SolidOccupancy, (data :: any).LiquidOccupancy
	local base = region.CFrame.Position - region.Size / 2
	local nx, ny, nz = #solid, #solid[1], #solid[1][1]
	local out = {}

	local plateauSurface = IslandTemplates.surfaceOf(band.plateau)
	local heights, mats = {}, {}
	local onArc, offArc, firstOff = 0, 0, nil
	local stranded, dry, floating = 0, 0, 0

	for xi = 1, nx do
		local wx = base.X + (xi - 0.5) * RES
		for zi = 1, nz do
			local wz = base.Z + (zi - 0.5) * RES
			local lx, lz = wx - SCULPT.X, wz - SCULPT.Z
			local s = surfaceOfColumn(solid, xi, zi, base.Y, ny)
			if s then
				-- the plateau, sampled well inside it
				if math.sqrt(lx * lx + lz * lz) <= band.rp * 0.78 then
					local key = ("%.0f"):format(s)
					heights[key] = (heights[key] or 0) + 1
					for yi = ny, 1, -1 do
						if solid[xi][yi][zi] > 0.01 then
							local m = mat[xi][yi][zi].Name
							mats[m] = (mats[m] or 0) + 1
							break
						end
					end
				end
				-- the shelf artifact, split by whether this column is on the landing arc
				if s > WATER_Y and s < WATER_Y + 8 then
					if IslandTemplates.faceRun(template, lx, lz) > 0 then
						onArc += 1
					else
						offArc += 1
						firstOff = firstOff
							or ("surface %.2f at r=%.0f bearing=%.0f"):format(
								s, math.sqrt(lx * lx + lz * lz), math.deg(math.atan2(lx, lz)) % 360)
					end
				end
				-- water above dry land: the pasteEmptyCells=false safety argument
				if s > WATER_Y then
					dry += 1
					for yi = 1, ny do
						if base.Y + (yi - 0.5) * RES > s and liquid[xi][yi][zi] > 0.05 then
							stranded += 1
						end
					end
				end
			end
			for yi = 1, ny do
				if base.Y + (yi - 0.5) * RES > band.plateau and solid[xi][yi][zi] > 0.5 then
					floating += 1
				end
			end
		end
	end

	local hs, ms = {}, {}
	for k, v in pairs(heights) do
		table.insert(hs, ("Y=%s x%d"):format(k, v))
	end
	for k, v in pairs(mats) do
		table.insert(ms, ("%s=%d"):format(k, v))
	end
	table.sort(hs)
	table.sort(ms)

	table.insert(out, ("PLATEAU: %d distinct height(s) -> %s   [want 1, at Y=%d]")
		:format(#hs, table.concat(hs, ", "), plateauSurface))
	table.insert(out, "  surface paint: " .. table.concat(ms, ", "))
	table.insert(out, "")
	table.insert(out, ("SHELF ARTIFACT off the landing arc: %d   [want 0 - by construction, see IslandTemplates]")
		:format(offArc))
	if firstOff then
		table.insert(out, "   first offender: " .. firstOff)
	end
	table.insert(out, ("SHELF ARTIFACT on the landing arc:  %d   [expected: one beach]"):format(onArc))
	table.insert(out, "")
	table.insert(out, ("WATER ABOVE DRY LAND: %d voxels over %d dry columns   [want 0]"):format(stranded, dry))
	table.insert(out, ("FLOATING above the plateau: %d   [want 0]"):format(floating))

	table.insert(out, "")
	table.insert(out, "SHORE PROFILES (surface height across the drop):")
	local function profile(label: string, bearing: number)
		local rows = {}
		local rad = math.rad(bearing)
		for _, r in ipairs({ 120, 126, 130, 134, 138, 142, 146, 150 }) do
			local wx, wz = SCULPT.X + math.sin(rad) * r, SCULPT.Z + math.cos(rad) * r
			local xi = math.floor((wx - base.X) / RES) + 1
			local zi = math.floor((wz - base.Z) / RES) + 1
			local s = (xi >= 1 and xi <= nx and zi >= 1 and zi <= nz)
					and surfaceOfColumn(solid, xi, zi, base.Y, ny)
				or nil
			table.insert(rows, ("r%d=%s"):format(r, s and ("%+.1f"):format(s) or "none"))
		end
		table.insert(out, ("  %-24s %s"):format(label, table.concat(rows, " ")))
	end
	local landing = template.landing
	if landing then
		profile(("bearing %d landing"):format(landing.bearing), landing.bearing)
		profile(("bearing %d cliff"):format((landing.bearing + 180) % 360), (landing.bearing + 180) % 360)
	end
	table.insert(out, "  A cliff steps from about +10 straight to -4, with nothing between.")
	table.insert(out, "")
	table.insert(out, (offArc == 0 and stranded == 0 and floating == 0 and #hs == 1)
			and 'PASSED. NEXT: set STEP = "capture".'
		or "🔴 FAILED - do not capture. Fix the profile first.")
	return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- STEP 3 - capture
-- ---------------------------------------------------------------------------

local function doCapture(): string
	local okc, tr = pcall(function()
		return Terrain:CopyRegion(cellRegion(SCULPT))
	end)
	if not okc then
		return "CopyRegion FAILED: " .. tostring(tr)
	end
	local region = tr :: TerrainRegion

	local store = SS:FindFirstChild("Islands")
	if not store then
		local folder = Instance.new("Folder")
		folder.Name = "Islands"
		folder.Parent = SS
		store = folder
	end
	assert(store, "Islands folder")
	-- rebuilt from scratch, so a re-run cannot leave half of an older template behind
	local old = store:FindFirstChild(TEMPLATE_ID)
	if old then
		old:Destroy()
	end

	local entry = Instance.new("Folder")
	entry.Name = TEMPLATE_ID
	entry.Parent = store
	region.Name = "Terrain"
	region.Parent = entry
	local props = Instance.new("Folder")
	props.Name = "Props" -- authored props would live here; the graybox ones are built at runtime
	props.Parent = entry

	local meta = Instance.new("Configuration")
	meta.Name = "Meta"
	meta.Parent = entry
	meta:SetAttribute("TemplateId", TEMPLATE_ID)
	meta:SetAttribute("HalfCells", halfCells)
	meta:SetAttribute("MinCellY", MIN_CELL_Y)
	meta:SetAttribute("MaxCellY", MAX_CELL_Y)
	meta:SetAttribute("WaterY", WATER_Y)
	meta:SetAttribute("PlateauY", band.plateau)
	meta:SetAttribute("PlateauSurfaceY", IslandTemplates.surfaceOf(band.plateau))
	meta:SetAttribute("SizeInCells", region.SizeInCells)
	meta:SetAttribute("SourceCentre", SCULPT)

	return table.concat({
		("captured -> ServerStorage/Islands/%s/{Terrain, Props, Meta}"):format(TEMPLATE_ID),
		("halfCells %d (%d studs); SizeInCells %s = %d cells")
			:format(halfCells, halfStuds, tostring(region.SizeInCells),
				region.SizeInCells.X * region.SizeInCells.Y * region.SizeInCells.Z),
		"",
		'NEXT: set STEP = "restore" to clear the sculpt site, then SAVE THE PLACE.',
	}, "\n")
end

-- ---------------------------------------------------------------------------
-- STEP 4 - restore
-- ---------------------------------------------------------------------------

--[[
	Restored by COPYING A CLEAN PATCH of ocean over the sculpt, rather than by computing what ocean should
	look like. Same cell grid, and the result matches the surrounding sea by construction instead of by
	arithmetic about seabed depth and water occupancy.
]]
local function doRestore(): string
	local stored = SS:FindFirstChild("Islands")
	stored = stored and stored:FindFirstChild(TEMPLATE_ID)
	local kept = stored and stored:FindFirstChild("Terrain")
	if not kept or not kept:IsA("TerrainRegion") then
		return "ABORT: no captured template in ServerStorage. Clearing the sculpt would lose the only copy."
	end

	local gap = (SCULPT.Z - halfStuds) - (DONOR.Z + halfStuds)
	if gap <= 0 then
		return ("ABORT: donor box overlaps the sculpt box (gap %.0f studs)"):format(gap)
	end

	-- the donor must actually be clean, or this pastes an island onto the sculpt site
	local probe = boxAround(DONOR)
	local okr, data = pcall(function()
		return Terrain:ReadVoxelChannels(probe, RES, { "SolidOccupancy" })
	end)
	if not okr then
		return "donor read failed: " .. tostring(data)
	end
	local occ = (data :: any).SolidOccupancy
	local pbase = probe.CFrame.Position - probe.Size / 2
	local pny = #occ[1]
	local dryColumns = 0
	for xi = 1, #occ do
		for zi = 1, #occ[xi][1] do
			local s = surfaceOfColumn(occ, xi, zi, pbase.Y, pny)
			if s and s > WATER_Y then
				dryColumns += 1
			end
		end
	end
	if dryColumns > 0 then
		return ("ABORT: donor patch at %s has %d dry columns - it is not open ocean")
			:format(tostring(DONOR), dryColumns)
	end

	local okc, patch = pcall(function()
		return Terrain:CopyRegion(cellRegion(DONOR))
	end)
	if not okc then
		return "CopyRegion of the donor FAILED: " .. tostring(patch)
	end
	local okp, err = pcall(function()
		--[[
			`true` here, deliberately unlike the runtime spawner. This paste must be EXACT so the sculpted
			land above the waterline is cleared; overlaying (false) would leave the island behind.
		]]
		Terrain:PasteRegion(patch :: TerrainRegion, cellCorner(SCULPT), true)
	end)
	;(patch :: TerrainRegion):Destroy()
	if not okp then
		return "PasteRegion FAILED: " .. tostring(err)
	end

	return table.concat({
		("restored the sculpt site at %s from clean ocean at %s (%.0f-stud gap between boxes)")
			:format(tostring(SCULPT), tostring(DONOR), gap),
		("template safe: %s cells in ServerStorage/Islands/%s/Terrain")
			:format(tostring((kept :: TerrainRegion).SizeInCells), TEMPLATE_ID),
		"",
		'NEXT: set STEP = "verify-restore", run it, then SAVE THE PLACE.',
	}, "\n")
end

-- ---------------------------------------------------------------------------
-- STEP 5 - verify the restore
-- ---------------------------------------------------------------------------

local function doVerifyRestore(): string
	local region = boxAround(SCULPT)
	local ok, data = pcall(function()
		return Terrain:ReadVoxelChannels(region, RES, { "SolidOccupancy", "LiquidOccupancy" })
	end)
	if not ok then
		return "read failed: " .. tostring(data)
	end
	local solid, liquid = (data :: any).SolidOccupancy, (data :: any).LiquidOccupancy
	local base = region.CFrame.Position - region.Size / 2
	local nx, ny, nz = #solid, #solid[1], #solid[1][1]

	local hist, dryColumns, thinWater = {}, 0, 0
	for xi = 1, nx do
		for zi = 1, nz do
			local s = surfaceOfColumn(solid, xi, zi, base.Y, ny)
			local key = s and ("%.0f"):format(s) or "none"
			hist[key] = (hist[key] or 0) + 1
			if s and s > WATER_Y then
				dryColumns += 1
			end
			for yi = 1, ny do
				if base.Y + (yi - 0.5) * RES == WATER_Y - RES / 2 and liquid[xi][yi][zi] < 0.9 then
					thinWater += 1
				end
			end
		end
	end
	local keys = {}
	for k in pairs(hist) do
		table.insert(keys, k)
	end
	table.sort(keys)

	local out = { ("SCULPT SITE %s after restore - surface histogram over %d columns:")
		:format(tostring(SCULPT), nx * nz) }
	for _, k in ipairs(keys) do
		table.insert(out, ("   %8s : %d"):format(k, hist[k]))
	end
	table.insert(out, ("dry columns remaining: %d   [want 0 - no island left behind]"):format(dryColumns))
	table.insert(out, ("columns without full surface water: %d   [want 0]"):format(thinWater))
	table.insert(out, "")
	table.insert(out, (dryColumns == 0 and thinWater == 0)
			and "PASSED. 🔴 NOW SAVE THE PLACE - the template only persists in the saved file."
		or "🔴 FAILED - the sculpt site is not clean ocean.")
	return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------

if STEP == "sculpt" then
	return doSculpt()
elseif STEP == "verify" then
	return doVerify()
elseif STEP == "capture" then
	return doCapture()
elseif STEP == "restore" then
	return doRestore()
elseif STEP == "verify-restore" then
	return doVerifyRestore()
end
return ('unknown STEP "%s" - use sculpt | verify | capture | restore | verify-restore'):format(STEP)
