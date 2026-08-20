--!strict
--[[
	VesselPhysics - buoyancy, thrust and steering. Pure maths, no instances.

	Feature: GAME-0001  ·  decision 0022  ·  job 021

	--------------------------------------------------------------------------------------------------
	WHY THIS IS PURE

	Nothing here touches a Part, a Constraint or the DataModel. It takes numbers and returns forces.

	Two reasons, and the first is the important one. A spring-damper cannot honestly be verified by looking at
	it - the failure mode is ENERGY GAIN, which looks completely fine for ten seconds and then bounces the
	boat off the map. Pure functions can be fed a fake state in a loop and the resulting amplitude measured,
	which is the only way to know it converges.

	Second: decision 0022 keeps client-side buoyancy as an escape hatch if helm feel demands it. If the maths
	is pure, that move is a change of caller rather than a rewrite.

	--------------------------------------------------------------------------------------------------
	🔴 STIFFNESS IS DERIVED FROM MASS AND DRAFT. NEVER AUTHORED.

	This is what makes decision 0009's kit real rather than nominal. At rest the total lift must equal the
	weight:

	    K x draft x pointCount  =  mass x gravity
	                          =>
	    K = (mass x gravity) / (draft x pointCount)

	So a vessel declares how deep it should SIT - a design statement anybody can make from a reference photo -
	and the spring constant falls out. A cutter with twenty times the mass floats correctly on the first
	attempt with no new numbers. The moment K is hand-tuned per hull, there is no kit: there is one boat and
	six copies of it.

	Damping is derived the same way, as a fraction of critical damping for the mass it is actually holding up.

	--------------------------------------------------------------------------------------------------
	🔴 THE BUG THIS MODULE EXISTS TO NOT HAVE

	From the Jungle boat, via the roblox-physics skill. Buoyancy is `max(spring, 0)` because water pushes up
	and never pulls down. If the DAMPING is computed inside that clamp, it disappears at exactly the moment
	the hull rises above the surface - spring goes negative, clamps to zero, and takes the damping with it.

	Energy then never leaves the system. The boat is rock-stable at rest and bounces higher and higher once
	driven, which reads as a mysterious tuning problem rather than a sign error.

	So: `spring` is clamped. `damping` is added AFTERWARDS, outside the clamp, always.
]]

local VesselPhysics = {}

--- Roblox's default. Read from Workspace at call time in the server loop; this is the fallback.
local GRAVITY = 196.2

--[[
	Damping as a fraction of critical.

	1.0 would return to level without overshooting at all, which reads as a boat on rails. 0.55 lets it
	settle with a little motion left, which is what a hull actually does - and crucially it is high enough to
	have real authority. Damping much weaker than the spring cannot remove energy fast enough and the boat
	limit-cycles for a different reason than the sign bug above.
]]
VesselPhysics.DAMPING_RATIO = 0.55

--[[
	Stiffness per buoyancy point, from the spec.

	`mass` is the EMPTY hull's mass, taken from the spec rather than read live from `AssemblyMass`.

	That is a deliberate gameplay choice: deriving K from live mass would make the vessel float at its
	declared draft no matter how much cargo it carried, which is both unrealistic and throws away a hook.
	Deriving it from the empty mass means **loading a vessel makes it ride lower** - and a Trawler that
	visibly settles as it fills is a better mechanic than a number in a menu.
]]
function VesselPhysics.stiffness(mass: number, draft: number, points: number, gravity: number?): number
	local g = gravity or GRAVITY
	return (mass * g) / (math.max(draft, 0.01) * math.max(points, 1))
end

--[[
	Damping per point, as a fraction of critical for the share of the mass this point holds.

	Critical damping for a spring-mass system is `2 * sqrt(k * m)`. Each point holds `mass/points` and has
	stiffness `k`, so its critical value follows from its own share.
]]
function VesselPhysics.damping(stiffness: number, mass: number, points: number): number
	local share = mass / math.max(points, 1)
	return VesselPhysics.DAMPING_RATIO * 2 * math.sqrt(stiffness * share)
end

export type FloatSample = {
	--- How far this point is below the wave surface. Negative = out of the water.
	submersion: number,
	--- Vertical speed of the hull at this point. Positive = rising.
	verticalVelocity: number,
}

--[[
	Upward force for ONE buoyancy point.

	    spring   = clamp(submersion, 0, maxDepth) * K     water pushes up, never pulls down
	    damping   = -verticalVelocity * D                  opposes motion, in BOTH directions
	    force    = spring + damping                       <- added OUTSIDE the clamp. See the header.

	`maxDepth` limits how much lift a fully-submerged point can produce. Without it, a hull that gets thrown
	deep by a storm wave is launched back out like a beach ball - the spring is linear and a 7-stud submersion
	would produce four times the force needed to hold the boat up. Clamping at roughly twice the draft keeps
	green water on deck survivable rather than comic.
]]
function VesselPhysics.floatForce(sample: FloatSample, stiffness: number, damping: number, maxDepth: number): number
	local depth = math.clamp(sample.submersion, 0, maxDepth)
	local spring = depth * stiffness

	--[[
		🔴 OUTSIDE THE CLAMP.

		Damping applies whenever the point is anywhere near the water, including while it is RISING OUT of
		it - which is precisely when the clamped spring is zero. Putting this inside the `math.max` above is
		the Jungle bug, and the boat bounces forever while driven.

		It is gated on being near the surface rather than submerged, so a hull thrown clear of the water is
		in free fall (correct) but one skimming the surface is still damped (also correct).
	]]
	local damped = 0
	if sample.submersion > -maxDepth then
		damped = -sample.verticalVelocity * damping
	end

	return spring + damped
end

--[[
	Drag coefficient that makes full thrust settle at `cruise`.

	Quadratic drag, because that is what water does and because it gives a naturally firm top speed rather
	than a linear ramp that has to be capped by hand. At terminal velocity thrust equals drag:

	    thrust = c * cruise^2   =>   c = thrust / cruise^2

	Deriving it means `cruise` in the spec is a PROMISE the physics keeps, not a hope. Change the number and
	the boat actually settles there.
]]
function VesselPhysics.dragCoefficient(thrust: number, cruise: number): number
	return thrust / math.max(cruise * cruise, 0.01)
end

--[[
	Net forward force: thrust minus drag, along the hull's heading.

	Drag opposes the CURRENT velocity rather than the throttle, so releasing the throttle coasts to a stop
	instead of braking - which is most of what makes a boat feel like a boat, and is why stopping distance
	rather than top speed is what makes a big vessel feel heavy.

	Reverse is deliberately weaker: `REVERSE_FRACTION` of forward thrust. A launch backing off a beach should
	be awkward.
]]
VesselPhysics.REVERSE_FRACTION = 0.4

function VesselPhysics.driveForce(throttle: number, forwardSpeed: number, thrust: number, drag: number): number
	local t = math.clamp(throttle, -1, 1)
	local applied = if t >= 0 then t * thrust else t * thrust * VesselPhysics.REVERSE_FRACTION
	-- drag always opposes motion, and scales with the square of speed
	local resist = -math.sign(forwardSpeed) * drag * forwardSpeed * forwardSpeed
	return applied + resist
end

--[[
	Yaw rate for a steering input.

	🔴 SCALED BY SPEED, and this is the whole character of the handling.

	The boat system doc asks for exactly this: "poor turning while nearly stationary, reasonable turn at
	cruise, wider turns at high speed". A rudder does nothing without water flowing past it, so:

	    at rest      almost no authority - you cannot pivot in place
	    at cruise    full authority
	    above cruise falls away again, so going flat out means committing to a line

	`math.min(speed / cruise, 1)` gives the ramp in; the second term takes it back off above cruise.
]]
function VesselPhysics.yawRate(steer: number, forwardSpeed: number, cruise: number, turnRate: number): number
	local s = math.clamp(steer, -1, 1)
	local speed = math.abs(forwardSpeed)
	local rampIn = math.min(speed / math.max(cruise, 0.01), 1)
	-- above cruise, authority bleeds off - fast means committed
	local excess = math.max(speed - cruise, 0) / math.max(cruise, 0.01)
	local bleed = 1 / (1 + excess * 0.8)
	--[[
		Reversing inverts the steering, as a real rudder does. Kept because it is correct and because
		backing a boat off a shoal being awkward is good, not a bug to paper over.
	]]
	local direction = if forwardSpeed < -0.5 then -1 else 1
	return s * turnRate * rampIn * bleed * direction
end

--[[
	Fuel burned this step.

	Idle burn is deliberately non-zero: an engine left running costs fuel, so "turn it off while you loot" is
	a real decision rather than a free action. Full throttle is the spec's rate; idle is a fraction of it.
]]
VesselPhysics.IDLE_BURN_FRACTION = 0.15

function VesselPhysics.fuelUsed(throttle: number, dt: number, burnRate: number, engineOn: boolean): number
	if not engineOn then
		return 0
	end
	local demand = math.abs(math.clamp(throttle, -1, 1))
	local rate = burnRate * (VesselPhysics.IDLE_BURN_FRACTION + (1 - VesselPhysics.IDLE_BURN_FRACTION) * demand)
	return rate * dt
end

--[[
	A self-check on the derivation, callable from a test.

	Answers the one question that matters about the algebra: does a hull of this mass, with this many points
	at this draft, actually balance its own weight? If this drifts from 1.0 the vessel floats too high or sinks
	regardless of how the forces are applied.
]]
function VesselPhysics.equilibriumRatio(mass: number, draft: number, points: number, gravity: number?): number
	local g = gravity or GRAVITY
	local k = VesselPhysics.stiffness(mass, draft, points, g)
	local totalLift = k * draft * points
	return totalLift / (mass * g)
end

return VesselPhysics
