--!strict
--[[
	VesselClient - the helm. Reads input, sends two numbers.

	Feature: GAME-0001  ·  decision 0022  ·  job 021

	--------------------------------------------------------------------------------------------------
	WHY THIS EXISTS AT ALL

	Decision 0022 rejected `VehicleSeat`, which would have supplied `ThrottleFloat`/`SteerFloat` and the
	mobile touch controls for free. It was rejected because it hands NETWORK OWNERSHIP of the assembly to the
	driver on sit, and a server-side buoyancy loop reading a client-owned body pumps energy instead of
	removing it - the Jungle boat bounced higher and higher while driven.

	So this file is the debt that decision knowingly took on. It is the price of a stable hull.

	--------------------------------------------------------------------------------------------------
	IT SENDS INTENT, NOT FORCE

	Two clamped numbers, throttle and steer, each -1..1. The server decides what force they become, what fuel
	they cost, and whether the sender is even in the seat. There is nothing here worth exploiting.

	Sent on CHANGE rather than every frame - a boat's controls are held, not tapped, so streaming 60 identical
	messages a second would be pure waste.

	--------------------------------------------------------------------------------------------------
	.local.luau, NOT .client.luau

	`.client.luau` becomes a Script with RunContext = Client, which Roblox runs TWICE in StarterPlayerScripts
	(job 016). Every client entry point in this project is `.local.luau`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("VesselInput", 30)
if not remote or not remote:IsA("RemoteEvent") then
	return
end
local input = remote :: RemoteEvent

local throttle, steer = 0, 0
local lastSentThrottle, lastSentSteer = -99, -99
local seated = false

--- Send only when something actually changed, and only meaningfully.
local function push()
	if math.abs(throttle - lastSentThrottle) < 0.02 and math.abs(steer - lastSentSteer) < 0.02 then
		return
	end
	lastSentThrottle, lastSentSteer = throttle, steer
	input:FireServer(throttle, steer)
end

-- ---------------------------------------------------------------------------
-- Are we at the helm?
-- ---------------------------------------------------------------------------

--[[
	Are WE the driver?

	Read from the `VesselDriver` attribute the server publishes, not tracked locally with a flag. The server
	is the only thing that decides who has the helm, so asking it directly means the controls cannot appear
	for someone who is not actually steering.

	🔴 It is a STATION, not a seat. The first version keyed off `Humanoid.SeatPart`, and sitting welded the
	character into the hull's assembly - which handed the assembly to the client and destroyed the boat every
	time (see the note in VesselServer). The driver now stands at the console, staying their own assembly.
]]
local function isDriver(): boolean
	return workspace:GetAttribute("VesselDriver") == player.Name
end

-- ---------------------------------------------------------------------------
-- Mobile controls (the debt decision 0022 took on)
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HelmControls"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local ABYSS = Color3.fromRGB(11, 30, 45)
local LINE = Color3.fromRGB(46, 70, 88)
local RADAR = Color3.fromRGB(82, 255, 154)

--[[
	🔴 BOTTOM-RIGHT, NOT BOTTOM-LEFT.

	Roblox's DynamicThumbstick owns the bottom-left quadrant (this place sets `DevTouchMovementMode =
	DynamicThumbstick`, job 004), and the `mobile` skill measured its reserved rect. Putting helm controls
	there would put them under the player's left thumb and under Roblox's own widget.

	Tap targets are 60px, comfortably over the 44px floor - and a helm is held rather than tapped, so it wants
	to be forgiving.
]]
local pad = Instance.new("Frame")
pad.AnchorPoint = Vector2.new(1, 1)
pad.Position = UDim2.new(1, -14, 1, -80)
pad.Size = UDim2.fromOffset(196, 132)
pad.BackgroundTransparency = 1
pad.Parent = gui

local function padButton(text: string, x: number, y: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(60, 60)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = ABYSS
	b.BackgroundTransparency = 0.25
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.Text = text
	b.TextSize = 22
	b.TextColor3 = RADAR
	b.AutoButtonColor = true
	b.Parent = pad
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = LINE
	s.Parent = b
	return b
end

--[[
	Held rather than tapped, so each control binds press AND release. A tapped throttle would mean holding a
	finger down to keep the engine running, which is exactly the wrong ergonomics for a boat.
]]
local function bindHold(button: TextButton, onDown: () -> (), onUp: () -> ())
	button.MouseButton1Down:Connect(onDown)
	button.MouseButton1Up:Connect(onUp)
	button.MouseLeave:Connect(onUp) -- a finger sliding off must not leave the throttle open
	button.TouchLongPress:Connect(function(_, tState)
		if tState == Enum.UserInputState.End then
			onUp()
		end
	end)
end

local touchThrottle, touchSteer = 0, 0

local fwd = padButton("▲", 68, 0)
local rev = padButton("▼", 68, 68)
local left = padButton("◀", 0, 34)
local right = padButton("▶", 136, 34)

bindHold(fwd, function() touchThrottle = 1 end, function() touchThrottle = 0 end)
bindHold(rev, function() touchThrottle = -1 end, function() touchThrottle = 0 end)
bindHold(left, function() touchSteer = -1 end, function() touchSteer = 0 end)
bindHold(right, function() touchSteer = 1 end, function() touchSteer = 0 end)

-- ---------------------------------------------------------------------------
-- The loop
-- ---------------------------------------------------------------------------

--[[
	Throttle RAMPS rather than snapping.

	A real throttle lever is moved, not switched, and ramping is also what stops a full-ahead-from-stop
	command slamming the hull. Steering snaps, because a wheel is quick and the yaw authority is already
	speed-gated in the physics.
]]
local THROTTLE_RAMP = 1.6 -- units per second

RunService.RenderStepped:Connect(function(dt)
	local nowSeated = isDriver()
	if nowSeated ~= seated then
		seated = nowSeated
		gui.Enabled = seated and UserInputService.TouchEnabled
		--[[
			🔴 PIN THE DRIVER IN PLACE WHILE THEY STEER.

			W/S/A/D are the helm controls AND the walk controls, so without this the driver walks straight off
			the bow the moment they open the throttle. That is not a hypothetical - it is the obvious first
			thing to happen.

			`WalkSpeed = 0` rather than anchoring: anchoring a part while it stands on a moving assembly is the
			failure the physics guidance warns about, and it would also stop the deck carrying them. At zero
			walk speed the character simply stands there and rides the platform, which already works.

			Jump is disabled too - jumping off the helm mid-turn would leave the vessel driverless at speed.
		]]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = if seated then 0 else 16
			humanoid.JumpPower = if seated then 0 else 50
			humanoid.AutoRotate = not seated -- the driver faces the console, not wherever the keys point
		end
		if not seated then
			-- leaving the helm must close the throttle, not abandon it open
			throttle, steer = 0, 0
			push()
		end
	end
	if not seated then
		return
	end

	-- desktop keys, plus the touch pad if it is being used
	local keyFwd = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
	local keyRev = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
	local keyLeft = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
	local keyRight = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)

	local wantThrottle = (keyFwd and 1 or 0) + (keyRev and -1 or 0) + touchThrottle
	wantThrottle = math.clamp(wantThrottle, -1, 1)
	local wantSteer = math.clamp((keyLeft and -1 or 0) + (keyRight and 1 or 0) + touchSteer, -1, 1)

	-- ramp toward the demand
	local step = THROTTLE_RAMP * dt
	if throttle < wantThrottle then
		throttle = math.min(throttle + step, wantThrottle)
	elseif throttle > wantThrottle then
		throttle = math.max(throttle - step, wantThrottle)
	end
	steer = wantSteer

	push()
end)

print("[HELM] client ready. Walk to the helm console, press E to take the helm, then W/S throttle and A/D steer.")
