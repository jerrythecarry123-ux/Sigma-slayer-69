--!strict
-- Original modular scenery. Cylinders in Roblox run along their local X axis.
local Kit = {}

export type Options = {
	material: Enum.Material?, collidable: boolean?, shadow: boolean?,
	transparency: number?, reflectance: number?, studded: boolean?,
}

Kit.palette = table.freeze({
	-- Keep the reference's green-and-blue brick identity, with quieter broad
	-- surfaces so paving, ponds and sky do not compete at full brightness.
	Grass = Color3.fromRGB(35, 163, 60), Moss = Color3.fromRGB(18, 116, 43),
	Leaf = Color3.fromRGB(23, 139, 52), Lime = Color3.fromRGB(105, 181, 64),
	Pine = Color3.fromRGB(20, 126, 50), PineLight = Color3.fromRGB(57, 159, 64),
	Blossom = Color3.fromRGB(199, 117, 155), BlossomLight = Color3.fromRGB(224, 164, 188),
	Stone = Color3.fromRGB(98, 126, 139), DeepStone = Color3.fromRGB(70, 97, 111),
	Cliff = Color3.fromRGB(89, 117, 132), Limestone = Color3.fromRGB(220, 213, 169),
	Sand = Color3.fromRGB(225, 217, 172), Wood = Color3.fromRGB(145, 108, 65),
	Bark = Color3.fromRGB(118, 83, 45), BarkLight = Color3.fromRGB(156, 112, 62),
	Plank = Color3.fromRGB(207, 191, 140), Cream = Color3.fromRGB(226, 220, 183),
	Teal = Color3.fromRGB(43, 129, 185), Water = Color3.fromRGB(45, 149, 184),
	Cloud = Color3.fromRGB(219, 229, 235), Coral = Color3.fromRGB(223, 116, 65),
	Brass = Color3.fromRGB(216, 179, 59), Iron = Color3.fromRGB(60, 83, 97),
	Lavender = Color3.fromRGB(110, 130, 179), Gold = Color3.fromRGB(226, 188, 31),
})

local function finish(p: BasePart, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, options: Options?)
	local opts = options or {}
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored = true
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.CanCollide = opts.collidable == true
	-- Scenery never needs touch events. Solid architecture remains queryable for cameras.
	p.CanTouch, p.CanQuery = false, opts.collidable == true
	p.CastShadow = opts.shadow ~= false
	p.Transparency, p.Reflectance = opts.transparency or 0, opts.reflectance or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if opts.studded then
		-- Native surface details repeat without adding individual stud Parts,
		-- textures to upload, touch events or physical joints.
		p.Material = Enum.Material.Plastic
		p.TopSurface,p.BottomSurface=Enum.SurfaceType.Studs,Enum.SurfaceType.Studs
		p.LeftSurface,p.RightSurface=Enum.SurfaceType.Studs,Enum.SurfaceType.Studs
		p.FrontSurface,p.BackSurface=Enum.SurfaceType.Studs,Enum.SurfaceType.Studs
	end
	p.Parent = parent
end

function Kit.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, options: Options?): Part
	local p = Instance.new("Part")
	finish(p, parent, name, size, cf, color, options)
	return p
end

function Kit.ball(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, options: Options?): Part
	local p = Kit.part(parent, name, size, CFrame.new(pos), color, options)
	-- Native Ball is a spherical primitive. An explicit Sphere mesh is the
	-- documented way to preserve independent visual dimensions on every axis.
	local mesh=Instance.new("SpecialMesh")
	mesh.Name,mesh.MeshType,mesh.Scale="EllipsoidMesh",Enum.MeshType.Sphere,Vector3.one
	mesh.Parent=p
	return p
end

function Kit.disk(parent: Instance, name: string, width: number, depth: number, thickness: number, pos: Vector3, color: Color3, options: Options?): Part
	local solid=options and options.collidable==true
	local unequal=math.abs(width-depth)>.001
	-- A native cylinder has a circular cross-section. Cosmetic oval plates
	-- use a shallow ellipsoid; solid floors retain an honest circular collider.
	if unequal and solid then width=math.min(width,depth);depth=width end
	local p = Kit.part(parent,name,Vector3.new(thickness,width,depth),
		CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),color,options)
	if unequal and not solid then
		local mesh=Instance.new("SpecialMesh")
		mesh.Name,mesh.MeshType,mesh.Scale="EllipsoidMesh",Enum.MeshType.Sphere,Vector3.one
		mesh.Parent=p
	else p.Shape=Enum.PartType.Cylinder end
	return p
end

function Kit.beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3, options: Options?): Part
	local length = (b - a).Magnitude
	assert(length > 0.001, "A scenery beam needs two distinct endpoints")
	local p = Kit.part(parent, name, Vector3.new(length, width, width),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, options)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, options: Options?): WedgePart
	local p = Instance.new("WedgePart")
	finish(p, parent, name, size, cf, color, options)
	return p
end

function Kit.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	return model
end

function Kit.sign(parent: BasePart, title: string, subtitle: string, color: Color3?): SurfaceGui
	local gui=Instance.new("SurfaceGui")
	gui.Name,gui.Face="PaintedSign",Enum.NormalId.Front
	-- Match the board's actual proportions. A single 900x280 canvas stretched
	-- short shop plaques and tall wayfinding boards by different amounts.
	local width=1024
	local height=math.clamp(math.floor(width*parent.Size.Y/math.max(.1,parent.Size.X)+.5),48,640)
	gui.SizingMode,gui.CanvasSize=Enum.SurfaceGuiSizingMode.FixedSize,Vector2.new(width,height)
	gui.LightInfluence,gui.Brightness,gui.AlwaysOnTop=.35,1,false
	gui.MaxDistance,gui.ZOffset=110,.01
	local bright=parent.Color.R*.2126+parent.Color.G*.7152+parent.Color.B*.0722>.65
	local ink=color or (if bright then Kit.palette.Iron else Kit.palette.Cream)
	local accent=if bright then Kit.palette.Teal else Kit.palette.Brass
	local function frame(name: string,x: number,y: number,w: number,h: number,tint: Color3): Frame
		local item=Instance.new("Frame")
		item.Name,item.BorderSizePixel=name,0
		item.Position,item.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
		item.BackgroundColor3,item.Parent=tint,gui
		return item
	end
	local inset=math.max(8,height*.075)
	local border=frame("InsetPaintedBorder",inset,inset,width-inset*2,height-inset*2,ink)
	border.BackgroundTransparency=1
	local outline=Instance.new("UIStroke")
	outline.Name,outline.Color,outline.Thickness="PaintedKeyline",ink:Lerp(parent.Color,.38),math.max(1,height*.009)
	outline.Parent=border
	local corners=Instance.new("UICorner")
	corners.CornerRadius,corners.Parent=UDim.new(0,height*.055),border
	local iconSize=height*.46
	local iconX,iconY=inset+height*.12,height*.25
	local body=frame("HarborFishMark",iconX,iconY+iconSize*.18,iconSize*.62,iconSize*.43,accent)
	local bodyRound=Instance.new("UICorner")
	bodyRound.CornerRadius,bodyRound.Parent=UDim.new(.5,0),body
	local tail=frame("HarborFishTail",iconX+iconSize*.58,iconY+iconSize*.22,iconSize*.29,iconSize*.29,accent)
	tail.Rotation=45
	local eye=frame("HarborFishEye",iconX+iconSize*.12,iconY+iconSize*.30,iconSize*.055,iconSize*.055,parent.Color)
	local eyeRound=Instance.new("UICorner")
	eyeRound.CornerRadius,eyeRound.Parent=UDim.new(.5,0),eye
	local textX=iconX+iconSize+height*.14
	local textWidth=width-textX-inset-height*.10
	frame("QuietHeaderRule",textX,height*.16,textWidth,math.max(1.2,height*.008),accent)
	local function label(name: string,text: string,y: number,h: number,bold: boolean,maxSize: number): TextLabel
		local item=Instance.new("TextLabel")
		item.Name,item.BackgroundTransparency=name,1
		item.Position,item.Size=UDim2.fromOffset(textX,y),UDim2.fromOffset(textWidth,h)
		item.Text,item.TextColor3,item.Font=text,ink,if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		item.TextScaled,item.TextWrapped,item.AutoLocalize=true,false,false
		item.TextXAlignment,item.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Center
		local sizing=Instance.new("UITextSizeConstraint")
		sizing.MaxTextSize,sizing.MinTextSize=maxSize,10
		sizing.Parent=item
		item.Parent=gui
		return item
	end
	label("Title",title,height*.25,height*.35,true,100)
	local caption=label("Caption",subtitle,height*.64,height*.18,false,48)
	caption.TextColor3=ink:Lerp(parent.Color,.18)
	gui.Parent=parent
	-- Wayfinding stays legible when approached from either side of a path.
	local reverse=gui:Clone()
	reverse.Name,reverse.Face,reverse.Parent="PaintedSignBack",Enum.NormalId.Back,parent
	return gui
end

function Kit.lantern(parent: Instance, pos: Vector3, scale: number?, shadowLight: boolean?): Model
	local s, c = scale or 1, Kit.palette
	local model = Kit.model(parent, "HarborLantern")
	local metal = { material = Enum.Material.Metal }
	Kit.beam(model, "HangingStem", pos + Vector3.new(0, 0.9, 0) * s, pos + Vector3.new(0, 1.6, 0) * s, 0.1 * s, c.Iron, metal)
	Kit.disk(model, "HangingEye", 0.38 * s, 0.38 * s, 0.09 * s, pos + Vector3.yAxis * 1.32 * s, c.Brass, metal)
	local glass = Kit.part(model, "AmberGlass", Vector3.new(0.82, 1.08, 0.82) * s, CFrame.new(pos),
		Color3.fromRGB(255, 222, 163), { material = Enum.Material.Glass, transparency = 0.38, shadow = false })
	Kit.part(model, "CandleGlow", Vector3.new(0.24, 0.7, 0.24) * s, CFrame.new(pos), c.Cream,
		{ material = Enum.Material.Neon, shadow = false })
	for _, y in { -0.64, 0.64 } do
		Kit.part(model, "LanternRim", Vector3.new(1.12, 0.16, 1.12) * s,
			CFrame.new(pos + Vector3.yAxis * y * s), c.Iron, metal)
	end
	for _, x in { -0.46, 0.46 } do
		for _, z in { -0.46, 0.46 } do
			Kit.beam(model, "CornerBrass", pos + Vector3.new(x, -0.61, z) * s,
				pos + Vector3.new(x, 0.61, z) * s, 0.075 * s, c.Brass, metal)
		end
	end
	for _, side in { -1, 1 } do
		Kit.wedge(model, "PitchedHood", Vector3.new(1.24, 0.34, 0.64) * s,
			CFrame.new(pos + Vector3.new(0, 0.87, side * 0.3) * s) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0), c.Teal, metal)
	end
	local light = Instance.new("PointLight")
	light.Name, light.Color = "WarmPool", Color3.fromRGB(255, 216, 150)
	light.Brightness, light.Range, light.Shadows = 0.65, 13 * s, shadowLight == true
	light.Parent = glass
	return model
end

return Kit
