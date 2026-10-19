--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fish = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("FishModel"))
local World = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cf
	object.Color = color
	object.Anchored = true
	object.Material = Enum.Material.SmoothPlastic
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local function sign(parent: BasePart, text: string, offset: Vector3, width: number, size: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldSign"
	gui.Size = UDim2.fromOffset(width, 64)
	gui.StudsOffset = offset
	gui.MaxDistance = 120
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.AutoLocalize = false
	label.TextSize = size
	label.TextColor3 = Color3.fromRGB(255, 246, 216)
	label.TextStrokeColor3 = Color3.fromRGB(25, 49, 69)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

function World.create(): BasePart
	assert(not workspace:FindFirstChild("MolnfiskarnaPrototype"),
		"Prototype world already exists. Use a separate test place or disable CreatePrototypeWorld.")
	local folder = Instance.new("Folder")
	folder.Name = "MolnfiskarnaPrototype"
	folder.Parent = workspace
	Lighting.ClockTime = 15
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(155, 177, 204)
	Lighting.OutdoorAmbient = Color3.fromRGB(177, 195, 220)
	Lighting.FogColor = Color3.fromRGB(190, 218, 245)
	Lighting.FogStart = 130
	Lighting.FogEnd = 420
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SundriftAir"
	atmosphere.Density, atmosphere.Haze, atmosphere.Glare = 0.22, 1.2, 0.12
	atmosphere.Color = Color3.fromRGB(216, 237, 248)
	atmosphere.Decay = Color3.fromRGB(177, 193, 221)
	atmosphere.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "SundriftColor"
	color.Saturation, color.Contrast, color.Brightness = 0.1, 0.05, 0.015
	color.TintColor = Color3.fromRGB(255, 247, 236)
	color.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SundriftGlow"
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.12, 20, 1.5
	bloom.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity, sun.Spread = 0.035, 0.8
	sun.Parent = Lighting

	local island = part(folder, "Island", Vector3.new(72, 7, 56), CFrame.new(0, -1.5, 0), Color3.fromRGB(121, 178, 151))
	island.Material = Enum.Material.Grass
	part(folder, "IslandRock", Vector3.new(66, 10, 50), CFrame.new(0, -8, 0), Color3.fromRGB(120, 147, 171))
	for index = 1, 10 do
		local angle = index * math.pi / 5
		local rock = part(folder, "RockRim", Vector3.new(15, 11, 13),
			CFrame.new(math.cos(angle) * 29, -4, math.sin(angle) * 22), Color3.fromRGB(136, 159, 178))
		rock.Shape = Enum.PartType.Ball
	end
	part(folder, "Path", Vector3.new(12, 0.12, 40), CFrame.new(0, 2.06, 6), Color3.fromRGB(223, 210, 174))
	for index = 0, 7 do
		local stone = part(folder, "Wayfinder", Vector3.new(1.8, 0.1, 0.7), CFrame.new(0, 2.14, -4 + index * 4), Color3.fromRGB(255, 222, 146))
		stone.Material, stone.CanCollide = Enum.Material.Neon, false
	end
	part(folder, "DockBase", Vector3.new(18, 0.7, 26), CFrame.new(0, 1.5, 39), Color3.fromRGB(105, 77, 65))
	for index = 0, 12 do
		part(folder, "DockPlank", Vector3.new(18, 0.32, 1.88), CFrame.new(0, 1.99, 27 + index * 2),
			if index % 2 == 0 then Color3.fromRGB(195, 148, 100) else Color3.fromRGB(180, 131, 88))
	end
	for _, x in { -9.5, 9.5 } do
		for _, z in { 29, 39, 50 } do
			part(folder, "DockPost", Vector3.new(0.7, 5, 0.7), CFrame.new(x, 2.8, z), Color3.fromRGB(120, 87, 65))
		end
		part(folder, "Rail", Vector3.new(0.35, 0.35, 22), CFrame.new(x, 4.7, 39), Color3.fromRGB(223, 190, 137))
	end
	local spot = part(folder, "FishingSpot", Vector3.new(12, 0.12, 9),
		CFrame.new(0, 2.24, 45) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(95, 225, 230))
	spot.CanCollide = false
	spot.CanTouch = false
	spot.Transparency = 0.45
	spot.Material = Enum.Material.Neon
	sign(spot, "SUNDRIFT POND\nCast from the glowing spot", Vector3.new(0, 6, 0), 310, 18)

	local pond = part(folder, "CloudPond", Vector3.new(64, 2, 40), CFrame.new(0, -0.2, 67), Color3.fromRGB(126, 210, 227))
	pond.Shape = Enum.PartType.Ball
	pond.Material = Enum.Material.Glass
	pond.Transparency = 0.22
	pond.CanCollide = false
	pond.CanTouch = false
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PrototypeSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 2.6, -5)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = folder
	local welcome = part(folder, "WelcomePost", Vector3.new(0.6, 7, 0.6), CFrame.new(0, 5, -14), Color3.fromRGB(149, 110, 82))
	sign(welcome, "CLOUD ANGLERS\nYour next catch is above the clouds", Vector3.new(0, 5, 0), 410, 22)

	for _, x in { -24, 24 } do
		for _, z in { -15, 12 } do
			part(folder, "TreeTrunk", Vector3.new(1.6, 9, 1.6), CFrame.new(x, 6, z), Color3.fromRGB(152, 114, 92))
			local crown = part(folder, "TreeCrown", Vector3.new(12, 11, 12), CFrame.new(x, 13, z),
				if z < 0 then Color3.fromRGB(175, 206, 183) else Color3.fromRGB(244, 194, 163))
			crown.Shape = Enum.PartType.Ball
		end
	end
	local random = Random.new(31)
	for index = 1, 32 do
		local x = (if index % 2 == 0 then -1 else 1) * random:NextNumber(9, 30)
		local z = random:NextNumber(-21, 19)
		local stem = part(folder, "FlowerStem", Vector3.new(0.14, 1.2, 0.14), CFrame.new(x, 2.7, z), Color3.fromRGB(107, 160, 131))
		stem.CanCollide, stem.CanTouch = false, false
		local flower = part(folder, "Flower", Vector3.new(0.9, 0.45, 0.9), CFrame.new(x, 3.35, z),
			if index % 3 == 0 then Color3.fromRGB(233, 173, 214) else Color3.fromRGB(255, 224, 160))
		flower.Shape, flower.CanCollide, flower.CanTouch = Enum.PartType.Ball, false, false
	end
	local shop = part(folder, "WorkshopCounter", Vector3.new(10, 3, 5), CFrame.new(17, 3.5, 12), Color3.fromRGB(159, 116, 87))
	for _, x in { 12, 22 } do
		part(folder, "WorkshopPost", Vector3.new(0.6, 7, 0.6), CFrame.new(x, 5.5, 14), Color3.fromRGB(135, 101, 81))
	end
	part(folder, "WorkshopAwning", Vector3.new(12, 0.5, 8), CFrame.new(17, 9, 12), Color3.fromRGB(101, 187, 182))
	sign(shop, "ROD WORKSHOP\nUpgrade / discover / earn while away", Vector3.new(0, 7.5, 0), 290, 15)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RodWorkshopPrompt"
	prompt.ActionText, prompt.ObjectText = "Open journal", "Rod Workshop"
	prompt.HoldDuration, prompt.MaxActivationDistance = 0, 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shop
	for _, x in { -31, 31 } do
		local crystal = part(folder, "CloudCrystal", Vector3.new(1.6, 4, 1.6),
			CFrame.new(x, 3.7, 24) * CFrame.Angles(0.1, 0.4, 0.2), Color3.fromRGB(145, 231, 235))
		crystal.Material = Enum.Material.Neon
		crystal.Transparency = 0.25
		crystal.CanCollide = false
	end
	for index = 1, 14 do
		local angle = index * math.pi / 7
		local cloud = part(folder, "Cloud", Vector3.new(33, 11, 28),
			CFrame.new(math.cos(angle) * 52, -7 - index % 3, 20 + math.sin(angle) * 61), Color3.fromRGB(239, 246, 255))
		cloud.Shape = Enum.PartType.Ball
		cloud.CanCollide = false
		cloud.CanTouch = false
	end
	for _, x in { -7, 7 } do
		local lamp = part(folder, "Lantern", Vector3.new(1.2, 1.7, 1.2), CFrame.new(x, 5, 27), Color3.fromRGB(255, 220, 146))
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = lamp.Color
		light.Brightness = 0.7
		light.Range = 14
		light.Parent = lamp
	end
	local fish = Fish.create(folder, "PuffletPreview")
	fish:PivotTo(CFrame.new(0, 4, 66))
	return spot
end

function World.findCustom(): BasePart
	local folder = workspace:FindFirstChild("World")
	local spot = if folder then folder:FindFirstChild("FishingSpot") else nil
	assert(spot and spot:IsA("BasePart"), "Create an anchored Part at Workspace.World.FishingSpot.")
	return spot :: BasePart
end

return World
