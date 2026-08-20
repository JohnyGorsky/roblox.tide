--!strict
--[[
	AdminTools - the tool registry.

	🔴 SERVER-ONLY, in ServerStorage on purpose. The client never sees this file; it asks the server for
	the tool list and receives it only after passing the admin check. That is the same reasoning as not
	shipping the panel UI to everyone and hiding it: if the definitions were in ReplicatedStorage, any
	player could enumerate every tool and every argument name without ever being an admin.

	Each tool declares:
	  id       stable key the client sends back
	  label    what the button says
	  section  which panel group it appears in
	  scope    "global" = changes the world for everyone | "local" = affects only the caller
	  controls what UI to build (buttons / slider / readout)
	  run      the handler. Receives (player, args) and returns (ok, resultOrMessage)

	There is NO DEFAULT SCOPE. A tool without one is rejected at startup rather than guessed, because
	guessing wrong means either granting everyone noclip or making the sea unjudgeable.

	Spec: docs/build/13-admin-tools.md
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local AdminTools = {}

local function seaStates()
	local mod = ReplicatedStorage:FindFirstChild("SeaStates")
	if not mod then
		return nil
	end
	local ok, m = pcall(require, mod)
	return ok and m or nil
end

local function round(n: number, places: number): number
	local mult = 10 ^ places
	return math.floor(n * mult + 0.5) / mult
end

local function rgb(c: Color3): string
	return ("Color3.fromRGB(%d, %d, %d)"):format(
		math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- ---------------------------------------------------------------------------
-- Tools
-- ---------------------------------------------------------------------------

local tools: { [string]: any } = {}

--[[
	Diagnostics: ping.

	This exists to prove the authorisation path works before any tool with real power is added. If ping
	is reachable by a non-admin, so is everything else - so it is the first thing to attack in testing.
]]
tools.ping = {
	id = "ping",
	label = "Ping server",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button" },
	run = function(player: Player, _args: any)
		return true, ("pong - server saw %s (UserId %d) at %s")
			:format(player.Name, player.UserId, os.date("!%H:%M:%SZ"))
	end,
}

--[[
	Sea tools register only where SeaStates exists.

	Roblox has no cross-place ReplicatedStorage, so this file is duplicated into both places' sync roots.
	Making it place-aware means the two copies stay byte-identical instead of diverging into a game
	variant and a lobby variant - and a tool that cannot work simply does not appear in the panel, rather
	than appearing and failing.
]]
local hasSea = ReplicatedStorage:FindFirstChild("SeaStates") ~= nil

if hasSea then

tools.setSeaState = {
	id = "setSeaState",
	label = "Sea state",
	section = "Sea",
	scope = "global", -- a sea only one person can see cannot be judged
	controls = { kind = "choice", options = { "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" } },
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then
			return false, "SeaStates module not found in ReplicatedStorage"
		end
		local id = args and args.value
		if typeof(id) ~= "string" then
			return false, "expected a state id"
		end
		local state = SeaStates.get(id)
		if not state then
			return false, ("unknown sea state %q"):format(tostring(id))
		end
		SeaStates.apply(state)
		return true, ("applied %s"):format(state.name)
	end,
}

tools.blendSeaStates = {
	id = "blendSeaStates",
	label = "Blend A→B",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "blend",
		options = { "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" },
	},
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then
			return false, "SeaStates module not found"
		end
		local a, b, t = args and args.a, args and args.b, args and args.t
		if typeof(a) ~= "string" or typeof(b) ~= "string" or typeof(t) ~= "number" then
			return false, "expected a, b (state ids) and t (0..1)"
		end
		local sa, sb = SeaStates.get(a), SeaStates.get(b)
		if not sa or not sb then
			return false, "unknown state id"
		end
		SeaStates.apply(SeaStates.lerp(sa, sb, math.clamp(t, 0, 1)))
		return true, ("blended %s -> %s at %.2f"):format(a, b, t)
	end,
}

--[[
	Live water and fog sliders.

	fogEnd is clamped to the ocean's half-extent. Job 007 established that if fog reaches past the water,
	the player sees the sea simply stop - so the panel refuses to create that artifact rather than letting
	a slider drag produce it.
]]
tools.setWater = {
	id = "setWater",
	label = "Water / fog",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "sliders",
		fields = {
			{ key = "waveSize", label = "Wave size", min = 0, max = 2, step = 0.01 },
			{ key = "waveSpeed", label = "Wave speed", min = 0, max = 40, step = 0.5 },
			{ key = "reflectance", label = "Reflectance", min = 0, max = 1, step = 0.01 },
			{ key = "transparency", label = "Transparency", min = 0, max = 1, step = 0.01 },
			{ key = "fogEnd", label = "Fog end", min = 100, max = 4000, step = 10 },
		},
	},
	run = function(_player: Player, args: any)
		local key, value = args and args.key, args and args.value
		if typeof(key) ~= "string" or typeof(value) ~= "number" then
			return false, "expected key and numeric value"
		end
		local T = workspace.Terrain
		if key == "waveSize" then
			T.WaterWaveSize = math.clamp(value, 0, 2)
		elseif key == "waveSpeed" then
			T.WaterWaveSpeed = math.clamp(value, 0, 100)
		elseif key == "reflectance" then
			T.WaterReflectance = math.clamp(value, 0, 1)
		elseif key == "transparency" then
			T.WaterTransparency = math.clamp(value, 0, 1)
		elseif key == "fogEnd" then
			local SeaStates = seaStates()
			local limit = SeaStates and SeaStates.OCEAN_HALF_EXTENT or 3072
			local clamped = math.clamp(value, 10, limit - 1)
			Lighting.FogEnd = clamped
			if clamped < value then
				return true, ("fogEnd clamped to %d - beyond that the ocean's edge becomes visible"):format(clamped)
			end
		else
			return false, ("unknown water key %q"):format(key)
		end
		return true, ("%s = %s"):format(key, tostring(value))
	end,
}

--[[
	Copy-as-Luau.

	The most valuable tool here: it turns values found by dragging a slider into a SeaStates entry that
	can be pasted into the module. Without it, every good-looking setting dies with the session - which is
	exactly what nearly happened to the lighting experiments in job 007.
]]
tools.copyAsLuau = {
	id = "copyAsLuau",
	label = "Copy current as Luau",
	section = "Sea",
	scope = "local", -- read-only; produces text for the caller
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local T = workspace.Terrain
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		local lines = {
			"-- captured from the live place, " .. os.date("!%Y-%m-%d %H:%M:%SZ"),
			"water = {",
			("\tcolor = %s,"):format(rgb(T.WaterColor)),
			("\treflectance = %s,"):format(round(T.WaterReflectance, 3)),
			("\ttransparency = %s,"):format(round(T.WaterTransparency, 3)),
			("\twaveSize = %s,"):format(round(T.WaterWaveSize, 3)),
			("\twaveSpeed = %s,"):format(round(T.WaterWaveSpeed, 2)),
			"},",
			"sky = {",
			("\tfogStart = %s,"):format(round(Lighting.FogStart, 1)),
			("\tfogEnd = %s,"):format(round(Lighting.FogEnd, 1)),
			("\tfogColor = %s,"):format(rgb(Lighting.FogColor)),
			("\tbrightness = %s,"):format(round(Lighting.Brightness, 2)),
			"},",
		}
		if atm then
			table.insert(lines, "-- Atmosphere is not part of SeaStates yet; add these if it becomes so:")
			table.insert(lines, ("-- density = %s, haze = %s, glare = %s")
				:format(round(atm.Density, 3), round(atm.Haze, 2), round(atm.Glare, 2)))
			table.insert(lines, ("-- color = %s, decay = %s"):format(rgb(atm.Color), rgb(atm.Decay)))
		end
		return true, table.concat(lines, "\n")
	end,
}

end -- if hasSea

tools.readSea = {
	id = "readSea",
	label = "Read water / fog",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local T = workspace.Terrain
		return true, table.concat({
			("waveSize    %.3f"):format(T.WaterWaveSize),
			("waveSpeed   %.2f"):format(T.WaterWaveSpeed),
			("reflectance %.3f"):format(T.WaterReflectance),
			("transparency %.3f"):format(T.WaterTransparency),
			("fog         %.0f .. %.0f"):format(Lighting.FogStart, Lighting.FogEnd),
			("brightness  %.2f"):format(Lighting.Brightness),
		}, "\n")
	end,
}

tools.placeInfo = {
	id = "placeInfo",
	label = "Place info",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local Players = game:GetService("Players")
		return true, table.concat({
			("place      %d"):format(game.PlaceId),
			("gameId     %d"):format(game.GameId),
			("players    %d / %d"):format(#Players:GetPlayers(), Players.MaxPlayers),
			("streaming  %s"):format(tostring(workspace.StreamingEnabled)),
			("autoload   %s"):format(tostring(Players.CharacterAutoLoads)),
			("sea tools  %s"):format(hasSea and "available" or "not in this place"),
		}, "\n")
	end,
}

-- ---------------------------------------------------------------------------
-- Registry access
-- ---------------------------------------------------------------------------

local VALID_SCOPES = { global = true, ["local"] = true }

--- Reject any tool with a missing or bogus scope at startup, rather than guessing one at call time.
function AdminTools.validate(): (boolean, string)
	local problems = {}
	for id, tool in pairs(tools) do
		if tool.id ~= id then
			table.insert(problems, ("%s: id field is %q"):format(id, tostring(tool.id)))
		end
		if not VALID_SCOPES[tool.scope] then
			table.insert(problems, ("%s: scope is %q, must be \"global\" or \"local\""):format(id, tostring(tool.scope)))
		end
		if typeof(tool.run) ~= "function" then
			table.insert(problems, ("%s: no run handler"):format(id))
		end
	end
	if #problems == 0 then
		return true, "all tools declare a valid scope and handler"
	end
	return false, table.concat(problems, "; ")
end

function AdminTools.get(id: string)
	return tools[id]
end

--[[
	The manifest sent to a confirmed-admin client so it can build the UI.
	Handlers are deliberately NOT included - only what the UI needs to draw itself.
]]
function AdminTools.manifest(): { any }
	local list = {}
	for _, tool in pairs(tools) do
		table.insert(list, {
			id = tool.id,
			label = tool.label,
			section = tool.section,
			scope = tool.scope,
			controls = tool.controls,
		})
	end
	table.sort(list, function(a, b)
		if a.section == b.section then
			return a.label < b.label
		end
		return a.section < b.section
	end)
	return list
end

return AdminTools
