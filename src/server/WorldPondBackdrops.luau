--!strict
-- Layered rock terraces frame the fishing view while the arrival shore stays
-- open. Tapered rock faces break up the original safe, continuous collision cores.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))

local Backdrops = {}
local GRAY = Color3.fromRGB(89, 117, 132)
local GRAY_UPPER = Color3.fromRGB(98, 126, 139)
local GREEN = Color3.fromRGB(28, 151, 49)
local CYAN = Color3.fromRGB(56, 153, 181)
local WHITE_WATER = Color3.fromRGB(160, 199, 208)
local OFFSETS = { -.87, -.62, -.37, -.12, .12, .37, .62, .87 }
local HEIGHTS = { 38, 54, 43, 34, 37, 47, 58, 43 }
local ROCK_SKIN = { material = Enum.Material.Slate }

local function block(parent: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return Kit.part(parent, name, size, cf, color, {
		material = Enum.Material.SmoothPlastic,
		collidable = true,
	})
end

local function waterfall(parent: Model, frame: CFrame, x: number, z: number, width: number, top: number, phase: number)
	-- The lip reaches across the upper setback; the curtain runs just outside
	-- the lower wall face and meets the pond, facing its fishing pier.
	block(parent, "WaterfallSourceLip", Vector3.new(width + .8, .6, 4.8),
		frame * CFrame.new(x, top - .25, z + 5.1), GRAY_UPPER)
	local fallHeight = top - .1
	local curtain = Kit.part(parent, "PondWaterfallCurtain", Vector3.new(width, fallHeight, .24),
		frame * CFrame.new(x, .1 + fallHeight / 2, z + 7.35), CYAN,
		{ material = Enum.Material.SmoothPlastic, transparency = .38, shadow = false })
	for streakIndex = 1, 3 do
		local streak = Kit.part(parent, "PondWaterfallStreak", Vector3.new(.13, 4.2, .09),
			curtain.CFrame * CFrame.new((streakIndex - 2) * width * .31, 0, .19), WHITE_WATER,
			{ material = Enum.Material.SmoothPlastic, transparency = .34, shadow = false })
		streak:SetAttribute("FlowStart", streak.CFrame)
		streak:SetAttribute("FlowPhase", phase + streakIndex * .29)
		streak:SetAttribute("FlowDistance", fallHeight - 4.2)
		streak:SetAttribute("FlowSpeed", 12)
	end
	for foamIndex = 1, 3 do
		local foam=Kit.wedge(parent, "PondWaterfallFoam", Vector3.new(width * .45, .18 + (foamIndex % 2) * .08, 1.8),
			frame * CFrame.new(x + (foamIndex - 2) * width * .32, .14, z + 7.9 + (foamIndex % 2) * .8)
				* CFrame.Angles(0, math.rad((foamIndex - 2) * 11), 0), WHITE_WATER,
			{ material = Enum.Material.SmoothPlastic, transparency = .34, shadow = false })
		-- Reuse the existing low-rate shimmer for a little life at the fall's foot.
		foam:SetAttribute("GlintPhase",phase+foamIndex*.43)
	end
end

function Backdrops.populate(parent: Instance)
	for _, water in Layout.Waters do
		local yaw = 0
		for _, dock in Layout.Docks do
			if dock.Id == water.Id then yaw = dock.Yaw; break end
		end
		local model = Kit.model(parent, water.Id .. "PondTerraces")
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local frame = CFrame.new(table.unpack(water.Center)) * CFrame.Angles(0, yaw, 0)
		local sideways = math.abs(math.sin(yaw)) > .5
		local radiusX = if sideways then water.Radius[2] else water.Radius[1]
		local radiusZ = if sideways then water.Radius[1] else water.Radius[2]
		local width = radiusX * .25 + .3
		local heightScale = if water.Id == "harbor" then 1 else .77
		for index, offset in OFFSETS do
			local x = offset * radiusX
			local z = -(radiusZ * math.sqrt(1 - offset * offset) + 6)
			local height = HEIGHTS[index] * heightScale
			local lowerTop = height * .48
			local lowerTint = GRAY:Lerp(Kit.palette.DeepStone, (index % 3) * .08)
			local upperTint = GRAY_UPPER:Lerp(Kit.palette.Stone, (index % 4) * .055)
			block(model, "LowerPondCliffBrick", Vector3.new(width, lowerTop + 5, 14),
				frame * CFrame.new(x, (lowerTop - 5) / 2, z), lowerTint).Transparency = 1
			block(model, "LowerPondGrassRim", Vector3.new(width + .12, 1.4, 14.2),
				frame * CFrame.new(x, lowerTop + .7, z), GREEN).Transparency = 1
			block(model, "UpperPondCliffBrick", Vector3.new(width, height - lowerTop, 10),
				frame * CFrame.new(x, (height + lowerTop) / 2, z - 2), upperTint).Transparency = 1
			block(model, "UpperPondGrassRim", Vector3.new(width + .12, 1.4, 10.2),
				frame * CFrame.new(x, height + .7, z - 2), GREEN).Transparency = 1
			-- The original 170 colliders remain unchanged and invisible. Broad
			-- rock faces and tapered shoulders form a cohesive, beveled shoreline;
			-- the upper outcrops extend down behind the lower ones, never floating.
			local lean = if index % 2 == 0 then -1 else 1
			local crownHeight = height + (if index == 2 or index == 7 then 1.4 else 0)
			Kit.part(model, "LowerShoreRockFace", Vector3.new(width * .68, lowerTop + 5, 14.4),
				frame * CFrame.new(x, (lowerTop - 5) / 2, z + .45), lowerTint, ROCK_SKIN)
			Kit.part(model, "UpperShoreRockFace", Vector3.new(width * .68, crownHeight + 5, 10.4),
				frame * CFrame.new(x, (crownHeight - 5) / 2, z - 1.9), upperTint, ROCK_SKIN)
			for _, side in {-1, 1} do
				local lowerHeight = lowerTop + 5
				Kit.wedge(model, "TaperedShoreButtress", Vector3.new(14.4, lowerHeight, width * .24),
					frame * CFrame.new(x + side * width * .46, -5 + lowerHeight / 2, z + .45)
						* CFrame.Angles(0, -side * math.pi / 2, 0),
					lowerTint:Lerp(Kit.palette.DeepStone, if side == lean then .13 else .04), ROCK_SKIN)
				local upperHeight = crownHeight + 5
				Kit.wedge(model, "UpperShoreRockFacet", Vector3.new(10.4, upperHeight, width * .24),
					frame * CFrame.new(x + side * width * .46, -5 + upperHeight / 2, z - 1.9)
						* CFrame.Angles(0, -side * math.pi / 2, 0),
					upperTint:Lerp(Kit.palette.Limestone, if side == lean then .055 else .015), ROCK_SKIN)
			end
			if index==3 or index==6 then
				-- A few planted cracks make the exposed ledges read as places,
				-- rather than a repeating wall. These never own collision.
				for blade=1,3 do
					local h=.6+blade*.22
					Kit.wedge(model,"LedgeGrassSprout",Vector3.new(.12,h,.75),
						frame*CFrame.new(x+(blade-2)*.55,lowerTop+h/2,z+5.3),
						Kit.palette.Leaf,{shadow=false})
				end
			end
			if index == 2 or index == 7 then
				waterfall(model, frame, x, z, width * .54, height + 1.4, index * .17)
			end
		end
	end
end

return Backdrops
