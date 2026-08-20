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

local function call(action: string, args: any?)
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

local function section(name: string)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 22)
	holder.LayoutOrder = nextOrder()
	holder.Parent = body
	local t = label(holder, name:upper(), 11, MUTED)
	t.Size = UDim2.new(1, 0, 1, 0)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.new(0, 0, 1, 0)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = LINE
	line.BorderSizePixel = 0
	line.Parent = holder
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
	holder.Parent = body

	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 4)
	l.Parent = holder

	local head = label(holder, tool.label .. scopeTag(tool.scope), 12)
	head.LayoutOrder = 1

	for i, opt in ipairs(tool.controls.options) do
		local b = button(holder, tostring(opt), 34)
		b.LayoutOrder = i + 1
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
	holder.Parent = body

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
	holder.Parent = body

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

local function buildButton(tool: any)
	local b = button(body, tool.label .. scopeTag(tool.scope), 36)
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
