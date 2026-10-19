--!strict
-- Original procedural art. Walkable surfaces are separate from decorative detail.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fish = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("FishModel"))
local World = {}
local C = {
	Grass = Color3.fromRGB(134, 181, 142), Moss = Color3.fromRGB(93, 148, 125),
	Stone = Color3.fromRGB(143, 164, 166), DeepStone = Color3.fromRGB(99, 130, 146),
	Sand = Color3.fromRGB(229, 215, 178), Wood = Color3.fromRGB(150, 104, 73),
	Plank = Color3.fromRGB(198, 154, 105), Cream = Color3.fromRGB(252, 239, 205),
	Teal = Color3.fromRGB(65, 139, 132), Water = Color3.fromRGB(93, 193, 194),
	Cloud = Color3.fromRGB(243, 242, 234), Coral = Color3.fromRGB(232, 168, 143),
}
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, decor: boolean?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.Material = true, Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if decor then p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false end
	p.Parent = parent
	return p
end
local function ball(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, decor: boolean?): Part
	local p = part(parent, name, size, CFrame.new(pos), color, decor)
	p.Shape = Enum.PartType.Ball
	return p
end
local function disk(parent: Instance, name: string, width: number, depth: number, thickness: number, pos: Vector3, color: Color3, decor: boolean?): Part
	local p = part(parent, name, Vector3.new(thickness, width, depth), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, decor)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function strut(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3, decor: boolean?): Part
	local p = part(parent, name, Vector3.new((b - a).Magnitude, width, width),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, decor)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function plaque(parent: BasePart, text: string, sub: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "PaintedSign", Enum.NormalId.Front
	gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(700, 240)
	gui.LightInfluence, gui.Parent = 0.35, parent
	local label = Instance.new("TextLabel")
	label.Size, label.Position = UDim2.fromScale(0.92, 0.48), UDim2.fromScale(0.04, 0.09)
	label.BackgroundTransparency, label.Text = 1, text
	label.Font, label.TextSize = Enum.Font.GothamBold, 48
	label.TextColor3, label.AutoLocalize, label.Parent = C.Cream, false, gui
	local caption = label:Clone()
	caption.Text, caption.TextSize = sub, 25
	caption.Position, caption.Size, caption.Parent = UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.92, 0.25), gui
end
local function lantern(parent: Instance, pos: Vector3)
	strut(parent, "LanternHanger", pos + Vector3.new(0, 0.9, 0), pos + Vector3.new(0, 1.6, 0), 0.1, C.Wood, true)
	local glow = part(parent, "WarmLantern", Vector3.new(0.8, 1.05, 0.8), CFrame.new(pos), C.Cream, true)
	glow.Material = Enum.Material.Neon
	for _, y in { -0.63, 0.63 } do
		part(parent, "LanternCap", Vector3.new(1.05, 0.17, 1.05), CFrame.new(pos + Vector3.new(0, y, 0)), C.Teal, true)
	end
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.45, 0.45 } do
			strut(parent, "LanternFrame", pos + Vector3.new(x, -0.6, z), pos + Vector3.new(x, 0.6, z), 0.07, C.Wood, true)
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(255, 218, 160), 0.6, 13, false
	light.Parent = glow
end
local function tree(parent: Instance, pos: Vector3, scale: number, tint: Color3, seed: number)
	local model = Instance.new("Model")
	model.Name = "WindTree"
	local r = Random.new(seed)
	local top = pos + Vector3.new(0, 9 * scale, 0)
	local trunk = strut(model, "Trunk", pos, top, 1.25 * scale, C.Wood)
	trunk.Material = Enum.Material.Wood
	for index = 1, 4 do
		local angle = index * math.pi / 2 + seed
		local endPos = top + Vector3.new(math.cos(angle) * 3, index % 2, math.sin(angle) * 3) * scale
		strut(model, "Branch", pos + Vector3.new(0, 5.2 * scale, 0), endPos, 0.55 * scale, C.Wood, true)
		for layer = 1, 2 do
			local crown = ball(model, "Canopy", Vector3.new(6.7, 4.4, 6.3) * scale,
				endPos + Vector3.new(0, (layer - 1) * 2.3, 0) * scale, tint:Lerp(C.Cream, r:NextNumber(0, 0.17)), true)
			crown.CFrame *= CFrame.Angles(r:NextNumber(-0.2, 0.2), angle, 0.13)
		end
	end
	ball(model, "CanopyTop", Vector3.new(6.6, 5.5, 6.8) * scale, top + Vector3.new(0, 3.3 * scale, 0), tint, true)
	model.Parent = parent
end
local function floatingIsland(parent: Instance, pos: Vector3, size: number, seed: number)
	local model = Instance.new("Model")
	model.Name = "DistantIsle"
	disk(model, "Meadow", size, size * 0.76, 2, pos, C.Moss, true)
	ball(model, "Cliff", Vector3.new(size * 0.95, size * 0.6, size * 0.72), pos - Vector3.new(0, size * 0.22, 0), C.DeepStone, true)
	ball(model, "Taper", Vector3.new(size * 0.5, size * 0.52, size * 0.4), pos - Vector3.new(0, size * 0.5, 0), C.Stone, true)
	tree(model, pos + Vector3.yAxis, size / 30, if seed % 2 == 0 then C.Coral else Color3.fromRGB(170, 198, 153), seed)
	-- Distant tree trunks must not create invisible obstacles to falling players.
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then child.CanCollide, child.CanTouch, child.CanQuery = false, false, false end
	end
	model.Parent = parent
end

function World.create(): BasePart
	assert(not workspace:FindFirstChild("MolnfiskarnaPrototype"), "Prototype world already exists. Disable CreatePrototypeWorld for a custom world.")
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "MolnfiskarnaPrototype", workspace
	Lighting.ClockTime, Lighting.Brightness, Lighting.GlobalShadows = 16.25, 2.4, true
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(117, 140, 153), Color3.fromRGB(173, 189, 186)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(209, 229, 228), 170, 650
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.8, 0.8
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name, atmosphere.Density, atmosphere.Haze, atmosphere.Glare = "SundriftAir", 0.27, 1.5, 0.12
	atmosphere.Color, atmosphere.Decay, atmosphere.Offset = Color3.fromRGB(228, 235, 218), Color3.fromRGB(160, 183, 196), 0.15
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name, grade.Saturation, grade.Contrast, grade.Brightness = "SundriftGrade", 0.06, 0.09, 0.015
	grade.TintColor, grade.Parent = Color3.fromRGB(255, 246, 230), Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold, bloom.Parent = "LanternBloom", 0.15, 24, 1.8, Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity, sun.Spread, sun.Parent = 0.035, 0.85, Lighting

	-- A curved silhouette and layered cliff replace the rectangular platform.
	local meadow = disk(folder, "Meadow", 74, 60, 4, Vector3.new(0, 0, 0), C.Grass)
	meadow.Material = Enum.Material.Grass
	disk(folder, "EarthLip", 75, 61, 2, Vector3.new(0, -2.3, 0), C.Sand)
	ball(folder, "CliffBody", Vector3.new(70, 22, 56), Vector3.new(0, -12, 0), C.Stone)
	ball(folder, "IslandKeel", Vector3.new(42, 27, 35), Vector3.new(-3, -25, 2), C.DeepStone)
	for i = 1, 16 do
		local a = i * math.pi / 8
		local pos = Vector3.new(math.cos(a) * 31, -6 - i % 3, math.sin(a) * 24)
		local rock = part(folder, "CliffFacet", Vector3.new(9, 15, 9), CFrame.new(pos) * CFrame.Angles(0.1, a, 0.15),
			if i % 3 == 0 then C.DeepStone else C.Stone, true)
		rock.Material = Enum.Material.Slate
		ball(folder, "GrassBank", Vector3.new(10, 2.2, 9), Vector3.new(math.cos(a) * 31, 1.2, math.sin(a) * 24), C.Grass, true)
	end
	-- Rounded stepping stones keep the central route readable without a neon runway.
	for i = 0, 9 do
		local z = -9 + i * 3.8
		local p = disk(folder, "PathStone", 5.4 + i % 2, 3.2, 0.13, Vector3.new(math.sin(i * 0.7) * 1.6, 2.08, z), C.Sand)
		p.CFrame *= CFrame.Angles(0, i * 0.3, 0)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame = "PrototypeSpawn", Vector3.new(6, 0.5, 6), CFrame.new(0, 2.3, -8) * CFrame.Angles(0, math.pi, 0)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.Parent = true, true, 0, 1, folder

	-- Boardwalk: staggered warm timber, pegs, rope rails and a broad casting platform.
	part(folder, "DockBase", Vector3.new(17.5, 0.8, 29), CFrame.new(0, 1.4, 38.5), C.Wood)
	for i = 0, 14 do
		local p = part(folder, "DockBoard", Vector3.new(18, 0.3, 1.85), CFrame.new(0, 1.98, 25 + i * 1.9),
			C.Plank:Lerp(C.Cream, (i % 3) * 0.045))
		p.Material = Enum.Material.Wood
		for _, x in { -7.4, 7.4 } do disk(folder, "BoardPeg", 0.12, 0.12, 0.02, Vector3.new(x, 2.14, 25 + i * 1.9), C.Wood, true) end
	end
	for _, x in { -9.3, 9.3 } do
		for i, z in { 28, 38, 49 } do
			strut(folder, "DockPiling", Vector3.new(x, -3, z), Vector3.new(x, 5.1, z), 0.75, C.Wood)
			disk(folder, "PostCap", 1.05, 1.05, 0.22, Vector3.new(x, 5.15, z), C.Plank, true)
			if i < 3 then
				local nextZ = if i == 1 then 38 else 49
				for segment = 0, 5 do
					local function ropePoint(t: number): Vector3
						return Vector3.new(x, 4.6 - math.sin(t * math.pi) * 0.75, z + (nextZ - z) * t)
					end
					strut(folder, "RopeRail", ropePoint(segment / 6), ropePoint((segment + 1) / 6), 0.14, C.Cream, true)
				end
			end
		end
	end
	for _, x in { -7, 7 } do
		strut(folder, "LampPost", Vector3.new(x, 2.2, 28), Vector3.new(x, 8, 28), 0.25, C.Teal)
		strut(folder, "LampArm", Vector3.new(x, 8, 28), Vector3.new(x * 0.84, 8, 28), 0.2, C.Teal, true)
		lantern(folder, Vector3.new(x * 0.84, 6.4, 28))
	end
	local spot = part(folder, "FishingSpot", Vector3.new(12, 0.08, 9), CFrame.new(0, 2.19, 45) * CFrame.Angles(0, math.pi, 0), C.Teal, true)
	spot.Transparency = 0.65
	-- Inlaid edge marks guide new players but leave the timber visible.
	for _, x in { -6, 6 } do
		part(folder, "CastingInlay", Vector3.new(0.12, 0.03, 5), CFrame.new(x, 2.25, 45), C.Cream, true)
	end
	local dockSign = part(folder, "HarborPlaque", Vector3.new(5, 1.7, 0.25), CFrame.new(-5, 3.5, 37), C.Teal, true)
	plaque(dockSign, "SUNDRIFT", "Cast. Discover. Unwind.")

	-- A suspended lagoon with a stone bowl, shallow shelves and fine foam edges.
	ball(folder, "LagoonBowl", Vector3.new(61, 17, 47), Vector3.new(0, -9.4, 68), C.Stone)
	ball(folder, "LagoonKeel", Vector3.new(29, 23, 26), Vector3.new(3, -18, 71), C.DeepStone, true)
	disk(folder, "LagoonBed", 56, 42, 1.2, Vector3.new(0, -1.2, 68), Color3.fromRGB(54, 139, 148), true)
	local water = disk(folder, "CloudPond", 56, 42, 0.16, Vector3.new(0, 0.77, 68), C.Water, true)
	water.Material, water.Transparency, water.Reflectance = Enum.Material.Glass, 0.22, 0.12
	for i = 1, 32 do
		local a = i * math.pi / 16
		local pos = Vector3.new(math.cos(a) * 28.4, -0.15, 68 + math.sin(a) * 21.5)
		-- Keep the near edge low where the dock meets the lagoon.
		ball(folder, "LagoonRim", Vector3.new(5.6, if math.sin(a) < -0.6 then 1.5 else 3, 4.7), pos,
			if i % 4 == 0 then C.Moss else C.Sand, true)
	end
	for ring = 1, 3 do
		for i = 1, 18 do
			local a, b = i * math.pi / 9, (i + 0.65) * math.pi / 9
			local rx, rz = 25 - ring * 1.5, 18.5 - ring
			local p = strut(folder, "WaterGlint", Vector3.new(math.cos(a) * rx, 0.89, 68 + math.sin(a) * rz),
				Vector3.new(math.cos(b) * rx, 0.89, 68 + math.sin(b) * rz), 0.045, C.Cream, true)
			p.Transparency = 0.68
		end
	end
	-- Broad flowing sheets and a misty base: animated locally, with no additional sound.
	for i = -1, 1 do
		local sheet = part(folder, "WaterfallRibbon", Vector3.new(2.4, 37 + i * 3, 0.18),
			CFrame.new(7 + i * 2.2, -18 - i * 1.5, 88), C.Water:Lerp(C.Cream, 0.2), true)
		sheet.Material, sheet.Transparency = Enum.Material.Glass, 0.3
		sheet:SetAttribute("FlowRibbon", true)
		for stripe = 1, 3 do
			local streak = part(folder, "WaterfallStreak", Vector3.new(0.1, 5 + stripe, 0.06),
				CFrame.new(6.2 + i * 2.2 + stripe * 0.38, -stripe * 9, 87.85), C.Cream, true)
			streak.Transparency = 0.65
			streak:SetAttribute("FlowStart", streak.CFrame)
			streak:SetAttribute("FlowPhase", stripe * 0.28 + i)
		end
	end
	-- A small roofed workshop, with curved stripe tiles, a counter and tackle props.
	local shopModel = Instance.new("Model")
	shopModel.Name, shopModel.Parent = "RodWorkshop", folder
	part(shopModel, "ShopDeck", Vector3.new(15, 0.35, 11), CFrame.new(20, 2.24, 8), C.Plank)
	for _, x in { 13.5, 26.5 } do
		for _, z in { 3.5, 12.5 } do
			strut(shopModel, "PavilionPost", Vector3.new(x, 2.4, z), Vector3.new(x, 10, z), 0.5, C.Wood)
		end
	end
	part(shopModel, "CounterBody", Vector3.new(11, 2.5, 2.3), CFrame.new(20, 3.7, 11), C.Teal)
	local counter = part(shopModel, "WorkshopCounter", Vector3.new(12, 0.35, 3), CFrame.new(20, 5.1, 11), C.Cream)
	for x = 15, 25, 2 do part(shopModel, "CounterSlat", Vector3.new(0.12, 2.3, 0.08), CFrame.new(x, 3.7, 12.2), C.Cream, true) end
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			local roof = part(shopModel, "CanopyStripe", Vector3.new(1.95, 0.3, 6.8),
				CFrame.new(13.2 + i * 1.95, 10.7, 8 + side * 3.1) * CFrame.Angles(side * 0.24, 0, 0),
				if i % 2 == 0 then C.Teal else C.Cream)
			roof.CanCollide = false
		end
	end
	strut(shopModel, "RoofRidge", Vector3.new(12.3, 11.5, 8), Vector3.new(28.2, 11.5, 8), 0.32, C.Wood, true)
	local shopSign = part(shopModel, "WorkshopSign", Vector3.new(8.5, 2, 0.25), CFrame.new(20, 8.8, 1.6), C.Teal, true)
	plaque(shopSign, "ROD & REEL", "A little upgrade. A bigger adventure.")
	lantern(shopModel, Vector3.new(13.5, 7.1, 12.5))
	for i = 1, 3 do
		strut(shopModel, "DisplayRod", Vector3.new(17 + i, 5.3, 10.8), Vector3.new(16.6 + i, 8.1, 10.6), 0.08,
			if i == 3 then C.Coral else C.Teal, true)
		disk(shopModel, "Spool", 0.7, 0.7, 0.55, Vector3.new(22 + i * 0.6, 5.5, 11), C.Plank, true)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "RodWorkshopPrompt", "Browse rods", "Rod & Reel"
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = 0, 10, false, counter

	-- A shady picnic corner balances the shop on the opposite side.
	for _, z in { -3.5, -2.4, -1.3 } do part(folder, "BenchSlat", Vector3.new(7, 0.25, 0.9), CFrame.new(-19, 4, z), C.Plank) end
	for _, x in { -21.5, -16.5 } do part(folder, "BenchLeg", Vector3.new(0.5, 2, 3), CFrame.new(x, 3, -2.4), C.Wood) end
	part(folder, "BenchBack", Vector3.new(7, 1.6, 0.25), CFrame.new(-19, 5.2, -3.7), C.Teal)
	tree(folder, Vector3.new(-24, 2, -12), 1.05, Color3.fromRGB(172, 197, 153), 11)
	tree(folder, Vector3.new(22, 2, -15), 0.9, C.Coral, 15)
	tree(folder, Vector3.new(-25, 2, 13), 0.85, Color3.fromRGB(152, 184, 146), 19)
	tree(folder, Vector3.new(28, 2, 20), 0.65, Color3.fromRGB(226, 188, 155), 22)
	local random = Random.new(31)
	for i = 1, 34 do
		local x = (if i % 2 == 0 then -1 else 1) * random:NextNumber(9, 29)
		local z = random:NextNumber(-21, 21)
		if x > 10 and z > 0 and z < 16 then continue end
		for blade = 1, 3 do
			local grass = part(folder, "MeadowBlade", Vector3.new(0.13, random:NextNumber(0.7, 1.5), 0.28),
				CFrame.new(x + blade * 0.23, 2.4, z) * CFrame.Angles(0, blade, (blade - 2) * 0.3), C.Moss, true)
			grass.Material = Enum.Material.Grass
		end
		if i % 2 == 0 then
			local center = Vector3.new(x, 3.05, z)
			strut(folder, "FlowerStem", Vector3.new(x, 2, z), center, 0.08, C.Moss, true)
			for petal = 1, 5 do
				local a = petal * math.pi * 0.4
				ball(folder, "Petal", Vector3.new(0.42, 0.16, 0.65), center + Vector3.new(math.cos(a) * 0.25, 0, math.sin(a) * 0.25),
					if i % 4 == 0 then C.Cream else C.Coral, true)
			end
			ball(folder, "FlowerHeart", Vector3.new(0.2, 0.2, 0.2), center + Vector3.yAxis * 0.1, Color3.fromRGB(243, 194, 85), true)
		end
	end
	for i = 1, 10 do
		local a = i * math.pi / 5
		for puff = 0, 2 do
			ball(folder, "CloudPuff", Vector3.new(27, 9 + puff * 2, 23),
				Vector3.new(math.cos(a) * (47 + puff * 6), -12 - puff * 3, 15 + math.sin(a) * 62), C.Cloud, true)
		end
	end
	for i, pos in {
		Vector3.new(-102, 12, 106), Vector3.new(112, 25, 142), Vector3.new(-165, 40, 210),
		Vector3.new(55, 48, 245), Vector3.new(180, 5, 230),
	} do floatingIsland(folder, pos, 24 + i * 3, i * 7) end
	-- Airship silhouette provides a focal point beyond the lagoon.
	local ship = Instance.new("Model")
	ship.Name = "SkySail"
	ball(ship, "Envelope", Vector3.new(15, 10, 27), Vector3.new(-72, 43, 166), C.Coral, true)
	ball(ship, "EnvelopeStripe", Vector3.new(15.3, 10.3, 6), Vector3.new(-72, 43, 166), C.Cream, true)
	part(ship, "Gondola", Vector3.new(5, 2.3, 9), CFrame.new(-72, 33, 166), C.Wood, true)
	for _, x in { -74, -70 } do
		strut(ship, "Rigging", Vector3.new(x, 34, 162), Vector3.new(x, 39, 161), 0.1, C.Cream, true)
		strut(ship, "Rigging", Vector3.new(x, 34, 170), Vector3.new(x, 39, 171), 0.1, C.Cream, true)
	end
	ship.Parent = folder
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
