--!strict
--[[
	Expedition - what a run IS. Pure state model, no instances.

	Feature: GAME-0001 / GAME-0003  ·  decisions 0024, 0025  ·  job 023

	--------------------------------------------------------------------------------------------------
	THE SHAPE OF A RUN (decision 0024)

	    Boarding   the crew is ashore, the front is visible and STATIONARY. Five minutes of grace.
	    Running    the helm has been taken. The storm has a clock now.
	    Finished   the northing target was reached -> the finale
	    Lost       the vessel is gone, and `cause` says how

	Same purity rule as `VesselDamage` and `VesselPhysics`: this module computes and names, and
	`ExpeditionServer` is the only thing that touches instances or writes attributes. The interesting
	failures here are a progress measure that can be farmed and a grace period that can be re-armed, and
	both are cheaper to reason about in a file with no side effects.

	--------------------------------------------------------------------------------------------------
	🔴 PROGRESS IS NET NORTHING, NOT STORM DISTANCE

	The obvious measure is `StormDistance`, and it does not work. `StormFront.advance` ends with:

	    distance = math.min(distance, StormFront.START_DISTANCE)

	That cap exists so an early lead cannot become un-loseable - and it means the number STOPS RISING once
	the crew is 4,200 studs ahead. A crew could sail north for ten minutes and it would not move.

	So a run measures its own displacement: `hull.Z - startZ`.

	NET displacement, not accumulated northward deltas. `StormFront` deliberately counts only northward
	travel (running back south must not hand the storm distance twice), and copying that rule here would let
	a crew farm progress by oscillating north and south forever. Net Z cannot be farmed: going south costs
	exactly what going north earned.

	⚠️ If finding 0018 is ever revisited by RECENTRING the world on the vessel, `startZ` must be shifted by
	the same offset at every recentre, or the run's progress silently resets itself.
]]

local Expedition = {}

export type State = "Boarding" | "Running" | "Finished" | "Lost"
export type Cause = "northing" | "integrity" | "capsize" | "fuel" | "abandoned"

--[[
	Attribute names. Published by `ExpeditionServer`, read by the client beat and the admin panel.

	Deliberately NOT including the vessel's Z or its heading: decision 0014 forbids handing the crew a free
	sense of direction inside The Wall, and finding 0023 is the story of that leaking through a bookkeeping
	attribute nobody thought of as gameplay. `Northing` is a scalar distance travelled, which tells you how
	far you have come and nothing about which way is out.
]]
Expedition.ATTR = {
	state = "ExpeditionState",
	cause = "ExpeditionCause",
	northing = "ExpeditionNorthing",
	target = "ExpeditionTarget",
	runStarted = "RunStarted",
	over = "ExpeditionOver",
	overReason = "ExpeditionOverReason",
}

--[[
	THE NORTHING TARGET, and it is a placeholder.

	2400 studs is 133 seconds of pure running at the launch's cruise of 18 - about 73% of a full tank. It is
	deliberately short: it lets the whole loop be played and measured today.

	🔴 The real figure belongs to decision 0024's ~50-minute run, and it cannot be set here, because the
	corridor has to grow with it. `SeaStates.validateCorridorForTarget` states the rule:

	    OCEAN_EXTENT_Z.max  >=  target + the largest fogEnd

	Raise this without growing the water and a crew standing at the finish sees the ocean stop.
]]
Expedition.NORTHING_TARGET = 2400

--- Seconds of grace before the storm starts, for reference and for the panel. The gate is an event, not a
--- timer - the storm starts when the helm is taken, however long that takes.
Expedition.BOARDING_GRACE_HINT = 300

--- Net northing from a run's start. The whole progress measure.
function Expedition.northingOf(startZ: number, z: number): number
	return z - startZ
end

function Expedition.fractionOf(northing: number, target: number?): number
	local t = target or Expedition.NORTHING_TARGET
	if t <= 0 then
		return 1
	end
	return math.clamp(northing / t, 0, 1)
end

function Expedition.reachedTarget(northing: number, target: number?): boolean
	return northing >= (target or Expedition.NORTHING_TARGET)
end

--[[
	Is the run in a state where the storm should be advancing?

	🔴 ONE-WAY, AND THAT IS THE WHOLE POINT. The grace ends when the helm is first taken and never begins
	again. Two ways to get this wrong, both of which switch off the game's only pressure:

	  * clearing `runStarted` when the driver steps away from the helm - stand up, and the storm politely
	    waits for you
	  * letting a client raise or lower it

	So the flag is raised once, server-side, by the helm prompt, and this function only ever reads it.
]]
function Expedition.stormShouldAdvance(runStarted: boolean, over: boolean): boolean
	return runStarted and not over
end

--[[
	How a run ended, in the words the summary should use.

	`fuel` is not a separate failure PATH - a fuelless crew is killed by the storm like any other, and
	`integrity` is what actually reaches zero. It is a CAUSE, recorded so the summary can say "ran out of
	fuel" rather than "hull destroyed", because that is the story decision 0024 is built around: *we ran out
	of fuel just before it caught us*.
]]
Expedition.CAUSE_TEXT = {
	northing = "Made the northing - the finale begins",
	integrity = "The hull came apart inside the front",
	capsize = "Rolled over and did not come back",
	fuel = "Ran out of fuel, and the storm caught up",
	abandoned = "The crew abandoned her",
}

function Expedition.causeText(cause: Cause?): string
	return cause and (Expedition.CAUSE_TEXT :: any)[cause] or "unknown"
end

--[[
	The summary a run resolves into. Shape only - the server fills it and the lobby reads it out of
	`TeleportData` later (Planned 0002).

	Kept as a plain table with no metatable so it survives `SetTeleportData`, which serialises.
]]
export type Summary = {
	state: State,
	cause: Cause?,
	northing: number,
	target: number,
	seconds: number,
	fuelUsed: number,
	integrityLeft: number,
	faults: { string },
	stops: number,
}

function Expedition.blankSummary(target: number?): Summary
	return {
		state = "Boarding",
		cause = nil,
		northing = 0,
		target = target or Expedition.NORTHING_TARGET,
		seconds = 0,
		fuelUsed = 0,
		integrityLeft = 0,
		faults = {},
		stops = 0,
	}
end

function Expedition.report(s: Summary): string
	return table.concat({
		("state       %s%s"):format(s.state, s.cause and (" (" .. s.cause .. ")") or ""),
		("northing    %.0f / %.0f  (%.0f%%)"):format(s.northing, s.target,
			Expedition.fractionOf(s.northing, s.target) * 100),
		("elapsed     %.0f s"):format(s.seconds),
		("fuel used   %.1f"):format(s.fuelUsed),
		("hull left   %.0f"):format(s.integrityLeft),
		("faults      %s"):format(#s.faults > 0 and table.concat(s.faults, ", ") or "none"),
		("verdict     %s"):format(Expedition.causeText(s.cause)),
	}, "\n")
end

return Expedition
