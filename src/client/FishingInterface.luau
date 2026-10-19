--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Rules = require(Shared:WaitForChild("FishingRules"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Interface = {}

function Interface.new(playerGui: Instance, audio: any, handlers: any)
	assert(not playerGui:FindFirstChild("MolnfiskarnaFishing"), "Install one fishing interface only.")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MolnfiskarnaFishing"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local brand = Theme.frame(gui, "Brand", UDim2.fromOffset(214, 48), UDim2.fromOffset(14, 12))
	Theme.surface(brand)
	local brandName = Theme.text(brand, "CLOUD ANGLERS", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 5), 17, Theme.Gold, true)
	Theme.text(brand, "SUNDRIFT ISLES", UDim2.new(1, -24, 0, 15), UDim2.fromOffset(12, 28), 10, Theme.Muted)
	local coins = Theme.frame(gui, "CoinBalance", UDim2.fromOffset(146, 44), UDim2.fromOffset(238, 14))
	Theme.surface(coins, Theme.Gold)
	local coinText = Theme.text(coins, "COINS  0", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 16, Theme.Gold, true)
	local coinValue = Instance.new("NumberValue")
	coinValue.Parent = gui
	coinValue.Changed:Connect(function(value) coinText.Text = "COINS  " .. math.floor(value + 0.5) end)
	local coinTween: Tween? = nil
	local rodChip = Theme.frame(gui, "RodLevel", UDim2.fromOffset(146, 44), UDim2.fromOffset(396, 14))
	Theme.surface(rodChip, Theme.Purple)
	local rodText = Theme.text(rodChip, "ROD LEVEL 0", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 12, Theme.Muted, true)
	local journalButton = Theme.button(gui, "JOURNAL  0/6", UDim2.fromOffset(122, 44), UDim2.new(1, -220, 0, 14), Theme.Gold)
	local soundButton = Theme.button(gui, "AUDIO ON", UDim2.fromOffset(78, 44), UDim2.new(1, -88, 0, 14), Theme.Blue)
	soundButton.TextSize = 11
	soundButton.Activated:Connect(function()
		local muted = audio.toggle()
		soundButton.Text = if muted then "MUTED" else "AUDIO ON"
		if not muted then audio.ui() end
	end)

	local goalCard = Theme.frame(gui, "NextGoal", UDim2.fromOffset(280, 100), UDim2.fromOffset(14, 76))
	Theme.surface(goalCard, Theme.Gold)
	Theme.text(goalCard, "YOUR NEXT ADVENTURE", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 10), 10, Theme.Gold, true)
	local goalTitle = Theme.text(goalCard, "Land your first fish", UDim2.new(1, -28, 0, 29), UDim2.fromOffset(14, 27), 14, nil, true)
	local goalTrack = Theme.frame(goalCard, "Track", UDim2.new(1, -28, 0, 5), UDim2.fromOffset(14, 66), Color3.fromRGB(57, 75, 92))
	goalTrack.ClipsDescendants = true
	local goalFill = Theme.frame(goalTrack, "Fill", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), Theme.Gold)
	local goalProgress = Theme.text(goalCard, "0/1  /  +10 coins", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 77), 11, Theme.Muted)
	local goalSummary = Theme.text(gui, "NEXT: Land your first fish", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 68), 12, Theme.Gold, true)
	goalSummary.Visible = false

	local panel = Theme.frame(gui, "FishingPanel", UDim2.new(0.62, 0, 0, 126), UDim2.new(0.5, 0, 1, -12))
	panel.AnchorPoint = Vector2.new(0.5, 1)
	Theme.surface(panel)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize, constraint.MaxSize = Vector2.new(254, 126), Vector2.new(420, 190)
	constraint.Parent = panel
	local status = Theme.text(panel, "Follow the path to the glowing fishing spot.", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 10), 14)
	status.TextXAlignment = Enum.TextXAlignment.Center
	local meter = Theme.frame(panel, "Meter", UDim2.new(1, -40, 0, 18), UDim2.fromOffset(20, 70), Color3.fromRGB(53, 72, 92))
	meter.ClipsDescendants = true
	for _, zone in {
		{"Normal", Rules.NormalMin, Rules.NormalMax, Color3.fromRGB(98, 174, 144)},
		{"Fine", Rules.FineMin, Rules.FineMax, Theme.Teal},
		{"Brilliant", Rules.BrilliantMin, Rules.BrilliantMax, Theme.Gold},
	} do
		local area = Instance.new("Frame")
		area.Name = zone[1]
		area.Position = UDim2.fromScale(zone[2], 0)
		area.Size = UDim2.fromScale(zone[3] - zone[2], 1)
		area.BackgroundColor3 = zone[4]
		area.BorderSizePixel = 0
		area.Parent = meter
	end
	local marker = Instance.new("Frame")
	marker.Size = UDim2.new(0, 4, 1, 0)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.BackgroundColor3 = Theme.Text
	marker.BorderSizePixel = 0
	marker.ZIndex = 2
	marker.Parent = meter
	local legend = Theme.text(panel, "NORMAL  /  FINE  /  BRILLIANT", UDim2.new(1, -32, 0, 16), UDim2.fromOffset(16, 94), 10, Theme.Muted)
	legend.TextXAlignment = Enum.TextXAlignment.Center
	local button = Theme.button(panel, "CONNECTING...", UDim2.new(1, -32, 0, 48), UDim2.new(0.5, 0, 0, 60))
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.TextSize = 17
	local buttonScale = Instance.new("UIScale")
	buttonScale.Parent = button
	local sessionText = Theme.text(panel, "SESSION COLLECTION", UDim2.new(1, -24, 0, 12), UDim2.fromOffset(12, 111), 9, Theme.Muted)
	sessionText.TextXAlignment = Enum.TextXAlignment.Center
	local count = Theme.text(panel, "", UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 1)
	count.Visible = false

	local toast = Theme.frame(gui, "RewardToast", UDim2.fromOffset(300, 44), UDim2.new(0.5, 0, 0, 72))
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.ZIndex = 20
	Theme.surface(toast, Theme.Gold)
	toast.Visible = false
	local toastText = Theme.text(toast, "", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 13, Theme.Gold, true)
	toastText.TextXAlignment = Enum.TextXAlignment.Center
	local toastGeneration = 0
	local function notify(text: string)
		toastGeneration += 1
		local generation = toastGeneration
		toastText.Text = text
		toast.Visible = true
		task.delay(2.4, function() if toastGeneration == generation then toast.Visible = false end end)
	end

	local modal = Instance.new("Frame")
	modal.Name = "JournalOverlay"
	modal.Size = UDim2.fromScale(1, 1)
	modal.BackgroundColor3 = Theme.Ink
	modal.BackgroundTransparency = 0.2
	modal.BorderSizePixel = 0
	modal.ZIndex = 10
	modal.Visible = false
	modal.Parent = gui
	local book = Theme.frame(modal, "FieldJournal", UDim2.new(0.9, 0, 0.84, 0), UDim2.fromScale(0.5, 0.5))
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.surface(book, Theme.Gold)
	local bookConstraint = Instance.new("UISizeConstraint")
	bookConstraint.MaxSize, bookConstraint.MinSize = Vector2.new(620, 550), Vector2.new(270, 240)
	bookConstraint.Parent = book
	local bookTitle = Theme.text(book, "FIELD JOURNAL", UDim2.new(1, -70, 0, 24), UDim2.fromOffset(16, 12), 20, Theme.Gold, true)
	local bookStats = Theme.text(book, "0/6 species  /  0/18 collection points", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 40), 11, Theme.Muted)
	local bookClose = Theme.button(book, "X", UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 7), Theme.Blue)
	local incomeText = Theme.text(book, "Discover fish to start earning offline coins.", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 59), 10, Theme.Teal)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "SpeciesCards"
	scroll.Position = UDim2.fromOffset(12, 88)
	scroll.Size = UDim2.new(1, -24, 1, -194)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Teal
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = book
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, 126)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local entries: { [string]: any } = {}
	for index, species in Catalog.Species do
		local card = Theme.frame(scroll, species.Id, UDim2.fromOffset(100, 126), UDim2.fromOffset(0, 0))
		card.LayoutOrder = index
		card.BackgroundColor3 = Theme.Ink:Lerp(Theme.Panel, 0.5)
		local icon = Theme.frame(card, "FishIcon", UDim2.fromOffset(58, 32), UDim2.new(0.5, -29, 0, 15), Color3.fromRGB(table.unpack(species.Body)))
		Theme.round(icon, 30)
		local tail = Theme.frame(icon, "Tail", UDim2.fromOffset(18, 24), UDim2.fromOffset(48, 4), Color3.fromRGB(table.unpack(species.Fin)))
		tail.Rotation = 30
		local eye = Theme.frame(icon, "Eye", UDim2.fromOffset(9, 9), UDim2.fromOffset(11, 8), Theme.Text)
		Theme.frame(eye, "Pupil", UDim2.fromOffset(4, 5), UDim2.fromOffset(2, 2), Theme.Ink)
		Theme.text(card, species.Name, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 55), 13, nil, true)
		Theme.text(card, string.upper(species.Rarity), UDim2.new(1, -16, 0, 14), UDim2.fromOffset(8, 78), 9, Theme.rarity(species.Rarity), true)
		local best = Theme.text(card, "Not discovered", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 96), 10, Theme.Muted)
		entries[species.Id] = { icon = icon, status = best, species = species }
	end
	local upgrade = Theme.frame(book, "Workshop", UDim2.new(1, -24, 0, 88), UDim2.new(0, 12, 1, -98))
	upgrade.BackgroundColor3 = Theme.Ink
	local upgradeName = Theme.text(upgrade, "Breeze Rod", UDim2.new(1, -146, 0, 25), UDim2.fromOffset(10, 6), 14, Theme.Gold, true)
	local upgradeDesc = Theme.text(upgrade, "Unlock more species.", UDim2.new(1, -146, 0, 48), UDim2.fromOffset(10, 32), 10, Theme.Muted)
	local upgradeButton = Theme.button(upgrade, "32 COINS", UDim2.fromOffset(120, 46), UDim2.new(1, -130, 0, 21), Theme.Gold)
	local currentProfile: any = nil
	upgradeButton.Activated:Connect(function()
		local nextRod = if currentProfile then currentProfile.nextUpgrade else nil
		if not nextRod then return end
		if currentProfile.coins < nextRod.cost then
			audio.ui(false)
			notify("Need " .. (nextRod.cost - currentProfile.coins) .. " more coins. Keep fishing!")
			return
		end
		handlers.upgrade()
	end)
	local sessionNotice = Theme.text(book, "PLAYTEST: COLLECTION RESETS WHEN YOU LEAVE", UDim2.new(1, -24, 0, 13), UDim2.new(0, 12, 1, -15), 8, Theme.Muted)
	sessionNotice.TextXAlignment = Enum.TextXAlignment.Center
	local function openJournal()
		audio.ui()
		handlers.openJournal()
		modal.Visible = true
	end
	journalButton.Activated:Connect(openJournal)
	bookClose.Activated:Connect(function() audio.ui(); modal.Visible = false end)

	local reveal = Theme.frame(gui, "CatchReveal", UDim2.fromOffset(286, 286), UDim2.fromScale(0.5, 0.46))
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.ZIndex = 5
	Theme.surface(reveal, Theme.Gold)
	reveal.Visible = false
	local revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal
	local revealTitle = Theme.text(reveal, "NICE CATCH!", UDim2.new(1, -36, 0, 24), UDim2.fromOffset(18, 12), 15, Theme.Gold, true)
	local viewport = Instance.new("ViewportFrame")
	viewport.Position, viewport.Size = UDim2.fromOffset(8, 40), UDim2.new(1, -16, 0, 138)
	viewport.BackgroundTransparency = 1
	viewport.Ambient, viewport.LightColor = Color3.fromRGB(210, 220, 232), Color3.fromRGB(255, 235, 200)
	viewport.LightDirection = Vector3.new(-1, -1, -2)
	viewport.Parent = reveal
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, -7.5), Vector3.zero)
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local fishWorld = Instance.new("WorldModel")
	fishWorld.Parent = viewport
	local revealFish: Model? = nil
	local revealName = Theme.text(reveal, "PUFFLET", UDim2.new(1, -36, 0, 28), UDim2.fromOffset(18, 181), 24, nil, true)
	local revealQuality = Theme.text(reveal, "Common / Normal", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(18, 213), 13, Theme.Muted)
	local revealCoins = Theme.text(reveal, "+8 coins", UDim2.new(1, -36, 0, 22), UDim2.fromOffset(18, 245), 16, Theme.Gold, true)
	local closeReveal = Theme.button(reveal, "X", UDim2.fromOffset(40, 40), UDim2.new(1, -44, 0, 4), Theme.Blue)
	local revealGeneration = 0
	local revealBaseScale = 1
	local function hideResult()
		revealGeneration += 1
		reveal.Visible = false
		panel.Visible = true
	end
	closeReveal.Activated:Connect(hideResult)
	local lastPhase = ""
	local function setState(phase: string)
		if phase == lastPhase then return end
		lastPhase = phase
		local active = phase == "Waiting" or phase == "Reeling"
		meter.Visible, legend.Visible = active, active
		marker.Visible = phase == "Reeling"
		button.Position = UDim2.new(0.5, 0, 0, if active then 124 else 60)
		sessionText.Position = UDim2.fromOffset(12, if active then 177 else 111)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.new(0.62, 0, 0, if active then 190 else 126) }):Play()
	end
	local function updateProfile(profile: any)
		if not profile then return end
		if not currentProfile or profile.coins ~= currentProfile.coins then
			if coinTween then coinTween:Cancel() end
			coinTween = TweenService:Create(coinValue, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = profile.coins })
			coinTween:Play()
		end
		currentProfile = profile
		rodText.Text = "ROD LEVEL " .. profile.level
		journalButton.Text = "JOURNAL " .. profile.species .. "/6"
		sessionText.Text = profile.species .. "/6 SPECIES  /  " .. profile.points .. "/18 COLLECTION POINTS"
		bookStats.Text = profile.species .. "/6 species  /  " .. profile.points .. "/18 collection points"
		incomeText.Text = if profile.persistent then "While away: " .. profile.offlineRate .. " coins/min. Up to 120 coins / 8 hours."
			else "Offline income activates in the published game. Studio progress is temporary."
		sessionNotice.Text = if profile.persistent then "PROGRESS SAVED / YOUR COLLECTION EARNS WHILE YOU ARE AWAY"
			else "STUDIO PLAYTEST / PROGRESS RESETS WHEN YOU LEAVE"
		goalTitle.Text = profile.goal.title
		goalSummary.Text = "NEXT: " .. profile.goal.title .. "  " .. profile.goal.progress .. "/" .. profile.goal.target
		goalProgress.Text = profile.goal.progress .. "/" .. profile.goal.target .. "  /  +" .. profile.goal.reward .. " coins"
		TweenService:Create(goalFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(profile.goal.progress / profile.goal.target, 1) }):Play()
		for id, entry in entries do
			local best = profile.best[id]
			entry.icon.BackgroundTransparency = if best then 0 else 0.78
			entry.status.Text = if best then ({"Normal", "Fine", "Brilliant"})[best] .. " best"
				elseif entry.species.Level > profile.level then "Needs rod level " .. entry.species.Level else "Not discovered yet"
		end
		local nextRod = profile.nextUpgrade
		upgradeName.Text = if nextRod then nextRod.name else profile.rod
		upgradeDesc.Text = if nextRod then nextRod.description else "Fully upgraded. Chase your best collection grades."
		upgradeButton.Text = if nextRod then nextRod.cost .. " COINS" else "MAX LEVEL"
		upgradeButton.BackgroundColor3 = if nextRod and profile.coins >= nextRod.cost then Theme.Gold else Theme.Muted
	end
	local function showResult(result: any)
		revealGeneration += 1
		local generation = revealGeneration
		audio.catch(result.quality, result.rarity, result.newDiscovery)
		task.delay(0.65, function()
			if generation ~= revealGeneration or modal.Visible then return end
			if revealFish then revealFish:Destroy() end
			revealFish = Fish.create(fishWorld, nil, result.speciesId)
			revealTitle.Text = if result.newDiscovery then "NEW DISCOVERY!" elseif result.improved then "NEW PERSONAL BEST!" else "NICE CATCH!"
			revealTitle.TextColor3 = Theme.rarity(result.rarity or "Common")
			revealName.Text = string.upper(result.species)
			revealQuality.Text = (result.rarity or "Common") .. " / " .. result.quality
			revealCoins.Text = "+" .. (result.coins or 0) .. " coins" .. (if (result.goalBonus or 0) > 0 then "  +" .. result.goalBonus .. " goal bonus" else "")
			panel.Visible, reveal.Visible = false, true
			revealScale.Scale = revealBaseScale * 0.65
			TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = revealBaseScale }):Play()
			task.delay(2.4, function() if generation == revealGeneration then hideResult() end end)
		end)
	end
	local lastWidth, lastHeight = 0, 0
	local function animate(time: number, width: number, height: number)
		if reveal.Visible and revealFish then
			revealFish:PivotTo(CFrame.Angles(0, math.sin(time * 1.5) * 0.3, math.sin(time * 2) * 0.05))
			Fish.animate(revealFish, time)
		end
		if width == lastWidth and height == lastHeight then return end
		lastWidth, lastHeight = width, height
		local mobile = width < 900
		local compact = height < 480
		brand.Size = UDim2.fromOffset(if mobile then 140 else 214, 48)
		brandName.TextSize = if mobile then 12 else 17
		journalButton.Size = UDim2.fromOffset(if mobile then 86 else 122, 44)
		journalButton.Position = UDim2.new(1, if mobile then -164 else -220, 0, 14)
		journalButton.TextSize = if mobile then 10 else 13
		soundButton.Size = UDim2.fromOffset(if mobile then 60 else 78, 44)
		soundButton.Position = UDim2.new(1, if mobile then -70 else -88, 0, 14)
		soundButton.TextSize = if mobile then 9 else 11
		coins.Position = if mobile then UDim2.fromOffset(14, 66) else UDim2.fromOffset(238, 14)
		rodChip.Position = if mobile then UDim2.new(1, -160, 0, 66) else UDim2.fromOffset(396, 14)
		coins.Size = UDim2.fromOffset(if compact then 100 else 146, 44)
		if compact then coins.Position = UDim2.fromOffset(164, 14) end
		coinText.TextSize = if compact then 12 else 16
		rodChip.Visible = not compact
		goalCard.Position = UDim2.fromOffset(14, if mobile then 120 else 76)
		goalCard.Visible = not compact
		goalSummary.Visible = compact
		reveal.Size = UDim2.fromOffset(286, 286)
		revealBaseScale = math.min(1, (height - 24) / 286)
		if reveal.Visible then revealScale.Scale = revealBaseScale end
		bookTitle.TextSize = if width < 400 then 17 else 20
	end
	setState("Connecting")
	return {
		button = button, status = status, marker = marker, legend = legend, buttonScale = buttonScale,
		count = count, hideResult = hideResult, showResult = showResult, updateProfile = updateProfile,
		notify = notify, setState = setState, animate = animate, openJournal = openJournal,
		isJournalOpen = function() return modal.Visible end,
		isResultOpen = function() return reveal.Visible end,
	}
end
return Interface
