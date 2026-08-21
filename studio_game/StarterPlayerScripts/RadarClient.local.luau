--!strict
--[[
	RadarClient - draws the scope, and makes it ping.

	Feature: GAME-0002  ·  decisions 0004, 0014, 0019  ·  job 026

	--------------------------------------------------------------------------------------------------
	HEAD-UP, SO IT IS NOT A COMPASS

	Contacts are plotted at bearing MINUS our own heading, bow at the top. A north-up scope would be a heading
	readout, which decision 0014 forbids. See the `Radar` module header for why the storm arc is allowed to
	imply direction anyway.

	--------------------------------------------------------------------------------------------------
	🔴 HEARTBEAT, NOT RenderStepped

	Finding 0022, measured: `RenderStepped` fires ZERO times in an unfocused Studio session while `Heartbeat`
	runs at 60 Hz. The compass in job 022 looked broken for exactly this reason. A scope is a GUI rotation and
	a set of positions - it needs no render-time precision.

	--------------------------------------------------------------------------------------------------
	WHAT THE SOUNDS MEAN

	    sweep tick     once per revolution - the instrument's heartbeat, alternating two variants so it does
	                   not become audible as one repeating clip over a fifty-minute run
	    contact ping   only when a contact appears that was not on the scope before

	The ping deliberately does NOT fire every time the beam re-illuminates a known contact: that would be
	constant noise and would teach the operator to ignore it. A ping means *something new*, which is worth
	looking up for.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Radar = require(ReplicatedStorage:WaitForChild("Radar"))
local StormFront = require(ReplicatedStorage:WaitForChild("StormFront"))
--[[
	Required for ONE constant, `ASTERN_BEARING`, and deliberately rather than copying the number.

	The first version of this file read `StormFront.ASTERN_BEARING or 180`, which silently fell through to the
	fallback every single frame - the constant lives in `Lightning`, not `StormFront`. It worked by accident,
	which is the worst kind of working: had the storm's bearing ever changed, the radar would have gone on
	drawing it at 180 with nothing to indicate why.
]]
local Lightning = require(ReplicatedStorage:WaitForChild("Lightning"))
local SeaStates = require(ReplicatedStorage:WaitForChild("SeaStates"))

local player = Players.LocalPlayer
local TAG_SCOPE = "RadarScope"
local TAG_CONTACT = "RadarContact"

--- Approved and logged in roblox.workspace/Assets/registry/audio.md (job 026).
local SOUND = {
	sweep = { "9126138070", "9126138068" },
	contact = "75886285262316",
}

--- Only draw for someone close enough to read it. A scope updating for a player below decks costs nothing useful.
local READ_RANGE = 16

--[[
	The stroke is held on the record rather than looked up as `dot.UIStroke`. That lookup works at runtime -
	`Instance.new("UIStroke")` is named "UIStroke" by default - but it is a name-based child lookup dressed up
	as a property, so a rename would break it silently and the type checker rejects it outright.
]]
type Blip = {
	dot: Frame,
	stroke: UIStroke,
	label: TextLabel,
	lastSwept: number,
	seen: boolean,
}

local scope: SurfaceGui? = nil
local ui: { [string]: any } = {}
local blips: { [Instance]: Blip } = {}
local previousAngle = 0
local sweepIndex = 1

-- ---------------------------------------------------------------------------
-- Build the scope face
-- ---------------------------------------------------------------------------

local function circle(parent: Instance, scale: number, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	return f
end

local function buildScope(surface: SurfaceGui)
	surface:ClearAllChildren()

	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.fromRGB(8, 18, 22)
	face.BorderSizePixel = 0
	face.Parent = surface

	--[[
		The scope is a circle inset in the face, leaving a margin for the readouts and the legend. Everything
		inside is positioned in SCALE against this frame, so it stays correct whatever the console's size.
	]]
	--[[
		LANDSCAPE LAYOUT, matching the concept mockup: scope on the left, conditions on the right.

		The screen is 4 x 2.8 studs, so the dial is sized off HEIGHT and squared with an aspect constraint -
		sizing a circle in scale on a non-square face is what makes it an ellipse.
	]]
	local dial = Instance.new("Frame")
	dial.Name = "Dial"
	dial.AnchorPoint = Vector2.new(0, 0.5)
	dial.Position = UDim2.fromScale(0.035, 0.5)
	dial.Size = UDim2.fromScale(0.62, 0.9)
	dial.BackgroundColor3 = Radar.SCOPE_COLOUR
	dial.BorderSizePixel = 0
	dial.Parent = face
	local dialCorner = Instance.new("UICorner")
	dialCorner.CornerRadius = UDim.new(1, 0)
	dialCorner.Parent = dial
	local dialStroke = Instance.new("UIStroke")
	dialStroke.Color = Radar.RING_COLOUR
	dialStroke.Thickness = 2
	dialStroke.Parent = dial
	--[[
		Square, or the scope is an ellipse and every bearing on it is a lie - a contact drawn at 45 degrees
		would not sit at 45 degrees.
	]]
	local dialAspect = Instance.new("UIAspectRatioConstraint")
	dialAspect.AspectRatio = 1
	dialAspect.Parent = dial
	--[[
		🔴 CLIP TO THE SCOPE. Without this the storm mass - which is deliberately larger than the
		dial so it reads as a front rather than a dot - drew straight out over the bezel and off the console
		into the sky. An instrument whose contents escape its own housing does not read as an instrument.
	]]
	dial.ClipsDescendants = true
	ui.dial = dial

	-- range rings, from the module so the drawing cannot disagree with the maths
	ui.rings = {}
	for _, fraction in ipairs(Radar.RINGS) do
		if fraction < 1 then
			local ring = circle(dial, fraction, Radar.RING_COLOUR, 1)
			local s = Instance.new("UIStroke")
			s.Color = Radar.RING_COLOUR
			s.Thickness = 1
			s.Transparency = 0.45
			s.Parent = ring
			table.insert(ui.rings, s)
		end
	end

	--[[
		THE STORM, drawn as a soft mass rather than a hard arc.

		A true arc needs either an image or a lot of little frames. A large, very transparent circle placed at
		the storm's bearing and range reads as a weather mass on that side of the scope - which is what the
		mockup drew and what the thing actually is. Cheap, and it cannot accidentally look like a discrete
		contact you could steer around.
	]]
	ui.storm = circle(dial, 0.85, Radar.colourOf("storm"), 1)
	ui.storm.Name = "Storm"
	--[[
		🔴 ZIndex 1, NOT 0. It was 0 - meaning "behind the rings" - and it disappeared entirely.

		Every property was correct: visible, 49% opacity, a 422 px circle with half its area overlapping the
		dial. It rendered nowhere, because under `Global` ZIndex behaviour a descendant with a LOWER ZIndex
		than its parent draws beneath that parent's own background, and the dial's background is opaque.

		So 0 put the storm behind the very frame it lives in. 1 ties it with the rings, and since it is created
		BEFORE them it still draws underneath - which was the whole intent of using 0 in the first place.

		Worth remembering: "behind its siblings" is ZIndex 1 and earlier creation, never ZIndex 0.
	]]
	ui.storm.ZIndex = 1

	--[[
		THE SWEEPING BEAM, and it needs a PIVOT CONTAINER.

		🔴 `GuiObject.Rotation` rotates about the object's own CENTRE, not its `AnchorPoint`.

		The first version was a single bar anchored at its bottom edge (0.5, 1), sitting at the dial's centre,
		rotated directly. Anchoring positions it correctly but does NOT move the pivot - so it swung around its
		own midpoint and traced a circle offset from the middle of the scope. On screen it read as a detached
		line floating up and to one side of the dial, which is precisely what it was.

		The fix is the standard one: a full-dial container centred on the scope, rotated; the bar lives inside
		it, offset from the centre outward. Rotating the container pivots about the dial's centre because that
		IS the container's centre.
	]]
	local pivot = Instance.new("Frame")
	pivot.Name = "BeamPivot"
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromScale(1, 1)
	pivot.BackgroundTransparency = 1
	pivot.ZIndex = 3
	pivot.Parent = dial

	local beam = Instance.new("Frame")
	beam.Name = "Beam"
	beam.AnchorPoint = Vector2.new(0.5, 1)
	beam.Position = UDim2.fromScale(0.5, 0.5) -- from the centre, upward
	beam.Size = UDim2.fromScale(0.012, 0.5)
	beam.BackgroundColor3 = Radar.BEAM_COLOUR
	beam.BackgroundTransparency = 0.25
	beam.BorderSizePixel = 0
	beam.Parent = pivot
	ui.beam = pivot -- the PIVOT is what gets rotated, never the bar

	-- own ship, dead centre, bow up
	local own = Instance.new("TextLabel")
	own.AnchorPoint = Vector2.new(0.5, 0.5)
	own.Position = UDim2.fromScale(0.5, 0.5)
	own.Size = UDim2.fromScale(0.12, 0.12)
	own.BackgroundTransparency = 1
	own.Font = Enum.Font.GothamBold
	own.Text = "\u{25B2}" -- a triangle, pointing up, because the scope is head-up
	own.TextColor3 = Radar.colourOf("own")
	own.TextScaled = true
	own.ZIndex = 4
	own.Parent = dial

	ui.contacts = Instance.new("Frame")
	ui.contacts.Name = "Contacts"
	ui.contacts.Size = UDim2.fromScale(1, 1)
	ui.contacts.BackgroundTransparency = 1
	ui.contacts.ZIndex = 2
	ui.contacts.Parent = dial

	--[[
		THE DEAD OVERLAY. An empty scope and a dead scope must not look the same, or the crew reads "nothing
		out there", sails on, and the instrument has lied by omission.
	]]
	local dead = Instance.new("TextLabel")
	dead.Name = "Dead"
	dead.AnchorPoint = Vector2.new(0.5, 0.5)
	dead.Position = UDim2.fromScale(0.5, 0.5)
	dead.Size = UDim2.fromScale(0.9, 0.22)
	dead.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	dead.BackgroundTransparency = 0.25
	dead.Font = Enum.Font.Code
	dead.TextColor3 = Color3.fromRGB(226, 122, 63)
	dead.Text = "NO RETURN"
	dead.TextScaled = true
	dead.Visible = false
	dead.ZIndex = 8
	dead.Parent = dial
	ui.dead = dead

	-- readouts, under the dial
	local function readout(name: string, y: number): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.Position = UDim2.fromScale(0.66, y)
		t.Size = UDim2.fromScale(0.32, 0.085)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Code
		t.TextColor3 = Color3.fromRGB(196, 232, 224)
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = ""
		t.Parent = face
		return t
	end
	ui.rDistance = readout("Distance", 0.06)
	ui.rArrival = readout("Arrival", 0.16)
	ui.rStrength = readout("Strength", 0.26)
	ui.rVisibility = readout("Visibility", 0.36)

	--[[
		THE LEGEND. Requested explicitly - the scope is unreadable without a key, and the key belongs on the
		console for the same reason the scope does. Built FROM `Radar.LEGEND`, so a colour can never disagree
		with the blips it explains.
	]]
	local legend = Instance.new("Frame")
	legend.Name = "Legend"
	legend.Position = UDim2.fromScale(0.66, 0.47)
	legend.Size = UDim2.fromScale(0.32, 0.50)
	legend.BackgroundTransparency = 1
	legend.Parent = face
	local grid = Instance.new("UIGridLayout")
	--[[
		Five rows must FIT: 5 x 0.165 plus four gaps of 0.02 is 0.905 of the frame. The first version used 0.17
		with 0.02 padding, which came to 1.01 and clipped "Your boat" off the bottom.
	]]
	grid.CellSize = UDim2.fromScale(1, 0.165)
	grid.CellPadding = UDim2.fromScale(0, 0.02)
	grid.Parent = legend
	for _, entry in ipairs(Radar.LEGEND) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Parent = legend
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromScale(0.14, 0.7)
		swatch.Position = UDim2.fromScale(0, 0.15)
		swatch.BackgroundColor3 = entry.colour
		swatch.BorderSizePixel = 0
		swatch.Parent = row
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(1, 0)
		sc.Parent = swatch
		local text = Instance.new("TextLabel")
		text.Position = UDim2.fromScale(0.19, 0)
		text.Size = UDim2.fromScale(0.81, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Gotham
		text.Text = entry.label
		text.TextColor3 = Color3.fromRGB(150, 175, 190)
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Parent = row
	end

	-- sounds, mounted on the console so they come from the station and not from everywhere
	local host = surface.Parent
	if host and host:IsA("BasePart") then
		ui.sweepSounds = {}
		for i, id in ipairs(SOUND.sweep) do
			local s = Instance.new("Sound")
			s.Name = "RadarSweep" .. i
			s.SoundId = id ~= "" and ("rbxassetid://" .. id) or ""
			s.Volume = 0.35
			s.RollOffMaxDistance = 40
			s.Parent = host
			table.insert(ui.sweepSounds, s)
		end
		local ping = Instance.new("Sound")
		ping.Name = "RadarContact"
		ping.SoundId = SOUND.contact ~= "" and ("rbxassetid://" .. SOUND.contact) or ""
		ping.Volume = 0.5
		ping.RollOffMaxDistance = 40
		ping.Parent = host
		ui.pingSound = ping
		--[[
			Announce an empty slot rather than shipping a placeholder clip. A wrong sound is far harder to
			notice than a missing one - the rule from the audio registry.
		]]
		for _, id in ipairs(SOUND.sweep) do
			if id == "" then
				print("[RADAR] a sweep slot is empty - no tick will play")
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Contacts
-- ---------------------------------------------------------------------------

local function blipFor(instance: Instance): Blip
	local existing = blips[instance]
	if existing then
		return existing
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.07, 0.07)
	dot.BackgroundTransparency = 1
	dot.BorderSizePixel = 0
	dot.Parent = ui.contacts
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = dot

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, -0.15)
	label.Size = UDim2.fromScale(3.6, 0.5) -- four barrels on similar bearings were stacking illegibly
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 11 -- TextScaled would otherwise blow these up to fill the dial
	cap.Parent = label
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.Text = ""
	label.Parent = dot

	local blip: Blip = { dot = dot, stroke = stroke, label = label, lastSwept = -99, seen = false }
	blips[instance] = blip
	return blip
end

local function nearestHull(): BasePart?
	--[[
		Our own vessel, found by the spec attribute rather than by name or path - finding 0020. The scope has
		to know where WE are before it can plot anything relative to us.
	]]
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("VesselSpec") == "StarterLaunch" then
			return child.PrimaryPart
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Step
-- ---------------------------------------------------------------------------

local function step()
	if not (scope and scope.Parent and ui.dial) then
		return
	end
	local host = scope.Parent :: BasePart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local here = root and (root :: BasePart).Position
	if not here or (host.Position - here).Magnitude > READ_RANGE then
		return -- nobody is at the station
	end

	local hull = nearestHull()
	if not hull then
		return
	end

	local now = workspace:GetServerTimeNow()
	local angle = Radar.sweepAngle(now)
	local intensity = workspace:GetAttribute("StormIntensity")
	local dead, why = Radar.isDead(
		typeof(intensity) == "number" and intensity or 0,
		workspace:GetAttribute("VesselFault_radar") == true)

	ui.dead.Visible = dead
	if dead then
		ui.dead.Text = tostring(why)
		ui.beam.Visible = false
		ui.storm.BackgroundTransparency = 1
		for _, blip in pairs(blips) do
			blip.dot.BackgroundTransparency = 1
			blip.stroke.Transparency = 1
			blip.label.Text = ""
		end
		ui.rDistance.Text = "  -- no return --"
		ui.rArrival.Text = ""
		ui.rStrength.Text = ""
		ui.rVisibility.Text = ""
		previousAngle = angle
		return
	end
	ui.beam.Visible = true
	ui.beam.Rotation = angle

	-- the sweep tick, once per revolution, alternating variants
	if angle < previousAngle and ui.sweepSounds then
		local s = ui.sweepSounds[sweepIndex]
		sweepIndex = sweepIndex % #ui.sweepSounds + 1
		if s and s.SoundId ~= "" then
			s:Play()
		end
	end

	local forward = hull.CFrame.LookVector
	local ownHeading = math.deg(math.atan2(forward.X, forward.Z)) % 360

	-- contacts
	for _, instance in ipairs(CollectionService:GetTagged(TAG_CONTACT)) do
		local part = instance:IsA("BasePart") and instance :: BasePart or nil
		if part and part ~= hull then
			local distance = Radar.distanceTo(hull.Position, part.Position)
			local resolution = Radar.classify(distance)
			local blip = blipFor(instance)
			if resolution == "off" then
				blip.dot.BackgroundTransparency = 1
				blip.stroke.Transparency = 1
				blip.label.Text = ""
				blip.seen = false
			else
				local absolute = Radar.bearingTo(hull.Position, part.Position)
				local relative = Radar.relativeBearing(absolute, ownHeading)
				local offset = Radar.scopeOffset(relative, distance)
				blip.dot.Position = UDim2.fromScale(0.5 + offset.X * 0.5, 0.5 + offset.Y * 0.5)

				-- did the beam pass it since the last frame?
				if Radar.sweptSince(relative % 360, previousAngle, angle) then
					blip.lastSwept = now
					if not blip.seen and ui.pingSound and ui.pingSound.SoundId ~= "" then
						ui.pingSound:Play() -- only for a contact that was not on the scope before
					end
					blip.seen = true
				end

				local brightness = Radar.blipBrightness(now - blip.lastSwept)
				local kind = instance:GetAttribute("RadarKind")
				local colour = Radar.colourOf(
					resolution == "uncertain" and "unknown"
					or (typeof(kind) == "string" and kind :: any or "object"))

				if resolution == "uncertain" then
					--[[
						The edge treatment: a small HOLLOW circle, no label. "Something is there." The whole
						point is that it is a guess, so it must not look like a fix.
					]]
					blip.dot.BackgroundTransparency = 1
					blip.stroke.Color = colour
					blip.stroke.Transparency = 1 - brightness * 0.9
					blip.dot.Size = UDim2.fromScale(0.05, 0.05)
					blip.label.Text = ""
				else
					blip.dot.BackgroundColor3 = colour
					blip.dot.BackgroundTransparency = 1 - brightness
					blip.stroke.Transparency = 1
					blip.dot.Size = UDim2.fromScale(0.07, 0.07)
					local label = instance:GetAttribute("RadarLabel")
					blip.label.TextColor3 = colour
					blip.label.TextTransparency = 1 - brightness
					--[[
						Distance in STUDS below a kilometre, because "0.3 km" for a barrel three hundred studs
						away reads as false precision and four of them stacked was unreadable.
					]]
					blip.label.Text = if distance < 1000
						then ("%s %.0f"):format(typeof(label) == "string" and label or "contact", distance)
						else ("%s %.1fkm"):format(typeof(label) == "string" and label or "contact", distance / 1000)
				end
			end
		end
	end

	-- the storm: astern in absolute terms, so its place on a head-up scope moves as we turn
	local stormDistance = workspace:GetAttribute("StormDistance")
	if typeof(stormDistance) == "number" then
		local band = StormFront.bandFor(stormDistance)
		ui.rDistance.Text = ("STORM     %.2f km"):format(stormDistance / 1000)
		local arrival = Radar.arrivalSeconds(stormDistance, StormFront.ADVANCE_RATE)
		ui.rArrival.Text = ("ARRIVAL   %s"):format(Radar.clock(arrival))
		ui.rStrength.Text = ("STRENGTH  %s"):format(band.label:upper())
		local clearest = SeaStates.DeadCalm.sky.fogEnd
		ui.rVisibility.Text = ("VISIBILITY %3.0f%%"):format(
			Radar.visibility(game:GetService("Lighting").FogEnd, clearest) * 100)

		if stormDistance <= Radar.RANGE then
			local relative = Radar.relativeBearing(Lightning.ASTERN_BEARING, ownHeading)
			local offset = Radar.scopeOffset(relative, stormDistance)
			--[[
				🔴 `* 0.5`, NOT `* 0.75`. `scopeOffset` returns -1..1, so half of it maps onto the
				dial's 0..1 - exactly as the contacts above do. The first version used 0.75 meaning "push it
				toward the edge", which pushed its centre PAST the edge: before the dial clipped its children
				the mass drew out over the bezel and into the sky, and once clipping was added it vanished
				entirely. Two different symptoms, one wrong constant.
			]]
			--[[
				Clamped inward. Plotted honestly at 1400 of 1800 the mass centres at 0.89 of the dial radius,
				which - once the dial clips its children - leaves only a crescent too thin to notice. The
				STORM is the one contact that must never be missed, so its centre is held inside 0.62 of the
				radius and it grows as the front closes instead of sliding off the edge.

				This is a deliberate departure from plotting it to scale, and the only one on the scope. The
				NUMBER beside it stays exact, which is the part decision 0019 actually promises.
			]]
			local reach = math.min(offset.Magnitude, 0.62)
			local dir = if offset.Magnitude > 0.001 then offset.Unit else Vector2.new(0, 1)
			ui.storm.Position = UDim2.fromScale(0.5 + dir.X * reach, 0.5 + dir.Y * reach)
			local closeness = 1 - math.clamp(stormDistance / Radar.RANGE, 0, 1)
			ui.storm.Size = UDim2.fromScale(0.55 + closeness * 0.6, 0.55 + closeness * 0.6)
			ui.storm.BackgroundTransparency = 0.62 - closeness * 0.22
		else
			ui.storm.BackgroundTransparency = 1 -- beyond range: not on the scope at all
		end
	end

	previousAngle = angle
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

local function adopt(surface: Instance)
	if surface:IsA("SurfaceGui") then
		scope = surface
		blips = {}
		buildScope(surface)
		print("[RADAR] scope adopted")
	end
end

for _, s in ipairs(CollectionService:GetTagged(TAG_SCOPE)) do
	adopt(s)
end
CollectionService:GetInstanceAddedSignal(TAG_SCOPE):Connect(adopt)

RunService.Heartbeat:Connect(function()
	local ok, err = pcall(step)
	if not ok then
		warn("[RADAR] draw failed: " .. tostring(err))
	end
end)

print("[RADAR] client ready")
