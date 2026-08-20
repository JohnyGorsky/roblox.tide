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
local ATTR_LAST_POS = "StormLastVesselZ" -- for measuring northward progress

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
	workspace:SetAttribute(ATTR_LAST_POS, 0)
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
		local last = num(ATTR_LAST_POS, vesselZ)
		local travelledNorth = vesselZ - last
		if travelledNorth > 0 then
			-- only northward progress counts; running back south does not hand distance to the storm twice
			distance += travelledNorth * StormFront.GAIN_PER_STUD
		end
		workspace:SetAttribute(ATTR_LAST_POS, vesselZ)
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
					WaveField.setState(state, 6)
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
		("rates      advance %.1f studs/s, gain %.1f per stud north"):format(
			StormFront.ADVANCE_RATE, StormFront.GAIN_PER_STUD),
		("net at 12 studs/s northward: %+.1f studs/s"):format(
			12 * StormFront.GAIN_PER_STUD - StormFront.ADVANCE_RATE),
	}, "\n")
end

return StormFront
