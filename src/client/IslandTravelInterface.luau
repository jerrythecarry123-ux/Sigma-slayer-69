--!strict
-- A small touch-friendly destination list. The server chooses every landing position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Rules = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("IslandTravelRules"))
local Interface = {}
local started = false
local BLUE = Color3.fromRGB(55, 137, 203)
local PALE = Color3.fromRGB(232, 245, 250)
local CREAM = Color3.fromRGB(255, 252, 237)
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local shade = Instance.new("Frame")
	shade.Name, shade.Size = "Backdrop", UDim2.fromScale(1, 1)
	shade.BackgroundColor3, shade.BackgroundTransparency = INK, 0.35
	shade.BorderSizePixel, shade.Parent = 0, gui
	local backdrop = Instance.new("TextButton")
	backdrop.Name, backdrop.Text, backdrop.Size = "CloseBackdrop", "", UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency, backdrop.BorderSizePixel, backdrop.Parent = 1, 0, shade
	local card = Instance.new("Frame")
	card.Name, card.AnchorPoint, card.Position = "DestinationCard", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3, card.BorderSizePixel, card.Active, card.Parent = CREAM, 0, true, shade
	rounded(card, 20)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Transparency, outline.Parent = Color3.fromRGB(255, 255, 255), 2, 0.1, card
	local eyebrow = label(card, "FreeLabel", "FREE ISLAND TRAVEL", 11)
	eyebrow.Font, eyebrow.TextColor3 = Enum.Font.GothamBold, BLUE
	eyebrow.Position, eyebrow.Size = UDim2.fromOffset(20, 18), UDim2.new(1, -88, 0, 16)
	local title = label(card, "Title", "Pick your next pond", 24)
	title.Font = Enum.Font.GothamBold
	title.Position, title.Size = UDim2.fromOffset(20, 38), UDim2.new(1, -86, 0, 31)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local subtitle = label(card, "Subtitle", "Arrive right beside the fishing pier.", 13)
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
	local rows: { { id: string, button: TextButton, badge: TextLabel } } = {}
	local source, waiting, terminal = "", false, false
	local oldSelection: GuiObject? = nil
	local function setOpen(open: boolean)
		gui.Enabled = open
		player:SetAttribute("IslandTravelMenuOpen", open)
		if not open then
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = if oldSelection and oldSelection.Parent then oldSelection else nil
			end
		end
	end
	local function refreshButtons()
		for _, row in rows do
			local current = row.id == source
			local enabled = not current and not waiting and not terminal
			row.button.Active, row.button.Selectable, row.button.AutoButtonColor = enabled, enabled, enabled
			row.button.BackgroundColor3 = if current then Color3.fromRGB(244, 235, 200) else PALE
			row.badge.Text = if current then "HERE" elseif waiting then "..." else "GO"
			row.badge.TextColor3 = if current then MUTED else BLUE
		end
	end
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
			if not gui.Enabled or waiting or terminal or destination.Id == source then return end
			waiting = true
			status.Text, status.TextColor3 = "Getting your next pond ready...", BLUE
			refreshButtons()
			event:FireServer(destination.Id)
		end)
	end
	local function resize()
		-- Fixed 56-pixel rows stay easy to tap; short screens scroll instead of shrinking buttons.
		local available = gui.AbsoluteSize
		if available.X <= 0 or available.Y <= 0 then return end
		card.Size = UDim2.fromOffset(math.min(440, math.max(260, available.X - 24)), math.min(478, math.max(232, available.Y - 24)))
	end
	close.Activated:Connect(function() setOpen(false) end)
	backdrop.Activated:Connect(function() setOpen(false) end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then setOpen(false) end
	end)
	player.CharacterAdded:Connect(function() setOpen(false) end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	event.OnClientEvent:Connect(function(verb: any, argument: any)
		if verb == "Open" and Rules.isDestination(argument) then
			source, waiting, terminal = argument, false, false
			status.Text, status.TextColor3 = "No coins, tickets or unlocks needed.", MUTED
			list.CanvasPosition = Vector2.zero
			oldSelection = GuiService.SelectedObject
			refreshButtons()
			setOpen(true)
			resize()
			if UserInputService.GamepadEnabled then
				for _, row in rows do if row.button.Selectable then GuiService.SelectedObject = row.button; break end end
			end
		elseif verb == "Loading" then
			waiting = true
			status.Text, status.TextColor3 = "Getting your next pond ready...", BLUE
			refreshButtons()
		elseif verb == "Arrived" then
			waiting, terminal = false, false
			setOpen(false)
		elseif verb == "Rejected" then
			waiting, terminal = false, true
			status.Text = if type(argument) == "string" then argument else "Close this menu and try the island stand again."
			status.TextColor3 = Color3.fromRGB(165, 82, 58)
			refreshButtons()
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
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
