--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("FishingRules"))
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local action = remotes:WaitForChild("FishingAction") :: RemoteEvent
local state = remotes:WaitForChild("FishingState") :: RemoteEvent
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
assert(not playerGui:FindFirstChild("MolnfiskarnaFishing"), "Installera bara en FishingClient.")

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
local message = "Gå till den blå rutan längst ut på bryggan."
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

local panel = Instance.new("Frame")
panel.Name = "FishingPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -12)
panel.Size = UDim2.new(0.66, 0, 0, 236)
panel.BackgroundColor3 = colors.panel
panel.BorderSizePixel = 0
panel.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MinSize = Vector2.new(260, 236)
constraint.MaxSize = Vector2.new(440, 236)
constraint.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = colors.blue
stroke.Transparency = 0.5
stroke.Thickness = 1
stroke.Parent = panel

local function label(name: string, text: string, y: number, height: number, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.Name = name
	object.Position = UDim2.fromOffset(16, y)
	object.Size = UDim2.new(1, -32, 0, height)
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.Gotham
	object.TextColor3 = colors.text
	object.TextSize = size
	object.TextWrapped = true
	object.Text = text
	object.Parent = panel
	return object
end
local title = label("Title", "MOLNFISKARNA", 10, 24, 19)
title.Font = Enum.Font.GothamBold
title.TextColor3 = colors.gold
local count = label("CatchCount", "Fångster denna session: 0", 37, 18, 13)
count.TextColor3 = colors.muted
local status = label("Status", message, 59, 42, 15)

local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.Position = UDim2.new(0, 20, 0, 109)
meter.Size = UDim2.new(1, -40, 0, 18)
meter.BackgroundColor3 = Color3.fromRGB(52, 68, 91)
meter.BorderSizePixel = 0
meter.ClipsDescendants = true
meter.Parent = panel
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
zone("Fin", Rules.FineMin, Rules.FineMax, colors.blue)
zone("Stralande", Rules.BrilliantMin, Rules.BrilliantMax, colors.gold)
local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.AnchorPoint = Vector2.new(0.5, 0)
marker.Size = UDim2.new(0, 4, 1, 0)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.BorderSizePixel = 0
marker.ZIndex = 2
marker.Parent = meter
local legend = label("Legend", "Fångstområde · Fin · Strålande", 132, 18, 12)
legend.TextColor3 = colors.muted

local button = Instance.new("TextButton")
button.Name = "ActionButton"
button.Position = UDim2.new(0, 20, 0, 156)
button.Size = UDim2.new(1, -40, 0, 50)
button.BackgroundColor3 = colors.blue
button.TextColor3 = colors.panel
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.Text = "Ansluter…"
button.AutoButtonColor = false
button.BorderSizePixel = 0
button.Parent = panel
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 12)
buttonCorner.Parent = button
local footnote = label("PrototypeNotice", "PROTOTYP · Framsteg sparas inte", 213, 16, 11)
footnote.TextColor3 = colors.muted

local function now(): number
	return workspace:GetServerTimeNow()
end

local function clearHeld()
	heldInput = nil
	if heldConnection then heldConnection:Disconnect() end
	heldConnection = nil
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
	if packet.phase == "Reeling" then
		request("Release")
	else
		-- The finger may lift before the server's Hold acknowledgement arrives.
		releasedBeforeAck = true
	end
end

local function press(input: InputObject)
	if heldInput or pendingSince then return end
	local time = now()
	if packet.phase == "Idle" and time >= packet.nextStart then
		message = "Kastar ut…"
		request("Start")
	elseif packet.phase == "Waiting" and time >= (packet.readyAt or math.huge) then
		heldInput = input
		releasedBeforeAck = false
		heldConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.Cancel then cancel()
			elseif input.UserInputState == Enum.UserInputState.End then release() end
		end)
		request("Hold")
	end
end

button.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		press(input)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.E and not UserInputService:GetFocusedTextBox() then
		press(input)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local held = heldInput
	if not held then return end
	if input == held
		or (held.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		or (held.KeyCode == Enum.KeyCode.E and input.KeyCode == Enum.KeyCode.E) then
		release()
	end
end)
UserInputService.WindowFocusReleased:Connect(cancel)
UserInputService.TextBoxFocused:Connect(cancel)

state.OnClientEvent:Connect(function(incoming: Packet)
	local previousId = packet.attemptId
	packet = incoming
	pendingSince = nil
	count.Text = "Fångster denna session: " .. tostring(packet.catches)
	if packet.result then
		message = packet.result.species .. " · " .. packet.result.quality .. "!\nSnyggt! Försök igen."
	elseif packet.message then
		message = packet.message
	end
	if packet.phase == "Idle" or packet.attemptId ~= previousId then
		clearHeld()
		releasedBeforeAck = false
	end
	if packet.phase == "Reeling" then
		if releasedBeforeAck then
			releasedBeforeAck = false
			request("Release")
		elseif not heldInput then
			-- Recover safely after a local interruption or a late Sync response.
			request("Cancel")
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local time = now()
	if pendingSince and time - pendingSince > 3 then
		-- A throttled/lost local action must never leave a disabled UI forever.
		clearHeld()
		releasedBeforeAck = false
		request("Sync")
	end
	marker.Visible = packet.phase == "Reeling"
	button.BackgroundColor3 = colors.blue
	legend.Text = "Fångstområde · Fin · Strålande"
	if packet.phase == "Waiting" then
		if time < (packet.readyAt or math.huge) then
			status.Text = "Flötet landar i molnen…"
			button.Text = "Vänta på napp…"
			button.BackgroundColor3 = colors.muted
		else
			status.Text = "Napp! Håll inne och släpp i fångstområdet."
			button.Text = if pendingSince then "Ett ögonblick…" else "HÅLL INNE" .. keyHint
		end
	elseif packet.phase == "Reeling" then
		local progress = math.clamp((time - (packet.chargeAt or time)) / (packet.duration or 1), 0, 1)
		marker.Position = UDim2.fromScale(progress, 0)
		legend.Text = "Nu: " .. (Rules.qualityAt(progress) or "Utanför fångstområdet")
		status.Text = if pendingSince then "Kontrollerar fångsten…" else "Släpp i området. Guld ger Strålande!"
		button.Text = if pendingSince then "Ett ögonblick…" else "SLÄPP!"
		button.BackgroundColor3 = colors.gold
	elseif packet.phase == "Idle" then
		status.Text = message
		button.Text = if pendingSince then "Ett ögonblick…"
			elseif time < packet.nextStart then "Gör dig redo…" else "FISKA" .. keyHint
	else
		status.Text = "Ansluter till fisket…"
		button.Text = "Ansluter…"
	end
end)

-- Subscribe first, then ask for state; avoids a PlayerAdded/UI startup race.
request("Sync")
