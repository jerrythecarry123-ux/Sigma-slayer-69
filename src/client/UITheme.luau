--!strict
local TweenService = game:GetService("TweenService")
local Theme = {
	Ink = Color3.fromRGB(19, 34, 54), Panel = Color3.fromRGB(28, 47, 68),
	Text = Color3.fromRGB(244, 250, 255), Muted = Color3.fromRGB(171, 194, 211),
	Teal = Color3.fromRGB(100, 224, 210), Gold = Color3.fromRGB(255, 211, 116),
	Purple = Color3.fromRGB(199, 165, 253), Blue = Color3.fromRGB(126, 199, 250),
}
function Theme.round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end
function Theme.frame(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size, frame.Position = size, position
	frame.BackgroundColor3 = color or Theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.round(frame, 14)
	return frame
end
function Theme.surface(frame: GuiObject, accent: Color3?)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.Panel:Lerp(Color3.new(1, 1, 1), 0.04), Theme.Ink)
	gradient.Rotation = 110
	gradient.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent or Theme.Teal
	stroke.Transparency = 0.65
	stroke.Parent = frame
end
function Theme.text(parent: Instance, value: string, size: UDim2, position: UDim2, fontSize: number, color: Color3?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size, label.Position = size, position
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextSize = fontSize
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextColor3 = color or Theme.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutoLocalize = false
	label.Parent = parent
	return label
end
function Theme.button(parent: Instance, value: string, size: UDim2, position: UDim2, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Size, button.Position = size, position
	button.BackgroundColor3 = color or Theme.Teal
	button.TextColor3 = Theme.Ink
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = value
	button.AutoLocalize = false
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = parent
	Theme.round(button, 12)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0.12 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
	end)
	return button
end
function Theme.rarity(name: string): Color3
	return if name == "Epic" then Theme.Purple elseif name == "Rare" then Theme.Blue
		elseif name == "Uncommon" then Theme.Teal else Theme.Gold
end
return Theme
