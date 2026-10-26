--!strict
-- Original silhouettes built from small, fitted primitive details. All cosmetic
-- geometry shares immutable rest transforms for catches, portraits and aquariums.
local Catalog = require(script.Parent:WaitForChild("FishCatalog"))
local Fish = {}

local function shape(parent: Model, name: string, size: Vector3, position: Vector3, color: Color3, tapered: boolean?, role: string?): BasePart
	local part: BasePart = if tapered then Instance.new("WedgePart") else Instance.new("Part")
	if part:IsA("Part") then
		local mesh=Instance.new("SpecialMesh")
		mesh.Name,mesh.MeshType,mesh.Scale="EllipsoidMesh",Enum.MeshType.Sphere,Vector3.one
		mesh.Parent=part
	end
	part.Name, part.Size, part.Position = name, size, position
	part.Color, part.Material = color, Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.LeftSurface, part.RightSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.FrontSurface, part.BackSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part:SetAttribute("FishColorRole", role or "Fin")
	part.Parent = parent
	return part
end

-- A tangent frame on an ellipsoid. Small marks are sunk slightly into its skin;
-- their shallow curved caps stay attached when seen from the side or from above.
local function skinFrame(size: Vector3, point: Vector3, inset: number?): CFrame
	local normal = Vector3.new(point.X / size.X, point.Y / size.Y, point.Z / size.Z).Unit
	local right = Vector3.yAxis:Cross(normal).Unit
	local up = normal:Cross(right)
	return CFrame.fromMatrix(size * point * .5 + normal * (inset or 0), right, up, normal)
end

local function finish(model: Model, parent: Instance, species: any): Model
	model:SetAttribute("SpeciesId", species.Id)
	model:SetAttribute("FishAnimation", species.Animation)
	model:SetAttribute("FishRarity", species.Rarity)
	-- Rest data is shared by all three renderers. Joint centers are authored in
	-- model space, then scaled from these originals rather than incrementally.
	for index, part in model:GetChildren() do
		if not part:IsA("BasePart") then continue end
		part:SetAttribute("FishRestCFrame", part.CFrame)
		part:SetAttribute("FishRestSize", part.Size)
		part:SetAttribute("FishBaseColor", part.Color)
		part:SetAttribute("FishColorIndex", index)
		if part.Name == "Fin" or part.Name == "Tail" or part.Name == "Tentacle" or part.Name == "TentacleTip"
			or part:GetAttribute("FishMotionGroup") ~= nil then
			part:SetAttribute("FinRest", part.CFrame)
		end
		local center = part:GetAttribute("FishMotionCenter")
		if typeof(center) == "Vector3" then part:SetAttribute("FishMotionRestCenter", center) end
	end
	model.Parent = parent
	return model
end

local function moving(part: BasePart, group: number, center: Vector3)
	part:SetAttribute("FishMotionGroup", group)
	part:SetAttribute("FishMotionCenter", center)
	return part
end

local function exceptionalFace(model: Model, size: Vector3, highEyes: boolean)
	for _, side in {-1, 1} do
		local nx, ny = .44, if highEyes then .58 else .22
		local frame = skinFrame(size, Vector3.new(side * nx, ny, -math.sqrt(1 - nx*nx - ny*ny)), .004)
		local white = shape(model, "EyeWhite", Vector3.new(.28, .32, .105), Vector3.zero, Color3.fromRGB(239, 246, 247), false, "Face")
		white.CFrame = frame
		local pupil = shape(model, "Pupil", Vector3.new(.13, .19, .058), Vector3.zero, Color3.fromRGB(25, 36, 56), false, "Face")
		pupil.CFrame = frame * CFrame.new(0, .01, .058)
		local glint = shape(model, "EyeGlint", Vector3.new(.045, .055, .02), Vector3.zero, Color3.new(1, 1, 1), false, "Face")
		glint.CFrame = frame * CFrame.new(-.025, .055, .091)
	end
	local mouth = shape(model, "Mouth", Vector3.new(.15, .045, .04), Vector3.zero, Color3.fromRGB(38, 42, 68), false, "Face")
	mouth.CFrame = skinFrame(size, Vector3.new(0, -.12, -math.sqrt(1 - .12*.12)), .008)
end

local function createVeilfin(parent: Instance, name: string?, species: any): Model
	local model = Instance.new("Model")
	model.Name = name or species.Name
	local bodyColor, finColor = Color3.fromRGB(table.unpack(species.Body)), Color3.fromRGB(table.unpack(species.Fin))
	local pale = Color3.fromRGB(224, 224, 240)
	local size = Vector3.new(.98, .84, 1.6)
	model.PrimaryPart = shape(model, "Body", size, Vector3.zero, bodyColor, false, "Body")
	shape(model, "Belly", Vector3.new(.70, .23, 1.25), Vector3.new(0, -.26, -.09), pale, false, "Belly")
	exceptionalFace(model, size, false)
	-- Each segment and its two trailing membranes share one joint transform.
	-- Generous overlap keeps the continuous eel body closed through its wave.
	for index = 1, 5 do
		local center = Vector3.new(math.sin(index * .4) * .05, math.sin(index * .6) * .02, .55 + index * .47)
		local width, height = .92 - index * .13, .68 - index * .095
		moving(shape(model, "VeilSegment", Vector3.new(width, height, .94 - index * .035), center,
			bodyColor:Lerp(finColor, index * .055), false, "Body"), index, center)
		for _, side in {-1, 1} do
			local span = .76 - index * .085
			local membrane = shape(model, "VeilMembrane", Vector3.new(.065, span, .94),
				center + Vector3.new(side * (width * .43 + span * .32), -.025, .18), finColor, true, "Fin")
			-- Keep the wedge's straight inner edge embedded along the segment;
			-- mirroring that edge made only its distant broad end face the skin.
			membrane.CFrame *= CFrame.Angles(0, side * -.25, -side * math.pi / 2)
			moving(membrane, index, center)
		end
		local ribbon = shape(model, "VeilSpine", Vector3.new(.07, .34, .78), center + Vector3.new(0, height * .42 + .09, .10), pale, true, "Accent")
		ribbon.CFrame *= CFrame.Angles(-.23, 0, 0)
		moving(ribbon, index, center)
	end
	for _, side in {-1, 1} do
		local root = Vector3.new(side * .39, -.03, .22)
		local fin = shape(model, "VeilHeadFin", Vector3.new(.09, 1, 1.4), Vector3.new(side * .68, -.03, .34), finColor, true, "Fin")
		fin.CFrame *= CFrame.Angles(0, side * -.28, -side * math.pi / 2)
		moving(fin, if side == -1 then -1 else -2, root)
		local tailCenter = Vector3.new(math.sin(2) * .05, math.sin(3) * .02, 2.90)
		local outward = Vector3.xAxis * side
		local streamer = shape(model, "VeilStreamer", Vector3.new(.07, .43, .54), Vector3.zero, pale, true, "Accent")
		streamer.CFrame = CFrame.fromMatrix(tailCenter + Vector3.zAxis * .44 + outward * .10,
			-Vector3.yAxis * side, -outward, -Vector3.zAxis)
		moving(streamer, 5, Vector3.new(math.sin(2) * .05, math.sin(3) * .02, 2.90))
	end
	local crest = shape(model, "VeilCrest", Vector3.new(.15, .44, .31), Vector3.new(0, .46, -.13), pale, true, "Accent")
	crest.CFrame *= CFrame.Angles(-.23, 0, 0)
	return finish(model, parent, species)
end

local function createEclipse(parent: Instance, name: string?, species: any): Model
	local model = Instance.new("Model")
	model.Name = name or species.Name
	local bodyColor, finColor = Color3.fromRGB(table.unpack(species.Body)), Color3.fromRGB(table.unpack(species.Fin))
	local pale, ink = Color3.fromRGB(223, 235, 239), Color3.fromRGB(32, 40, 65)
	local size = Vector3.new(2.2, .52, 2.05)
	model.PrimaryPart = shape(model, "Body", size, Vector3.zero, bodyColor, false, "Body")
	shape(model, "Belly", Vector3.new(1.75, .17, 1.61), Vector3.new(0, -.17, -.03), finColor, false, "Belly")
	exceptionalFace(model, size, true)
	-- A fitted open crescent runs across the real upper disk, rather than an
	-- unrelated glowing ring hovering around an ordinary ray.
	for index = 0, 7 do
		local a = -.15 * math.pi + index / 8 * math.pi * 1.5
		local b = -.15 * math.pi + (index + 1) / 8 * math.pi * 1.5
		local from = Vector3.new(math.cos(a) * .946, .132, math.sin(a) * .8815)
		local to = Vector3.new(math.cos(b) * .946, .132, math.sin(b) * .8815)
		local rim = shape(model, "CrescentRim", Vector3.new(.13, .09, (to - from).Magnitude + .05), Vector3.zero, pale, false, "Accent")
		rim.CFrame = CFrame.lookAt((from + to) * .5, to)
	end
	for _, side in {-1, 1} do
		local center = Vector3.new(side * .72, -.035, .20)
		local fin = shape(model, "EclipseWing", Vector3.new(.12, 1.30, 2.05), Vector3.new(side * 1.12, -.04, .27), finColor, true, "Fin")
		fin.CFrame *= CFrame.Angles(0, side * -.34, -side * math.pi / 2)
		moving(fin, side, center)
		local vein = shape(model, "EclipseWingVein", Vector3.new(.045, .82, .065), Vector3.zero, ink, false, "Pattern")
		-- Fit the marking to the triangle's broad region, with a shallow skin
		-- overlap. An independent world offset left a dark rod outside the fin.
		vein.CFrame = fin.CFrame * CFrame.new(-side * .055, -.12, .615)
		moving(vein, side, center)
	end
	for index = 1, 3 do
		local center = Vector3.new(.05 + index * index * .072, -.025, .55 + index * .51)
		local tail = shape(model, "CometTail", Vector3.new(.37 - index * .075, .20 - index * .03, .94), center,
			if index == 3 then pale else bodyColor:Lerp(finColor, index * .20), false, if index == 3 then "Accent" else "Body")
		-- The centreline bends toward +X. Each long axis follows that bend;
		-- opposite yaw opened visible gaps between the narrow ellipsoids.
		tail.CFrame *= CFrame.Angles(0, .16 + index * .16, 0)
		moving(tail, 10, Vector3.new(.18, -.025, 1.03))
	end
	local terminal = Vector3.new(.698, -.025, 2.08)
	local forward = Vector3.new(math.sin(.64), 0, math.cos(.64))
	local root = terminal + forward * .18
	for _, side in {-1, 1} do
		local outward = Vector3.new(forward.Z, 0, -forward.X) * side
		local streamer = shape(model, "CometStreamer", Vector3.new(.065, .46, .65), Vector3.zero, finColor, true, "Fin")
		-- A wedge's broad root is its local +Z end. Seat that edge through
		-- the terminal skin, then point the tapered ends aft and apart.
		streamer.CFrame = CFrame.fromMatrix(root + outward * .14 + forward * .325,
			-Vector3.yAxis * side, -outward, -forward)
		moving(streamer, 10, Vector3.new(.18, -.025, 1.03))
	end
	local pearl = shape(model, "CometPearl", Vector3.new(.18, .15, .21), terminal + forward * .42, pale, false, "Accent")
	moving(pearl, 10, Vector3.new(.18, -.025, 1.03))
	return finish(model, parent, species)
end

function Fish.create(parent: Instance, name: string?, speciesId: string?): Model
	local species = Catalog.get(speciesId)
	if species.Shape == "Veil" then return createVeilfin(parent, name, species) end
	if species.Shape == "Eclipse" then return createEclipse(parent, name, species) end
	local bodyColor, finColor = Color3.fromRGB(table.unpack(species.Body)), Color3.fromRGB(table.unpack(species.Fin))
	local dark = bodyColor:Lerp(finColor, .58):Lerp(Color3.fromRGB(30, 55, 68), .30)
	local light = bodyColor:Lerp(Color3.fromRGB(255, 246, 221), .65)
	local model = Instance.new("Model")
	model.Name = name or species.Name
	model:SetAttribute("SpeciesId", species.Id)
	local id, kind = species.Id, species.Shape
	local size = if id == "pufflet" then Vector3.new(2.2, 1.85, 1.9)
		elseif id == "petalperch" then Vector3.new(1.3, 1.8, 2.3)
		elseif id == "mintfin" then Vector3.new(1.18, 1.08, 2.65)
		elseif id == "pinepike" then Vector3.new(.9, .85, 3.05)
		elseif id == "sunskipper" then Vector3.new(1.05, .86, 2.45)
		elseif id == "cloudmoth" then Vector3.new(1.05, 1.3, 1.85)
		elseif kind == "Ray" then Vector3.new(1.6, .58, 2.35)
		elseif kind == "Whale" then Vector3.new(2.25, 1.65, 2.95)
		elseif kind == "Squid" then Vector3.new(1.7, 2.1, 1.55)
		elseif kind == "Turtle" then Vector3.new(2.05, .72, 2.15)
		elseif kind == "Ribbon" then Vector3.new(1.35, 1.18, 2.65)
		elseif kind == "Lure" then Vector3.new(1.85, 1.65, 2.3)
		elseif kind == "Whiskers" then Vector3.new(1.8, 1.3, 2.6)
		elseif kind == "Crown" then Vector3.new(1.55, 1.8, 2.15)
		else Vector3.new(1.65, 1.45, 2.45)
	local body = shape(model, "Body", size, Vector3.zero, bodyColor, false, "Body")
	model.PrimaryPart = body
	shape(model, "Belly", size * Vector3.new(.76, .38, .8), Vector3.new(0, -size.Y * .325, -.04), light, false, "Belly")
	if kind ~= "Squid" and kind ~= "Turtle" then
		shape(model, "TailStock", Vector3.new(size.X * .26, size.Y * .29, .78), Vector3.new(0, -.04, size.Z * .43), bodyColor, false, "Body")
	end
	local function mark(name: string, side: number, y: number, z: number, width: number, height: number, color: Color3, angle: number?, role: string?)
		local x = side * math.sqrt(math.max(.01, 1 - y*y - z*z))
		local depth = .13 + .35 * (width*width/size.Z + height*height/size.Y)
		local patch = shape(model, name, Vector3.new(width, height, depth), Vector3.zero, color, false, role or "Pattern")
		patch.CFrame = skinFrame(size, Vector3.new(x,y,z), .018-depth*.5) * CFrame.Angles(0,0,angle or 0)
		return patch
	end
	if kind == "Turtle" then
		shape(model,"TurtleHead",Vector3.new(.85,.56,.9),Vector3.new(0,-.03,-1.15),bodyColor,false,"Body")
	elseif id == "pinepike" then
		shape(model,"PikeSnout",Vector3.new(.48,.36,.8),Vector3.new(0,-.06,-1.38),bodyColor,false,"Body")
		shape(model,"PikeJaw",Vector3.new(.4,.13,.62),Vector3.new(0,-.21,-1.45),light,false,"Belly")
	end
	for _, side in {-1,1} do
		if kind ~= "Turtle" then
			local span = if kind == "Ray" then 1.85 elseif id == "sunskipper" then 1.8 elseif id == "cloudmoth" then 1.65 elseif id == "pufflet" then .58 elseif id == "petalperch" then .75 elseif kind == "Whale" then .86 else .78
			local length = if kind == "Ray" then 2.2 elseif id == "sunskipper" then 1.9 elseif id == "cloudmoth" then 1.8 elseif kind == "Ribbon" then 1.7 elseif id == "pufflet" then .7 else 1.1
			local x = if kind == "Ray" then .98 elseif kind == "Wings" then .90 else size.X * .45 + .13
			local rounded = id == "cloudmoth" or id == "pufflet" or id == "petalperch" or kind == "Squid"
			local fin = shape(model,"Fin",Vector3.new(.14,span,length),Vector3.new(side*x,-.12,.24),finColor,not rounded)
			fin.CFrame *= CFrame.Angles(0,side*(if id == "sunskipper" then -.38 else -.18),side*math.pi/2)
			fin:SetAttribute("Side",side)
		end
		if kind ~= "Squid" and kind ~= "Turtle" and kind ~= "Ray" then
			local horizontal = kind == "Whale" or id == "sunskipper"
			local petal = id == "petalperch" or id == "cloudmoth"
			local tail = shape(model,"Tail",Vector3.new(if petal then .18 else .14,if kind == "Ribbon" then 1.03 elseif petal then .72 else .7,if kind == "Ribbon" then 1.25 else .83),
				Vector3.new(if horizontal then side*.36 else 0,if horizontal then -.05 else side*.29,size.Z*.56+.3),finColor,not petal)
			tail.CFrame *= if horizontal then CFrame.Angles(0,side*-.15,side*math.pi/2) else CFrame.Angles(side*(if petal then -.28 else 0),0,if side == 1 then 0 else math.pi)
			tail:SetAttribute("Side",side)
		end
		-- Eyes sit on the actual head surface, keeping the face readable in three
		-- quarter views without a stack of detached spherical accessories.
		local eyeSize = if id == "pinepike" then .30 elseif id == "pufflet" then .46 else .38
		local eyeFrame: CFrame
		if kind == "Turtle" then
			eyeFrame = CFrame.new(side*.26,.04,-1.54)*CFrame.Angles(0,math.pi,0)
		else
			local nx,ny = .48,if kind == "Ray" then .52 else .16
			eyeFrame = skinFrame(size,Vector3.new(side*nx,ny,-math.sqrt(1-nx*nx-ny*ny)),.005)
		end
		local white = shape(model,"EyeWhite",Vector3.new(eyeSize,eyeSize*1.08,.13),Vector3.zero,Color3.new(1,1,1),false,"Face")
		white.CFrame = eyeFrame
		local pupil = shape(model,"Pupil",Vector3.new(eyeSize*.48,eyeSize*.62,.065),Vector3.zero,Color3.fromRGB(25,44,63),false,"Face")
		pupil.CFrame = eyeFrame*CFrame.new(0,.012,.075)
		local glint = shape(model,"EyeGlint",Vector3.new(.055,.07,.023),Vector3.zero,Color3.new(1,1,1),false,"Face")
		glint.CFrame = eyeFrame*CFrame.new(-.03,.065,.11)
		if kind ~= "Turtle" then
			mark("Cheek",side,-.23,-.68,.23,.09,bodyColor:Lerp(Color3.fromRGB(231,135,137),.5),nil,"Accent")
		end
		if kind ~= "Turtle" and kind ~= "Squid" and kind ~= "Ray" then
			for stroke=0,1 do mark("GillLine",side,.02,-.24+stroke*.15,.055,.31,dark,side*-.15) end
		end
		if id == "pufflet" then
			for spot=0,2 do mark("PuffletFreckle",side,.36+spot%2*.14,-.24+spot*.30,.18,.16,dark) end
		elseif id == "petalperch" then
			for petal=0,2 do mark("PetalScale",side,.12,-.12+petal*.32,.25,.52,if petal == 1 then light else finColor,side*-.4,if petal == 1 then "Accent" else "Pattern") end
		elseif id == "mintfin" then
			mark("MintStripe",side,.12,.03,1.30,.16,dark)
			mark("MintFlash",side,.43,-.02,.70,.09,light,nil,"Accent")
		elseif id == "pinepike" then
			for stripe=0,2 do mark("PineBar",side,.02,-.12+stripe*.30,.16,.43,light,side*.50,"Accent") end
		elseif id == "emberfin" then
			for ember=0,2 do mark("EmberScale",side,.12,-.08+ember*.30,.25,.36,if ember%2 == 0 then dark else light,side*.42,if ember%2 == 0 then "Pattern" else "Accent") end
		elseif kind == "Whiskers" then
			for branch=0,1 do
				local whisker=shape(model,"Whisker",Vector3.new(.91,.055,.065),Vector3.new(side*.85,-.12-branch*.17,-size.Z*.40),finColor)
				whisker.CFrame*=CFrame.Angles(0,side*-.3,side*(.1+branch*.2))
			end
			mark("StarCheek",side,.23,.16,.29,.29,light,nil,"Accent")
		elseif id == "cloudmoth" then
			local lower=shape(model,"WingTip",Vector3.new(.13,1.16,1.16),Vector3.new(side*.82,-.16,1.01),finColor:Lerp(bodyColor,.3))
			lower.CFrame*=CFrame.Angles(0,side*.20,side*math.pi/2)
			-- These two oval markings are embedded in the upper face of the broad
			-- fixed hind wing, so they cannot separate when the front fins flutter.
			local eyespot=shape(model,"MothWingSpot",Vector3.new(.43,.07,.45),Vector3.new(side*1.03,-.105,1.0),dark,false,"Pattern")
			eyespot.CFrame*=CFrame.Angles(0,side*.20,0)
			shape(model,"MothWingPearl",Vector3.new(.18,.055,.20),Vector3.new(side*1.03,-.068,1.0),light,false,"Accent")
			local antenna=shape(model,"Antenna",Vector3.new(.055,.66,.07),Vector3.new(side*.23,.78,-.48),dark,false,"Pattern")
			antenna.CFrame*=CFrame.Angles(-.30,0,side*-.30)
			shape(model,"AntennaTip",Vector3.new(.14,.18,.13),Vector3.new(side*.33,1.07,-.58),finColor,false,"Accent")
		elseif id == "sunskipper" then
			mark("SkipperFlash",side,.15,.05,.92,.14,light,nil,"Accent")
			local keel=shape(model,"SkipperKeel",Vector3.new(.10,.38,.8),Vector3.new(side*.21,-.31,.8),finColor,true)
			keel.CFrame*=CFrame.Angles(0,0,side*.32)
		elseif kind == "Turtle" then
			for z=-1,1,2 do
				local flipper=shape(model,"Fin",Vector3.new(.12,.85,.95),Vector3.new(side*1.12,-.26,z*.64),finColor,true)
				flipper.CFrame*=CFrame.Angles(0,side*z*.22,side*math.pi/2)
				flipper:SetAttribute("Side",side)
			end
		elseif kind == "Ribbon" then
			mark("KoiPatch",side,.13,-.05,.65,.52,finColor,side*.35)
			mark("KoiInk",side,.22,.48,.28,.29,dark,side*-.2)
		elseif kind == "Whale" then
			for stripe=0,1 do mark("WhalePleat",side,-.68+stripe*.18,-.35,.70,.055,light,nil,"Accent") end
			mark("WhaleTemple",side,.36,-.10,.32,.17,dark)
		elseif kind == "Crown" then
			for pearl=0,2 do mark("CoralPearl",side,.04+pearl%2*.2,-.02+pearl*.28,.17,.18,light,nil,"Accent") end
		elseif kind == "Lure" then
			for spot=0,2 do mark("AuroraFleck",side,.22,-.07+spot*.25,.11,.27,if spot%2 == 0 then light else finColor,side*.45,"Accent") end
		elseif kind == "Squid" then
			for spot=0,1 do mark("MantleBubble",side,.30+spot*.22,.02,.21,.23,light,nil,"Accent") end
		end
	end
	local mouth=shape(model,"Mouth",Vector3.new(if id == "pufflet" then .15 else .24,.065,.05),Vector3.zero,Color3.fromRGB(81,59,61),false,"Face")
	if kind == "Turtle" then mouth.Position=Vector3.new(0,-.13,-1.594)
	elseif id == "pinepike" then mouth.Position=Vector3.new(0,-.12,-1.77)
	else mouth.CFrame=skinFrame(size,Vector3.new(0,-.13,-math.sqrt(1-.13*.13)),.012) end
	if kind == "Turtle" then
		local shellSize=Vector3.new(2.2,.94,1.95)
		local shellCenter=Vector3.new(0,.22,.12)
		shape(model,"MossShell",shellSize,shellCenter,finColor:Lerp(bodyColor,.65),false,"Body")
		for index=-1,1 do
			local seam=shape(model,"ShellScute",Vector3.new(.42,.08,.63),Vector3.zero,dark,false,"Pattern")
			local x=index*.42
			local y=math.sqrt(1-x*x)
			local normal=Vector3.new(x/shellSize.X,y/shellSize.Y,0).Unit
			seam.CFrame=CFrame.new(shellCenter+shellSize*Vector3.new(x,y,0)*.5-normal*.025)*CFrame.Angles(0,0,-index*.19)
		end
		shape(model,"TurtleTail",Vector3.new(.22,.18,.62),Vector3.new(0,-.16,1.04),bodyColor,false,"Body")
	elseif kind == "Squid" then
		shape(model,"MantleRim",Vector3.new(1.25,.22,1.15),Vector3.new(0,-.79,.02),finColor,false,"Fin")
		for index=0,5 do
			local angle=index*math.pi/3
			local tentacle=shape(model,"Tentacle",Vector3.new(.18,1.20,.22),Vector3.new(math.cos(angle)*.57,-1.28,math.sin(angle)*.46),finColor)
			tentacle.CFrame*=CFrame.Angles(.13*math.sin(angle),0,-.23*math.cos(angle))
			tentacle:SetAttribute("Side",index)
			local tip=shape(model,"TentacleTip",Vector3.new(.13,.54,.15),Vector3.zero,finColor:Lerp(bodyColor,.25))
			tip.CFrame=tentacle.CFrame*CFrame.new(0,-.71,0)*CFrame.Angles(.2*math.sin(angle),0,-.22*math.cos(angle))
			tip:SetAttribute("Side",index)
		end
	elseif kind == "Crown" then
		-- Three coral stems grow directly from the back; short slanting branches
		-- distinguish a reef crest from Crownwhale's compact royal tiara.
		for index=-1,1 do
			local height=.54-math.abs(index)*.10
			local stem=shape(model,"CoralStem",Vector3.new(.14,height,.16),Vector3.new(index*.31,size.Y*.5+height*.23,.10),finColor)
			stem.CFrame*=CFrame.Angles(0,0,-index*.28)
			for _,side in {-1,1} do
				local branch=shape(model,"CoralBranch",Vector3.new(.12,.27,.13),Vector3.new(index*.31+side*.10,size.Y*.5+height*.40,.10),finColor)
				branch.CFrame*=CFrame.Angles(0,0,-side*.65)
			end
		end
	elseif kind == "Whale" then
		shape(model,"CrownBand",Vector3.new(1.13,.15,.58),Vector3.new(0,size.Y*.5-.015,-.10),finColor,false,"Fin")
		for index=-1,1 do
			local height=.45-math.abs(index)*.10
			for _,half in {-1,1} do
				local crown=shape(model,"Crown",Vector3.new(.12,height,.19),Vector3.new(index*.37+half*.085,size.Y*.5+.14,-.10),finColor,true)
				crown.CFrame*=CFrame.Angles(0,-half*math.pi/2,0)
			end
		end
	elseif id == "petalperch" then
		for index=0,2 do
			local dorsal=shape(model,"PetalDorsal",Vector3.new(.18,.80-index*.11,.59),Vector3.new(0,size.Y*.46+.17,-.37+index*.37),finColor)
			dorsal.CFrame*=CFrame.Angles(-.28,0,0)
		end
	elseif id == "mintfin" then
		local dorsal=shape(model,"DorsalFin",Vector3.new(.12,.48,.88),Vector3.new(0,size.Y*.45+.08,.08),finColor,true)
		dorsal.CFrame*=CFrame.Angles(0,math.pi,0)
	elseif id == "pinepike" then
		local dorsal=shape(model,"PikeDorsal",Vector3.new(.12,.67,.83),Vector3.new(0,size.Y*.43+.15,.74),finColor,true)
		dorsal.CFrame*=CFrame.Angles(0,math.pi,0)
		local lower=shape(model,"PikeAnalFin",Vector3.new(.10,.43,.69),Vector3.new(0,-.43,.80),finColor,true)
		lower.CFrame*=CFrame.Angles(0,0,math.pi)
	elseif kind == "Spiky" or kind == "Whiskers" then
		for index=0,2 do
			local dorsal=shape(model,"DorsalFin",Vector3.new(.12,if kind == "Spiky" then .75-index*.15 else .45-index*.05,.49),Vector3.new(0,size.Y*.43+.12,-.38+index*.37),finColor,true)
			dorsal.CFrame*=CFrame.Angles(0,math.pi,0)
		end
	elseif kind == "Lure" then
		for step=0,2 do
			local stem=shape(model,"LureStem",Vector3.new(.065,.43,.075),Vector3.new(0,.82+step*.23,-.88-step*.10),dark,false,"Pattern")
			stem.CFrame*=CFrame.Angles(-.35,0,0)
		end
		shape(model,"LurePearl",Vector3.new(.32,.37,.28),Vector3.new(0,1.43,-1.20),light,false,"Accent")
	elseif kind == "Ray" then
		local tail=shape(model,"Tail",Vector3.new(.11,.12,1.7),Vector3.new(0,-.03,1.68),finColor)
		tail:SetAttribute("Side",1)
		for _,side in {-1,1} do
			local spot=shape(model,"MoonSpot",Vector3.new(.25,.055,.40),Vector3.zero,light,false,"Accent")
			local point=Vector3.new(side*.5,.80,.33)
			spot.CFrame=CFrame.new(size*point*.5-Vector3.new(0,.025,0))*CFrame.Angles(0,0,-side*.12)
		end
	end
	return finish(model, parent, species)
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
		-- Long/asymmetric tails need slightly smaller display envelopes through
		-- the outer slots' full yaw/wave. Catches keep authored proportions.
		local maximum = if species.Shape == "Veil" then .77 elseif species.Shape == "Eclipse" then .80 else 1
		scale *= math.min(math.clamp(displayScale, 0.5, 1), maximum)
	end
	-- Keep the same relationship between skin, pale accents and dark markings in
	-- every variant. Per-part rainbow cycling used to erase stripes and fin edges.
	local palette = { Color3.fromRGB(175, 151, 224), Color3.fromRGB(102, 190, 184), Color3.fromRGB(224, 153, 182), Color3.fromRGB(225, 194, 125) }
	local speciesIndex = 1
	for index, entry in Catalog.Species do if entry.Id == species.Id then speciesIndex = index; break end end
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
		local center = part:GetAttribute("FishMotionRestCenter")
		if typeof(center) == "Vector3" then part:SetAttribute("FishMotionCenter", center * scale) end
		local role = part:GetAttribute("FishColorRole")
		if role == "Face" or part.Name == "EyeWhite" or part.Name == "Pupil" or part.Name == "EyeGlint" or part.Name == "Mouth" then continue end
		if variant == "Golden" then
			local gold = if role == "Belly" or role == "Accent" then Color3.fromRGB(255, 235, 166)
				elseif role == "Pattern" then Color3.fromRGB(125, 83, 43)
				elseif role == "Fin" then Color3.fromRGB(202, 142, 54)
				else Color3.fromRGB(235, 194, 91)
			part.Color = color:Lerp(gold, .73)
		elseif variant == "Prismatic" then
			local tint = palette[(speciesIndex-1) % #palette + 1]
			if role == "Belly" or role == "Accent" then tint = tint:Lerp(Color3.fromRGB(255, 244, 222), .66)
			elseif role == "Pattern" then tint = palette[(speciesIndex+1) % #palette + 1]:Lerp(Color3.fromRGB(40, 56, 85), .54)
			elseif role == "Fin" then tint = palette[speciesIndex % #palette + 1] end
			part.Color = color:Lerp(tint, .70)
		end
	end
	model:SetAttribute("Variant", variant or "Normal")
end

local animationProfiles: { [string]: { number } } = {
	Paddle = { 2.3, .12, 3.8, .12 }, Dart = { 7.2, .12, 8.4, .23 },
	Flick = { 6.3, .18, 7.6, .21 }, Hover = { 2.7, .13, 3.6, .11 },
	Glide = { 1.9, .15, 2.8, .10 }, Pulse = { 3.3, .20, 4.1, .17 },
	Flutter = { 5.8, .25, 4.9, .12 }, Flow = { 2.8, .14, 4.2, .24 },
	Skip = { 6.5, .22, 7.0, .13 }, Heavy = { 1.6, .08, 1.9, .11 },
}

function Fish.animate(model: Model, time: number)
	local pivot = model:GetPivot()
	local profileName = model:GetAttribute("FishAnimation")
	local profile = animationProfiles[profileName :: string] or animationProfiles.Paddle
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then continue end
		local rest = child:GetAttribute("FinRest")
		local side = child:GetAttribute("Side")
		local group, center = child:GetAttribute("FishMotionGroup"), child:GetAttribute("FishMotionCenter")
		if typeof(rest) == "CFrame" and typeof(group) == "number" and typeof(center) == "Vector3" then
			local wave: number
			local motion: CFrame
			if profileName == "Undulate" then
				wave = math.sin(time * 2.4 - group * .65) * (if group > 0 then .018 + group * .014 else .09)
				motion = CFrame.Angles(wave * .2, wave, wave * .4)
			else
				wave = math.sin(time * 1.8 + group * .27)
				motion = if group == 10 then CFrame.Angles(0, wave * .065, 0) else CFrame.Angles(wave * .025, 0, wave * .11 * group)
			end
			child.CFrame = pivot * CFrame.new(center) * motion * CFrame.new(-center) * rest
			continue
		end
		if typeof(rest) ~= "CFrame" or typeof(side) ~= "number" then continue end
		if child.Name == "Fin" then
			child.CFrame = pivot * rest * CFrame.Angles(0, 0, math.sin(time * profile[1] + side * .3) * profile[2] * side)
		elseif child.Name == "Tail" then
			local beat = math.sin(time * profile[3]) * profile[4]
			child.CFrame = pivot * rest * (if profileName == "Heavy" then CFrame.Angles(beat, 0, 0) else CFrame.Angles(0, beat, 0))
		elseif child.Name == "Tentacle" or child.Name == "TentacleTip" then
			child.CFrame = pivot * rest * CFrame.Angles(math.sin(time * 3 + side) * 0.14, 0, math.cos(time * 3 + side) * 0.1)
		end
	end
end

return Fish
