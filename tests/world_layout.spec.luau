--!strict
-- Geometry checks use the production map coordinates and actual coast polygons.
-- They verify traversal and casting constraints; appearance still needs Studio.
local Layout = require("../src/server/WorldLayout")
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
	for i, point in nodes do
		for s, segment in segments do
			local d, y = projection(point, segment.a, segment.b)
			if d > 1.5 or math.abs(y-point[2]) > 0.25 then continue end
			local first = 1 + #Layout.Docks + (s-1)*2 + 1
			for _, j in {first, first+1} do
				local weight = distance(point, nodes[j])
				edges[i][j], edges[j][i] = weight, weight
			end
		end
	end
	return nodes, edges
end

test("coast polygons and spawn produce a valid walking surface", function()
	local spawnIsland = nil
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
		if contains(polygon, Layout.Spawn) and math.abs(Layout.Spawn[2]-island.Center[2]) < 0.1 then spawnIsland = island end
	end
	assert(spawnIsland and clearance(Layout.outline(spawnIsland), Layout.Spawn) >= 5, "Spawn needs a full safe footprint on land")
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
		assert(path.Width >= 8 and #path.Points >= 2, path.Island .. " has an unusable trail")
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

test("the first fishing area is reachable within a short walk from spawn", function()
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
	assert(best[2] and best[2] <= 220, "First fishing spot should take less than 14 seconds of standard walking")
end)

print(string.format("%d tests passed; 0 skipped", passed))
