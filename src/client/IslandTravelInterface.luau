--!strict
-- Walk into a gateway, choose a pond, and cross under a short, dark transition.
-- Clients send an ID only; the server owns every landing position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Rules = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("IslandTravelRules"))
local Interface = {}
local started = false
local BLUE = Color3.fromRGB(55, 137, 203)
local PALE = Color3.fromRGB(214, 230, 232)
local CREAM = Color3.fromRGB(229, 229, 210)
local INK = Color3.fromRGB(40, 66, 83)
local MUTED = Color3.fromRGB(98, 118, 128)

local function rounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, radius), parent
end

local function label(parent: Instance, name: string, text: string, size: number): TextLabel
	local value = Instance.new("TextLabel")
	value.Name, value.Text, value.TextSize = name, text, size
	value.Font, value.TextColor3 = Enum.Font.GothamMedium, INK
	value.BackgroundTransparency, value.BorderSizePixel = 1, 0
	value.TextXAlignment, value.AutoLocalize = Enum.TextXAlignment.Left, false
	value.Parent = parent
	return value
end

local function mount(event: RemoteEvent)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "IslandTravel", false, 80, false
	gui.ZIndexBehavior, gui.IgnoreGuiInset = Enum.ZIndexBehavior.Sibling, true
	local shade = Instance.new("Frame")
	shade.Name, shade.Size = "Backdrop", UDim2.fromScale(1, 1)
	shade.BackgroundColor3, shade.BackgroundTransparency = INK, 0.28
	shade.BorderSizePixel, shade.Parent = 0, gui
	local backdrop = Instance.new("TextButton")
	backdrop.Name, backdrop.Text, backdrop.Size = "CloseBackdrop", "", UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency, backdrop.BorderSizePixel, backdrop.Parent = 1, 0, shade
	local card = Instance.new("Frame")
	card.Name, card.AnchorPoint, card.Position = "DestinationCard", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3, card.BorderSizePixel, card.Active, card.Parent = CREAM, 0, true, shade
	rounded(card, 20)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Transparency, outline.Parent = Color3.fromRGB(133, 162, 167), 1, 0.3, card
	local eyebrow = label(card, "FreeLabel", "FREE PORTAL TRAVEL", 11)
	eyebrow.Font, eyebrow.TextColor3 = Enum.Font.GothamBold, BLUE
	eyebrow.Position, eyebrow.Size = UDim2.fromOffset(20, 18), UDim2.new(1, -88, 0, 16)
	local title = label(card, "Title", "Pick your next pond", 24)
	title.Font = Enum.Font.GothamBold
	title.Position, title.Size = UDim2.fromOffset(20, 38), UDim2.new(1, -86, 0, 31)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local subtitle = label(card, "Subtitle", "Choose a gateway. Arrive ready to fish.", 13)
	subtitle.TextColor3 = MUTED
	subtitle.Position, subtitle.Size = UDim2.fromOffset(20, 75), UDim2.new(1, -40, 0, 20)
	local close = Instance.new("TextButton")
	close.Name, close.Text, close.TextSize, close.Font = "Close", "X", 18, Enum.Font.GothamBold
	close.AnchorPoint, close.Position, close.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 15), UDim2.fromOffset(48, 48)
	close.TextColor3, close.BackgroundColor3, close.BorderSizePixel = INK, PALE, 0
	close.Modal, close.Parent = true, card
	rounded(close, 14)
	local list = Instance.new("ScrollingFrame")
	list.Name, list.Position, list.Size = "Destinations", UDim2.fromOffset(12, 108), UDim2.new(1, -24, 1, -158)
	list.BackgroundTransparency, list.BorderSizePixel = 1, 0
	list.CanvasSize, list.ScrollBarThickness = UDim2.fromOffset(0, #Rules.Destinations * 64 - 8), 4
	list.ScrollBarImageColor3, list.ScrollingDirection, list.Parent = BLUE, Enum.ScrollingDirection.Y, card
	local stack = Instance.new("UIListLayout")
	stack.Padding, stack.SortOrder, stack.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, list
	local status = label(card, "Status", "No coins, tickets or unlocks needed.", 12)
	status.AnchorPoint, status.Position = Vector2.new(0, 1), UDim2.new(0, 20, 1, -12)
	status.Size, status.TextWrapped, status.TextColor3 = UDim2.new(1, -40, 0, 34), true, MUTED
	-- This cover is dark ink, with no Bloom, white flash, camera shake or FOV change.
	local curtain = Instance.new("Frame")
	curtain.Name, curtain.Size, curtain.ZIndex = "PortalTransition", UDim2.fromScale(1, 1), 20
	curtain.BackgroundColor3, curtain.BackgroundTransparency = Color3.fromRGB(9, 17, 22), 1
	curtain.BorderSizePixel, curtain.Active, curtain.Visible, curtain.Parent = 0, true, false, gui
	local journey = label(curtain, "Journey", "CROSSING TO", 12)
	journey.AnchorPoint, journey.Position, journey.Size = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.48), UDim2.new(1, -40, 0, 22)
	journey.TextColor3, journey.TextXAlignment, journey.ZIndex = Color3.fromRGB(151, 182, 189), Enum.TextXAlignment.Center, 21
	local destinationLabel = label(curtain, "Destination", "", 26)
	destinationLabel.AnchorPoint, destinationLabel.Position, destinationLabel.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.49), UDim2.new(1, -40, 0, 42)
	destinationLabel.Font, destinationLabel.TextColor3 = Enum.Font.GothamBold, CREAM
	destinationLabel.TextXAlignment, destinationLabel.TextWrapped, destinationLabel.ZIndex = Enum.TextXAlignment.Center, true, 21
	local arrival = Instance.new("Frame")
	arrival.Name, arrival.AnchorPoint, arrival.Position = "Arrival", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.13)
	arrival.Size, arrival.BackgroundColor3, arrival.BackgroundTransparency = UDim2.fromOffset(310, 68), INK, 0.12
	arrival.BorderSizePixel, arrival.Visible, arrival.Parent = 0, false, gui
	rounded(arrival, 16)
	local arrivalName = label(arrival, "PondName", "", 21)
	arrivalName.Position, arrivalName.Size = UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 28)
	arrivalName.Font, arrivalName.TextColor3, arrivalName.TextXAlignment = Enum.Font.GothamBold, CREAM, Enum.TextXAlignment.Center
	arrivalName.TextTruncate = Enum.TextTruncate.AtEnd
	local ready = label(arrival, "Ready", "READY TO FISH", 11)
	ready.Position, ready.Size = UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 18)
	ready.TextColor3, ready.TextXAlignment = Color3.fromRGB(173, 204, 197), Enum.TextXAlignment.Center
	local rows: { { id: string, button: TextButton, badge: TextLabel } } = {}
	local source, waiting, terminal = "", false, false
	local phase, destinationName = "closed", ""
	local generation = 0
	local oldSelection: GuiObject? = nil
	local coverTween: Tween? = nil
	local controls: any = nil
	local movementLocked, disabledControls = false, false
	local function lockMovement(locked: boolean)
		movementLocked = locked
		if locked then
			if controls and not disabledControls and controls.controlsEnabled ~= false then
				controls:Disable(); disabledControls = true
			end
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then humanoid:Move(Vector3.zero) end
		elseif controls and disabledControls then
			controls:Enable()
			disabledControls = false
		end
	end
	-- Resolving PlayerModule may yield, so it never delays fishing's initial Sync.
	task.spawn(function()
		local scripts = player:WaitForChild("PlayerScripts")
		local module = scripts:WaitForChild("PlayerModule", 5)
		if not module or not module:IsA("ModuleScript") then return end
		local ok, result = pcall(function() return require(module):GetControls() end)
		if ok and result then controls = result; lockMovement(movementLocked) end
	end)
	local function restoreSelection()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = if oldSelection and oldSelection.Parent then oldSelection else nil
		end
	end
	local function updateVisibility()
		shade.Visible = phase == "menu" or phase == "rejected" or phase == "covering"
		gui.Enabled = phase ~= "closed" or arrival.Visible
		player:SetAttribute("IslandTravelMenuOpen", phase ~= "closed")
	end
	local function cancelTween()
		if coverTween then coverTween:Cancel(); coverTween = nil end
	end
	local function reset()
		generation += 1
		cancelTween()
		phase, waiting, terminal = "closed", false, false
		curtain.Visible, curtain.BackgroundTransparency, arrival.Visible = false, 1, false
		journey.Visible, destinationLabel.Visible = false, false
		lockMovement(false)
		restoreSelection()
		updateVisibility()
	end
	local function closeMenu()
		-- Once sent, keep the view covered until the server finishes or recovery times out.
		if phase == "pending" or phase == "uncovering" then return end
		reset()
	end
	local function fadeCover(alpha: number, duration: number, token: number, complete: () -> ())
		cancelTween()
		local tween = TweenService:Create(curtain, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = alpha })
		coverTween = tween
		tween:Play()
		task.spawn(function()
			local playback = tween.Completed:Wait()
			if generation ~= token or playback ~= Enum.PlaybackState.Completed then return end
			if coverTween == tween then coverTween = nil end
			complete()
		end)
	end
	local function refreshButtons()
		for _, row in rows do
			local current = row.id == source
			local enabled = not current and not waiting and not terminal
			row.button.Active, row.button.Selectable, row.button.AutoButtonColor = enabled, enabled, enabled
			row.button.BackgroundColor3 = if current then Color3.fromRGB(214, 209, 180) else PALE
			row.badge.Text = if current then "HERE" elseif waiting then "..." else "GO"
			row.badge.TextColor3 = if current then MUTED else BLUE
		end
	end
	local reject: (string) -> ()
	for index, destination in Rules.Destinations do
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.LayoutOrder = destination.Id, "", index
		button.Size, button.BorderSizePixel, button.Parent = UDim2.new(1, -7, 0, 56), 0, list
		rounded(button, 12)
		local name = label(button, "Name", destination.Name, 17)
		name.Font, name.Position, name.Size = Enum.Font.GothamBold, UDim2.fromOffset(14, 6), UDim2.new(1, -80, 0, 23)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local detail = label(button, "Detail", destination.Detail, 11)
		detail.TextColor3, detail.Position, detail.Size = MUTED, UDim2.fromOffset(14, 31), UDim2.new(1, -80, 0, 17)
		local badge = label(button, "Badge", "GO", 12)
		badge.Font, badge.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Center
		badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0), UDim2.fromOffset(43, 32)
		table.insert(rows, { id = destination.Id, button = button, badge = badge })
		button.Activated:Connect(function()
			if phase ~= "menu" or waiting or terminal or destination.Id == source then return end
			generation += 1
			local token = generation
			phase, waiting, destinationName = "covering", true, destination.Name
			status.Text, status.TextColor3 = "Opening your gateway...", BLUE
			curtain.Visible, curtain.BackgroundTransparency = true, 1
			journey.Visible, destinationLabel.Visible = false, false
			refreshButtons()
			updateVisibility()
			fadeCover(0, 0.16, token, function()
				phase = "pending"
				journey.Text, journey.Visible = "CROSSING TO", true
				destinationLabel.Text, destinationLabel.Visible = destinationName, true
				updateVisibility()
				local ok = pcall(function() event:FireServer(destination.Id) end)
				if not ok then reject("Your portal could not connect. Close this menu and try again."); return end
				task.delay(8, function()
					if generation == token and phase == "pending" then
						reject("The portal took too long. Close this menu and step into it again.")
					end
				end)
			end)
		end)
	end
	local function resize()
		-- Fixed 56-pixel rows stay easy to tap; short screens scroll instead of shrinking buttons.
		local available = gui.AbsoluteSize
		if available.X <= 0 or available.Y <= 0 then return end
		card.Size = UDim2.fromOffset(math.min(440, math.max(260, available.X - 24)), math.min(478, math.max(232, available.Y - 24)))
	end
	reject = function(message: string)
		if phase ~= "pending" and phase ~= "covering" then return end
		generation += 1
		local token = generation
		waiting, terminal = false, true
		status.Text, status.TextColor3 = message, Color3.fromRGB(151, 77, 55)
		refreshButtons()
		journey.Visible, destinationLabel.Visible = false, false
		-- Rejection never traps movement, including when the server loses the world.
		lockMovement(false)
		phase = "rejected"
		updateVisibility()
		fadeCover(1, 0.2, token, function() curtain.Visible = false end)
	end
	close.Activated:Connect(closeMenu)
	backdrop.Activated:Connect(closeMenu)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then closeMenu() end
	end)
	local deathConnection: RBXScriptConnection? = nil
	local function watchCharacter(character: Model)
		if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 5)
			if player.Character ~= character or not humanoid or not humanoid:IsA("Humanoid") then return end
			deathConnection = humanoid.Died:Connect(reset)
		end)
	end
	player.CharacterRemoving:Connect(function() reset(); if deathConnection then deathConnection:Disconnect(); deathConnection = nil end end)
	player.CharacterAdded:Connect(function(character) reset(); watchCharacter(character) end)
	if player.Character then watchCharacter(player.Character) end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	event.OnClientEvent:Connect(function(verb: any, argument: any)
		if verb == "Open" and Rules.isDestination(argument) then
			if phase == "pending" or phase == "covering" or phase == "uncovering" then return end
			generation += 1
			cancelTween()
			source, waiting, terminal, phase = argument, false, false, "menu"
			curtain.Visible, arrival.Visible = false, false
			status.Text, status.TextColor3 = "No coins, tickets or unlocks needed.", MUTED
			list.CanvasPosition = Vector2.zero
			if not GuiService.SelectedObject or not GuiService.SelectedObject:IsDescendantOf(gui) then
				oldSelection = GuiService.SelectedObject
			end
			refreshButtons()
			lockMovement(true)
			updateVisibility()
			resize()
			if UserInputService.GamepadEnabled then
				for _, row in rows do if row.button.Selectable then GuiService.SelectedObject = row.button; break end end
			end
		elseif verb == "Loading" and phase == "pending" then
			status.Text, status.TextColor3 = "Getting your next pond ready...", BLUE
		elseif verb == "Arrived" and phase == "pending" then
			generation += 1
			local token = generation
			phase, waiting, terminal = "uncovering", false, false
			journey.Visible, destinationLabel.Visible = false, false
			updateVisibility()
			fadeCover(1, 0.2, token, function()
				curtain.Visible, phase = false, "closed"
				arrivalName.Text, arrival.Visible = destinationName, true
				lockMovement(false)
				restoreSelection()
				updateVisibility()
				task.delay(1.4, function()
					if generation == token then arrival.Visible = false; updateVisibility() end
				end)
			end)
		elseif verb == "Rejected" then
			reject(if type(argument) == "string" then argument else "Close this menu and step into the portal again.")
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	updateVisibility()
	resize()
	-- ScreenGui.AbsoluteSize settles after parenting on the first rendered frame.
	task.defer(resize)
end

function Interface.start()
	if started then return end
	started = true
	Players.LocalPlayer:SetAttribute("IslandTravelMenuOpen", false)
	-- A custom world without travel must not block the fishing client's initial Sync.
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("FishingTravelRemotes", 30)
		if not remotes then return end
		local event = remotes:WaitForChild("Travel", 5)
		if event and event:IsA("RemoteEvent") then mount(event) end
	end)
end

return Interface
