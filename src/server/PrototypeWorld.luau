--!strict
-- Five original, connected sky islands. World generation never changes a custom map.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Fish = require(Shared:WaitForChild("FishModel"))
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Nature = require(script.Parent:WaitForChild("WorldNature"))
local Architecture = require(script.Parent:WaitForChild("WorldArchitecture"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local Landscaping = require(script.Parent:WaitForChild("WorldLandscaping"))
local Residents = require(script.Parent:WaitForChild("WorldResidents"))
local PondBackdrops = require(script.Parent:WaitForChild("WorldPondBackdrops"))
local DockDetails = require(script.Parent:WaitForChild("WorldDockDetails"))
local TrailDetails = require(script.Parent:WaitForChild("WorldTrailDetails"))
local C = Kit.palette
local World = {}
local function v(p: {number}): Vector3 return Vector3.new(p[1], p[2], p[3]) end

-- Two thin solid wedges form an exact triangle, including irregular coastlines.
local function triangle(parent: Instance, name: string, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: Enum.Material, solid: boolean, shadow: boolean?, studded: boolean?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c
	elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	if ac:Cross(ab).Magnitude < 0.001 then return end
	local right = ac:Cross(ab).Unit
	local back = bc.Unit
	local up = bc:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	local options = {material = material, collidable = solid, shadow = shadow ~= false,studded=studded==true}
	local thickness = if solid then 0.7 else 0.45
	local l1, l2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if l1 > 0.01 then Kit.wedge(parent, name, Vector3.new(thickness, height, l1), CFrame.fromMatrix((a+b)/2, right, up, back), color, options) end
	if l2 > 0.01 then Kit.wedge(parent, name, Vector3.new(thickness, height, l2), CFrame.fromMatrix((a+c)/2, -right, up, -back), color, options) end
end
local function island(parent: Instance, data: any, color: Color3, material: Enum.Material): Model
	local model = Kit.model(parent, data.Name)
	model:SetAttribute("ZoneId", data.Id)
	local center = v(data.Center)
	local edge = Layout.outline(data)
	local n = #edge
	for i = 1, n do
		local j = i % n + 1
		-- Triangle center is half the floor thickness below the declared walking surface.
		triangle(model, "WalkableMeadow", center - Vector3.yAxis * 0.35, v(edge[i]) - Vector3.yAxis * 0.35,
			v(edge[j]) - Vector3.yAxis * 0.35, color, material, true,true,true)
		local bottomY=if data.Basin then -18 else -34
		local tiers = { {1,-.75},{1,-2},{1,bottomY},{0,bottomY} }
		for tier = 1, #tiers - 1 do
			local top, bottom = tiers[tier], tiers[tier+1]
			local function ring(k: number, t: {number}): Vector3
				local offset = (v(edge[k]) - center) * t[1]
				return center + offset + Vector3.yAxis * t[2]
			end
			local a,b,c,d = ring(i,top),ring(j,top),ring(i,bottom),ring(j,bottom)
			local tint = if tier == 1 then color else (if (i+tier)%3 == 0 then C.Stone else C.Cliff)
			if top[1]==bottom[1] then
				-- A straight collar needs one panel, rather than four hidden wedge faces.
				Kit.part(model,"StratifiedCliff",Vector3.new((b-a).Magnitude,math.abs(top[2]-bottom[2]),.65),
					CFrame.lookAt((a+b+c+d)/4,b+(c-a)/2)*CFrame.Angles(0,math.pi/2,0),tint,{material=Enum.Material.Plastic,studded=true})
			elseif bottom[1]==0 then
				triangle(model,"StratifiedCliff",a,b,c,tint,Enum.Material.Plastic,false)
			else
				triangle(model,"StratifiedCliff",a,b,c,tint,Enum.Material.Plastic,false,true,true)
				triangle(model,"StratifiedCliff",b,d,c,tint,Enum.Material.Plastic,false,true,true)
			end
		end
	end
	if not data.Basin then
		-- One inset block guarantees a broad native-studded surface without
		-- relying on how triangular wedge faces render legacy surface details.
		-- Its top stays below the paths; the original floor owns collision.
		Kit.part(model,"InsetStuddedMeadow",Vector3.new(data.Radius[1]*1.25,.06,data.Radius[2]*1.25),
			CFrame.new(center-Vector3.yAxis*.01),color,{material=Enum.Material.Plastic,studded=true,shadow=false})
	end
	return model
end
local function path(parent: Instance, points: {{number}}, width: number, material: Enum.Material?, tint: Color3?, lift: number?)
	-- A joined miter strip avoids coplanar disks/rectangles flickering at every bend.
	local left,right={},{}
	for i,p in points do
		local before=v(points[math.max(1,i-1)])
		local after=v(points[math.min(#points,i+1)])
		local direction=(after-before).Unit
		local normal=Vector3.new(-direction.Z,0,direction.X)
		local point=v(p)+Vector3.yAxis*(-.135+(lift or 0))
		left[i],right[i]=point+normal*width/2,point-normal*width/2
	end
	for i=1,#points-1 do
		triangle(parent,"WornFootpath",left[i],right[i],left[i+1],tint or C.Sand,material or Enum.Material.Plastic,false,false,true)
		triangle(parent,"WornFootpath",right[i],right[i+1],left[i+1],tint or C.Sand,material or Enum.Material.Plastic,false,false,true)
	end
end
local function waypost(parent: Instance, pos: Vector3, title: string, subtitle: string, yaw: number?)
	Kit.beam(parent,"Waypost",pos,pos+Vector3.yAxis*6,0.35,C.Wood,{material=Enum.Material.Wood})
	local board = Kit.part(parent,"TrailSign",Vector3.new(8,2.1,0.3),CFrame.new(pos+Vector3.yAxis*5.3)*CFrame.Angles(0,yaw or 0,0),C.Teal)
	Kit.sign(board,title,subtitle)
end
local function lampPost(parent: Instance, pos: Vector3, lightShadow: boolean?)
	Kit.beam(parent,"TurnedLampPost",pos,pos+Vector3.yAxis*7.6,0.3,C.Iron,{material=Enum.Material.Metal})
	Kit.beam(parent,"CurvedLampArm",pos+Vector3.yAxis*7.6,pos+Vector3.new(1.2,7.6,0),0.2,C.Iron)
	Kit.lantern(parent,pos+Vector3.new(1.2,6,0),0.9,lightShadow)
end
local function water(parent: Instance, data: any)
	local center = v(data.Center)
	-- Native Terrain water supplies Roblox's own wave and reflection shader.
	local min = center - Vector3.new(data.Radius[1]+4, 8, data.Radius[2]+4)
	local max = center + Vector3.new(data.Radius[1]+4, 0, data.Radius[2]+4)
	local region = Region3.new(min,max):ExpandToGrid(4)
	local size = region.Size / 4
	local origin = region.CFrame.Position - region.Size / 2
	local materials, occupancy = {}, {}
	for x = 1, size.X do
		materials[x], occupancy[x] = {}, {}
		for y = 1, size.Y do
			materials[x][y], occupancy[x][y] = {}, {}
			for z = 1, size.Z do
				local p = origin + Vector3.new((x-.5)*4,(y-.5)*4,(z-.5)*4)
				local inside = ((p.X-center.X)/data.Radius[1])^2+((p.Z-center.Z)/data.Radius[2])^2 < 1
				materials[x][y][z] = if inside then Enum.Material.Water else Enum.Material.Air
				occupancy[x][y][z] = if inside then 1 else 0
			end
		end
	end
	workspace.Terrain:WriteVoxels(region,4,materials,occupancy)
	-- Lower basin, exposed stone collar, reeds and a small cascade over the rim.
	local basin = {Id=data.Id.."_lagoon",Name="SuspendedLagoon",Center={center.X,center.Y-5,center.Z},Radius={data.Radius[1]+5,data.Radius[2]+5},Seed=13,Basin=true}
	local model = island(parent,basin,C.Sand,Enum.Material.Plastic)
	for i = 1, 12 do
		local a=i*math.pi/6
		local p=center+Vector3.new(math.cos(a)*(data.Radius[1]+2),-.8,math.sin(a)*(data.Radius[2]+2))
		Nature.rock(model,p,Vector3.new(5.5,2.8,4.6),i*11,true)
	end
	for i = 1, 9 do
		local a = i*2.4
		local glint = Kit.beam(model,"WaterGlint",center+Vector3.new(math.cos(a)*data.Radius[1]*.65,.16,math.sin(a)*data.Radius[2]*.65),
			center+Vector3.new(math.cos(a)*data.Radius[1]*.65+2.5,.16,math.sin(a)*data.Radius[2]*.65),.045,C.Cream,{shadow=false,transparency=.78})
		glint:SetAttribute("GlintPhase",i)
	end
	local fallPos = center + Vector3.new(data.Radius[1]*.45,0,data.Radius[2]*.89)
	for i = -1,1 do
		Kit.part(model,"WaterfallCurtain",Vector3.new(2.8,55,0.2),CFrame.new(fallPos+Vector3.new(i*2.6,-27.5,0)),C.Water,
			{material=Enum.Material.Glass,transparency=.33,shadow=false})
		local streak=Kit.part(model,"FlowStreak",Vector3.new(.14,8,0.1),CFrame.new(fallPos+Vector3.new(i*2.5,-27,0.2)),C.Cream,{shadow=false,transparency=.58})
		streak:SetAttribute("FlowStart",streak.CFrame)
		streak:SetAttribute("FlowPhase",i*.27)
		streak:SetAttribute("FlowDistance",48)
		streak:SetAttribute("FlowSpeed",12)
	end
	Nature.cloud(model,fallPos-Vector3.yAxis*55,Vector3.new(21,8,14),83)
end
local function plaza(parent: Instance)
	Kit.disk(parent,"TownSquare",45,45,.2,Vector3.new(-8,12.11,-2),C.Limestone,{material=Enum.Material.Plastic,studded=true})
	-- Small koi fountain: clear routes pass either side, not through its bowl.
	local f=Kit.model(parent,"CloudKoiFountain")
	Kit.disk(f,"FountainBase",11,11,.4,Vector3.new(-17,12.4,-14),C.Stone,{material=Enum.Material.Marble,collidable=true})
	Kit.disk(f,"Basin",9.6,9.6,.65,Vector3.new(-17,13,-14),C.Limestone,{material=Enum.Material.Marble,collidable=true})
	Kit.disk(f,"FountainWater",8.8,8.8,.08,Vector3.new(-17,13.37,-14),C.Water,{material=Enum.Material.Glass,transparency=.22,shadow=false})
	Kit.disk(f,"Pedestal",2.7,2.7,2,Vector3.new(-17,14,-14),C.Stone,{material=Enum.Material.Marble})
	local koi=Fish.create(f,"GoldenKoi","pufflet")
	koi:PivotTo(CFrame.new(-17,16,-14)*CFrame.Angles(0,.4,.2))
	for _,p in koi:GetChildren() do if p:IsA("BasePart") then p.Material=Enum.Material.Metal; p.Color=C.Brass; p.CastShadow=true end end
end
local function dockWorkshop(parent: Instance)
	local model=Kit.model(parent,"PierRodWorkshop")
	local pos=v(Layout.RodStand)
	local cf=CFrame.lookAt(pos,pos+Vector3.xAxis)
	local wood={material=Enum.Material.Wood}
	-- A working upgrade stop in the fishing loop; the larger town workshop stays open.
	Kit.part(model,"RodCounter",Vector3.new(7,2.6,2),cf*CFrame.new(0,1.3,-1.4),C.Wood,wood)
	Kit.part(model,"CounterTop",Vector3.new(7.5,.25,2.4),cf*CFrame.new(0,2.75,-1.4),C.Plank,wood)
	for _,x in {-3.5,3.5} do
		Kit.beam(model,"WorkshopCanopyPost",cf:PointToWorldSpace(Vector3.new(x,0,1.5)),cf:PointToWorldSpace(Vector3.new(x,7,1.5)),.22,C.Wood,wood)
	end
	Kit.part(model,"SunnyCanopy",Vector3.new(8,.3,5),cf*CFrame.new(0,7,0),C.Gold)
	for _,x in {-2,0,2} do
		Kit.part(model,"CreamCanopyStripe",Vector3.new(.85,.02,5),cf*CFrame.new(x,7.16,0),C.Cream,{shadow=false})
	end
	local board=Kit.part(model,"RodWorkshopSign",Vector3.new(7,1.2,.16),cf*CFrame.new(0,5.7,-2),C.Teal)
	Kit.sign(board,"ROD UPGRADES","Fish · upgrade · cast again")
	for i=0,2 do
		local a=cf:PointToWorldSpace(Vector3.new(-2.2+i*1.9,2.9,.25))
		local b=a+Vector3.new(.2,2.6,0)
		Kit.beam(model,"DisplayRod",a,b,.09,if i==2 then C.Gold else C.Bark,wood)
		Kit.ball(model,"RodReel",Vector3.one*.3,a+Vector3.yAxis*.4,C.Cream,{shadow=false})
	end
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name,prompt.ActionText,prompt.ObjectText="RodWorkshopPrompt","Upgrade rods","Dockside workshop"
	prompt.HoldDuration,prompt.MaxActivationDistance,prompt.RequiresLineOfSight=0,8,false
	prompt.Parent=board
end
local function windmill(parent: Instance, pos: Vector3)
	local model=Kit.model(parent,"PetalwindMill")
	Kit.disk(model,"StonePlinth",12,12,.5,pos+Vector3.yAxis*.25,C.Limestone,{material=Enum.Material.Cobblestone,collidable=true})
	for i=0,7 do
		local a=i*math.pi/4
		Kit.part(model,"MillWall",Vector3.new(4.2,18,.5),CFrame.new(pos+Vector3.new(math.sin(a)*4.6,9,math.cos(a)*4.6))*CFrame.Angles(0,a,0),C.Cream,{material=Enum.Material.Plaster,collidable=true})
	end
	for i=0,7 do
		local a=i*math.pi/4
		Kit.wedge(model,"MillRoof",Vector3.new(4.4,5,6),CFrame.new(pos+Vector3.new(math.sin(a)*2,20,math.cos(a)*2))*CFrame.Angles(0,a,0),C.Teal,{material=Enum.Material.Slate})
	end
	local origin=CFrame.new(pos+Vector3.new(0,15,-6))
	local rotor=Kit.model(model,"MillBlades")
	rotor.WorldPivot=origin
	for i=0,3 do
		local cf=origin*CFrame.Angles(0,0,i*math.pi/2)
		Kit.part(rotor,"SailSpar",Vector3.new(.35,15,.35),cf*CFrame.new(0,7,0),C.Wood,{material=Enum.Material.Wood})
		Kit.part(rotor,"CanvasSail",Vector3.new(2.5,10,.16),cf*CFrame.new(1.2,8.5,0),C.Cream,{material=Enum.Material.Fabric})
		for n=1,4 do Kit.part(rotor,"SailBatten",Vector3.new(2.7,.13,.2),cf*CFrame.new(1.2,4+n*2,0),C.Wood) end
	end
	Kit.ball(rotor,"Hub",Vector3.new(2,2,1),origin.Position,C.Brass,{material=Enum.Material.Metal})
	rotor:SetAttribute("SpinOrigin",origin)
	rotor:SetAttribute("SpinRate",.13)
end
local function hill(parent: Instance, pos: Vector3, width: number, depth: number, height: number)
	local peak=pos+Vector3.yAxis*height
	for i=1,10 do
		local a,b=i*math.pi/5,(i+1)*math.pi/5
		triangle(parent,"GrassyKnoll",peak,pos+Vector3.new(math.cos(a)*width/2,.04,math.sin(a)*depth/2),
			pos+Vector3.new(math.cos(b)*width/2,.04,math.sin(b)*depth/2),C.Grass,Enum.Material.Plastic,true,true,true)
	end
end
local function townDetails(parent: Instance)
	-- Waist-high planters frame the square without blocking either main route.
	for i,pos in {Vector3.new(-34,12,-9),Vector3.new(21,12,19),Vector3.new(-18,12,31)} do
		local model=Kit.model(parent,"SquarePlanter")
		Kit.part(model,"LimestoneBox",Vector3.new(9,.9,4),CFrame.new(pos+Vector3.yAxis*.45),C.Limestone,{material=Enum.Material.Limestone,collidable=true})
		Kit.part(model,"DarkSoil",Vector3.new(8.3,.12,3.3),CFrame.new(pos+Vector3.yAxis*.96),C.Wood,{material=Enum.Material.Ground,shadow=false})
		Nature.garden(model,pos+Vector3.yAxis*1.05,Vector2.new(3.4,1.2),8,i*71,"Lavender")
	end
	Architecture.props(parent,CFrame.new(-26,12,23)*CFrame.Angles(0,math.pi/2,0),"Picnic")
	Architecture.props(parent,CFrame.new(30,12,53)*CFrame.Angles(0,-.4,0),"Picnic")
	-- A generous casting entrance: beam and lights sit above avatar head height.
	local gate=Kit.model(parent,"SundriftPierGateway")
	for _,x in {-13,13} do
		Kit.beam(gate,"TurnedPierPost",Vector3.new(x,12,84),Vector3.new(x,23,84),.8,C.Wood,{material=Enum.Material.Wood,collidable=true})
		Kit.beam(gate,"GatewayBrace",Vector3.new(x,20,84),Vector3.new(x*.7,23,84),.4,C.Wood)
		Kit.lantern(gate,Vector3.new(x*.85,20.4,84),1,false)
	end
	Kit.part(gate,"CarvedLintel",Vector3.new(28,.7,1),CFrame.new(0,23,84),C.Wood,{material=Enum.Material.Wood})
	local sign=Kit.part(gate,"PierName",Vector3.new(13,2.7,.28),CFrame.new(0,21.3,83.7),C.Teal)
	Kit.sign(sign,"SUNDRIFT PIER","A new discovery is one cast away")
	for _,x in {-9,9} do
		local banner=Kit.part(gate,"LinenPennant",Vector3.new(1.3,3.1,.06),CFrame.new(x,21,84),C.Coral,{material=Enum.Material.Fabric})
		banner.CanCollide=false
	end
	hill(parent,Vector3.new(76,12,64),33,30,5)
	Nature.tree(parent,Vector3.new(76,17,64),.9,"Oak",233)
	hill(parent,Vector3.new(-102,12,-31),28,33,4)
	Nature.tree(parent,Vector3.new(-102,16,-31),.85,"Oak",237)
end
local function grotto(parent: Instance, cf: CFrame)
	local model=Kit.model(parent,"TideglassGrotto")
	for _,side in {-1,1} do
		Kit.wedge(model,"WeatheredArchPillar",Vector3.new(8,13,12),cf*CFrame.new(side*8,6.5,0)*CFrame.Angles(0,side*math.pi/2,0),C.DeepStone,{material=Enum.Material.Slate,collidable=true})
		Kit.part(model,"PillarCore",Vector3.new(5,12,8),cf*CFrame.new(side*8,6,-1),C.Cliff,{material=Enum.Material.Slate,collidable=true})
	end
	Kit.part(model,"ShadedCaveRoof",Vector3.new(24,5,13),cf*CFrame.new(0,14,0),C.Cliff,{material=Enum.Material.Slate,collidable=true})
	Kit.part(model,"CaveBackWall",Vector3.new(24,12,1),cf*CFrame.new(0,6,5.5),C.DeepStone,{material=Enum.Material.Slate,collidable=true})
	Nature.rock(model,cf:PointToWorldSpace(Vector3.new(-3,16.3,1)),Vector3.new(19,5,12),607,true)
	for i=1,6 do
		local x=(i-3.5)*1.4
		local crystal=Kit.wedge(model,"TideglassCrystal",Vector3.new(.8,2+i%3,1),cf*CFrame.new(x,1.1,3.6)*CFrame.Angles(0,i*.6,-.12+x*.03),
			if i%2==0 then C.Water else C.Lavender,{material=Enum.Material.Neon,shadow=false})
		crystal.Transparency=.12
	end
	local sign=Kit.part(model,"GrottoPlaque",Vector3.new(5.4,1.6,.2),cf*CFrame.new(9,2,-6.3),C.Teal)
	Kit.sign(sign,"TIDEGLASS GROTTO","A little shade beneath the palms")
end
local function skyship(parent: Instance)
	local model=Kit.model(parent,"SkySail")
	local o=Vector3.new(15,91,266)
	Kit.ball(model,"LinenEnvelope",Vector3.new(25,19,48),o,C.Cream,{material=Enum.Material.Fabric})
	for _,z in {-12,0,12} do
		Kit.ball(model,"EnvelopeBand",Vector3.new(25.25,19.25,2.6),o+Vector3.new(0,0,z),C.Coral,{material=Enum.Material.Fabric})
	end
	Kit.part(model,"BoatCabin",Vector3.new(9,5,16),CFrame.new(o+Vector3.new(0,-17,0)),C.Wood,{material=Enum.Material.WoodPlanks})
	for _,x in {-4.6,4.6} do
		for _,z in {-7,7} do Kit.beam(model,"AirshipRigging",o+Vector3.new(x,-15,z),o+Vector3.new(x,-7,z*1.5),.13,C.Iron) end
	end
	Kit.wedge(model,"TailFin",Vector3.new(.4,10,12),CFrame.new(o+Vector3.new(0,1,26)),C.Teal,{material=Enum.Material.Fabric})
	model:SetAttribute("DriftOrigin",model:GetPivot())
end
function World.create(): BasePart
	assert(not workspace:FindFirstChild("MolnfiskarnaPrototype"),"World already exists. Disable CreatePrototypeWorld to use a custom map.")
	local root=Instance.new("Folder")
	root.Name="MolnfiskarnaPrototype"
	-- Build before parenting: each streamed model arrives with its geometry/attributes.
	local regions={}
	-- An early spawn platform holds joining avatars while the larger world is built.
	local spawn=Instance.new("SpawnLocation")
	spawn.Name,spawn.Size,spawn.CFrame="HarborSpawn",Vector3.new(14,.3,14),CFrame.new(v(Layout.Spawn)+Vector3.yAxis*.2)*CFrame.Angles(0,math.pi,0)
	spawn.Anchored,spawn.Neutral,spawn.Duration,spawn.Transparency,spawn.CastShadow=true,true,0,1,false
	spawn.Parent=workspace
	Lighting.ClockTime,Lighting.Brightness,Lighting.GlobalShadows=13.7,3,true
	Lighting.ShadowSoftness=.12
	Lighting.Ambient,Lighting.OutdoorAmbient=Color3.fromRGB(120,145,159),Color3.fromRGB(178,195,207)
	Lighting.EnvironmentDiffuseScale,Lighting.EnvironmentSpecularScale=.25,.05
	local atmosphere=Instance.new("Atmosphere")
	atmosphere.Name,atmosphere.Density,atmosphere.Offset,atmosphere.Haze,atmosphere.Glare="SundriftAtmosphere",.06,0,0,0
	atmosphere.Color,atmosphere.Decay,atmosphere.Parent=Color3.fromRGB(180,220,255),Color3.fromRGB(146,194,243),Lighting
	local sky=Instance.new("Sky")
	sky.Name,sky.SunAngularSize,sky.MoonAngularSize,sky.StarCount,sky.Parent="SundriftSky",9,9,800,Lighting
	local clouds=Instance.new("Clouds")
	clouds.Name,clouds.Cover,clouds.Density,clouds.Color,clouds.Parent="HighClouds",.12,.2,C.Cloud,workspace.Terrain
	local color=Instance.new("ColorCorrectionEffect")
	color.Name,color.Saturation,color.Contrast,color.TintColor,color.Parent="HarborGrade",.05,.04,Color3.fromRGB(255,255,255),Lighting
	local bloom=Instance.new("BloomEffect")
	bloom.Name,bloom.Intensity,bloom.Threshold,bloom.Size,bloom.Parent="LanternBloom",.035,2.2,24,Lighting
	local rays=Instance.new("SunRaysEffect")
	rays.Intensity,rays.Spread,rays.Parent=.01,.85,Lighting
	workspace.Terrain.WaterColor,workspace.Terrain.WaterReflectance,workspace.Terrain.WaterTransparency=C.Water,.03,.18
	workspace.Terrain.WaterWaveSize,workspace.Terrain.WaterWaveSpeed=.08,4
	for _,data in Layout.Islands do
		local tint=if data.Kind=="Cove" then C.Sand elseif data.Kind=="Summit" then C.Moss else C.Grass
		regions[data.Id]=island(root,data,tint,Enum.Material.Plastic)
	end
	for i,data in Layout.Paths do path(regions[data.Island],data.Points,data.Width,nil,nil,i*.012) end
	-- The fountain has a broad walkable ring; the main trail goes around its center.
	plaza(regions.harbor)
	townDetails(regions.harbor)
	dockWorkshop(regions.harbor)
	Architecture.cottage(regions.harbor,CFrame.new(52,12,-20)*CFrame.Angles(0,math.pi,0),26,22,Color3.fromRGB(220,215,176),"Workshop")
	Architecture.cottage(regions.harbor,CFrame.new(-52,12,-20)*CFrame.Angles(0,math.pi,0),26,22,Color3.fromRGB(237,207,169),"Cafe")
	Architecture.cottage(regions.harbor,CFrame.new(67,12,-48)*CFrame.Angles(0,math.pi/4,0),21,18,Color3.fromRGB(208,218,183),"Cottage")
	Architecture.lighthouse(regions.harbor,CFrame.new(-48,12,-60))
	Architecture.props(regions.harbor,CFrame.new(-72,12,43)*CFrame.Angles(0,-.3,0),"Market")
	Architecture.props(regions.harbor,CFrame.new(66,12,43),"Market")
	Architecture.props(regions.harbor,CFrame.new(-46,12,27),"Picnic")
	Architecture.props(regions.harbor,CFrame.new(16,12,85),"Fishing")
	windmill(regions.blossom,Vector3.new(-272,28,35))
	Architecture.props(regions.blossom,CFrame.new(-216,28,47),"Picnic")
	Architecture.cottage(regions.forest,CFrame.new(299,24,-36)*CFrame.Angles(0,math.pi/2,0),20,17,Color3.fromRGB(184,201,169),"Cottage")
	Architecture.props(regions.forest,CFrame.new(249,24,45),"Fishing")
	Architecture.ruins(regions.summit,CFrame.new(244,60,-268))
	Architecture.props(regions.summit,CFrame.new(285,60,-224),"Picnic")
	Architecture.props(regions.cove,CFrame.new(-250,4,-235),"Fishing")
	Architecture.props(regions.cove,CFrame.new(-211,4,-201),"Picnic")
	grotto(regions.cove,CFrame.new(-227,4,-246)*CFrame.Angles(0,math.pi,0))
	for _,bridge in Layout.Bridges do
		local points=Layout.bridgePoints(bridge)
		for i=1,#points-1 do Architecture.dock(root,v(points[i]),v(points[i+1]),bridge.Width,bridge.Id.."_"..i,true) end
	end
	local spots=Instance.new("Folder")
	spots.Name,spots.Parent="FishingSpots",root
	local first: BasePart?=nil
	for _,data in Layout.Waters do water(root,data) end
	for _,dock in Layout.Docks do
		local deck=Architecture.dock(root,v(dock.A),v(dock.B),dock.Width,dock.Id.."_pier",true)
		local zone=nil
		for _,w in Layout.Waters do if w.Id==dock.Id then zone=w end end
		local spot=Kit.part(spots,"FishingSpot",Vector3.new(dock.Width-5,.05,10),CFrame.new(v(dock.Spot))*CFrame.Angles(0,dock.Yaw,0),C.Teal,{transparency=.72,shadow=false})
		spot:SetAttribute("ZoneId",dock.Id)
		for _,region in Layout.Islands do if region.Id==dock.Id then spot:SetAttribute("ZoneName",region.Name) end end
		spot:SetAttribute("WaterY",zone.Center[2])
		if not first then first=spot end
		local basis=CFrame.lookAt(v(dock.A),v(dock.B))
		Architecture.props(deck,basis*CFrame.new(dock.Width*.34,0,-5),"Fishing")
	end
	-- Deliberate clearings keep the paths, entrances and vistas open.
	local trees: {{any}}={
		{"harbor",-92,12,-25,1.25,"Oak"},{"harbor",90,12,34,1.35,"Oak"},{"harbor",-87,12,65,1.2,"Oak"},
		{"harbor",45,12,-72,1.05,"Blossom"},{"harbor",-75,12,-72,1.15,"Oak"},{"harbor",86,12,-17,1.0,"Oak"},
		{"blossom",-283,28,-23,1.25,"Blossom"},{"blossom",-211,28,-20,1.2,"Blossom"},{"blossom",-290,28,64,1.1,"Blossom"},
		{"blossom",-223,28,55,1,"Blossom"},{"blossom",-268,28,-35,1.15,"Blossom"},
		{"forest",221,24,27,1.25,"Pine"},{"forest",235,24,-42,1.65,"Pine"},{"forest",289,24,49,1.35,"Pine"},
		{"forest",319,24,3,1.7,"Pine"},{"forest",300,24,-65,1.3,"Pine"},{"forest",281,24,-66,1.15,"Pine"},
		{"forest",228,24,48,1.2,"Oak"},{"forest",307,24,30,1.1,"Pine"},
		{"cove",-269,4,-179,1.4,"Palm"},{"cove",-199,4,-236,1.55,"Palm"},{"cove",-259,4,-251,1.2,"Palm"},
		{"cove",-207,4,-167,1.15,"Palm"},{"cove",-278,4,-226,1.3,"Palm"},
		{"summit",219,60,-213,.95,"Pine"},{"summit",291,60,-274,1.1,"Pine"},
	}
	for i,t in trees do Nature.tree(regions[t[1]],Vector3.new(t[2],t[3],t[4]),t[5],t[6],i*17) end
	local gardens: {{any}}={
		{"harbor",-30,12,-25,10,7,20},{"harbor",28,12,35,14,9,24},{"harbor",-36,12,61,15,8,22},
		{"blossom",-280,28,1,11,9,24},{"blossom",-213,28,33,9,8,20},{"forest",239,24,23,12,10,25},
		{"forest",293,24,19,11,7,22},{"summit",223,60,-266,12,9,24},{"cove",-253,4,-185,9,8,18},
	}
	for i,g in gardens do Nature.garden(regions[g[1]],Vector3.new(g[2],g[3],g[4]),Vector2.new(g[5],g[6]),math.ceil(g[7]*.45),i*53,if g[1]=="summit" then "Lavender" else "Grass") end
	for i,pos in {Vector3.new(-95,12,34),Vector3.new(87,12,-58),Vector3.new(-289,28,38),Vector3.new(321,24,-29),Vector3.new(-182,4,-211),Vector3.new(210,60,-254)} do
		Nature.rock(root,pos,Vector3.new(11+i%3*2,8+i%2*4,9),i*19,true)
	end
	for _,p in {Vector3.new(-20,12,-35),Vector3.new(20,12,42),Vector3.new(-18,12,75),Vector3.new(-105,12,18),Vector3.new(107,12,12)} do lampPost(root,p,false) end
	waypost(root,Vector3.new(20,12,-19),"SUNDRIFT HARBOR","Rod & Reel / Main Pier")
	waypost(root,Vector3.new(-94,12,20),"PETALWIND GROVE","Blossom walks / Tideglass Cove",math.pi/2)
	waypost(root,Vector3.new(96,12,-10),"EVERGREEN REACH","Forest Pier / Starfall Lookout",-math.pi/2)
	waypost(root,Vector3.new(274,24,-67),"STARFALL LOOKOUT","Follow the rising bridge")
	waypost(root,Vector3.new(-261,28,-33),"TIDEGLASS COVE","Palm shade / Quiet water")
	spawn.Parent=root
	local preview=Fish.create(root,"PuffletPreview","pufflet")
	local display=CFrame.new(0,12,162)
	preview:PivotTo(display)
	preview:SetAttribute("DisplayOrigin",display)
	skyship(root)
	-- Distant cloud banks frame the playable islands rather than covering walkways.
	for i=1,14 do
		local a=i*math.pi/7
		Nature.cloud(root,Vector3.new(math.cos(a)*490,-72,math.sin(a)*390-40),Vector3.new(88,22,55),i*13)
	end
	Landscaping.populate(root,regions)
	DockDetails.populate(root)
	TrailDetails.populate(root,regions)
	local population=Residents.populate(root)
	PondBackdrops.populate(root)
	local largeModels: {[Instance]: boolean}={[population]=true}
	for _,region in regions do largeModels[region]=true end
	for _,model in root:GetDescendants() do
		if model:IsA("Model") and not largeModels[model] and model.Name~="SuspendedLagoon" then
			model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
		end
	end
	root.Parent=workspace
	assert(first,"Map needs a primary fishing spot")
	return first
end
function World.findCustom(): BasePart
	local folder=workspace:FindFirstChild("World")
	local spot=if folder then folder:FindFirstChild("FishingSpot") else nil
	assert(spot and spot:IsA("BasePart"),"Create an anchored Part at Workspace.World.FishingSpot.")
	return spot :: BasePart
end
return World
