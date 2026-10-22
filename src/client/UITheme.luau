--!strict
local TweenService = game:GetService("TweenService")
local Theme = {
	Ink = Color3.fromRGB(31, 63, 66), Panel = Color3.fromRGB(255, 250, 237),
	Text = Color3.fromRGB(36, 66, 66), Muted = Color3.fromRGB(90, 111, 106),
	Teal = Color3.fromRGB(37, 119, 109), Gold = Color3.fromRGB(246, 190, 81),
	Purple = Color3.fromRGB(118, 87, 166), Blue = Color3.fromRGB(44, 113, 156),
	Line = Color3.fromRGB(226, 227, 209), Soft = Color3.fromRGB(239, 241, 224),
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
	Theme.round(frame, 18)
	return frame
end
function Theme.stroke(frame: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Line
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	return stroke
end
function Theme.surface(frame: GuiObject, _accent: Color3?)
	frame.BackgroundColor3 = Theme.Panel
	Theme.stroke(frame)
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
	button.TextColor3 = Color3.fromRGB(255, 253, 243)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = value
	button.AutoLocalize = false
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = parent
	Theme.round(button, 14)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.14), { BackgroundTransparency = 0.12 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.14), { BackgroundTransparency = 0 }):Play()
	end)
	return button
end
-- Drawn locally: no icon asset IDs or image permissions required.
function Theme.coin(parent: Instance, position: UDim2, diameter: number)
	local disc = Theme.frame(parent, "CoinIcon", UDim2.fromOffset(diameter, diameter), position, Theme.Gold)
	Theme.round(disc, diameter)
	local inset = Theme.frame(disc, "Emboss", UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), Theme.Gold)
	Theme.stroke(inset, Color3.fromRGB(201, 143, 45), 1.5)
	local mark = Theme.text(disc, "+", UDim2.fromScale(1, 1), UDim2.fromOffset(0, -1), diameter * 0.65, Color3.fromRGB(157, 105, 32), true)
	mark.TextXAlignment = Enum.TextXAlignment.Center
end
function Theme.rarity(name: string): Color3
	return if name == "Legendary" then Theme.Gold elseif name == "Epic" then Theme.Purple elseif name == "Rare" then Theme.Blue
		elseif name == "Uncommon" then Theme.Teal else Color3.fromRGB(132, 94, 34)
end
return Theme
