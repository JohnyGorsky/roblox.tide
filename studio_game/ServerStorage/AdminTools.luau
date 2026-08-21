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
	controls = {
		kind = "choice",
		options = { "auto (storm decides)", "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" },
	},
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then return false, "SeaStates not found" end
		local value = tostring(args and args.value)
		--[[
			🔴 PIN THE OVERRIDE, or this tool does nothing.

			`WorldTick` calls `StormFront.apply()` every second, which rewrites `SeaState` from the current
			storm band - measured clobbering a manual write in 0.65s. So this tool had been silently broken
			since job 017 for any state that did not match the band, and DeadCalm was unreachable entirely
			because no band selects it. Setting `SeaOverride` makes the storm leave the sea alone.
		]]
		if value:find("auto") then
			workspace:SetAttribute("SeaOverride", nil)
			return true, "handed back to the storm - the current band decides the sea again"
		end
		local state = SeaStates.get(value)
		if not state then return false, ("unknown sea state %q"):format(value) end
		workspace:SetAttribute("SeaOverride", state.id)
		-- 4s blend: fast enough to judge, slow enough that nothing floating is thrown
		return true, table.concat({
			"PINNED " .. applyFull(state, 4),
			"The storm keeps closing, but no longer picks the sea. Choose 'auto' to release.",
		}, "\n")
	end,
}

tools.seaStateInstant = {
	id = "seaStateInstant",
	label = "Sea state (snap, no blend)",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "auto (storm decides)", "DeadCalm", "LightSwell", "Choppy", "Storm", "TheWall" },
	},
	run = function(_player: Player, args: any)
		local SeaStates = seaStates()
		if not SeaStates then return false, "SeaStates not found" end
		local value = tostring(args and args.value)
		if value:find("auto") then
			workspace:SetAttribute("SeaOverride", nil)
			return true, "handed back to the storm"
		end
		local state = SeaStates.get(value)
		if not state then return false, "unknown sea state" end
		workspace:SetAttribute("SeaOverride", state.id) -- see the note on `seaState`
		return true, "PINNED, snapped to " .. applyFull(state, 0)
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
	label = "Rain / spray / wall / lightning status",
	section = "Storm",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local lines = {}
		for _, name in ipairs({ "StormVFX", "CloudWallVFX", "LightningVFX" }) do
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
	Point the camera at the storm.

	Sounds trivial; it is not. The wall only exists astern (bearing 180, i.e. -Z) and there is no vessel, no
	compass and no landmark in the place yet, so "look astern" is not a thing a tester can actually DO - and
	a wall you happened to be facing away from is indistinguishable from a wall that is not being drawn.
	That ambiguity cost a full round of debugging.
]]
tools.faceStorm = {
	id = "faceStorm",
	label = "Face the storm (look astern)",
	section = "Storm",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(player: Player, _args: any)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false, "no character - press Play first"
		end
		--[[
			Turn the CHARACTER rather than the camera. The camera follows the character in Play, so writing
			Camera.CFrame from the server is pointless - the camera script overwrites it the same frame.
		]]
		local position = root.Position
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
		local distance = workspace:GetAttribute("StormDistance")
		return true, ("turned to face bearing 180 (-Z), where the front is.\nstorm %s studs out; the wall is drawn well inside the fog of that.")
			:format(typeof(distance) == "number" and ("%.0f"):format(distance) or "?")
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
	VESSEL. Server-side, because the hull is server-owned by design (decision 0022) and `_G.TideVessel` only
	exists there. A client-side handler would find nothing, which is the trap finding 0017 records.
]]
local function vessel()
	return (_G :: any).TideVessel
end

--[[
	🔴 THE SURVIVAL TEST. The tool this whole job is answerable to.

	Decision 0014 states a number - "survivable for roughly 30-60 seconds of competent play" - and there is no
	way to see whether that is true by looking at the game. Two things have to be measured, and they are
	different questions:

	  HOLD POSITION   how long does the hull last at full exposure?  Should equal the spec's `survivability`.
	                  This checks the damage curve against the number a designer wrote.
	  ESCAPE RUN      can a crew that reacts immediately get out, and at what cost?  Should clear the front
	                  in the high teens of seconds with real integrity left.
	                  This checks the curve against the STORM's constants, which is the harder question.

	The two together are what "escapable in 30-60 seconds" actually means: staying is fatal on a known clock,
	and leaving works if you leave now.

	Both drive the REAL loop - the world tick advances the front, `VesselServer` applies the damage, the vessel
	buys distance from its own northward travel. Nothing is simulated in the tool, which is the point: a
	simulation would have re-derived the arithmetic and then agreed with itself.

	⚠️ REFUSES TO RUN WITH A TIME SCALE SET. `WorldTick` scales the front's advance but not the vessel's
	travel, so at scale 10 the crew loses ground ten times faster than they should and every number this
	prints would be wrong in a direction that looks like a damage bug.
]]
tools.stormSurvivalTest = {
	id = "stormSurvivalTest",
	label = "Survival test (measured)",
	section = "Storm",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "escape run (full throttle north)", "hold position (time to loss)" },
	},
	run = function(_player: Player, args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		local SF = stormFront()
		if not SF then return false, "StormFront not found" end
		local hull = V.state.hull
		local spec = V.state.spec
		if not hull or not spec then return false, "no hull" end

		local scale = workspace:GetAttribute("TimeScale")
		if typeof(scale) == "number" and scale ~= 1 then
			return false, ("TimeScale is %.1f. Set it back to 1x (Storm -> Time scale) before measuring - it "
				.. "speeds up the front but not the vessel, so every number here would be wrong."):format(scale)
		end

		local escaping = tostring(args and args.value):find("escape") ~= nil

		--[[
			Set up a KNOWN starting state, or the run is not repeatable: sound hull, full tank, and the front
			exactly at the point of full exposure.

			Distance 0 rather than somewhere further inside the band: it is the deepest point that is not
			saturated arbitrarily, so it is the hardest honest start. Anything deeper only measures saturation.
		]]
		V.repairAll()
		V.setFuel(spec.fuelCapacity)
		SF.reset(0)

		-- Point her north (+Z) and stop her dead, so acceleration is part of what is measured.
		local position = hull.Position
		hull.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
		hull.AssemblyLinearVelocity = Vector3.zero
		hull.AssemblyAngularVelocity = Vector3.zero

		--[[
			Drive through the TEST HOOK rather than by writing `state.throttle`, so the input takes the same
			path a driver's would and a driver at the helm cannot fight it. See the hook's note in
			`VesselServer`.
		]]
		workspace:SetAttribute("VesselTestThrottle", escaping and 1 or 0)
		workspace:SetAttribute("VesselTestSteer", 0)
		workspace:SetAttribute("VesselTestDrive", true)

		local SAMPLE = 0.25
		local CAP = 120
		local t0 = os.clock()
		local wall = SF.wallAt()
		local outcome, elapsed = "still going at the cap", CAP
		local minIntegrity: number, maxSpeed: number = V.state.integrityMax, 0
		local faultsSeen: { [string]: boolean } = {}

		while os.clock() - t0 < CAP do
			task.wait(SAMPLE)
			local now = os.clock() - t0
			minIntegrity = math.min(minIntegrity, V.state.integrity)
			local speed = hull.AssemblyLinearVelocity:Dot(hull.CFrame.LookVector)
			maxSpeed = math.max(maxSpeed, speed)
			for id, on in pairs(V.state.faults) do
				if on then
					faultsSeen[id] = true
				end
			end
			if V.state.lost then
				outcome, elapsed = "VESSEL LOST", now
				break
			end
			if escaping and SF.distance() >= wall then
				outcome, elapsed = "cleared the front", now
				break
			end
		end

		-- Always hand the helm back, whatever happened.
		workspace:SetAttribute("VesselTestDrive", false)
		workspace:SetAttribute("VesselTestThrottle", 0)

		local faults = {}
		for id in pairs(faultsSeen) do
			table.insert(faults, id)
		end
		table.sort(faults)

		--[[
			The verdict, stated against decision 0014 rather than left to the reader. A report that prints
			numbers and no judgement gets skimmed, and the whole reason this is a tool is that the judgement
			cannot be made by eye.
		]]
		local lost = outcome == "VESSEL LOST"
		local verdict
		if escaping then
			if lost then
				verdict = "🔴 A crew reacting IMMEDIATELY at full throttle still died. Either the curve is too "
					.. "steep or she is not making enough way north - check max speed against cruise above."
			elseif elapsed > 60 then
				verdict = "⚠️ Escaped, but it took over a minute. Decision 0014 wants the front to be a "
					.. "deadline, not a slog - suspect the storm's own constants rather than the damage."
			elseif minIntegrity / V.state.integrityMax > 0.85 then
				verdict = "⚠️ Escaped almost unscathed. Being caught should COST something, or The Wall is "
					.. "scenery - consider a shorter survivability."
			else
				verdict = "✅ Escaped at a real cost. This is the intended story."
			end
		else
			local target = spec.survivability
			local ratio = elapsed / target
			if not lost then
				verdict = ("🔴 Held at full exposure for %.0fs and SURVIVED. The Wall is not a wall - loss was "
					.. "expected at about %ds."):format(elapsed, target)
			elseif ratio < 0.7 or ratio > 1.3 then
				verdict = ("🔴 Died in %.1fs against a declared survivability of %ds (%.0f%%). The damage rate "
					.. "and the spec disagree - the exposure ramp is the first suspect.")
					:format(elapsed, target, ratio * 100)
			else
				verdict = ("✅ Died in %.1fs against %ds declared. The number a designer wrote is the number "
					.. "the stopwatch read."):format(elapsed, target)
			end
		end

		local theory = SF.secondsToEscape(0, spec.cruise)
		return true, table.concat({
			("mode        %s"):format(escaping and "escape run, full throttle north" or "hold position"),
			("outcome     %s after %.1f s"):format(outcome, elapsed),
			("integrity   %.0f / %.0f  (%.0f%% left, low water %.0f%%)"):format(
				V.state.integrity, V.state.integrityMax,
				V.state.integrity / math.max(V.state.integrityMax, 1) * 100,
				minIntegrity / math.max(V.state.integrityMax, 1) * 100),
			("distance    %.0f studs (the wall edge is %.0f)"):format(SF.distance(), wall),
			("max speed   %.1f studs/s northward (cruise %d, min escape speed %.1f)"):format(
				maxSpeed, spec.cruise, SF.minEscapeSpeed()),
			("flooding    %.0f%%"):format(V.state.flooding * 100),
			("faults      %s"):format(#faults > 0 and table.concat(faults, ", ") or "none"),
			("theory      escape from distance 0 at cruise %d should take %s"):format(
				spec.cruise, theory and ("%.1f s"):format(theory) or "forever - she cannot gain ground"),
			("            the hull should empty in %ds at full exposure"):format(spec.survivability),
			"",
			verdict,
			"",
			"The front is left where the test finished. Storm -> Storm distance puts it back.",
		}, "\n")
	end,
}

tools.vesselStatus = {
	id = "vesselStatus",
	label = "Vessel status",
	section = "Vessel",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		return true, V.report()
	end,
}

--[[
	🔴 THE TEST THAT MATTERS MOST, and the reason it is a tool rather than something I run.

	A spring-damper fails by GAINING energy, and that looks completely fine for ten seconds before it throws
	the boat off the map. The Jungle boat was rock-stable at rest and bounced higher and higher once driven.

	So this samples the hull's height over time and compares the bob amplitude in the first third against the
	last third. Growing = the damping is wrong (almost certainly damping computed inside the up-only clamp,
	where it vanishes exactly when the hull rises). Shrinking or flat = it converges.

	Judging this by eye is not possible, which is why it is measured.
]]
tools.vesselStability = {
	id = "vesselStability",
	label = "Buoyancy stability check",
	section = "Vessel",
	scope = "local",
	controls = { kind = "choice", options = { "20 seconds", "60 seconds" } },
	run = function(_player: Player, args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		local hull = V.state.hull
		if not hull then return false, "no hull" end
		local seconds = tostring(args and args.value):find("60") and 60 or 20

		local samples = {}
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			table.insert(samples, hull.Position.Y)
			task.wait(0.1)
		end
		if #samples < 30 then return false, "too few samples" end

		--[[
			Amplitude as peak-to-trough within a window, compared first third against last third. Comparing
			means would miss the failure entirely - a boat oscillating +/-1 and one oscillating +/-8 can share
			the same average height.
		]]
		local function amplitude(from: number, to: number): (number, number)
			local lo, hi, sum = math.huge, -math.huge, 0
			for i = from, to do
				lo = math.min(lo, samples[i]); hi = math.max(hi, samples[i]); sum += samples[i]
			end
			return hi - lo, sum / (to - from + 1)
		end
		local third = math.floor(#samples / 3)
		local firstAmp, firstMean = amplitude(1, third)
		local lastAmp, lastMean = amplitude(#samples - third + 1, #samples)
		local growth = if firstAmp > 0.001 then lastAmp / firstAmp else 0

		local verdict
		if growth > 1.25 then
			verdict = "🔴 GROWING - energy is being ADDED. Check that damping is applied OUTSIDE the up-only clamp."
		elseif growth > 1.05 then
			verdict = "⚠️ slightly growing - watch it over 60s before trusting it"
		else
			verdict = "✅ converging or steady"
		end

		local spec = V.state.spec
		return true, table.concat({
			("sampled %ds, %d points, sea %s"):format(seconds, #samples, tostring(workspace:GetAttribute("SeaState"))),
			("bob amplitude   first third %.3f  ->  last third %.3f"):format(firstAmp, lastAmp),
			("mean height     first third %.3f  ->  last third %.3f  (resting %.2f)"):format(
				firstMean, lastMean, spec and require(ReplicatedStorage.Vessel).restingY(spec, 0) or 0),
			("growth ratio    %.3f"):format(growth),
			"",
			verdict,
		}, "\n")
	end,
}

tools.vesselTeleport = {
	id = "vesselTeleport",
	label = "Put me on the boat",
	section = "Vessel",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(player: Player, _args: any)
		local V = vessel()
		if not V or not V.state.hull then return false, "no vessel - is the game in Play?" end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false, "no character - Diagnostics -> Spawn me a character"
		end
		local hull = V.state.hull
		root.CFrame = CFrame.new(hull.Position + Vector3.new(0, hull.Size.Y / 2 + 4, 0))
		return true, ("on the deck at %s. It is a moving platform, so you should ride it."):format(
			tostring(hull.Position))
	end,
}

--[[
	DAMAGE TOOLS (job 022, decision 0014).

	Global scope, all of them: hull integrity is one shared thing and there is no per-player view of it.
	`vesselDamageReport` is the exception - reading a number changes nothing for anyone else.
]]
tools.vesselDamageReport = {
	id = "vesselDamageReport",
	label = "Damage report",
	section = "Vessel",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		return true, V.damageReport()
	end,
}

tools.vesselDamageSet = {
	id = "vesselDamageSet",
	label = "Set hull integrity",
	section = "Vessel",
	scope = "global",
	controls = { kind = "choice", options = { "full", "75%", "50%", "25%", "critical (5%)" } },
	run = function(_player: Player, args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		local map = { full = 1, ["75%"] = 0.75, ["50%"] = 0.5, ["25%"] = 0.25, ["critical (5%)"] = 0.05 }
		local f = map[tostring(args and args.value)]
		if f == nil then return false, "unknown level" end
		V.setIntegrity(f)
		--[[
			Says out loud that it did NOT fire the ladder, because the natural expectation is that dropping to
			25% breaks things - and a tool that silently does less than you expect is worse than one that does
			nothing. Inflicting a fault is a separate tool on purpose.
		]]
		return true, ("integrity %.0f/%.0f (%.0f%%). Faults NOT fired - the ladder is re-armed to match, so "
			.. "storm exposure will fire from here. Use 'Inflict fault' to break something now.")
			:format(V.state.integrity, V.state.integrityMax, f * 100)
	end,
}

tools.vesselFault = {
	id = "vesselFault",
	label = "Inflict fault",
	section = "Vessel",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "engine cut", "hull breach", "steering", "radar (stub)", "generator (stub)", "REPAIR ALL" },
	},
	run = function(_player: Player, args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		local choice = tostring(args and args.value)
		if choice == "REPAIR ALL" then
			V.repairAll()
			return true, "all faults cleared, flooding pumped out, integrity restored, ladder re-armed"
		end
		local map = {
			["engine cut"] = "engine",
			["hull breach"] = "breach",
			steering = "steering",
			["radar (stub)"] = "radar",
			["generator (stub)"] = "generator",
		}
		local id = map[choice]
		if not id then return false, "unknown fault" end
		V.inflict(id)
		local notes = {
			engine = ("thrust is dead for %ds; she keeps her way on and still answers the wheel")
				:format(require(ReplicatedStorage.VesselDamage).ENGINE_CUT_SECONDS),
			breach = "flooding is rising; she will sit lower and start taking water over the deck",
			steering = "rudder authority cut - the turn takes more than twice as long to build",
			radar = "flag only: GAME-0002 does not exist yet, so nothing consumes it",
			generator = "flag only: there are no deck lights or radar power to lose yet",
		}
		return true, ("%s inflicted. %s\n\nDamage control is the locker on the aft deck - hold for 3s."):format(id, notes[id])
	end,
}

tools.vesselFuel = {
	id = "vesselFuel",
	label = "Set fuel",
	section = "Vessel",
	scope = "global",
	controls = { kind = "choice", options = { "full", "half", "almost empty", "empty" } },
	run = function(_player: Player, args: any)
		local V = vessel()
		if not V then return false, "no vessel - is the game in Play?" end
		local spec = V.state.spec
		local map = { full = 1, half = 0.5, ["almost empty"] = 0.05, empty = 0 }
		local f = map[tostring(args and args.value)]
		if f == nil then return false, "unknown amount" end
		V.setFuel(spec.fuelCapacity * f)
		return true, ("fuel %.1f/%.0f. At full throttle that is %.0fs of running."):format(
			V.state.fuel, spec.fuelCapacity, V.state.fuel / spec.fuelBurn)
	end,
}

--[[
	TIME OF DAY.

	`DayNight.jumpTo` has existed since job 016 and was exposed nowhere, so changing the hour meant waiting up
	to 9.5 minutes for a phase to come round. That blocked judging the night look at all - not just whether
	the gulls go quiet.

	Server-side, correctly: the clock lives in Workspace attributes and everyone must agree what time it is.
]]
tools.timeOfDay = {
	id = "timeOfDay",
	label = "Time of day",
	section = "Sea",
	scope = "global",
	controls = {
		kind = "choice",
		options = { "Dawn", "Day", "Dusk", "Night", "pause", "resume" },
	},
	run = function(_player: Player, args: any)
		local mod = ReplicatedStorage:FindFirstChild("DayNight")
		if not mod then return false, "DayNight not found" end
		local ok, DN = pcall(require, mod)
		if not ok then return false, "DayNight failed to load: " .. tostring(DN) end
		local value = tostring(args and args.value)
		if value == "pause" then
			DN.pause()
			return true, "clock paused. The composer still runs, so the look keeps updating."
		elseif value == "resume" then
			DN.resume()
			return true, "clock resumed"
		end
		DN.jumpTo(value)
		--[[
			Compose immediately. The world tick would do it within a second anyway, but a control that
			appears to do nothing for a beat reads as broken.
		]]
		pcall(DN.compose)
		local phase, progress = DN.currentPhase()
		return true, ("jumped to %s (%.0f%% through)\n%s"):format(phase, progress * 100, DN.report())
	end,
}

--[[
	AUDIO.

	🔴 THESE RUN ON THE CLIENT. See the note in AdminClient's `CLIENT_HANDLERS`.

	`scope = "local"` was only ever metadata about what a tool AFFECTS - every handler here is invoked by
	AdminServer, i.e. on the server, where the audio beds and VFX rigs have never been started. So these
	readouts truthfully reported nothing running. AdminClient now intercepts them by id and runs them locally,
	where the state actually lives. The definitions stay here so the panel's labels and options still come
	from the server.
]]
local function stormAudio()
	local m = ReplicatedStorage:FindFirstChild("StormAudio")
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

tools.audioReport = {
	id = "audioReport",
	label = "Audio status (every channel)",
	section = "Audio",
	scope = "local",
	controls = { kind = "button", output = "text" },
	run = function(_player: Player, _args: any)
		--[[
			Both modules, in one readout. They are levelled from the same attributes, so seeing them side by
			side is how you catch one of them disagreeing - and a silent channel here is diagnosable rather
			than mysterious, which is the lesson of the VFX that never started (finding 0011).
		]]
		local lines = {}
		local A = stormAudio()
		if A then
			table.insert(lines, "===== STORM (wind / rain / thunder) =====")
			table.insert(lines, A.report())
		else
			table.insert(lines, "StormAudio not found")
		end
		table.insert(lines, "")
		local ambMod = ReplicatedStorage:FindFirstChild("Ambience")
		if ambMod then
			local ok, Amb = pcall(require, ambMod)
			table.insert(lines, "===== AMBIENCE (ocean / birds / storm bed) =====")
			table.insert(lines, ok and Amb.report() or ("failed to load: " .. tostring(Amb)))
		else
			table.insert(lines, "Ambience not found")
		end
		return true, table.concat(lines, "\n")
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
--[[
	SOLO one audio channel.

	Nine beds play at once, and picking one out by ear is genuinely hard - `deadCalm` is deliberately
	near-subsonic and `birds` peaks at 0.22. Runs on the CLIENT: `AudioBed.setSolo` is a module-level setting,
	and the server's copy of that module is not the one making any noise.
]]
tools.audioSolo = {
	id = "audioSolo",
	label = "Solo one channel",
	section = "Audio",
	scope = "local",
	controls = {
		kind = "choice",
		options = { "off (mix)", "oceanCalm", "oceanHeavy", "deadCalm", "birds", "stormBed",
			"windLow", "windHigh", "rain", "thunder" },
	},
	run = function(_player: Player, _args: any)
		-- never reached: AdminClient intercepts this id. Kept so the manifest carries label and options.
		return false, "this tool runs on the client"
	end,
}

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
	--[[
		Sections in a DELIBERATE order, not alphabetically.

		Alphabetical put Audio first and Sea in the middle, which is meaningless to anyone using the panel.
		This orders by how often a section is actually reached for while working: the storm and the weather
		are what gets driven, the sea is set less often, audio is being tuned right now, and Diagnostics is
		where you go when something is wrong rather than as a matter of course.

		A section not listed here falls to the end alphabetically, so adding one never breaks the sort - it
		just does not get a considered position until someone gives it one.
	]]
	local SECTION_ORDER = { Vessel = 1, Storm = 2, Weather = 3, Sea = 4, Audio = 5, Diagnostics = 6 }
	table.sort(list, function(a, b)
		if a.section == b.section then
			return a.label < b.label
		end
		local ra = SECTION_ORDER[a.section] or 99
		local rb = SECTION_ORDER[b.section] or 99
		if ra == rb then
			return a.section < b.section
		end
		return ra < rb
	end)
	return list
end

return AdminTools
