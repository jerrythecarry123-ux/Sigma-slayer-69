--!strict
-- Small, authored fishing scenes live on the outside edges of the piers.
-- They add no prompts, touch events, camera obstacles or gameplay state.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local C = Kit.palette
local Details = {}

local LABELS = {
	harbor = "SUNDRIFT HARBOR", blossom = "PETALWIND GROVE", forest = "EVERGREEN REACH",
	cove = "TIDEGLASS COVE", summit = "STARFALL LOOKOUT",
}

local function part(parent: Model, name: string, size: Vector3, cf: CFrame, color: Color3, studded: boolean?): Part
	return Kit.part(parent, name, size, cf, color, {
		material = Enum.Material.Plastic, studded = studded == true,
		shadow = math.max(size.X, size.Y, size.Z) >= 1.2,
	})
end

local function beam(parent: Model, name: string, cf: CFrame, a: Vector3, b: Vector3, width: number, color: Color3)
	Kit.beam(parent, name, cf:PointToWorldSpace(a), cf:PointToWorldSpace(b), width, color,
		{ material = Enum.Material.Plastic, shadow = (b-a).Magnitude >= 1.2 })
end

local function cylinder(parent: Model, name: string, diameter: number, depth: number, height: number, cf: CFrame, color: Color3): Part
	local value = part(parent, name, Vector3.new(height, diameter, depth), cf * CFrame.Angles(0, 0, math.pi / 2), color)
	value.Shape = Enum.PartType.Cylinder
	return value
end

local function tackle(parent: Model, cf: CFrame, accent: Color3)
	part(parent, "PaintedTackleBox", Vector3.new(1.8, .85, 1.25), cf*CFrame.new(0,.49,0), accent, true)
	part(parent, "CreamTackleLid", Vector3.new(1.94,.16,1.37), cf*CFrame.new(0,.995,0), C.Cream, true)
	for _, x in {-.56,.56} do
		part(parent, "TackleBoxHinge", Vector3.new(.24,.15,.18), cf*CFrame.new(x,.93,.66), C.Brass)
	end
	part(parent, "BrassTackleLatch", Vector3.new(.28,.33,.1), cf*CFrame.new(0,.86,-.68), C.Brass)
	beam(parent, "TackleCarryingHandle", cf, Vector3.new(-.45,1.13,0), Vector3.new(.45,1.13,0), .12, C.Iron)
	part(parent, "OpenLureTray", Vector3.new(1.8,.12,.78), cf*CFrame.new(0,.1,-1.22), C.Wood)
	for index, tint in {C.Coral,C.Gold} do
		local x = (index-1.5)*.68
		Kit.wedge(parent, "PaintedFishingLure", Vector3.new(.22,.18,.54),
			cf*CFrame.new(x,.28,-1.22)*CFrame.Angles(0,math.pi/2,0), tint, {shadow=false})
		Kit.wedge(parent, "LureSilverTail", Vector3.new(.08,.18,.24),
			cf*CFrame.new(x+.28,.25,-1.22)*CFrame.Angles(0,-math.pi/2,0), C.Cream, {shadow=false})
	end
end

local function bucket(parent: Model, cf: CFrame, accent: Color3)
	cylinder(parent, "CreelBottom", 1.12, 1.12, .12, cf*CFrame.new(0,.1,0), C.Wood)
	cylinder(parent, "PaintedRoundCreel", 1.05, 1.05, 1, cf*CFrame.new(0,.65,0), accent)
	cylinder(parent, "CreelOpenInterior", .86, .86, .025, cf*CFrame.new(0,1.158,0), C.DeepStone)
	beam(parent, "BucketCarryHandle", cf, Vector3.new(-.51,1.04,.35), Vector3.new(-.36,1.55,.35), .085, C.Iron)
	beam(parent, "BucketCarryHandle", cf, Vector3.new(-.36,1.55,.35), Vector3.new(.36,1.55,.35), .085, C.Iron)
	beam(parent, "BucketCarryHandle", cf, Vector3.new(.36,1.55,.35), Vector3.new(.51,1.04,.35), .085, C.Iron)
	cylinder(parent, "CreamFishingFloat", .28, .28, .72, cf*CFrame.new(.17,.91,-.03)*CFrame.Angles(.18,0,-.22), C.Cream)
	cylinder(parent, "CoralFloatTip", .29, .29, .23, cf*CFrame.new(.23,1.17,-.08)*CFrame.Angles(.18,0,-.22), C.Coral)
end

local function rodRack(parent: Model, cf: CFrame)
	for _, z in {-.65,.65} do
		part(parent, "RodRackPost", Vector3.new(.18,1.65,.18), cf*CFrame.new(0,.88,z), C.Wood)
	end
	part(parent, "RodRackCrosspiece", Vector3.new(.23,.23,1.7), cf*CFrame.new(0,1.55,0), C.Plank)
	beam(parent, "RestingSpareRod", cf, Vector3.new(.12,.18,-.46), Vector3.new(-.17,3.72,.43), .07, C.Gold)
	local reel=Kit.disk(parent, "SpareRodReel", .29,.29,.16, cf:PointToWorldSpace(Vector3.new(.1,.76,-.31)), C.Teal,
		{ material = Enum.Material.Plastic, shadow = false })
	reel.CFrame=cf*CFrame.new(.1,.76,-.31)
end

local function railTrim(parent: Model, basis: CFrame, width: number, length: number, index: number, name: string)
	for _, x in {-width/2+.25,width/2-.25} do
		for _, z in {-.5,-length+.5} do
			cylinder(parent, "CreamPierCornerBumper", .75, .75, 1.65, basis*CFrame.new(x,1.3,z), C.Cream)
		end
		part(parent, "MooringCleatFoot", Vector3.new(.64,.13,1.1), basis*CFrame.new(x,.19,-11), C.Iron)
		part(parent, "MooringCleatHorn", Vector3.new(.23,.18,1.43), basis*CFrame.new(x,.33,-11), C.Brass)
	end
	-- Front normal faces inward from the left rail; arriving anglers can read it.
	local plaque = part(parent, "PaintedPierNameplate", Vector3.new(4.7,1.35,.13),
		basis*CFrame.new(width/2-.17,2.25,-13)*CFrame.Angles(0,math.pi/2,0), C.Teal)
	Kit.sign(plaque,name,string.format("PIER %02d  /  CAST · COLLECT · EXPLORE",index),C.Cream)
end

local function lifeRing(parent: Model, cf: CFrame)
	-- Twelve short round sections make a recognizable open lifebuoy rather
	-- than a square outline. Its rope stays attached to the pier edge.
	for index=0,11 do
		local a, b = index*math.pi/6, (index+1)*math.pi/6
		beam(parent,"SegmentedLifeBuoy",cf,
			Vector3.new(math.cos(a)*.9,1.65+math.sin(a)*.9,0),
			Vector3.new(math.cos(b)*.9,1.65+math.sin(b)*.9,0),.3,
			if index%3==0 then C.Coral else C.Cream)
	end
	beam(parent,"SafetyRingHanger",cf,Vector3.new(-.38,2.7,.12),Vector3.new(.38,2.7,.12),.1,C.Iron)
end

local function teaBreak(parent: Model, cf: CFrame)
	part(parent,"PicnicTeaTray",Vector3.new(1.65,.14,1.45),cf*CFrame.new(0,.13,0),C.Plank,true)
	cylinder(parent,"BlueTeaFlask",.59,.59,1.35,cf*CFrame.new(-.42,.86,.03),C.Teal)
	cylinder(parent,"FlaskCreamLid",.65,.65,.2,cf*CFrame.new(-.42,1.63,.03),C.Cream)
	cylinder(parent,"TeaFlaskStripe",.61,.61,.16,cf*CFrame.new(-.42,.77,.03),C.Gold)
	for _, z in {-.38,.38} do
		cylinder(parent,"GlazedTeaCup",.43,.43,.4,cf*CFrame.new(.43,.41,z),C.Cream)
		cylinder(parent,"WarmTeaSurface",.3,.3,.025,cf*CFrame.new(.43,.615,z),C.Bark)
		beam(parent,"TeaCupHandle",cf,Vector3.new(.61,.54,z),Vector3.new(.78,.5,z),.075,C.Gold)
		beam(parent,"TeaCupHandle",cf,Vector3.new(.78,.5,z),Vector3.new(.78,.36,z),.075,C.Gold)
		beam(parent,"TeaCupHandle",cf,Vector3.new(.78,.36,z),Vector3.new(.61,.31,z),.075,C.Gold)
	end
end

local function forestKeepsake(parent: Model, cf: CFrame)
	for index=0,2 do
		beam(parent,"NeatlyStackedFirewood",cf,Vector3.new((index-1)*.61,.34,-.9),Vector3.new((index-1)*.61,.34,.9),.57,C.Bark)
		cylinder(parent,"FirewoodCutEnd",.47,.43,.025,cf*CFrame.new((index-1)*.61,.34,-.915)*CFrame.Angles(math.pi/2,0,0),C.Plank)
	end
	part(parent,"ExplorerCompassCase",Vector3.new(.9,.16,.9),cf*CFrame.new(0,.71,.1),C.Brass)
	part(parent,"CompassIvoryDial",Vector3.new(.73,.025,.73),cf*CFrame.new(0,.805,.1),C.Cream)
	part(parent,"CompassRedNeedle",Vector3.new(.07,.04,.54),cf*CFrame.new(0,.84,.1)*CFrame.Angles(0,.45,0),C.Coral)
end

local function beachKeepsake(parent: Model, cf: CFrame)
	part(parent,"FoundShellTray",Vector3.new(1.7,.1,1.2),cf*CFrame.new(0,.12,0),C.Plank,true)
	for index=0,2 do
		local x=(index-1)*.48
		local shell=cf*CFrame.new(x,.3,(index%2)*.25-.1)*CFrame.Angles(0,index*.5,0)
		Kit.wedge(parent,"TaperedBeachShell",Vector3.new(.43,.19,.56),shell,C.Cream,{shadow=false})
		part(parent,"CoralShellRidge",Vector3.new(.055,.045,.48),shell*CFrame.new(0,.115,0),C.Coral)
	end
	beam(parent,"BeachPennantPole",cf,Vector3.new(.88,0,.4),Vector3.new(.88,2.85,.4),.09,C.Wood)
	Kit.wedge(parent,"BlueBeachPennant",Vector3.new(.05,.62,.95),cf*CFrame.new(.88,2.4,-.1),C.Teal,{shadow=false})
	Kit.wedge(parent,"GoldPennantTip",Vector3.new(.06,.25,.31),cf*CFrame.new(.88,2.55,-.66),C.Gold,{shadow=false})
end

local function skyKeepsake(parent: Model, cf: CFrame)
	part(parent,"WeatherVaneFoot",Vector3.new(1.3,.23,1.3),cf*CFrame.new(0,.18,0),C.Stone,true)
	beam(parent,"WeatherVaneMast",cf,Vector3.new(0,.28,0),Vector3.new(0,3.8,0),.13,C.Brass)
	beam(parent,"WeatherVaneEastWest",cf,Vector3.new(-.88,2.53,0),Vector3.new(.88,2.53,0),.075,C.Brass)
	beam(parent,"WeatherVaneNorthSouth",cf,Vector3.new(0,2.53,-.85),Vector3.new(0,2.53,.85),.075,C.Brass)
	for _, x in {-.9,.9} do
		part(parent,"BlueDirectionTab",Vector3.new(.35,.29,.12),cf*CFrame.new(x,2.53,0),C.Teal)
	end
	part(parent,"StarVaneGoldCore",Vector3.new(.54,.54,.16),cf*CFrame.new(0,3.8,0)*CFrame.Angles(0,0,math.pi/4),C.Gold)
	part(parent,"StarVaneLongArms",Vector3.new(.2,1.04,.17),cf*CFrame.new(0,3.8,0),C.Gold)
	part(parent,"StarVaneCrossArms",Vector3.new(1.04,.2,.17),cf*CFrame.new(0,3.8,0),C.Gold)
end

function Details.populate(root: Instance)
	for index,dock in Layout.Docks do
		local model=Kit.model(root,dock.Id.."DockDetails")
		model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
		local basis=CFrame.new(table.unpack(dock.A))*CFrame.Angles(0,dock.Yaw,0)
		local edge=-dock.Width/2+1.35
		local accent=if dock.Id=="blossom" then C.Blossom elseif dock.Id=="cove" then C.Coral else C.Teal
		tackle(model,basis*CFrame.new(edge,0,-2.8),accent)
		bucket(model,basis*CFrame.new(edge-.15,0,-5.4),accent)
		rodRack(model,basis*CFrame.new(edge-.4,0,-8))
		local a,b=dock.A,dock.B
		local length=math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)
		railTrim(model,basis,dock.Width,length,index,LABELS[dock.Id])
		local keepsake=basis*CFrame.new(edge-.35,0,-16)
		if dock.Id=="harbor" then
			lifeRing(model,keepsake*CFrame.Angles(0,math.pi/2,0))
		elseif dock.Id=="blossom" then teaBreak(model,keepsake)
		elseif dock.Id=="forest" then forestKeepsake(model,keepsake)
		elseif dock.Id=="cove" then beachKeepsake(model,keepsake)
		else skyKeepsake(model,keepsake) end
	end
end

return Details
