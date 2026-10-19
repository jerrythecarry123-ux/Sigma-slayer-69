--!strict
-- Original reusable nature, built from a small number of broad, readable shapes.
-- Positions are ground height except cloud (center) and islandUnderside (meadow top).
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local C = Kit.palette
local Nature = {}

local wood = { material = Enum.Material.Wood }
local trunkWood = { material = Enum.Material.Wood, collidable = true }
local leaves = { material = Enum.Material.SmoothPlastic }
local tinyLeaves = { material = Enum.Material.SmoothPlastic, shadow = false }

-- Overlapping domes with a low faceted leaf skirt soften the branched silhouette.
local function leafCrown(parent: Instance, center: Vector3, width: number, height: number, depth: number, tint: Color3, yaw: number)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local canopy=Kit.model(parent,"BreezyBroadleafCanopy")
	canopy.WorldPivot=CFrame.new(center)
	canopy:SetAttribute("SwayOrigin",CFrame.new(center))
	canopy:SetAttribute("SwayAmplitude",.027)
	Kit.ball(canopy, "CanopyHeart", Vector3.new(width * .95, height, depth * .95), center, tint, leaves)
	for i = 0, 3 do
		local rotation = CFrame.Angles(0, i * math.pi / 2, 0)
		local shoulder = frame * rotation * CFrame.new(0, -height * .19, -depth * .2)
		Kit.wedge(canopy, "LeafShoulder", Vector3.new(width * .64, height * .55, depth * .55), shoulder,
			tint:Lerp(if i % 2 == 0 then C.Lime else C.Pine, 0.07), leaves)
	end
end

local function roots(parent: Instance, pos: Vector3, scale: number, random: Random)
	for i = 1, 4 do
		local a = i * math.pi / 2 + random:NextNumber(-0.25, 0.25)
		Kit.beam(parent, "ButtressRoot", pos + Vector3.yAxis * 1.7 * scale,
			pos + Vector3.new(math.cos(a) * 2.6, 0.17, math.sin(a) * 2.6) * scale,
			0.65 * scale, C.Bark, wood)
	end
end

local function broadleaf(parent: Instance, pos: Vector3, scale: number, blossom: boolean, random: Random)
	local trunkTop = pos + Vector3.new(0.6, 10.8, -0.6) * scale
	local bend = pos + Vector3.new(-0.5, 5.3, 0.2) * scale
	Kit.beam(parent, "LowerTrunk", pos - Vector3.yAxis * 0.12 * scale, bend, 1.8 * scale, C.Bark, trunkWood)
	Kit.beam(parent, "UpperTrunk", bend, trunkTop, 1.25 * scale, C.BarkLight, trunkWood)
	roots(parent, pos, scale, random)
	for i = 1, 3 do
		local a = i * math.pi * 0.65
		local offset = Vector3.new(math.cos(a) * 0.71, 0, math.sin(a) * 0.71) * scale
		Kit.beam(parent, "BarkSeam", pos + offset + Vector3.yAxis * scale,
			bend + offset * 0.7 - Vector3.yAxis * scale, 0.12 * scale, C.Bark:Lerp(C.DeepStone, 0.3), wood)
	end
	local baseTint = if blossom then C.Blossom else C.Leaf
	for i = 1, 5 do
		local angle = i * math.pi * 0.4 + random:NextNumber(-0.14, 0.14)
		local reach = random:NextNumber(3.8, 5.8) * scale
		local endPos = trunkTop + Vector3.new(math.cos(angle) * reach, random:NextNumber(0.1, 3.2) * scale, math.sin(angle) * reach)
		local elbow = bend + Vector3.new(math.cos(angle) * reach * 0.45, (3.5 + i % 2) * scale, math.sin(angle) * reach * 0.45)
		Kit.beam(parent, "CrookedBough", bend, elbow, 0.75 * scale, C.Bark, wood)
		Kit.beam(parent, "CrownBranch", elbow, endPos, 0.47 * scale, C.BarkLight, wood)
		local tint = baseTint:Lerp(if blossom then C.BlossomLight else C.Lime, random:NextNumber(0.02, 0.28))
		leafCrown(parent, endPos + Vector3.yAxis * 1.2 * scale,
			random:NextNumber(7.1, 8.8) * scale, random:NextNumber(3.6, 4.8) * scale, 7.3 * scale, tint, angle)
		if blossom and i % 2 == 0 then
			-- Small drooping blossom sprays read close up; the large crown carries the silhouette.
			for spray = 1, 3 do
				local drop = endPos + Vector3.new(spray - 2, -1.1 - spray * 0.24, -1.8) * scale
				Kit.ball(parent, "BlossomSpray", Vector3.new(0.45, 0.9, 0.45) * scale, drop,
					C.BlossomLight, { shadow = false })
			end
		end
	end
	leafCrown(parent, trunkTop + Vector3.new(-0.7, 4, 0.4) * scale, 8.7 * scale, 4.2 * scale, 8.1 * scale,
		baseTint:Lerp(if blossom then C.BlossomLight else C.Lime, 0.18), random:NextNumber(0, math.pi))
end

local function canopyTriangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, tint: Color3)
	local ab,ac,bc=b-a,c-a,c-b
	local abd,acd,bcd=ab:Dot(ab),ac:Dot(ac),bc:Dot(bc)
	if abd>acd and abd>bcd then c,a=a,c elseif acd>bcd and acd>abd then a,b=b,a end
	ab,ac,bc=b-a,c-a,c-b
	local right=ac:Cross(ab).Unit
	local back=bc.Unit
	local up=bc:Cross(right).Unit
	local height=math.abs(ab:Dot(up))
	local first,second=math.abs(ab:Dot(back)),math.abs(ac:Dot(back))
	if first>.001 then Kit.wedge(parent,"EvergreenBough",Vector3.new(.12,height,first),CFrame.fromMatrix((a+b)/2,right,up,back),tint,leaves) end
	if second>.001 then Kit.wedge(parent,"EvergreenBough",Vector3.new(.12,height,second),CFrame.fromMatrix((a+c)/2,-right,up,-back),tint,leaves) end
end
local function pine(parent: Instance, pos: Vector3, scale: number, random: Random)
	Kit.beam(parent,"PineTrunk",pos,pos+Vector3.yAxis*22.8*scale,1.15*scale,C.Bark,trunkWood)
	roots(parent,pos,scale*.7,random)
	local yaw=random:NextNumber(0,math.pi)
	local needles=Kit.model(parent,"BreezyNeedleCanopy")
	needles.WorldPivot=CFrame.new(pos)
	needles:SetAttribute("SwayOrigin",CFrame.new(pos))
	needles:SetAttribute("SwayAmplitude",.009)
	-- Closed, overlapping hexagonal needle skirts form a clean conifer silhouette.
	for tier=0,5 do
		local radius=(7.1-tier*.98)*scale
		local base=pos+Vector3.yAxis*(3+tier*3.1)*scale
		local tip=base+Vector3.yAxis*(8-tier*.12)*scale
		local tint=C.Pine:Lerp(C.PineLight,tier*.06)
		for face=0,5 do
			local a=yaw+face*math.pi/3
			local b=yaw+(face+1)*math.pi/3
			local left=base+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)
			local right=base+Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius)
			canopyTriangle(needles,tip,left,right,tint:Lerp(C.PineLight,face%2*.035))
		end
		Kit.disk(needles,"NeedleSkirtUnderside",radius*1.7,radius*1.7,.12*scale,base,tint,leaves)
	end
end

local function palm(parent: Instance, pos: Vector3, scale: number, random: Random)
	local curve = Vector3.new(random:NextNumber(1.8, 3.8), 0, random:NextNumber(-2.2, 2.2)) * scale
	local previous = pos
	for segment = 1, 6 do
		local t = segment / 6
		local nextPos = pos + Vector3.yAxis * 16.8 * t * scale + curve * t * t
		Kit.beam(parent, "CurvedPalmTrunk", previous, nextPos, (1.1 - t * 0.45) * scale,
			if segment % 2 == 0 then C.BarkLight else C.Wood, trunkWood)
		-- Short collars emphasize growth rings without texturing every face.
		local direction = (nextPos - previous).Unit
		Kit.beam(parent, "PalmGrowthRing", nextPos - direction * 0.1 * scale,
			nextPos + direction * 0.1 * scale, (1.22 - t * 0.43) * scale, C.Bark, wood)
		previous = nextPos
	end
	local fronds=Kit.model(parent,"BreezyPalmCanopy")
	fronds.WorldPivot=CFrame.new(previous)
	fronds:SetAttribute("SwayOrigin",CFrame.new(previous))
	fronds:SetAttribute("SwayAmplitude",.022)
	for frond = 1, 8 do
		local angle = frond * math.pi / 4 + random:NextNumber(-0.1, 0.1)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = previous
		local tint = C.PineLight:Lerp(C.Lime, frond % 3 * 0.16)
		for section = 1, 3 do
			local finish = previous + direction * section * 3.5 * scale
				+ Vector3.yAxis * (if section == 1 then 2.5 elseif section == 2 then 1.1 else -2.5) * scale
			Kit.wedge(fronds, "PalmLeaf", Vector3.new((3.2 - section * 0.65) * scale, 0.26 * scale, (finish - start).Magnitude + 0.2 * scale),
				CFrame.lookAt((start + finish) / 2, finish), tint, leaves)
			start = finish
		end
	end
	for nut = 1, 3 do
		local angle = nut * math.pi * 2 / 3
		Kit.ball(fronds, "Coconut", Vector3.one * 0.83 * scale,
			previous + Vector3.new(math.cos(angle) * 0.65, -0.6, math.sin(angle) * 0.65) * scale, C.Bark, wood)
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
	local model = Kit.model(parent, "WeatheredRock")
	local random = Random.new(seed)
	local yaw = random:NextNumber(0, math.pi)
	local frame = CFrame.new(pos + Vector3.yAxis * size.Y * 0.34) * CFrame.Angles(0.05, yaw, -0.06)
	local tint = C.Stone:Lerp(C.DeepStone, random:NextNumber(0, 0.24))
	Kit.part(model, "RockCore", size * Vector3.new(0.7, 0.7, 0.7), frame, tint,
		{ material = Enum.Material.Slate, collidable = size.Y >= 3 })
	for facet = 0, 3 do
		local turn = CFrame.Angles(0, facet * math.pi / 2, 0)
		Kit.wedge(model, "StoneFacet", size * Vector3.new(0.74, 0.88, 0.61),
			frame * turn * CFrame.new(0, 0, -size.Z * 0.2), tint:Lerp(C.Limestone, facet % 3 * 0.08),
			{ material = Enum.Material.Slate })
	end
	for fragment = 1, 2 do
		local side = if fragment == 1 then -1 else 1
		Kit.wedge(model, "FallenChip", size * Vector3.new(0.24, 0.2, 0.34),
			CFrame.new(pos + Vector3.new(side * size.X * 0.52, size.Y * 0.03, size.Z * 0.2)) * CFrame.Angles(0, yaw + fragment, 0),
			C.DeepStone:Lerp(tint, 0.6), { material = Enum.Material.Slate })
	end
	if moss then
		for patch = 1, 2 do
			Kit.wedge(model, "ClingingMoss", size * Vector3.new(0.44, 0.04, 0.4),
				CFrame.new(pos + Vector3.new((patch - 1.5) * size.X * 0.3, size.Y * 0.73, 0)) * CFrame.Angles(0.04, yaw, 0.07),
				C.Moss:Lerp(C.Grass, patch * 0.15), leaves)
		end
	end
	return model
end

function Nature.garden(parent: Instance, center: Vector3, radius: Vector2, count: number, seed: number, kind: string?): Model
	local model = Kit.model(parent, (kind or "Meadow") .. "Garden")
	local random = Random.new(seed)
	local limit = math.clamp(math.floor(count), 1, if kind == "Lavender" then 16 else 32)
	for index = 1, limit do
		local a, distance = random:NextNumber(0, math.pi * 2), math.sqrt(random:NextNumber())
		local pos = center + Vector3.new(math.cos(a) * radius.X * distance, 0, math.sin(a) * radius.Y * distance)
		local yaw = random:NextNumber(0, math.pi * 2)
		local height = random:NextNumber(0.65, 1.3)
		if kind == "Reeds" then
			for stem = 1, 3 do
				local h = height * (1.8 + stem * 0.35)
				local bottom = pos + Vector3.new((stem - 2) * 0.22, 0, (stem % 2) * 0.18)
				Kit.beam(model, "ReedStem", bottom, bottom + Vector3.yAxis * h, 0.055, C.Moss, tinyLeaves)
				Kit.beam(model, "ReedHead", bottom + Vector3.yAxis * h, bottom + Vector3.yAxis * (h + 0.48), 0.16, C.Wood, { shadow = false })
			end
		elseif kind == "Lavender" then
			for stem = 1, 3 do
				local point = pos + Vector3.new((stem - 2) * 0.25, height + stem * 0.13, 0)
				Kit.beam(model, "LavenderStem", pos, point, 0.045, C.Moss, tinyLeaves)
				for bud = 1, 3 do
					Kit.ball(model, "LavenderBud", Vector3.new(0.19, 0.28, 0.19), point - Vector3.yAxis * bud * 0.16,
						C.Lavender:Lerp(C.Cream, bud * 0.08), { shadow = false })
				end
			end
		else
			for blade = 1, 3 do
				local cf = CFrame.new(pos + Vector3.yAxis * height * 0.45)
					* CFrame.Angles(0, yaw + blade * 2.1, (blade - 2) * 0.22)
				Kit.wedge(model, "MeadowBlade", Vector3.new(0.09, height, 0.38), cf,
					C.Moss:Lerp(C.Lime, random:NextNumber(0, 0.3)), tinyLeaves)
			end
			if kind ~= "Grass" and index % 3 == 0 then
				local point = pos + Vector3.yAxis * (height + 0.25)
				Kit.beam(model, "WildflowerStem", pos, point, 0.045, C.Moss, tinyLeaves)
				local tint = if index % 2 == 0 then C.Cream else C.Coral
				for petal = 1, 4 do
					local angle = petal * math.pi / 2 + yaw
					local flower = Kit.ball(model, "WildflowerPetal", Vector3.new(0.36, 0.1, 0.59),
						point + Vector3.new(math.cos(angle) * 0.2, 0, math.sin(angle) * 0.2), tint, { shadow = false })
					flower.CFrame *= CFrame.Angles(0, -angle + math.pi / 2, 0)
				end
				Kit.ball(model, "WildflowerHeart", Vector3.new(0.21, 0.15, 0.21), point + Vector3.yAxis * 0.07, C.Gold, { shadow = false })
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
		local center = pos + Vector3.new(math.cos(angle) * size.X * 0.23, random:NextNumber(-0.12, 0.14) * size.Y, math.sin(angle) * size.Z * 0.22)
		Kit.ball(model, "CloudVolume", size * Vector3.new(random:NextNumber(0.48, 0.7), random:NextNumber(0.63, 0.98), random:NextNumber(0.55, 0.78)),
			center, C.Cloud:Lerp(C.Cream, puff % 3 * 0.025), { shadow = false, transparency = 0.035 })
	end
	return model
end

function Nature.islandUnderside(parent: Instance, center: Vector3, width: number, depth: number, seed: number): Model
	local model = Kit.model(parent, "AncientFloatingCliffs")
	local random = Random.new(seed)
	local height = math.min(width * 0.31, 53)
	-- Stone masses overlap internally. The outer silhouette carries actual facets and strata.
	Kit.ball(model, "CliffMass", Vector3.new(width * 0.95, height * 1.25, depth * 0.95), center - Vector3.yAxis * height * 0.66,
		C.Cliff, { material = Enum.Material.Slate })
	Kit.ball(model, "WeatheredKeel", Vector3.new(width * 0.59, height * 1.23, depth * 0.55),
		center + Vector3.new(-width * 0.035, -height * 1.03, depth * 0.03), C.DeepStone, { material = Enum.Material.Slate })
	local segments = math.clamp(math.floor((width + depth) / 12), 14, 28)
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local sway = random:NextNumber(0.9, 1.03)
		local rim = center + Vector3.new(math.cos(angle) * width * 0.435 * sway, -height * 0.43, math.sin(angle) * depth * 0.435 * sway)
		local frame = CFrame.new(rim) * CFrame.Angles(random:NextNumber(-0.08, 0.08), -angle, random:NextNumber(-0.11, 0.11))
		local broad = math.pi * math.min(width, depth) / segments * 1.3
		local tint = C.Stone:Lerp(C.DeepStone, index % 4 * 0.13)
		Kit.part(model, "FracturedCliffFace", Vector3.new(broad, height * random:NextNumber(0.58, 0.81), broad * 0.8), frame,
			tint, { material = Enum.Material.Slate })
		Kit.part(model, "SedimentaryBand", Vector3.new(broad * 1.02, height * 0.045, broad * 0.82),
			frame * CFrame.new(0, height * (if index % 2 == 0 then -0.06 else 0.13), 0), C.Limestone:Lerp(tint, 0.65),
			{ material = Enum.Material.Limestone })
		if index % 2 == 0 then
			Kit.wedge(model, "HangingSpur", Vector3.new(broad * 0.7, height * 0.8, broad * 0.66),
				CFrame.new(rim + Vector3.new(-math.cos(angle) * broad * 0.28, -height * 0.42, -math.sin(angle) * broad * 0.28))
					* CFrame.Angles(math.pi, -angle + 0.3, 0), C.DeepStone, { material = Enum.Material.Slate })
		end
		-- Ledges sit below the walkable cap, leaving the root's route geometry unobstructed.
		if index % 3 == 0 then
			Kit.wedge(model, "MossyCliffLedge", Vector3.new(broad * 0.85, 1.2, broad * 0.75),
				CFrame.new(rim + Vector3.yAxis * height * 0.24) * CFrame.Angles(0, -angle, 0), C.Moss, leaves)
		end
	end
	return model
end

return Nature
