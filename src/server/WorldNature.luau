--!strict
-- Sculpted scenery: pointed foliage, branching trunks and irregular stone facets.
-- Positions are ground height except cloud (center) and islandUnderside (meadow top).
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local C = Kit.palette
local Nature = {}

-- Large natural forms have their own surface character. Tiny foliage stays
-- quiet so distant crowns do not turn into noisy, repeating grass textures.
local foliage = { material = Enum.Material.SmoothPlastic }
local bark = { material = Enum.Material.Wood }
local stone = { material = Enum.Material.Slate }
local detail = { material = Enum.Material.SmoothPlastic, shadow = false }
local mossSurface = { material = Enum.Material.Grass, shadow = false }
local collider = { material = Enum.Material.Plastic, collidable = true, transparency = 1, shadow = false }

-- Two thin mirrored wedges form a single tapered leaf, with its tip at b.
local function leaf(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, tint: Color3, options: any?)
	local frame = CFrame.lookAt((a+b)/2,b)
	for _, side in {-1,1} do
		Kit.wedge(parent,name,Vector3.new(.09,width/2,(b-a).Magnitude),
			frame*CFrame.new(side*width/4,0,0)*CFrame.Angles(0,0,-side*math.pi/2),tint,options or foliage)
	end
end

-- Radial sloping panels overlap into one cohesive crown, rather than separate cubes.
local function crown(parent: Instance, center: Vector3, radius: number, height: number, tint: Color3, turn: number, name: string)
	for face=0,5 do
		local angle=turn+face*math.pi/3
		local frame=CFrame.new(center)*CFrame.Angles(0,angle,0)*CFrame.new(0,0,-radius/2)
		Kit.wedge(parent,name,Vector3.new(radius*1.05,height,radius),frame,
			tint:Lerp(C.Lime,face%3*.025),foliage)
	end
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
	-- Established invisible collision cores stay in exactly the same positions.
	Kit.beam(parent, "LowerTrunk", foot, bend, 1.8 * scale, C.Bark, collider)
	Kit.beam(parent, "UpperTrunk", bend, top, 1.25 * scale, C.BarkLight, collider)
	Kit.beam(parent,"SculptedLowerTrunk",foot,bend,1.81*scale,C.Bark,bark)
	Kit.beam(parent,"TaperedUpperTrunk",bend,top,1.26*scale,C.Bark,bark)
	local canopy=swaying(parent,"BreezyBroadleafCanopy",top,.018)
	local tint=if blossom then C.Blossom else C.Leaf
	local light=if blossom then C.BlossomLight else C.Lime
	local turn=random:NextNumber(0,math.pi*2)
	local basis=CFrame.new(pos)*CFrame.Angles(0,turn,0)
	for index=0,2 do
		local angle=turn+index*math.pi*2/3
		local branchStart=pos+Vector3.yAxis*(6.4+index*.6)*scale
		local branchEnd=pos+Vector3.new(math.cos(angle)*3.9,10.1+index*.5,math.sin(angle)*3.9)*scale
		Kit.beam(parent,"TaperedCrownBranch",branchStart,branchEnd,(.64-index*.1)*scale,C.BarkLight,bark)
	end
	crown(canopy,basis:PointToWorldSpace(Vector3.new(0,12.2,0)*scale),6.7*scale,4.3*scale,tint,turn,"FacetedLeafCrown")
	crown(canopy,basis:PointToWorldSpace(Vector3.new(-2.8,10.6,1.4)*scale),4.2*scale,3.2*scale,tint:Lerp(light,.18),turn+.35,"LeafShoulder")
	for index=0,2 do
		local angle=turn+index*math.pi*2/3
		local start=pos+Vector3.new(math.cos(angle)*4.5,12.4,math.sin(angle)*4.5)*scale
		local tip=pos+Vector3.new(math.cos(angle)*7.1,11.6,math.sin(angle)*7.1)*scale
		leaf(canopy,"PointedCanopyLeaf",start,tip,1.9*scale,tint:Lerp(light,.24))
	end
end

local function pine(parent: Instance, pos: Vector3, scale: number, random: Random)
	local top = pos + Vector3.yAxis * 22.8 * scale
	Kit.beam(parent,"PineTrunk",pos,top,1.15*scale,C.Bark,collider)
	Kit.beam(parent,"TaperedPineTrunk",pos,top,1.16*scale,C.Bark,bark)
	local needles=swaying(parent,"BreezyNeedleCanopy",pos,.009)
	local turn=random:NextNumber(0,math.pi*2)
	for tier=0,2 do
		local radius=(7.3-tier*2.1)*scale
		local center=pos+Vector3.yAxis*(9.2+tier*5)*scale
		crown(needles,center,radius,(8.8-tier*.8)*scale,C.Pine:Lerp(C.PineLight,tier*.13),turn+tier*.27,"EvergreenBough")
	end
	-- A slender terminal shoot closes the crown above the preserved trunk core.
	crown(needles,pos+Vector3.yAxis*22.75*scale,.65*scale,3.4*scale,
		C.Pine:Lerp(C.PineLight,.28),turn+.54,"PineNeedleTip")
	for branch=0,1 do
		local angle=turn+branch*math.pi
		Kit.beam(parent,"ExposedPineBranch",pos+Vector3.yAxis*5.7*scale,
			pos+Vector3.new(math.cos(angle)*2.8,6.7,math.sin(angle)*2.8)*scale,.35*scale,C.BarkLight,bark)
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
		Kit.beam(parent,"CurvedPalmTrunk",previous,nextPos,width,tint,collider)
		Kit.beam(parent,"SculptedPalmTrunk",previous,nextPos,width*1.01,tint,bark)
		previous=nextPos
	end
	local fronds=swaying(parent,"BreezyPalmCanopy",previous,.022)
	for frond=1,6 do
		local angle=frond*math.pi/3
		local direction=Vector3.new(math.cos(angle),0,math.sin(angle))
		local elbow=previous+direction*4.5*scale+Vector3.yAxis*1.7*scale
		local finish=previous+direction*9.5*scale-Vector3.yAxis*1.3*scale
		local tint=C.PineLight:Lerp(C.Lime,frond%3*.07)
		leaf(fronds,"TaperedPalmFrond",previous,elbow,2.9*scale,tint)
		leaf(fronds,"TaperedPalmTip",elbow-direction*.8*scale,finish,1.9*scale,tint:Lerp(C.Leaf,.1))
	end
	for nut=1,2 do
		local angle=nut*math.pi
		Kit.ball(fronds,"Coconut",Vector3.new(.76,1,.7)*scale,
			previous+Vector3.new(math.cos(angle)*.65,-.6,math.sin(angle)*.65)*scale,C.Bark,bark)
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
	local model=Kit.model(parent,"FacetedShoreRock")
	local random=Random.new(seed)
	local yaw=random:NextNumber(0,math.pi)
	local oldFrame=CFrame.new(pos+Vector3.yAxis*size.Y*.34)*CFrame.Angles(.05,yaw,-.06)
	local tint=C.Stone:Lerp(C.DeepStone,random:NextNumber(0,.24))
	if size.Y>=3 then
		Kit.part(model,"RockCore",size*Vector3.new(.7,.7,.7),oldFrame,tint,collider)
	end
	Kit.wedge(model,"SlopingStoneFace",size*Vector3.new(.95,.76,.88),oldFrame,tint,stone)
	Kit.wedge(model,"BrokenStoneCrown",size*Vector3.new(.78,.66,.78),
		oldFrame*CFrame.new(-size.X*.06,size.Y*.09,size.Z*.04)*CFrame.Angles(0,math.pi,0),tint:Lerp(C.Cliff,.2),stone)
	Kit.wedge(model,"ChippedRockShoulder",size*Vector3.new(.56,.48,.7),
		oldFrame*CFrame.new(size.X*.24,-size.Y*.05,-size.Z*.03)*CFrame.Angles(0,math.pi/2,.12),tint:Lerp(C.DeepStone,.16),stone)
	if moss then
		Kit.wedge(model,"SlopingMossPatch",size*Vector3.new(.48,.025,.48),
			oldFrame*CFrame.new(-size.X*.1,size.Y*.425,size.Z*.12)*CFrame.Angles(.12,.2,0),C.Moss,mossSurface)
	end
	return model
end

function Nature.garden(parent: Instance, center: Vector3, radius: Vector2, count: number, seed: number, kind: string?): Model
	local model=Kit.model(parent,(kind or "Meadow").."Garden")
	local random=Random.new(seed)
	local limit=math.clamp(math.floor(count),1,if kind=="Lavender" then 10 else 24)
	for index=1,limit do
		local a,distance=random:NextNumber(0,math.pi*2),math.sqrt(random:NextNumber())
		local pos=center+Vector3.new(math.cos(a)*radius.X*distance,0,math.sin(a)*radius.Y*distance)
		local yaw=random:NextNumber(0,math.pi*2)
		local height=random:NextNumber(.65,1.3)
		if kind=="Reeds" then
			for stem=1,2 do
				local h=height*(1.8+stem*.35)
				local bottom=pos+Vector3.new((stem-1.5)*.3,0,0)
				Kit.beam(model,"ReedStem",bottom,bottom+Vector3.yAxis*h,.12,C.Moss,detail)
				Kit.beam(model,"ReedSeedHead",bottom+Vector3.yAxis*h,bottom+Vector3.yAxis*(h+.48),.22,C.Wood,detail)
			end
		elseif kind=="Lavender" then
			Kit.beam(model,"LavenderStem",pos,pos+Vector3.yAxis*height,.09,C.Moss,detail)
			for flower=0,2 do
				local frame=CFrame.new(pos+Vector3.yAxis*(height+flower*.19))*CFrame.Angles(0,yaw+flower*1.2,0)
				Kit.wedge(model,"LavenderPetalSpike",Vector3.new(.38,.4,.3),frame,C.Lavender,detail)
			end
		else
			local frame=CFrame.new(pos+Vector3.yAxis*height/2)*CFrame.Angles(0,yaw,0)
			Kit.wedge(model,"PointedGrassBlade",Vector3.new(.07,height,.4),frame*CFrame.Angles(0,0,-.15),C.Leaf,detail)
			Kit.wedge(model,"LeaningGrassBlade",Vector3.new(.07,height*.65,.35),frame*CFrame.new(.24,-height*.175,0)*CFrame.Angles(0,.9,.28),C.Moss,detail)
			if kind~="Grass" and index%3==0 then
				local point=pos+Vector3.yAxis*(height+.2)
				local tint=if index%2==0 then C.Cream else C.Gold
				for petal=0,4 do
					local angle=yaw+petal*math.pi*2/5
					local petalFrame=CFrame.new(point)*CFrame.Angles(0,angle,0)*CFrame.new(0,0,-.29)*CFrame.Angles(0,0,math.pi/2)
					Kit.wedge(model,"WildflowerPetal",Vector3.new(.1,.29,.55),petalFrame,tint,detail)
				end
				Kit.disk(model,"WildflowerHeart",.22,.22,.12,point+Vector3.yAxis*.07,C.Gold,detail)
			end
		end
	end
	return model
end

function Nature.cloud(parent: Instance, pos: Vector3, size: Vector3, seed: number): Model
	local model=Kit.model(parent,"DriftingCloud")
	local random=Random.new(seed)
	-- Long overlapping volumes read as a single cloud bank rather than bead clusters.
	for bank=-1,1 do
		local center=pos+Vector3.new(bank*size.X*.21,random:NextNumber(-.08,.08)*size.Y,bank*size.Z*.08)
		Kit.ball(model,"CloudBank",size*Vector3.new(if bank==0 then .92 else .65,if bank==0 then .8 else .58,.8),
			center,C.Cloud,{shadow=false,transparency=.035})
	end
	return model
end

function Nature.islandUnderside(parent: Instance, center: Vector3, width: number, depth: number, seed: number): Model
	local model=Kit.model(parent,"FacetedFloatingCliffs")
	local height=math.min(width*.31,53)
	for face=0,7 do
		local angle=(face+.5)*math.pi/4
		local radius=1/math.sqrt(math.sin(angle)^2/(width*.47)^2+math.cos(angle)^2/(depth*.47)^2)
		local h=height*(.9+math.sin(seed+face*1.7)*.08)
		local frame=CFrame.new(center)*CFrame.Angles(0,angle,0)*CFrame.new(0,-h*.49,-radius/2)*CFrame.Angles(0,0,math.pi)
		Kit.wedge(model,"DescendingIslandFacet",Vector3.new(radius*.88,h,radius),frame,C.Cliff:Lerp(C.DeepStone,(face%3)*.06),stone)
	end
	return model
end

return Nature
