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
--[[
	🔴 HARD CEILING ON WHAT BUOYANCY MAY EVER APPLY, as a multiple of the hull's own weight.

	This exists because the vessel DESTROYED ITSELF once, and the cause is worth recording in full.

	A zero-blend sea change (the panel's "snap, no blend" tool) moved the wave amplitude from Dead Calm's 0.15
	to Storm's 4.5 in a single frame. The hull found itself several studs underwater instantly, the stiff
	spring produced an enormous impulse, the explicit integration diverged over a few frames, and the engine
	removed the whole assembly - `Parent` became nil with no `Destroying` event, exactly the failure the
	physics guidance describes for an exploding assembly.

	The lesson is not "do not snap the sea". The sea is allowed to do whatever it likes; a spring-damper that
	can be driven to destruction by its own input is simply not finished. So the force is clamped to something
	physically sufficient and numerically safe:

	  * 3x weight is far more than needed to right a swamped hull (it accelerates at 2g),
	  * and it is small enough that no single frame can impart a velocity the next frame cannot absorb.
]]
VesselPhysics.MAX_FORCE_WEIGHTS = 3

--[[
	Ceiling on the velocity fed to the damping term.

	Damping is `-velocity * D`, so a spike in velocity produces a proportional spike in force - which is the
	mechanism by which a diverging oscillation feeds itself. Clamping the velocity breaks that loop while
	leaving normal motion (a few studs per second) completely untouched.
]]
VesselPhysics.MAX_DAMPED_VELOCITY = 60

function VesselPhysics.floatForce(sample: FloatSample, stiffness: number, damping: number, maxDepth: number): number
	--[[
		Reject non-finite input before it can propagate. A NaN submersion - from a wave field sampled at a
		NaN position, say - would otherwise become a NaN force, and a NaN in the solver removes the assembly
		rather than reporting anything.
	]]
	if sample.submersion ~= sample.submersion or sample.verticalVelocity ~= sample.verticalVelocity then
		return 0
	end

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
		-- velocity clamped, so a spike cannot produce a damping force that feeds the next spike
		local v = math.clamp(sample.verticalVelocity, -VesselPhysics.MAX_DAMPED_VELOCITY, VesselPhysics.MAX_DAMPED_VELOCITY)
		damped = -v * damping
	end

	return spring + damped
end

--[[
	The same force, with the hard ceiling applied. THIS is what the server should call.

	Kept as a separate function so `floatForce` stays a clean statement of the physics and the safety limit is
	visible as a deliberate, separate act rather than buried in the maths.
]]
function VesselPhysics.clampedFloatForce(
	sample: FloatSample,
	stiffness: number,
	damping: number,
	maxDepth: number,
	weight: number,
	points: number
): number
	local raw = VesselPhysics.floatForce(sample, stiffness, damping, maxDepth)
	local ceiling = (weight / math.max(points, 1)) * VesselPhysics.MAX_FORCE_WEIGHTS
	if raw ~= raw then
		return 0
	end
	return math.clamp(raw, -ceiling, ceiling)
end

--[[
	Drag coefficient that makes full thrust settle at `cruise`.

	Quadratic drag, because that is what water does and because it gives a naturally firm top speed rather
	than a linear ramp that has to be capped by hand. At terminal velocity thrust equals drag:

	    thrust = c * cruise^2   =>   c = thrust / cruise^2

	Deriving it means `cruise` in the spec is a PROMISE the physics keeps, not a hope. Change the number and
	the boat actually settles there.
]]
--[[
	Fraction of the drag at cruise that is LINEAR rather than quadratic.

	Pure quadratic drag decays asymptotically, so the hull never actually stops - simulated, she took 78
	seconds to come to rest from cruise, spending most of it crawling. That is not "a boat glides", it is a
	boat that will not park.

	Real water resistance has both terms: quadratic (form drag) dominates at speed, linear (viscous) at low
	speed. Splitting them makes the coast finite without touching the top speed, because both are derived so
	their SUM equals thrust exactly at cruise.
]]
VesselPhysics.LINEAR_DRAG_SHARE = 0.25

--- Quadratic coefficient. Carries `1 - LINEAR_DRAG_SHARE` of the drag at cruise.
function VesselPhysics.dragCoefficient(thrust: number, cruise: number): number
	return (1 - VesselPhysics.LINEAR_DRAG_SHARE) * thrust / math.max(cruise * cruise, 0.01)
end

--- Linear coefficient. Carries the rest, and is what actually brings her to a stop.
function VesselPhysics.linearDrag(thrust: number, cruise: number): number
	return VesselPhysics.LINEAR_DRAG_SHARE * thrust / math.max(cruise, 0.01)
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

function VesselPhysics.driveForce(
	throttle: number,
	forwardSpeed: number,
	thrust: number,
	drag: number,
	linear: number?
): number
	local t = math.clamp(throttle, -1, 1)
	local applied = if t >= 0 then t * thrust else t * thrust * VesselPhysics.REVERSE_FRACTION
	--[[
		Drag always opposes MOTION, never the throttle. That is what makes releasing the throttle a coast
		rather than a brake, and it is most of what will make a heavier hull feel heavy later.

		Two terms: quadratic dominates at speed, linear brings her to an actual stop.
	]]
	local speed = math.abs(forwardSpeed)
	local lin = linear or 0
	local resist = -math.sign(forwardSpeed) * (drag * speed * speed + lin * speed)
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
	--[[
		🔴 SUB-LINEAR, and this is what makes the turn read as a boat.

		With a LINEAR ramp, yaw rate is proportional to speed - so turn radius (speed / rate) is CONSTANT.
		Measured 33 studs at every speed from 5 to 18, which is under one boat length and identical whether
		crawling or flat out. The boat system doc asks for the opposite: "wider turns at high speed".

		Raising the ratio to a power below 1 makes rate grow slower than speed, so the radius WIDENS as she
		gains way - while still leaving almost no authority at rest, because a rudder needs water moving past
		it. 0.65 gives roughly 32 studs of radius at a crawl and 60 at cruise.
	]]
	local rampIn = math.min(speed / math.max(cruise, 0.01), 1) ^ 0.65
	-- above cruise, authority bleeds off - fast means committed
	local excess = math.max(speed - cruise, 0) / math.max(cruise, 0.01)
	local bleed = 1 / (1 + excess * 0.8)
	--[[
		Reversing inverts the steering, as a real rudder does. Kept because it is correct and because
		backing a boat off a shoal being awkward is good, not a bug to paper over.
	]]
	local direction = if forwardSpeed < -0.5 then -1 else 1
	--[[
		🔴 NEGATED, because Roblox's Y rotation is counter-clockwise from above.

		A positive angular velocity about +Y rotates the forward vector (which is -Z) toward -X, i.e. to PORT.
		So sending steer = +1 for "right" produced a turn to the LEFT. Steering was inverted by construction,
		and no amount of tuning would have shown it - only driving it would, which is exactly what I failed to
		do before handing it over.
	]]
	return -s * turnRate * rampIn * bleed * direction
end

--[[
	🔴 LATERAL GRIP - the missing system that made her "turn on the spot but keep going straight".

	A hull refuses to move sideways. That is what a keel IS, and it is what converts a change of HEADING into
	a change of DIRECTION. Without it, yawing the hull merely rotates it while momentum carries the boat dead
	ahead - it crabs sideways down its original course, nose pointing somewhere else entirely.

	I had no lateral resistance whatsoever. Forward drag existed, sideways drag did not.

	Modelled as a time constant rather than a coefficient, because that is the quantity with meaning: `grip`
	is roughly how many seconds it takes to kill sideways motion. Force = mass / grip x lateralSpeed, so a
	smaller number grips harder.

	    0.3   speedboat, bites hard, almost no drift
	    0.6   working launch - follows her nose with a little slip
	    1.5   barge, slides through turns

	Deriving it from mass means the same number behaves the same way on a cutter, which is the whole point of
	the kit.
]]
function VesselPhysics.lateralForce(lateralSpeed: number, mass: number, grip: number): number
	if lateralSpeed ~= lateralSpeed then
		return 0
	end
	return -(mass / math.max(grip, 0.05)) * lateralSpeed
end

--[[
	🔴 THE RUDDER. A TORQUE, not a commanded yaw rate.

	This replaced an `AngularVelocity`, and the reason is the whole feel of the boat.

	`AngularVelocity` is a SERVO: it drives to a target rate with up to MaxTorque, so the instant the wheel
	goes over the hull is already rotating at the full commanded rate. There is no build-up, no rudder lag,
	and no dependence on the hull's own resistance to turning. The rotation is IMPOSED rather than earned,
	and that is precisely what "it just rotates on the spot" feels like. The boat system doc asks for a
	"controlled force-based boat controller" and this was not one.

	A real rudder applies a torque; the yaw rate that results is a balance between that torque and the hull's
	yaw damping.

	--------------------------------------------------------------------------------------------------
	WHY BOTH TERMS SCALE WITH v^2

	Rudder force scales with the square of water speed - it is a foil, and no flow means no force. So does
	hydrodynamic yaw damping, for the same reason.

	That pairing is what produces the behaviour the doc asks for, and it falls out rather than being forced:

	    steady yaw rate = rudderTorque / yawDamping   -> both scale with v^2, so the RATE is
	                                                     roughly speed-independent
	    turn radius     = speed / yaw rate            -> therefore GROWS LINEARLY WITH SPEED

	"Wider turns at high speed" for free. A constant damping term would have given the opposite - radius
	shrinking as she sped up, which is a car, not a boat.

	`DAMP_FLOOR` keeps a little damping at rest so the hull cannot be spun on the spot by a rudder that has no
	water flowing past it - "poor turning while nearly stationary", also from the doc.
]]
VesselPhysics.DAMP_FLOOR = 0.15

--- Torque the rudder makes. Scales with v^2, because a foil with no flow does nothing.
function VesselPhysics.rudderTorque(steer: number, forwardSpeed: number, cruise: number, authority: number): number
	local s = math.clamp(steer, -1, 1)
	local ratio = math.clamp(math.abs(forwardSpeed) / math.max(cruise, 0.01), 0, 1.4)
	--[[
		Reversing inverts the rudder, exactly as a real one does - the flow arrives from the other side. Kept
		because it is true, and because backing a boat off a shoal being awkward is good.
	]]
	local direction = if forwardSpeed < -0.5 then -1 else 1
	-- negated: positive rotation about +Y is counter-clockwise from above, so steer right needs a negative rate
	return -s * authority * ratio * ratio * direction
end

--[[
	Yaw damping: the hull resisting rotation. This is what LIMITS the turn rate rather than a servo target.

	Also gives the rudder its LAG, which is most of the feel: the time constant is inertia / damping, so the
	yaw builds over a second or so instead of snapping on.
]]
function VesselPhysics.yawDamping(yawRate: number, forwardSpeed: number, cruise: number, damping: number): number
	local ratio = math.clamp(math.abs(forwardSpeed) / math.max(cruise, 0.01), 0, 1.4)
	local coefficient = damping * (VesselPhysics.DAMP_FLOOR + (1 - VesselPhysics.DAMP_FLOOR) * ratio * ratio)
	return -yawRate * coefficient
end

--[[
	🔴 HEEL IN A TURN - and it is TWO OPPOSING MOMENTS, which is what makes it look alive.

	Researched rather than guessed (MARIN, "Heel Angles in Turn and Passenger Safety"; ScienceDirect on heel
	angle). A ship in a turn does not simply lean one way:

	  * TRANSIENT: the rudder force acts before the hull's hydrodynamic side force has built up, and it acts
	    BELOW the centre of gravity - so she first heels INWARD, into the turn. The maximum heel of the whole
	    manoeuvre happens here.
	  * STEADY: once the rate of turn settles, centrifugal force at the centre of gravity - which is ABOVE the
	    centre of lateral resistance - takes over and she heels OUTWARD.

	This falls out naturally here rather than needing to be scripted, and that is the pleasing part: the
	rudder torque appears the instant the wheel moves, while the yaw rate takes ~1.3s to build. So the inward
	flick genuinely precedes the outward settle, for the same reason it does on a real hull.

	Returns a roll moment. Positive = heel to starboard.
]]
function VesselPhysics.heelMoment(
	rudderTorque: number,
	yawRate: number,
	forwardSpeed: number,
	rudderHeel: number,
	centrifugalHeel: number
): number
	--[[
		Rudder term: acts immediately, heels INTO the turn. A negative rudder torque is a turn to starboard
		(see rudderTorque), and heeling into a starboard turn means heeling to starboard - hence the negation.
	]]
	local transient = -rudderTorque * rudderHeel
	--[[
		Centrifugal term: builds with the turn, heels OUT of it. Proportional to yawRate * speed, which is
		the actual centripetal acceleration, so it grows exactly as the turn tightens.
	]]
	local steady = yawRate * forwardSpeed * centrifugalHeel
	return transient + steady
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
