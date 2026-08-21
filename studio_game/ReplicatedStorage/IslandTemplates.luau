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
	THE PROFILE, AND THE ONE RULE IT EXISTS TO OBEY

	    r <= rp          flat plateau
	    rp < r <= rb     upper beach, gentle
	    rb < r <= rf     THE STEEP FACE, crossing the waterline in roughly one voxel
	    rf < r <= ro     underwater shelf
	    r > ro           untouched

	🔴 The steep face is not a style choice. Land whose surface sits between the water level and about
	WATER_Y + 8 renders as thin hole-riddled sheets - the shelf artifact - and a gentle beach ramp through the
	waterline produces it along its entire length. Job 024 measured the floor: 240 offending columns around a
	400-column shoreline ring, which is what "as good as it gets" looks like.

	Noise is applied to the band RADII, never to the heights. The outline then wanders while the plateau stays
	provably flat - which matters because things get placed on it.

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

export type Band = {
	plateau: number,
	rp: number, -- plateau radius
	rb: number, -- upper beach outer radius
	rf: number, -- foot of the steep face
	ro: number, -- outer edge of the underwater shelf
	beachTop: number, -- height at rb
	faceBottom: number, -- height at rf
	shelfBottom: number, -- height at ro
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
		rf = 138, -- 8 studs of run for 14 studs of drop: a ~60 degree sand slope. Steep, and still walkable
		ro = 175,
		beachTop = 8, -- the top of the forbidden band; the face starts here and dives
		faceBottom = -6,
		shelfBottom = -22,
	},
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

		-- BEACH: where a boat comes in. Just inside the waterline on the lee side.
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

--[[
	Surface height at a local XZ offset from the island's centre, or nil for "do not touch this column".

	Local coordinates on purpose: the same function serves the authoring sculpt and any later analysis without
	either needing to know where in the world the island ended up.
]]
function IslandTemplates.heightAt(template: Template, x: number, z: number): number?
	local b = template.band
	local r = math.sqrt(x * x + z * z)
	local n = IslandTemplates.radiusNoise(template, math.atan2(z, x))
	local rp, rb, rf, ro = b.rp * n, b.rb * n, b.rf * n, b.ro * n
	if r <= rp then
		return b.plateau
	elseif r <= rb then
		return b.plateau + smoothstep((r - rp) / (rb - rp)) * (b.beachTop - b.plateau)
	elseif r <= rf then
		-- LINEAR here, not smoothed: the point is to cross the waterline fast
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

--- How wide a region the island needs, including margin. Used for both the capture and the paste.
function IslandTemplates.footprint(template: Template): number
	return template.band.ro + 20
end

return IslandTemplates
