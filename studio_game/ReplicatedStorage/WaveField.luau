--!strict
--[[
	WaveField - the one answer to "where is the sea surface?"

	`HeightAt(x, z)` and `NormalAt(x, z)` are sampled by everything that has to sit on, bob in, or be
	thrown by the ocean: the vessel's buoyancy, floating debris, buoys, spray, the wake.

	Feature: docs/features/0014-wave-field/
	Manifest: docs/build/01-sea.md
	Sea states: ReplicatedStorage.SeaStates (the `wave` block)

	--------------------------------------------------------------------------------------------------
	WHY THIS EXISTS

	Roblox terrain water's waves are a RENDERING EFFECT. They animate the surface you look at and move
	nothing at all. So the sea has two independent truths:

	    visual swell   Terrain.WaterWaveSize / WaterWaveSpeed   - what the player watches
	    physical swell THIS MODULE                              - what moves the boat

	They must agree, or the hull visibly climbs crests that are not there. SeaStates carries one `wave`
	block per state so both truths read from the same table; this module is its consumer.

	--------------------------------------------------------------------------------------------------
	DETERMINISM - the load-bearing property

	Every client and the server must agree on the surface without exchanging a single byte about it. So:

	  * time comes from Workspace:GetServerTimeNow(), which is synchronised - NEVER os.clock(), tick(),
	    or a per-machine accumulator, all of which drift apart immediately;
	  * the wave set is derived from FIXED constants below, never from math.random(), which would give
	    every machine a different sea.

	If you add a wave, add it as a constant. The moment anything here becomes machine-dependent, boats
	desync and the bug looks like physics jitter rather than what it is.

	--------------------------------------------------------------------------------------------------
	APPLYING FORCES IS NOT THIS MODULE'S JOB

	This module answers questions. It moves nothing and applies no force. Buoyancy belongs to the boat
	controller (GAME-0001), which must read roblox-physics first - there are two logged traps that make a
	moving boat bounce forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local WaveField = {}

--[[
	Four waves summed. Enough for a sea that does not read as a single rolling sine, few enough to sample
	a dozen times a frame on a phone.

	All three tables are FIXED, deliberately. `ampMul` is normalised at load so the sum of the components
	equals the state's `amplitude` exactly - meaning the number in SeaStates is the real crest height, not
	an arbitrary scalar, which matters because that number gets calibrated against the rendered water.
]]
local WAVE_COUNT = 4
local LENGTH_MUL = { 1.00, 0.62, 0.41, 0.27 } -- shorter waves riding on the main swell
local AMP_MUL = { 1.00, 0.55, 0.30, 0.16 } -- normalised below
local PHASE = { 0.0, 1.7, 3.4, 5.1 } -- fixed offsets so components never align into one huge crest
local ANGLE_STEP = { 0.0, 0.7, -0.5, 1.3 } -- radians, scaled by directionSpread

local AMP_NORM: { number } = {}
do
	local total = 0
	for i = 1, WAVE_COUNT do
		total += AMP_MUL[i]
	end
	for i = 1, WAVE_COUNT do
		AMP_NORM[i] = AMP_MUL[i] / total
	end
end

-- The state the field currently describes. Set by the sea/storm system; defaults to the cruising sea.
local activeState: any = SeaStates.LightSwell

--[[
	Blending.

	A state change must not step the surface height - a floating object would be launched or submerged.
	So a change starts a blend and `HeightAt` interpolates through it. The sea *arrives*.
]]
local blendFrom: any = nil
local blendStartedAt = 0
local blendDuration = 0

local function now(): number
	-- Synchronised across server and all clients. This is the whole determinism story.
	return workspace:GetServerTimeNow()
end

--- Returns the wave spec to sample right now, interpolating if a blend is in flight.
local function currentWave(): any
	if not blendFrom or blendDuration <= 0 then
		return activeState.wave
	end
	local t = (now() - blendStartedAt) / blendDuration
	if t >= 1 then
		blendFrom = nil
		return activeState.wave
	end
	local a, b = blendFrom.wave, activeState.wave
	local function n(x: number, y: number): number
		return x + (y - x) * t
	end
	return {
		amplitude = n(a.amplitude, b.amplitude),
		length = n(a.length, b.length),
		speed = n(a.speed, b.speed),
		choppiness = n(a.choppiness, b.choppiness),
		directionSpread = n(a.directionSpread, b.directionSpread),
		directionDeg = n(a.directionDeg, b.directionDeg),
	}
end

--- Switch state, blending over `seconds` so nothing floating gets thrown.
function WaveField.setState(state: any, seconds: number?)
	if not state or not state.wave then
		return
	end
	local dur = seconds or 4
	if dur > 0 and activeState ~= state then
		blendFrom = activeState
		blendStartedAt = now()
		blendDuration = dur
	else
		blendFrom = nil
	end
	activeState = state
end

function WaveField.getState(): any
	return activeState
end

--[[
	Is this point even on the ocean?

	Outside the filled water the honest answer is "flat, at sea level" - never nan, never an extrapolated
	crest, because callers use this to decide where to float things.
]]
local function insideOcean(x: number, z: number): boolean
	local half = SeaStates.OCEAN_HALF_EXTENT
	return math.abs(x) <= half and math.abs(z) <= half
end

--[[
	Height of the surface at a world XZ.

	Sum of `WAVE_COUNT` travelling sines. `choppiness` sharpens the crests and flattens the troughs by
	biasing the sine through a power curve - a cheap stand-in for a true Gerstner displacement, which
	would also move points horizontally. Horizontal displacement is deliberately skipped: it costs an
	iterative solve to invert, and nothing here needs it, because we sample "height at a fixed XZ" rather
	than "where did this water particle go".
]]
function WaveField.HeightAt(x: number, z: number, atTime: number?): number
	local waterY = SeaStates.WATER_Y
	if not insideOcean(x, z) then
		return waterY
	end

	local w = currentWave()
	local t = atTime or now()
	local baseAngle = math.rad(w.directionDeg)
	local sum = 0

	for i = 1, WAVE_COUNT do
		local angle = baseAngle + ANGLE_STEP[i] * w.directionSpread
		local dirX, dirZ = math.sin(angle), math.cos(angle) -- 0 deg = +Z
		local length = math.max(w.length * LENGTH_MUL[i], 1)
		local k = (2 * math.pi) / length -- wavenumber
		local omega = k * w.speed -- crest travel
		local phase = (x * dirX + z * dirZ) * k - omega * t + PHASE[i]

		local s = math.sin(phase)
		if w.choppiness > 0 then
			-- Bias toward sharp crests / flat troughs. exponent 1 -> pure sine, higher -> peakier.
			local unit = (s + 1) * 0.5
			local exponent = 1 + w.choppiness * 1.5
			s = (unit ^ exponent) * 2 - 1
		end
		sum += s * (w.amplitude * AMP_NORM[i])
	end

	return waterY + sum
end

--[[
	Surface normal, for sitting a hull at the angle of the water.

	Central finite difference rather than an analytic derivative: the choppiness power curve makes the
	analytic form messy and easy to get subtly wrong, and four extra height samples is still cheap. Being
	obviously correct is worth more here than being clever.
]]
function WaveField.NormalAt(x: number, z: number, atTime: number?): Vector3
	if not insideOcean(x, z) then
		return Vector3.yAxis
	end
	local t = atTime or now()
	local d = 1.5 -- studs; below ~1 the difference is dominated by float noise
	local hL = WaveField.HeightAt(x - d, z, t)
	local hR = WaveField.HeightAt(x + d, z, t)
	local hB = WaveField.HeightAt(x, z - d, t)
	local hF = WaveField.HeightAt(x, z + d, t)
	-- Gradient -> normal. Negated X/Z because the normal tilts away from rising water.
	return Vector3.new(-(hR - hL) / (2 * d), 1, -(hF - hB) / (2 * d)).Unit
end

--- Convenience: the world position of the surface directly above/below a point.
function WaveField.SurfaceAt(x: number, z: number, atTime: number?): Vector3
	return Vector3.new(x, WaveField.HeightAt(x, z, atTime), z)
end

--[[
	How deep is this point below the surface? Negative means above water.
	The one call buoyancy will actually make.
]]
function WaveField.SubmersionAt(position: Vector3, atTime: number?): number
	return WaveField.HeightAt(position.X, position.Z, atTime) - position.Y
end

--[[
	Self-check, for the admin panel and tests.

	Returns the crest-to-trough range actually produced over a grid, which is the number to compare
	against the rendered water during calibration. If this disagrees with `amplitude * 2`, the
	normalisation above is wrong.
]]
function WaveField.measureRange(samples: number?, atTime: number?): (number, number, number)
	local n = samples or 24
	local t = atTime or now()
	local lo, hi = math.huge, -math.huge
	local step = (activeState.wave.length * 2) / n
	for i = 0, n do
		for j = 0, n do
			local h = WaveField.HeightAt(i * step, j * step, t)
			lo = math.min(lo, h)
			hi = math.max(hi, h)
		end
	end
	return lo, hi, hi - lo
end

return WaveField
