--!strict
local Catalog = require(script.Parent:WaitForChild("FishCatalog"))
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

function Fish.create(parent: Instance, name: string?, speciesId: string?): Model
	local species = Catalog.get(speciesId)
	local bodyColor = Color3.fromRGB(table.unpack(species.Body))
	local finColor = Color3.fromRGB(table.unpack(species.Fin))
	local model = Instance.new("Model")
	model.Name = name or species.Name
	model:SetAttribute("SpeciesId", species.Id)
	local kind = species.Shape
	local size = if kind == "Ray" then Vector3.new(3.8, 0.95, 2.1)
		elseif kind == "Long" or kind == "Lure" then Vector3.new(2.2, 1.5, 2.7) else Vector3.new(2.8, 2, 1.9)
	local body = shape(model, "Body", size, Vector3.zero, bodyColor)
	model.PrimaryPart = body
	shape(model, "Belly", size * Vector3.new(0.75, 0.65, 0.86), Vector3.new(0, -size.Y * 0.18, -0.1),
		bodyColor:Lerp(Color3.new(1, 1, 1), 0.65))
	local front = -size.Z * 0.45
	for _, side in { -1, 1 } do
		local fin = shape(model, "Fin", if kind == "Ray" then Vector3.new(2.4, 0.2, 2.2) else Vector3.new(0.9, 0.22, 1),
			Vector3.new(side * size.X * 0.48, -0.08, 0.2), finColor)
		fin.CFrame *= CFrame.Angles(0, 0, side * 0.22)
		fin:SetAttribute("FinRest", fin.CFrame)
		fin:SetAttribute("Side", side)
		shape(model, "Tail", Vector3.new(0.9, 1, 0.28), Vector3.new(side * 0.32, 0, size.Z * 0.7), finColor)
		shape(model, "EyeWhite", Vector3.new(0.58, 0.6, 0.3), Vector3.new(side * 0.65, size.Y * 0.16, front), Color3.new(1, 1, 1))
		shape(model, "Pupil", Vector3.new(0.27, 0.32, 0.15), Vector3.new(side * 0.65, size.Y * 0.17, front - 0.17), Color3.fromRGB(25, 44, 63))
		shape(model, "EyeGlint", Vector3.new(0.09, 0.11, 0.07), Vector3.new(side * 0.65 - 0.05, size.Y * 0.17 + 0.08, front - 0.25), Color3.new(1, 1, 1))
		shape(model, "Cheek", Vector3.new(0.36, 0.17, 0.15), Vector3.new(side * 0.98, -0.12, front + 0.16), Color3.fromRGB(255, 164, 153))
		if kind == "Whiskers" then
			local whisker = shape(model, "Whisker", Vector3.new(1.1, 0.09, 0.09), Vector3.new(side * 1.12, -0.18, front - 0.03), finColor)
			whisker.CFrame *= CFrame.Angles(0, side * -0.35, side * 0.2)
		end
	end
	shape(model, "Mouth", Vector3.new(0.3, 0.14, 0.16), Vector3.new(0, -0.2, front - 0.18), Color3.fromRGB(81, 59, 61))
	if kind == "Spiky" or kind == "Whiskers" then
		for index = -1, 1 do
			shape(model, "Crown", Vector3.new(0.35, 0.6 - math.abs(index) * 0.15, 0.5), Vector3.new(index * 0.4, size.Y * 0.5, 0.1), finColor)
		end
	elseif kind == "Lure" then
		shape(model, "LureStem", Vector3.new(0.13, 0.9, 0.13), Vector3.new(0, 1, front + 0.2), finColor)
		local lure = shape(model, "LureGlow", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 1.5, front + 0.2), finColor)
		lure.Material = Enum.Material.Neon
	end
	model.Parent = parent
	return model
end

function Fish.animate(model: Model, time: number)
	local pivot = model:GetPivot()
	for _, child in model:GetChildren() do
		if child.Name == "Fin" and child:IsA("BasePart") then
			local rest = child:GetAttribute("FinRest")
			local side = child:GetAttribute("Side")
			if typeof(rest) == "CFrame" and typeof(side) == "number" then
				child.CFrame = pivot * rest * CFrame.Angles(0, 0, math.sin(time * 6) * 0.16 * side)
			end
		end
	end
end

return Fish
