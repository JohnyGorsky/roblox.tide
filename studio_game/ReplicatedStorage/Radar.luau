--!strict
--[[
	Radar - the scope's maths. Pure, no instances.

	Feature: GAME-0002  ·  decisions 0004, 0014, 0019  ·  job 026

	--------------------------------------------------------------------------------------------------
	🔴 THE SCOPE IS HEAD-UP, AND DECISION 0014 DECIDES THAT

	A PPI can be drawn north-up (north fixed at the top) or head-up (your own bow at the top). It is not a
	style choice here:

	    A NORTH-UP SCOPE IS A COMPASS. The boat marker's rotation against a fixed north *is* a heading
	    readout, and decision 0014 forbids one.

	So every contact is plotted at RELATIVE bearing - `bearing - ownHeading` - with the bow at the top. Which
	is also what small-craft radar actually does.

	--------------------------------------------------------------------------------------------------
	THE TENSION THAT FOLLOWS, AND WHY IT IS FINE

	Head-up plus a storm arc means the arc's position tells you where the front is relative to your bow. The
	front is always astern in absolute terms, so that is a soft compass.

	**Intended.** Decision 0019 gives the radar the storm's number deliberately, and the storm doc's whole
	argument is that knowing where the front is *is* knowing which way is away. The blindness clause bites
	inside The Wall - where the radar DIES. So outside it you are meant to know; inside it the compass is all
	you have.

	Written down because it looks like a leak and is not, and someone will otherwise "fix" it.

	--------------------------------------------------------------------------------------------------
	RANGE IS ONE NUMBER, BECAUSE SKILLS WILL CHANGE IT

	`RANGE` is read from here and nowhere else. When progression lands (decisions 0008 role mastery, 0012
	parts) it changes this value and nothing in the drawing code has to move.
]]

local Radar = {}

--[[
	1,800 studs. Roughly a third of the storm's 4,200-stud cushion, which is the figure that matters: the
	front appears on the scope well before it is dangerous, but not from the first second of a run.

	🔴 The concept mockup said 6.0 km. That does not fit - `SeaStates.OCEAN_EXTENT_Z` runs to 5,500, so a
	6 km scope would see past the end of the world. It is also the wrong instinct: a radar that shows
	everything removes the searching, which is the loop.
]]
Radar.RANGE = 1800

--[[
	Beyond this fraction of range a contact is a GUESS rather than a fix - a small hollow circle with no
	label, "something is there".

	This is the mechanic the user asked for, and its value is what makes it worth having: it gives the crew a
	reason to steer TOWARDS an unknown rather than only away from the storm. At 0.6 the uncertain band is
	1,080..1,800 - 720 studs deep, wide enough that a contact spends real time as a question mark.
]]
Radar.CONFIDENT_FRACTION = 0.6

--- Seconds per revolution. Marine radar is 2-6; 4 leaves time to notice a blip before it fades.
Radar.SWEEP_PERIOD = 4

--[[
	How long a blip stays lit after the beam passes it. Equal to the sweep period, so a contact fades to
	nothing just as the beam comes back round.

	This is what makes "someone must watch rada constantly" mechanically true rather than thematic: look away
	and the picture you remember is already stale.
]]
Radar.BLIP_DECAY = 4

--[[
	THE LEGEND. The colours are the instrument's vocabulary, so they live with the maths rather than in the
	drawing code - a legend that can disagree with the blips is worse than no legend.

	⚠️ Taken from the concept mockup, and the game has no style guide yet (todo 0001). These are a mockup's
	choices, not a system's, so they are a known thing to reconcile when `tide-style` lands.
]]
export type Kind = "land" | "object" | "unknown" | "storm" | "own"

--[[
	Declared as a local first because Luau cannot annotate a table FIELD - `Radar.LEGEND: {...} = {...}` is a
	syntax error. Same shape as `VesselDamage.LADDER`.
]]
local LEGEND: { { kind: Kind, colour: Color3, label: string } } = {
	{ kind = "land", colour = Color3.fromRGB(126, 200, 96), label = "Island" },
	{ kind = "storm", colour = Color3.fromRGB(214, 74, 70), label = "Storm" },
	{ kind = "unknown", colour = Color3.fromRGB(232, 176, 58), label = "Unknown" },
	{ kind = "object", colour = Color3.fromRGB(232, 176, 58), label = "Contact" },
	{ kind = "own", colour = Color3.fromRGB(196, 232, 224), label = "Your boat" },
}
Radar.LEGEND = LEGEND

Radar.RING_COLOUR = Color3.fromRGB(74, 132, 190)
Radar.SCOPE_COLOUR = Color3.fromRGB(12, 32, 30)
Radar.BEAM_COLOUR = Color3.fromRGB(126, 220, 170)

function Radar.colourOf(kind: Kind): Color3
	for _, entry in ipairs(LEGEND) do
		if entry.kind == kind then
			return entry.colour
		end
	end
	return LEGEND[#LEGEND].colour
end

--- Rings, as fractions of range. Three is legible; more is clutter on a scope this size.
Radar.RINGS = { 1 / 3, 2 / 3, 1 }

-- ---------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------

--[[
	Absolute bearing from one point to another, in degrees, 0 = +Z north.

	Same convention as the wave field, the storm and the compass - `atan2(dx, dz)`. Getting this consistent
	across four systems is worth more than it looks: a bearing convention that differs by 90 degrees in one
	place produces contacts that are plausibly wrong, which is far harder to spot than obviously wrong.
]]
function Radar.bearingTo(from: Vector3, to: Vector3): number
	return math.deg(math.atan2(to.X - from.X, to.Z - from.Z)) % 360
end

function Radar.distanceTo(from: Vector3, to: Vector3): number
	local dx, dz = to.X - from.X, to.Z - from.Z
	return math.sqrt(dx * dx + dz * dz) -- horizontal only; a contact's height is not a radar's business
end

--[[
	Bearing relative to our own bow. The head-up transform, and the whole reason the scope does not leak
	heading.

	Range is HALF-OPEN: [-180, 180). So dead astern is -180, never +180 - which caught out this module's own
	first test. It makes no difference to drawing (sin/-cos give the same point either way) but it matters to
	anything that compares the value, so it is stated rather than discovered.
]]
function Radar.relativeBearing(absoluteBearing: number, ownHeading: number): number
	return (absoluteBearing - ownHeading + 540) % 360 - 180
end

--[[
	Where a contact sits on the scope, as x/y in -1..1 with the bow at the top.

	Screen Y grows DOWNWARD, so a contact dead ahead (relative bearing 0) must land at y = -1 x fraction, not
	+1. That sign is the single easiest thing to get wrong here and it produces a scope that is upside down
	but otherwise convincing.
]]
function Radar.scopeOffset(relativeBearing: number, distance: number, range: number?): Vector2
	local r = math.min(distance / (range or Radar.RANGE), 1)
	local rad = math.rad(relativeBearing)
	return Vector2.new(math.sin(rad) * r, -math.cos(rad) * r)
end

-- ---------------------------------------------------------------------------
-- Confidence
-- ---------------------------------------------------------------------------

export type Resolution = "confident" | "uncertain" | "off"

function Radar.classify(distance: number, range: number?): Resolution
	local rng = range or Radar.RANGE
	if distance > rng then
		return "off"
	elseif distance > rng * Radar.CONFIDENT_FRACTION then
		return "uncertain"
	end
	return "confident"
end

--[[
	0..1, for how solidly a contact is drawn. Full inside the confident radius, falling to zero at the edge
	of range - so a contact does not pop out of existence, it fades out of certainty.
]]
function Radar.confidence(distance: number, range: number?): number
	local rng = range or Radar.RANGE
	local edge = rng * Radar.CONFIDENT_FRACTION
	if distance <= edge then
		return 1
	end
	if distance >= rng then
		return 0
	end
	return 1 - (distance - edge) / (rng - edge)
end

-- ---------------------------------------------------------------------------
-- The sweep
-- ---------------------------------------------------------------------------

--- Where the beam is pointing, in degrees, derived from server time so every client agrees without a remote.
function Radar.sweepAngle(atTime: number, period: number?): number
	return (atTime % (period or Radar.SWEEP_PERIOD)) / (period or Radar.SWEEP_PERIOD) * 360
end

--[[
	Did the beam cross this bearing between two samples?

	🔴 THE WRAP IS THE WHOLE PROBLEM. The beam goes 350 -> 5 degrees across the 360 boundary, and a naive
	`prev <= b and b <= now` misses every contact in that arc once per revolution - which reads as one dead
	sector on the scope, the sort of bug that gets blamed on the drawing code for an hour.

	Handled by detecting the wrap and treating it as two ranges.
]]
function Radar.sweptSince(bearing: number, previousAngle: number, currentAngle: number): boolean
	local b = bearing % 360
	if currentAngle >= previousAngle then
		return b > previousAngle and b <= currentAngle
	end
	-- wrapped through 360
	return b > previousAngle or b <= currentAngle
end

--- Brightness of a blip, `age` seconds after the beam last passed it. Linear fade over `BLIP_DECAY`.
function Radar.blipBrightness(age: number, decay: number?): number
	local d = decay or Radar.BLIP_DECAY
	if age < 0 then
		return 0
	end
	return math.clamp(1 - age / d, 0, 1)
end

-- ---------------------------------------------------------------------------
-- Readouts
-- ---------------------------------------------------------------------------

--[[
	Seconds until the front arrives at the current closing rate. The honest version of the mockup's `02:35`.

	Returns nil when the crew is gaining ground - which is a real answer, not an error, and the readout should
	say so rather than printing a number that is about to be wrong.
]]
function Radar.arrivalSeconds(stormDistance: number, closingRate: number): number?
	if closingRate <= 0 then
		return nil
	end
	return stormDistance / closingRate
end

function Radar.clock(seconds: number?): string
	if not seconds then
		return "--:--"
	end
	local s = math.max(math.floor(seconds + 0.5), 0)
	return ("%02d:%02d"):format(math.floor(s / 60), s % 60)
end

--- Visibility as a fraction of the clearest sea state's view. Derived, so it cannot disagree with the fog.
function Radar.visibility(fogEnd: number, clearestFogEnd: number): number
	if clearestFogEnd <= 0 then
		return 1
	end
	return math.clamp(fogEnd / clearestFogEnd, 0, 1)
end

--[[
	Is the scope working at all?

	Two ways it dies, and BOTH must be drawn as visibly broken rather than empty:

	  * inside The Wall - decision 0019 gives the radar the storm's number and then takes it away at the worst
	    moment, which is the arc the whole storm design is built around
	  * the radar FAULT - job 022 published `VesselFault_radar` and nothing consumed it. This is where it
	    finally bites, and lightning already rolls it on close strikes

	🔴 An empty scope and a dead scope must not look the same. A blank display reads as "nothing out there",
	the crew sails on, and the instrument has lied by omission.
]]
function Radar.isDead(stormIntensity: number, radarFault: boolean): (boolean, string?)
	if radarFault then
		return true, "RADAR FAULT"
	end
	if stormIntensity >= 4 then
		return true, "NO RETURN"
	end
	return false, nil
end

return Radar
