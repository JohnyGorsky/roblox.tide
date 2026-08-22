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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

--[[
	Atmosphere is the DOMINANT lever on how the sea reads.

	Job 007 tried four ways to recolour the ocean through water properties and fog and all four failed;
	the sky and the air win. So every state carries its own air, not just its own water. Without this
	block, switching state changed the water and the fog while the atmosphere stayed put - which made the
	five states look far more alike than they are.

	Measured landmark from that job: haze above about 2 flattens ALL wave detail. Storm and The Wall sit
	at 2.0 deliberately, not higher.
]]
export type AtmosphereSpec = {
	density: number,
	offset: number,
	haze: number,
	glare: number,
	color: Color3,
	decay: Color3,
}

--[[
	THE GRADE: everything about the FINAL IMAGE rather than the world.

	This block is why the ladder reads as a journey instead of five unrelated looks. Job 028's direction is
	that a normal day is warm and sunny and the storm takes that away - so warmth, saturation and light all
	drain together as severity climbs, and the front's approach becomes legible on the water itself.

	🔴 Why each of these exists, because five of them were dead before this job:
	  * `saturation`/`contrast`/`tint` - there was NO ColorCorrectionEffect in the place at all, so nothing
	    could grade the image. This is the cheapest depth lever in Roblox and we had none of it.
	  * `bloomThreshold` - Bloom sat at 2.6 against a sea of 3.2% luminance, so nothing ever bloomed. The
	    threshold has to sit under the brightest thing on screen or the effect is decorative.
	  * `sunRays` - SunRaysEffect was Enabled with Intensity 0. Enabled and doing nothing.
	  * `shiftTop`/`shiftBottom` - `ColorShift_Top` is the colour of the light from above. Warming it is
	    what makes sunlight look like sunlight; a global tint alone just washes the whole frame.
]]
export type GradeSpec = {
	saturation: number, -- ColorCorrectionEffect.Saturation, -1..1
	contrast: number, -- ColorCorrectionEffect.Contrast
	brightness: number, -- ColorCorrectionEffect.Brightness, small trims only
	tint: Color3, -- ColorCorrectionEffect.TintColor
	bloomIntensity: number,
	bloomThreshold: number, -- keep BELOW the brightest thing on screen or bloom does nothing
	sunRays: number, -- SunRaysEffect.Intensity. Only meaningful when the sky has a sun disc
	--[[
		Sky.SunAngularSize, and it lives on the STATE rather than on the sky on purpose.

		A skybox cannot be cross-faded - six ContentIds, no blend - so it snaps at the halfway point. If the
		sun disc were a property of the sky it would snap with it, and the plan's requirement is that the sun
		FADES OUT across Choppy. Here it rides `lerp` like everything else, so the disc has already shrunk to
		nothing by the time the skybox actually changes.
	]]
	sunSize: number,
	--[[
		🔴 Lighting.ExposureCompensation - the lever that actually rescued the storm.

		`Brightness` is only the SUN, so in a sunless overcast it does almost nothing: Storm went black and
		survived three rounds of raising brightness, ambient, reflectance and water colour. An isolation test
		ruled the clouds out too (cover 0.78 -> 0.20 changed the sea not at all).

		This is a stop-for-stop exposure control on the WHOLE frame, and it is what gives a dark scene tonal
		range instead of crushing it. It was sitting at -0.05 globally, driven by nothing.

		Keep it near 0 for the fair states - they are already correctly exposed - and push it up as the light
		goes away. The Wall stays low ON PURPOSE: being unable to see is its mechanic.
	]]
	exposure: number,
	shiftTop: Color3, -- Lighting.ColorShift_Top: the colour of the sun
	shiftBottom: Color3, -- Lighting.ColorShift_Bottom: the colour of the bounce
}

--[[
	Terrain.Clouds - DYNAMIC clouds, and they were already in the place at Cover 0.15, i.e. invisible.

	These are not the skybox. The skybox clouds are painted on and never move; these are volumetric, they
	drift, and they are the biggest sky win available to an ocean game. Driving Cover from the state is what
	makes the sky thicken as the storm closes.
]]
export type CloudSpec = {
	cover: number, -- 0..1
	density: number, -- 0..1
	color: Color3,
}

export type SeaState = {
	id: string,
	name: string,
	description: string,
	water: WaterSpec,
	sky: SkySpec,
	--[[
		Which sky from SkyLibrary. This is the last piece of the colour problem: job 007 proved the sky
		dominates how the sea reads and that no amount of fog or atmosphere can overcast a clear-day sky,
		so a state that does not name its own sky can never fully change the sea's mood.
	]]
	skyId: string,
	--[[
		How hard this weather overrides the time of day, 0..1. See decision 0018.

		This is NOT decoration - it is the blend weight. At 0 the time of day wins entirely, so a calm
		night reads as night. At 1 the time contributes nothing, which is why The Wall looks identical at
		noon and midnight: inside the front there is no sun, no stars and no horizon to tell the hour by.
		That falls out of the arithmetic rather than needing a special case.
	]]
	severity: number,
	atmosphere: AtmosphereSpec,
	grade: GradeSpec,
	clouds: CloudSpec,
	wave: WaveSpec,
	spray: number, -- 0..1 drives whitecap/spray density in the VFX layer
	audioBed: string, -- key into the audio registry (group 12)
}

-- Palette anchors from docs/game/visual-design.md
--[[
	The ocean ramp must get DARKER as the sea worsens. Measured luminance, so this is not a matter of
	taste: Abyss Navy 0.106, Deep Ocean 0.185, Storm Teal 0.309.

	Storm Teal is the LIGHTEST of the three despite its name - it belongs to shallow, sheltered water
	(it is what the harbour uses), not to a worsening sea. Assigning it to Choppy made the ramp read
	0.185 -> 0.185 -> 0.309 -> 0.106, so the sea visibly brightened just as it turned nasty. Caught by
	screenshot, then confirmed by computing the luminances.
]]
local ABYSS_NAVY = Color3.fromRGB(20, 48, 64) -- lifted in job 028 so waves still read under storm cloud
-- Kept as palette anchors from visual-design.md though nothing references them now: Deep Ocean was the
-- old start of the ramp (job 028 replaced it with lit water), and Storm Teal belongs to sheltered water.
local _DEEP_OCEAN = Color3.fromRGB(18, 53, 74) -- luminance 0.185
local _STORM_TEAL = Color3.fromRGB(30, 90, 110) -- luminance 0.309 - SHALLOW water, not rough water
local CHOP_BLUE = Color3.fromRGB(24, 66, 88) -- lifted twice in job 028; 15,42,58 left a cliff in the ramp
local WALL_BLACK = Color3.fromRGB(8, 20, 30) -- darker than Abyss Navy; the sea at its worst
local COLD_MIST = Color3.fromRGB(110, 142, 153)
local THUNDER_CLOUD = Color3.fromRGB(42, 49, 59)
local WET_STEEL = Color3.fromRGB(75, 89, 100)
local FOG_GREY = Color3.fromRGB(140, 154, 163)

--[[
	SUNLIT water, added in job 028. The old ramp started at Deep Ocean (18,53,74) for BOTH calm states -
	3.2% linear luminance, which is near-black. A sunny day cannot be built on near-black water.

	The ramp still DARKENS monotonically as the sea worsens, which is the rule job 007 established; it just
	starts much higher now. Luminances: 12.1% -> 9.4% -> 2.6% -> 1.5% -> 1.0%.
]]
local SUNLIT_MIRROR = Color3.fromRGB(34, 104, 128) -- Dead Calm: glass under a blazing sun
local WORKING_BLUE = Color3.fromRGB(26, 88, 116) -- Light Swell: the good day

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
		color = SUNLIT_MIRROR,
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
		brightness = 2.4, -- still the hottest state: the doldrums are SUPPOSED to glare
	},
	atmosphere = {
		--[[
			🔴 `offset` is the SILHOUETTE control. Roblox's docs: "Lower values blend distant objects
			seamlessly into the skybox; higher values create horizon silhouettes." It was 0.25 on the
			CLEAREST day, which is why distant land dissolved instead of reading as a pale shape.

			`glare` matters twice over: it draws the sun's glare AND it is the gate on `decay` - the
			away-from-sun hue does not render at all while glare is 0. At 0.05 the sky was a single flat
			wash with no directional falloff.
		]]
		density = 0.22, offset = 0.55, haze = 1.2, glare = 0.45,
		color = Color3.fromRGB(245, 232, 205), -- warm, hazy glare: the doldrums, oppressive by HEAT
		decay = Color3.fromRGB(150, 178, 200), -- cool blue away from the sun
	},
	severity = 0.00, -- time wins entirely
	skyId = "SunlessBlue", -- clear blue with a big blazing sun: the doldrums
	wave = { amplitude = 0.15, length = 90, speed = 4, choppiness = 0.0, directionSpread = 0.1, directionDeg = 0 },
	spray = 0.0,
	--[[ THE DOLDRUMS. Blazing, hazy, windless. Oppressive by heat and stillness, not by cold - which is
		what keeps it from rhyming with The Wall at the other end of the ladder. ]]
	grade = {
		saturation = 0.12, contrast = 0.06, brightness = 0.02,
		tint = Color3.fromRGB(255, 246, 230),
		bloomIntensity = 1.15, bloomThreshold = 1.15, sunRays = 0.22, sunSize = 21, exposure = -0.05,
		shiftTop = Color3.fromRGB(255, 238, 205), shiftBottom = Color3.fromRGB(150, 170, 190),
	},
	clouds = { cover = 0.08, density = 0.26, color = Color3.fromRGB(245, 242, 236) },
	audioBed = "sea_dead_calm",
} :: SeaState

--[[ The default cruising sea. Everything else is judged relative to this one. ]]
SeaStates.LightSwell = {
	id = "LightSwell",
	name = "Light Swell",
	description = "The working default. A gentle roll, a readable horizon, comfortable to steer.",
	water = {
		color = WORKING_BLUE,
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
		-- 3.0 clipped the start island's sand to pure white once job 028 added warm ColorShift and
		-- contrast on top. The grade multiplies what this sets; it does not replace it.
		brightness = 2.5,
	},
	atmosphere = {
		density = 0.30, offset = 0.50, haze = 1.0, glare = 0.35,
		color = Color3.fromRGB(232, 226, 210), -- warm pale: a good working day
		decay = Color3.fromRGB(128, 156, 180),
	},
	severity = 0.15, -- barely tints the hour
	--[[
		Changed in job 028 from SnowGrey. "Warm and sunny" cannot be built on a flat grey overcast, and
		SkyLibrary's own note warns that a sharp sun disc punched through an overcast reads as broken.

		So the two fair states SHARE the clear blue sky and are told apart by cloud cover (0.08 vs 0.22),
		grade and sun size - which is also what stops the DeadCalm -> LightSwell transition snapping, since
		there is no skybox change between them at all.
	]]
	skyId = "SunlessBlue", -- legacy id; it is the clear blue sky WITH a sun now
	wave = { amplitude = 0.8, length = 70, speed = 11, choppiness = 0.2, directionSpread = 0.2, directionDeg = 8 },
	spray = 0.1,
	-- THE GOOD DAY. This is the state the player should miss once it is gone.
	grade = {
		saturation = 0.07, contrast = 0.04, brightness = 0.0,
		tint = Color3.fromRGB(252, 248, 238),
		bloomIntensity = 1.0, bloomThreshold = 1.4, sunRays = 0.16, sunSize = 17, exposure = 0.0,
		shiftTop = Color3.fromRGB(255, 244, 222), shiftBottom = Color3.fromRGB(140, 162, 184),
	},
	clouds = { cover = 0.22, density = 0.32, color = Color3.fromRGB(238, 240, 242) },
	audioBed = "sea_light_swell",
} :: SeaState

--[[ Working sea. The boat starts to move under the crew; spray begins. ]]
SeaStates.Choppy = {
	id = "Choppy",
	name = "Choppy",
	description = "A working sea. The deck moves, spray starts, the horizon closes in.",
	water = {
		color = CHOP_BLUE, -- NOT Storm Teal: see the ramp note above
		reflectance = 0.22,
		transparency = 0.18,
		waveSize = 0.45,
		waveSpeed = 16,
	},
	sky = {
		fogStart = 80,
		fogEnd = 1900,
		fogColor = WET_STEEL,
		outdoorAmbient = 0.90,
		brightness = 2.6, -- raised with Storm's: cover-0.55 cloud eats light the old numbers never accounted for
	},
	atmosphere = {
		density = 0.42, offset = 0.38, haze = 1.4, glare = 0.18,
		color = Color3.fromRGB(168, 178, 186), -- the warmth is draining out
		decay = Color3.fromRGB(86, 100, 114),
	},
	severity = 0.45, -- weather tints heavily
	skyId = "FogOnWater", -- weather closing in
	wave = { amplitude = 2.0, length = 55, speed = 15, choppiness = 0.5, directionSpread = 0.4, directionDeg = 15 },
	spray = 0.35,
	-- THE TURN. Warmth draining, sun going hazy behind thickening cloud. The sun disc fades out ACROSS
	-- this state, so the sky swap lands where cloud already hides it rather than popping.
	grade = {
		saturation = -0.10, contrast = 0.05, brightness = -0.01,
		tint = Color3.fromRGB(240, 244, 248),
		bloomIntensity = 0.7, bloomThreshold = 1.35, sunRays = 0.06, sunSize = 7, exposure = 0.25,
		shiftTop = Color3.fromRGB(222, 228, 232), shiftBottom = Color3.fromRGB(96, 112, 126),
	},
	clouds = { cover = 0.55, density = 0.44, color = Color3.fromRGB(186, 192, 199) },
	audioBed = "sea_choppy",
} :: SeaState

--[[ Storm proper. Rain, poor visibility, real risk to a small launch. ]]
SeaStates.Storm = {
	id = "Storm",
	name = "Storm",
	description = "Heavy swell, rain, whitecaps. A small launch is in trouble here.",
	water = {
		color = ABYSS_NAVY,
		reflectance = 0.20, -- picks up enough sky for the surface to read as water rather than as a void
		transparency = 0.10,
		waveSize = 0.85,
		waveSpeed = 22,
	},
	sky = {
		fogStart = 40,
		fogEnd = 900,
		fogColor = THUNDER_CLOUD,
		--[[
			🔴 AMBIENT CARRIES AN OVERCAST, NOT BRIGHTNESS - and this is physics, not a workaround.

			`Brightness` is the SUN. Storm has no sun disc, so raising it did almost nothing: the state went
			black and three rounds of raising brightness, reflectance and water colour barely moved it. An
			isolation test settled it - dropping cloud cover from 0.78 to 0.20 changed the sea not at all,
			so the clouds were not eating the light either.

			A real overcast is the opposite of a clear day: light arrives from the WHOLE SKY as diffuse
			ambient and almost none of it is directional. So ambient goes UP past Dead Calm's 1.0 while
			brightness comes DOWN. That reads as flat, sunless, heavy - which is exactly the brief.

			Storm must stay DARK AND LEGIBLE. Being unable to see the water is The Wall's job, not Storm's.
		]]
		outdoorAmbient = 1.35,
		brightness = 1.8,
	},
	atmosphere = {
		-- haze at the 2.0 ceiling, not past it (job 007: above ~2 flattens all wave detail).
		-- glare stays just above 0 so `decay` still renders and the sky keeps some falloff.
		density = 0.62, offset = 0.22, haze = 2.0, glare = 0.06,
		color = Color3.fromRGB(86, 96, 105),
		decay = Color3.fromRGB(30, 36, 44),
	},
	severity = 0.80, -- weather nearly wins
	skyId = "AngryHeavens", -- dark storm cloud
	wave = { amplitude = 4.5, length = 45, speed = 20, choppiness = 0.8, directionSpread = 0.6, directionDeg = 22 },
	spray = 0.75,
	-- COLD. No sun at all from here on.
	grade = {
		-- contrast stays low: +0.10 crushed the blacks into one flat mass with the waves invisible inside it
		saturation = -0.28, contrast = 0.04, brightness = 0.02,
		tint = Color3.fromRGB(224, 234, 244),
		bloomIntensity = 0.35, bloomThreshold = 1.8, sunRays = 0.0, sunSize = 0, exposure = 0.85,
		shiftTop = Color3.fromRGB(150, 162, 175), shiftBottom = Color3.fromRGB(58, 70, 80),
	},
	clouds = { cover = 0.78, density = 0.52, color = Color3.fromRGB(118, 124, 132) },
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
		color = WALL_BLACK,
		reflectance = 0.08,
		transparency = 0.05,
		-- Terrain.WaterWaveSize is CAPPED AT 1.0 by the engine. This asked for 1.4 and silently got 1.0,
		-- verified by read-back. So 1.0 is the roughest the RENDER can look; extra violence in The Wall
		-- has to come from the wave field, spray and camera shake, not from this dial.
		waveSize = 1.0,
		waveSpeed = 28,
	},
	sky = {
		fogStart = 10,
		fogEnd = 330, -- you cannot see the bow of a large vessel
		fogColor = Color3.fromRGB(6, 7, 9), -- matched to BlackVoid: no seam between fog and sky
		outdoorAmbient = 0.35,
		--[[
			0.30, not 1.0. The Wall is applied ABSOLUTELY (severity 1.0 bypasses the time base, see
			DayNight), so this number must be darker than the darkest HOUR or entering the front at night
			would make it brighter - which is exactly what 1.0 did: night-Storm 0.44, night-Wall 1.00.

			It also happens to be the right design answer. "You cannot tell noon from midnight inside the
			front" means noon must look like midnight, so the correct value is near-black regardless of
			the hour.
		]]
		brightness = 0.30,
	},
	atmosphere = {
		density = 0.85, offset = 0.10, haze = 2.0, glare = 0.0,
		-- cooler than Storm's air, for the same reason as shiftTop: red-minus-blue must not turn back up
		color = Color3.fromRGB(66, 76, 92),
		decay = Color3.fromRGB(22, 28, 38),
	},
	--[[
		BlackVoid is a DELIBERATE choice, kept after review (2026-08-20).

		The alternative was reusing AngryHeavens so The Wall read as Storm intensified - textured cloud,
		with fog doing the blinding. Rejected: The Wall should feel like the world has stopped existing,
		not like bad weather. Do not "fix" this to a cloud sky without asking.

		The risk it carries is a flat black ceiling above dark water, which can read as a rendering
		failure. The mitigation is below: fogColor is matched to the void so there is no seam between
		fog and sky - enveloping rather than a lid.
	]]
		severity = 1.00, -- weather total - The Wall is timeless
	skyId = "BlackVoid",
	wave = { amplitude = 7.5, length = 38, speed = 26, choppiness = 1.0, directionSpread = 0.9, directionDeg = 30 },
	spray = 1.0,
	-- The world has stopped existing. Colour is nearly gone, which is the point.
	grade = {
		saturation = -0.55, contrast = 0.14, brightness = -0.06,
		tint = Color3.fromRGB(216, 228, 240),
		bloomIntensity = 0.2, bloomThreshold = 2.2, sunRays = 0.0, sunSize = 0, exposure = 0.40,
		-- cooler than Storm's, or the ladder's cooling REVERSES on the final step. Caught by measuring
		-- red-minus-blue across all five states, which no eye would spot in a near-black scene.
		shiftTop = Color3.fromRGB(86, 98, 118), shiftBottom = Color3.fromRGB(30, 38, 50),
	},
	clouds = { cover = 1.0, density = 0.72, color = Color3.fromRGB(66, 70, 76) },
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

--[[
	THE OCEAN IS A CORRIDOR, NOT A SQUARE (decision 0025, job 023).

	`OCEAN_HALF_EXTENT` above is retained and still means exactly what every fog check needs: the distance to
	the NEAREST edge, which is east-west and does not change as the corridor grows north. That is why
	`validateFogWithinOcean` and `DayNight` can keep using it unchanged.

	Northing is different. The voyage runs up the middle, so the Z extent has to hold the whole run:

	    X:  +/- OCEAN_EXTENT_X          east-west, unchanged, and the fog constraint
	    Z:  OCEAN_EXTENT_Z.min .. .max  the corridor the expedition travels along
]]
SeaStates.OCEAN_EXTENT_X = 3072

--[[
	The corridor's north-south span.

	The southern margin is deliberate: the crew is being pushed south by the storm, so being swept backwards
	must not mean being swept out of the world.

	*** THE INVARIANT THAT SETS `max` ***

	    max  >=  northing target  +  the largest fogEnd

	Because a crew standing AT the finish and looking north must still see fog rather than the water stopping.
	With the job-023 placeholder target of 2400 and Dead Calm's capped fogEnd of 2900, that is 5300 - hence
	5500.

	This is also where decision 0025's figure of 12000 comes from, which the decision itself did not spell
	out: 12000 is a target of about 9100 plus the same 2900 of fog. So the corridor is grown WITH the target,
	and the rule tells you by how much.

	🔴 GROW THE TERRAIN AND THIS CONSTANT TOGETHER. If the constant claims water that is not
	filled, `WaveField.HeightAt` computes waves over nothing: the hull stops floating on a sea and starts
	floating on a flat plane, and it reads as the wave field breaking rather than as running out of world.

	Filled incrementally rather than straight to 12000 on purpose: the full corridor is +145% terrain on a
	mobile-first game, for a northing target nobody has tuned yet. +40% buys the placeholder run with the
	invariant satisfied, and the rest lands when the target does.
]]
SeaStates.OCEAN_EXTENT_Z = { min = -1000, max = 5500 }

--- Is a world XZ inside the filled ocean? The one place that knows the patch is a corridor.
function SeaStates.insideOcean(x: number, z: number): boolean
	return math.abs(x) <= SeaStates.OCEAN_EXTENT_X
		and z >= SeaStates.OCEAN_EXTENT_Z.min
		and z <= SeaStates.OCEAN_EXTENT_Z.max
end

--[[
	Does the corridor hold a run of `target` studs of northing without the crew ever seeing its north end?
	Returns the shortfall so a caller can say how much water to add rather than just failing.
]]
function SeaStates.validateCorridorForTarget(target: number): (boolean, string)
	local worst = 0
	for _, id in ipairs(SeaStates.Order) do
		worst = math.max(worst, ((SeaStates :: any)[id] :: SeaState).sky.fogEnd)
	end
	local needed = target + worst
	local have = SeaStates.OCEAN_EXTENT_Z.max
	if have >= needed then
		return true, ("corridor reaches Z=%d; a %d target with %d of fog needs %d - %d studs of margin")
			:format(have, target, worst, needed, have - needed)
	end
	return false, ("corridor reaches only Z=%d; a %d target with %d of fog needs %d - fill %d more studs north")
		:format(have, target, worst, needed, needed - have)
end

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

--[[
	The sea RIGHT NOW, interpolated if a state change is still in flight.

	🔴 EVERYTHING THAT WANTS THE CURRENT SEA MUST COME THROUGH HERE.

	This exists because of a bug that made the storm feel mechanical. Each caller used to look up the target
	state by name and read its numbers directly, which meant every value derived from `severity` - brightness,
	fog, ambient, the atmosphere, the cloud cover - JUMPED the instant the storm crossed a band, while the
	water colour and the wave field crossfaded smoothly over six seconds. Half the world eased and half of it
	snapped, and the snap is what the eye notices.

	One implementation, three callers (the composer, everyday weather, and the wave field's own blend), so
	they cannot disagree about how far through a transition the sea is.

	The blend state lives on Workspace attributes, written by `WaveField.setState`, for the usual reason:
	each context has its own copy of this module, so an upvalue would let the server and the clients believe
	different things about the weather.
]]
function SeaStates.currentBlended(): SeaState
	local target = SeaStates.get(workspace:GetAttribute("SeaState") or "LightSwell") or SeaStates.LightSwell
	local fromName = workspace:GetAttribute("SeaBlendFrom")
	local startedAt = workspace:GetAttribute("SeaBlendStartedAt")
	local duration = workspace:GetAttribute("SeaBlendDuration")
	if typeof(fromName) ~= "string" or typeof(startedAt) ~= "number" or typeof(duration) ~= "number" or duration <= 0 then
		return target
	end
	local from = SeaStates.get(fromName)
	if not from then
		return target
	end
	local t = (workspace:GetServerTimeNow() - startedAt) / duration
	if t <= 0 or t >= 1 then
		return target
	end
	return SeaStates.lerp(from, target, t)
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
	-- A sky cannot be cross-faded (six ContentIds, no blend), so it snaps with the dominant half. The
	-- fog and atmosphere blend around it, which hides the cut surprisingly well.
	local dominant = if t < 0.5 then a else b
	return {
		id = dominant.id,
		name = dominant.name,
		description = dominant.description,
		skyId = dominant.skyId,
		severity = n(a.severity, b.severity),
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
		atmosphere = {
			density = n(a.atmosphere.density, b.atmosphere.density),
			offset = n(a.atmosphere.offset, b.atmosphere.offset),
			haze = n(a.atmosphere.haze, b.atmosphere.haze),
			glare = n(a.atmosphere.glare, b.atmosphere.glare),
			color = c(a.atmosphere.color, b.atmosphere.color),
			decay = c(a.atmosphere.decay, b.atmosphere.decay),
		},
		--[[
			The grade blends like everything else. If it snapped, the whole point of job 028 would be lost:
			the drain from warm to cold IS the storm's arrival, and half the world easing while half of it
			snaps is exactly the bug the header describes.
		]]
		grade = {
			saturation = n(a.grade.saturation, b.grade.saturation),
			contrast = n(a.grade.contrast, b.grade.contrast),
			brightness = n(a.grade.brightness, b.grade.brightness),
			tint = c(a.grade.tint, b.grade.tint),
			bloomIntensity = n(a.grade.bloomIntensity, b.grade.bloomIntensity),
			bloomThreshold = n(a.grade.bloomThreshold, b.grade.bloomThreshold),
			sunRays = n(a.grade.sunRays, b.grade.sunRays),
			sunSize = n(a.grade.sunSize, b.grade.sunSize),
			exposure = n(a.grade.exposure, b.grade.exposure),
			shiftTop = c(a.grade.shiftTop, b.grade.shiftTop),
			shiftBottom = c(a.grade.shiftBottom, b.grade.shiftBottom),
		},
		clouds = {
			cover = n(a.clouds.cover, b.clouds.cover),
			density = n(a.clouds.density, b.clouds.density),
			color = c(a.clouds.color, b.clouds.color),
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
--[[
	Get an effect object, creating it if the place does not have one.

	Returns `any` deliberately: `Instance.new` with a string class name cannot be typed more precisely, and
	the alternative is a nil-union at every assignment below.

	🔴 This CREATES rather than requiring a human to add the object. The place had no `ColorCorrectionEffect`
	at all, and an absent effect would silently drop the entire grade with no error anywhere.
]]
local function ensureEffect(parent: Instance, className: string): any
	local found = parent:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Parent = parent
	return made
end

function SeaStates.apply(state: SeaState)
	local Terrain = workspace.Terrain
	Terrain.WaterColor = state.water.color
	Terrain.WaterReflectance = state.water.reflectance
	Terrain.WaterTransparency = state.water.transparency
	Terrain.WaterWaveSize = state.water.waveSize
	Terrain.WaterWaveSpeed = state.water.waveSpeed

	local Lighting = game:GetService("Lighting")
	--[[
		⚠️ THESE THREE DO NOTHING. Finding 0027: Roblox hides and stops applying FogStart/FogEnd/FogColor
		whenever Lighting holds an Atmosphere object, and this place has one. Proved by setting FogEnd from
		2353 to 300 and getting a pixel-identical screenshot.

		They are still written so that DELETING the Atmosphere degrades to the old look rather than to no
		visibility model at all. Retiring `sky.fogEnd` and repointing everything derived from it - the radar's
		visibility readout, validateFogWithinOcean, decision 0025's corridor arithmetic - is job 028 step 1
		and is NOT done yet. Do not reason about visibility from these numbers.
	]]
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

	-- The sky. Dominant term in the sea's apparent colour (job 007), so it moves with the state.
	local skyMod = ReplicatedStorage:FindFirstChild("SkyLibrary")
	if skyMod and state.skyId then
		local okSky, SkyLibrary = pcall(require, skyMod)
		if okSky then
			SkyLibrary.apply(state.skyId)
		end
	end

	-- The air. This is what actually makes the states look different from each other.
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and state.atmosphere then
		local at = state.atmosphere
		atm.Density = at.density
		atm.Offset = at.offset
		atm.Haze = at.haze
		atm.Glare = at.glare
		atm.Color = at.color
		atm.Decay = at.decay
	end

	--[[
		THE GRADE - the final image. Job 028.

		Five of these were dead before this job: there was no ColorCorrectionEffect at all, Bloom's threshold
		sat above anything on screen, SunRays was Enabled at Intensity 0, and ColorShift was cold in every
		state. Together they are what makes a warm day read as warm and the storm read as the warmth leaving.
	]]
	local g = state.grade
	if g then
		Lighting.ExposureCompensation = g.exposure
		-- the colour of the light itself, which is what a global tint alone cannot fake
		Lighting.ColorShift_Top = g.shiftTop
		Lighting.ColorShift_Bottom = g.shiftBottom

		local cc = ensureEffect(Lighting, "ColorCorrectionEffect")
		cc.Name = "SeaGrade"
		cc.Saturation = g.saturation
		cc.Contrast = g.contrast
		cc.Brightness = g.brightness
		cc.TintColor = g.tint

		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom then
			bloom.Intensity = g.bloomIntensity
			bloom.Threshold = g.bloomThreshold -- must stay UNDER the brightest thing on screen
		end
		local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
		if rays then
			rays.Intensity = g.sunRays -- only means anything while the sky still has a sun disc
		end

		--[[
			The sun disc. SkyLibrary.apply has already run above and set the sky's own defaults, so this
			overrides them with the state's blended value.

			`CelestialBodiesShown` is the gate: SunAngularSize alone draws nothing while it is false, which
			is how the place ended up with no sun anywhere.
		]]
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			sky.SunAngularSize = g.sunSize
			sky.CelestialBodiesShown = g.sunSize > 0
		end
	end

	-- Dynamic clouds. Present in the place at Cover 0.15 - invisible - and driven by nothing until now.
	local cl = state.clouds
	if cl then
		local clouds = ensureEffect(Terrain, "Clouds")
		clouds.Cover = cl.cover
		clouds.Density = cl.density
		clouds.Color = cl.color
	end
end

return SeaStates
