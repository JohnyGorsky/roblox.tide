--!strict
--[[
	AdminClient - the button and the panel.

	🔴 Nothing is created until the server confirms this player is an admin. The UI is not built-and-hidden:
	a hidden Frame is trivially unhidden, and an exploiter reading it learns every tool and argument name.
	If the handshake fails or returns not-ok, this script does nothing at all and leaves no trace.

	The client is a keyboard and a screen. It asks; the server decides. Nothing here is a permission check
	- the `handshake` gate below is a *UI* decision, not a security boundary. The security boundary is
	AdminServer, which re-checks every call.

	Layout notes (docs/build/09-ui.md, `mobile` skill): the place is landscape-only with a
	DynamicThumbstick, which reserves the bottom-LEFT quadrant for movement. So the button lives
	bottom-RIGHT, and tap targets are >= 44px.

	⚠️ FILE SUFFIX MATTERS HERE. This file is `.local.luau`, which Studio Sync turns into a LocalScript
	(RunContext = Legacy). It was originally `.client.luau`, which becomes a Script with
	RunContext = Client - and Roblox runs such a script TWICE in StarterPlayerScripts (once in place,
	once as the PlayerScripts copy), which built two panels. Verified 2026-08-20.
	Client scripts under StarterPlayerScripts must be `.local.luau`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local remote = ReplicatedStorage:WaitForChild("AdminRemote", 30)
if not remote or not remote:IsA("RemoteFunction") then
	return
end

-- ---------------------------------------------------------------------------
-- Handshake. No UI exists before this succeeds.
-- ---------------------------------------------------------------------------

local okCall, response = pcall(function()
	return (remote :: RemoteFunction):InvokeServer("handshake", nil)
end)
if not okCall or typeof(response) ~= "table" or not response.ok then
	return -- not an admin, or the server refused. Build nothing.
end

local toolManifest = response.tools or {}
local adminLabel = tostring(response.label)

-- ---------------------------------------------------------------------------
-- Palette (docs/game/visual-design.md)
-- ---------------------------------------------------------------------------

local ABYSS = Color3.fromRGB(11, 30, 45)
local PANEL = Color3.fromRGB(20, 40, 56)
local LINE = Color3.fromRGB(46, 70, 88)
local TEXT = Color3.fromRGB(220, 234, 242)
local MUTED = Color3.fromRGB(140, 154, 163)
local RADAR = Color3.fromRGB(82, 255, 154)
local AMBER = Color3.fromRGB(242, 181, 68)
local DANGER = Color3.fromRGB(217, 75, 75)

local FONT = Enum.Font.Gotham
local FONT_MONO = Enum.Font.Code

-- ---------------------------------------------------------------------------
-- Small UI helpers
-- ---------------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color or TEXT
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, size + 8)
	t.Parent = parent
	return t
end

local function button(parent: Instance, text: string, height: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height)
	b.BackgroundColor3 = Color3.fromRGB(31, 56, 74)
	b.BorderSizePixel = 0
	b.Font = FONT
	b.Text = text
	b.TextSize = 14
	b.TextColor3 = TEXT
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	stroke(b, LINE)
	return b
end

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Bottom-RIGHT: the bottom-left quadrant belongs to Roblox's DynamicThumbstick.
local toggle = Instance.new("TextButton")
toggle.Name = "AdminToggle"
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.Position = UDim2.new(1, -14, 1, -14)
toggle.Size = UDim2.fromOffset(52, 52)
toggle.BackgroundColor3 = ABYSS
toggle.BorderSizePixel = 0
toggle.Font = FONT
toggle.Text = "ADM"
toggle.TextSize = 13
toggle.TextColor3 = RADAR
toggle.Parent = gui
corner(toggle, 10)
stroke(toggle, RADAR, 1.5)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -14, 1, -78)
panel.Size = UDim2.fromOffset(330, 460)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 10)
stroke(panel, LINE)

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = ABYSS
header.BorderSizePixel = 0
header.Parent = panel
corner(header, 10)

local title = label(header, "ADMIN  ·  " .. adminLabel, 13, RADAR)
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -50, 0, 20)

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -10, 0.5, 0)
close.Size = UDim2.fromOffset(28, 28)
close.BackgroundTransparency = 1
close.Font = FONT
close.Text = "✕"
close.TextSize = 16
close.TextColor3 = MUTED
close.Parent = header

-- Scrolling body
local body = Instance.new("ScrollingFrame")
body.Position = UDim2.fromOffset(0, 40)
body.Size = UDim2.new(1, 0, 1, -104)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollBarImageColor3 = LINE
body.CanvasSize = UDim2.new()
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)
pad.Parent = body

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = body

-- Output strip
local outFrame = Instance.new("Frame")
outFrame.AnchorPoint = Vector2.new(0, 1)
outFrame.Position = UDim2.new(0, 0, 1, 0)
outFrame.Size = UDim2.new(1, 0, 0, 64)
outFrame.BackgroundColor3 = ABYSS
outFrame.BorderSizePixel = 0
outFrame.Parent = panel
corner(outFrame, 10)

local output = Instance.new("TextBox")
output.Position = UDim2.fromOffset(10, 6)
output.Size = UDim2.new(1, -20, 1, -12)
output.BackgroundTransparency = 1
output.Font = FONT_MONO
output.Text = "ready"
output.TextSize = 11
output.TextColor3 = MUTED
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.ClearTextOnFocus = false
output.TextEditable = false -- selectable, so Copy-as-Luau output can be copied out
output.MultiLine = true
output.Parent = outFrame

local function say(text: string, colour: Color3?)
	output.Text = text
	output.TextColor3 = colour or MUTED
end

-- ---------------------------------------------------------------------------
-- Calling the server
-- ---------------------------------------------------------------------------

--[[
	🔴 TOOLS THAT MUST RUN ON THE CLIENT.

	This exists because of a bug worth spelling out. `AdminServer` invokes every `tool.run` itself, so
	`scope = "local"` was only ever metadata about what a tool AFFECTS - it never controlled where the handler
	EXECUTES. Everything ran on the server.

	For most tools that is correct: the sea state, the clock and the storm all live in Workspace attributes and
	everyone must agree on them. But the audio beds and the weather VFX rigs are built by THIS script, on the
	client, and exist nowhere else. So a server-side handler inspecting them found no beds and no rigs, and
	truthfully reported nothing running - a readout that was confidently, silently wrong.

	It went unnoticed because the automated checks ran in a single Studio context which had started those
	modules itself, so the state the handler looked for happened to be there.

	These handlers run locally instead. The tool DEFINITIONS stay in ServerStorage so the panel's labels and
	options still come from the server, and every tool that changes the world still goes through the server's
	authorisation - that boundary is untouched. Only read-only diagnostics and client-local audio moved.
]]
local function requireShared(name: string)
	local m = ReplicatedStorage:FindFirstChild(name)
	if not m then
		return nil, name .. " not found"
	end
	local ok, mod = pcall(require, m)
	if not ok then
		return nil, name .. " failed to load: " .. tostring(mod)
	end
	return mod, nil
end

local CLIENT_HANDLERS: { [string]: (any) -> (boolean, string) } = {
	--- Is the client half of the weather actually running? The question job 017's dead VFX made necessary.
	vfxReport = function(_args)
		local lines = {}
		for _, name in ipairs({ "StormVFX", "CloudWallVFX", "LightningVFX" }) do
			local mod, err = requireShared(name)
			table.insert(lines, "-- " .. name .. " --")
			table.insert(lines, mod and mod.report() or tostring(err))
			table.insert(lines, "")
		end
		return true, table.concat(lines, "\n")
	end,

	audioReport = function(_args)
		local lines = {}
		local SA, saErr = requireShared("StormAudio")
		table.insert(lines, "===== STORM (wind / rain / thunder) =====")
		table.insert(lines, SA and SA.report() or tostring(saErr))
		table.insert(lines, "")
		local Amb, ambErr = requireShared("Ambience")
		table.insert(lines, "===== AMBIENCE (ocean / birds / storm bed) =====")
		table.insert(lines, Amb and Amb.report() or tostring(ambErr))
		return true, table.concat(lines, "\n")
	end,

	--[[
		What normally drives each channel.

		Included because the first version of solo just went quiet and the control looked broken. Six of the
		nine channels are legitimately silent at default conditions, so a tester needs to be told what would
		bring one in - otherwise "solo deadCalm" and "solo a channel that is broken" look identical.
	]]
	audioSolo = (function()
		local DRIVEN_BY = {
			oceanCalm = "calm seas - loudest at low severity, fades as the sea worsens",
			oceanHeavy = "sea severity above ~0.2. Sea -> Sea state -> Choppy or Storm",
			deadCalm = "severity below 0.15 only. Sea -> Sea state -> DeadCalm",
			birds = "daylight AND calm AND no storm. Sea -> Time of day -> Day",
			stormBed = "storm intensity 1+. Storm -> Storm distance -> 2.5 km or nearer",
			windLow = "Wind, thinning above 0.35. Weather -> Pin today's weather -> Slight/Moderate",
			windHigh = "Wind above 0.35 only. Weather -> Pin today's weather -> Fresh or Rough",
			rain = "Precipitation. Weather -> Pin -> Rough, or close the storm in",
			thunder = "NOTHING - it is a one-shot, fired only by a lightning strike",
		}
		return function(args)
			local Bed, err = requireShared("AudioBed")
			if not Bed then
				return false, tostring(err)
			end
			local value = tostring(args and args.value or "")
			if value == "" or value:find("off") then
				Bed.setSolo(nil)
				return true, "solo off - normal mix restored"
			end
			Bed.setSolo(value)

			--[[
				Thunder is a one-shot and has no bed, so solo cannot force it up - there is nothing playing to
				force. Fire one instead, which is what the tester actually wanted.
			]]
			if value == "thunder" then
				local SA = requireShared("StormAudio")
				if SA then
					SA.thunder(500, 0.9)
					return true, "SOLO: thunder\nFired one strike at 500 studs. It is a ONE-SHOT, so there is nothing to sustain - click again to hear it, or Storm -> Force a lightning strike to hear it in context."
				end
			end

			return true, ("SOLO: %s\nForced to full so you can hear it, and everything else muted.\nNormally driven by: %s"):format(
				value, DRIVEN_BY[value] or "unknown")
		end
	end)(),

	audioAudition = function(args)
		local SA, err = requireShared("StormAudio")
		if not SA then
			return false, tostring(err)
		end
		local raw = tostring(args and args.value or "")
		local slot, id = raw:match("^%s*(%a+)%s*=%s*(.+)%s*$")
		if not slot then
			return false, "expected  slot=id  - slots are: windLow, windHigh, rain, thunder"
		end
		local ok, msg = SA.setId(slot, id)
		if not ok then
			return false, msg
		end
		if slot == "thunder" then
			SA.thunder(600, 0.9)
			return true, msg .. "\nplayed once at 600 studs. Force a strike to hear it in context."
		end
		return true, msg .. "\nlooping now - move the wind to hear it level."
	end,
}

local function call(action: string, args: any?)
	--[[
		Client-side tools never reach the network. They inspect or change state that only exists here, so
		there is nothing for the server to answer.
	]]
	local handler = CLIENT_HANDLERS[action]
	if handler then
		local okRun, okResult, text = pcall(handler, args)
		if not okRun then
			say("client tool error: " .. tostring(okResult), DANGER)
			return nil
		end
		say(tostring(text), okResult and RADAR or AMBER)
		return { ok = okResult, result = text }
	end

	local ok, res = pcall(function()
		return (remote :: RemoteFunction):InvokeServer(action, args)
	end)
	if not ok then
		say("call failed: " .. tostring(res), DANGER)
		return nil
	end
	if typeof(res) ~= "table" then
		say("unexpected response", DANGER)
		return nil
	end
	if not res.ok then
		say(("refused: %s"):format(tostring(res.error or res.result)), AMBER)
		return res
	end
	if res.result ~= nil then
		say(tostring(res.result), RADAR)
	else
		say("ok", RADAR)
	end
	return res
end

-- ---------------------------------------------------------------------------
-- Build the UI from the server-supplied manifest
-- ---------------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

--[[
	COLLAPSIBLE SECTIONS.

	The panel reached 33 tools in one flat scrolling list and became a wall - you scrolled past four sections
	to reach the one you wanted, and the sheer length made it read as complicated rather than capable.

	Each header is now a button that toggles its own container, and everything starts COLLAPSED except the
	section named in `OPEN_BY_DEFAULT`. So the panel opens as a short list of headers you can read at a glance.

	`currentParent` is what makes this a small change: the build helpers below parent into it rather than into
	`body`, so adding a tool needs no knowledge of sections at all.
]]
local currentParent: Instance = body
local sectionCount = 0

--[[
	The FIRST section is open on arrival; everything else starts collapsed.

	Keyed off position rather than a section name on purpose - the server decides the order (see
	SECTION_ORDER in AdminTools), so naming a section here would let the two drift apart and quietly leave
	the panel opening on whatever happened to be called that.
]]

local function section(name: string)
	sectionCount += 1

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundColor3 = Color3.fromRGB(24, 43, 58)
	header.BorderSizePixel = 0
	header.Font = FONT
	header.TextSize = 12
	header.TextColor3 = TEXT
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.AutoButtonColor = true
	header.LayoutOrder = nextOrder()
	header.Parent = body
	corner(header, 6)
	stroke(header, LINE)

	local hpad = Instance.new("UIPadding")
	hpad.PaddingLeft = UDim.new(0, 10)
	hpad.Parent = header

	-- The container every tool in this section lives in. Collapsing is just hiding this.
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.LayoutOrder = nextOrder()
	container.Parent = body

	local inner = Instance.new("UIListLayout")
	inner.Padding = UDim.new(0, 6)
	inner.SortOrder = Enum.SortOrder.LayoutOrder
	inner.Parent = container

	local ipad = Instance.new("UIPadding")
	ipad.PaddingTop = UDim.new(0, 6)
	ipad.PaddingBottom = UDim.new(0, 6)
	ipad.PaddingLeft = UDim.new(0, 6)
	ipad.Parent = container

	local open = (sectionCount == 1)
	local function refresh()
		container.Visible = open
		-- the caret is the whole affordance; without it a header looks like a label, not a control
		header.Text = ("%s  %s"):format(open and "▾" or "▸", name:upper())
	end
	refresh()
	header.Activated:Connect(function()
		open = not open
		refresh()
	end)

	currentParent = container
end


local function scopeTag(scope: string): string
	return scope == "global" and "  ·  all players" or "  ·  you only"
end

local function buildChoice(tool: any)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.LayoutOrder = nextOrder()
	holder.Parent = currentParent

	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 4)
	l.Parent = holder

	local head = label(holder, tool.label .. scopeTag(tool.scope), 12)
	head.LayoutOrder = 1

	--[[
		MANY OPTIONS WRAP INTO TWO COLUMNS.

		A full-width button per option is fine for three or four, and becomes a wall at ten - the audio solo
		control alone was ten stacked rows, which reintroduced inside one section exactly the crowding the
		collapsible sections were meant to fix.

		Two columns rather than three: option labels here are words like "oceanHeavy" and "0.15 km THE WALL",
		and a third column makes them truncate. Tap targets stay >= 34px tall, which the mobile guidance
		requires, so wrapping costs nothing there.
	]]
	local options = tool.controls.options
	local twoColumn = #options > 5

	if not twoColumn then
		for i, opt in ipairs(options) do
			local b = button(holder, tostring(opt), 34)
			b.LayoutOrder = i + 1
			b.Activated:Connect(function()
				call(tool.id, { value = opt })
			end)
		end
		return
	end

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.LayoutOrder = 2
	grid.Parent = holder

	local flow = Instance.new("UIGridLayout")
	flow.CellPadding = UDim2.fromOffset(4, 4)
	-- 0.5 scale minus half the padding, so two cells plus the gap fit the width exactly
	flow.CellSize = UDim2.new(0.5, -2, 0, 32)
	flow.SortOrder = Enum.SortOrder.LayoutOrder
	flow.Parent = grid

	for i, opt in ipairs(options) do
		local b = button(grid, tostring(opt), 32)
		b.Size = UDim2.new() -- the grid owns sizing
		b.TextSize = 12 -- a half-width cell needs a smaller face or the longer labels clip
		b.LayoutOrder = i
		b.Activated:Connect(function()
			call(tool.id, { value = opt })
		end)
	end
end

local function buildSliders(tool: any)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.LayoutOrder = nextOrder()
	holder.Parent = currentParent

	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 6)
	l.Parent = holder

	local head = label(holder, tool.label .. scopeTag(tool.scope), 12)
	head.LayoutOrder = 1

	for i, field in ipairs(tool.controls.fields) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 44)
		row.LayoutOrder = i + 1
		row.Parent = holder

		local name = label(row, field.label, 11, MUTED)
		name.Size = UDim2.new(1, 0, 0, 14)

		-- A drag-free slider: a track with -/+ steppers. Deliberately simple - it must work with a
		-- thumb on a phone, and a 4px drag handle does not.
		local minus = button(row, "−", 26)
		minus.Position = UDim2.fromOffset(0, 18)
		minus.Size = UDim2.fromOffset(34, 26)

		local valueBox = Instance.new("TextBox")
		valueBox.Position = UDim2.fromOffset(40, 18)
		valueBox.Size = UDim2.new(1, -80, 0, 26)
		valueBox.BackgroundColor3 = ABYSS
		valueBox.BorderSizePixel = 0
		valueBox.Font = FONT_MONO
		valueBox.TextSize = 12
		valueBox.TextColor3 = TEXT
		valueBox.Text = "—"
		valueBox.ClearTextOnFocus = false
		valueBox.Parent = row
		corner(valueBox, 5)
		stroke(valueBox, LINE)

		local plus = button(row, "+", 26)
		plus.AnchorPoint = Vector2.new(1, 0)
		plus.Position = UDim2.new(1, 0, 0, 18)
		plus.Size = UDim2.fromOffset(34, 26)

		local current = (field.min + field.max) / 2

		local function push(v: number)
			current = math.clamp(v, field.min, field.max)
			valueBox.Text = string.format("%.2f", current)
			call(tool.id, { key = field.key, value = current })
		end

		minus.Activated:Connect(function()
			push(current - field.step)
		end)
		plus.Activated:Connect(function()
			push(current + field.step)
		end)
		valueBox.FocusLost:Connect(function(enter)
			if not enter then
				return
			end
			local n = tonumber(valueBox.Text)
			if n then
				push(n)
			else
				valueBox.Text = string.format("%.2f", current)
			end
		end)
	end
end

local function buildBlend(tool: any)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.LayoutOrder = nextOrder()
	holder.Parent = currentParent

	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 4)
	l.Parent = holder

	local head = label(holder, tool.label .. scopeTag(tool.scope), 12)
	head.LayoutOrder = 1

	local opts = tool.controls.options
	local aIdx, bIdx, t = 2, 4, 0.5

	local pick = label(holder, "", 11, MUTED)
	pick.LayoutOrder = 2

	local function refresh()
		pick.Text = ("%s → %s   t=%.2f"):format(opts[aIdx], opts[bIdx], t)
	end
	refresh()

	local cycleA = button(holder, "cycle A", 30)
	cycleA.LayoutOrder = 3
	cycleA.Activated:Connect(function()
		aIdx = (aIdx % #opts) + 1
		refresh()
	end)

	local cycleB = button(holder, "cycle B", 30)
	cycleB.LayoutOrder = 4
	cycleB.Activated:Connect(function()
		bIdx = (bIdx % #opts) + 1
		refresh()
	end)

	local less = button(holder, "t − 0.1", 30)
	less.LayoutOrder = 5
	less.Activated:Connect(function()
		t = math.clamp(t - 0.1, 0, 1)
		refresh()
		call(tool.id, { a = opts[aIdx], b = opts[bIdx], t = t })
	end)

	local more = button(holder, "t + 0.1", 30)
	more.LayoutOrder = 6
	more.Activated:Connect(function()
		t = math.clamp(t + 0.1, 0, 1)
		refresh()
		call(tool.id, { a = opts[aIdx], b = opts[bIdx], t = t })
	end)
end

--[[
	A free-text control: a box plus a send button.

	Added for auditioning sound ids (job 018). The point is that a candidate clip cannot be judged from its
	Creator Store page - it has to be heard under the wind bed at the volume curve the storm gives it - so
	the id has to be pasteable at runtime rather than compiled in.

	`ClearTextOnFocus = false` deliberately: the usual use is pasting one id, tweaking a digit, and sending
	again, and clearing on focus makes that infuriating.
]]
local function buildText(tool: any)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 62)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = nextOrder()
	holder.Parent = currentParent

	local title = label(holder, tool.label .. scopeTag(tool.scope), 13)
	title.Size = UDim2.new(1, 0, 0, 18)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -74, 0, 32)
	box.Position = UDim2.new(0, 0, 0, 22)
	box.BackgroundColor3 = Color3.fromRGB(18, 32, 44)
	box.BorderSizePixel = 0
	box.Font = FONT
	box.TextSize = 13
	box.TextColor3 = TEXT
	box.PlaceholderText = (tool.controls and tool.controls.placeholder) or ""
	box.PlaceholderColor3 = Color3.fromRGB(110, 128, 142)
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = holder
	corner(box, 6)
	stroke(box, LINE)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = box

	local send = button(holder, "Send", 32)
	send.Size = UDim2.new(0, 68, 0, 32)
	send.Position = UDim2.new(1, -68, 0, 22)

	local function submit()
		if box.Text ~= "" then
			call(tool.id, { value = box.Text })
		end
	end
	send.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

local function buildButton(tool: any)
	local b = button(currentParent, tool.label .. scopeTag(tool.scope), 36)
	b.LayoutOrder = nextOrder()
	b.Activated:Connect(function()
		call(tool.id, nil)
	end)
end

local currentSection: string? = nil
for _, tool in ipairs(toolManifest) do
	if tool.section ~= currentSection then
		currentSection = tool.section
		section(tool.section)
	end
	local kind = tool.controls and tool.controls.kind
	if kind == "choice" then
		buildChoice(tool)
	elseif kind == "sliders" then
		buildSliders(tool)
	elseif kind == "blend" then
		buildBlend(tool)
	elseif kind == "text" then
		buildText(tool)
	else
		buildButton(tool)
	end
end

-- Audit log viewer, always last
section("Audit")
local auditBtn = button(body, "Show recent admin actions", 36)
auditBtn.LayoutOrder = nextOrder()
auditBtn.Activated:Connect(function()
	call("auditLog", nil)
end)

-- ---------------------------------------------------------------------------
-- Open / close
-- ---------------------------------------------------------------------------

local function setOpen(open: boolean)
	panel.Visible = open
	toggle.TextColor3 = open and AMBER or RADAR
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F4 then
		setOpen(not panel.Visible)
	end
end)

say(("admin panel ready · %d tools · F4 toggles"):format(#toolManifest), RADAR)
print(("[ADMIN] panel built for %s (%d tools)"):format(adminLabel, #toolManifest))
