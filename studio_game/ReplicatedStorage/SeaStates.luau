--!strict
--[[
	SeaStates - the named moods of the ocean.

	ONE table drives everything about how the sea reads: terrain water properties, fog, ambient, and the
	amplitude/frequency the wave field will later use. Keeping them together is deliberate - if the
	visual swell and the physical swell come from different numbers they drift apart, and the boat
	visibly rides through crests it should be climbing.

	Feature: docs/features/0011-sea-states/
	Manifest: docs/build/01-sea.md
	Palette: docs/game/visual-design.md

	IMPORTANT - Roblox terrain water waves are a RENDERING effect. They do not move objects. The
	`wave` block below is *not* read by the engine; it is the contract for our own wave field
	(HeightAt/NormalAt) so that when the boat arrives it agrees with what the player can see.

	These numbers are a starting point for judging by eye, not final balance.
]]

local SeaStates = {}

export type WaveSpec = {
	amplitude: number, -- studs, crest to trough / 2
	length: number, -- studs between crests
	speed: number, -- studs/second of crest travel
	choppiness: number, -- 0 = rolling swell, 1 = steep and broken
	directionSpread: number, -- 0 = one direction, 1 = confused sea
	--[[
		Heading the waves TRAVEL TOWARD, in degrees. 0 = +Z (north), 90 = +X (east).

		Progress is broadly northward and the storm chases from astern, so the swell runs north too:
		a FOLLOWING sea, arriving from behind. That is what "the storm is pushing us" feels like, and
		it is also the more interesting sea to steer, because following seas make a small vessel yaw.
	]]
	directionDeg: number,
}

export type WaterSpec = {
	color: Color3,
	reflectance: number,
	transparency: number,
	waveSize: number, -- Terrain.WaterWaveSize
	waveSpeed: number, -- Terrain.WaterWaveSpeed
}

export type SkySpec = {
	fogStart: number,
	fogEnd: number,
	fogColor: Color3,
	outdoorAmbient: number, -- multiplier applied to the base ambient, see BASE_AMBIENT
	brightness: number,
}

export type SeaState = {
	id: string,
	name: string,
	description: string,
	water: WaterSpec,
	sky: SkySpec,
	wave: WaveSpec,
	spray: number, -- 0..1 drives whitecap/spray density in the VFX layer
	audioBed: string, -- key into the audio registry (group 12)
}

-- Palette anchors from docs/game/visual-design.md
local ABYSS_NAVY = Color3.fromRGB(11, 30, 45)
local DEEP_OCEAN = Color3.fromRGB(18, 53, 74)
local STORM_TEAL = Color3.fromRGB(30, 90, 110)
local COLD_MIST = Color3.fromRGB(110, 142, 153)
local THUNDER_CLOUD = Color3.fromRGB(42, 49, 59)
local WET_STEEL = Color3.fromRGB(75, 89, 100)
local FOG_GREY = Color3.fromRGB(140, 154, 163)

--[[
	Dead Calm is deliberately the *most* unsettling state, not the safest-feeling one: glass water and a
	long clear horizon in a game built on weather means something is wrong. It is a special-night state
	(docs/systems/day-night) as much as a weather state.
]]
SeaStates.DeadCalm = {
	id = "DeadCalm",
	name = "Dead Calm",
	description = "Glass water, no wind, wrong silence. Long sightlines and nowhere to hide.",
	water = {
		color = DEEP_OCEAN,
		reflectance = 0.65, -- high: a mirror sea is the whole point
		transparency = 0.35,
		waveSize = 0.02,
		waveSpeed = 3,
	},
	sky = {
		fogStart = 200,
		fogEnd = 2900, -- the longest view in the game, but still inside OCEAN_HALF_EXTENT
		fogColor = COLD_MIST,
		outdoorAmbient = 1.0,
		brightness = 2.6,
	},
	wave = { amplitude = 0.15, length = 90, speed = 4, choppiness = 0.0, directionSpread = 0.1, directionDeg = 0 },
	spray = 0.0,
	audioBed = "sea_dead_calm",
} :: SeaState

--[[ The default cruising sea. Everything else is judged relative to this one. ]]
SeaStates.LightSwell = {
	id = "LightSwell",
	name = "Light Swell",
	description = "The working default. A gentle roll, a readable horizon, comfortable to steer.",
	water = {
		color = DEEP_OCEAN,
		reflectance = 0.30,
		transparency = 0.25,
		waveSize = 0.18,
		waveSpeed = 11,
	},
	sky = {
		fogStart = 120,
		fogEnd = 2800,
		fogColor = FOG_GREY,
		outdoorAmbient = 1.0,
		brightness = 3.0,
	},
	wave = { amplitude = 0.8, length = 70, speed = 11, choppiness = 0.2, directionSpread = 0.2, directionDeg = 8 },
	spray = 0.1,
	audioBed = "sea_light_swell",
} :: SeaState

--[[ Working sea. The boat starts to move under the crew; spray begins. ]]
SeaStates.Choppy = {
	id = "Choppy",
	name = "Choppy",
	description = "A working sea. The deck moves, spray starts, the horizon closes in.",
	water = {
		color = STORM_TEAL,
		reflectance = 0.22,
		transparency = 0.18,
		waveSize = 0.45,
		waveSpeed = 16,
	},
	sky = {
		fogStart = 80,
		fogEnd = 1900,
		fogColor = WET_STEEL,
		outdoorAmbient = 0.85,
		brightness = 2.4,
	},
	wave = { amplitude = 2.0, length = 55, speed = 15, choppiness = 0.5, directionSpread = 0.4, directionDeg = 15 },
	spray = 0.35,
	audioBed = "sea_choppy",
} :: SeaState

--[[ Storm proper. Rain, poor visibility, real risk to a small launch. ]]
SeaStates.Storm = {
	id = "Storm",
	name = "Storm",
	description = "Heavy swell, rain, whitecaps. A small launch is in trouble here.",
	water = {
		color = ABYSS_NAVY,
		reflectance = 0.14,
		transparency = 0.10,
		waveSize = 0.85,
		waveSpeed = 22,
	},
	sky = {
		fogStart = 40,
		fogEnd = 900,
		fogColor = THUNDER_CLOUD,
		outdoorAmbient = 0.55,
		brightness = 1.6,
	},
	wave = { amplitude = 4.5, length = 45, speed = 20, choppiness = 0.8, directionSpread = 0.6, directionDeg = 22 },
	spray = 0.75,
	audioBed = "sea_storm",
} :: SeaState

--[[
	The Wall - the interior of the storm front. This is the state that must feel unsurvivable, because
	the whole macro loop depends on the player believing they cannot stay in it (decision 0007).
]]
SeaStates.TheWall = {
	id = "TheWall",
	name = "The Wall",
	description = "Inside the front. Near-zero visibility, violent water, no way to hold position.",
	water = {
		color = ABYSS_NAVY,
		reflectance = 0.08,
		transparency = 0.05,
		waveSize = 1.4,
		waveSpeed = 28,
	},
	sky = {
		fogStart = 10,
		fogEnd = 330, -- you cannot see the bow of a large vessel
		fogColor = Color3.fromRGB(26, 30, 36),
		outdoorAmbient = 0.35,
		brightness = 1.0,
	},
	wave = { amplitude = 7.5, length = 38, speed = 26, choppiness = 1.0, directionSpread = 0.9, directionDeg = 30 },
	spray = 1.0,
	audioBed = "sea_the_wall",
} :: SeaState

-- Weakest to strongest. The storm system (GAME-0003) indexes this by intensity level 0-4.
SeaStates.Order = { "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" }

-- Base ambient the `outdoorAmbient` multiplier scales, from the place settings baseline.
SeaStates.BASE_AMBIENT = Color3.fromRGB(70, 82, 92)

--- The sea surface height. Everything (terrain fill, buoyancy, spawn heights) references this.
SeaStates.WATER_Y = 0

--[[
	Distance from origin to the edge of the filled ocean, in studs. The terrain is a bounded patch, so
	this is the number every fogEnd above must stay under.

	HARD RULE: fogEnd < OCEAN_HALF_EXTENT, always.

	If fog reaches further than the water does, the player sees the ocean simply stop - a flat line of
	nothing at the horizon, which instantly reveals the map as a box. Measured 2026-08-19: terrain water
	ends at exactly x=3072, and a raycast at x=3100 finds nothing. Dead Calm originally asked for
	fogEnd 4200 and was capped to 2900 for precisely this reason.

	Growing the ocean is cheap (36 FillRegion tiles took 0.68s), so if a state needs a longer view,
	enlarge the water first and raise this constant - never just raise fogEnd.
]]
SeaStates.OCEAN_HALF_EXTENT = 3072

--- Every state's fogEnd must be inside the water. Call in a test; cheap enough to call on load.
function SeaStates.validateFogWithinOcean(): (boolean, string)
	local problems = {}
	for _, id in ipairs(SeaStates.Order) do
		local state = (SeaStates :: any)[id] :: SeaState
		if state.sky.fogEnd >= SeaStates.OCEAN_HALF_EXTENT then
			table.insert(problems, ("%s fogEnd=%d >= ocean half-extent %d"):format(
				id, state.sky.fogEnd, SeaStates.OCEAN_HALF_EXTENT))
		end
	end
	if #problems == 0 then
		return true, "all sea states keep fog inside the ocean"
	end
	return false, table.concat(problems, "; ")
end

function SeaStates.get(id: string): SeaState?
	return (SeaStates :: any)[id]
end

--- Linear interpolation between two states, so weather *arrives* instead of snapping.
--- Returns a synthetic state; `id`/`name`/`audioBed` are taken from whichever side is dominant.
function SeaStates.lerp(a: SeaState, b: SeaState, t: number): SeaState
	local function n(x: number, y: number): number
		return x + (y - x) * t
	end
	local function c(x: Color3, y: Color3): Color3
		return x:Lerp(y, t)
	end
	local dominant = if t < 0.5 then a else b
	return {
		id = dominant.id,
		name = dominant.name,
		description = dominant.description,
		water = {
			color = c(a.water.color, b.water.color),
			reflectance = n(a.water.reflectance, b.water.reflectance),
			transparency = n(a.water.transparency, b.water.transparency),
			waveSize = n(a.water.waveSize, b.water.waveSize),
			waveSpeed = n(a.water.waveSpeed, b.water.waveSpeed),
		},
		sky = {
			fogStart = n(a.sky.fogStart, b.sky.fogStart),
			fogEnd = n(a.sky.fogEnd, b.sky.fogEnd),
			fogColor = c(a.sky.fogColor, b.sky.fogColor),
			outdoorAmbient = n(a.sky.outdoorAmbient, b.sky.outdoorAmbient),
			brightness = n(a.sky.brightness, b.sky.brightness),
		},
		wave = {
			amplitude = n(a.wave.amplitude, b.wave.amplitude),
			length = n(a.wave.length, b.wave.length),
			speed = n(a.wave.speed, b.wave.speed),
			choppiness = n(a.wave.choppiness, b.wave.choppiness),
			directionSpread = n(a.wave.directionSpread, b.wave.directionSpread),
			directionDeg = n(a.wave.directionDeg, b.wave.directionDeg),
		},
		spray = n(a.spray, b.spray),
		audioBed = dominant.audioBed,
	} :: SeaState
end

--[[
	Apply a state to the live scene.

	Terrain water properties and Lighting are place-level, so this is a *client-visible* change made from
	wherever it is called. The storm system will own calling this on the server and replicating the
	current state; for now it exists so a state can be judged by eye.
]]
function SeaStates.apply(state: SeaState)
	local Terrain = workspace.Terrain
	Terrain.WaterColor = state.water.color
	Terrain.WaterReflectance = state.water.reflectance
	Terrain.WaterTransparency = state.water.transparency
	Terrain.WaterWaveSize = state.water.waveSize
	Terrain.WaterWaveSpeed = state.water.waveSpeed

	local Lighting = game:GetService("Lighting")
	Lighting.FogStart = state.sky.fogStart
	Lighting.FogEnd = state.sky.fogEnd
	Lighting.FogColor = state.sky.fogColor
	Lighting.Brightness = state.sky.brightness

	local a = SeaStates.BASE_AMBIENT
	local m = state.sky.outdoorAmbient
	Lighting.OutdoorAmbient = Color3.new(
		math.clamp(a.R * m, 0, 1),
		math.clamp(a.G * m, 0, 1),
		math.clamp(a.B * m, 0, 1)
	)
end

return SeaStates
