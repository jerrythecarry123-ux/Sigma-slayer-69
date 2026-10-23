--!strict
-- Five small, authored rest stops beside the trails. These are scenery rather
-- than interaction points; the walking routes and their collisions stay clear.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local C = Kit.palette
local Details = {}

local WOOD_PARTS = {
	BenchBackSupport = true, BenchTrestleFoot = true, BenchArmrest = true,
	PaintedPierDirection = true,
}
local PLANK_PARTS = { WornBenchSeat = true, BenchBackSlat = true }
local CLOTH_PARTS = { HarborGuideCover = true, GoldenGuideBookmark = true }

local function part(parent: Instance, cf: CFrame, name: string, size: Vector3, offset: Vector3, tint: Color3, tiny: boolean?): Part
	local material = if PLANK_PARTS[name] then Enum.Material.WoodPlanks
		elseif WOOD_PARTS[name] then Enum.Material.Wood
		elseif CLOTH_PARTS[name] then Enum.Material.Fabric
		elseif name == "CompassNorthNeedle" then Enum.Material.Metal
		else Enum.Material.SmoothPlastic
	return Kit.part(parent, name, size, cf * CFrame.new(offset), tint,
		{ material = material, shadow = tiny ~= true })
end

local function clearTrail(region: string, center: Vector3)
	-- The entire scene fits inside this radius, including the projecting sign.
	-- Keep it beyond the full authored path edge, not only its center line.
	for _, route in Layout.Paths do
		if route.Island ~= region then continue end
		for i = 1, #route.Points - 1 do
			local a, b = route.Points[i], route.Points[i + 1]
			local dx, dz = b[1] - a[1], b[3] - a[3]
			local t = math.clamp(((center.X-a[1])*dx+(center.Z-a[3])*dz)/(dx*dx+dz*dz), 0, 1)
			local distance = Vector2.new(center.X-a[1]-dx*t, center.Z-a[3]-dz*t).Magnitude
			assert(distance >= route.Width/2 + 8.75, region .. " rest stop crosses its trail")
		end
	end
end

local function bench(parent: Instance, cf: CFrame)
	part(parent, cf, "WornBenchSeat", Vector3.new(7.6, .32, 2.1), Vector3.new(0, 1.68, 0), C.Plank)
	for _, y in {2.55, 3.16} do
		part(parent, cf, "BenchBackSlat", Vector3.new(7.6, .38, .2), Vector3.new(0, y, .83), C.Plank)
	end
	for _, side in {-1, 1} do
		-- Rear uprights meet both back slats and the cantilevered armrests.
		part(parent, cf, "BenchBackSupport", Vector3.new(.3, 3.35, .3), Vector3.new(side * 3.65, 1.675, .76), C.Wood)
		part(parent, cf, "BenchTrestleFoot", Vector3.new(.36, 1.52, 1.8), Vector3.new(side * 2.8, .76, 0), C.Bark)
	end
	for _, x in {-3.65, 3.65} do
		part(parent, cf, "BenchArmrest", Vector3.new(.35, .22, 2.2), Vector3.new(x, 2.22, 0), C.Wood)
	end
end

local function flowerpot(parent: Instance, cf: CFrame, x: number, accent: Color3)
	local base = cf * CFrame.new(x, 0, .45)
	local smooth = { material = Enum.Material.SmoothPlastic, shadow = false }
	Kit.disk(parent, "GlazedTrailFlowerpot", 1.65, 1.65, .74, (base*CFrame.new(0,.37,0)).Position, accent,
		{ material = Enum.Material.SmoothPlastic, reflectance = .025 })
	Kit.disk(parent, "FlowerpotSoil", 1.38, 1.38, .06, (base*CFrame.new(0,.75,0)).Position, C.Bark,
		{ material = Enum.Material.Ground, shadow = false })
	Kit.beam(parent, "FlowerStem", (base*CFrame.new(0,.77,0)).Position,
		(base*CFrame.new(0,1.91,0)).Position, .09, C.Moss, smooth)
	Kit.wedge(parent, "PointedPottedLeaf", Vector3.new(.08,.54,.9),
		base*CFrame.new(.25,1.2,.05)*CFrame.Angles(-.25,.6,math.pi/2),C.Leaf,smooth)
	for petal=0,2 do
		local rosette=base*CFrame.new(0,1.91,0)*CFrame.Angles(0,petal*math.pi*2/3,0)*CFrame.new(0,0,-.24)
		Kit.wedge(parent,"PottedRosettePetal",Vector3.new(.51,.1,.63),rosette,accent:Lerp(C.Cream,.22),smooth)
	end
	Kit.disk(parent, "PollenHeart", .24, .24, .12, (base*CFrame.new(0,2.01,0)).Position, C.Gold, smooth)
end

local function waymarker(parent: Instance, cf: CFrame, zone: string, title: string, accent: Color3)
	local direction = 1
	for _, dock in Layout.Docks do
		if dock.Id == zone then
			local toward = Vector3.new(dock.A[1], dock.A[2], dock.A[3]) - cf.Position
			direction = if cf.RightVector:Dot(toward) >= 0 then 1 else -1
			break
		end
	end
	Kit.beam(parent,"TrailMarkerPost",(cf*CFrame.new(5.8,0,-1.25)).Position,
		(cf*CFrame.new(5.8,3.8,-1.25)).Position,.24,C.Bark,{ material=Enum.Material.Wood })
	local board = part(parent, cf, "PaintedPierDirection", Vector3.new(2.9, 1.15, .18), Vector3.new(5.8, 3.3, -1.25), accent)
	local brightBoard = zone == "blossom" or zone == "cove" or zone == "summit"
	local ink = if brightBoard then C.Iron:Lerp(Color3.new(0, 0, 0), .35) else C.Cream
	Kit.sign(board, title, "Follow the trail", ink)
	Kit.wedge(parent, "TrailArrowPoint", Vector3.new(.15, .75, .85),
		cf * CFrame.new(5.8 + direction * 1.85, 3.3, -1.25) * CFrame.Angles(0, -direction * math.pi/2, 0),
		accent, { material = Enum.Material.Wood, shadow = false })
end

local function motif(parent: Instance, cf: CFrame, zone: string)
	if zone == "harbor" then
		-- A little closed trail guide rests on the bench; it is not a fake button.
		part(parent, cf, "HarborGuidePages", Vector3.new(.86, .07, 1.03), Vector3.new(-1.8, 1.875, -.1), C.Cream, true)
		part(parent, cf, "HarborGuideCover", Vector3.new(.95, .055, 1.15), Vector3.new(-1.8, 1.936, -.1), C.Teal, true)
		part(parent, cf, "GoldenGuideBookmark", Vector3.new(.09, .025, .7), Vector3.new(-1.62, 1.976, -.1), C.Gold, true)
	elseif zone == "blossom" then
		for i = 1, 3 do
			local petal = part(parent, cf, "FallenTrailBlossom", Vector3.new(.82, .055, .48),
				Vector3.new((i-2)*1.2, .07, -1.8-(i%2)*.4), C.Blossom:Lerp(C.BlossomLight, i*.13), true)
			petal.CFrame *= CFrame.Angles(0, i*.65, 0)
		end
	elseif zone == "forest" then
		Kit.ball(parent,"FallenPinecone",Vector3.new(.6,.85,.58),(cf*CFrame.new(2.3,.43,-2.1)).Position,C.Bark,
			{material=Enum.Material.Wood,shadow=false})
		Kit.wedge(parent,"PineconeScale",Vector3.new(.58,.48,.55),
			cf*CFrame.new(2.3,.45,-2.1)*CFrame.Angles(.15,.7,.15),C.Wood,{material=Enum.Material.Wood,shadow=false})
	elseif zone == "cove" then
		for _, x in {-1.2, 1.2} do
			Kit.wedge(parent, "TideglassTrailShell", Vector3.new(.85, .3, 1.05),
				cf * CFrame.new(x, .18, -2.05) * CFrame.Angles(0, x*.7, 0), C.Cream,
				{ material = Enum.Material.Limestone, shadow = false })
		end
		Kit.ball(parent, "SmallTrailPearl", Vector3.one*.22, (cf*CFrame.new(-.45, .13, -1.75)).Position, C.Cloud, { shadow = false })
	else
		Kit.disk(parent,"LookoutCompassStone",2,2,.17,(cf*CFrame.new(1.8,.1,-2.1)).Position,C.Stone,
			{material=Enum.Material.Slate,shadow=false})
		local dial=CFrame.new((cf*CFrame.new(1.8,.21,-2.1)).Position)
		part(parent, dial, "CompassNorthNeedle", Vector3.new(.13, .04, 1.65), Vector3.zero, C.Gold, true)
		part(parent, dial, "CompassCrossNeedle", Vector3.new(1.65, .04, .13), Vector3.zero, C.Cream, true)
	end
end

function Details.populate(_root: Instance, regions: {[string]: Model})
	local stops = {
		{ id="harbor", name="HarborTrailRest", pos=Vector3.new(31,12,-13), yaw=math.pi/2, title="MAIN PIER", accent=C.Teal },
		{ id="blossom", name="PetalwindTrailRest", pos=Vector3.new(-260,28,11), yaw=-math.pi/2, title="GROVE PIER", accent=C.Blossom },
		{ id="forest", name="EvergreenTrailRest", pos=Vector3.new(248,24,-24), yaw=-math.pi/2, title="FOREST PIER", accent=C.Leaf },
		{ id="cove", name="TideglassTrailRest", pos=Vector3.new(-255,4,-196), yaw=math.pi/2, title="COVE PIER", accent=C.Coral },
		{ id="summit", name="StarfallTrailRest", pos=Vector3.new(269,60,-230), yaw=-math.pi/2, title="LOOKOUT PIER", accent=C.Gold },
	}
	for _, stop in stops do
		clearTrail(stop.id, stop.pos)
		local model = Kit.model(regions[stop.id], stop.name)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("TrailRegion", stop.id)
		local cf = CFrame.new(stop.pos) * CFrame.Angles(0, stop.yaw, 0)
		bench(model, cf)
		flowerpot(model, cf, -5.5, stop.accent)
		flowerpot(model, cf, 5.5, stop.accent)
		waymarker(model, cf, stop.id, stop.title, stop.accent)
		motif(model, cf, stop.id)
	end
end

return Details
