--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("FishRarity"))
local reducedEffects = false
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
	button.Selectable = true
	button.BorderSizePixel = 0
	button.Parent = parent
	Theme.round(button, 14)
	button.MouseEnter:Connect(function()
		if reducedEffects then return end
		TweenService:Create(button, TweenInfo.new(0.14), { BackgroundTransparency = 0.12 }):Play()
	end)
	button.MouseLeave:Connect(function()
		if reducedEffects then button.BackgroundTransparency = 0; return end
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
	return disc
end
function Theme.rarity(name: string): Color3
	local color = Rarity.get(name).Color
	return Color3.fromRGB(color[1], color[2], color[3])
end
function Theme.rarityLabel(name: string): string
	return tostring(Rarity.get(name).Rank) .. " / " .. string.upper(name)
end
function Theme.setReducedEffects(enabled: boolean)
	reducedEffects = enabled
end
function Theme.effectsReduced(): boolean
	return reducedEffects
end
function Theme.selectionGroup(frame: GuiObject)
	frame.SelectionGroup = true
	frame.SelectionBehaviorUp, frame.SelectionBehaviorDown = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
	frame.SelectionBehaviorLeft, frame.SelectionBehaviorRight = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
end

-- Capture once after the model's appearance/weight has been applied. The padded
-- box follows its actual pivot, so a long or asymmetric fish is not cropped by
-- a fixed camera aimed at the origin. Animation may move fins inside the margin.
function Theme.portraitBounds(model: Model): any
	local bounds, size = model:GetBoundingBox()
	local relative = model:GetPivot():Inverse() * bounds
	local center = relative.Position
	local corners: { Vector3 } = {}
	for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
		table.insert(corners, relative * (size * Vector3.new(x, y, z) * .58) - center)
	end end end
	return { center = center, corners = corners }
end

local portraitDirection = Vector3.new(.42, .13, -1).Unit
local portraitBasis = CFrame.lookAt(Vector3.zero, -portraitDirection)
function Theme.fitPortrait(view: ViewportFrame, camera: Camera, model: Model, bounds: any)
	local size, pivot = view.AbsoluteSize, model:GetPivot()
	if size.X <= 0 or size.Y <= 0 then return end
	if bounds.width == size.X and bounds.height == size.Y and bounds.pivot == pivot then return end
	bounds.width, bounds.height, bounds.pivot = size.X, size.Y, pivot
	local target = pivot * bounds.center
	local tangent = math.tan(math.rad(camera.FieldOfView * .5)) * .92
	local aspect = math.max(.2, size.X / size.Y)
	local distance = 2
	for _, corner in bounds.corners do
		local projected = portraitBasis:PointToObjectSpace(pivot * (bounds.center + corner) - target)
		distance = math.max(distance, math.abs(projected.Y) / tangent + projected.Z,
			math.abs(projected.X) / (tangent * aspect) + projected.Z)
	end
	camera.CFrame = CFrame.lookAt(target + portraitDirection * distance, target)
end
return Theme
