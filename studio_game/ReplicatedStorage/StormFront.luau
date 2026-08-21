--!strict
--[[
	StormFront - the thing chasing you.

	Feature: docs/features/0003-storm-front/  ·  decisions 0007, 0014, 0018, 0019  ·  job 017

	--------------------------------------------------------------------------------------------------
	TWO CHANNELS, DELIBERATELY SEPARATE

	  the NUMBER  lives on the radar (decision 0019). Precise, and it dies inside The Wall.
	  the FEELING lives in the world: wind, rain, spray, sound, the cloud wall.

	A crew with nobody at the radar should still know in their gut that something is coming. That is why
	the sensory channel is not driven by the readout - both are driven by the same underlying distance, and
	either one alone is enough to make a decision.

	--------------------------------------------------------------------------------------------------
	FLOW IS ONE-DIRECTIONAL

	    StormFront: distance -> intensity -> picks a sea state
	                                          -> its `severity` drives DayNight.compose()

	This module NEVER writes Lighting. Decision 0018 gives that to the composer alone, and a second writer
	produces flicker bugs that look like anything except two systems disagreeing.

	What this module does own is WIND, which is new here and is the master control for everything sensory.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local StormFront = {}

-- Shared state. Attributes for the same reason the clock uses them: per-context module copies would
-- otherwise let the server and each client disagree about where the storm is.
local ATTR_DISTANCE = "StormDistance" -- studs astern
local ATTR_INTENSITY = "StormIntensity" -- 0..4
local ATTR_WIND = "StormWind" -- 0..1, the master sensory control
local ATTR_SHELTERED = "StormSheltered" -- bool
--[[
	🔴 THE LAST VESSEL POSITION IS NOT AN ATTRIBUTE. Job 022, and it was one until validation caught it.

	It used to live on `StormLastVesselZ`, alongside the attributes above - and Workspace attributes replicate,
	so every client could read the hull's northward coordinate. A client watching that number RISE knows it is
	heading north, which is precisely the free heading oracle decision 0014 forbids inside The Wall. It is the
	same leak `VesselHeading` was removed for, arriving through the storm's own bookkeeping.

	It was harmless until job 022 by accident: `vesselZ` never resolved (finding 0020), so this was written
	once as 0 by `reset` and never updated. Fixing the storm published the vessel's position as a side effect,
	which is a good argument for reading a client's attribute list after any change to what the server writes.

	An upvalue is also simply CORRECT here. The attributes above are shared because clients read them and must
	agree with the server about where the storm is. Nothing outside `advance` has ever read this one, and only
	the server calls `advance` - so there is no second reader to keep in sync.

	`nil` means "no measurement yet", which is what makes the first tick after a reset measure zero travel
	rather than crediting the hull's whole Z coordinate. See `reset`.
]]
local lastVesselZ: number? = nil

--[[
	THE TWO NUMBERS THAT DECIDE THE GAME (decision 0019).

	Their ratio sets how much looting an expedition affords, and it is the most important balance figure in
	the project. Stated as: at full cruise the crew gains ground, standing still they lose it.

	ADVANCE_RATE  studs/second the front closes, always.
	GAIN_PER_STUD studs of distance bought per stud travelled north.

	With 14 and 1.6: a vessel making ~12 studs/s northward gains 19.2 - 14 = +5.2 studs/s, so it slowly
	pulls away. Stopped, it loses 14/s. A 60-second island visit therefore costs ~840 studs of cushion -
	roughly a fifth of the starting distance. That is the dial to turn when looting feels too cheap or too
	punishing.
]]
StormFront.ADVANCE_RATE = 14
StormFront.GAIN_PER_STUD = 1.6

--- Moored at a shelter the front still closes, at this fraction of normal. Never zero (decision 0019).
StormFront.SHELTER_RATE = 0.3

StormFront.START_DISTANCE = 4200

--[[
	Intensity bands, by distance astern.

	Deliberately uneven: the outer bands are wide so most of an expedition is spent at 0-1, and the inner
	ones are narrow so the last stretch escalates fast. A linear ramp would make the whole run feel
	uniformly threatened, which is the same mistake as a storm that cannot be outrun.
]]
local BANDS = {
	{ min = 3200, intensity = 0, label = "Calm", sea = "LightSwell" },
	{ min = 1900, intensity = 1, label = "Incoming", sea = "LightSwell" },
	{ min = 900, intensity = 2, label = "Storm", sea = "Choppy" },
	{ min = 260, intensity = 3, label = "Severe", sea = "Storm" },
	{ min = -math.huge, intensity = 4, label = "The Wall", sea = "TheWall" },
}
StormFront.BANDS = BANDS

local function num(name: string, fallback: number): number
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else fallback
end

function StormFront.distance(): number
	return num(ATTR_DISTANCE, StormFront.START_DISTANCE)
end

function StormFront.wind(): number
	return num(ATTR_WIND, 0)
end

function StormFront.isSheltered(): boolean
	return workspace:GetAttribute(ATTR_SHELTERED) == true
end

--- Band for a distance: intensity, label, and the sea state it selects.
function StormFront.bandFor(distance: number)
	for _, b in ipairs(BANDS) do
		if distance >= b.min then
			return b
		end
	end
	return BANDS[#BANDS]
end

--[[
	WHERE THE WALL BEGINS, and where being inside it is as bad as it gets (job 022).

	`WALL_AT` is read from the band table rather than restated, so the two can never drift apart - the whole
	point of the storm having ONE source for its bands.

	`FULL_EXPOSURE_AT` is distance 0. Band 4 has no floor (`min = -math.huge`) because the front keeps
	overtaking a crew that cannot move, so exposure has to saturate somewhere. Distance 0 is the choice, and
	it is a mercy with a reason: 400 studs inside the wall is not meaningfully worse than 200, and making it
	worse would mean a late reaction is unrecoverable no matter how well the crew then drove. Decision 0014
	wants a crew punished for lingering, not for being slow to understand.
]]
StormFront.FULL_EXPOSURE_AT = 0

function StormFront.wallAt(): number
	return BANDS[#BANDS - 1].min -- the band ABOVE The Wall ends where The Wall starts
end

--[[
	EXPOSURE, 0..1. How hard the front is working on whatever is out in it.

	Zero outside band 4 entirely, and that edge is sharp on purpose. A crew in a Severe sea is being
	THREATENED, not damaged - decision 0014 attaches the consequence to The Wall specifically, and bleeding a
	little damage into the approach would turn a deadline into slow attrition. The whole macro loop depends on
	the front being a line you can be on the right side of.

	This is the storm's half of the damage model. What a given hull does with it belongs to `VesselDamage`.
]]
function StormFront.exposure(distance: number?): number
	local d = distance or StormFront.distance()
	local wall = StormFront.wallAt()
	if d >= wall then
		return 0
	end
	local span = wall - StormFront.FULL_EXPOSURE_AT
	if span <= 0 then
		return 1
	end
	return math.clamp((wall - d) / span, 0, 1)
end

--[[
	THE ESCAPE ARITHMETIC. Seconds to claw back out of the front, at a given northward speed.

	A function rather than a comment because it is the number decision 0014's 30-60 second target is actually
	about, and because it is what the survival test checks the damage curve against. From the constants above
	at cruise 18:

	    net  =  18 x 1.6 - 14  =  +14.8 studs/s
	    from distance    0  ->  260 studs  ->  17.6 s
	    from distance -450  ->  710 studs  ->  48.0 s

	Returns nil when the crew cannot gain ground at all, which is a real answer rather than an error: below
	ADVANCE_RATE / GAIN_PER_STUD - 8.75 studs/s for these constants - the front closes faster than northward
	travel buys distance, and no amount of patience gets them out. That threshold is worth knowing. It is the
	speed a damaged or half-fuelled vessel has to stay above to have any escape at all.
]]
function StormFront.secondsToEscape(distance: number, northSpeed: number): number?
	local net = northSpeed * StormFront.GAIN_PER_STUD - StormFront.ADVANCE_RATE
	if net <= 0 then
		return nil
	end
	local wall = StormFront.wallAt()
	if distance >= wall then
		return 0
	end
	return (wall - distance) / net
end

--- The slowest northward speed that gains any ground at all. Below this there is no escape, at any range.
function StormFront.minEscapeSpeed(): number
	return StormFront.ADVANCE_RATE / StormFront.GAIN_PER_STUD
end

function StormFront.intensity(): number
	return math.floor(num(ATTR_INTENSITY, 0))
end

--[[
	Wind from intensity, plus a slow breathing so it never sits perfectly still.

	Wind is what every sensory system reads: rain angle and density, spray, cloth, debris, audio level, and
	later the boat's handling. Keeping it as ONE number means those can never disagree about how bad it is.
	The breathing is deterministic from server time, so all clients gust together.
]]
local function windFor(intensity: number, t: number): number
	local base = intensity / 4
	-- gusts grow with the storm; at intensity 0 there is almost none
	local gust = math.sin(t * 0.37) * 0.5 + math.sin(t * 0.11) * 0.5
	return math.clamp(base + gust * 0.06 * base, 0, 1)
end

function StormFront.reset(distance: number?)
	workspace:SetAttribute(ATTR_DISTANCE, distance or StormFront.START_DISTANCE)
	workspace:SetAttribute(ATTR_SHELTERED, false)
	--[[
		🔴 CLEAR the last position, do not zero it. Job 022, and it is a one-word difference that hands out
		free distance.

		`advance` treats a nil `lastVesselZ` as "no measurement yet" and seeds it from the vessel's current Z,
		so the first tick correctly measures zero travel. Setting 0 instead makes that tick believe the vessel
		travelled its entire Z coordinate in one step: a hull 500 studs north would be handed
		500 x 1.6 = 800 studs of free cushion by the mere act of resetting the storm.

		Latent until job 022. `vesselZ` never returned anything before it was fixed (finding 0020), so the old
		attribute was written and never read. The moment the fix landed, every `reset` mid-run - which is
		exactly what the admin panel's storm-distance tool does - became a distance cheat.
	]]
	lastVesselZ = nil
	--[[
		Clear the retired attribute too, in case a session or a saved place still carries it. Cheap, and it
		stops a stale copy of the vessel's position sitting on the wire for a client to find.
	]]
	if workspace:GetAttribute("StormLastVesselZ") ~= nil then
		workspace:SetAttribute("StormLastVesselZ", nil)
	end
	StormFront.apply()
end

--[[
	Advance the front by `dt` seconds, accounting for how far north the vessel travelled.

	`vesselZ` is the vessel's world Z (north is +Z). Pass nil when there is no vessel yet, and the front
	simply closes - which is the correct behaviour for a crew that cannot move.
]]
function StormFront.advance(dt: number, vesselZ: number?)
	local distance = StormFront.distance()

	local rate = StormFront.ADVANCE_RATE * (if StormFront.isSheltered() then StormFront.SHELTER_RATE else 1)
	distance -= rate * dt

	if vesselZ then
		local travelledNorth = vesselZ - (lastVesselZ or vesselZ)
		if travelledNorth > 0 then
			-- only northward progress counts; running back south does not hand distance to the storm twice
			distance += travelledNorth * StormFront.GAIN_PER_STUD
		end
		lastVesselZ = vesselZ
	end

	-- Never let it run away past the start, or an early lead becomes an un-loseable one
	distance = math.min(distance, StormFront.START_DISTANCE)
	workspace:SetAttribute(ATTR_DISTANCE, distance)
	StormFront.apply()
end

--[[
	Publish intensity, wind and the selected sea state from the current distance.

	Note what this does NOT do: touch Lighting. It sets the sea state, and the composer reads it.
]]
function StormFront.apply()
	local distance = StormFront.distance()
	local band = StormFront.bandFor(distance)
	workspace:SetAttribute(ATTR_INTENSITY, band.intensity)
	workspace:SetAttribute(ATTR_WIND, windFor(band.intensity, workspace:GetServerTimeNow()))

	--[[
		🔴 AN OVERRIDE THAT ACTUALLY STICKS.

		This function runs every second from the world tick and rewrites `SeaState`, which silently clobbered
		any manual override within about 0.65 seconds - measured, not guessed. So the admin panel's "Sea state"
		tool has been broken since the tick arrived in job 017 for any state that did not happen to match the
		current storm band, and `DeadCalm` was unreachable entirely, because NO band ever selects it.

		That is the "forcing an end-state" trap: a system that rewrites a value every tick beats a manual
		write, and the fix is to give it something to respect rather than to fight it.

		With `SeaOverride` set, the storm keeps computing distance, intensity and wind - all of which stay
		honest, so the front still closes and still threatens - and simply stops choosing the sea. Clearing
		the attribute hands the choice straight back.
	]]
	local override = workspace:GetAttribute("SeaOverride")
	if typeof(override) == "string" and SeaStates.get(override) then
		return
	end

	-- Selecting the sea state is how the storm changes the look, indirectly (decision 0018).
	local current = workspace:GetAttribute("SeaState")
	if current ~= band.sea then
		local state = SeaStates.get(band.sea)
		if state then
			local wf = ReplicatedStorage:FindFirstChild("WaveField")
			if wf then
				local ok, WaveField = pcall(require, wf)
				if ok then
					-- blend the physical sea too, so the water does not step
					WaveField.setState(state, 9) -- ONE blend drives everything: water, light, fog, clouds, weather weight
				end
			end
			workspace:SetAttribute("SeaState", band.sea)
		end
	end
end

--- Mooring at a shelter slows the front (decision 0019). Never stops it.
function StormFront.setSheltered(sheltered: boolean)
	workspace:SetAttribute(ATTR_SHELTERED, sheltered == true)
end

--[[
	Distance in the units the radar and the HUD should speak.

	Studs are meaningless to a player. The storm doc's threshold example is "0.8 KM", so one kilometre is
	treated as 1000 studs - close enough to Roblox's rough 1 stud ~= 28 cm scale to be readable, and the
	point is relative change rather than real-world accuracy.
]]
function StormFront.distanceKm(): number
	return StormFront.distance() / 1000
end

--- Threshold alerts, few enough to stay meaningful (decision 0019).
StormFront.ALERT_KM = { 2.0, 0.8, 0.3 }

function StormFront.report(): string
	local d = StormFront.distance()
	local band = StormFront.bandFor(d)
	return table.concat({
		("distance   %.0f studs  (%.2f km)%s"):format(d, StormFront.distanceKm(),
			StormFront.isSheltered() and "  [SHELTERED - closing at 30%]" or ""),
		("intensity  %d  %s  -> sea %s"):format(band.intensity, band.label, band.sea),
		("wind       %.2f"):format(StormFront.wind()),
		("exposure   %.2f  (0 outside The Wall, 1 at distance %d)"):format(
			StormFront.exposure(), StormFront.FULL_EXPOSURE_AT),
		("rates      advance %.1f studs/s, gain %.1f per stud north"):format(
			StormFront.ADVANCE_RATE, StormFront.GAIN_PER_STUD),
		("net at 12 studs/s northward: %+.1f studs/s"):format(
			12 * StormFront.GAIN_PER_STUD - StormFront.ADVANCE_RATE),
		("min escape speed %.2f studs/s; escape from here at cruise 18: %s"):format(
			StormFront.minEscapeSpeed(),
			(function()
				local t = StormFront.secondsToEscape(d, 18)
				return if t then ("%.1f s"):format(t) else "never at this speed"
			end)()),
	}, "\n")
end

return StormFront
