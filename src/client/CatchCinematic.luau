--!strict
-- A client-only fish portrait stage. Its private camera belongs to the
-- ViewportFrame: the player's camera, movement and Lighting are never changed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Fish = require(Shared:WaitForChild("FishModel"))
local Rarity = require(Shared:WaitForChild("FishRarity"))
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Cinematic = {}

local function ease(value: number): number
	value = math.clamp(value, 0, 1)
	return value * value * (3 - 2 * value)
end

function Cinematic.new(playerGui: PlayerGui, audio: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "CatchCinematic", false, 65, false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local cover = Instance.new("Frame")
	cover.Name, cover.Size, cover.BackgroundColor3 = "StageCover", UDim2.fromScale(1, 1), Color3.fromRGB(11, 24, 32)
	cover.BackgroundTransparency, cover.BorderSizePixel, cover.Active = .3, 0, true
	cover.Parent = gui
	local stage = Theme.frame(cover, "PortraitStage", UDim2.fromOffset(584, 470), UDim2.fromScale(.5, .5), Color3.fromRGB(21, 43, 52))
	stage.AnchorPoint = Vector2.new(.5, .5)
	stage.ClipsDescendants = true
	local border = Theme.stroke(stage, Theme.Gold, 1.5)
	local bar = Theme.frame(stage, "RarityBar", UDim2.new(1, -56, 0, 3), UDim2.fromOffset(28, 25), Theme.Gold)
	local kicker = Theme.text(stage, "LEGENDARY", UDim2.new(1, -48, 0, 28), UDim2.fromOffset(24, 39), 17, Theme.Gold, true)
	kicker.TextXAlignment = Enum.TextXAlignment.Center
	local speciesLabel = Theme.text(stage, "", UDim2.new(1, -48, 0, 42), UDim2.fromOffset(24, 71), 31, Color3.fromRGB(250, 244, 223), true)
	speciesLabel.TextXAlignment = Enum.TextXAlignment.Center
	local caption = Theme.text(stage, "", UDim2.new(1, -48, 0, 24), UDim2.new(0, 24, 1, -91), 13, Color3.fromRGB(185, 211, 208))
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local skip = Theme.button(stage, "CONTINUE  ·  SKIP", UDim2.fromOffset(214, 46), UDim2.new(.5, 0, 1, -58), Color3.fromRGB(41, 94, 99))
	skip.Name, skip.AnchorPoint, skip.Selectable = "SkipCatch", Vector2.new(.5, 0), true
	local view = Instance.new("ViewportFrame")
	view.Name, view.BackgroundTransparency = "FishStage", 1
	view.Size, view.Position = UDim2.new(1, -32, 1, -222), UDim2.fromOffset(16, 116)
	view.Ambient, view.LightColor, view.LightDirection = Color3.fromRGB(172, 186, 194), Color3.fromRGB(255, 242, 216), Vector3.new(-1, -.7, -1)
	view.Parent = stage
	local world = Instance.new("WorldModel")
	world.Name, world.Parent = "PortraitWorld", view
	local camera = Instance.new("Camera")
	camera.Name, camera.FieldOfView, camera.Parent = "PortraitCamera", 36, view
	view.CurrentCamera = camera
	local motes: { Frame } = {}
	for index = 1, 8 do
		local mote = Theme.frame(view, "Accent" .. index, UDim2.fromOffset(if index % 2 == 0 then 4 else 3, if index % 2 == 0 then 12 else 3), UDim2.fromScale(.5, .5), Theme.Gold)
		mote.AnchorPoint, mote.Rotation, mote.BackgroundTransparency = Vector2.new(.5, .5), index * 29, .35
		mote.ZIndex, mote.Visible = 2, false
		table.insert(motes, mote)
	end
	local reduced, destroyed, generation = false, false, 0
	local active: any = nil
	local render: RBXScriptConnection? = nil
	local selectedBefore: GuiObject? = nil
	local connections: { RBXScriptConnection } = {}
	local seen: { [string]: boolean } = {}
	local death: RBXScriptConnection? = nil
	local characterChild: RBXScriptConnection? = nil
	local function systemReduced(): boolean
		-- Respect Roblox's own accessibility preference even before our settings load.
		return reduced or GuiService.ReducedMotionEnabled
	end
	local function close(complete: boolean)
		if not active then return end
		local previous = active
		active = nil
		generation += 1
		gui.Enabled = false
		if render then render:Disconnect(); render = nil end
		if previous.model then previous.model:Destroy() end
		if GuiService.SelectedObject == skip then
			GuiService.SelectedObject = if selectedBefore and selectedBefore.Parent then selectedBefore else nil
		end
		selectedBefore = nil
		for _, mote in motes do mote.Visible = false end
		-- Clear ownership before callback: it may open another modal or start a cast.
		if complete and previous.complete then previous.complete() end
	end
	local function layout()
		local canvas = gui.AbsoluteSize
		local width, height = math.max(240, canvas.X), math.max(220, canvas.Y)
		local short = height < 430
		local horizontal = short and width >= 480
		stage.Size = UDim2.fromOffset(math.min(584, width - 24), math.min(470, height - 20))
		if horizontal then
			-- Give the fish a real portrait area on a short phone. Stacking the
			-- desktop headings left only a thin strip for the central attraction.
			local split = math.floor(stage.Size.X.Offset * .46)
			local compressed = stage.Size.Y.Offset < 240
			view.Position, view.Size = UDim2.fromOffset(12, 16), UDim2.new(0, split - 20, 1, -32)
			bar.Position, bar.Size = UDim2.fromOffset(split + 14, 18), UDim2.new(1, -split - 38, 0, 3)
			kicker.Position, kicker.Size, kicker.TextSize = UDim2.fromOffset(split + 14, 32), UDim2.new(1, -split - 38, 0, if compressed then 28 else 34), 12
			speciesLabel.Position, speciesLabel.Size, speciesLabel.TextSize = UDim2.fromOffset(split + 14, if compressed then 64 else 77), UDim2.new(1, -split - 38, 0, 36), 23
			caption.Position, caption.Size = UDim2.fromOffset(split + 14, if compressed then 104 else 123), UDim2.new(1, -split - 38, 0, if compressed then 24 else 38)
			skip.Position, skip.Size = UDim2.new(.5, split * .5, 1, -58), UDim2.fromOffset(math.min(214, stage.Size.X.Offset - split - 32), 46)
		else
			bar.Position, bar.Size = UDim2.fromOffset(24, if short then 12 else 25), UDim2.new(1, -48, 0, 3)
			kicker.Position, kicker.Size, kicker.TextSize = UDim2.fromOffset(24, if short then 20 else 39), UDim2.new(1, -48, 0, 28), if short then 13 else 17
			speciesLabel.Position, speciesLabel.Size, speciesLabel.TextSize = UDim2.fromOffset(24, if short then 45 else 71), UDim2.new(1, -48, 0, 42), if width < 360 or short then 24 else 31
			view.Position, view.Size = UDim2.fromOffset(16, if short then 86 else 116), UDim2.new(1, -32, 1, if short then -184 else -222)
			caption.Position, caption.Size = UDim2.new(0, 24, 1, -91), UDim2.new(1, -48, 0, 24)
			skip.Position, skip.Size = UDim2.new(.5, 0, 1, -58), UDim2.fromOffset(214, 46)
		end
		caption.TextSize = if width < 360 then 11 else 13
	end
	local function update(deltaTime: number)
		local data = active
		if not data then return end
		data.elapsed += math.max(0, deltaTime)
		local elapsed, duration = data.elapsed, data.duration
		local quiet = systemReduced()
		local entrance = if quiet then 1 else ease(elapsed / .45)
		local fade = ease((elapsed - duration + .16) / .16)
		cover.BackgroundTransparency = .3 + fade * .7
		layout()
		local canvas = view.AbsoluteSize
		local aspect = if canvas.Y > 0 then math.max(.4, canvas.X / canvas.Y) else 1.5
		-- Sphere framing fits unusual wings and long tails in narrow phone viewports.
		local distance = data.radius / math.sin(math.rad(camera.FieldOfView * .5)) / math.min(1, aspect) * 1.10
		local yaw = if quiet then .42 else .66 - entrance * .24 + math.sin(elapsed * .9) * .035
		local origin = Vector3.new(math.sin(yaw) * distance, data.center.Y + distance * .10, -math.cos(yaw) * distance)
		camera.CFrame = CFrame.lookAt(origin + Vector3.new(data.center.X, 0, data.center.Z), data.center)
		local sway = if quiet then 0 else math.sin(elapsed * (if data.shape == "Whale" then 1.6 else 2.3)) * .09
		local lift = if quiet then 0 else (1 - entrance) * -.8 + math.sin(elapsed * 2) * .06
		local roll = if quiet then 0 elseif data.shape == "Eclipse" then math.sin(elapsed * 1.8) * .08 elseif data.shape == "Veil" then math.sin(elapsed * 2.2) * .06 else sway * .4
		data.model:PivotTo(CFrame.new(0, lift, 0) * CFrame.Angles(0, sway, roll))
		if not quiet then Fish.animate(data.model, elapsed) end
		for index, mote in motes do
			mote.Visible = not quiet and elapsed > .2 and elapsed < duration - .18
			if not mote.Visible then continue end
			-- Reuse the same eight quiet accents for distinct tier compositions.
			-- Their silhouettes stay outside the portrait's central reading area.
			local pulse = math.sin(elapsed * 1.6 + index) * .08
			mote.BackgroundTransparency = .48 + pulse
			if data.effect == "Crown" then
				local angle = (index - 1) / 7 * math.pi
				mote.Position = UDim2.fromScale(.5 - math.cos(angle) * .29, .40 - math.sin(angle) * .12)
				mote.Size = UDim2.fromOffset(3, if index % 2 == 0 then 13 else 6)
				mote.Rotation = (index - 4.5) * 5
			elseif data.effect == "Aurora" then
				local side = if index <= 4 then -1 else 1
				local row = (index - 1) % 4
				local flow = math.sin(elapsed * .85 + row * .6)
				mote.Position = UDim2.fromScale(.5 + side * (.29 + flow * .025), .36 + row * .08)
				mote.Size, mote.Rotation = UDim2.fromOffset(3, 15), side * (16 + flow * 9)
			elseif data.effect == "Eclipse" then
				local angle = -.15 * math.pi + (index - 1) / 7 * math.pi * 1.5 + elapsed * .08
				local comet = index == 8
				mote.Position = UDim2.fromScale(.5 + math.cos(angle) * (if comet then .37 else .33), .49 + math.sin(angle) * .24)
				mote.Size = UDim2.fromOffset(3, if comet then 3 else 11)
				mote.Rotation = math.deg(angle) + 90
			else
				local angle = index * math.pi * .25 - elapsed * .10
				local spread = .22 + entrance * .12
				mote.Position = UDim2.fromScale(.5 + math.cos(angle) * spread, .49 + math.sin(angle) * .24)
				mote.Size, mote.Rotation = UDim2.fromOffset(4, 9), math.deg(angle) + 35
			end
		end
		if elapsed >= duration then close(true) end
	end
	local function play(result: any, onComplete: (() -> ())?): boolean
		if destroyed or not gui:IsDescendantOf(playerGui) or type(result) ~= "table" then return false end
		local tier = Rarity.get(result.rarity or "Common")
		if tier.Rank < 4 then close(false); return false end
		close(false)
		local species = Catalog.get(result.speciesId)
		local color = Color3.fromRGB(table.unpack(tier.Color))
		local model = Fish.create(world, "CinematicFish", species.Id)
		Fish.applyAppearance(model, result.variant, result.weightKg)
		local bounds, size = model:GetBoundingBox()
		local quiet = systemReduced()
		local repeatCatch = seen[species.Id] == true and not result.newDiscovery
		local duration = if quiet then .85 elseif repeatCatch then math.min(1.5, tier.RevealDuration) else tier.RevealDuration
		seen[species.Id] = true
		active = {
			model = model, complete = onComplete, elapsed = 0, duration = math.min(3.8, math.max(.55, duration)),
			radius = math.max(.75, size.Magnitude * .5), center = bounds.Position,
			shape = species.Shape, rank = tier.Rank, effect = species.Effects.Style or tier.Effect,
		}
		border.Color, bar.BackgroundColor3, kicker.TextColor3 = color, color, color
		kicker.Text = tier.Rank .. "/7  ·  " .. string.upper(tier.Title) .. (if result.newDiscovery then "  ·  FIRST DISCOVERY" else "  ·  LANDED")
		speciesLabel.Text = (if result.variant and result.variant ~= "Normal" then result.variant .. " " else "") .. species.Name
		caption.Text = string.format("%.2f kg", result.weightKg or species.WeightMin) .. "  ·  " .. (result.quality or "Normal") .. (if result.newRecord then "  ·  PERSONAL RECORD" else "")
		for _, mote in motes do mote.BackgroundColor3 = color end
		selectedBefore = GuiService.SelectedObject
		gui.Enabled = true
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = skip end
		update(0)
		render = RunService.RenderStepped:Connect(update)
		local current = generation
		-- A watchdog independent of rendering makes a suspended render loop harmless.
		task.delay(active.duration + .35, function()
			if not destroyed and generation == current and active then close(true) end
		end)
		audio.catch(result.quality, result.rarity, result.newDiscovery)
		return true
	end
	table.insert(connections, skip.Activated:Connect(function() close(true) end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, _processed)
		if active and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.ButtonA) then close(true) end
	end))
	local function unbindCharacter()
		if death then death:Disconnect(); death = nil end
		if characterChild then characterChild:Disconnect(); characterChild = nil end
	end
	local function bindCharacter(character: Model)
		-- CharacterAdded can replace a character independently of this module's
		-- removal callback (for example when binding during a streamed respawn).
		-- A previous character's portrait must never finish over the new one.
		close(false)
		unbindCharacter()
		local function humanoidReady(humanoid: Instance)
			if not humanoid:IsA("Humanoid") or death or player.Character ~= character then return end
			death = humanoid.Died:Connect(function()
				if player.Character == character then close(false) end
			end)
			if characterChild then characterChild:Disconnect(); characterChild = nil end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoidReady(humanoid)
		else characterChild = character.ChildAdded:Connect(humanoidReady) end
	end
	table.insert(connections, player.CharacterRemoving:Connect(function() close(false); unbindCharacter() end))
	table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
	if player.Character then bindCharacter(player.Character) end
	table.insert(connections, player:GetAttributeChangedSignal("IslandTravelMenuOpen"):Connect(function()
		if player:GetAttribute("IslandTravelMenuOpen") == true then close(false) end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("IslandTravelBusy"):Connect(function()
		if player:GetAttribute("IslandTravelBusy") == true then close(false) end
	end))
	table.insert(connections, gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(playerGui) then close(false) end
	end))
	return {
		play = play,
		stop = function(_reason: string?) close(false) end,
		setReducedEffects = function(value: boolean)
			reduced = value == true
			if active and systemReduced() then
				active.duration = math.min(active.duration, active.elapsed + .55)
				for _, mote in motes do mote.Visible = false end
			end
		end,
		isPlaying = function(): boolean return active ~= nil end,
		destroy = function()
			if destroyed then return end
			destroyed = true
			close(false)
			unbindCharacter()
			for _, connection in connections do connection:Disconnect() end
			table.clear(connections)
			gui:Destroy()
		end,
	}
end

return Cinematic
