--!strict
--[[
	VesselDamage - what the storm does to a hull. Pure maths, no instances.

	Feature: GAME-0003  ·  decision 0014  ·  job 022

	--------------------------------------------------------------------------------------------------
	THE SPLIT, AND WHY IT IS HERE RATHER THAN IN StormFront

	    StormFront.exposure()   how bad is it OUT THERE   (one more derivation from the distance it owns)
	    VesselDamage            what THIS HULL does about it

	Keeping them apart means a future vessel, an island shelter or a second weather system can all ask the
	same question of the storm and get the same answer, while what happens to a given hull stays a property
	of that hull. Folding exposure in here would mean re-reading the storm's attribute and being able to
	disagree with its own band, which is the class of bug that produces "the sky says Wall and nothing is
	taking damage".

	Same purity rule as `VesselPhysics`, for the same reason: the interesting failure is a curve that kills
	too fast or never kills at all, and that is measured by feeding it a fake state in a loop, not by looking
	at it.

	--------------------------------------------------------------------------------------------------
	🔴 EVERY NUMBER DERIVES FROM `spec.survivability`. NOTHING IS AUTHORED PER HULL.

	A spec says how many seconds of full exposure it survives. From that alone:

	    integrityMax  = mass-scaled pool                (so a big hull has a big pool, and reads bigger)
	    damage/second = integrityMax / survivability     (so the pool always empties in exactly that time)
	    fault points  = fractions of integrityMax        (so a tough hull faults later in wall-clock terms)

	The ratio is what matters, and stating the SECONDS rather than the pool is what keeps it honest: the
	number a designer writes is the number the stopwatch reads. This is the same discipline as deriving
	buoyancy stiffness from draft - see the `VesselPhysics` header - and breaking it costs decision 0009.

	--------------------------------------------------------------------------------------------------
	WHY THE CURVE IS SQUARED

	Decision 0014 requires the damage curve be "steep enough that lingering is never a shortcut for extra
	looting". A linear curve fails that: at half penetration you would take half damage, which makes skimming
	the front's edge to shave a route strictly better than going round.

	Squared, half penetration costs a QUARTER rate. So the edge of the front is a real tactical option and
	the inside of it is not, which is exactly the shape the decision asks for.
]]

local VesselDamage = {}

--[[
	Not here on purpose: EXPOSURE and the ESCAPE ARITHMETIC live on `StormFront`.

	Both are made entirely of storm constants - the band edge, `ADVANCE_RATE`, `GAIN_PER_STUD` - so putting
	them here would mean this module knowing how far astern the front is, which is precisely the coupling
	the header's split exists to avoid. This module takes an `exposure` number and never asks where it came
	from.
]]

--[[
	Integrity per unit of hull mass.

	Mass-scaled rather than a flat pool so the numbers a diagnostic prints read like a bigger vessel is a
	bigger vessel - a 90,000-mass trawler with a 4,200-mass hull's integrity would look absurd in a report
	and would make every future percentage-based effect mean something different per hull.

	The absolute value is arbitrary and deliberately so: it cancels out of every rate in this module, because
	the damage rate is `integrityMax / survivability`. It exists to be READ, not to be tuned. 0.25 puts the
	starter launch at 1,050 - a four-digit number that reads as a health pool rather than as a percentage.
]]
VesselDamage.INTEGRITY_PER_MASS = 0.25

--[[
	The most buoyancy a fully-flooded hull loses. 0.35, and the ceiling matters more than the value.

	Flooding is modelled as LOST LIFT rather than as added mass, because added mass changes the assembly's
	weight and every derived constant (stiffness, damping, the force ceiling) was solved for the mass the
	spec declares. Scaling the lift instead leaves all of those intact and still does the visible thing: she
	sits lower, and the freeboard the sea states were chosen against (3 studs, see `Vessel`) starts letting
	green water aboard.

	🔴 WHY IT IS CAPPED WELL BELOW 1.0. At full flooding the hull must still float. A vessel that sinks
	because of flooding alone would take the loss decision away from the integrity pool - two systems racing
	to end the run, with the tuned one usually losing. Flooding makes her wallow and take water over the
	deck; INTEGRITY is what decides whether she is lost, and it is the only thing that does.

	MEASURED at 100% flooding (job 022 validation), against a full-lift resting Y of 0.70:

	    Light Swell   floats at  0.39   ->  0.31 studs lower
	    Storm         floats at -0.45   ->  1.15 studs lower, riding a 4.2-stud bob

	So in a calm sea she is visibly down but dry, and in a Storm sea she is a third of her freeboard lower
	with green water coming aboard - which is the intended shape, and it is not what I estimated when writing
	this (0.6 studs, sea unspecified). The equilibrium argument gives ~1.0 studs; the real figure depends on
	the sea, because the float points spend part of each wave out of the water where there is no lift to lose.

	Verified in the same session that the spring still CONVERGES at this setting: 62 seconds at full flooding
	in a Storm sea gave amplitude 4.28 -> 4.27 across five windows (growth 0.999) with the mean holding, so
	removing 35% of the lift does not cost the damping its authority.
]]
VesselDamage.MAX_FLOODING_LIFT_LOSS = 0.35

--[[
	THE FAULT LADDER.

	Fired at fractions of integrity LOST, and the order is designed rather than random.

	    radar     you lose the number. The storm becomes something you feel instead of something you read.
	    generator you lose the light. The dark gets darker, and the deck stops being legible.
	    engine    you lose the ability to run, briefly. This is the moment the crew finds out whether they
	              left themselves any margin.
	    breach    you lose the floor. Flooding starts and does not stop until somebody works it.

	🔴 DETERMINISTIC, NOT RANDOMISED, and that is a decision rather than a shortcut.

	A random order makes decision 0014's 30-60 second target unmeasurable - the same run would end at wildly
	different times depending on whether the engine cut early - and makes the failure unlearnable, so a crew
	cannot get better at The Wall. It also throws away the escalation above, which is the actual design: each
	step removes a different sense, and the last one starts a clock.

	A seeded per-run shuffle is the escalation if this ever reads as too scripted. It is not the default.
]]
export type FaultId = "radar" | "generator" | "engine" | "breach" | "steering"

export type Fault = {
	id: FaultId,
	--- Fraction of integrity LOST at which it fires.
	at: number,
	label: string,
	--- False while nothing in the game can act on it yet. Honest, and it drives the report.
	real: boolean,
}

local LADDER: { Fault } = {
	{ id = "radar", at = 0.20, label = "Radar down", real = false },
	{ id = "generator", at = 0.40, label = "Generator fault", real = false },
	{ id = "engine", at = 0.60, label = "Engine cut", real = true },
	{ id = "breach", at = 0.75, label = "Hull breach", real = true },
}
VesselDamage.LADDER = LADDER

--- Seconds the engine stays dead when it cuts. Long enough to be frightening, short enough to survive.
VesselDamage.ENGINE_CUT_SECONDS = 8

--[[
	`steering` is deliberately NOT on the ladder above.

	It is a lightning-strike and collision fault rather than an exposure one - the front does not
	progressively bend a rudder. It exists as an inflictable fault so the admin panel can test it, and so
	group 05's enemies and the storm's rare strike effects have something to reach for.

	It is also the fault that earns its keep today. Two of the four the intake named cannot bite yet (see
	`real` above), and this is the one that proves the machinery does something a driver can FEEL: at 45%
	authority she still answers the wheel, but the turn takes more than twice as long to build, which in a
	sea that is throwing her around is the difference between holding north and not.
]]
--- Rudder authority retained while steering is damaged. She answers the wheel, slowly.
VesselDamage.STEERING_AUTHORITY = 0.45
--- Flooding gained per second while a breach is open, as a fraction. 0.06 = fully flooded in ~17s.
VesselDamage.FLOODING_RATE = 0.06

--[[
	Flooding pumped out per second once no breach is open. Deliberately SLOWER than it comes in.

	0.02 against 0.06 means a breach is a setback that outlives the fixing of it - fifty seconds to pump dry
	what took seventeen to take on. Symmetric rates would make a breach a brief inconvenience, and the whole
	point of the fault ladder's last rung is that it starts a clock the crew cannot simply cancel.
]]
VesselDamage.FLOODING_DRAIN_RATE = 0.02
--- Integrity returned by one completed damage-control action, as a fraction of the pool.
VesselDamage.REPAIR_FRACTION = 0.12

--[[
	CAPSIZE. The second failure state, and the one `VesselServer` explicitly left to this job:

	  "past roughly 90 degrees of heel the float points leave the water and hydrostatics loses its lever, so
	   a full capsize is unrecoverable. That is arguably correct for a small craft in The Wall, and capsizing
	   belongs to the storm-damage job as a real failure state rather than being papered over by a
	   constraint here."

	100 degrees rather than 90, held for 4 seconds rather than instantly. Both guards matter: 90 is reachable
	by a violent wave in a Storm sea that the hull then rights itself from, and an instant trigger would end
	a run on a single frame's worth of solver noise. Past 100 and still there four seconds later, she is not
	coming back - hydrostatics has no lever and nothing else is going to supply one.
]]
VesselDamage.CAPSIZE_DEGREES = 100
VesselDamage.CAPSIZE_SECONDS = 4

--[[
	The integrity pool this hull carries. Derived from mass; see INTEGRITY_PER_MASS.
]]
function VesselDamage.integrityFor(mass: number): number
	return mass * VesselDamage.INTEGRITY_PER_MASS
end

--[[
	Integrity lost per second at a given exposure. Squared - see the header.

	Note what happens at exposure 1: `integrityMax / survivability`, exactly. The seconds a spec declares are
	the seconds a stopwatch reads, which is the whole point of stating toughness in seconds.
]]
function VesselDamage.damageRate(integrityMax: number, survivability: number, exposure: number): number
	if exposure <= 0 then
		return 0
	end
	local e = math.clamp(exposure, 0, 1)
	return (integrityMax / math.max(survivability, 1)) * e * e
end

--[[
	Which faults should be active at a given fraction of integrity lost.

	Returns the ladder entries at or below the loss, so it is a pure function of state rather than a set of
	edge-triggered events. That matters for repair: clearing a fault has to be able to STICK even though the
	hull is still below the threshold that caused it, or damage control would be undone by the next frame.
	The caller therefore uses this to decide what to FIRE, once each, not what should currently be true.
]]
function VesselDamage.faultsAt(lostFraction: number): { Fault }
	local out = {}
	for _, fault in ipairs(LADDER) do
		if lostFraction >= fault.at then
			table.insert(out, fault)
		end
	end
	return out
end

--- The multiplier applied to each buoyancy point's lift at a given flooding level.
function VesselDamage.floodingLiftFactor(flooding: number): number
	local f = math.clamp(flooding, 0, 1)
	return 1 - f * VesselDamage.MAX_FLOODING_LIFT_LOSS
end

--[[
	Is the hull past the capsize angle? Returns the tilt in degrees so the caller can hold its own timer.

	`UpVector.Y` is the cosine of the tilt from level: 1 upright, 0 on her beam ends, -1 fully inverted. The
	clamp is not decoration - floating-point drift puts it a hair outside [-1, 1] and `acos` returns NaN,
	which would silently disable the capsize check rather than erroring.
]]
function VesselDamage.tiltDegrees(upVectorY: number): number
	return math.deg(math.acos(math.clamp(upVectorY, -1, 1)))
end

--[[
	Seconds until the pool empties at the current rate, or nil if it is not emptying.

	For the report and for the survival test. A crew cannot see this number and should not - it is the thing
	the storm is supposed to make them guess at.
]]
function VesselDamage.secondsToLoss(integrity: number, ratePerSecond: number): number?
	if ratePerSecond <= 0 then
		return nil
	end
	return integrity / ratePerSecond
end

return VesselDamage
