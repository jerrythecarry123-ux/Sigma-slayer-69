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
