--!strict
-- Five small, authored rest stops beside the trails. These are scenery rather
-- than interaction points; the walking routes and their collisions stay clear.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local C = Kit.palette
local Details = {}

local function part(parent: Instance, cf: CFrame, name: string, size: Vector3, offset: Vector3, tint: Color3, tiny: boolean?): Part
	return Kit.part(parent, name, size, cf * CFrame.new(offset), tint,
		{ material = Enum.Material.Plastic, studded = tiny ~= true, shadow = tiny ~= true })
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
	part(parent, cf, "StuddedBenchSeat", Vector3.new(7.6, .32, 2.1), Vector3.new(0, 1.68, 0), C.Plank)
	for _, y in {2.55, 3.16} do
		part(parent, cf, "BenchBackSlat", Vector3.new(7.6, .38, .2), Vector3.new(0, y, .83), C.Plank)
	end
	for _, x in {-2.8, 2.8} do
		part(parent, cf, "BenchBackSupport", Vector3.new(.3, 2.95, .3), Vector3.new(x, 1.58, .76), C.Wood)
		part(parent, cf, "BenchTrestleFoot", Vector3.new(.36, 1.5, 1.8), Vector3.new(x, .75, 0), C.Bark)
	end
	for _, x in {-3.9, 3.9} do
		part(parent, cf, "BenchArmrest", Vector3.new(.35, .22, 2.2), Vector3.new(x, 2.22, 0), C.Wood)
	end
end

local function flowerpot(parent: Instance, cf: CFrame, x: number, accent: Color3)
	local base = cf * CFrame.new(x, 0, .45)
	part(parent, base, "PaintedSquareFlowerpot", Vector3.new(1.65, .74, 1.65), Vector3.new(0, .37, 0), accent)
	part(parent, base, "FlowerpotSoil", Vector3.new(1.38, .08, 1.38), Vector3.new(0, .77, 0), C.Bark, true)
	part(parent, base, "PottedLeafBrick", Vector3.new(.87, .68, .87), Vector3.new(0, 1.08, 0), C.Leaf, true)
	part(parent, base, "FlowerStem", Vector3.new(.1, .65, .1), Vector3.new(0, 1.54, 0), C.Moss, true)
	part(parent, base, "BrightCrossPetal", Vector3.new(.92, .18, .42), Vector3.new(0, 1.91, 0), accent, true)
	part(parent, base, "BrightCrossPetal", Vector3.new(.42, .18, .92), Vector3.new(0, 1.91, 0), accent, true)
	part(parent, base, "PollenSquare", Vector3.new(.25, .24, .25), Vector3.new(0, 2.04, 0), C.Gold, true)
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
	part(parent, cf, "TrailMarkerPost", Vector3.new(.24, 3.8, .24), Vector3.new(5.8, 1.9, -1.25), C.Bark)
	local board = part(parent, cf, "PaintedPierDirection", Vector3.new(2.9, 1.15, .18), Vector3.new(5.8, 3.3, -1.25), accent)
	local brightBoard = zone == "blossom" or zone == "cove" or zone == "summit"
	local ink = if brightBoard then C.Iron:Lerp(Color3.new(0, 0, 0), .35) else C.Cream
	Kit.sign(board, title, "Follow the trail", ink)
	Kit.wedge(parent, "TrailArrowPoint", Vector3.new(.15, .75, .85),
		cf * CFrame.new(5.8 + direction * 1.85, 3.3, -1.25) * CFrame.Angles(0, direction * math.pi/2, 0),
		accent, { material = Enum.Material.Plastic, shadow = false })
end

local function motif(parent: Instance, cf: CFrame, zone: string)
	if zone == "harbor" then
		-- A little closed trail guide rests on the bench; it is not a fake button.
		part(parent, cf, "HarborGuideCover", Vector3.new(.95, .12, 1.15), Vector3.new(-1.8, 1.9, -.1), C.Teal, true)
		part(parent, cf, "HarborGuidePages", Vector3.new(.86, .07, 1.03), Vector3.new(-1.8, 1.99, -.1), C.Cream, true)
		part(parent, cf, "GoldenGuideBookmark", Vector3.new(.09, .025, .7), Vector3.new(-1.62, 2.04, -.1), C.Gold, true)
	elseif zone == "blossom" then
		for i = 1, 3 do
			local petal = part(parent, cf, "FallenTrailBlossom", Vector3.new(.82, .055, .48),
				Vector3.new((i-2)*1.2, .07, -1.8-(i%2)*.4), C.Blossom:Lerp(C.BlossomLight, i*.13), true)
			petal.CFrame *= CFrame.Angles(0, i*.65, 0)
		end
	elseif zone == "forest" then
		for i = 0, 2 do
			local width = .85-i*.23
			part(parent, cf, "FallenBrickPinecone", Vector3.new(width, .29, width),
				Vector3.new(2.3, .17+i*.29, -2.1), C.Bark:Lerp(C.Wood, i*.2))
		end
	elseif zone == "cove" then
		for _, x in {-1.2, 1.2} do
			Kit.wedge(parent, "TideglassTrailShell", Vector3.new(.85, .3, 1.05),
				cf * CFrame.new(x, .18, -2.05) * CFrame.Angles(0, x*.7, 0), C.Cream,
				{ material = Enum.Material.Plastic, shadow = false })
		end
		Kit.ball(parent, "SmallTrailPearl", Vector3.one*.22, (cf*CFrame.new(-.45, .13, -1.75)).Position, C.Cloud, { shadow = false })
	else
		part(parent, cf, "LookoutCompassStone", Vector3.new(2, .17, 2), Vector3.new(1.8, .1, -2.1), C.Stone, true)
		part(parent, cf, "CompassNorthNeedle", Vector3.new(.13, .04, 1.65), Vector3.new(1.8, .21, -2.1), C.Gold, true)
		part(parent, cf, "CompassCrossNeedle", Vector3.new(1.65, .04, .13), Vector3.new(1.8, .21, -2.1), C.Cream, true)
	end
end

function Details.populate(_root: Instance, regions: {[string]: Model})
	local stops = {
		{ id="harbor", name="HarborTrailRest", pos=Vector3.new(31,12,-13), yaw=math.pi/2, title="MAIN PIER", accent=C.Teal },
		{ id="blossom", name="PetalwindTrailRest", pos=Vector3.new(-260,28,11), yaw=-math.pi/2, title="GROVE PIER", accent=C.Blossom },
		{ id="forest", name="EvergreenTrailRest", pos=Vector3.new(248,24,-24), yaw=-math.pi/2, title="FOREST PIER", accent=C.Leaf },
		{ id="cove", name="TideglassTrailRest", pos=Vector3.new(-255,4,-196), yaw=0, title="COVE PIER", accent=C.Coral },
		{ id="summit", name="StarfallTrailRest", pos=Vector3.new(269,60,-230), yaw=0, title="LOOKOUT PIER", accent=C.Gold },
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
