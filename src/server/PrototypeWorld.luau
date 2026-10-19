--!strict
-- Creates an isolated disposable test world; never deletes existing user objects.
local World = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.Position = position
	object.Color = color
	object.Anchored = true
	object.Material = Enum.Material.SmoothPlastic
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function World.create(): BasePart
	assert(not workspace:FindFirstChild("MolnfiskarnaPrototype"),
		"MolnfiskarnaPrototype finns redan. Använd en tom testplats eller stäng av CreatePrototypeWorld.")
	local folder = Instance.new("Folder")
	folder.Name = "MolnfiskarnaPrototype"
	folder.Parent = workspace
	part(folder, "Island", Vector3.new(72, 4, 56), Vector3.zero, Color3.fromRGB(160, 210, 198))
	part(folder, "Dock", Vector3.new(18, 1, 26), Vector3.new(0, 1.5, 39), Color3.fromRGB(192, 149, 105))
	local spot = part(folder, "FishingSpot", Vector3.new(12, 0.12, 10), Vector3.new(0, 2.06, 44),
		Color3.fromRGB(87, 221, 243))
	spot.CanCollide = false
	spot.CanTouch = false
	spot.Transparency = 0.25
	spot.Material = Enum.Material.Neon
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PrototypeSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 2.5, 8)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(251, 215, 123)
	spawn.Parent = folder

	for index = 1, 8 do
		local angle = index * math.pi / 4
		local cloud = part(folder, "Cloud", Vector3.new(30, 12, 25),
			Vector3.new(math.cos(angle) * 45, -6, math.sin(angle) * 38), Color3.fromRGB(235, 244, 255))
		cloud.Shape = Enum.PartType.Ball
		cloud.CanCollide = false
		cloud.CanTouch = false
	end
	-- A visible prototype fish hovering beyond the dock. Decorative, not a reward source.
	local fish = part(folder, "PuffisPreview", Vector3.new(5, 3, 3), Vector3.new(0, 5, 57),
		Color3.fromRGB(255, 211, 116))
	fish.Shape = Enum.PartType.Ball
	fish.CanCollide = false
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffset = Vector3.new(0, 5, 0)
	sign.AlwaysOnTop = true
	sign.Parent = spot
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "MOLNFISKE\nStå i den blå rutan"
	text.Font = Enum.Font.GothamBold
	text.TextSize = 21
	text.TextColor3 = Color3.fromRGB(22, 45, 70)
	text.TextStrokeColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Parent = sign
	return spot
end

function World.findCustom(): BasePart
	local folder = workspace:FindFirstChild("World")
	local spot = if folder then folder:FindFirstChild("FishingSpot") else nil
	assert(spot and spot:IsA("BasePart"), "Skapa Workspace.World.FishingSpot som en förankrad Part.")
	return spot :: BasePart
end

return World
