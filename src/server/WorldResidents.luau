--!strict
-- Original, lightweight block-toy townsfolk. Their movement is cosmetic and
-- runs locally; no Humanoids, pathfinding, avatar requests or server simulation.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Residents = {}

local COLORS = {
	Ink = Color3.fromRGB(34, 47, 66), White = Color3.fromRGB(255, 250, 234),
	Peach = Color3.fromRGB(255, 202, 154), Tan = Color3.fromRGB(197, 128, 78),
	Brown = Color3.fromRGB(117, 74, 45), Pink = Color3.fromRGB(255, 150, 145),
	Gold = Color3.fromRGB(255, 215, 42), Teal = Color3.fromRGB(0, 163, 147),
	Blue = Color3.fromRGB(31, 139, 235), Coral = Color3.fromRGB(245, 93, 58),
	Lilac = Color3.fromRGB(105, 145, 222), Green = Color3.fromRGB(35, 185, 75),
	Hair = Color3.fromRGB(75, 47, 34), Blonde = Color3.fromRGB(245, 197, 68),
}

local BODY_SHADOWS = {
	CheerfulFace = true, LinenShirt = true, TrouserLeg = true, RoundedBoot = true,
	SoftHair = true, SunHatCrown = true, CanvasCap = true, KnittedCap = true,
	CanvasBackpack = true,
}
local CLOTH = {
	LinenShirt=true, TrouserLeg=true, RolledSleeve=true, ApronBib=true, ApronStrap=true,
	CanvasBackpack=true, BackpackPocket=true, CanvasCap=true, KnittedCap=true,
	WovenSunBrim=true, SunHatCrown=true, HatRibbon=true,
}

local function ball(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	return Kit.ball(parent, name, size, position, color, { shadow = BODY_SHADOWS[name] == true })
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return Kit.part(parent, name, size, cf, color, {
		material=if CLOTH[name] then Enum.Material.Fabric else Enum.Material.SmoothPlastic,
		shadow = BODY_SHADOWS[name] == true,
	})
end

local function brick(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	return block(parent, name, size, CFrame.new(position), color)
end

local function pivot(parent: Model, name: string, position: Vector3): Model
	local joint = Kit.model(parent, name)
	local anchor = Kit.part(joint, "PosePivot", Vector3.new(0.08, 0.08, 0.08), CFrame.new(position), COLORS.Ink,
		{ shadow = false, transparency = 1 })
	joint.PrimaryPart = anchor
	joint:SetAttribute("AmbientRest", CFrame.new(position))
	return joint
end

local function limb(actor: Model, name: string, x: number, shirt: Color3, skin: Color3, leg: boolean): Model
	local position = Vector3.new(x, if leg then 1.6 else 3.16, 0)
	local joint = pivot(actor, name, position)
	if leg then
		brick(joint, "TrouserLeg", Vector3.new(0.57, 1.18, 0.61), position + Vector3.new(0, -0.52, 0), shirt)
		brick(joint, "RoundedBoot", Vector3.new(0.65, 0.48, 0.94), position + Vector3.new(0, -1.34, -0.13), COLORS.Ink)
	else
		brick(joint, "RolledSleeve", Vector3.new(0.61, 0.91, 0.66), position + Vector3.new(0, -0.34, 0), shirt)
		brick(joint, "MittenHand", Vector3.new(0.48, 0.57, 0.48), position + Vector3.new(0, -1.0, 0), skin)
	end
	return joint
end

local function face(actor: Model, skin: Color3, hair: Color3, hat: string, accent: Color3): Model
	local head = pivot(actor, "HeadPose", Vector3.new(0, 3.8, 0))
	local at = Vector3.new(0, 3.8, 0)
	brick(head, "CheerfulFace", Vector3.new(2.04, 2.08, 1.72), at + Vector3.new(0, 0.36, 0), skin)
	brick(head, "SoftHair", Vector3.new(2.09, 1.0, 1.58), at + Vector3.new(0, 1.0, 0.19), hair)
	for _, side in { -1, 1 } do
		local eye = ball(head, "Eye", Vector3.new(0.17, 0.24, 0.1), at + Vector3.new(side * 0.35, 0.51, -0.91), COLORS.Ink)
		eye:SetAttribute("AmbientEyeSize", eye.Size)
		local spark = ball(head, "EyeSpark", Vector3.new(0.055, 0.065, 0.035), at + Vector3.new(side * 0.35 - 0.025, 0.56, -0.965), COLORS.White)
		spark:SetAttribute("AmbientEyeSize", spark.Size)
		ball(head, "Blush", Vector3.new(0.27, 0.13, 0.055), at + Vector3.new(side * 0.61, 0.27, -0.895), COLORS.Pink)
		block(head, "Eyebrow", Vector3.new(0.27, 0.07, 0.075), CFrame.new(at + Vector3.new(side * 0.35, 0.80, -0.91))
			* CFrame.Angles(0, 0, side * -0.12), hair)
		block(head, "SmileCorner", Vector3.new(0.08, 0.12, 0.06), CFrame.new(at + Vector3.new(side * 0.13, 0.09, -0.91))
			* CFrame.Angles(0, 0, side * -0.45), COLORS.Brown)
	end
	ball(head, "Smile", Vector3.new(0.24, 0.08, 0.065), at + Vector3.new(0, 0.035, -0.92), COLORS.Brown)
	if hat == "Straw" then
		brick(head, "WovenSunBrim", Vector3.new(3.0, 0.14, 2.7), at + Vector3.new(0, 1.29, 0.04), COLORS.Gold)
		brick(head, "SunHatCrown", Vector3.new(1.9, 0.94, 1.65), at + Vector3.new(0, 1.54, 0.08), COLORS.Gold)
		brick(head, "HatRibbon", Vector3.new(1.94, 0.18, 1.70), at + Vector3.new(0, 1.37, 0.08), accent)
	elseif hat == "Beanie" then
		brick(head, "KnittedCap", Vector3.new(2.1, 0.95, 1.82), at + Vector3.new(0, 1.24, 0.04), accent)
		ball(head, "CapPompom", Vector3.new(0.49, 0.47, 0.47), at + Vector3.new(0, 1.83, 0.08), COLORS.White)
	else
		brick(head, "CanvasCap", Vector3.new(2.1, 0.8, 1.8), at + Vector3.new(0, 1.29, 0.08), accent)
		brick(head, "CapVisor", Vector3.new(1.71, 0.14, 1.11), at + Vector3.new(0, 1.12, -0.81), accent)
		brick(head, "CapBadge", Vector3.new(0.28, 0.25, 0.08), at + Vector3.new(0, 1.45, -0.87), COLORS.White)
	end
	return head
end

local function resident(parent: Model, data: any): Model
	local actor = Instance.new("Model")
	actor.Name, actor.ModelStreamingMode = "Resident_" .. data.name, Enum.ModelStreamingMode.Atomic
	local root = Kit.part(actor, "ResidentRoot", Vector3.new(0.12, 0.12, 0.12), CFrame.identity, COLORS.Ink,
		{ transparency = 1, shadow = false })
	actor.PrimaryPart = root
	brick(actor, "LinenShirt", Vector3.new(1.75, 1.88, 1.13), Vector3.new(0, 2.57, 0), data.shirt)
	block(actor, "ApronBib", Vector3.new(1.02, 1.09, 0.16), CFrame.new(0, 2.30, -0.56), data.apron)
	for _, x in { -0.38, 0.38 } do
		block(actor, "ApronStrap", Vector3.new(0.15, 0.81, 0.12), CFrame.new(x, 3.02, -0.51), data.apron)
		ball(actor, "BrassButton", Vector3.new(0.12, 0.12, 0.07), Vector3.new(x, 2.73, -0.66), COLORS.Gold)
	end
	limb(actor, "ArmLeft", -0.97, data.shirt, data.skin, false)
	local right = limb(actor, "ArmRight", 0.97, data.shirt, data.skin, false)
	limb(actor, "LegLeft", -0.40, data.apron, data.skin, true)
	limb(actor, "LegRight", 0.40, data.apron, data.skin, true)
	face(actor, data.skin, data.hair or COLORS.Hair, data.hat, data.accent)
	if data.style == "Repair" then
		Kit.beam(right, "RepairBrush", Vector3.new(0.97, 2.14, -0.25), Vector3.new(0.97, 2.18, -1), 0.12, COLORS.Gold, { shadow = false })
		ball(right, "BrushBristles", Vector3.new(0.28, 0.13, 0.30), Vector3.new(0.97, 2.16, -1.10), COLORS.White)
	elseif data.style == "Fish" then
		local handle = Vector3.new(0.97, 2.12, -0.18)
		local tip = Vector3.new(0.97, 4.35, -4.3)
		Kit.beam(right, "BambooFishingRod", handle, tip, 0.075, COLORS.Gold, { shadow = false })
		ball(right, "Reel", Vector3.new(0.35, 0.35, 0.25), Vector3.new(0.97, 2.46, -0.52), COLORS.Teal)
		local lineEnd = Vector3.new(0.97, -3.8, -10)
		-- The line lives outside the animated arm, so its bobber stays on real
		-- water while the rod tip and free hand move independently.
		Kit.beam(actor, "FineFishingLine", tip, lineEnd, 0.025, COLORS.White,
			{ shadow = false, transparency = 0.35 })
		ball(actor, "ResidentBobber", Vector3.new(.18,.23,.18), lineEnd, COLORS.Coral)
		actor:SetAttribute("AmbientLineEnd", data.cf:PointToWorldSpace(lineEnd))
	elseif data.style == "Serve" then
		Kit.disk(right, "LemonadeTray", 1.7, 1.1, 0.12, Vector3.new(0.97, 1.94, -0.32), COLORS.White, { shadow = false })
		for _, x in { 0.59, 1.33 } do
			Kit.disk(right, "LemonadeCup", .37, .37, .49, Vector3.new(x, 2.22, -0.32), COLORS.Gold, {shadow=false})
		end
	elseif data.style == "Garden" then
		ball(right, "WateringCan", Vector3.new(0.88, 0.76, 0.72), Vector3.new(1.0, 1.99, -0.2), COLORS.Teal)
		Kit.beam(right, "WateringSpout", Vector3.new(1.0, 2.03, -0.2), Vector3.new(1.0, 2.15, -1.06), 0.19, COLORS.Teal, { shadow = false })
		actor:SetAttribute("AmbientWaterTarget", data.cf:PointToWorldSpace(Vector3.new(1,.48,-1.65)))
		for index=1,3 do
			local drop=ball(actor,"WateringDrop"..index,Vector3.new(.055,.14,.055),Vector3.new(1,1.6-index*.3,-1.4),COLORS.Lilac)
			drop.Transparency=.35
		end
	elseif data.style == "Lookout" then
		brick(actor, "CanvasBackpack", Vector3.new(1.27, 1.48, 0.71), Vector3.new(0, 2.67, 0.70), COLORS.Gold)
		block(actor, "BackpackPocket", Vector3.new(0.86, 0.61, 0.18), CFrame.new(0, 2.4, 1.05), data.accent)
	end
	actor:SetAttribute("AmbientKind", "Resident")
	actor:SetAttribute("AmbientOrigin", data.cf)
	actor:SetAttribute("AmbientStyle", data.style)
	actor:SetAttribute("AmbientPhase", data.phase)
	actor:SetAttribute("AmbientPeriod", data.period or 35)
	if data.travel then
		actor:SetAttribute("AmbientTravel", data.travel)
		actor:SetAttribute("AmbientRouteWidth", 3.8)
	end
	actor:PivotTo(data.cf)
	actor.Parent = parent
	return actor
end

local function workspaces(parent: Instance, cast: {any})
	local folder=Instance.new("Folder")
	folder.Name,folder.Parent="ResidentWorkspaces",parent
	for _,data in cast do
		if data.style~="Repair" and data.style~="Garden" then continue end
		local scene=Kit.model(folder,data.name.."Workspace")
		scene.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
		local function part(name: string,size: Vector3,pos: Vector3,tint: Color3): Part
			return Kit.part(scene,name,size,data.cf*CFrame.new(pos),tint,{material=Enum.Material.Wood,shadow=false})
		end
		if data.style=="Repair" then
			part("RepairWorktop",Vector3.new(2.8,.16,1.2),Vector3.new(.7,2.08,-1.3),COLORS.Brown)
			for _,x in {-.45,1.85} do
				part("WorkbenchTrestle",Vector3.new(.18,2,.8),Vector3.new(x,1,-1.3),COLORS.Brown)
			end
			Kit.wedge(scene,"HalfPaintedHull",Vector3.new(1.8,.25,.65),data.cf*CFrame.new(.75,2.25,-1.12),COLORS.Teal,{material=Enum.Material.Wood,shadow=false})
			Kit.disk(scene,"OpenPaintPot",.34,.34,.3,data.cf:PointToWorldSpace(Vector3.new(-.3,2.31,-1.35)),COLORS.Coral,{shadow=false})
		else
			Kit.disk(scene,"TendedSoilPatch",2.2,1.7,.12,data.cf:PointToWorldSpace(Vector3.new(1,.08,-1.65)),COLORS.Brown,{material=Enum.Material.Ground,shadow=false})
			for index=-1,1 do
				local x=1+index*.65
				Kit.beam(scene,"TendedFlowerStem",data.cf:PointToWorldSpace(Vector3.new(x,.16,-1.65)),
					data.cf:PointToWorldSpace(Vector3.new(x,.7+index%2*.15,-1.65)),.07,COLORS.Green,{shadow=false})
				Kit.wedge(scene,"TendedFlowerLeaf",Vector3.new(.12,.3,.6),data.cf*CFrame.new(x,.4,-1.65)*CFrame.Angles(0,index*.6,math.pi/2),COLORS.Green,{shadow=false})
				Kit.disk(scene,"TendedFlowerBloom",.38,.38,.09,data.cf:PointToWorldSpace(Vector3.new(x,.74+index%2*.15,-1.65)),COLORS.Pink,{shadow=false})
			end
		end
	end
end

local function gull(parent: Model, index: number, origin: Vector3, radius: Vector3, phase: number)
	local model = Instance.new("Model")
	model.Name, model.ModelStreamingMode = "IslandGull_" .. index, Enum.ModelStreamingMode.Atomic
	local body = ball(model, "GullBody", Vector3.new(0.72, 0.65, 1.45), Vector3.zero, COLORS.White)
	model.PrimaryPart = body
	ball(model, "GullHead", Vector3.new(0.56, 0.55, 0.62), Vector3.new(0, 0.30, -0.60), COLORS.White)
	ball(model, "GoldenBeak", Vector3.new(0.17, 0.17, 0.45), Vector3.new(0, 0.24, -1.0), COLORS.Gold)
	for _, side in { -1, 1 } do
		local wing = pivot(model, if side < 0 then "WingLeft" else "WingRight", Vector3.new(side * 0.26, 0.11, 0))
		ball(wing, "SweptWing", Vector3.new(1.75, 0.15, 0.77), Vector3.new(side * 1.05, 0.11, 0.11), COLORS.White)
		ball(wing, "InkWingtip", Vector3.new(0.47, 0.13, 0.62), Vector3.new(side * 1.78, 0.11, 0.20), COLORS.Ink)
	end
	local cf = CFrame.new(origin)
	model:SetAttribute("AmbientKind", "Gull")
	model:SetAttribute("AmbientOrigin", cf)
	model:SetAttribute("AmbientRadius", radius)
	model:SetAttribute("AmbientPeriod", 22 + index * 1.6)
	model:SetAttribute("AmbientPhase", phase)
	model:PivotTo(cf)
	model.Parent = parent
end

local function butterfly(parent: Model, index: number, origin: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name, model.ModelStreamingMode = "GardenButterfly_" .. index, Enum.ModelStreamingMode.Atomic
	local body = ball(model, "ButterflyBody", Vector3.new(0.12, 0.44, 0.13), Vector3.zero, COLORS.Ink)
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		local wing = pivot(model, if side < 0 then "WingLeft" else "WingRight", Vector3.new(side * 0.05, 0, 0))
		ball(wing, "ButterflyWing", Vector3.new(0.76, 0.81, 0.075), Vector3.new(side * 0.36, 0.06, 0), color)
	end
	local cf = CFrame.new(origin)
	model:SetAttribute("AmbientKind", "Butterfly")
	model:SetAttribute("AmbientOrigin", cf)
	model:SetAttribute("AmbientRadius", Vector3.new(2.5, 0.7, 2.1))
	model:SetAttribute("AmbientPeriod", 7.5 + index * 0.7)
	model:SetAttribute("AmbientPhase", index * 1.73)
	model:PivotTo(cf)
	model.Parent = parent
end

local function fishSchool(parent: Model, index: number, origin: Vector3)
	local model = Instance.new("Model")
	model.Name, model.ModelStreamingMode = "LagoonFishSchool_" .. index, Enum.ModelStreamingMode.Atomic
	local root = Kit.part(model, "SchoolOrigin", Vector3.new(0.08, 0.08, 0.08), CFrame.identity, COLORS.Teal,
		{ transparency = 1, shadow = false })
	model.PrimaryPart = root
	for number = 1, 3 do
		local fish = Kit.model(model, "LagoonFish_" .. number)
		local position = Vector3.new((number - 2) * 1.35, (number % 2) * 0.2, number * 1.3)
		local color = if number == 1 then COLORS.Gold elseif number == 2 then COLORS.Coral else COLORS.Teal
		fish.PrimaryPart = ball(fish, "FishBody", Vector3.new(0.66, 0.47, 1.19), position, color)
		for _, side in { -1, 1 } do
			local tail = ball(fish, "TailFan", Vector3.new(0.43, 0.11, 0.59), position + Vector3.new(side * 0.16, 0, 0.77), color)
			tail.CFrame *= CFrame.Angles(0, side * -0.65, 0)
			ball(fish, "FishEye", Vector3.new(0.09, 0.10, 0.10), position + Vector3.new(side * 0.27, 0.09, -0.35), COLORS.Ink)
		end
	end
	local cf = CFrame.new(origin)
	model:SetAttribute("AmbientKind", "FishSchool")
	model:SetAttribute("AmbientOrigin", cf)
	model:SetAttribute("AmbientRadius", Vector3.new(9, 0.24, 6))
	model:SetAttribute("AmbientPeriod", 24 + index * 2)
	model:SetAttribute("AmbientPhase", index * 2.17)
	model:PivotTo(cf)
	model.Parent = parent
end

function Residents.populate(parent: Instance): Model
	local group = Instance.new("Model")
	group.Name = "IslandResidents"
	local cast = {
		{ name = "Milo", cf = CFrame.new(45, 12.15, -6) * CFrame.Angles(0, 0.35, 0), shirt = COLORS.White,
			apron = COLORS.Teal, skin = COLORS.Tan, hat = "Cap", accent = COLORS.Coral, style = "Repair", phase = 0.2 },
		{ name = "Juniper", cf = CFrame.new(-45, 12.15, -5.1) * CFrame.Angles(0, math.pi + .35, 0), shirt = COLORS.Coral,
			apron = COLORS.White, skin = COLORS.Peach, hat = "Beanie", accent = COLORS.Lilac, style = "Serve", phase = 1.7 },
		{ name = "CaptainPip", cf = CFrame.new(8, 12, 127) * CFrame.Angles(0, -math.pi / 2, 0), shirt = COLORS.White,
			apron = COLORS.Blue, skin = COLORS.Brown, hat = "Cap", accent = COLORS.Gold, style = "Fish", phase = 3.5 },
		{ name = "Sunny", cf = CFrame.new(-13, 12, 40), shirt = COLORS.Gold, apron = COLORS.Lilac,
			skin = COLORS.Peach, hat = "Cap", accent = COLORS.Teal, style = "Walk", phase = 0.6,
			travel = Vector3.new(0, 0, 24), period = 35 },
		{ name = "Petal", cf = CFrame.new(-229, 28, 30) * CFrame.Angles(0, math.pi / 2, 0), shirt = COLORS.Lilac,
			apron = COLORS.White, skin = COLORS.Tan, hat = "Straw", accent = COLORS.Coral, style = "Garden", phase = 2.2 },
		{ name = "Rowan", cf = CFrame.new(252, 24, 22) * CFrame.Angles(0, -math.pi / 2, 0), shirt = COLORS.Green,
			apron = COLORS.White, skin = COLORS.Brown, hat = "Cap", accent = COLORS.Gold, style = "Wave", phase = 4.1 },
		{ name = "Scout", cf = CFrame.new(-270, 4, -198) * CFrame.Angles(0, math.pi, 0), shirt = COLORS.Teal,
			apron = COLORS.Coral, skin = COLORS.Peach, hat = "Straw", hair = COLORS.Blonde, accent = COLORS.Blue,
			style = "Lookout", phase = 5.4 },
	}
	workspaces(parent,cast)
	for _, data in cast do resident(group, data) end
	local flock = {
		{ Vector3.new(4, 31, 122), Vector3.new(20, 2.0, 13) },
		{ Vector3.new(-14, 35, 165), Vector3.new(18, 2.0, 12) },
		{ Vector3.new(27, 30, 142), Vector3.new(16, 1.5, 12) },
		{ Vector3.new(-241, 47, 113), Vector3.new(17, 1.4, 12) },
		{ Vector3.new(268, 44, 101), Vector3.new(18, 1.4, 13) },
		{ Vector3.new(-287, 24, -204), Vector3.new(15, 1.5, 11) },
	}
	for index, data in flock do gull(group, index, data[1], data[2], index * 1.6) end
	for index, position in {
		Vector3.new(-27, 15.5, 16), Vector3.new(-32, 15.0, 18), Vector3.new(32, 15.5, 34),
		Vector3.new(-229, 31.5, 34), Vector3.new(-234, 32, 36), Vector3.new(249, 27.5, 27),
	} do
		butterfly(group, index, position, if index % 2 == 0 then COLORS.Gold else COLORS.Coral)
	end
	fishSchool(group, 1, Vector3.new(-14, 6.5, 147))
	fishSchool(group, 2, Vector3.new(-342, -1.5, -211))
	group.Parent = parent
	return group
end

return Residents
