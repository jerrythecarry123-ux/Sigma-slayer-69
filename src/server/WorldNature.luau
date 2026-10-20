--!strict
-- Bright brick scenery: flat green leaf shelves, square trunks and stepped stone.
-- Positions are ground height except cloud (center) and islandUnderside (meadow top).
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local C = Kit.palette
local Nature = {}

local brick = { material = Enum.Material.Plastic, studded = true }
local detail = { material = Enum.Material.Plastic, shadow = false }
local collider = { material = Enum.Material.Plastic, collidable = true, transparency = 1, shadow = false }

local function blockBeam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, tint: Color3)
	return Kit.part(parent, name, Vector3.new(width, width, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b), tint, brick)
end

local function swaying(parent: Instance, name: string, pos: Vector3, amplitude: number): Model
	local model = Kit.model(parent, name)
	model.WorldPivot = CFrame.new(pos)
	model:SetAttribute("SwayOrigin", CFrame.new(pos))
	model:SetAttribute("SwayAmplitude", amplitude)
	return model
end

local function broadleaf(parent: Instance, pos: Vector3, scale: number, blossom: boolean, random: Random)
	local top = pos + Vector3.new(.6, 10.8, -.6) * scale
	local bend = pos + Vector3.new(-.5, 5.3, .2) * scale
	local foot = pos - Vector3.yAxis * .12 * scale
	-- Preserve the established narrow trunk collisions; the visible square shells are cosmetic.
	Kit.beam(parent, "LowerTrunk", foot, bend, 1.8 * scale, C.Bark, collider)
	Kit.beam(parent, "UpperTrunk", bend, top, 1.25 * scale, C.BarkLight, collider)
	blockBeam(parent, "SquareLowerTrunk", foot, bend, 1.8 * scale, C.Bark)
	blockBeam(parent, "SquareUpperTrunk", bend, top + Vector3.yAxis * 3.5 * scale, 1.25 * scale, C.Bark)
	local canopy = swaying(parent, "BreezyBroadleafCanopy", top, .018)
	local tint = if blossom then C.Blossom else C.Leaf
	local light = if blossom then C.BlossomLight else C.Lime
	local turn = math.floor(random:NextNumber(0, 4)) * math.pi / 2
	local cf = CFrame.new(pos) * CFrame.Angles(0, turn, 0)
	-- Offset horizontal shelves leave the trunk readable, as in the supplied reference.
	local shelves = {
		{Vector3.new(-3.2, 6.8, .2), Vector3.new(7.4, 1.8, 5.4)},
		{Vector3.new(3.1, 9.8, -1), Vector3.new(7.7, 1.8, 5.8)},
		{Vector3.new(-1.5, 12.8, 1.1), Vector3.new(8.1, 1.9, 6.3)},
		{Vector3.new(.8, 15.1, -.8), Vector3.new(6.8, 1.7, 5.5)},
	}
	for i, shelf in shelves do
		local offset, size = shelf[1], shelf[2]
		if i < 4 then
			local branchEnd = cf:PointToWorldSpace((offset - Vector3.yAxis * .5) * scale)
			local branchStart = pos + Vector3.yAxis * (offset.Y - .5) * scale
			blockBeam(parent, "SquareCrownBranch", branchStart, branchEnd, .75 * scale, C.Bark)
		end
		Kit.part(canopy, "BrickLeafShelf", size * scale, cf * CFrame.new(offset * scale),
			tint:Lerp(light, (i % 3) * .05), brick)
	end
end

local function pine(parent: Instance, pos: Vector3, scale: number, random: Random)
	local top = pos + Vector3.yAxis * 22.8 * scale
	Kit.beam(parent, "PineTrunk", pos, top, 1.15 * scale, C.Bark, collider)
	blockBeam(parent, "SquarePineTrunk", pos, top, 1.15 * scale, C.Bark)
	local needles = swaying(parent, "BreezyNeedleCanopy", pos, .009)
	local yaw = math.floor(random:NextNumber(0, 4)) * math.pi / 2
	for tier = 0, 3 do
		local width = (13 - tier * 2.8) * scale
		local frame = CFrame.new(pos + Vector3.yAxis * (6.8 + tier * 4.6) * scale) * CFrame.Angles(0, yaw, 0)
		local tint = C.Pine:Lerp(C.PineLight, tier * .1)
		-- Four descending square shelves keep the evergreen silhouette without triangle skirts.
		Kit.part(needles, "BrickNeedleShelf", Vector3.new(width, 2.5 * scale, width), frame, tint, brick)
	end
end

local function palm(parent: Instance, pos: Vector3, scale: number, random: Random)
	local curve = Vector3.new(random:NextNumber(1.8, 3.8), 0, random:NextNumber(-2.2, 2.2)) * scale
	local previous = pos
	for segment = 1, 6 do
		local t = segment / 6
		local nextPos = pos + Vector3.yAxis * 16.8 * t * scale + curve * t * t
		local width = (1.1 - t * .45) * scale
		local tint = if segment % 2 == 0 then C.BarkLight else C.Wood
		Kit.beam(parent, "CurvedPalmTrunk", previous, nextPos, width, tint, collider)
		blockBeam(parent, "SquarePalmTrunk", previous, nextPos, width, tint)
		previous = nextPos
	end
	local fronds = swaying(parent, "BreezyPalmCanopy", previous, .022)
	for frond = 1, 8 do
		local angle = frond * math.pi / 4
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local elbow = previous + direction * 4.5 * scale + Vector3.yAxis * 1.7 * scale
		local finish = previous + direction * 9.5 * scale - Vector3.yAxis * 1.3 * scale
		local tint = C.PineLight:Lerp(C.Lime, frond % 3 * .07)
		for i, ends in {{previous, elbow}, {elbow, finish}} do
			local a, b = ends[1], ends[2]
			Kit.part(fronds, "BrickPalmFrond", Vector3.new((if i == 1 then 2.4 else 1.5) * scale, .6 * scale, (b-a).Magnitude),
				CFrame.lookAt((a+b)/2,b), tint, brick)
		end
	end
	for nut = 1, 3 do
		local angle = nut * math.pi * 2 / 3
		Kit.part(fronds, "SquareCoconut", Vector3.one * .83 * scale,
			CFrame.new(previous + Vector3.new(math.cos(angle) * .65, -.6, math.sin(angle) * .65) * scale), C.Bark, brick)
	end
end

function Nature.tree(parent: Instance, pos: Vector3, scale: number, kind: string, seed: number): Model
	local model = Kit.model(parent, kind .. "Tree")
	local random = Random.new(seed)
	if kind == "Pine" then pine(model, pos, scale, random)
	elseif kind == "Palm" then palm(model, pos, scale, random)
	else broadleaf(model, pos, scale, kind == "Blossom", random) end
	return model
end

function Nature.rock(parent: Instance, pos: Vector3, size: Vector3, seed: number, moss: boolean?): Model
	local model = Kit.model(parent, "SteppedBrickRock")
	local random = Random.new(seed)
	local yaw = random:NextNumber(0, math.pi)
	local oldFrame = CFrame.new(pos + Vector3.yAxis * size.Y * .34) * CFrame.Angles(.05, yaw, -.06)
	local tint = C.Stone:Lerp(C.DeepStone, random:NextNumber(0, .24))
	if size.Y >= 3 then
		Kit.part(model, "RockCore", size * Vector3.new(.7, .7, .7), oldFrame, tint, collider)
	end
	-- Axis-aligned ledges replace the old organic facets and keep the green rim flat.
	Kit.part(model, "StoneBrickBase", size * Vector3.new(.94, .46, .9),
		CFrame.new(pos + Vector3.yAxis * size.Y * .23), tint, brick)
	Kit.part(model, "StoneBrickCrown", size * Vector3.new(.68, .32, .64),
		CFrame.new(pos + Vector3.new(-size.X * .08, size.Y * .6, size.Z * .06)), tint:Lerp(C.Cliff, .18), brick)
	if moss then
		Kit.part(model, "FlatGrassRockCap", size * Vector3.new(.69, .045, .65),
			CFrame.new(pos + Vector3.new(-size.X * .08, size.Y * .7825, size.Z * .06)), C.Grass, brick)
	end
	return model
end

function Nature.garden(parent: Instance, center: Vector3, radius: Vector2, count: number, seed: number, kind: string?): Model
	local model = Kit.model(parent, (kind or "Meadow") .. "Garden")
	local random = Random.new(seed)
	local limit = math.clamp(math.floor(count), 1, if kind == "Lavender" then 10 else 24)
	for index = 1, limit do
		local a, distance = random:NextNumber(0, math.pi * 2), math.sqrt(random:NextNumber())
		local pos = center + Vector3.new(math.cos(a) * radius.X * distance, 0, math.sin(a) * radius.Y * distance)
		local yaw = math.floor(random:NextNumber(0, 4)) * math.pi / 2
		local height = random:NextNumber(.65, 1.3)
		if kind == "Reeds" then
			for stem = 1, 2 do
				local h = height * (1.8 + stem * .35)
				local bottom = pos + Vector3.new((stem - 1.5) * .3, 0, 0)
				Kit.part(model, "SquareReedStem", Vector3.new(.12, h, .12), CFrame.new(bottom + Vector3.yAxis * h/2), C.Moss, detail)
				Kit.part(model, "SquareReedHead", Vector3.new(.22, .48, .22), CFrame.new(bottom + Vector3.yAxis * (h+.24)), C.Wood, detail)
			end
		elseif kind == "Lavender" then
			Kit.part(model, "LavenderStem", Vector3.new(.12, height, .12), CFrame.new(pos + Vector3.yAxis * height/2), C.Moss, detail)
			Kit.part(model, "LavenderFlowerBrick", Vector3.new(.42, .65, .42), CFrame.new(pos + Vector3.yAxis * (height+.15)), C.Lavender, brick)
		else
			local frame = CFrame.new(pos + Vector3.yAxis * height/2) * CFrame.Angles(0,yaw,0)
			Kit.part(model, "SquareGrassBlade", Vector3.new(.18, height, .42), frame, C.Leaf, detail)
			Kit.part(model, "SquareGrassSideBlade", Vector3.new(.18, height*.65, .42), frame * CFrame.new(.38,-height*.175,0), C.Moss, detail)
			if kind ~= "Grass" and index % 3 == 0 then
				local point = pos + Vector3.yAxis * (height+.25)
				local tint = if index % 2 == 0 then C.Cream else C.Gold
				Kit.part(model, "WildflowerPetalBrick", Vector3.new(.9,.16,.36), CFrame.new(point), tint, detail)
				Kit.part(model, "WildflowerCrossBrick", Vector3.new(.36,.16,.9), CFrame.new(point), tint, detail)
				Kit.part(model, "WildflowerHeart", Vector3.new(.25,.2,.25), CFrame.new(point + Vector3.yAxis*.1), C.Gold, detail)
			end
		end
	end
	return model
end

function Nature.cloud(parent: Instance, pos: Vector3, size: Vector3, seed: number): Model
	local model = Kit.model(parent, "DriftingCloud")
	local random = Random.new(seed)
	for puff = 0, 6 do
		local angle = puff * math.pi / 3
		local center = pos + Vector3.new(math.cos(angle) * size.X * .23, random:NextNumber(-.12, .14) * size.Y, math.sin(angle) * size.Z * .22)
		Kit.ball(model, "CloudVolume", size * Vector3.new(random:NextNumber(.48, .7), random:NextNumber(.63, .98), random:NextNumber(.55, .78)),
			center, C.Cloud:Lerp(C.Cream, puff % 3 * .025), { shadow = false, transparency = .035 })
	end
	return model
end

function Nature.islandUnderside(parent: Instance, center: Vector3, width: number, depth: number, _seed: number): Model
	local model = Kit.model(parent, "SteppedFloatingCliffs")
	local height = math.min(width * .31, 53)
	for tier = 0, 2 do
		local factor = 1 - tier*.23
		Kit.part(model, "StuddedCliffTier", Vector3.new(width*.9*factor,height*.4,depth*.9*factor),
			CFrame.new(center-Vector3.yAxis*height*(.2+tier*.38)), C.Cliff:Lerp(C.DeepStone,tier*.12), brick)
	end
	return model
end

return Nature
