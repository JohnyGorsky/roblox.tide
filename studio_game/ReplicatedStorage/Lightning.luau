--!strict
--[[
	Lightning - the storm's only loud moment.

	Feature: docs/features/0003-storm-front/  ·  decisions 0018, 0020  ·  job 018

	--------------------------------------------------------------------------------------------------
	WHY IT IS SERVER-CHOSEN AND CLIENT-RENDERED

	A strike has to happen at the same instant, in the same direction, for everybody - a crew shouting
	"did you see that" only works if they saw the same thing. So the server picks (when, where, how hard)
	and broadcasts; each client draws its own bolt and hears its own thunder.

	Rolling it per-client would be cheaper and would quietly destroy the shared moment.

	--------------------------------------------------------------------------------------------------
	🔴 THE ONE LIGHTING PROPERTY LIGHTNING MAY TOUCH: ExposureCompensation

	`DayNight.compose()` owns Lighting (decision 0018) and writes Brightness, Fog*, OutdoorAmbient, the
	Atmosphere and the Sky. A flash needs to brighten the frame for ~150 ms, and a 1 Hz composer cannot do
	that - so lightning takes `ExposureCompensation`, which compose() never writes.

	That is the whole reason the flash uses exposure rather than Brightness: two writers on Brightness would
	produce a flicker that looks exactly like a bug in the day/night cycle. If you add another flash effect,
	give it its own unwritten property or route it through the composer - do not reach for Brightness.

	ExposureCompensation is also per-client by nature, which is what we want: the flash is a camera
	response, not a change to the world.

	--------------------------------------------------------------------------------------------------
	LIGHTNING IS A STORM CUE, NOT A WEATHER CUE

	Decision 0020 makes rain ordinary. Lightning deliberately stays rare and storm-only: it needs storm
	intensity 2 or above, so it can never fire on an ordinary wet afternoon. It is one of the few signals
	that means the front and nothing else.
]]

local Lightning = {}

--[[
	Strikes per minute, by storm intensity 0..4.

	Nothing at all below intensity 2. Then it climbs steeply rather than smoothly, because the interesting
	quantity is not the average rate - it is the gap between strikes. At 20/minute you are never in the dark
	for more than a few seconds, which is what makes The Wall feel electrically lit rather than merely dark.
]]
local RATE_PER_MINUTE = { 0, 0, 2, 9, 22 } -- index = intensity + 1

Lightning.MIN_INTENSITY = 2

function Lightning.ratePerMinute(intensity: number): number
	local i = math.clamp(math.floor(intensity), 0, 4)
	return RATE_PER_MINUTE[i + 1]
end

--[[
	Where strikes happen.

	Biased ASTERN, because that is where the front is. A crew that notices the lightning is always behind
	them has learned something true about the world without being told it, and it makes turning round to
	look a deliberate act.

	Bearing is degrees, 0 = +Z (north, the way progress runs), matching SeaStates.WaveSpec.directionDeg.
	The front is south, so strikes cluster around 180.
]]
Lightning.ASTERN_BEARING = 180
Lightning.BEARING_SPREAD = 75

--- How far a strike can be. The near end only opens up as the front closes.
Lightning.DISTANCE_NEAR = 180
Lightning.DISTANCE_FAR = 2600

--[[
	Sound travels this many studs per second.

	Real sound is ~343 m/s and a stud is roughly 28 cm, so a literal conversion gives ~1225 studs/s - which
	at our distances would put thunder 0.15s behind the flash and read as simultaneous. 300 is deliberately
	slow, tuned so a mid-distance strike lands its thunder about four seconds late: long enough for a player
	to count, which is the whole point of the effect.

	This is a legibility number, not a physics one. Do not "correct" it.
]]
Lightning.SOUND_STUDS_PER_SECOND = 300

--- Strikes closer than this shake the camera and can disrupt ship systems.
Lightning.CLOSE_DISTANCE = 420

export type Strike = {
	bearing: number, -- degrees, 0 = +Z
	distance: number, -- studs from the crew
	magnitude: number, -- 0..1, how big the bolt and flash are
	at: number, -- Workspace:GetServerTimeNow() when it fired
	fault: string?, -- a ship system it disrupted, if any
}

--- Seconds between flash and thunder, from distance.
function Lightning.thunderDelay(distance: number): number
	return distance / Lightning.SOUND_STUDS_PER_SECOND
end

--[[
	Flash strength from magnitude and distance.

	Falls off with distance but never to nothing - a far strike still lights the cloud base, and on a sea
	with no landmarks that distant glow is most of what tells you the sky has depth.
]]
function Lightning.flashExposure(strike: Strike): number
	local near = math.clamp(1 - (strike.distance / Lightning.DISTANCE_FAR), 0, 1)
	return (0.25 + 1.35 * near) * (0.4 + 0.6 * strike.magnitude)
end

--[[
	The world-space direction a strike came from.

	Returned as a unit vector so callers do not each re-derive the bearing convention and get it subtly
	wrong - which is easy here, because 0 degrees is +Z rather than the +X that `math.atan2` would suggest.
]]
function Lightning.directionOf(strike: Strike): Vector3
	local a = math.rad(strike.bearing)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

return Lightning
