--!strict
-- Inset-free world coordinates. Heights are walking surfaces; water sits below decks.
local Layout = {}
Layout.Islands = {
	{ Id = "harbor", Name = "Sundrift Harbor", Center = {0, 12, 0}, Radius = {130, 105}, Seed = 14, Kind = "Harbor" },
	{ Id = "blossom", Name = "Petalwind Grove", Center = {-246, 28, 15}, Radius = {84, 79}, Seed = 21, Kind = "Blossom" },
	{ Id = "forest", Name = "Evergreen Reach", Center = {262, 24, -10}, Radius = {88, 92}, Seed = 35, Kind = "Forest" },
	{ Id = "cove", Name = "Tideglass Cove", Center = {-228, 4, -211}, Radius = {79, 77}, Seed = 46, Kind = "Cove" },
	{ Id = "summit", Name = "Starfall Lookout", Center = {252, 60, -244}, Radius = {72, 76}, Seed = 51, Kind = "Summit" },
}
Layout.Bridges = {
	{ Id = "petal_bridge", From = "harbor", To = "blossom", A = {-105, 12, 10}, B = {-183, 28, 12}, Width = 16 },
	{ Id = "evergreen_bridge", From = "harbor", To = "forest", A = {107, 12, 4}, B = {194, 24, -5}, Width = 16 },
	{ Id = "cove_bridge", From = "blossom", To = "cove", A = {-247, 28, -47}, B = {-232, 4, -150}, Width = 14 },
	{ Id = "summit_bridge", From = "forest", To = "summit", A = {264, 24, -83}, B = {253, 60, -189}, Width = 16 },
}
Layout.Waters = {
	{ Id = "harbor", Center = {0, 8, 166}, Radius = {65, 55} },
	{ Id = "blossom", Center = {-242, 24, 147}, Radius = {49, 47} },
	{ Id = "forest", Center = {270, 20, 144}, Radius = {48, 46} },
	{ Id = "cove", Center = {-355, 0, -211}, Radius = {48, 45} },
	{ Id = "summit", Center = {367, 56, -244}, Radius = {46, 47} },
}
Layout.Docks = {
	{ Id = "harbor", A = {0, 12, 88}, B = {0, 12, 135}, Width = 23, Spot = {0, 12.1, 126}, Yaw = math.pi },
	{ Id = "blossom", A = {-242, 28, 77}, B = {-242, 28, 123}, Width = 17, Spot = {-242, 28.1, 115}, Yaw = math.pi },
	{ Id = "forest", A = {270, 24, 69}, B = {270, 24, 119}, Width = 18, Spot = {270, 24.1, 111}, Yaw = math.pi },
	{ Id = "cove", A = {-289, 4, -211}, B = {-333, 4, -211}, Width = 18, Spot = {-325, 4.1, -211}, Yaw = math.pi / 2 },
	{ Id = "summit", A = {310, 60, -244}, B = {345, 60, -244}, Width = 17, Spot = {337, 60.1, -244}, Yaw = -math.pi / 2 },
}
Layout.Paths = {
	{ Island = "harbor", Width = 13, Points = {{0,12,-62},{5,12,-40},{4,12,-25},{4,12,3},{0,12,29},{7,12,52},{0,12,72},{0,12,90}} },
	{ Island = "harbor", Width = 11, Points = {{-106,12,10},{-77,12,9},{-36,12,7},{0,12,4},{34,12,4},{68,12,0},{108,12,4}} },
	{ Island = "harbor", Width = 8, Points = {{0,12,-30},{-20,12,-47},{-37,12,-73},{-48,12,-69}} },
	{ Island = "harbor", Width = 6, Points = {{0,12,80},{-8,12,78},{-16,12,80}} },
	{ Island = "blossom", Width = 10, Points = {{-182,28,12},{-218,28,8},{-246,28,15},{-242,28,45},{-242,28,79}} },
	{ Island = "blossom", Width = 9, Points = {{-246,28,15},{-247,28,-16},{-247,28,-48}} },
	{ Island = "forest", Width = 10, Points = {{193,24,-5},{224,24,-5},{264,24,-8},{270,24,30},{270,24,70}} },
	{ Island = "forest", Width = 10, Points = {{264,24,-8},{264,24,-44},{264,24,-84}} },
	{ Island = "cove", Width = 10, Points = {{-232,4,-149},{-229,4,-181},{-236,4,-211},{-266,4,-211},{-290,4,-211}} },
	{ Island = "summit", Width = 10, Points = {{253,60,-188},{253,60,-216},{253,60,-244},{286,60,-244},{311,60,-244}} },
}
-- The play loop starts beside the water; the town remains optional exploration.
Layout.Spawn = {0, 12, 104}
Layout.WalkSpeed = 22
Layout.RodStand = {-20, 12, 82}

-- Terrain, coping and the basin share this one footprint. A voxel is selected
-- by its centre, so its four outer corners can sit beyond the ideal ellipse.
-- Tracing that ellipse independently is what formerly left dry shoreline gaps.
local waterGeometryCache: {[string]: any} = {}
function Layout.waterGeometry(water: any): any
	local cacheKey=water.Id.."@"..table.concat(water.Center,",")..":"..table.concat(water.Radius,",")
	local cached=waterGeometryCache[cacheKey]
	if cached then return cached end
	local resolution=4
	local center,radius=water.Center,water.Radius
	local fallX,fallZ=center[1]+radius[1]*.45,center[3]+radius[2]*.89
	-- The old three-curtain strip spanned 8 studs. Quantize its source once;
	-- the curtains now partition this exact wet front without dry outer edges.
	local spillway={MinX=math.floor((fallX-4.05)/resolution)*resolution,MaxX=math.ceil((fallX+4.05)/resolution)*resolution,
		MinZ=math.floor((fallZ-7)/resolution)*resolution,MaxZ=math.ceil((fallZ-.12)/resolution)*resolution,
		CurtainX=fallX,CurtainZ=fallZ,SourceFrontZ=math.ceil((fallZ-.12)/resolution)*resolution}
	local minimum={math.floor((center[1]-radius[1]-4)/resolution)*resolution,
		-- Keep the native volume above the basin floor. Two full layers
		-- extended below its tapered underside near the outer cell corners.
		math.floor((center[2]-4)/resolution)*resolution,
		math.floor((center[3]-radius[2]-4)/resolution)*resolution}
	local maximum={math.ceil((center[1]+radius[1]+4)/resolution)*resolution,
		math.ceil(center[2]/resolution)*resolution,
		math.ceil((center[3]+radius[2]+4)/resolution)*resolution}
	local size={}
	for axis=1,3 do size[axis]=(maximum[axis]-minimum[axis])/resolution end
	local occupied,corners,seen={},{},{}
	for x=1,size[1] do
		occupied[x]={}
		for z=1,size[3] do
			local px,pz=minimum[1]+(x-.5)*resolution,minimum[3]+(z-.5)*resolution
			local inside=((px-center[1])/radius[1])^2+((pz-center[3])/radius[2])^2<1
			inside=inside or (px+resolution/2>spillway.MinX and px-resolution/2<spillway.MaxX
				and pz+resolution/2>spillway.MinZ and pz-resolution/2<spillway.MaxZ)
			occupied[x][z]=inside
			if not inside then continue end
			for _,dx in {0,resolution} do
				for _,dz in {0,resolution} do
					local cx,cz=minimum[1]+(x-1)*resolution+dx,minimum[3]+(z-1)*resolution+dz
					local key=tostring(cx)..":"..tostring(cz)
					if seen[key] then continue end
					seen[key]=true
					table.insert(corners,{cx,center[2],cz})
				end
			end
		end
	end
	table.sort(corners,function(a,b) return a[1]<b[1] or (a[1]==b[1] and a[3]<b[3]) end)
	local function turn(a,b,c)
		return (b[1]-a[1])*(c[3]-a[3])-(b[3]-a[3])*(c[1]-a[1])
	end
	local lower,upper={},{}
	for _,point in corners do
		while #lower>=2 and turn(lower[#lower-1],lower[#lower],point)<=0 do table.remove(lower) end
		table.insert(lower,point)
	end
	for index=#corners,1,-1 do
		local point=corners[index]
		while #upper>=2 and turn(upper[#upper-1],upper[#upper],point)<=0 do table.remove(upper) end
		table.insert(upper,point)
	end
	table.remove(lower);table.remove(upper)
	local hull=lower
	for _,point in upper do table.insert(hull,point) end
	local normals={}
	for index,a in hull do
		local b=hull[index%#hull+1]
		local dx,dz=b[1]-a[1],b[3]-a[3]
		local length=math.sqrt(dx*dx+dz*dz)
		normals[index]={dz/length,-dx/length}
	end
	local function offset(distance: number,height: number): {{number}}
		local points={}
		for index,point in hull do
			local previous=normals[(index-2)%#normals+1]
			local normal=normals[index]
			local nx,nz=previous[1]+normal[1],previous[2]+normal[2]
			local scale=distance/(nx*normal[1]+nz*normal[2])
			table.insert(points,{point[1]+nx*scale,height,point[3]+nz*scale})
		end
		return points
	end
	-- Prove containment against every air cell, rather than assuming one radial
	-- inset handles both an ellipse and the square source channel. Expanding air
	-- cells by a stud also reserves clearance for the native water edge.
	local function clearOfAir(inset: number): boolean
		for x=1,size[1] do
			for z=1,size[3] do
				if occupied[x][z] then continue end
				local ax,az=minimum[1]+(x-1)*resolution-1,minimum[3]+(z-1)*resolution-1
				local polygon={{ax,az},{ax+resolution+2,az},{ax+resolution+2,az+resolution+2},{ax,az+resolution+2}}
				for index,normal in normals do
					local limit=hull[index][1]*normal[1]+hull[index][3]*normal[2]-inset
					local clipped={}
					for vertex,b in polygon do
						local a=polygon[(vertex-2)%#polygon+1]
						local da=a[1]*normal[1]+a[2]*normal[2]-limit
						local db=b[1]*normal[1]+b[2]*normal[2]-limit
						if (da<=0)~=(db<=0) then
							local t=da/(da-db)
							table.insert(clipped,{a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t})
						end
						if db<=0 then table.insert(clipped,b) end
					end
					polygon=clipped
					if #polygon==0 then break end
				end
				if #polygon>0 then return false end
			end
		end
		return true
	end
	local low,high=0,12
	assert(clearOfAir(high),"Lagoon needs room for its contained water hole")
	for _=1,18 do
		local mid=(low+high)/2
		if clearOfAir(mid) then high=mid else low=mid end
	end
	local innerInset=math.ceil(high*100)/100+.02
	-- The inner hole stays within selected cells, including their concave steps.
	-- The outer coping covers every selected corner; the foundation is wider.
	local geometry={Resolution=resolution,Min=minimum,Max=maximum,Size=size,Occupied=occupied,
		Hull=hull,Inner=offset(-innerInset,center[2]),Outer=offset(.3,center[2]),Basin=offset(1.2,center[2]-5),
		InnerInset=innerInset,Spillway=spillway}
	waterGeometryCache[cacheKey]=geometry
	return geometry
end

function Layout.outline(island: any): {{ number }}
	local points = {}
	for i = 1, 20 do
		local a = (i - 1) * math.pi / 10
		local variation = 1 + math.sin(a * 3 + island.Seed) * 0.055 + math.cos(a * 5 + island.Seed) * 0.025
		table.insert(points, {island.Center[1] + math.cos(a) * island.Radius[1] * variation,
			island.Center[2], island.Center[3] + math.sin(a) * island.Radius[2] * variation})
	end
	return points
end
-- Keep a level landing over each coast. The rise occurs over open air, so a
-- sloping boardwalk cannot disappear under the higher island's solid floor.
function Layout.bridgePoints(bridge: any): {{number}}
	local from, to = nil, nil
	for _, data in Layout.Islands do
		if data.Id==bridge.From then from=data end
		if data.Id==bridge.To then to=data end
	end
	assert(from and to,"Bridge references missing islands")
	local function contains(polygon: {{number}},x: number,z: number): boolean
		local inside=false
		for i,a in polygon do
			local b=polygon[i%#polygon+1]
			if (a[3]>z)~=(b[3]>z) and x<(b[1]-a[1])*(z-a[3])/(b[3]-a[3])+a[1] then inside=not inside end
		end
		return inside
	end
	local a,b=bridge.A,bridge.B
	local dx,dz=b[1]-a[1],b[3]-a[3]
	local distance=math.sqrt(dx*dx+dz*dz)
	local lastFrom,firstTo=0,1
	local fromPoly,toPoly=Layout.outline(from),Layout.outline(to)
	for i=0,400 do
		local t=i/400
		for _,offset in {-bridge.Width/2,0,bridge.Width/2} do
			local x,z=a[1]+dx*t-dz/distance*offset,a[3]+dz*t+dx/distance*offset
			if contains(fromPoly,x,z) then lastFrom=math.max(lastFrom,t) end
			if contains(toPoly,x,z) then firstTo=math.min(firstTo,t) end
		end
	end
	local start=lastFrom+2/distance
	local finish=firstTo-2/distance
	assert(start<finish,"Bridge needs an open span between its islands")
	return {a,{a[1]+dx*start,a[2],a[3]+dz*start},{a[1]+dx*finish,b[2],a[3]+dz*finish},b}
end
return Layout
