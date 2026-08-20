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
-- ---------------------------------------------------------------------------
-- Storm
-- ---------------------------------------------------------------------------
--[[
	The storm sets intensity; intensity picks a sea state; the state's severity drives the look through
	DayNight.compose(). So these tools never touch Lighting either - they move the front and let the flow
	do the rest, exactly as the real game will.
]]

local function stormFront(): any
	local mod = ReplicatedStorage:FindFirstChild("StormFront")
	if not mod then return nil end
	local ok, m = pcall(require, mod)
	return ok and m or nil
end

tools.stormDistance = {
	id = "stormDistance",
	label = "Storm distance",
	section = "Storm",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "4.2 km (start)", "2.5 km incoming", "1.5 km storm", "0.7 km severe", "0.15 km THE WALL" },
	},
	run = function(_player: Player, args: any)
		local SF = stormFront()
		if not SF then return false, "StormFront not found" end
		local map = {
			["4.2 km (start)"] = 4200,
			["2.5 km incoming"] = 2500,
			["1.5 km storm"] = 1500,
			["0.7 km severe"] = 700,
			["0.15 km THE WALL"] = 150,
		}
		local d = map[tostring(args and args.value)]
		if not d then return false, "unknown distance" end
        SF.reset(d)
		local band = SF.bandFor(d)
		return true, ("front at %.0f studs -> intensity %d %s, sea %s, wind %.2f")
			:format(d, band.intensity, band.label, band.sea, SF.wind())
	end,
}

tools.stormShelter = {
	id = "stormShelter",
	label = "Shelter (slows to 30%)",
	section = "Storm",
	scope = "global",
	controls = { kind = "choice", options = { "moored at shelter", "at sea" } },
	run = function(_player: Player, args: any)
		local SF = stormFront()
		if not SF then return false, "StormFront not found" end
		local sheltered = tostring(args and args.value) == "moored at shelter"
		SF.setSheltered(sheltered)
		return true, sheltered and "sheltered - front closes at 30%, never stops" or "at sea - full rate"
	end,
}

tools.stormReport = {
	id = "stormReport",
	label = "Storm status",
	section = "Storm",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local SF = stormFront()
		if not SF then return false, "StormFront not found" end
		return true, SF.report()
	end,
}

--[[
	The sensory channels, reported from the CLIENT.

	`scope = "local"` matters here and is not a detail: the rain, the spray and the cloud wall are all
	camera-local client rigs, so a server-side report would truthfully say they do not exist. Job 017 shipped
	VFX that nothing ever started and the storm still *looked* like it worked, because the server-composed
	channels replicate on their own - so "is the client half actually running" is a question worth being able
	to ask directly.
]]
tools.vfxReport = {
	id = "vfxReport",
	label = "Rain / spray / cloud wall status",
	section = "Storm",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local lines = {}
		for _, name in ipairs({ "StormVFX", "CloudWallVFX" }) do
			local m = ReplicatedStorage:FindFirstChild(name)
			if not m then
				table.insert(lines, name .. ": module not found")
			else
				local ok, mod = pcall(require, m)
				if not ok then
					table.insert(lines, name .. ": failed to load - " .. tostring(mod))
				else
					table.insert(lines, "-- " .. name .. " --")
					table.insert(lines, mod.report())
				end
			end
			table.insert(lines, "")
		end
		return true, table.concat(lines, "\n")
	end,
}

local function localWeather()
	local m = ReplicatedStorage:FindFirstChild("LocalWeather")
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

--[[
	TIME SCALE - the tool that made job 018 necessary.

	`Storm distance` teleports the front, which shows you five looks but never an approach. This speeds the
	clock instead, so the escalation can actually be watched building. 10x turns a five-minute approach into
	thirty seconds; 30x into ten.
]]
tools.timeScale = {
	id = "timeScale",
	label = "Time scale (storm speed)",
	section = "Storm",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "1x real time", "3x", "10x", "30x", "frozen" },
	},
	run = function(_player: Player, args: any)
		local map = { ["1x real time"] = 1, ["3x"] = 3, ["10x"] = 10, ["30x"] = 30, ["frozen"] = 0 }
		local scale = map[tostring(args and args.value)]
		if not scale then return false, "unknown scale" end
		workspace:SetAttribute("TimeScale", scale)
		if scale == 0 then
			return true, "storm frozen. Everything else still runs, so the look keeps composing."
		end
		local SF = stormFront()
		local secs = SF and (SF.distance() / (SF.ADVANCE_RATE * scale)) or 0
		return true, ("%dx - the front reaches you in %.0fs from here (%.0fs at 1x)")
			:format(scale, secs, secs * scale)
	end,
}

--[[
	One click for the thing that is actually hard to see: the whole approach, start to finish.

	Resets to full distance and winds the clock up, because doing it by hand means two tools and remembering
	to put the scale back afterwards.
]]
tools.stormApproach = {
	id = "stormApproach",
	label = "Watch a full approach",
	section = "Storm",
	scope = "global",
	controls = { kind = "choice", options = { "30 seconds (10x)", "60 seconds (5x)", "10 seconds (30x)" } },
	run = function(_player: Player, args: any)
		local SF = stormFront()
		if not SF then return false, "StormFront not found" end
		local map = { ["30 seconds (10x)"] = 10, ["60 seconds (5x)"] = 5, ["10 seconds (30x)"] = 30 }
		local scale = map[tostring(args and args.value)]
		if not scale then return false, "unknown speed" end
		SF.reset(SF.START_DISTANCE)
		SF.setSheltered(false)
		workspace:SetAttribute("TimeScale", scale)
		return true, ("front reset to %.1f km and clock at %dx. It arrives in ~%.0fs - watch ASTERN.\nRemember to set the scale back to 1x before judging balance.")
			:format(SF.distanceKm(), scale, SF.START_DISTANCE / (SF.ADVANCE_RATE * scale))
	end,
}

--[[
	Force a strike, rather than waiting on the dice.

	Lightning is silent below storm intensity 2 and rolls at 2/minute at intensity 2, so testing it by
	waiting means sitting through a storm hoping. This calls the same roll-and-fire the server uses, so what
	is tested is the real path - it only skips the waiting.
]]
tools.lightningStrike = {
	id = "lightningStrike",
	label = "Force a lightning strike",
	section = "Storm",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "random", "distant (2 km)", "close (300)", "overhead (180)" },
	},
	run = function(_player: Player, args: any)
		local mod = ReplicatedStorage:FindFirstChild("Lightning")
		if not mod then return false, "Lightning not found" end
		local ok, L = pcall(require, mod)
		if not ok then return false, "Lightning failed to load: " .. tostring(L) end
		local fire = (_G :: any).TideLightningFire
		local roll = (_G :: any).TideLightningRoll
		if not fire or not roll then
			return false, "LightningServer is not running - is the game in Play?"
		end

		local choice = tostring(args and args.value)
		local intensity = workspace:GetAttribute("StormIntensity")
		local strike = roll(if typeof(intensity) == "number" then intensity else 3)
		local forced = { ["distant (2 km)"] = 2000, ["close (300)"] = 300, ["overhead (180)"] = 180 }
		if forced[choice] then
			strike.distance = forced[choice]
			-- Re-roll the fault, since it is decided from distance and we have just changed it.
			strike.fault = nil
			if strike.distance <= L.CLOSE_DISTANCE and math.random() < 0.5 then
				strike.fault = "radar"
			end
		end
		fire(strike)
		return true, ("struck at %.0f studs, bearing %.0f, magnitude %.2f\nthunder in %.1fs%s")
			:format(strike.distance, strike.bearing, strike.magnitude,
				L.thunderDelay(strike.distance),
				strike.fault and ("\nfault raised: " .. strike.fault .. " (nothing consumes it yet)") or "")
	end,
}

--[[
	AUDIO. `scope = "local"` throughout - sound is a client thing, and a server-side audio report would
	truthfully say nothing is playing.
]]
local function stormAudio()
	local m = ReplicatedStorage:FindFirstChild("StormAudio")
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

tools.audioReport = {
	id = "audioReport",
	label = "Audio status (what is still silent)",
	section = "Audio",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local A = stormAudio()
		if not A then return false, "StormAudio not found" end
		return true, A.report()
	end,
}

--[[
	AUDITION a candidate id before it is committed to code.

	The whole reason the empty slots are addressable at runtime. A clip judged on its Creator Store page is
	heard alone and dry; the only question that matters is how it sounds UNDER the wind bed at the volume
	curve the storm will actually give it. So: paste an id, hear it in place, then decide.

	Nothing here writes the id to disk - a keeper still gets written into StormAudio and logged in the shared
	registry by hand, which is the step that records the licence.
]]
tools.audioAudition = {
	id = "audioAudition",
	label = "Audition a sound id",
	section = "Audio",
	scope = "local",
	controls = {
		kind = "text",
		placeholder = "slot=id, e.g.  rain=1234567890  or  thunder=1234567890",
	},
	run = function(_player: Player, args: any)
		local A = stormAudio()
		if not A then return false, "StormAudio not found" end
		local raw = tostring(args and args.value or "")
		local slot, id = raw:match("^%s*(%a+)%s*=%s*(.+)%s*$")
		if not slot then
			return false, "expected  slot=id  - slots are: windLow, windHigh, rain, thunder"
		end
		local ok, msg = A.setId(slot, id)
		if not ok then return false, msg end
		if slot == "thunder" then
			A.thunder(600, 0.9) -- play it once so it can be heard immediately
			return true, msg .. "\nplayed once at 600 studs. Force a strike to hear it in context."
		end
		return true, msg .. "\nlooping now - move the wind to hear it level."
	end,
}

--[[
	EVERYDAY WEATHER (decision 0020).

	Its own section, deliberately, and not under Storm - because the whole point of the system is that the
	two are unrelated. A panel that filed "showers" under "Storm" would teach the wrong thing to the person
	testing it.
]]
tools.weatherSet = {
	id = "weatherSet",
	label = "Pin today's weather",
	section = "Weather",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "auto (drifts)", "Glassy", "Slight", "Moderate", "Fresh", "Rough" },
	},
	run = function(_player: Player, args: any)
		local LW = localWeather()
		if not LW then return false, "LocalWeather not found" end
		local value = tostring(args and args.value)
		if value == "auto (drifts)" then
			LW.setOverride(nil)
			return true, "handed back to the clock - it drifts on its own again"
		end
		local map = { Glassy = 0.05, Slight = 0.25, Moderate = 0.46, Fresh = 0.70, Rough = 0.95 }
		local u = map[value]
		if not u then return false, "unknown weather" end
		LW.setOverride(u)
		return true, ("pinned at %s (%.2f)\nwaves x%.2f, wind %.2f, fog x%.2f\nNote: the sky and the light do NOT change - that is deliberate (decision 0020).")
			:format(value, u, LW.waveScale(), LW.wind(), LW.fogScale())
	end,
}

tools.weatherForecast = {
	id = "weatherForecast",
	label = "Forecast (next 20 min)",
	section = "Weather",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local LW = localWeather()
		if not LW then return false, "LocalWeather not found" end
		if LW.isOverridden() then
			return true, "weather is PINNED - set it back to auto to see the drift.\n\n" .. LW.forecast(20, 120)
		end
		return true, LW.forecast(20, 120)
	end,
}

tools.weatherReport = {
	id = "weatherReport",
	label = "Weather status",
	section = "Weather",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local LW = localWeather()
		if not LW then return false, "LocalWeather not found" end
		return true, LW.report()
	end,
}

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
