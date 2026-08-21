--!strict
--[[
	ExpeditionServer - owns the run: its state, its progress, and how it ends.

	Feature: GAME-0001 / GAME-0003  ·  decisions 0024, 0025  ·  job 023

	--------------------------------------------------------------------------------------------------
	WHAT THIS OWNS, AND WHAT IT DOES NOT

	Owns   `ExpeditionState`, `ExpeditionCause`, `ExpeditionNorthing`, `ExpeditionTarget`, `ExpeditionOver`
	Reads  `VesselLost` / `VesselFuel` / `VesselIntegrity` from `VesselServer`, and the hull's Z
	Never  touches the storm's clock. That gate is raised by the helm prompt in `VesselServer` and read by
	       `WorldTick` - one writer, and this file is not it.

	🔴 ONE OWNER FOR `ExpeditionOver`. Job 022's `loseVessel` used to set it directly, as an admitted
	placeholder for a flow that did not exist. It exists now, so that write moved here: `VesselServer` says
	*the vessel is lost* and this decides *the run is over*. Two writers for one flag is how a run ends twice,
	or ends and then un-ends.

	--------------------------------------------------------------------------------------------------
	PROGRESS IS NET NORTHING - see the `Expedition` header for why it cannot be storm distance.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Expedition = require(ReplicatedStorage:WaitForChild("Expedition"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local ATTR = Expedition.ATTR

--[[
	Where arriving crew are put. The run opens ASHORE (decision 0024) - five minutes to look at the front,
	walk around, and get aboard. Spawning on the deck would delete the whole opening beat.

	The start island's plateau is at +12 (job 024), so a couple of studs above it.
]]
local ISLAND_SPAWN = Vector3.new(0, 15, 0)

local state = {
	startZ = nil :: number?,
	startedAt = nil :: number?,
	fuelAtStart = nil :: number?,
	resolved = false,
	summary = Expedition.blankSummary(),
}

local function num(name: string): number?
	local v = workspace:GetAttribute(name)
	return if typeof(v) == "number" then v else nil
end

local function hull(): BasePart?
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("VesselSpec") then
			--[[
				Found by ATTRIBUTE rather than by name or path. Finding 0020 is the story of a hardcoded
				instance path between two systems rotting silently and making the storm unbeatable; the spec
				attribute is set by `Vessel.build`, so it travels with the model whatever it is called.
			]]
			return child.PrimaryPart
		end
	end
	return nil
end

local function publish()
	workspace:SetAttribute(ATTR.state, state.summary.state)
	workspace:SetAttribute(ATTR.cause, state.summary.cause or "")
	workspace:SetAttribute(ATTR.northing, state.summary.northing)
	workspace:SetAttribute(ATTR.target, state.summary.target)
end

--[[
	WHY THE RUN ENDED, in the words the summary should use.

	`fuel` is the one that needs deciding rather than reading: a fuelless crew is killed by the storm exactly
	like any other crew, so `integrity` is what actually reaches zero. Decision 0024 wants the summary to say
	"ran out of fuel" because that is the story - *we ran out just before it caught us* - so the tank is
	checked at the moment of loss and it wins over the mechanical cause.
]]
local function causeOfLoss(): Expedition.Cause
	local reason = workspace:GetAttribute("ExpeditionOverReason")
	if typeof(reason) == "string" and reason:lower():find("capsiz") then
		return "capsize"
	end
	local fuel = num("VesselFuel")
	if fuel and fuel <= 0.01 then
		return "fuel"
	end
	return "integrity"
end

local function faultList(): { string }
	local out = {}
	for _, id in ipairs({ "radar", "generator", "engine", "breach", "steering" }) do
		if workspace:GetAttribute("VesselFault_" .. id) == true then
			table.insert(out, id)
		end
	end
	return out
end

local function resolve(newState: Expedition.State, cause: Expedition.Cause)
	if state.resolved then
		return
	end
	state.resolved = true

	local s = state.summary
	s.state = newState
	s.cause = cause
	s.seconds = state.startedAt and (workspace:GetServerTimeNow() - state.startedAt) or 0
	s.integrityLeft = num("VesselIntegrity") or 0
	s.faults = faultList()
	local fuelNow = num("VesselFuel") or 0
	s.fuelUsed = (state.fuelAtStart or fuelNow) - fuelNow

	workspace:SetAttribute(ATTR.over, true)
	publish()

	--[[
		🟡 THE RETURN IS NOT BUILT HERE. Planned 0002 owns the teleport home and the lobby's breakdown of
		this summary; job 023 ships the in-place beat and this resolution. So a resolved run currently ends
		with the world holding still and the summary published - which is playable and judgeable, and is not
		the finished flow. Do not build on `ExpeditionOver` as if it teleported anybody.
	]]
	print(("[EXPEDITION] %s - %s | northing %.0f/%.0f, %.0fs, hull %.0f, faults: %s")
		:format(newState:upper(), Expedition.causeText(cause), s.northing, s.target, s.seconds,
			s.integrityLeft, #s.faults > 0 and table.concat(s.faults, ",") or "none"))
end

--[[
	Reset to the boarding state. Called at startup and by the admin panel, never by a client.

	Deliberately clears the storm's gate too, so a fresh run gets its grace back - this is the ONE place
	allowed to lower `RunStarted`, and it is not reachable during a run.
]]
local function beginBoarding()
	state.startZ = nil
	state.startedAt = nil
	state.fuelAtStart = nil
	state.resolved = false
	state.summary = Expedition.blankSummary(Expedition.NORTHING_TARGET)
	workspace:SetAttribute(ATTR.runStarted, false)
	workspace:SetAttribute(ATTR.over, false)
	workspace:SetAttribute("ExpeditionOverReason", "")
	publish()

	local ok, msg = SeaStates.validateCorridorForTarget(state.summary.target)
	print(("[EXPEDITION] boarding. target %.0f studs of northing. corridor: %s")
		:format(state.summary.target, msg))
	if not ok then
		warn("[EXPEDITION] " .. msg)
	end
end

--- Put a player ashore. Only touches players who have no character, so the admin auto-spawn is not fought.
local function spawnAshore(player: Player)
	if player.Character then
		return
	end
	--[[
		`LoadCharacterAsync` rather than the deprecated `LoadCharacter`. It yields, which is fine here - this
		is called from `PlayerAdded` and from a deferred loop, never from the heartbeat.
	]]
	local ok = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.new(ISLAND_SPAWN)
	end
end

local step = 0
RunService.Heartbeat:Connect(function(dt)
	--[[
		Heartbeat, not RenderStepped - finding 0022 measured RenderStepped firing ZERO times in an unfocused
		Studio session while Heartbeat ran at 60 Hz. This is server-side anyway, but the habit matters.
	]]
	step += dt
	if step < 0.25 then
		return
	end
	step = 0

	if state.resolved then
		return
	end

	local h = hull()
	local runStarted = workspace:GetAttribute(ATTR.runStarted) == true

	-- The run begins the moment the helm is taken; capture the datum then, not at server start.
	if runStarted and not state.startZ then
		if not h then
			return
		end
		-- through a local for the same reason as below: a field read is not narrowed by having just assigned it
		local datum = h.Position.Z
		state.startZ = datum
		state.startedAt = workspace:GetServerTimeNow()
		state.fuelAtStart = num("VesselFuel") or 0
		state.summary.state = "Running"
		publish()
		print(("[EXPEDITION] running. datum Z=%.0f, target %.0f"):format(datum, state.summary.target))
	end

	--[[
		Bound into a local so the guard genuinely narrows it. Reading `state.startZ` again after the check
		is what the analyzer flagged, and it is right to: nothing stops another coroutine clearing it between
		the test and the use, and `northingOf` would then be called with nil.
	]]
	local startZ = state.startZ
	if not (runStarted and startZ and h) then
		return
	end

	state.summary.northing = Expedition.northingOf(startZ, h.Position.Z)
	publish()

	--[[
		THE PLACEHOLDER FINALE. Decision 0024 ends a run by defeating a hostile vessel, and there is no
		vessel to defeat yet (groups 05, 06). So reaching the northing resolves the run as finished, and the
		boss will slot in behind this same trigger.

		Written as its own branch rather than folded into the resolve call so that when the finale arrives,
		what changes here is one line - "start the finale" instead of "resolve" - and nothing else in the loop
		has to move.
	]]
	if Expedition.reachedTarget(state.summary.northing, state.summary.target) then
		resolve("Finished", "northing")
		return
	end

	if workspace:GetAttribute("VesselLost") == true then
		resolve("Lost", causeOfLoss())
	end
end)

Players.PlayerAdded:Connect(spawnAshore)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(spawnAshore, player)
end

beginBoarding()

--[[
	Exposed for the admin panel, same as `_G.TideVessel`. Server-side only; `_G` does not replicate and is
	not shared with an `execute_luau` probe either.
]]
_G.TideExpedition = {
	state = state,
	reset = beginBoarding,
	setTarget = function(target: number)
		state.summary.target = math.max(1, target)
		publish()
		local ok, msg = SeaStates.validateCorridorForTarget(state.summary.target)
		return ok, msg
	end,
	--[[
		Force an ending, for testing. Takes the cause so the summary can be checked for each of them without
		having to actually run out of fuel in a storm.
	]]
	force = function(newState: Expedition.State, cause: Expedition.Cause)
		resolve(newState, cause)
	end,
	startNow = function()
		workspace:SetAttribute(ATTR.runStarted, true)
	end,
	report = function(): string
		local h = hull()
		return table.concat({
			Expedition.report(state.summary),
			("runStarted  %s   over %s"):format(
				tostring(workspace:GetAttribute(ATTR.runStarted)), tostring(workspace:GetAttribute(ATTR.over))),
			("datum Z     %s   hull Z %s"):format(
				state.startZ and ("%.0f"):format(state.startZ) or "not set",
				h and ("%.0f"):format(h.Position.Z) or "no hull"),
			("corridor    %s"):format(select(2, SeaStates.validateCorridorForTarget(state.summary.target))),
		}, "\n")
	end,
}

print("[EXPEDITION] server ready")
