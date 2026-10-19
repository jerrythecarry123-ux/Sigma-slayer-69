--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("FishingRules"))
local Fish = require(Shared:WaitForChild("FishModel"))
local audio = require(script.Parent:WaitForChild("FishingAudio")).new()
local presentation = require(script.Parent:WaitForChild("FishingPresentation")).new(audio)
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local action = remotes:WaitForChild("FishingAction") :: RemoteEvent
local state = remotes:WaitForChild("FishingState") :: RemoteEvent
local visual = remotes:WaitForChild("FishingVisual") :: RemoteEvent
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
assert(not playerGui:FindFirstChild("MolnfiskarnaFishing"), "Install one FishingClient only.")

type Packet = {
	phase: string, catches: number, nextStart: number,
	attemptId: number?, readyAt: number?, expiresAt: number?,
	chargeAt: number?, duration: number?, message: string?,
	result: { species: string, quality: string }?,
}
local packet: Packet = { phase = "Connecting", catches = 0, nextStart = 0 }
local pendingSince: number? = nil
local heldInput: InputObject? = nil
local heldConnection: RBXScriptConnection? = nil
local releasedBeforeAck = false
local message = "Follow the path to the glowing spot on the dock."
local keyHint = if UserInputService.TouchEnabled then "" else "  [E]"
local colors = {
	panel = Color3.fromRGB(24, 39, 62), text = Color3.fromRGB(243, 248, 255),
	muted = Color3.fromRGB(180, 200, 216), blue = Color3.fromRGB(91, 212, 228),
	gold = Color3.fromRGB(255, 214, 119), green = Color3.fromRGB(112, 192, 156),
}
local gui = Instance.new("ScreenGui")
gui.Name = "MolnfiskarnaFishing"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end
local function label(parent: Instance, name: string, text: string, y: number, height: number, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.Name = name
	object.Position = UDim2.fromOffset(16, y)
	object.Size = UDim2.new(1, -32, 0, height)
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.Gotham
	object.TextColor3 = colors.text
	object.TextSize = size
	object.TextWrapped = true
	object.AutoLocalize = false
	object.Text = text
	object.Parent = parent
	return object
end

local brand = Instance.new("Frame")
brand.Name = "Brand"
brand.Position = UDim2.fromOffset(14, 12)
brand.Size = UDim2.fromOffset(195, 44)
brand.BackgroundColor3 = colors.panel
brand.BackgroundTransparency = 0.08
brand.BorderSizePixel = 0
brand.Parent = gui
round(brand, 12)
local brandText = label(brand, "Title", "CLOUD ANGLERS", 0, 44, 16)
brandText.Font = Enum.Font.GothamBold
brandText.TextColor3 = colors.gold
local mute = Instance.new("TextButton")
mute.Name = "SoundToggle"
mute.AnchorPoint = Vector2.new(1, 0)
mute.Position = UDim2.new(1, -14, 0, 12)
mute.Size = UDim2.fromOffset(84, 44)
mute.BackgroundColor3 = colors.panel
mute.Text = "SFX ON"
mute.Font = Enum.Font.GothamBold
mute.TextSize = 13
mute.TextColor3 = colors.blue
mute.AutoLocalize = false
mute.Parent = gui
round(mute, 12)
mute.Activated:Connect(function()
	local muted = audio.toggle()
	mute.Text = if muted then "SFX OFF" else "SFX ON"
	mute.TextColor3 = if muted then colors.muted else colors.blue
end)

local panel = Instance.new("Frame")
panel.Name = "FishingPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -12)
panel.Size = UDim2.new(0.62, 0, 0, 220)
panel.BackgroundColor3 = colors.panel
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui
round(panel, 16)
local constraint = Instance.new("UISizeConstraint")
constraint.MinSize = Vector2.new(254, 220)
constraint.MaxSize = Vector2.new(420, 220)
constraint.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Scale = 0.9
panelScale.Parent = panel
TweenService:Create(panelScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
local stroke = Instance.new("UIStroke")
stroke.Color = colors.blue
stroke.Transparency = 0.5
stroke.Thickness = 1
stroke.Parent = panel
local title = label(panel, "Location", "SUNDRIFT POND", 10, 20, 15)
title.Font = Enum.Font.GothamBold
title.TextColor3 = colors.gold
local count = label(panel, "CatchCount", "SESSION CATCHES  0", 32, 18, 12)
count.TextColor3 = colors.muted
local countScale = Instance.new("UIScale")
countScale.Parent = count
local status = label(panel, "Status", message, 54, 38, 14)
local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.Position = UDim2.new(0, 20, 0, 100)
meter.Size = UDim2.new(1, -40, 0, 18)
meter.BackgroundColor3 = Color3.fromRGB(52, 68, 91)
meter.BorderSizePixel = 0
meter.ClipsDescendants = true
meter.Parent = panel
round(meter, 5)
local function zone(name: string, low: number, high: number, color: Color3)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromScale(low, 0)
	frame.Size = UDim2.fromScale(high - low, 1)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = meter
end
zone("Normal", Rules.NormalMin, Rules.NormalMax, colors.green)
zone("Fine", Rules.FineMin, Rules.FineMax, colors.blue)
zone("Brilliant", Rules.BrilliantMin, Rules.BrilliantMax, colors.gold)
local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.AnchorPoint = Vector2.new(0.5, 0)
marker.Size = UDim2.new(0, 4, 1, 0)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.BorderSizePixel = 0
marker.ZIndex = 2
marker.Parent = meter
local legend = label(panel, "Legend", "NORMAL  /  FINE  /  BRILLIANT", 124, 18, 11)
legend.TextColor3 = colors.muted
local button = Instance.new("TextButton")
button.Name = "ActionButton"
button.AnchorPoint = Vector2.new(0.5, 0)
button.Position = UDim2.new(0.5, 0, 0, 150)
button.Size = UDim2.new(1, -40, 0, 48)
button.BackgroundColor3 = colors.blue
button.TextColor3 = colors.panel
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.AutoLocalize = false
button.Text = "CONNECTING..."
button.AutoButtonColor = false
button.BorderSizePixel = 0
button.Parent = panel
round(button, 12)
local buttonScale = Instance.new("UIScale")
buttonScale.Parent = button
local footnote = label(panel, "PrototypeNotice", "PLAYTEST BUILD  /  SESSION PROGRESS", 203, 12, 10)
footnote.TextColor3 = colors.muted

-- A real 3D fish in the result card, not a static placeholder image.
local resultCard = Instance.new("Frame")
resultCard.Name = "CatchReveal"
resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
resultCard.Position = UDim2.fromScale(0.5, 0.45)
resultCard.Size = UDim2.fromOffset(270, 242)
resultCard.BackgroundColor3 = colors.panel
resultCard.BorderSizePixel = 0
resultCard.Visible = false
resultCard.Parent = gui
round(resultCard, 20)
local resultScale = Instance.new("UIScale")
resultScale.Parent = resultCard
local resultStroke = Instance.new("UIStroke")
resultStroke.Color = colors.gold
resultStroke.Thickness = 2
resultStroke.Parent = resultCard
local resultTitle = label(resultCard, "Headline", "NICE CATCH!", 12, 22, 15)
resultTitle.Font = Enum.Font.GothamBold
resultTitle.TextColor3 = colors.gold
local viewport = Instance.new("ViewportFrame")
viewport.Position = UDim2.fromOffset(10, 38)
viewport.Size = UDim2.new(1, -20, 0, 128)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(210, 218, 229)
viewport.LightColor = Color3.fromRGB(255, 236, 199)
viewport.LightDirection = Vector3.new(-1, -1, -2)
viewport.Parent = resultCard
local camera = Instance.new("Camera")
camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, -6.8), Vector3.zero)
camera.FieldOfView = 40
camera.Parent = viewport
viewport.CurrentCamera = camera
local fishWorld = Instance.new("WorldModel")
fishWorld.Parent = viewport
local revealFish = Fish.create(fishWorld)
local resultName = label(resultCard, "Species", "PUFFLET", 171, 28, 24)
resultName.Font = Enum.Font.GothamBold
local resultQuality = label(resultCard, "Quality", "Normal", 202, 22, 16)
local dismiss = Instance.new("TextButton")
dismiss.Name = "Close"
dismiss.AnchorPoint = Vector2.new(1, 0)
dismiss.Position = UDim2.new(1, 0, 0, 0)
dismiss.Size = UDim2.fromOffset(44, 44)
dismiss.BackgroundTransparency = 1
dismiss.Text = "x"
dismiss.TextSize = 20
dismiss.TextColor3 = colors.muted
dismiss.AutoLocalize = false
dismiss.Parent = resultCard
local revealGeneration = 0
local function hideResult()
	revealGeneration += 1
	resultCard.Visible = false
	panel.Visible = true
end
dismiss.Activated:Connect(hideResult)
local function showResult(result: { species: string, quality: string })
	revealGeneration += 1
	local generation = revealGeneration
	audio.catch(result.quality)
	countScale.Scale = 1.18
	TweenService:Create(countScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- Let the fish visibly jump out of the pond before showing its close-up.
	task.delay(0.65, function()
		if generation ~= revealGeneration then return end
		resultName.Text = string.upper(result.species)
		resultQuality.Text = result.quality .. " catch"
		resultQuality.TextColor3 = if result.quality == "Brilliant" then colors.gold
			elseif result.quality == "Fine" then colors.blue else colors.green
		panel.Visible = false
		resultCard.Visible = true
		resultScale.Scale = 0.65
		TweenService:Create(resultScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(2.2, function()
			if generation == revealGeneration then hideResult() end
		end)
	end)
end

local function now(): number
	return workspace:GetServerTimeNow()
end
local function clearHeld()
	heldInput = nil
	if heldConnection then heldConnection:Disconnect() end
	heldConnection = nil
	TweenService:Create(buttonScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end
local function request(verb: string)
	pendingSince = now()
	action:FireServer(verb, packet.attemptId)
end
local function cancel()
	clearHeld()
	releasedBeforeAck = false
	if packet.attemptId then request("Cancel") end
end
local function release()
	if not heldInput then return end
	clearHeld()
	if packet.phase == "Reeling" then request("Release")
	else releasedBeforeAck = true end
end
local function press(input: InputObject)
	if resultCard.Visible then hideResult() return end
	if heldInput or pendingSince then return end
	local time = now()
	if packet.phase == "Idle" and time >= packet.nextStart then
		hideResult()
		message = "Casting into the clouds..."
		request("Start")
	elseif packet.phase == "Waiting" and time >= (packet.readyAt or math.huge) then
		heldInput = input
		releasedBeforeAck = false
		TweenService:Create(buttonScale, TweenInfo.new(0.1), { Scale = 0.95 }):Play()
		heldConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.Cancel then cancel()
			elseif input.UserInputState == Enum.UserInputState.End then release() end
		end)
		request("Hold")
	end
end
button.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then press(input) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.E and not UserInputService:GetFocusedTextBox() then press(input) end
end)
UserInputService.InputEnded:Connect(function(input)
	local held = heldInput
	if not held then return end
	if input == held
		or (held.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		or (held.KeyCode == Enum.KeyCode.E and input.KeyCode == Enum.KeyCode.E) then release() end
end)
UserInputService.WindowFocusReleased:Connect(cancel)
UserInputService.TextBoxFocused:Connect(cancel)
visual.OnClientEvent:Connect(presentation.apply)
state.OnClientEvent:Connect(function(incoming: Packet)
	local previousId = packet.attemptId
	local previousCatches = packet.catches
	local previousPhase = packet.phase
	packet = incoming
	pendingSince = nil
	count.Text = "SESSION CATCHES  " .. tostring(packet.catches)
	if packet.result and packet.catches > previousCatches then
		message = packet.result.species .. " / " .. packet.result.quality .. "! Cast again?"
		showResult(packet.result)
	elseif packet.message then message = packet.message end
	if packet.phase == "Idle" or packet.attemptId ~= previousId then
		clearHeld()
		releasedBeforeAck = false
	end
	if packet.phase == "Waiting" and previousPhase ~= "Waiting" then
		hideResult()
		TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.1 }):Play()
	end
	audio.setReeling(packet.phase == "Reeling")
	if packet.phase == "Reeling" then
		if releasedBeforeAck then
			releasedBeforeAck = false
			request("Release")
		elseif not heldInput then request("Cancel") end
	end
end)

RunService.RenderStepped:Connect(function()
	local time = now()
	if pendingSince and time - pendingSince > 3 then
		clearHeld()
		releasedBeforeAck = false
		request("Sync")
	end
	marker.Visible = packet.phase == "Reeling"
	button.BackgroundColor3 = colors.blue
	legend.Text = "NORMAL  /  FINE  /  BRILLIANT"
	if resultCard.Visible then
		revealFish:PivotTo(CFrame.Angles(0, math.sin(time * 1.5) * 0.3, math.sin(time * 2) * 0.05))
	end
	if packet.phase == "Waiting" then
		if time < (packet.readyAt or math.huge) then
			status.Text = "Watch your bobber..."
			button.Text = "CASTING..."
			button.BackgroundColor3 = colors.muted
		else
			status.Text = "BITE! Hold, then release inside the zone."
			button.Text = if pendingSince then "ONE MOMENT..." else "HOLD TO REEL" .. keyHint
			stroke.Transparency = 0.15 + (math.sin(time * 7) + 1) * 0.18
		end
	elseif packet.phase == "Reeling" then
		local progress = math.clamp((time - (packet.chargeAt or time)) / (packet.duration or 1), 0, 1)
		marker.Position = UDim2.fromScale(progress, 0)
		legend.Text = "NOW: " .. string.upper(Rules.qualityAt(progress) or "OUTSIDE THE ZONE")
		status.Text = if pendingSince then "Checking your catch..." else "Release in the zone. Aim for gold!"
		button.Text = if pendingSince then "ONE MOMENT..." else "RELEASE!"
		button.BackgroundColor3 = colors.gold
	elseif packet.phase == "Idle" then
		status.Text = message
		button.Text = if pendingSince then "ONE MOMENT..."
			elseif time < packet.nextStart then "GET READY..." else "CAST LINE" .. keyHint
	else
		status.Text = "Connecting to the pond..."
		button.Text = "CONNECTING..."
	end
end)
request("Sync")
