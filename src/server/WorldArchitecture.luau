--!strict
-- Original, explorable harbor buildings. Every public entry stays open; decorative
-- glazing, ropes and shingles do not add physics work to the walking surfaces.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))

local Architecture = {}
local C = {
	Timber = Color3.fromRGB(151, 103, 64),
	Wood = Color3.fromRGB(202, 151, 99),
	Plank = Color3.fromRGB(230, 185, 126),
	Dark = Color3.fromRGB(39, 84, 100),
	Cream = Color3.fromRGB(255, 247, 220),
	Stone = Color3.fromRGB(207, 212, 193),
	Moss = Color3.fromRGB(75, 170, 104),
	Glass = Color3.fromRGB(136, 225, 230),
	Gold = Color3.fromRGB(255, 198, 79),
	Rope = Color3.fromRGB(233, 214, 163),
	Roof = Color3.fromRGB(53, 178, 188),
	Coral = Color3.fromRGB(245, 133, 114),
	Sky = Color3.fromRGB(104, 184, 225),
}
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local STONE = Enum.Material.Slate
local METAL = Enum.Material.Metal

local function p(parent, name, size, cf, color, material, collidable)
	return Kit.part(parent, name, size, cf, color, {
		material = material or WOOD,
		collidable = collidable == true,
	})
end

local function beam(parent, name, a, b, thickness, color, material)
	return Kit.beam(parent, name, a, b, thickness, color, { material = material or WOOD })
end

local function localBeam(parent, cf, name, a, b, thickness, color, material)
	return beam(parent, name, cf:PointToWorldSpace(a), cf:PointToWorldSpace(b), thickness, color, material)
end

local function localBall(parent, cf, name, size, position, color, material)
	return Kit.ball(parent, name, size, cf:PointToWorldSpace(position), color, {
		material = material or WOOD,
	})
end

local function barrel(parent, cf, scale)
	local model = Kit.model(parent, "CooperedBarrel")
	local s = scale or 1
	local center = cf * CFrame.new(0, 1.1 * s, 0)
	Kit.disk(model, "OakStaves", 1.9 * s, 1.9 * s, 2.2 * s, center.Position, C.Wood, { material = WOOD })
	for _, y in { 0.25, 0.65, 1.75, 2.05 } do
		Kit.disk(model, "IronHoop", 1.99 * s, 1.99 * s, 0.11 * s, (cf * CFrame.new(0, y * s, 0)).Position, C.Dark, { material = METAL })
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		p(model, "StaveSeam", Vector3.new(0.035 * s, 1.85 * s, 0.035 * s),
			cf * CFrame.new(math.sin(angle) * 0.94 * s, 1.1 * s, math.cos(angle) * 0.94 * s),
			C.Timber, WOOD)
	end
	p(model, "LidCrossbar", Vector3.new(1.5 * s, 0.1 * s, 0.18 * s), cf * CFrame.new(0, 2.24 * s, 0), C.Timber)
	return model
end

local function crate(parent, cf, size)
	local model = Kit.model(parent, "SlattedCrate")
	p(model, "CrateBody", size, cf * CFrame.new(0, size.Y / 2, 0), C.Wood)
	for _, side in { -1, 1 } do
		for _, y in { 0.18, size.Y - 0.18 } do
			p(model, "Binding", Vector3.new(size.X + 0.1, 0.16, 0.12), cf * CFrame.new(0, y, side * size.Z / 2), C.Plank)
		end
		p(model, "CornerBinding", Vector3.new(0.13, size.Y, size.Z + 0.12), cf * CFrame.new(side * (size.X / 2 - 0.13), size.Y / 2, 0), C.Plank)
	end
	local diagonal = math.atan2(size.Y, size.X)
	p(model, "DiagonalBrace", Vector3.new(math.sqrt(size.X ^ 2 + size.Y ^ 2) - 0.1, 0.2, 0.14),
		cf * CFrame.new(0, size.Y / 2, -size.Z / 2 - 0.08) * CFrame.Angles(0, 0, diagonal), C.Timber)
	return model
end

local function ropeCoil(parent, cf, radius)
	for ring = 0, 1 do
		local r = radius - ring * 0.17
		for i = 0, 9 do
			local a = i * math.pi / 5
			local b = (i + 1) * math.pi / 5
			localBeam(parent, cf, "CoiledMooringRope",
				Vector3.new(math.sin(a) * r, 0.12 + ring * 0.07, math.cos(a) * r),
				Vector3.new(math.sin(b) * r, 0.12 + ring * 0.07, math.cos(b) * r), 0.12, C.Rope)
		end
	end
end

local function window(parent, cf, width, height, shutters)
	p(parent, "RecessedWindow", Vector3.new(width, height, 0.1), cf, C.Dark)
	Kit.part(parent, "WindowGlass", Vector3.new(width - 0.3, height - 0.3, 0.11), cf * CFrame.new(0, 0, -0.08), C.Glass,
		{ material = Enum.Material.Glass, transparency = 0.22, reflectance = 0.15 })
	for _, side in { -1, 1 } do
		p(parent, "WindowJamb", Vector3.new(0.16, height + 0.25, 0.24), cf * CFrame.new(side * width / 2, 0, -0.08), C.Cream)
		p(parent, "WindowLintel", Vector3.new(width + 0.3, 0.16, 0.24), cf * CFrame.new(0, side * height / 2, -0.08), C.Cream)
		if shutters then
			p(parent, "PaintedShutter", Vector3.new(width * 0.26, height, 0.14), cf * CFrame.new(side * width * 0.7, 0, -0.02), C.Roof, PLANKS)
			p(parent, "ShutterHinge", Vector3.new(width * 0.26, 0.12, 0.12), cf * CFrame.new(side * width * 0.7, -height * 0.29, -0.12), C.Dark, METAL)
		end
	end
	p(parent, "WindowMullion", Vector3.new(0.1, height, 0.2), cf * CFrame.new(0, 0, -0.15), C.Cream)
	p(parent, "WindowTransom", Vector3.new(width, 0.1, 0.2), cf * CFrame.new(0, 0.05, -0.15), C.Cream)
	p(parent, "DeepWindowSill", Vector3.new(width + 0.65, 0.2, 0.65), cf * CFrame.new(0, -height / 2 - 0.08, -0.2), C.Timber)
end

local function flowerBox(parent, cf, width, tint)
	p(parent, "WindowFlowerBox", Vector3.new(width, 0.65, 0.7), cf, C.Wood, PLANKS)
	p(parent, "Soil", Vector3.new(width - 0.16, 0.08, 0.54), cf * CFrame.new(0, 0.32, 0), C.Timber, Enum.Material.Ground)
	for i = 1, 4 do
		local x = (i - 2.5) * width / 4
		localBall(parent, cf, "TrailingLeaf", Vector3.new(0.65, 0.55, 0.65), Vector3.new(x, 0.5, -0.05), C.Moss, Enum.Material.Grass)
		localBall(parent, cf, "WindowBlossom", Vector3.new(0.36, 0.27, 0.36), Vector3.new(x + 0.05, 0.8, -0.12), tint, Enum.Material.SmoothPlastic)
	end
end

function Architecture.cottage(parent, cf, width, depth, tint, kind)
	local buildingKind = kind or "Cottage"
	local model = Kit.model(parent, buildingKind .. "House")
	local w, d = math.max(width, 16), math.max(depth, 12)
	local h = 9.2
	local half, front = w / 2, -d / 2
	local roofColor = buildingKind == "Workshop" and C.Roof
		or (buildingKind == "Cafe" and C.Coral or C.Sky)
	-- Painted plaster, honey-colored wood and clear shop colors stay legible in
	-- daylight. Each shop reads as a place to visit from both harbor approaches.
	tint = buildingKind == "Workshop" and Color3.fromRGB(227, 250, 228)
		or (buildingKind == "Cafe" and Color3.fromRGB(255, 228, 204)
		or tint:Lerp(Color3.fromRGB(255, 249, 219), 0.72))
	-- Stone footings, an open doorway and a real timber floor make the porch explorable.
	p(model, "RaisedTimberFloor", Vector3.new(w, 0.4, d), cf * CFrame.new(0, 0, 0), C.Plank, PLANKS, true)
	p(model, "RearWall", Vector3.new(w, h, 0.5), cf * CFrame.new(0, h / 2, d / 2), tint, Enum.Material.Plaster, true)
	for _, side in { -1, 1 } do
		p(model, "SideWall", Vector3.new(0.5, h, d), cf * CFrame.new(side * half, h / 2, 0), tint, Enum.Material.Plaster, true)
		local bay = (w - 3.8) / 2
		p(model, "FrontWallBay", Vector3.new(bay, h, 0.5), cf * CFrame.new(side * (1.9 + bay / 2), h / 2, front), tint, Enum.Material.Plaster, true)
		p(model, "DoorJamb", Vector3.new(0.24, 7.2, 0.7), cf * CFrame.new(side * 1.94, 3.6, front - 0.12), C.Timber)
		for _, z in { front, d / 2 } do
			p(model, "ExposedCornerTimber", Vector3.new(0.34, h + 0.1, 0.65), cf * CFrame.new(side * (half - 0.1), h / 2, z), C.Timber)
		end
		p(model, "FoundationStones", Vector3.new(1.5, 0.9, d + 0.5), cf * CFrame.new(side * (half - 0.7), -0.45, 0), C.Stone, STONE)
		p(model, "LowerWallTimber", Vector3.new(0.28, 0.3, d), cf * CFrame.new(side * (half + 0.15), 0.8, 0), C.Cream)
		p(model, "PaintedSideWainscot", Vector3.new(0.09, 2.05, d - 0.8), cf * CFrame.new(side * (half + 0.29), 1.85, 0), roofColor, PLANKS)
		window(model, cf * CFrame.new(side * w * 0.3, 4.8, front - 0.31), math.min(3.2, w * 0.16), 3.3, true)
		flowerBox(model, cf * CFrame.new(side * w * 0.3, 2.65, front - 0.72), math.min(3.7, w * 0.18),
			buildingKind == "Cafe" and C.Gold or C.Coral)
		window(model, cf * CFrame.new(side * (half + 0.31), 4.8, d * 0.12) * CFrame.Angles(0, -side * math.pi / 2, 0),
			math.min(5.5, d * 0.25), 3.3, buildingKind == "Workshop" or buildingKind == "Cafe")
	end
	-- The spawn path first sees these back walls. A broad shuttered window and
	-- layered paint replace the former blank rectangle without closing a route.
	local rear = d / 2 + 0.32
	p(model, "PaintedRearWainscot", Vector3.new(w - 0.7, 2.05, 0.09), cf * CFrame.new(0, 1.85, rear), roofColor, PLANKS)
	p(model, "RearWainscotCap", Vector3.new(w - 0.6, 0.18, 0.23), cf * CFrame.new(0, 2.95, rear + 0.04), C.Cream)
	window(model, cf * CFrame.new(0, 5.45, rear) * CFrame.Angles(0, math.pi, 0), w * 0.37, 3.25, true)
	p(model, "DoorLintel", Vector3.new(4.2, 0.3, 0.7), cf * CFrame.new(0, 7.15, front - 0.12), C.Timber)
	p(model, "DoorwayHeadWall", Vector3.new(3.8, h - 7.25, 0.5), cf * CFrame.new(0, (h + 7.25) / 2, front), tint, Enum.Material.Plaster, true)
	-- Layered slate tiles follow the real roof slope, catching light on every row.
	local overhang, rise = 1.25, 4.3
	local roofHalf = half + overhang
	local pitch = math.atan2(rise, roofHalf)
	local slope = math.sqrt(roofHalf ^ 2 + rise ^ 2)
	local roofDepth = d + 2.6
	local cols = math.max(4, math.floor(roofDepth / 2.5))
	for _, side in { -1, 1 } do
		local roofCf = cf * CFrame.new(side * roofHalf / 2, h + rise / 2, 0) * CFrame.Angles(0, 0, -side * pitch)
		p(model, "RoofUnderlay", Vector3.new(slope + 0.2, 0.35, roofDepth), roofCf, roofColor, STONE, true)
		for row = 0, 3 do
			for col = 0, cols - 1 do
				local shift = (row % 2 == 1 and 0.12 or -0.12)
				local tileCf = roofCf * CFrame.new(-slope / 2 + (row + 0.5) * slope / 4, 0.24 + row * 0.008,
					-roofDepth / 2 + (col + 0.5) * roofDepth / cols + shift)
				local shade = ((row * 7 + col * 3) % 5) * 0.025
				p(model, "IndividualSlateShingle", Vector3.new(slope / 4 + 0.12, 0.12, roofDepth / cols - 0.09), tileCf,
					roofColor:Lerp(C.Cream, shade), STONE)
			end
		end
		for _, z in { -roofDepth / 2, roofDepth / 2 } do
			localBeam(model, cf, "CarvedGableTrim", Vector3.new(side * roofHalf, h, z), Vector3.new(0, h + rise, z), 0.27, C.Cream)
		end
		p(model, "EaveTimber", Vector3.new(0.24, 0.28, roofDepth + 0.3), cf * CFrame.new(side * roofHalf, h, 0), C.Timber)
	end
	p(model, "RidgeCap", Vector3.new(0.48, 0.35, roofDepth + 0.2), cf * CFrame.new(0, h + rise + 0.13, 0), C.Dark, METAL)
	-- Stepped plaster infill stays under the sloping roof; exposed framing gives
	-- the attic real depth without closing the entrance below it.
	for _, z in { -d / 2 - 0.08, d / 2 + 0.08 } do
		for i = -5, 5 do
			local x = i * w / 11
			local panelHeight = rise * (1 - (math.abs(x) + w / 22) / roofHalf)
			p(model, "GablePlasterInfill", Vector3.new(w / 11 + 0.02, panelHeight, 0.18), cf * CFrame.new(x, h + panelHeight / 2, z), tint, Enum.Material.Plaster)
		end
		for i = -3, 3 do
			local x = i * half / 4
			local beamHeight = rise * (1 - math.abs(x) / roofHalf)
			p(model, "GableLattice", Vector3.new(0.19, beamHeight, 0.2), cf * CFrame.new(x, h + beamHeight / 2, z), C.Timber)
		end
		p(model, "GableCrossbeam", Vector3.new(w + 0.5, 0.26, 0.4), cf * CFrame.new(0, h, z), C.Timber)
		local outside = z < 0 and -0.2 or 0.2
		local ring = Kit.disk(model, "RoundAtticWindowFrame", 2.1, 2.1, 0.2, (cf * CFrame.new(0, h + 1.75, z + outside)).Position, C.Cream, { material = WOOD })
		ring.CFrame = cf * CFrame.new(0, h + 1.75, z + outside) * CFrame.Angles(0, math.pi / 2, 0)
		local glass = Kit.disk(model, "RoundAtticWindow", 1.65, 1.65, 0.22, ring.Position, C.Glass, { material = Enum.Material.Glass, reflectance = 0.1 })
		glass.CFrame = ring.CFrame
	end
	-- The sheltered porch is a visual landmark and a usable place to stand.
	local porchZ = front - 2.5
	p(model, "PorchFloor", Vector3.new(w + 1.4, 0.35, 5), cf * CFrame.new(0, -0.025, porchZ), C.Plank, PLANKS, true)
	p(model, "PorchFrontRiser", Vector3.new(w + 1.4, 0.65, 0.3), cf * CFrame.new(0, -0.3, front - 5), C.Timber)
	for _, side in { -1, 1 } do
		p(model, "PorchPost", Vector3.new(0.38, 7.3, 0.38), cf * CFrame.new(side * half, 3.5, front - 4.5), C.Timber)
		localBeam(model, cf, "PorchKneeBrace", Vector3.new(side * half, 5.6, front - 4.5), Vector3.new(side * (half - 1.4), 7, front - 4.5), 0.23, C.Cream)
		localBeam(model, cf, "PorchKneeBrace", Vector3.new(side * half, 5.6, front - 4.5), Vector3.new(side * half, 7, front - 3.1), 0.23, C.Cream)
	end
	local canopyCf = cf * CFrame.new(0, 7.5, front - 2.6) * CFrame.Angles(math.rad(7), 0, 0)
	p(model, "PorchCanopy", Vector3.new(w + 2, 0.27, 5.4), canopyCf, C.Cream, Enum.Material.Fabric)
	for stripe = 0, 2 do
		p(model, "PaintedCanvasStripe", Vector3.new((w + 2) / 6, 0.03, 5.39),
			canopyCf * CFrame.new(-(w + 2) / 2 + (stripe * 2 + 0.5) * (w + 2) / 6, 0.15, 0), roofColor, Enum.Material.Fabric)
	end
	p(model, "PorchFascia", Vector3.new(w + 2, 0.35, 0.26), cf * CFrame.new(0, 7.1, front - 5.2), roofColor)
	local label = buildingKind == "Workshop" and "THE ROD WORKSHOP" or (buildingKind == "Cafe" and "THE TIDE TABLE" or "HARBOR COTTAGE")
	local subtitle = buildingKind == "Workshop" and "A better rod. A bigger adventure." or (buildingKind == "Cafe" and "Fresh bakes. Good company." or "A little home above the clouds")
	local sign = p(model, "PaintedShopSign", Vector3.new(math.min(11, w - 3), 1.55, 0.22), cf * CFrame.new(0, 6.45, front - 5.28), roofColor)
	Kit.sign(sign, label, subtitle, C.Cream)
	Kit.lantern(model, cf:PointToWorldSpace(Vector3.new(half - 0.8, 5.4, front - 4.5)), 0.7, false)
	-- A quiet interior, visible through the open door, rewards looking around.
	p(model, "WovenInteriorRug", Vector3.new(w * 0.53, 0.035, d * 0.55), cf * CFrame.new(0, 0.23, 0), roofColor:Lerp(C.Cream, 0.22), Enum.Material.Fabric)
	p(model, "RearDisplayShelf", Vector3.new(w - 3, 0.22, 1.2), cf * CFrame.new(0, 4.6, d / 2 - 0.8), C.Timber)
	p(model, "BackCounter", Vector3.new(w - 4, 2.8, 1.7), cf * CFrame.new(0, 1.6, d / 2 - 1.25), tint:Lerp(C.Timber, 0.3), PLANKS, true)
	p(model, "CounterTop", Vector3.new(w - 3.5, 0.2, 2.1), cf * CFrame.new(0, 3.1, d / 2 - 1.25), C.Plank)
	for i = -1, 1 do
		local x = i * (w - 4) / 3
		localBall(model, cf, "GlazedStoragePot", Vector3.new(0.85, 0.95, 0.85), Vector3.new(x, 5.15, d / 2 - 0.8),
			i == 0 and C.Gold or C.Roof, Enum.Material.CeramicTiles)
	end
	local rearCf = cf * CFrame.new(0, 0, rear) * CFrame.Angles(0, math.pi, 0)
	if buildingKind == "Cafe" then
		-- A small take-away hatch faces the arrival path. Cups and fresh bakes
		-- tell a story at walking distance rather than relying on floating text.
		p(model, "CafeServingCounter", Vector3.new(10.7, 2.65, 1.35), rearCf * CFrame.new(0, 1.7, -1.05), C.Coral, PLANKS)
		p(model, "CreamCounterMoulding", Vector3.new(10.9, 0.18, 1.45), rearCf * CFrame.new(0, 2.65, -1.05), C.Cream)
		p(model, "CafeHatchCountertop", Vector3.new(11.3, 0.2, 1.8), rearCf * CFrame.new(0, 3.15, -1.15), C.Plank)
		local hatchCanopy = rearCf * CFrame.new(0, 7.65, -1.25) * CFrame.Angles(math.rad(8), 0, 0)
		p(model, "CafeHatchCanvas", Vector3.new(12, 0.12, 3), hatchCanopy, C.Cream, Enum.Material.Fabric)
		for stripe = 0, 2 do
			p(model, "CafeHatchStripe", Vector3.new(2, 0.025, 2.99), hatchCanopy * CFrame.new(-5 + stripe * 4, 0.075, 0), C.Coral, Enum.Material.Fabric)
		end
		for _, side in { -1, 1 } do
			localBeam(model, rearCf, "HatchCanopyBracket", Vector3.new(side * 5.4, 6.3, -0.2), Vector3.new(side * 5.4, 7.35, -2.45), 0.12, C.Gold, METAL)
			local cupCf = rearCf * CFrame.new(side * 2.8, 3.53, -1.15)
			Kit.disk(model, "CafeCup", 0.57, 0.57, 0.57, cupCf.Position, side == -1 and C.Roof or C.Cream, { material = Enum.Material.SmoothPlastic })
			Kit.disk(model, "FreshCoffee", 0.45, 0.45, 0.025, (cupCf * CFrame.new(0, 0.29, 0)).Position, C.Timber, { material = Enum.Material.SmoothPlastic })
		end
		Kit.disk(model, "BakeryServingPlate", 2.1, 1.2, 0.065, (rearCf * CFrame.new(0, 3.3, -1.15)).Position, C.Cream, { material = Enum.Material.SmoothPlastic })
		for i = -1, 1 do
			localBall(model, rearCf, "GoldenBakedRoll", Vector3.new(0.62, 0.35, 0.78), Vector3.new(i * 0.57, 3.49, -1.15), C.Gold, Enum.Material.SmoothPlastic)
		end
	elseif buildingKind == "Workshop" then
		-- The fish silhouette and full-size rods read from the spawn route even
		-- when the shop's front porch is on the far side of the building.
		local emblemCf = rearCf * CFrame.new(-w * 0.34, 5.2, -0.17)
		p(model, "WorkshopFishPlaque", Vector3.new(3.9, 2.65, 0.25), emblemCf, C.Roof)
		localBall(model, emblemCf, "WorkshopGoldenFish", Vector3.new(2.1, 1.12, 0.18), Vector3.new(-0.15, 0, -0.2), C.Gold, Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			p(model, "FishTailEmblem", Vector3.new(0.9, 0.38, 0.16), emblemCf * CFrame.new(1.04, side * 0.21, -0.2) * CFrame.Angles(0, 0, side * math.rad(32)), C.Gold, Enum.Material.SmoothPlastic)
		end
		localBall(model, emblemCf, "FishEmblemEye", Vector3.new(0.19, 0.19, 0.08), Vector3.new(-0.68, 0.14, -0.32), C.Dark, Enum.Material.SmoothPlastic)
		for _, y in { 1.8, 5.6 } do
			p(model, "OutdoorRodRack", Vector3.new(3.3, 0.24, 0.5), rearCf * CFrame.new(w * 0.34, y, -0.4), C.Cream)
		end
		for i = -1, 1 do
			local x = w * 0.34 + i * 0.82
			localBeam(model, rearCf, "DisplayFishingRod", Vector3.new(x, 0.7, -0.71), Vector3.new(x + 0.16, 6.5, -0.71), 0.11, i == 0 and C.Gold or C.Roof)
			local reel = Kit.disk(model, "DisplayRodReel", 0.48, 0.48, 0.17, (rearCf * CFrame.new(x, 1.65, -0.9)).Position, C.Gold, { material = METAL })
			reel.CFrame = rearCf * CFrame.new(x, 1.65, -0.9) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end
	if buildingKind == "Workshop" then
		local trigger = p(model, "WorkshopJournalStand", Vector3.new(2.3, 2.5, 1.1), cf * CFrame.new(half - 3, 1.4, front - 2.6), C.Roof, PLANKS, true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RodWorkshopPrompt"
		prompt.ActionText = "Open journal"
		prompt.ObjectText = "Rod Workshop"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = trigger
		for i = 0, 3 do
			local x = -half + 2 + i * 0.72
			localBeam(model, cf, "WorkshopRod", Vector3.new(x, 0.4, d / 2 - 2), Vector3.new(x + 0.3, 6.5, d / 2 - 2), 0.09, i % 2 == 0 and C.Gold or C.Dark)
		end
	else
		p(model, "PorchBenchSeat", Vector3.new(4, 0.24, 1.3), cf * CFrame.new(-half + 3.1, 1.4, porchZ), C.Plank, WOOD, true)
		p(model, "PorchBenchBack", Vector3.new(4, 1.3, 0.18), cf * CFrame.new(-half + 3.1, 2.1, porchZ + 0.55), C.Timber)
		for _, x in { -half + 1.8, -half + 4.4 } do
			p(model, "BenchLeg", Vector3.new(0.3, 1.4, 1.1), cf * CFrame.new(x, 0.65, porchZ), C.Timber)
		end
	end
	local chimneyCf = cf * CFrame.new(half * 0.52, h + 3.1, d * 0.23)
	p(model, "ChimneyStack", Vector3.new(1.4, 4, 1.5), chimneyCf, C.Coral:Lerp(C.Cream, 0.16), Enum.Material.Brick)
	p(model, "ChimneyCap", Vector3.new(1.8, 0.28, 1.9), chimneyCf * CFrame.new(0, 2, 0), C.Stone, STONE)
	p(model, "ChimneyOpening", Vector3.new(0.9, 0.03, 1), chimneyCf * CFrame.new(0, 2.15, 0), C.Dark, STONE)
	return model
end

function Architecture.dock(parent, a, b, width, name, rails)
	local model = Kit.model(parent, name or "HarborBoardwalk")
	local length = (b - a).Magnitude
	if length < 0.1 then return model end
	local basis = CFrame.lookAt((a + b) / 2, b)
	local up = basis.UpVector
	-- One uninterrupted collider keeps small gaps between visible planks harmless.
	local floor = p(model, "ContinuousWalkSurface", Vector3.new(width, 0.42, length), basis - up * 0.21, C.Timber, WOOD, true)
	floor.Transparency = 1
	local count = math.min(48, math.max(2, math.ceil(length / 2.25)))
	for i = 0, count - 1 do
		local plankCf = basis * CFrame.new(0, -0.02, -length / 2 + (i + 0.5) * length / count)
		p(model, "WeatheredDeckPlank", Vector3.new(width, 0.16, length / count - 0.045), plankCf,
			C.Plank:Lerp(C.Timber, (i % 4) * 0.055), WOOD)
		if i % 4 == 0 then
			for _, side in { -1, 1 } do
				p(model, "IronDeckNail", Vector3.new(0.08, 0.018, 0.08), plankCf * CFrame.new(side * (width / 2 - 0.4), 0.09, 0), C.Dark, METAL)
			end
		end
	end
	for _, side in { -1, 1 } do
		p(model, "LongitudinalStringer", Vector3.new(0.55, 0.9, length + 0.6), basis * CFrame.new(side * (width / 2 - 0.8), -0.75, 0), C.Timber)
	end
	local bays = math.min(4, math.max(1, math.ceil(length / 17)))
	for i = 0, bays do
		local z = -length / 2 + i * length / bays
		for _, side in { -1, 1 } do
			local postCf = basis * CFrame.new(side * (width / 2 - 0.25), 0, z)
			if i % 2 == 0 or i == bays then
				p(model, "DeepTimberPile", Vector3.new(0.8, 7, 0.8), postCf * CFrame.new(0, -3.5, 0), C.Timber)
				p(model, "PileWaterlineBand", Vector3.new(0.83, 0.35, 0.83), postCf * CFrame.new(0, -2.7, 0), C.Dark, METAL)
			end
			if rails ~= false then
				p(model, "RopeRailPost", Vector3.new(0.45, 3.5, 0.45), postCf * CFrame.new(0, 1.7, 0), C.Timber, WOOD, true)
				p(model, "PostCap", Vector3.new(0.6, 0.16, 0.6), postCf * CFrame.new(0, 3.5, 0), C.Plank)
			end
		end
		if i < bays and rails ~= false then
			for _, side in { -1, 1 } do
				local x = side * (width / 2 - 0.25)
				local nextZ = z + length / bays
				for _, h in { 1.4, 3.1 } do
					local start = Vector3.new(x, h, z)
					local middle = Vector3.new(x, h - 0.3, (z + nextZ) / 2)
					local finish = Vector3.new(x, h, nextZ)
					localBeam(model, basis, "SaggingHempRail", start, middle, 0.14, C.Rope)
					localBeam(model, basis, "SaggingHempRail", middle, finish, 0.14, C.Rope)
				end
				p(model, "SafeRailCollider", Vector3.new(0.12, 2.5, length / bays), basis * CFrame.new(x, 1.75, (z + nextZ) / 2), C.Timber, WOOD, true).Transparency = 1
			end
		end
	end
	if length >= 25 then
		Kit.lantern(model, (basis * CFrame.new(width / 2 - 0.25, 3.9, -length * 0.28)).Position, 0.65, false)
	end
	return model
end

function Architecture.lighthouse(parent, cf)
	local model = Kit.model(parent, "WayfarerLighthouse")
	local n, r = 12, 6
	local tangentWidth = 2 * r * math.tan(math.pi / n) + 0.04
	Kit.disk(model, "OctagonalFoundation", 16, 16, 0.7, cf:PointToWorldSpace(Vector3.new(0, -0.35, 0)), C.Stone, { material = STONE, collidable = true })
	for i = 0, n - 1 do
		local angle = i * math.pi * 2 / n
		local face = cf * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, -r)
		if i == 0 then
			p(model, "DoorwayUpperWall", Vector3.new(tangentWidth, 17.4, 0.6), face * CFrame.new(0, 16.7, 0), C.Cream, Enum.Material.Plaster, true)
		elseif i == 3 or i == 9 then
			p(model, "WindowLowerWall", Vector3.new(tangentWidth, 11, 0.6), face * CFrame.new(0, 5.5, 0), C.Cream, Enum.Material.Plaster, true)
			p(model, "WindowUpperWall", Vector3.new(tangentWidth, 10.9, 0.6), face * CFrame.new(0, 19.95, 0), C.Cream, Enum.Material.Plaster, true)
			window(model, face * CFrame.new(0, 12.75, -0.32), tangentWidth - 0.3, 3.5, false)
		else
			p(model, "LimewashedTowerWall", Vector3.new(tangentWidth, 25.4, 0.6), face * CFrame.new(0, 12.7, 0), C.Cream, Enum.Material.Plaster, true)
		end
		-- Painted banding and footings make the silhouette readable from other islands.
		if i ~= 0 then
			p(model, "TowerStoneFooting", Vector3.new(tangentWidth + 0.12, 1.2, 0.82), face * CFrame.new(0, 0.6, 0), C.Stone, STONE, true)
		end
		for _, y in { 9.3, 23.7 } do
			p(model, "MarinerBlueBand", Vector3.new(tangentWidth + 0.12, 1, 0.76), face * CFrame.new(0, y, -0.08), C.Roof, Enum.Material.Plaster)
		end
	end
	-- 7.8 studs of rise per revolution leave enough headroom for a standard R15
	-- avatar. The final 26.65-stud tread meets the 27-stud lookout deck.
	for i = 0, 40 do
		local angle = i * math.pi / 6
		local stepCf = cf * CFrame.Angles(0, -angle, 0) * CFrame.new(0, i * 0.65 + 0.325, -3.05)
		p(model, "SpiralStairTread", Vector3.new(2.2, 0.65, 3.6), stepCf, C.Plank, WOOD, true)
		if i % 3 == 0 then
			p(model, "InnerStairBaluster", Vector3.new(0.12, 2.7, 0.12), stepCf * CFrame.new(0, 1.6, 1.68), C.Dark, METAL)
		end
	end
	p(model, "CentralStairMast", Vector3.new(0.65, 29, 0.65), cf * CFrame.new(0, 14.5, 0), C.Timber)
	for i = 0, n - 1 do
		local angle = i * math.pi * 2 / n
		local ring = cf * CFrame.Angles(0, -angle, 0)
		p(model, "AccessibleLookoutBalcony", Vector3.new(4.2, 0.45, 3), ring * CFrame.new(0, 26.775, -6.2), C.Stone, STONE, true)
		p(model, "LookoutRailingPost", Vector3.new(0.16, 3.2, 0.16), ring * CFrame.new(0, 28.6, -7.55), C.Dark, METAL)
		local barrier = p(model, "LookoutRailingCollider", Vector3.new(4.2, 2.8, 0.15), ring * CFrame.new(0, 28.4, -7.55), C.Dark, METAL, true)
		barrier.Transparency = 1
		local a = Vector3.new(math.sin(angle) * 7.55, 30.15, -math.cos(angle) * 7.55)
		local nextAngle = angle + math.pi * 2 / n
		local b = Vector3.new(math.sin(nextAngle) * 7.55, 30.15, -math.cos(nextAngle) * 7.55)
		localBeam(model, cf, "ContinuousBalconyHandrail", a, b, 0.15, C.Dark, METAL)
		localBeam(model, cf, "BalconyLowerRail", a - Vector3.new(0, 1.5, 0), b - Vector3.new(0, 1.5, 0), 0.1, C.Dark, METAL)
		if i ~= 0 then
			Kit.part(model, "LanternRoomGlazing", Vector3.new(2.4, 5.8, 0.12), ring * CFrame.new(0, 31.6, -4.45), C.Glass,
				{ material = Enum.Material.Glass, transparency = 0.58, reflectance = 0.1 })
		end
		p(model, "LanternRoomUpright", Vector3.new(0.14, 6.3, 0.14), ring * CFrame.new(0, 31.6, -4.5), C.Dark, METAL)
		localBeam(model, cf, "CopperDomeRib", Vector3.new(math.sin(angle) * 5.3, 34.5, -math.cos(angle) * 5.3), Vector3.new(0, 37.7, 0), 0.14, C.Dark, METAL)
	end
	Kit.disk(model, "LanternRoomCornice", 10.5, 10.5, 0.36, cf:PointToWorldSpace(Vector3.new(0, 34.5, 0)), C.Dark, { material = METAL })
	localBall(model, cf, "VerdigrisDome", Vector3.new(10.4, 5.1, 10.4), Vector3.new(0, 35.3, 0), C.Roof, METAL)
	localBall(model, cf, "LighthouseLens", Vector3.new(2.6, 3.4, 2.6), Vector3.new(0, 31.4, 0), C.Gold, Enum.Material.Neon)
	local lampMount = p(model, "LensPedestal", Vector3.new(1.1, 1.8, 1.1), cf * CFrame.new(0, 28.7, 0), C.Dark, METAL)
	local light = Instance.new("PointLight")
	light.Name = "WarmNavigationLight"
	light.Color = Color3.fromRGB(255, 220, 158)
	light.Brightness = 1.5
	light.Range = 32
	light.Shadows = false
	light.Parent = lampMount
	p(model, "WeatherVaneMast", Vector3.new(0.14, 3.8, 0.14), cf * CFrame.new(0, 39, 0), C.Dark, METAL)
	p(model, "WeatherVaneArrow", Vector3.new(3.2, 0.16, 0.16), cf * CFrame.new(0, 40, 0), C.Gold, METAL)
	Kit.wedge(model, "WeatherVanePennant", Vector3.new(0.08, 0.9, 1.5), cf * CFrame.new(1.2, 39.8, 0) * CFrame.Angles(0, math.pi / 2, 0), C.Gold, { material = METAL })
	local sign = p(model, "LighthousePlaque", Vector3.new(4.2, 1, 0.15), cf * CFrame.new(0, 7.4, -6.4), C.Dark)
	Kit.sign(sign, "WAYFARER LIGHT", "Climb to the harbor lookout", C.Cream)
	return model
end

function Architecture.ruins(parent, cf)
	local model = Kit.model(parent, "OldCloudObservatory")
	Kit.disk(model, "WeatheredObservatoryFloor", 29, 25, 0.45, cf:PointToWorldSpace(Vector3.new(0, -0.165, 0)), C.Stone,
		{ material = Enum.Material.Limestone, collidable = true })
	for _, side in { -1, 1 } do
		local x = side * 6.4
		p(model, "ColumnPedestal", Vector3.new(3.5, 0.8, 3.5), cf * CFrame.new(x, 0.4, -1), C.Stone, Enum.Material.Limestone, true)
		for segment = 0, 2 do
			Kit.disk(model, "AgedColumnDrum", 2.45 - segment * 0.08, 2.45 - segment * 0.08, 2.2,
				cf:PointToWorldSpace(Vector3.new(x + (segment == 1 and side * 0.08 or 0), 1.9 + segment * 2.2, -1)), C.Stone:Lerp(C.Cream, segment * 0.04),
				{ material = Enum.Material.Limestone, collidable = true })
		end
		p(model, "ColumnCapital", Vector3.new(3, 0.55, 3), cf * CFrame.new(x, 7.55, -1), C.Stone, Enum.Material.Limestone)
		localBall(model, cf, "MossOnCapital", Vector3.new(2.2, 0.15, 1.4), Vector3.new(x, 7.87, -1.4), C.Moss, Enum.Material.Grass)
	end
	for i = 0, 10 do
		local angle = (i + 0.5) / 11 * math.pi
		local center = Vector3.new(math.cos(angle) * 6.4, 7.5 + math.sin(angle) * 6.4, -1)
		p(model, "RadialArchVoussoir", Vector3.new(2.03, 2.2, 2.6), cf * CFrame.new(center) * CFrame.Angles(0, 0, angle - math.pi / 2),
			i == 5 and C.Cream or C.Stone, Enum.Material.Limestone, true)
	end
	p(model, "ArchKeystoneCarving", Vector3.new(0.6, 1.25, 0.1), cf * CFrame.new(0, 13.75, -2.36), C.Gold, METAL)
	-- A legible, original telescope silhouette points above the clouds.
	local pivot = Vector3.new(0, 4.3, 4.2)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		localBeam(model, cf, "BrassTelescopeTripod", Vector3.new(math.sin(a) * 2.5, 0.1, 4.2 + math.cos(a) * 2.5), pivot, 0.25, C.Timber)
	end
	local start, finish = Vector3.new(0, 3.6, 6.4), Vector3.new(0, 6.2, 0.6)
	localBeam(model, cf, "TelescopeBrassBody", start, finish, 1.1, C.Gold, METAL)
	local direction = (finish - start).Unit
	localBeam(model, cf, "TelescopeObjectiveRim", finish - direction * 0.15, finish + direction * 0.2, 1.45, C.Dark, METAL)
	localBeam(model, cf, "TelescopeBlueLens", finish + direction * 0.21, finish + direction * 0.24, 1.21, C.Glass, Enum.Material.Glass)
	localBeam(model, cf, "TelescopeEyepiece", start - direction * 0.55, start, 0.45, C.Dark, METAL)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		p(model, "BrokenMasonry", Vector3.new(1.8 + i % 2, 0.7 + (i % 3) * 0.35, 1.5),
			cf * CFrame.new(math.sin(angle) * 10.7, 0.5, 3 + math.cos(angle) * 7.6) * CFrame.Angles(0, angle, math.rad(5 * (i % 2))),
			C.Stone, Enum.Material.Limestone)
	end
	for _, side in { -1, 1 } do
		p(model, "ObservatoryBench", Vector3.new(5.5, 0.5, 1.6), cf * CFrame.new(side * 9, 1.4, 4), C.Stone, STONE, true)
		for _, z in { 2.9, 5.1 } do
			p(model, "BenchStoneLeg", Vector3.new(1.2, 1.3, 0.8), cf * CFrame.new(side * 9, 0.65, z), C.Stone, STONE)
		end
	end
	local sign = p(model, "ObservatoryPlaque", Vector3.new(5.4, 1.2, 0.2), cf * CFrame.new(-9.4, 2.2, -5.5) * CFrame.Angles(math.rad(12), 0, 0), C.Dark)
	Kit.sign(sign, "THE OLD OBSERVATORY", "A quiet place to watch the cloud tides", C.Cream)
	return model
end

function Architecture.props(parent, cf, kind)
	local model = Kit.model(parent, (kind or "Fishing") .. "Details")
	if kind == "Market" then
		p(model, "MarketCounter", Vector3.new(7.8, 2.7, 3.1), cf * CFrame.new(0, 1.35, 0), C.Wood, PLANKS, true)
		p(model, "CounterEdge", Vector3.new(8.2, 0.22, 3.5), cf * CFrame.new(0, 2.8, 0), C.Plank)
		for _, side in { -1, 1 } do
			p(model, "StallAwningPost", Vector3.new(0.3, 7.3, 0.3), cf * CFrame.new(side * 3.75, 3.65, 1.25), C.Timber)
			localBeam(model, cf, "AwningBrace", Vector3.new(side * 3.75, 5.2, 1.25), Vector3.new(side * 2.65, 6.9, 1.25), 0.18, C.Timber)
		end
		for i = 0, 7 do
			local color = i % 2 == 0 and C.Cream or C.Roof
			local awningCf = cf * CFrame.new(-3.5 + i, 6.7, -0.2) * CFrame.Angles(math.rad(9), 0, 0)
			p(model, "StripedCanvasAwning", Vector3.new(0.97, 0.14, 5.2), awningCf, color, Enum.Material.Fabric)
			p(model, "ScallopedAwningValance", Vector3.new(0.97, 0.5, 0.12), cf * CFrame.new(-3.5 + i, 6.06, -2.77), color, Enum.Material.Fabric)
		end
		for _, x in { -2.3, 0, 2.3 } do
			p(model, "ProduceTray", Vector3.new(1.9, 0.35, 2.2), cf * CFrame.new(x, 3.05, 0), C.Timber, PLANKS)
			for i = 0, 2 do
				localBall(model, cf, "SeaGlassFloat", Vector3.new(0.7, 0.6, 0.7), Vector3.new(x + (i - 1) * 0.5, 3.5, 0.1 * (i % 2)),
					i == 1 and C.Gold or C.Glass, Enum.Material.Glass)
			end
		end
		local sign = p(model, "MarketPaintedSign", Vector3.new(5.2, 1, 0.15), cf * CFrame.new(0, 1.6, -1.64), C.Dark)
		Kit.sign(sign, "HARBOR SUPPLIES", "Made for a slower afternoon", C.Cream)
		barrel(model, cf * CFrame.new(5.1, 0, 0.6), 0.9)
	elseif kind == "Picnic" then
		p(model, "PicnicTableTop", Vector3.new(5.4, 0.3, 3), cf * CFrame.new(0, 2.3, 0), C.Plank, PLANKS, true)
		for _, side in { -1, 1 } do
			p(model, "PicnicBench", Vector3.new(6, 0.22, 1.2), cf * CFrame.new(0, 1.25, side * 2.5), C.Plank, WOOD, true)
			for _, x in { -1.8, 1.8 } do
				p(model, "BenchSupport", Vector3.new(0.25, 1.25, 1), cf * CFrame.new(x, 0.6, side * 2.5), C.Timber)
			end
			p(model, "TableTrestle", Vector3.new(0.28, 2.2, 2.8), cf * CFrame.new(side * 1.8, 1.1, 0) * CFrame.Angles(0, 0, side * math.rad(9)), C.Timber)
		end
		Kit.disk(model, "PicnicPlate", 0.9, 0.9, 0.05, cf:PointToWorldSpace(Vector3.new(1.4, 2.5, 0.2)), C.Cream, { material = Enum.Material.SmoothPlastic })
		localBall(model, cf, "GlazedTeapot", Vector3.new(0.75, 0.65, 0.75), Vector3.new(-0.8, 2.77, 0), C.Roof, Enum.Material.SmoothPlastic)
		localBeam(model, cf, "TeapotSpout", Vector3.new(-0.5, 2.7, 0), Vector3.new(-0.2, 2.95, 0), 0.13, C.Roof)
		Kit.lantern(model, cf:PointToWorldSpace(Vector3.new(0, 2.65, 0)), 0.5, false)
	else
		crate(model, cf * CFrame.new(-1.5, 0, 0), Vector3.new(2.5, 1.9, 2.1))
		crate(model, cf * CFrame.new(-1.3, 1.94, 0.1) * CFrame.Angles(0, math.rad(12), 0), Vector3.new(2, 1.3, 1.7))
		barrel(model, cf * CFrame.new(1.6, 0, 0.6), 0.9)
		ropeCoil(model, cf * CFrame.new(0.7, 0, -1.6), 0.75)
		Kit.disk(model, "BaitPail", 1, 1, 1.15, cf:PointToWorldSpace(Vector3.new(2.9, 0.58, -1.1)), C.Dark, { material = METAL })
		Kit.disk(model, "PailOpenTop", 0.83, 0.83, 0.035, cf:PointToWorldSpace(Vector3.new(2.9, 1.16, -1.1)), C.Timber, { material = Enum.Material.Ground })
		localBeam(model, cf, "PailHandle", Vector3.new(2.42, 0.9, -1.1), Vector3.new(2.9, 1.8, -1.1), 0.065, C.Dark, METAL)
		localBeam(model, cf, "PailHandle", Vector3.new(2.9, 1.8, -1.1), Vector3.new(3.38, 0.9, -1.1), 0.065, C.Dark, METAL)
		localBeam(model, cf, "RestingFishingRod", Vector3.new(-2, 0.2, 1), Vector3.new(-0.7, 5.1, 1.1), 0.08, C.Gold)
	end
	return model
end

return Architecture
