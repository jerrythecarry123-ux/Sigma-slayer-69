--!strict
-- Authored planting and little everyday scenes, rather than scatter over walkways.
-- All scenery here is anchored, non-solid and excluded from camera/raycast queries.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Nature = require(script.Parent:WaitForChild("WorldNature"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local C = Kit.palette
local Landscaping = {}
local TAU = math.pi * 2
local foliage = { material = Enum.Material.SmoothPlastic }
local detail = { material = Enum.Material.Plastic, shadow = false }
local wood = { material = Enum.Material.Wood }
local cloth = { material = Enum.Material.Fabric, shadow = false }
local flowerTints = {
	C.Gold, C.Coral, C.Cream, C.Teal,
}

local function group(parent: Instance, name: string): Model
	local model = Kit.model(parent, name)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end
local function clearRoutes(zone: string, pos: Vector3, radius: number): boolean
	for _, route in Layout.Paths do
		if route.Island == zone then
			for i = 1, #route.Points - 1 do
				local a, b = route.Points[i], route.Points[i + 1]
				local dx, dz = b[1] - a[1], b[3] - a[3]
				local t = math.clamp(((pos.X - a[1]) * dx + (pos.Z - a[3]) * dz) / (dx * dx + dz * dz), 0, 1)
				if Vector2.new(pos.X - a[1] - dx * t, pos.Z - a[3] - dz * t).Magnitude < route.Width / 2 + radius + 1.25 then
					return false
				end
			end
		end
	end
	return true
end

local function flower(parent: Instance, pos: Vector3, height: number, tint: Color3, angle: number)
	local top = pos + Vector3.yAxis * height
	Kit.beam(parent, "FlowerStem", pos, top, .12, C.Moss, detail)
	Kit.wedge(parent, "PointedFlowerLeaf", Vector3.new(.08,.42,.95),
		CFrame.new(pos + Vector3.new(.3, height * .46, 0)) * CFrame.Angles(0,angle,math.pi/2), C.Leaf, detail)
	for petal=0,3 do
		local cf=CFrame.new(top)*CFrame.Angles(0,angle+petal*math.pi/2,0)*CFrame.new(0,0,-.38)
		Kit.wedge(parent,"SculptedFlowerPetal",Vector3.new(.65,.12,.85),cf,tint,detail)
	end
	Kit.disk(parent, "PollenHeart", .35, .35, .16, top+Vector3.yAxis*.12, C.Gold, detail)
end

local function planting(parent: Instance, pos: Vector3, scale: number, tint: Color3, seed: number): Model
	local model = group(parent, "FloweringIslandBorder")
	local random = Random.new(seed)
	-- A shallow planted patch belongs to the ground, rather than sitting on it
	-- as a stack of green disks. The flowers and their leaves provide the volume.
	Kit.disk(model, "TendedGardenSoil", 6.8*scale, 4.2*scale, .07*scale,
		pos+Vector3.yAxis*.04*scale, C.Bark:Lerp(C.Moss,.4), {shadow=false})
	for i = 0, 2 do
		local a = .35 + i * TAU / 3
		flower(model, pos + Vector3.new(math.cos(a) * 2.1, .065, math.sin(a) * 1.4) * scale,
			(1.75 + i * .22) * scale, tint:Lerp(C.Cream, i * .12), random:NextNumber(0, TAU))
	end
	return model
end

local function hedge(parent: Instance, center: Vector3, length: number, yaw: number, tint: Color3)
	local model = group(parent, "BrickGardenHedge")
	local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	for i = 0, 2 do
		local pos = cf:PointToWorldSpace(Vector3.new((i - 1) * length / 3, .95 + i % 2 * .2, 0))
		for _,side in {-1,1} do
			Kit.wedge(model, "TaperedGardenHedge", Vector3.new(length/3+.12,1.8,2),
				CFrame.new(pos)*CFrame.Angles(0,yaw,0)*CFrame.new(0,0,side*.75)*CFrame.Angles(0,if side==1 then math.pi else 0,0),
				C.Leaf:Lerp(C.Lime,i*.03), foliage)
		end
		if i ~= 1 then
			Kit.disk(model, "HedgeRosette", .75,.75,.13,pos+Vector3.new(0,1,-.85),tint,detail)
		end
	end
	return model
end

local function fern(parent: Instance, pos: Vector3, scale: number, yaw: number)
	for i = 0, 3 do
		local a = yaw + i * TAU / 4
		local tip = pos + Vector3.new(math.cos(a) * 2.5, .8 + i % 2 * .35, math.sin(a) * 2.5) * scale
		local frond = Kit.wedge(parent, "TaperedFernFrond", Vector3.new(.8, .18, 3.25) * scale,
			CFrame.lookAt((pos + tip) / 2, tip) * CFrame.Angles(.1, 0, 0), C.Leaf:Lerp(C.Lime, i % 3 * .12), detail)
		frond.CFrame *= CFrame.new(0, .3 * scale, 0)
	end
end

local function forestFloor(parent: Instance, pos: Vector3, seed: number)
	local model = group(parent, "FernAndToadstoolNook")
	local random = Random.new(seed)
	for i = 0, 1 do fern(model, pos + Vector3.new((i - .5) * 4, 0, 0), .9 + i * .15, random:NextNumber(0, TAU)) end
	for i = 1, 3 do
		local base = pos + Vector3.new(i - 2, 0, 2.7 + i % 2 * .6)
		local height = .6 + i * .18
		Kit.part(model, "IvoryMushroomStalk", Vector3.new(.26,height,.26), CFrame.new(base+Vector3.yAxis*height/2), C.Cream, detail)
		Kit.ball(model, "MushroomDome", Vector3.new(1.25, .48, 1.25), base + Vector3.yAxis * height,
			if i == 2 then flowerTints[1] else flowerTints[2], detail)
		Kit.part(model, "MushroomCapSpot", Vector3.new(.29, .05, .3), CFrame.new(base + Vector3.new(.2, height + .24, -.12)), C.Cream, detail)
	end
	return model
end

local function blossomDrift(parent: Instance, pos: Vector3, seed: number)
	local model = group(parent, "PetalwindFallenBlossoms")
	local random = Random.new(seed)
	for i = 1, 12 do
		local a = random:NextNumber(0, TAU)
		local radius = random:NextNumber(1.4, 6)
		local petal = Kit.wedge(model, "FallenBlossomPetal", Vector3.new(.55, .035, 1),
			CFrame.new(pos + Vector3.new(math.cos(a) * radius, .07, math.sin(a) * radius * .65)),
			C.Blossom:Lerp(C.BlossomLight, i % 3 * .3), detail)
		petal.CFrame *= CFrame.Angles(0, random:NextNumber(0, TAU), 0)
	end
	return model
end

local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, tint: Color3)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local back = bc.Unit
	local up = bc:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	Kit.wedge(parent, "StripedUmbrellaPanel", Vector3.new(.065, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a+b)/2, right, up, back), tint, cloth)
	Kit.wedge(parent, "StripedUmbrellaPanel", Vector3.new(.065, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a+c)/2, -right, up, -back), tint, cloth)
end

local function umbrella(parent: Instance, pos: Vector3, tint: Color3, yaw: number)
	local model = group(parent, "StripedParasolSeating")
	Kit.disk(model, "ParasolFoot", 2.2, 2.2, .22, pos + Vector3.yAxis * .11, C.Limestone, { material = Enum.Material.Limestone })
	Kit.beam(model, "ParasolMast", pos, pos + Vector3.yAxis * 8.3, .2, C.Cream, wood)
	local canvas=Kit.model(model,"BreezyParasolCanvas")
	local canvasOrigin=CFrame.new(pos+Vector3.yAxis*8.4)
	canvas.WorldPivot=canvasOrigin
	Kit.ball(canvas, "BrassParasolFinial", Vector3.one * .4, pos + Vector3.yAxis * 8.55, C.Brass)
	for i = 0, 7 do
		local a, b = yaw + i * TAU / 8, yaw + (i + 1) * TAU / 8
		local left = pos + Vector3.new(math.cos(a) * 6, 6.55, math.sin(a) * 6)
		local right = pos + Vector3.new(math.cos(b) * 6, 6.55, math.sin(b) * 6)
		triangle(canvas, pos + Vector3.yAxis * 8.4, left, right, if i % 2 == 0 then tint else C.Cream)
	end
	canvas:SetAttribute("SwayOrigin",canvasOrigin)
	canvas:SetAttribute("SwayAmplitude",.007)
	Kit.disk(model, "CafeRoundTable", 4.4, 4.4, .25, pos + Vector3.yAxis * 2.6, C.Plank, wood)
	Kit.beam(model, "CafeTableLeg", pos + Vector3.yAxis * .2, pos + Vector3.yAxis * 2.5, .5, C.Wood, wood)
	for _, x in {-3.8, 3.8} do
		local chair = pos + Vector3.new(x, 0, 0)
		Kit.disk(model, "RoundCafeStool", 2.2, 2.2, .3, chair + Vector3.yAxis * 1.65, tint, cloth)
		Kit.beam(model, "CafeStoolSupport", chair, chair + Vector3.yAxis * 1.6, .45, C.Wood, wood)
	end
	return model
end

local function produce(parent: Instance, cf: CFrame)
	local model = group(parent, "FreshHarborProduce")
	for crate = 0, 1 do
		local base = cf * CFrame.new(crate * 3.8, 0, 0)
		Kit.part(model, "ProduceCrateFloor", Vector3.new(3.4, .2, 3), base * CFrame.new(0, .2, 0), C.Plank, wood)
		for _, side in {-1, 1} do
			Kit.part(model, "SlattedCrateSide", Vector3.new(3.5, .9, .2), base * CFrame.new(0, .7, side * 1.45), C.Wood, wood)
			Kit.part(model, "CrateEnd", Vector3.new(.2, .9, 2.8), base * CFrame.new(side * 1.65, .7, 0), C.Plank, wood)
		end
		for fruit = 0, 5 do
			local pos = base:PointToWorldSpace(Vector3.new((fruit % 3 - 1) * .87, .85, (math.floor(fruit / 3) - .5) * 1.08))
			Kit.ball(model, if crate == 0 then "SunPear" else "CoralApple", Vector3.new(.83, if crate == 0 then 1.05 else .8, .83), pos,
				if crate == 0 then flowerTints[1] else flowerTints[2], detail)
		end
	end
	Kit.part(model, "FoldedMarketCloth", Vector3.new(2, .15, 1.5), cf * CFrame.new(-2.9, .2, .6) * CFrame.Angles(0, .2, 0), C.Teal, cloth)
	return model
end

local function skiff(parent: Instance)
	local model = group(parent, "SundriftPaintedSkiff")
	-- Seat the hull slightly into native water; the old origin held its entire
	-- bottom above the surface even at the low point of the gentle bob.
	local cf = CFrame.new(22, 7.65, 144) * CFrame.Angles(0, -.22, 0)
	model.WorldPivot=cf
	Kit.part(model, "SkiffFloor", Vector3.new(4.6, .4, 12), cf * CFrame.new(0, .65, 0), C.Plank, wood)
	for _, x in {-2.5, 2.5} do
		local side = if x < 0 then -1 else 1
		Kit.part(model, "PaintedHull", Vector3.new(.45, 1.8, 12), cf * CFrame.new(x, 1.1, 0) * CFrame.Angles(0, 0, side * .13), C.Teal, wood)
		Kit.part(model, "CreamGunwale", Vector3.new(.53, .18, 12.3), cf * CFrame.new(x + side * .12, 2, 0), C.Cream, wood)
		Kit.beam(model, "PointedBowSide", cf:PointToWorldSpace(Vector3.new(x, 1.1, -6)), cf:PointToWorldSpace(Vector3.new(0, 1.1, -8.4)), .55, C.Teal, wood)
		Kit.beam(model, "PointedBowRim", cf:PointToWorldSpace(Vector3.new(x, 2, -6)), cf:PointToWorldSpace(Vector3.new(0, 2, -8.4)), .21, C.Cream, wood)
	end
	-- Mirrored thin wedges form a horizontal triangle inside the pointed bow.
	-- An upright wedge left a ramp poking through the narrowing hull sides.
	for _, side in {-1, 1} do
		Kit.wedge(model, "BowFloor", Vector3.new(.12, 2.2, 2.5),
			cf * CFrame.new(side * 1.1, .8, -7.15) * CFrame.Angles(0, 0, -side * math.pi / 2), C.Wood, wood)
	end
	Kit.part(model, "Transom", Vector3.new(5.3, 1.8, .45), cf * CFrame.new(0, 1.1, 6), C.Teal, wood)
	for _, z in {-3.7, .7, 4} do Kit.part(model, "RowingBench", Vector3.new(4.7, .27, 1.25), cf * CFrame.new(0, 1.6, z), C.Plank, wood) end
	for _, side in {-1, 1} do
		local a = cf:PointToWorldSpace(Vector3.new(side * .7, 1.95, -2.3))
		local b = cf:PointToWorldSpace(Vector3.new(side * 3.5, 2.1, 4.6))
		Kit.beam(model, "AshRowingOar", a, b, .15, C.Cream, wood)
		Kit.part(model, "OarBlade", Vector3.new(.85, .12, 2.5), CFrame.lookAt(b, a), C.Plank, wood)
	end
	-- The dock end stays on the dock while the boat bobs. A rigid rope parented
	-- to the boat made its landward anchor drift through the pier.
	local dockAnchor=Kit.part(parent,"SkiffDockMooring",Vector3.one*.08,CFrame.new(11.3,12,132),C.Cream,
		{transparency=1,shadow=false})
	local bowAnchor=Kit.part(model,"SkiffBowMooring",Vector3.one*.08,cf*CFrame.new(0,2,-8),C.Cream,
		{transparency=1,shadow=false})
	local dockEye, bowEye=Instance.new("Attachment"),Instance.new("Attachment")
	dockEye.Axis,bowEye.Axis=Vector3.yAxis,Vector3.yAxis
	dockEye.Name,dockEye.Parent="DockEye",dockAnchor
	bowEye.Name,bowEye.Parent="BowEye",bowAnchor
	local mooring=Instance.new("Beam")
	mooring.Name,mooring.Attachment0,mooring.Attachment1="SkiffMooringLine",dockEye,bowEye
	mooring.Color,mooring.Transparency=ColorSequence.new(C.Cream),NumberSequence.new(.12)
	mooring.Width0,mooring.Width1,mooring.Segments=.09,.09,10
	mooring.CurveSize0,mooring.CurveSize1,mooring.FaceCamera=-1.1,1.1,true
	mooring.LightInfluence,mooring.Parent=1,bowAnchor
	model:SetAttribute("SceneryMotion", "Boat")
	model:SetAttribute("DriftOrigin", cf)
	return model
end

local function beach(parent: Instance)
	local model = group(parent, "TideglassBeachDay")
	local cf = CFrame.new(-205, 4.05, -222) * CFrame.Angles(0, -.32, 0)
	for towel = 0, 1 do
		local base = cf * CFrame.new(towel * 5.5, 0, towel * 2)
		local tint = if towel == 0 then C.Coral else C.Teal
		Kit.part(model, "BeachTowel", Vector3.new(3.4, .07, 6.5), base, C.Cream, cloth)
		for stripe = 0, 3 do Kit.part(model, "WovenTowelStripe", Vector3.new(3.4, .015, .55), base * CFrame.new(0, .045, (stripe - 1.5) * 1.6), tint, cloth) end
		Kit.beam(model, "RolledTowelPillow", base:PointToWorldSpace(Vector3.new(-1.5, .35, -2.65)), base:PointToWorldSpace(Vector3.new(1.5, .35, -2.65)), .6, tint, cloth)
	end
	Kit.part(model, "BeachCooler", Vector3.new(2.2, 1.75, 1.8), cf * CFrame.new(3, .9, -4), C.Teal)
	Kit.part(model, "CoolerCreamLid", Vector3.new(2.35, .25, 1.95), cf * CFrame.new(3, 1.9, -4), C.Cream)
	for i = 1, 5 do
		local p = Vector3.new(-267 + i * 3.1, 4.14, -230 + math.sin(i) * 3)
		Kit.ball(model, "PearlShell", Vector3.new(.75, .21, .65), p, C.Cream:Lerp(C.Coral, i % 3 * .14), detail)
		for ridge = -1, 1 do Kit.beam(model, "ShellRidge", p + Vector3.new(0, .12, -.25), p + Vector3.new(ridge * .2, .12, .2), .045, C.Coral:Lerp(C.Cream, .65), detail) end
	end
	-- Navigation beacon is a physical landmark rather than a non-functional prompt.
	local b = Vector3.new(-274, 4, -200)
	Kit.beam(model, "CoveSignalPole", b, b + Vector3.yAxis * 8, .25, C.Wood, wood)
	local pennants=Kit.model(model,"CoveWindPennants")
	local pennantOrigin=CFrame.new(b+Vector3.yAxis*6.5)
	pennants.WorldPivot=pennantOrigin
	for _, side in {-1, 1} do
		Kit.wedge(pennants, "CoralWindPennant", Vector3.new(.055, 1.3, 2.6), CFrame.new(b + Vector3.new(0, 6.5 + side * .7, 1)) * CFrame.Angles(0, math.pi / 2, 0),
			if side == 1 then C.Coral else C.Cream, cloth)
	end
	pennants:SetAttribute("SwayOrigin",pennantOrigin)
	pennants:SetAttribute("SwayAmplitude",.038)
	return model
end

local function skyPicnic(parent: Instance, cf: CFrame, name: string, tint: Color3)
	local model = group(parent, name)
	Kit.part(model, "WovenPicnicBlanket", Vector3.new(8, .06, 6.4), cf * CFrame.new(0, .05, 0), C.Cream, cloth)
	for i = -2, 2 do
		Kit.part(model, "BlanketWovenStripe", Vector3.new(.5, .015, 6.4), cf * CFrame.new(i * 1.4, .09, 0), tint, cloth)
	end
	for _, x in {-2.6, 2.6} do
		Kit.ball(model, "LinenCushion", Vector3.new(1.9, .65, 1.8), cf:PointToWorldSpace(Vector3.new(x, .4, .7)), tint, cloth)
	end
	Kit.part(model, "PicnicHamper", Vector3.new(2, 1.2, 1.6), cf * CFrame.new(.3, .65, -2), C.Plank, wood)
	Kit.part(model, "HamperLid", Vector3.new(2.12, .15, 1.7), cf * CFrame.new(.3, 1.32, -2), C.Wood, wood)
	for _, x in {-.3, .9} do
		Kit.disk(model, "GlazedTeaCup", .45, .45, .55, cf:PointToWorldSpace(Vector3.new(x, .4, -.5)), C.Cream)
	end
	Kit.disk(model, "PicnicFruitPlate", 1.5, 1.5, .1, cf:PointToWorldSpace(Vector3.new(.2, .2, .8)), C.Coral)
	for i = 0, 2 do Kit.ball(model, "PicnicApricot", Vector3.one * .42, cf:PointToWorldSpace(Vector3.new(i * .35 - .15, .5, .8)), C.Gold, detail) end
	return model
end

function Landscaping.populate(_root: Instance, regions: {[string]: Model})
	local borders: {{any}} = {
		-- The same six harbor beds now frame the cafe, workshop and seating.
		{"harbor",-72,12,-7,1.35,2}, {"harbor",72,12,-6,1.25,1},
		{"harbor",-58,12,22,1.45,3}, {"harbor",57,12,17,1.25,2},
		{"harbor",-75,12,68,1.4,1}, {"harbor",44,12,82,1.3,4},
		{"blossom",-226,28,-33,1.2,4}, {"blossom",-267,28,-10,1.35,3},
		{"blossom",-270,28,65,1.4,2}, {"blossom",-194,28,-8,1.2,3},
		{"forest",292,24,11,1.25,1}, {"forest",245,24,61,1.25,4},
		{"summit",277,60,-278,1.15,4}, {"summit",277,60,-202,1.15,3},
		{"cove",-244,4,-169,1.05,2}, {"cove",-257,4,-232,1.15,1},
	}
	for i, data in borders do
		local pos = Vector3.new(data[2], data[3], data[4])
		if clearRoutes(data[1], pos, 4.1 * data[5]) then
			planting(regions[data[1]], pos, data[5], flowerTints[data[6]], i * 81)
		end
	end
	local hedges: {{any}} = {
		{"harbor",-17,12,-80,11,-.2}, {"harbor",26,12,-37,12,.05},
		{"harbor",-21,12,46,11,-.3}, {"harbor",26,12,60,12,.2},
		{"blossom",-217,28,26,10,.3}, {"blossom",-270,28,-24,12,-.2},
		{"forest",291,24,36,11,.3}, {"summit",275,60,-262,9,0},
	}
	for i, data in hedges do
		local pos = Vector3.new(data[2], data[3], data[4])
		if clearRoutes(data[1], pos, data[5] * .5) then hedge(regions[data[1]], pos, data[5], data[6], flowerTints[(i - 1) % 4 + 1]) end
	end
	-- Young, grouped trees fill the middle distance beneath the existing hero trees.
	local saplings: {{any}} = {
		{"harbor",-73,12,58,.73,"Oak"}, {"harbor",93,12,52,.7,"Oak"},
		{"blossom",-299,28,-7,.72,"Blossom"}, {"blossom",-215,28,-46,.7,"Blossom"},
		{"forest",215,24,10,.68,"Oak"}, {"forest",307,24,51,.65,"Oak"},
	}
	for i, data in saplings do
		local pos = Vector3.new(data[2], data[3], data[4])
		if clearRoutes(data[1], pos, 5.5) then
			local tree = Nature.tree(regions[data[1]], pos, data[5], data[6], 600 + i)
			tree.Name = "Young" .. data[6] .. "Cluster"
			for _, part in tree:GetDescendants() do
				if part:IsA("BasePart") then part.CanCollide, part.CanQuery = false, false end
			end
		end
	end
	-- Woodland groundcover belongs under the existing pine/oak crowns.
	for i, p in {Vector3.new(239,24,-35), Vector3.new(302,24,23), Vector3.new(222,24,54), Vector3.new(289,24,-61)} do
		if clearRoutes("forest", p, 4.5) then forestFloor(regions.forest, p, i * 39) end
	end
	blossomDrift(regions.blossom, Vector3.new(-282,28,-19), 718)
	blossomDrift(regions.blossom, Vector3.new(-224,28,57), 719)
	produce(regions.harbor, CFrame.new(-80,12,44) * CFrame.Angles(0,-.3,0))
	umbrella(regions.harbor, Vector3.new(32,12,79), C.Teal, .2)
	umbrella(regions.cove, Vector3.new(-212,4,-225), C.Coral, -.4)
	skiff(regions.harbor)
	beach(regions.cove)
	skyPicnic(regions.blossom, CFrame.new(-207,28,26) * CFrame.Angles(0,.4,0), "PetalwindTeaPicnic", C.Blossom)
	skyPicnic(regions.summit, CFrame.new(286,60,-208) * CFrame.Angles(0,-.45,0), "LookoutStargazerPicnic", C.Lavender)
end
return Landscaping
