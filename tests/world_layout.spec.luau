--!strict
-- Geometry checks use the production map coordinates and actual coast polygons.
-- They verify traversal and casting constraints; appearance still needs Studio.
local Layout = require("../src/server/WorldLayout")
local FishingConfig = require("../src/shared/FishingConfig")
local passed = 0
local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
	passed += 1
	print("PASS " .. name)
end

type Point = { number }
type Segment = { a: Point, b: Point, width: number }
local function distance(a: Point, b: Point): number
	return math.sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2 + (a[3]-b[3])^2)
end
local function projection(point: Point, a: Point, b: Point): (number, number, number)
	local dx, dz = b[1]-a[1], b[3]-a[3]
	local length2 = dx*dx + dz*dz
	local t = if length2 > 0 then math.clamp(((point[1]-a[1])*dx+(point[3]-a[3])*dz)/length2, 0, 1) else 0
	local x, z = a[1]+dx*t, a[3]+dz*t
	return math.sqrt((point[1]-x)^2+(point[3]-z)^2), a[2]+(b[2]-a[2])*t, t
end
local function contains(polygon: { Point }, point: Point): boolean
	local inside = false
	for i, a in polygon do
		local b = polygon[i % #polygon + 1]
		local d = projection(point, a, b)
		if d < 0.0001 then return true end
		if (a[3] > point[3]) ~= (b[3] > point[3])
			and point[1] < (b[1]-a[1])*(point[3]-a[3])/(b[3]-a[3])+a[1] then inside = not inside end
	end
	return inside
end
local function clearance(polygon: { Point }, point: Point): number
	if not contains(polygon, point) then return -math.huge end
	local nearest = math.huge
	for i, a in polygon do
		local d = projection(point, a, polygon[i % #polygon + 1])
		nearest = math.min(nearest, d)
	end
	return nearest
end
local function supported(point: Point): boolean
	for _, island in Layout.Islands do
		if math.abs(point[2]-island.Center[2]) < 0.1 and contains(Layout.outline(island), point) then return true end
	end
	for _, dock in Layout.Docks do
		local dx, dz = dock.B[1]-dock.A[1], dock.B[3]-dock.A[3]
		local along = ((point[1]-dock.A[1])*dx+(point[3]-dock.A[3])*dz)/(dx*dx+dz*dz)
		local d, y = projection(point, dock.A, dock.B)
		-- Stay clear of the side rails as well as the ends of the deck.
		if along >= 0 and along <= 1 and d <= dock.Width/2-1.3 and math.abs(y-point[2]) < 0.1 then return true end
	end
	return false
end
local islands, waters = {}, {}
for _, island in Layout.Islands do islands[island.Id] = island end
for _, water in Layout.Waters do waters[water.Id] = water end
local function pathNear(point: Point, islandId: string): boolean
	for _, path in Layout.Paths do
		if path.Island ~= islandId then continue end
		for i = 1, #path.Points - 1 do
			local d, y = projection(point, path.Points[i], path.Points[i+1])
			if d <= path.Width/2-1 and math.abs(y-point[2]) <= 0.25 then return true end
		end
	end
	return false
end
local function waterContains(water: any, x: number, z: number): boolean
	return ((x-water.Center[1])/water.Radius[1])^2 + ((z-water.Center[3])/water.Radius[2])^2 < 1
end

local function routes(): { Segment }
	local segments = {}
	for _, path in Layout.Paths do
		for i = 1, #path.Points - 1 do
			table.insert(segments, {a=path.Points[i], b=path.Points[i+1], width=path.Width})
		end
	end
	for _, bridge in Layout.Bridges do
		local points=Layout.bridgePoints(bridge)
		for i=1,#points-1 do table.insert(segments,{a=points[i],b=points[i+1],width=bridge.Width}) end
	end
	for _, dock in Layout.Docks do table.insert(segments, {a=dock.A, b=dock.B, width=dock.Width}) end
	return segments
end

-- A graph derived from real centerlines, including contacts at interior points.
-- Height checks prevent a bridge passing overhead from creating a false junction.
local function routeGraph()
	local segments = routes()
	local nodes: { Point } = {Layout.Spawn}
	for _, dock in Layout.Docks do table.insert(nodes, dock.Spot) end
	for _, segment in segments do table.insert(nodes, segment.a); table.insert(nodes, segment.b) end
	local edges: { { [number]: number } } = {}
	for i = 1, #nodes do edges[i] = {} end
	for _, segment in segments do
		local contacts = {}
		for i, point in nodes do
			local d, y = projection(point, segment.a, segment.b)
			if d > 1.5 or math.abs(y-point[2]) > 0.25 then continue end
			table.insert(contacts, i)
		end
		-- Interior contacts on the same deck connect directly; routing through an
		-- endpoint first would overstate the walk between spawn and the first cast.
		for _, i in contacts do
			for _, j in contacts do
				local weight = distance(nodes[i], nodes[j])
				edges[i][j], edges[j][i] = weight, weight
			end
		end
	end
	return nodes, edges
end

test("coast polygons and the complete spawn pad produce a valid walking surface", function()
	for _, island in Layout.Islands do
		local polygon = Layout.outline(island)
		assert(#polygon >= 3 and contains(polygon, island.Center), island.Id .. " has no central floor")
		local area = 0
		for i, a in polygon do
			local b = polygon[i % #polygon + 1]
			assert(a[2] == island.Center[2] and distance(a, b) > 0.1, island.Id .. " has invalid coast vertices")
			area += a[1]*b[3]-b[1]*a[3]
		end
		assert(math.abs(area)/2 > 100, island.Id .. " has a degenerate land polygon")
	end
	-- The pier is a walking surface too. A center-only coast check misses a pad
	-- that hangs over an edge or collides with the pier rails.
	for x = -7, 7 do
		for z = -7, 7 do
			assert(supported({Layout.Spawn[1]+x, Layout.Spawn[2], Layout.Spawn[3]+z}), "Spawn needs support under its full 14-by-14 footprint")
		end
	end
end)

test("bridge landings overlap the coast across their full walkable width", function()
	for _, bridge in Layout.Bridges do
		for _, endpoint in {{point=bridge.A, islandId=bridge.From}, {point=bridge.B, islandId=bridge.To}} do
			local point, island = endpoint.point, assert(islands[endpoint.islandId])
			assert(math.abs(point[2]-island.Center[2]) < 0.1, bridge.Id .. " does not meet land height")
			assert(clearance(Layout.outline(island), point) >= bridge.Width/2,
				bridge.Id .. " landing is too close to the " .. island.Id .. " cliff")
			assert(pathNear(point, island.Id), bridge.Id .. " has no trail reaching its landing")
		end
	end
end)

test("bridge grades and widths allow comfortable walking without jumping", function()
	for _, bridge in Layout.Bridges do
		local points=Layout.bridgePoints(bridge)
		assert(bridge.Width>=12,bridge.Id.." has an unsafe walking width")
		assert(points[1][2]==points[2][2] and points[3][2]==points[4][2],bridge.Id.." lacks level coast landings")
		for i=1,#points-1 do
			local a,b=points[i],points[i+1]
			local horizontal=math.sqrt((a[1]-b[1])^2+(a[3]-b[3])^2)
			assert(horizontal>1,bridge.Id.." has a degenerate span")
			assert(math.abs(a[2]-b[2])/horizontal<=math.tan(math.rad(35)),bridge.Id.." ramp exceeds a 35-degree walkable grade")
		end
	end
end)

test("trail corridors stay inside their island floors", function()
	for _, path in Layout.Paths do
		local island = assert(islands[path.Island])
		local polygon = Layout.outline(island)
		local workshopSpur = path.Island == "harbor" and Layout.RodStand
			and distance(path.Points[#path.Points], Layout.RodStand) <= 6
		assert(path.Width >= (if workshopSpur then 6 else 8) and #path.Points >= 2, path.Island .. " has an unusable trail")
		for i = 1, #path.Points - 1 do
			local a, b = path.Points[i], path.Points[i+1]
			local samples = math.ceil(distance(a, b)/3)
			for sample = 0, samples do
				local t = sample/samples
				local point = {a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t}
				assert(math.abs(point[2]-island.Center[2]) < 0.1, path.Island .. " trail has a vertical gap")
				assert(clearance(polygon, point) >= path.Width/2, path.Island .. " trail crosses its cliff edge")
			end
		end
	end
end)

test("every casting spot fits a continuous pier connected to a trail", function()
	for _, dock in Layout.Docks do
		local island = assert(islands[dock.Id])
		assert(clearance(Layout.outline(island), dock.A) >= dock.Width/2, dock.Id .. " pier starts outside land")
		assert(pathNear(dock.A, dock.Id), dock.Id .. " pier is detached from its trail")
		local d, y, t = projection(dock.Spot, dock.A, dock.B)
		local length = distance(dock.A, dock.B)
		assert(d < 0.1 and math.abs(y-dock.Spot[2]) < 0.25, dock.Id .. " casting spot floats off the deck")
		assert(t*length >= 5 and (1-t)*length >= 5, dock.Id .. " casting area overhangs a pier end")
		assert(dock.Width >= 12 and dock.A[2] == dock.B[2], dock.Id .. " has no level casting area")
	end
end)

test("all server casting lanes land safely inside native water voxels", function()
	for _, dock in Layout.Docks do
		local water = assert(waters[dock.Id])
		assert(water.Center[2] % 4 == 0, dock.Id .. " water surface must match its 4-stud terrain grid")
		assert(dock.Spot[2]-water.Center[2] >= 1 and dock.Spot[2]-water.Center[2] <= 7, dock.Id .. " water is too far above or below its pier")
		for _, lane in {-3, -1, 1, 3} do
			local x = dock.Spot[1] + math.cos(dock.Yaw)*lane - math.sin(dock.Yaw)*14
			local z = dock.Spot[3] - math.sin(dock.Yaw)*lane - math.cos(dock.Yaw)*14
			for _, dx in {-4, 4} do
				for _, dz in {-4, 4} do
					assert(waterContains(water, x+dx, z+dz), dock.Id .. " casts within a voxel-width of the lagoon edge")
				end
			end
			local voxelX, voxelZ = math.floor(x/4)*4+2, math.floor(z/4)*4+2
			assert(waterContains(water, voxelX, voxelZ), dock.Id .. " cast lands on an empty terrain voxel")
		end
	end
end)

test("real trail and bridge contacts connect spawn to every island pier", function()
	local _, edges = routeGraph()
	local visited, queue = {[1]=true}, {1}
	local head = 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		for j in edges[i] do
			if not visited[j] then visited[j] = true; table.insert(queue, j) end
		end
	end
	for i, dock in Layout.Docks do assert(visited[i+1], dock.Id .. " pier has no connected walking route from spawn") end
end)

test("every spawn-pad position reaches first-cast range within two seconds", function()
	local nodes, edges = routeGraph()
	local best: { [number]: number } = {[1]=0}
	local visited: { [number]: boolean } = {}
	for _ = 1, #nodes do
		local nextNode, nextCost = nil, math.huge
		for i, cost in best do if not visited[i] and cost < nextCost then nextNode, nextCost = i, cost end end
		if not nextNode then break end
		visited[nextNode] = true
		for j, weight in edges[nextNode] do best[j] = math.min(best[j] or math.huge, nextCost+weight) end
	end
	assert(Layout.WalkSpeed >= 20 and Layout.WalkSpeed <= 26, "Walking should be quick while preserving control on the smallest touch devices")
	-- Conservatively include the farthest possible spawn-pad corner and a
	-- three-stud root height in the server's three-dimensional cast range.
	local padRadius = math.sqrt(7*7+7*7)
	local horizontalRange = math.sqrt(FishingConfig.MaxDistance^2-3^2)
	local walkingDistance = math.max(0, assert(best[2], "First pier is disconnected")+padRadius-horizontalRange)
	assert(walkingDistance/Layout.WalkSpeed < 2, "The farthest spawn position takes more than two seconds to reach first-cast range")
end)

test("rod upgrades have a supported booth and a short authored approach from fishing", function()
	local stand = assert(Layout.RodStand, "The first pier needs a nearby rod-upgrade stand")
	for x = -3, 3 do
		for z = -4, 4 do
			assert(supported({stand[1]+x, stand[2], stand[3]+z}), "Rod stand footprint overhangs its walking surface")
		end
	end
	local harborDock = Layout.Docks[1]
	local bestWalk = math.huge
	for _, path in Layout.Paths do
		if path.Island ~= "harbor" or distance(path.Points[#path.Points], stand) > 6 then continue end
		local length = distance(harborDock.Spot, harborDock.A)+distance(harborDock.A, path.Points[1])
		for i = 1, #path.Points-1 do length += distance(path.Points[i], path.Points[i+1]) end
		bestWalk = math.min(bestWalk, length)
	end
	assert(bestWalk/Layout.WalkSpeed <= 4, "Fishing-to-upgrade loop takes more than four seconds along its authored approach")
end)

test("the complete native water depth stays above the suspended basin floor", function()
	for _,water in Layout.Waters do
		local geometry=Layout.waterGeometry(water)
		local floorY=geometry.Basin[1][2]
		assert(geometry.Min[2]>floorY+.5,water.Id.." native water leaks beneath its basin floor")
		assert(geometry.Max[2]==water.Center[2],water.Id.." native water surface changed height")
		assert(geometry.Max[2]-geometry.Min[2]>=geometry.Resolution,water.Id.." lacks a complete water layer")
		for axis=1,3 do
			assert(geometry.Min[axis]%geometry.Resolution==0 and geometry.Max[axis]%geometry.Resolution==0,
				water.Id.." water volume leaves the Terrain grid")
		end
	end
end)

test("native lagoon cell corners fit the coping and its complete foundation", function()
	for _,water in Layout.Waters do
		local geometry=Layout.waterGeometry(water)
		for axis=1,3 do
			assert(geometry.Min[axis]%4==0 and geometry.Max[axis]%4==0,water.Id.." water region is off grid")
			assert(geometry.Size[axis]*4==geometry.Max[axis]-geometry.Min[axis],water.Id.." water region size differs")
		end
		for x,row in geometry.Occupied do
			for z,occupied in row do
				if not occupied then continue end
				for _,dx in {0,4} do for _,dz in {0,4} do
					local point={geometry.Min[1]+(x-1)*4+dx,water.Center[2],geometry.Min[3]+(z-1)*4+dz}
					assert(clearance(geometry.Outer,point)>=.2999,water.Id.." has an uncovered native-water corner")
				end end
			end
		end
		for _,point in geometry.Outer do
			assert(clearance(geometry.Basin,point)>=.8999,water.Id.." coping overhangs its visible foundation")
		end
	end
end)

test("the complete inner lagoon polygon stays clear of native air cells", function()
	local function segmentDistance(a: Point,b: Point,c: Point,d: Point): number
		local function cross(p,q,r) return (q[1]-p[1])*(r[3]-p[3])-(q[3]-p[3])*(r[1]-p[1]) end
		local abC,abD,cdA,cdB=cross(a,b,c),cross(a,b,d),cross(c,d,a),cross(c,d,b)
		if abC*abD<0 and cdA*cdB<0 then return 0 end
		return math.min((projection(a,c,d)),(projection(b,c,d)),(projection(c,a,b)),(projection(d,a,b)))
	end
	for _,water in Layout.Waters do
		local geometry=Layout.waterGeometry(water)
		for x,row in geometry.Occupied do
			for z,occupied in row do
				if occupied then continue end
				local ax,az=geometry.Min[1]+(x-1)*4,geometry.Min[3]+(z-1)*4
				local rectangle={{ax,water.Center[2],az},{ax+4,water.Center[2],az},
					{ax+4,water.Center[2],az+4},{ax,water.Center[2],az+4}}
				for _,corner in rectangle do assert(not contains(geometry.Inner,corner),water.Id.." encloses an air-cell corner") end
				for index,a in geometry.Inner do
					assert(not (a[1]>=ax and a[1]<=ax+4 and a[3]>=az and a[3]<=az+4),water.Id.." inner corner touches air")
					local b=geometry.Inner[index%#geometry.Inner+1]
					for edge,c in rectangle do
						assert(segmentDistance(a,b,c,rectangle[edge%4+1])>=.9999,water.Id.." inner bank leaves dry native-water gaps")
					end
				end
			end
		end
	end
end)

test("every spillway begins across a connected wet native-cell front", function()
	for _,water in Layout.Waters do
		local geometry=Layout.waterGeometry(water)
		local spillway=geometry.Spillway
		assert(spillway.SourceFrontZ==spillway.MaxZ and spillway.MinX%4==0 and spillway.MaxX%4==0)
		for x=spillway.MinX+.25,spillway.MaxX-.25,.5 do
			local column=math.floor((x-geometry.Min[1])/4)+1
			local row=math.floor((spillway.SourceFrontZ-.05-geometry.Min[3])/4)+1
			assert(geometry.Occupied[column][row],water.Id.." spillway curtain starts beyond native water")
		end
		local startX=math.floor((water.Center[1]-geometry.Min[1])/4)+1
		local startZ=math.floor((water.Center[3]-geometry.Min[3])/4)+1
		local queue,seen={{startX,startZ}},{[startX..":"..startZ]=true}
		local cursor=1
		while cursor<=#queue do
			local p=queue[cursor];cursor+=1
			for _,step in {{1,0},{-1,0},{0,1},{0,-1}} do
				local x,z=p[1]+step[1],p[2]+step[2]
				local key=x..":"..z
				if seen[key] or not geometry.Occupied[x] or not geometry.Occupied[x][z] then continue end
				seen[key]=true;table.insert(queue,{x,z})
			end
		end
		for x,row in geometry.Occupied do for z,occupied in row do
			assert(not occupied or seen[x..":"..z],water.Id.." has a disconnected source cell")
		end end
	end
end)

test("water geometry caching follows dimensions as well as its zone ID", function()
	local source=Layout.Waters[1]
	local original=Layout.waterGeometry(source)
	local larger={Id=source.Id,Center=table.clone(source.Center),Radius={source.Radius[1]+8,source.Radius[2]+8}}
	local changed=Layout.waterGeometry(larger)
	assert(changed~=original and changed.Max[1]>original.Max[1] and changed.Min[1]<original.Min[1],"Changed dimensions reused a stale native mask")
	assert(Layout.waterGeometry(source)==original and Layout.waterGeometry(larger)==changed,"Identical masks should reuse their computed contour")
end)

print(string.format("%d tests passed; 0 skipped", passed))
