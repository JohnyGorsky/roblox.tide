--!strict
--[[
	LightningServer - decides when the sky goes off, and tells everybody at once.

	Feature: docs/features/0003-storm-front/  ·  job 018

	Separate from `WorldTick` on purpose. The world tick exists to compose the LOOK in a fixed order, and
	its whole value is that the order is unambiguous. Lightning is an event stream with its own cadence and
	nothing downstream depends on it, so folding it in would only make the tick's contract muddier.

	--------------------------------------------------------------------------------------------------
	WHY THE SERVER ROLLS THE DICE

	So the crew sees the same strike. A per-client roll is cheaper and would quietly destroy the only
	moment in the storm that two players can point at together.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lightning = require(ReplicatedStorage:WaitForChild("Lightning"))

local remote = ReplicatedStorage:FindFirstChild("LightningRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "LightningRemote"
	remote.Parent = ReplicatedStorage
end
local strikeRemote = remote :: RemoteEvent

--[[
	Ship systems a close strike can disrupt, from the storm system doc.

	Published as an attribute and nothing more. None of these systems EXIST yet - radar is group 09,
	the generator is group 02 - so this writes the signal and lets them read it when they arrive. Faking the
	effects now would mean writing the disruption twice and getting a "working" feature that does nothing.
]]
local FAULTS = { "radar", "generator", "lights" }
local FAULT_CHANCE = 0.35 -- of a CLOSE strike, so most near misses are merely loud
local ATTR_FAULT = "LightningFault"
local ATTR_FAULT_AT = "LightningFaultAt"

local ATTR_LAST_STRIKE = "LastLightningAt" -- for the admin panel, and for anything that wants "recently?"

--[[
	Distance distribution, biased nearer as the front closes.

	`bias` squashes the roll toward the near end - at intensity 2 strikes are mostly far-off flickers on the
	horizon, at intensity 4 they are overhead. Using one distribution for all intensities made the far ones
	feel identical to the near ones, which wasted the only escalation this effect has.
]]
local function rollDistance(intensity: number): number
	local bias = math.clamp((intensity - Lightning.MIN_INTENSITY) / 2, 0, 1)
	local roll = math.random() ^ (1 + bias * 2.2)
	return Lightning.DISTANCE_NEAR + roll * (Lightning.DISTANCE_FAR - Lightning.DISTANCE_NEAR)
end

local function rollStrike(intensity: number): Lightning.Strike
	local distance = rollDistance(intensity)
	local spread = (math.random() - 0.5) * 2 * Lightning.BEARING_SPREAD
	local strike: Lightning.Strike = {
		bearing = (Lightning.ASTERN_BEARING + spread) % 360,
		distance = distance,
		magnitude = math.clamp(0.35 + math.random() * 0.65, 0, 1),
		at = workspace:GetServerTimeNow(),
		fault = nil,
	}
	if distance <= Lightning.CLOSE_DISTANCE and math.random() < FAULT_CHANCE then
		strike.fault = FAULTS[math.random(1, #FAULTS)]
	end
	return strike
end

local function fire(strike: Lightning.Strike)
	workspace:SetAttribute(ATTR_LAST_STRIKE, strike.at)
	if strike.fault then
		workspace:SetAttribute(ATTR_FAULT, strike.fault)
		workspace:SetAttribute(ATTR_FAULT_AT, strike.at)
	end
	strikeRemote:FireAllClients(strike)
end

--- Exposed so the admin panel can force a strike without waiting for the dice.
_G.TideLightningFire = fire
_G.TideLightningRoll = rollStrike

--[[
	The roll.

	Poisson-ish: each tick, probability = rate * dt. At 22 strikes/minute and a 0.5s tick that is a 0.18
	chance per tick, so strikes cluster naturally instead of arriving on a metronome - which is what a real
	storm does, and what makes the quiet gaps between them feel like held breath.

	Ticked faster than the world tick because a 1 Hz roll cannot place a strike more precisely than the
	nearest second, and at high rates that quantisation is audible as a rhythm.
]]
local TICK = 0.5
local accumulated = 0

RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	local step = accumulated
	accumulated = 0

	local intensity = workspace:GetAttribute("StormIntensity")
	if typeof(intensity) ~= "number" or intensity < Lightning.MIN_INTENSITY then
		return
	end

	-- Time scale speeds the storm up for testing; lightning has to keep pace or a compressed approach
	-- arrives in an eerie silence (see WorldTick's TIME SCALE note).
	local scale = workspace:GetAttribute("TimeScale")
	scale = if typeof(scale) == "number" then math.clamp(scale, 0, 60) else 1

	local perSecond = Lightning.ratePerMinute(intensity) / 60
	if math.random() < perSecond * step * scale then
		fire(rollStrike(intensity))
	end
end)

print(("[LIGHTNING] armed. Silent below storm intensity %d; %d strikes/min inside The Wall.")
	:format(Lightning.MIN_INTENSITY, Lightning.ratePerMinute(4)))
