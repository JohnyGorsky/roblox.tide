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
			{ key = "waveSize", label = "Wave size (engine caps at 1)", min = 0, max = 1, step = 0.01 },
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
			T.WaterWaveSize = math.clamp(value, 0, 1) -- engine caps at 1; above that it silently clamps
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
			-- Real pasteable fields, not comments: this block is what makes a value found by dragging a
			-- slider survive the session. Add the matching `atmosphere` field to SeaStates (todo 0004).
			table.insert(lines, "atmosphere = {")
			table.insert(lines, ("\tdensity = %s,"):format(round(atm.Density, 3)))
			table.insert(lines, ("\toffset = %s,"):format(round(atm.Offset, 3)))
			table.insert(lines, ("\thaze = %s,"):format(round(atm.Haze, 2)))
			table.insert(lines, ("\tglare = %s,"):format(round(atm.Glare, 2)))
			table.insert(lines, ("\tcolor = %s,"):format(rgb(atm.Color)))
			table.insert(lines, ("\tdecay = %s,"):format(rgb(atm.Decay)))
			table.insert(lines, "},")
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

-- ---------------------------------------------------------------------------
-- Sea state: visuals AND wave field together
-- ---------------------------------------------------------------------------
--[[
	These replace the earlier setSeaState/blendSeaStates, which only moved the VISUALS. Switching the look
	without switching the field left the boat riding a sea nobody could see - the exact failure this whole
	feature exists to prevent. One button now moves both.
]]

local function waveField(): any
	local mod = ReplicatedStorage:FindFirstChild("WaveField")
	if not mod then return nil end
	local ok, m = pcall(require, mod)
	return ok and m or nil
end

local function waveDebug(): any
	local mod = ReplicatedStorage:FindFirstChild("WaveFieldDebug")
	if not mod then return nil end
	local ok, m = pcall(require, mod)
	return ok and m or nil
end

--- Apply a state to everything: water, fog, ambient, and the physical field.
local function applyFull(state: any, blendSeconds: number): string
	local SeaStates = seaStates()
	SeaStates.apply(state)
	local WF = waveField()
	if WF then
		WF.setState(state, blendSeconds)
		return ("%s  (look + wave field, blending %.0fs)"):format(state.name, blendSeconds)
	end
	return ("%s  (look only - WaveField module not found)"):format(state.name)
end

if hasSea then

tools.seaState = {
	id = "seaState",
	label = "Sea state",
	section = "Sea",
	scope = "global",
	controls = { kind = "choice", options = { "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" } },
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then return false, "SeaStates not found" end
		local state = SeaStates.get(args and args.value)
		if not state then return false, ("unknown sea state %q"):format(tostring(args and args.value)) end
		-- 4s blend: fast enough to judge, slow enough that nothing floating is thrown
		return true, "applied " .. applyFull(state, 4)
	end,
}

tools.seaStateInstant = {
	id = "seaStateInstant",
	label = "Sea state (snap, no blend)",
	section = "Sea",
	scope = "global",
	controls = { kind = "choice", options = { "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" } },
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then return false, "SeaStates not found" end
		local state = SeaStates.get(args and args.value)
		if not state then return false, "unknown sea state" end
		return true, "snapped to " .. applyFull(state, 0)
	end,
}

--[[
	Cycle every state in order, dwelling on each.

	This is the review tool: one press and the whole range plays out, calm through to The Wall, so the set
	can be judged as a progression rather than five disconnected screenshots.
]]
local cycleToken = 0
tools.cycleSeaStates = {
	id = "cycleSeaStates",
	label = "Cycle all states",
	section = "Sea",
	scope = "global",
	controls = { kind = "choice", options = { "6s each", "12s each", "stop" } },
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then return false, "SeaStates not found" end
		local choice = tostring(args and args.value)
		cycleToken += 1
		if choice == "stop" then
			return true, "cycle stopped"
		end
		local dwell = choice == "12s each" and 12 or 6
		local myToken = cycleToken
		task.spawn(function()
			for _, id in ipairs(SeaStates.Order) do
				if cycleToken ~= myToken then return end -- superseded by a newer press
				applyFull(SeaStates.get(id), math.min(dwell * 0.4, 4))
				task.wait(dwell)
			end
		end)
		return true, ("cycling all 5 states, %ds each (~%ds total)"):format(dwell, dwell * 5)
	end,
}

tools.waveGrid = {
	id = "waveGrid",
	label = "Wave field markers",
	section = "Sea",
	scope = "global",
	controls = { kind = "choice", options = { "show", "show wide", "hide" } },
	run = function(_player: Player, args: any)
		local D = waveDebug()
		if not D then return false, "WaveFieldDebug module not found" end
		local choice = tostring(args and args.value)
		if choice == "hide" then
			D.hideGrid()
			return true, "wave markers hidden"
		end
		local n = choice == "show wide" and 22 or 14
		local spacing = choice == "show wide" and 16 or 10
		local made = D.showGrid(n, spacing, Vector3.zero)
		return true, ("%d markers over %d studs - they ride OUR field, not the render"):format(made, n * spacing)
	end,
}

tools.waveRuler = {
	id = "waveRuler",
	label = "Height ruler",
	section = "Sea",
	scope = "global",
	controls = { kind = "choice", options = { "+/-3 studs", "+/-10 studs", "hide" } },
	run = function(_player: Player, args: any)
		local D = waveDebug()
		if not D then return false, "WaveFieldDebug module not found" end
		local choice = tostring(args and args.value)
		if choice == "hide" then
			D.hideRuler()
			return true, "ruler hidden"
		end
		local span = choice == "+/-10 studs" and 10 or 3
		local made = D.showRuler(Vector3.zero, -span, span, span > 5 and 0.5 or 0.25)
		return true, ("%d rungs, +/-%d studs. Red = 0, labels every whole stud"):format(made, span)
	end,
}

tools.seaReport = {
	id = "seaReport",
	label = "What sea am I looking at?",
	section = "Sea",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local D = waveDebug()
		local WF = waveField()
		if not D or not WF then return false, "wave modules not found" end
		local blend = WF.blendProgress()
		return true, D.report() .. (blend and ("\nblending... %.0f%%"):format(blend * 100) or "\nsettled")
	end,
}

end -- if hasSea

-- ---------------------------------------------------------------------------
-- Atmosphere: the real colour lever
-- ---------------------------------------------------------------------------
--[[
	Job 007 tried four ways to recolour the ocean through water properties and fog and all four failed -
	the sky and Atmosphere win. So these are the controls that actually change how the sea reads, and
	WaterColor is the weak one. Measured landmarks from that job, worth knowing while dragging:
	  Haze 3.0  flattens ALL wave detail (technically the right colour, visually dead)
	  Haze 1.1  keeps depth
	  storm treatment: Density 0.62, Haze 2.2
]]

local function atmosphere(): Instance?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

tools.setAtmosphere = {
	id = "setAtmosphere",
	label = "Atmosphere",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "sliders",
		fields = {
			{ key = "density", label = "Density", min = 0, max = 1, step = 0.02 },
			{ key = "offset", label = "Offset", min = 0, max = 1, step = 0.05 },
			{ key = "haze", label = "Haze (>2 kills wave detail)", min = 0, max = 5, step = 0.1 },
			{ key = "glare", label = "Glare", min = 0, max = 2, step = 0.05 },
		},
	},
	run = function(_player: Player, args: any)
		local atm = atmosphere()
		if not atm then
			return false, "no Atmosphere in Lighting"
		end
		local key, value = args and args.key, args and args.value
		if typeof(key) ~= "string" or typeof(value) ~= "number" then
			return false, "expected key and numeric value"
		end
		local a = atm :: any
		if key == "density" then
			a.Density = math.clamp(value, 0, 1)
		elseif key == "offset" then
			a.Offset = math.clamp(value, 0, 1)
		elseif key == "haze" then
			a.Haze = math.clamp(value, 0, 5)
		elseif key == "glare" then
			a.Glare = math.clamp(value, -1, 2)
		else
			return false, ("unknown atmosphere key %q"):format(key)
		end
		local note = (key == "haze" and value > 2) and "  (warning: above ~2 the swell stops reading)" or ""
		return true, ("%s = %.2f%s"):format(key, value, note)
	end,
}

--[[
	Colours come from the palette, not from freeform RGB.

	Two reasons: tuning by eye cannot drift off-palette, and a choice list works with a thumb whereas nine
	numeric fields do not. If a colour is genuinely needed that is not here, add it to the palette in
	docs/game/visual-design.md first - that is the point.
]]
local PALETTE: { [string]: Color3 } = {
	AbyssNavy = Color3.fromRGB(11, 30, 45),
	DeepOcean = Color3.fromRGB(18, 53, 74),
	StormTeal = Color3.fromRGB(30, 90, 110),
	ColdSeaMist = Color3.fromRGB(110, 142, 153),
	ThunderCloud = Color3.fromRGB(42, 49, 59),
	WetSteel = Color3.fromRGB(75, 89, 100),
	FogGrey = Color3.fromRGB(140, 154, 163),
	LightningPale = Color3.fromRGB(220, 234, 242),
}
local PALETTE_ORDER = {
	"AbyssNavy", "DeepOcean", "StormTeal", "ColdSeaMist",
	"ThunderCloud", "WetSteel", "FogGrey", "LightningPale",
}

local function paletteTool(id: string, label: string, apply: (Color3) -> ())
	return {
		id = id,
		label = label,
		section = "Sea",
		scope = "global",
		controls = { kind = "choice", options = PALETTE_ORDER },
		run = function(_player: Player, args: any)
			local name = args and args.value
			if typeof(name) ~= "string" then
				return false, "expected a palette colour name"
			end
			local c = PALETTE[name]
			if not c then
				return false, ("%q is not in the palette"):format(tostring(name))
			end
			apply(c)
			return true, ("%s = %s (%d,%d,%d)"):format(label, name,
				math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
		end,
	}
end

tools.waterColor = paletteTool("waterColor", "Water colour", function(c)
	workspace.Terrain.WaterColor = c
end)

tools.fogColor = paletteTool("fogColor", "Fog colour", function(c)
	Lighting.FogColor = c
end)

tools.atmosphereColor = paletteTool("atmosphereColor", "Atmosphere colour", function(c)
	local atm = atmosphere()
	if atm then
		(atm :: any).Color = c
	end
end)

tools.atmosphereDecay = paletteTool("atmosphereDecay", "Atmosphere decay", function(c)
	local atm = atmosphere()
	if atm then
		(atm :: any).Decay = c
	end
end)

--[[
	Spawn on demand.

	The game place runs with CharacterAutoLoads = false on purpose: the expedition owns death, and nothing
	may respawn behind the run's back. The side effect is that pressing Play gives you no body at all, no
	camera subject, and an apparently dead session.

	This is the deliberate opt-in. It does not change the setting - it asks for a character explicitly,
	which is exactly the contract the rule describes.
]]
--[[
	Sky override.

	Each sea state names its own sky now, so this is for judging one against another without changing the
	state - e.g. seeing whether Snow Grey or Fog on Water suits Choppy better. Switching state afterwards
	will overwrite it, which is correct: the state owns the sky.
]]
tools.setSky = {
	id = "setSky",
	label = "Sky (override)",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "choice",
		options = {
			"SunlessBlue", "SnowGrey", "FogOnWater", "AngryHeavens",
			"BlackVoid", "NightFog", "ClassicRoblox", "none (procedural)",
		},
	},
	run = function(_player: Player, args: any)
		local mod = ReplicatedStorage:FindFirstChild("SkyLibrary")
		if not mod then
			return false, "SkyLibrary not found in ReplicatedStorage"
		end
		local okReq, SkyLibrary = pcall(require, mod)
		if not okReq then
			return false, "SkyLibrary failed to load"
		end
		local choice = tostring(args and args.value)
		if choice == "none (procedural)" then
			return SkyLibrary.apply(nil)
		end
		return SkyLibrary.apply(choice)
	end,
}

tools.whichSky = {
	id = "whichSky",
	label = "Which sky is applied?",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local mod = ReplicatedStorage:FindFirstChild("SkyLibrary")
		if not mod then return false, "SkyLibrary not found" end
		local okReq, SkyLibrary = pcall(require, mod)
		if not okReq then return false, "SkyLibrary failed to load" end
		local id = SkyLibrary.current()
		if not id then
			return true, "no library sky applied (procedural gradient, or a hand-placed Sky)"
		end
		local d = SkyLibrary.get(id)
		return true, ("%s\n%s\n%s"):format(d.label, d.intent, d.source)
	end,
}

tools.spawnMe = {
	id = "spawnMe",
	label = "Spawn me a character",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(player: Player, _args: any)
		local Players = game:GetService("Players")
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			return false, "LoadCharacter failed: " .. tostring(err)
		end

		-- Put them somewhere standable rather than in the water.
		local deck = workspace:FindFirstChild("GB_ObservationDeck")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and deck and deck:IsA("BasePart") then
			(root :: BasePart).CFrame = CFrame.new(deck.Position + Vector3.new(0, deck.Size.Y / 2 + 4, 0))
			return true, ("spawned on %s (autoload stays off - this was an explicit request)"):format(deck.Name)
		end
		return true, "spawned. No observation deck found, so you may be swimming."
	end,
}

tools.despawnMe = {
	id = "despawnMe",
	label = "Remove my character",
	section = "Diagnostics",
	scope = "local",
	controls = { kind = "button" },
	run = function(player: Player, _args: any)
		if player.Character then
			player.Character:Destroy()
			return true, "character removed (autoload is off, so nothing will bring it back)"
		end
		return true, "you had no character"
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
