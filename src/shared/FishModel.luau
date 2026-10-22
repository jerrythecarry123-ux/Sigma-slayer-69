--!strict
-- Original stylized fish. Tapered fins, forked tails and small surface markings
-- provide the silhouettes; no uploaded meshes or animation assets are needed.
local Catalog = require(script.Parent:WaitForChild("FishCatalog"))
local Fish = {}

local function shape(parent: Model, name: string, size: Vector3, position: Vector3, color: Color3, tapered: boolean?): BasePart
	local part: BasePart = if tapered then Instance.new("WedgePart") else Instance.new("Part")
	if part:IsA("Part") then part.Shape = Enum.PartType.Ball end
	part.Name, part.Size, part.Position = name, size, position
	part.Color, part.Material = color, Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.LeftSurface, part.RightSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.FrontSurface, part.BackSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Parent = parent
	return part
end

function Fish.create(parent: Instance, name: string?, speciesId: string?): Model
	local species = Catalog.get(speciesId)
	local bodyColor, finColor = Color3.fromRGB(table.unpack(species.Body)), Color3.fromRGB(table.unpack(species.Fin))
	local model = Instance.new("Model")
	model.Name = name or species.Name
	model:SetAttribute("SpeciesId", species.Id)
	local kind = species.Shape
	local size = if kind == "Ray" then Vector3.new(1.65, 0.64, 2.45)
		elseif kind == "Whale" then Vector3.new(2.35, 1.7, 2.9)
		elseif kind == "Squid" then Vector3.new(1.7, 2.25, 1.6)
		elseif kind == "Turtle" then Vector3.new(2.05, .72, 2.15)
		elseif kind == "Long" then Vector3.new(1.3, 1.12, 2.95)
		elseif kind == "Ribbon" then Vector3.new(1.5, 1.2, 2.75)
		elseif kind == "Lure" then Vector3.new(2.15, 1.55, 2.5)
		elseif kind == "Wings" then Vector3.new(1.1, 1.05, 2.2)
		elseif kind == "Whiskers" then Vector3.new(1.85, 1.4, 2.75)
		elseif kind == "Spiky" or kind == "Crown" then Vector3.new(1.9, 1.4, 2.65)
		elseif species.Id == "petalperch" then Vector3.new(2.05, 1.45, 2.45)
		else Vector3.new(2.35, 1.72, 2.1)
	local body = shape(model, "Body", size, Vector3.zero, bodyColor)
	model.PrimaryPart = body
	-- This thin inset follows the body's underside rather than becoming a second
	-- ball attached to it. The stock gives ordinary tails a continuous narrow root.
	shape(model, "Belly", size * Vector3.new(0.74, 0.35, 0.79), Vector3.new(0, -size.Y * 0.34, -0.05), bodyColor:Lerp(Color3.new(1, 1, 1), 0.62))
	if kind ~= "Squid" and kind ~= "Turtle" then
		shape(model, "TailStock", Vector3.new(size.X * 0.27, size.Y * 0.30, 0.78), Vector3.new(0, -0.04, size.Z * 0.43), bodyColor)
	end
	local front = if kind == "Turtle" then -1.52 else -size.Z * 0.44
	local eyeX = math.min(0.48, size.X * 0.28)
	local eyeY = if kind == "Ray" then 0.25 else size.Y * 0.11
	local cheek = finColor:Lerp(bodyColor, 0.4)
	if kind == "Turtle" then
		shape(model, "TurtleHead", Vector3.new(.85,.56,.9), Vector3.new(0,-.03,-1.15), bodyColor)
	end
	for _, side in { -1, 1 } do
		if kind ~= "Turtle" then
			local span = if kind == "Ray" then 1.9 elseif kind == "Wings" then 1.75 elseif kind == "Ribbon" then 1.1 elseif kind == "Whale" then .85 else .8
			local length = if kind == "Ray" then 2.25 elseif kind == "Wings" then 1.75 elseif kind == "Ribbon" then 1.8 else 1.15
			local x = if kind == "Ray" then 1.0 elseif kind == "Wings" then .9 else size.X * .47 + .16
			local fin = shape(model, "Fin", Vector3.new(.14,span,length), Vector3.new(side*x,-.12,.28), finColor,true)
			fin.CFrame *= CFrame.Angles(0,side*-.2,side*math.pi/2)
			fin:SetAttribute("Side",side)
		end
		if kind ~= "Squid" and kind ~= "Turtle" and kind ~= "Ray" then
			-- Two opposed triangular lobes make a true fork, not a pair of beads.
			local horizontal = kind == "Whale" or kind == "Wings"
			local tail = shape(model,"Tail",Vector3.new(.14,if kind == "Ribbon" then .92 else .72,if kind == "Ribbon" then 1.15 else .82),
				Vector3.new(if horizontal then side*.37 else 0,if horizontal then -.05 else side*.32,size.Z*.56+.3),finColor,true)
			tail.CFrame *= if horizontal then CFrame.Angles(0,side*-.15,side*math.pi/2) else CFrame.Angles(0,0,if side == 1 then 0 else math.pi)
			tail:SetAttribute("Side",side)
		end
		-- Eyes are inset, almost flat ovals. Tiny glints read as paint rather than
		-- another stack of spheres attached to a spherical head.
		shape(model,"EyeWhite",Vector3.new(.40,.44,.13),Vector3.new(side*eyeX,eyeY,front),Color3.new(1,1,1))
		shape(model,"Pupil",Vector3.new(.18,.25,.07),Vector3.new(side*eyeX,eyeY+.015,front-.075),Color3.fromRGB(25,44,63))
		shape(model,"EyeGlint",Vector3.new(.055,.075,.025),Vector3.new(side*eyeX-.035,eyeY+.075,front-.12),Color3.new(1,1,1))
		shape(model,"Cheek",Vector3.new(.28,.09,.035),Vector3.new(side*(eyeX+.17),eyeY-.27,front+.02),Color3.fromRGB(223,149,146))
		if kind ~= "Turtle" and kind ~= "Squid" and kind ~= "Ray" then
			for stroke=0,1 do
				local z=-size.Z*.12+stroke*.18
				local x=size.X*.5*math.sqrt(1-(z/(size.Z*.5))^2)+.006
				local gill=shape(model,"GillLine",Vector3.new(.025,.34,.065),Vector3.new(side*x,-.01,z),finColor:Lerp(bodyColor,.45))
				gill.CFrame *= CFrame.Angles(.18,0,side*-.14)
			end
		end
		if kind == "Whiskers" then
			for branch=0,1 do
				local whisker=shape(model,"Whisker",Vector3.new(.95,.055,.065),Vector3.new(side*.93,-.10-branch*.18,front-.04),finColor)
				whisker.CFrame*=CFrame.Angles(0,side*-.3,side*(.1+branch*.2))
			end
		elseif kind == "Wings" then
			local lower=shape(model,"WingTip",Vector3.new(.10,1.05,1.0),Vector3.new(side*.9,-.18,1.05),finColor:Lerp(bodyColor,.3),true)
			lower.CFrame*=CFrame.Angles(0,side*.3,side*math.pi/2)
			local antenna=shape(model,"Antenna",Vector3.new(.055,.8,.07),Vector3.new(side*.26,.78,front+.12),finColor)
			antenna.CFrame*=CFrame.Angles(-.25,0,side*-.28)
		elseif kind == "Turtle" then
			for z=-1,1,2 do
				local flipper=shape(model,"Fin",Vector3.new(.12,.85,.95),Vector3.new(side*1.12,-.26,z*.64),finColor,true)
				flipper.CFrame*=CFrame.Angles(0,side*z*.22,side*math.pi/2)
				flipper:SetAttribute("Side",side)
			end
		elseif kind == "Ribbon" then
			local patch=shape(model,"KoiPatch",Vector3.new(.035,.65,.8),Vector3.new(side*.745,.12,-.2),finColor)
			patch.CFrame*=CFrame.Angles(.35,0,0)
		elseif kind == "Whale" then
			for stripe=0,1 do
				shape(model,"WhalePleat",Vector3.new(.035,.035,.95),Vector3.new(side*(.16+stripe*.23),-.72,-.42),finColor:Lerp(bodyColor,.5))
			end
		end
	end
	shape(model,"Mouth",Vector3.new(.25,.065,.045),Vector3.new(0,eyeY-.22,if kind=="Turtle" then -1.615 else -size.Z*.5-.012),Color3.fromRGB(81,59,61))
	if kind == "Turtle" then
		shape(model,"MossShell",Vector3.new(2.2,.94,1.95),Vector3.new(0,.22,.12),finColor:Lerp(bodyColor,.65))
		for index=-1,1 do
			shape(model,"ShellSeam",Vector3.new(.035,.04,1.28),Vector3.new(index*.46,.69-math.abs(index)*.045,.12),finColor:Lerp(bodyColor,.3))
		end
	elseif kind == "Squid" then
		for index=0,5 do
			local angle=index*math.pi/3
			local tentacle=shape(model,"Tentacle",Vector3.new(.18,1.24,.22),Vector3.new(math.cos(angle)*.57,-1.32,math.sin(angle)*.46),finColor)
			tentacle.CFrame*=CFrame.Angles(.13*math.sin(angle),0,-.23*math.cos(angle))
			tentacle:SetAttribute("Side",index)
			local tip=shape(model,"TentacleTip",Vector3.new(.13,.57,.15),Vector3.zero,finColor:Lerp(bodyColor,.25))
			tip.CFrame=tentacle.CFrame*CFrame.new(0,-.73,0)*CFrame.Angles(.2*math.sin(angle),0,-.22*math.cos(angle))
			tip:SetAttribute("Side",index)
		end
	elseif kind == "Crown" or kind == "Whale" then
		for index=-1,1 do
			local x=index*.38
			local height=.58-math.abs(index)*.12
			for _,half in {-1,1} do
				local crown=shape(model,"Crown",Vector3.new(.13,height,.20),Vector3.new(x+half*.10,size.Y*.5+.16,.04),finColor,true)
				crown.CFrame*=CFrame.Angles(0,-half*math.pi/2,0)
			end
		end
	elseif kind == "Spiky" or kind == "Whiskers" or kind == "Long" or species.Id == "petalperch" then
		for index=0,2 do
			local dorsal=shape(model,"DorsalFin",Vector3.new(.12,.53-index*.08,.48),Vector3.new(0,size.Y*.43+.1,-.38+index*.37),finColor,true)
			dorsal.CFrame*=CFrame.Angles(0,math.pi,0)
		end
	elseif kind == "Lure" then
		for step=0,2 do
			local stem=shape(model,"LureStem",Vector3.new(.065,.45,.075),Vector3.new(0,.8+step*.25,front+.22-step*.11),finColor)
			stem.CFrame*=CFrame.Angles(-.35,0,0)
		end
		shape(model,"LurePearl",Vector3.new(.32,.37,.26),Vector3.new(0,1.45,front-.1),finColor)
	elseif kind == "Ray" then
		local tail=shape(model,"Tail",Vector3.new(.11,.12,1.7),Vector3.new(0,-.03,1.72),finColor)
		tail:SetAttribute("Side",1)
	elseif kind == "Round" then
		for _,x in {-.55,0,.55} do
			local y=size.Y*.5*math.sqrt(1-(x/(size.X*.5))^2-(-.14/(size.Z*.5))^2)+.008
			shape(model,"PuffletSpot",Vector3.new(.2,.035,.28),Vector3.new(x,y,-.14),cheek)
		end
	end
	-- Immutable rest geometry supports repeatable appearance changes at any pivot.
	for index, part in model:GetChildren() do
		if not part:IsA("BasePart") then continue end
		part:SetAttribute("FishRestCFrame", part.CFrame)
		part:SetAttribute("FishRestSize", part.Size)
		part:SetAttribute("FishBaseColor", part.Color)
		part:SetAttribute("FishColorIndex", index)
		if part.Name == "Fin" or part.Name == "Tail" or part.Name == "Tentacle" or part.Name == "TentacleTip" then part:SetAttribute("FinRest", part.CFrame) end
	end
	model.Parent = parent
	return model
end

function Fish.applyAppearance(model: Model, variant: string?, weightKg: number?, displayScale: number?)
	local species = Catalog.get(model:GetAttribute("SpeciesId"))
	local scale = 1
	if type(weightKg) == "number" and weightKg == weightKg and weightKg > 0 and weightKg < math.huge then
		local ratio = math.clamp((weightKg - species.WeightMin) / math.max(0.01, species.WeightMax - species.WeightMin), 0, 1)
		scale = 0.86 + ratio * 0.32
	end
	-- Tank models use a bounded presentation scale; the recorded weight stays real.
	if type(displayScale) == "number" and displayScale == displayScale and displayScale > 0 and displayScale < math.huge then
		scale *= math.clamp(displayScale, 0.5, 1)
	end
	local palette = { Color3.fromRGB(166, 132, 207), Color3.fromRGB(86, 178, 181), Color3.fromRGB(215, 145, 174), Color3.fromRGB(221, 188, 117) }
	local pivot = model:GetPivot()
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then continue end
		local rest = part:GetAttribute("FishRestCFrame") :: CFrame?
		local restSize = part:GetAttribute("FishRestSize") :: Vector3?
		local color = part:GetAttribute("FishBaseColor") :: Color3?
		if not rest or not restSize or not color then continue end
		local scaledRest = CFrame.new(rest.Position * scale) * (rest - rest.Position)
		part.Size, part.CFrame, part.Color = restSize * scale, pivot * scaledRest, color
		if part:GetAttribute("FinRest") then part:SetAttribute("FinRest", scaledRest) end
		if part.Name == "EyeWhite" or part.Name == "Pupil" or part.Name == "EyeGlint" or part.Name == "Mouth" then continue end
		if variant == "Golden" then part.Color = color:Lerp(Color3.fromRGB(226, 187, 79), 0.8)
		elseif variant == "Prismatic" then
			local index = part:GetAttribute("FishColorIndex") :: number
			part.Color = color:Lerp(palette[index % #palette + 1], 0.82)
		end
	end
	model:SetAttribute("Variant", variant or "Normal")
end

function Fish.animate(model: Model, time: number)
	local pivot = model:GetPivot()
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then continue end
		local rest = child:GetAttribute("FinRest")
		local side = child:GetAttribute("Side")
		if typeof(rest) ~= "CFrame" or typeof(side) ~= "number" then continue end
		if child.Name == "Fin" then
			child.CFrame = pivot * rest * CFrame.Angles(0, 0, math.sin(time * 5 + side * 0.3) * 0.18 * side)
		elseif child.Name == "Tail" then
			child.CFrame = pivot * rest * CFrame.Angles(0, math.sin(time * 6) * 0.17, 0)
		elseif child.Name == "Tentacle" or child.Name == "TentacleTip" then
			child.CFrame = pivot * rest * CFrame.Angles(math.sin(time * 3 + side) * 0.14, 0, math.cos(time * 3 + side) * 0.1)
		end
	end
end

return Fish
