--!strict
--[[
	IslandTemplates - what an island IS, as data. No instances, no terrain writes.

	Feature: GAME-0005  ·  decisions 0003, 0016, 0024  ·  job 027

	--------------------------------------------------------------------------------------------------
	WHY THIS IS DATA AND NOT A SCRIPT PER ISLAND

	Group 04's instruction is that its first job "proves it with one island before any others are built". The
	way that promise gets kept is for island number two to be a **table entry** rather than a new script - so
	the profile, the paint rules and the marker layout all live here, and both the authoring tool and the
	runtime spawner read the same description.

	--------------------------------------------------------------------------------------------------
	THE PROFILE

	    r <= rp          flat plateau
	    rp < r <= rb     upper beach, gentle, bottoming out at `beachTop`
	    r > rb           THE DROP - a cliff everywhere except the landing arc
	    ... <= ro        underwater shelf, down to `shelfBottom`
	    r > ro           untouched

	Noise is applied to the band RADII, never to the heights. The outline then wanders while the plateau stays
	provably flat - which matters because things get placed on it.

	--------------------------------------------------------------------------------------------------
	🔴 THE SHELF ARTIFACT, AND HOW THIS PROFILE AVOIDS IT BY CONSTRUCTION

	Land whose surface sits between the water level and about WATER_Y + 8 renders as thin hole-riddled
	sheets. Job 024 measured the floor for a gentle shore: 240 offending columns around a 400-column
	shoreline. Job 027's first sculpt measured 335, clearly visible as flat sheets lying on the sea.

	A gentle ramp CANNOT avoid it: to get from +10 to -4 continuously you must pass through the band, and
	whatever column lands in there is a sheet. Making the ramp steeper only reduces the count.

	So the drop is a DISCONTINUITY instead. Outside the landing arc, `heightAt` jumps straight from
	`beachTop` to `faceBottom` with nothing in between, so no column's surface can land in the forbidden
	band - not "rarely", but never. The renderer bridges the two adjacent columns with a ~74 degree face,
	which is still walkable (a Humanoid's default `MaxSlopeAngle` is 89).

	⚠️ The cost is that the coastline is a low bluff rather than a beach, so ONE landing arc keeps a real
	sandy shore - see `Landing`. That arc is the only place the artifact is accepted, it is small, and it is
	exactly where the dock and jetty art will sit.

	--------------------------------------------------------------------------------------------------
	🔴 SMOOTH TERRAIN'S SURFACE SITS RES/2 ABOVE THE HEIGHT YOU ASK FOR

	Measured in job 027 across 73 columns: the collision surface of a column is

	    topmost non-empty voxel centre + occupancy * 4        (mean absolute error 0.087 studs)

	which for a sculpt target `h` simplifies to **`h + 2`**. The `roblox-terrain` skill's rule of
	"centre + RES/2" is off by up to 2 studs (mean error 1.657 studs on the same data).

	So a plateau declared at 16 is WALKED ON AT 18, and every height in this file is a sculpt target rather
	than a stand-on height. `IslandTemplates.surfaceOf` converts. Anything comparing a raycast against a band
	height must convert first, or it is silently wrong by 2.

	--------------------------------------------------------------------------------------------------
	VOXEL ALIGNMENT: THE PLATEAU HEIGHT MUST BE A MULTIPLE OF 4

	The first sculpt used 14 and produced a plateau whose top voxel was **half full** - occupancy 0.498,
	spanning 12..16. That is a soft lid, not a floor: the isosurface runs through the middle of the voxel, and
	the full sand voxel underneath shows through the thin grass above it.

	16 puts the surface exactly on a voxel boundary, so the top voxel is solid 1.0 and the one above is empty.
	The plateau is then flat by construction rather than flat on average - which is what the markers need,
	because things get placed on it.

	--------------------------------------------------------------------------------------------------
	PAINT BY THE COLUMN'S SURFACE HEIGHT, NOT BY THE VOXEL'S OWN HEIGHT

	The same first sculpt came out 707 sand to 101 grass on a plateau that should be green. Materials were
	chosen per voxel from its own centre height, so on a plateau at 14 the topmost mostly-solid voxel sits at
	centre 10 - below the grass line - and got painted sand. Only the half-full lid above it went green.

	So `grassLine` is a threshold on the SURFACE of the column, and the surface material is then applied to
	the top few studs beneath it. Depth-below-surface decides how deep the paint goes; height decides which
	paint it is.

	--------------------------------------------------------------------------------------------------
	⚠️ DO NOT GROW AN ISLAND TO PAD DWELL TIME

	Decision 0024 wants 5-6 minutes on a deep island. A lap of this one's beach is 817 studs - **51 seconds**
	at walk speed. The minutes come from CONTENT: the manifest's own template has five loot points, a hidden
	cache under the rise, and three or four enemies. Acreage would just be walking.
]]

local IslandTemplates = {}

local RES = 4 -- the terrain voxel size, which the surface rule above depends on

export type Band = {
	plateau: number,
	rp: number, -- plateau radius
	rb: number, -- upper beach outer radius; the drop starts here
	ro: number, -- outer edge of the underwater shelf
	beachTop: number, -- the LOWEST DRY height. Must stay clear of the forbidden band
	faceBottom: number, -- the height the drop lands at, below the forbidden band
	shelfBottom: number, -- height at ro
}

--[[
	The one arc with a real beach: a walkable ramp through the waterline, so a crew that ends up in the water
	can get ashore, and so the island has somewhere that looks like a landing.

	`run` is how many studs the drop is spread over at the centre of the arc, tapering to a cliff at its
	edges. Keep `rb + run` comfortably inside `ro`, or the beach would run out past the shelf.
]]
export type Landing = {
	bearing: number, -- degrees, 0 = +Z. Matched to the Dock marker
	halfWidth: number, -- degrees either side
	run: number, -- studs of horizontal run at the centre of the arc
}

export type MarkerKind = "dock" | "loot" | "spawn" | "poi" | "prop"

--[[
	Markers are POLAR - a fraction of the plateau/beach radius plus a bearing - so a bigger or smaller
	template places them proportionally instead of needing every offset rewritten.

	`ground = true` means "drop me onto whatever terrain is actually there", which is every marker except the
	offshore ones. Decision 0016's consequence: probe for ground, never assume.
]]
export type Marker = {
	name: string,
	kind: MarkerKind,
	radiusFraction: number, -- of `ro`
	bearing: number, -- degrees, 0 = +Z
	ground: boolean,
	lift: number?, -- studs above the surface, for things that sit rather than sink
	note: string?,
}

export type Template = {
	id: string,
	name: string,
	band: Band,
	landing: Landing?,
	noise: { { amplitude: number, harmonic: number, phase: number } },
	grassLine: number, -- height above which the paint turns green
	markers: { Marker },
}

--[[
	THE SMALLEST TEMPLATE, from the manifest's own zone breakdown: beach, wreck corner, camp, rise, reef.

	350 studs across. Sized as the manifest specifies rather than as the dwell time might tempt - see the
	header.
]]
local CAY: Template = {
	id = "Cay",
	name = "Small Cay",
	band = {
		plateau = 16, -- a MULTIPLE OF 4, deliberately - see 'voxel alignment' above
		rp = 90,
		rb = 130,
		ro = 175,
		--[[
			🔴 THE GAP BETWEEN THESE TWO IS THE POINT.

			`beachTop` is the lowest dry land, `faceBottom` the highest wet land, and NOTHING is generated
			between them. Their surfaces land at +10 and -4 once the RES/2 rule is applied, straddling the
			0..+8 forbidden band without ever entering it.

			Narrow this gap and the artifact comes back.
		]]
		beachTop = 8,
		faceBottom = -6,
		shelfBottom = -22,
	},
	--[[
		The landing faces the same way as the Dock marker (bearing 200) - a beach and a mooring in different
		places would be silly. 26 degrees either side is ~118 studs of shoreline: a beach you can see across,
		rather than a notch.
	]]
	landing = { bearing = 200, halfWidth = 26, run = 16 },
	--[[
		Three harmonics on the radii. Deterministic, so the same template sculpts identically every time -
		which matters because the markers below are placed against the shape it produces.
	]]
	noise = {
		{ amplitude = 0.07, harmonic = 3, phase = 1.1 },
		{ amplitude = 0.05, harmonic = 5, phase = 2.7 },
		{ amplitude = 0.03, harmonic = 7, phase = 0.4 },
	},
	grassLine = 11, -- compared against the COLUMN'S SURFACE, never a voxel's own height
	--[[
		The manifest's five zones, turned into anchors. Nothing here places loot or enemies - groups 03 and 05
		do that - but they need somewhere agreed to attach to, and deciding those spots now is what stops two
		later jobs inventing two different conventions.
	]]
	markers = {
		-- the POI anchor: dead centre, and what the radar tags as a `land` contact
		{ name = "POI", kind = "poi", radiusFraction = 0, bearing = 0, ground = true, lift = 6,
			note = "radar contact anchor" },

		-- BEACH: where a boat comes in. On the landing arc, which is what makes it reachable on foot.
		{ name = "Dock", kind = "dock", radiusFraction = 0.79, bearing = 200, ground = false,
			note = "moor here; sits at the waterline, not on land" },

		-- WRECK CORNER
		{ name = "Wreck", kind = "prop", radiusFraction = 0.66, bearing = 55, ground = true,
			note = "derelict rowboat, hull fragment, torn tarp" },
		{ name = "LootWreckBarrel", kind = "loot", radiusFraction = 0.63, bearing = 62, ground = true, lift = 1,
			note = "FUEL - the reason to stop (manifest)" },
		{ name = "LootRowboat", kind = "loot", radiusFraction = 0.68, bearing = 50, ground = true, lift = 1,
			note = "repair materials, occasionally an Engine Part" },

		-- CAMP
		{ name = "Camp", kind = "prop", radiusFraction = 0.34, bearing = 300, ground = true,
			note = "tent, dead campfire, drying rack, rope coil, lantern" },
		{ name = "LootCrateA", kind = "loot", radiusFraction = 0.31, bearing = 293, ground = true, lift = 1,
			note = "scrap, food, sometimes ammo" },
		{ name = "LootCrateB", kind = "loot", radiusFraction = 0.36, bearing = 307, ground = true, lift = 1,
			note = "scrap, food, sometimes ammo" },

		-- RISE, and the cache that rewards actually exploring
		{ name = "Rise", kind = "prop", radiusFraction = 0.2, bearing = 130, ground = true,
			note = "scrub, dead tree, boulder, weathered unreadable sign" },
		{ name = "LootCache", kind = "loot", radiusFraction = 0.16, bearing = 138, ground = true,
			note = "HIDDEN. Rare-ish: Hull Part or Electronic Part" },

		-- REEF, offshore
		{ name = "Reef", kind = "prop", radiusFraction = 0.92, bearing = 15, ground = false,
			note = "coral outcrop, crab pot" },
		{ name = "LootCrabPot", kind = "loot", radiusFraction = 0.9, bearing = 20, ground = false,
			note = "food, minor" },

		-- enemy spawns: beach and reef, per the manifest
		{ name = "SpawnBeachA", kind = "spawn", radiusFraction = 0.74, bearing = 240, ground = true,
			note = "giant crab" },
		{ name = "SpawnBeachB", kind = "spawn", radiusFraction = 0.72, bearing = 340, ground = true,
			note = "giant crab" },
		{ name = "SpawnReef", kind = "spawn", radiusFraction = 0.95, bearing = 100, ground = false,
			note = "shark - punishes swimming rather than landing" },
	},
}

IslandTemplates.Templates = { Cay = CAY }

function IslandTemplates.get(id: string): Template?
	return (IslandTemplates.Templates :: any)[id]
end

--[[
	The height a character actually stands at, given a sculpt target. See the header - this is a MEASURED
	relationship, not a guess, and forgetting it is a silent 2-stud error in every comparison.
]]
function IslandTemplates.surfaceOf(targetHeight: number): number
	return targetHeight + RES / 2
end

--- The radius multiplier at a bearing. Applied to every band equally, so their order can never invert.
function IslandTemplates.radiusNoise(template: Template, theta: number): number
	local n = 1
	for _, term in ipairs(template.noise) do
		n += term.amplitude * math.sin(theta * term.harmonic + term.phase)
	end
	return n
end

local function smoothstep(u: number): number
	return u * u * (3 - 2 * u)
end

--- Compass bearing of a local offset, 0 = +Z, matching `Marker.bearing`.
local function bearingOf(x: number, z: number): number
	return math.deg(math.atan2(x, z)) % 360
end

--- Shortest angle between two bearings, 0..180.
local function angleBetween(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

--[[
	How many studs the drop is spread over at this bearing. 0 means a cliff, which is the default and the
	whole reason the shelf artifact does not appear - see the header.
]]
function IslandTemplates.faceRun(template: Template, x: number, z: number): number
	local l = template.landing
	if not l or l.halfWidth <= 0 then
		return 0
	end
	local d = angleBetween(bearingOf(x, z), l.bearing)
	if d >= l.halfWidth then
		return 0
	end
	return l.run * smoothstep(1 - d / l.halfWidth)
end

--[[
	Sculpt target height at a local XZ offset from the island's centre, or nil for "do not touch this column".

	Local coordinates on purpose: the same function serves the authoring sculpt and any later analysis without
	either needing to know where in the world the island ended up.

	⚠️ Returns a SCULPT TARGET. Characters stand at `surfaceOf(that)`.
]]
function IslandTemplates.heightAt(template: Template, x: number, z: number): number?
	local b = template.band
	local r = math.sqrt(x * x + z * z)
	local n = IslandTemplates.radiusNoise(template, math.atan2(z, x))
	local rp, rb, ro = b.rp * n, b.rb * n, b.ro * n
	local rf = rb + IslandTemplates.faceRun(template, x, z) * n -- == rb off the landing arc, i.e. a cliff

	if r <= rp then
		return b.plateau
	elseif r <= rb then
		return b.plateau + smoothstep((r - rp) / (rb - rp)) * (b.beachTop - b.plateau)
	elseif r <= rf then
		-- the landing beach: the ONE place a surface is allowed through the forbidden band
		return b.beachTop + ((r - rb) / (rf - rb)) * (b.faceBottom - b.beachTop)
	elseif r <= ro then
		return b.faceBottom + smoothstep((r - rf) / (ro - rf)) * (b.shelfBottom - b.faceBottom)
	end
	return nil
end

--- Local XZ of a marker, from its polar description.
function IslandTemplates.markerOffset(template: Template, marker: Marker): Vector2
	local rad = math.rad(marker.bearing)
	local r = template.band.ro * marker.radiusFraction
	return Vector2.new(math.sin(rad) * r, math.cos(rad) * r)
end

--[[
	How wide a region the island needs, including margin. Used for both the CAPTURE and the PASTE, which is
	why it has to be an over-estimate rather than a nice round number.

	🔴 It must account for the radius NOISE. This returned `ro + 20` = 195 at first, while the noise can swell
	the outline to `ro * 1.15` = 201 - so the outermost ring of the shelf fell outside the box on the four axis
	directions and would have been clipped out of the captured template, leaving a one-cell step underwater.

	Summing the amplitudes gives the worst case the harmonics can reach together.
]]
function IslandTemplates.footprint(template: Template): number
	local swell = 1
	for _, term in ipairs(template.noise) do
		swell += math.abs(term.amplitude)
	end
	return template.band.ro * swell + 8
end

return IslandTemplates
