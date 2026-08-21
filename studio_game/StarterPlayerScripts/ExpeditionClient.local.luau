--!strict
--[[
	ExpeditionClient - the beat when a run ends.

	Feature: GAME-0001 / GAME-0003  ·  decision 0024  ·  job 023

	--------------------------------------------------------------------------------------------------
	THE GAME-PLACE HALF OF A SPLIT SUMMARY

	The ruling was a split: a beat HERE, where the run actually ended, and the full breakdown in the lobby
	after the trip home. So this is the beat - she goes down, or you make your northing, and the screen holds
	on what just happened. The lobby's panel and the teleport that reaches it belong to Planned 0002.

	Which means this screen currently has no exit, and that is honest rather than unfinished: there is
	nowhere to go yet. It says so.

	--------------------------------------------------------------------------------------------------
	🔴 HEARTBEAT, NOT RenderStepped

	Finding 0022, measured: in an unfocused Studio session `RenderStepped` fires ZERO times while `Heartbeat`
	runs at 60 Hz. A screen driven by `RenderStepped` is untestable over MCP and looks broken with no error
	anywhere - which is exactly what happened to the compass in this same job.

	--------------------------------------------------------------------------------------------------
	AND NO HEADING ON IT, EVER

	Decision 0014: *"the HUD must never show a heading, or the blindness is free."* This panel shows how far
	the crew came, what ended the run, and how long it took. Northing is a scalar - it says nothing about
	which way is out. Do not be tempted to add a bearing here because the run is already over; the screen
	outlives the run only by a moment, and the rule is easier to keep than to re-litigate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Expedition = require(ReplicatedStorage:WaitForChild("Expedition"))

local player = Players.LocalPlayer
local ATTR = Expedition.ATTR

-- palette, matching the admin panel's (there is no style guide yet - todo 0001)
local ABYSS = Color3.fromRGB(11, 30, 45)
local LINE = Color3.fromRGB(46, 70, 88)
local CREAM = Color3.fromRGB(226, 228, 224)
local RADAR = Color3.fromRGB(82, 255, 154)
local RUST = Color3.fromRGB(226, 122, 63)

local gui = Instance.new("ScreenGui")
gui.Name = "ExpeditionEnd"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

--[[
	A full-screen wash rather than a small card. The run ending is the loudest thing that happens in a
	session and a corner notification would undersell it - and on the loss path the deck is sinking behind
	it, which is worth letting the player watch through a veil rather than a solid panel.
]]
local wash = Instance.new("Frame")
wash.Size = UDim2.fromScale(1, 1)
wash.BackgroundColor3 = ABYSS
wash.BackgroundTransparency = 1
wash.BorderSizePixel = 0
wash.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
--[[
	Scale-based, with an aspect constraint, so it holds together on a phone. The `mobile` skill's rule is to
	measure rather than guess, and this is not measured on a device yet - but a scale-sized panel with a
	pinned aspect ratio is the shape that survives being wrong.
]]
panel.Size = UDim2.fromScale(0.46, 0.34)
panel.BackgroundColor3 = ABYSS
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = wash

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1.55
aspect.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = LINE
stroke.Thickness = 2
stroke.Parent = panel

local function label(name: string, y: number, height: number, size: number, colour: Color3, font: Enum.Font): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = UDim2.fromScale(0.06, y)
	t.Size = UDim2.fromScale(0.88, height)
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextColor3 = colour
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = ""
	t.Parent = panel
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = t
	return t
end

local verdict = label("Verdict", 0.10, 0.20, 40, CREAM, Enum.Font.GothamBold)
local cause = label("Cause", 0.32, 0.14, 22, RUST, Enum.Font.Gotham)
local stats = label("Stats", 0.50, 0.30, 18, RADAR, Enum.Font.Code)
local footer = label("Footer", 0.82, 0.12, 14, LINE, Enum.Font.Gotham)

local shown = false

local function show()
	if shown then
		return
	end
	shown = true

	local state = tostring(workspace:GetAttribute(ATTR.state))
	local causeId = workspace:GetAttribute(ATTR.cause)
	local northing = workspace:GetAttribute(ATTR.northing)
	local target = workspace:GetAttribute(ATTR.target)

	verdict.Text = state == "Finished" and "You made the northing" or "The expedition is over"
	verdict.TextColor3 = state == "Finished" and RADAR or CREAM
	cause.Text = Expedition.causeText(typeof(causeId) == "string" and causeId ~= "" and causeId :: any or nil)
	stats.Text = ("northing   %.0f / %.0f studs"):format(
		typeof(northing) == "number" and northing or 0,
		typeof(target) == "number" and target or 0)
	--[[
		Says out loud that the trip home does not exist yet. A screen that just hangs reads as a bug; a screen
		that tells you it is the end of what is built reads as a POC.
	]]
	footer.Text = "The passage home is not built yet — Planned 0002"

	gui.Enabled = true
	wash.BackgroundTransparency = 1
	panel.BackgroundTransparency = 1
	TweenService:Create(wash, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.42 }):Play()
	TweenService:Create(panel, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.08 }):Play()
end

local function hide()
	shown = false
	gui.Enabled = false
end

--[[
	Polled on a heartbeat rather than driven by an attribute-changed signal.

	`ExpeditionOver` going true is the event, and a signal would be the obvious wiring - but the panel also
	has to CLEAR when the admin panel resets the run to boarding, and it has to survive a respawn. Polling a
	single boolean four times a second costs nothing and cannot miss an edge.
]]
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < 0.25 then
		return
	end
	accumulated = 0

	local over = workspace:GetAttribute(ATTR.over) == true
	if over and not shown then
		show()
	elseif not over and shown then
		hide()
	end
end)

print("[EXPEDITION] client ready - the end-of-run beat is armed")
