--!strict
-- Original modular scenery. Cylinders in Roblox run along their local X axis.
local Kit = {}

export type Options = {
	material: Enum.Material?, collidable: boolean?, shadow: boolean?,
	transparency: number?, reflectance: number?, studded: boolean?,
}

Kit.palette = table.freeze({
	-- Read from the supplied Duck Pond screenshot: saturated green bricks,
	-- blue-gray walls, pale yellow paving and bright cyan ponds.
	Grass = Color3.fromRGB(20, 200, 55), Moss = Color3.fromRGB(0, 145, 42),
	Leaf = Color3.fromRGB(14, 163, 45), Lime = Color3.fromRGB(81, 214, 40),
	Pine = Color3.fromRGB(17, 149, 53), PineLight = Color3.fromRGB(54, 191, 59),
	Blossom = Color3.fromRGB(230, 119, 171), BlossomLight = Color3.fromRGB(255, 173, 202),
	Stone = Color3.fromRGB(109, 142, 157), DeepStone = Color3.fromRGB(76, 111, 127),
	Cliff = Color3.fromRGB(99, 132, 147), Limestone = Color3.fromRGB(247, 241, 180),
	Sand = Color3.fromRGB(250, 244, 181), Wood = Color3.fromRGB(151, 112, 67),
	Bark = Color3.fromRGB(118, 83, 45), BarkLight = Color3.fromRGB(156, 112, 62),
	Plank = Color3.fromRGB(234, 221, 155), Cream = Color3.fromRGB(255, 250, 202),
	Teal = Color3.fromRGB(37, 158, 238), Water = Color3.fromRGB(66, 207, 255),
	Cloud = Color3.fromRGB(249, 253, 255), Coral = Color3.fromRGB(255, 124, 55),
	Brass = Color3.fromRGB(255, 210, 36), Iron = Color3.fromRGB(65, 93, 107),
	Lavender = Color3.fromRGB(116, 141, 201), Gold = Color3.fromRGB(255, 221, 0),
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
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.disk(parent: Instance, name: string, width: number, depth: number, thickness: number, pos: Vector3, color: Color3, options: Options?): Part
	local p = Kit.part(parent, name, Vector3.new(thickness, width, depth),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, options)
	p.Shape = Enum.PartType.Cylinder
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
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "PaintedSign", Enum.NormalId.Front
	gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(900, 280)
	gui.LightInfluence, gui.Brightness, gui.AlwaysOnTop = 0.7, 1, false
	gui.Parent = parent
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name, titleLabel.BackgroundTransparency = "Title", 1
	titleLabel.Size, titleLabel.Position = UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.1)
	titleLabel.Font, titleLabel.TextSize, titleLabel.Text = Enum.Font.GothamBold, 61, title
	titleLabel.TextColor3, titleLabel.AutoLocalize = color or Kit.palette.Cream, false
	titleLabel.TextScaled, titleLabel.TextWrapped, titleLabel.Parent = true, true, gui
	local sub = titleLabel:Clone()
	sub.Name, sub.Text, sub.Font = "Caption", subtitle, Enum.Font.Gotham
	sub.Size, sub.Position, sub.Parent = UDim2.fromScale(0.88, 0.23), UDim2.fromScale(0.06, 0.65), gui
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
