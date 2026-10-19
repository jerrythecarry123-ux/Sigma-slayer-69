--!strict
-- Original geometry shared by the pond preview, catch animation and result card.
local Fish = {}

local function shape(parent: Model, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Fish.create(parent: Instance, name: string?): Model
	local model = Instance.new("Model")
	model.Name = name or "Pufflet"
	local body = shape(model, "Body", Vector3.new(2.8, 2, 1.9), Vector3.zero, Color3.fromRGB(255, 206, 99))
	model.PrimaryPart = body
	shape(model, "Belly", Vector3.new(2.1, 1.3, 1.6), Vector3.new(0, -0.35, -0.18), Color3.fromRGB(255, 238, 185))
	for _, side in { -1, 1 } do
		local fin = shape(model, "Fin", Vector3.new(0.9, 0.22, 1), Vector3.new(side * 1.38, -0.1, 0.15),
			Color3.fromRGB(247, 146, 107))
		fin.CFrame *= CFrame.Angles(0, 0, side * 0.25)
		shape(model, "Tail", Vector3.new(1, 1.1, 0.28), Vector3.new(side * 0.36, 0, 1.28),
			Color3.fromRGB(247, 146, 107))
		shape(model, "EyeWhite", Vector3.new(0.58, 0.65, 0.3), Vector3.new(side * 0.65, 0.34, -0.84),
			Color3.fromRGB(255, 255, 250))
		shape(model, "Pupil", Vector3.new(0.27, 0.35, 0.15), Vector3.new(side * 0.65, 0.35, -1.01),
			Color3.fromRGB(25, 44, 63))
		shape(model, "EyeGlint", Vector3.new(0.09, 0.11, 0.07), Vector3.new(side * 0.65 - 0.05, 0.43, -1.09),
			Color3.new(1, 1, 1))
		shape(model, "Cheek", Vector3.new(0.4, 0.2, 0.15), Vector3.new(side * 1.02, -0.05, -0.7),
			Color3.fromRGB(255, 159, 135))
	end
	shape(model, "Mouth", Vector3.new(0.3, 0.16, 0.16), Vector3.new(0, -0.18, -1.02), Color3.fromRGB(81, 59, 61))
	model.Parent = parent
	return model
end

return Fish
