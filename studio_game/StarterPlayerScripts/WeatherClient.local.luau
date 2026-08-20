--!strict
--[[
	WeatherClient - the thing that actually turns the weather on.

	Feature: docs/features/0003-storm-front/  ·  job 018

	🔴 WHY THIS EXISTS, AND IT IS EMBARRASSING

	`StormVFX` was written in job 017 and NOTHING EVER CALLED IT. There was no client script in this place
	at all except the admin panel, so the rain, the spray and the wind-blown debris had never run once. The
	storm was tested by walking the front in from 4.2 km and it *looked* like it worked, because four of the
	five channels - sky, fog, brightness, atmosphere - are composed on the server and replicate on their own.
	The one channel that needed a client had no client.

	The lesson worth keeping: a client-side module is not wired up until something in StarterPlayerScripts
	requires it. "The module exists and its API is correct" is not the same as "the effect happens", and a
	server-composed world will happily hide the difference.

	--------------------------------------------------------------------------------------------------
	.local.luau, NOT .client.luau

	Studio Sync maps `.client.luau` to a script that ran TWICE here (job 016). Every client entry point in
	this project is `.local.luau`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StormVFX = require(ReplicatedStorage:WaitForChild("StormVFX"))
local LightningVFX = require(ReplicatedStorage:WaitForChild("LightningVFX"))
local CloudWallVFX = require(ReplicatedStorage:WaitForChild("CloudWallVFX"))

--[[
	Rain and spray follow the camera, so they need a camera. In a fresh session the CurrentCamera can be nil
	for a frame or two, and starting before it exists parents the emitter rig to nothing.
]]
while not workspace.CurrentCamera do
	task.wait()
end

StormVFX.start()
CloudWallVFX.start()

--[[
	Both rigs are parented to the CAMERA, and the camera is replaced when the character respawns. Rebuild on
	that, or the weather silently stops after the first death - the emitters keep existing, attached to a
	camera nothing is looking through any more.
]]
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then
		StormVFX.start()
		CloudWallVFX.start()
	end
end)

local remote = ReplicatedStorage:WaitForChild("LightningRemote") :: RemoteEvent
remote.OnClientEvent:Connect(function(strike)
	--[[
		Validate before rendering. The payload crosses the network, and a malformed one would otherwise
		reach `drawBolt` and build geometry at nan - which produces parts that cannot be selected or deleted
		in Studio, an unpleasant thing to clean up by hand.
	]]
	if typeof(strike) ~= "table" or typeof(strike.distance) ~= "number" or typeof(strike.bearing) ~= "number" then
		return
	end
	if strike.distance ~= strike.distance or strike.bearing ~= strike.bearing then -- nan
		return
	end
	LightningVFX.render(strike)
end)

--[[
	🔨 THUNDER HAS NO SOUND YET (group 12 - audio is not sourced).

	The listener is attached anyway so the timing is live and testable: the print fires at exactly the moment
	a clip should play, delayed from the flash by distance / SOUND_STUDS_PER_SECOND. Attaching the audio is
	then a one-line change here rather than a hunt for the right seam.

	It logs rather than playing a placeholder clip on purpose - a wrong rumble is harder to notice than no
	rumble, and placeholders are how the wrong sound ends up shipping.
]]
local Lightning = require(ReplicatedStorage:WaitForChild("Lightning"))

--- Only the near ones are logged: inside The Wall there are 22 strikes a minute and the rest is noise.
local THUNDER_LOG_WITHIN = 900

LightningVFX.onThunder(function(strike)
	if strike.distance <= THUNDER_LOG_WITHIN then
		print(("[THUNDER] %.0f studs, %.1fs after the flash%s"):format(
			strike.distance,
			Lightning.thunderDelay(strike.distance),
			strike.fault and ("  [fault: " .. strike.fault .. "]") or ""))
	end
end)

print("[WEATHER] client started: rain, spray, debris and lightning are live.")
