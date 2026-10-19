--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Rules = require(Shared:WaitForChild("FishingRules"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("InterfaceLayout"))
local Interface = {}

local function centered(label: TextLabel): TextLabel
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end
local function viewport(parent: Instance, name: string, size: UDim2, position: UDim2)
	local view = Instance.new("ViewportFrame")
	view.Name, view.Size, view.Position = name, size, position
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(185, 204, 204)
	view.LightColor = Color3.fromRGB(255, 240, 213)
	view.LightDirection = Vector3.new(-1, -1, -2)
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, -6.5), Vector3.zero)
	camera.FieldOfView = 36
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = view
	return view, world, camera
end

function Interface.new(playerGui: Instance, audio: any, handlers: any)
	assert(not playerGui:FindFirstChild("MolnfiskarnaFishing"), "Install one fishing interface only.")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "MolnfiskarnaFishing", false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	-- A small location label leaves the landscape visible, with one wallet chip.
	local location = Theme.frame(gui, "Location", UDim2.fromOffset(208, 48), UDim2.fromOffset(16, 12))
	location.BackgroundTransparency = 0.08
	local locationName = Theme.text(location, "CLOUD ANGLERS", UDim2.new(1, -24, 0, 21), UDim2.fromOffset(12, 5), 14, Theme.Ink, true)
	local locationSub = Theme.text(location, "SUNDRIFT HARBOR", UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 28), 9, Theme.Muted, true)
	local coins = Theme.frame(gui, "Wallet", UDim2.fromOffset(122, 48), UDim2.new(1, -138, 0, 12))
	Theme.surface(coins)
	Theme.coin(coins, UDim2.fromOffset(10, 10), 28)
	local coinText = Theme.text(coins, "0", UDim2.new(1, -50, 1, 0), UDim2.fromOffset(46, 0), 19, Theme.Ink, true)
	local coinValue = Instance.new("NumberValue")
	coinValue.Parent = gui
	coinValue.Changed:Connect(function(value)
		local amount = math.floor(value + 0.5)
		coinText.Text = if amount >= 1000000 then string.format("%.1fm", amount / 1000000)
			elseif amount >= 10000 then string.format("%.1fk", amount / 1000) else tostring(amount)
	end)
	local coinTween: Tween? = nil
	local soundButton = Theme.button(gui, "SFX", UDim2.fromOffset(44, 48), UDim2.new(1, -190, 0, 12), Theme.Panel)
	soundButton.TextColor3, soundButton.TextSize = Theme.Teal, 11
	soundButton.Activated:Connect(function()
		local muted = audio.toggle()
		soundButton.Text = if muted then "OFF" else "SFX"
		if not muted then audio.ui() end
	end)
	local goalCard = Theme.frame(gui, "Adventure", UDim2.fromOffset(264, 64), UDim2.fromOffset(16, 72))
	Theme.surface(goalCard)
	local goalKicker = Theme.text(goalCard, "NEXT ADVENTURE", UDim2.new(1, -70, 0, 13), UDim2.fromOffset(14, 9), 9, Theme.Teal, true)
	local goalTitle = Theme.text(goalCard, "Land your first fish", UDim2.new(1, -70, 0, 25), UDim2.fromOffset(14, 25), 13, nil, true)
	local goalReward = Theme.text(goalCard, "+10", UDim2.fromOffset(42, 35), UDim2.new(1, -52, 0, 12), 15, Theme.rarity("Common"), true)
	goalReward.TextXAlignment = Enum.TextXAlignment.Right
	local goalTrack = Theme.frame(goalCard, "Progress", UDim2.new(1, -28, 0, 3), UDim2.fromOffset(14, 55), Theme.Line)
	goalTrack.ClipsDescendants = true
	local goalFill = Theme.frame(goalTrack, "Fill", UDim2.fromScale(0, 1), UDim2.fromOffset(0, 0), Theme.Teal)
	local journalButton = Theme.button(gui, "COLLECTION  0/6", UDim2.fromOffset(156, 48), UDim2.fromOffset(16, 150), Theme.Ink)
	journalButton.TextSize = 12

	local panel = Theme.frame(gui, "CastCard", UDim2.fromOffset(360, 122), UDim2.new(0.5, 0, 1, -20))
	panel.AnchorPoint = Vector2.new(0.5, 1)
	Theme.surface(panel)
	local status = centered(Theme.text(panel, "Find the lantern-lit dock to begin.", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 8), 12, Theme.Muted))
	local meter = Theme.frame(panel, "TimingTrack", UDim2.new(1, -40, 0, 20), UDim2.fromOffset(20, 52), Theme.Ink)
	meter.ClipsDescendants = true
	for _, zone in {
		{"Normal", Rules.NormalMin, Rules.NormalMax, Color3.fromRGB(151, 186, 147)},
		{"Fine", Rules.FineMin, Rules.FineMax, Color3.fromRGB(74, 166, 151)},
		{"Brilliant", Rules.BrilliantMin, Rules.BrilliantMax, Theme.Gold},
	} do
		local area = Instance.new("Frame")
		area.Name, area.Position = zone[1], UDim2.fromScale(zone[2], 0)
		area.Size, area.BackgroundColor3 = UDim2.fromScale(zone[3] - zone[2], 1), zone[4]
		area.BorderSizePixel, area.Parent = 0, meter
	end
	local marker = Instance.new("Frame")
	marker.Name, marker.Size = "Needle", UDim2.new(0, 4, 1, 0)
	marker.AnchorPoint, marker.BackgroundColor3 = Vector2.new(0.5, 0), Color3.new(1, 1, 1)
	marker.BorderSizePixel, marker.ZIndex, marker.Parent = 0, 2, meter
	local legend = centered(Theme.text(panel, "AIM FOR GOLD", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 78), 10, Theme.Teal, true))
	local button = Theme.button(panel, "CONNECTING...", UDim2.new(1, -24, 0, 52), UDim2.new(0.5, 0, 0, 46))
	button.AnchorPoint, button.TextSize = Vector2.new(0.5, 0), 16
	local buttonScale = Instance.new("UIScale")
	buttonScale.Parent = button
	local sessionText = centered(Theme.text(panel, "YOUR FIRST DISCOVERY IS WAITING", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 101), 9, Theme.Muted))

	local toast = Theme.frame(gui, "Notice", UDim2.fromOffset(340, 54), UDim2.new(0.5, 0, 0, 12), Theme.Ink)
	toast.AnchorPoint, toast.ZIndex, toast.Visible = Vector2.new(0.5, 0), 30, false
	local toastText = centered(Theme.text(toast, "", UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0), 13, Theme.Panel, true))
	local toastGeneration = 0
	local function notify(text: string)
		toastGeneration += 1
		local generation = toastGeneration
		toastText.Text, toast.Visible = text, true
		task.delay(3, function() if toastGeneration == generation then toast.Visible = false end end)
	end
	-- The collection is a gallery, with a separate workshop rather than squeezed controls.
	local modal = Instance.new("Frame")
	modal.Name, modal.Size = "CollectionOverlay", UDim2.fromScale(1, 1)
	modal.BackgroundColor3, modal.BackgroundTransparency = Theme.Ink, 0.26
	modal.BorderSizePixel, modal.ZIndex, modal.Visible, modal.Parent = 0, 10, false, gui
	modal.Active = true
	local book = Theme.frame(modal, "CollectionBook", UDim2.fromOffset(900, 590), UDim2.fromScale(0.5, 0.5))
	book.AnchorPoint, book.ClipsDescendants = Vector2.new(0.5, 0.5), true
	Theme.surface(book)
	local title = Theme.text(book, "The fish collection", UDim2.new(1, -84, 0, 32), UDim2.fromOffset(22, 16), 25, Theme.Ink, true)
	local bookStats = Theme.text(book, "0 of 6 discovered", UDim2.new(1, -44, 0, 20), UDim2.fromOffset(22, 50), 12, Theme.Muted)
	local close = Theme.button(book, "×", UDim2.fromOffset(44, 44), UDim2.new(1, -58, 0, 14), Theme.Soft)
	close.TextColor3, close.TextSize = Theme.Ink, 25
	local collectionTab = Theme.button(book, "Collection", UDim2.new(0.5, -26, 0, 44), UDim2.fromOffset(18, 80), Theme.Ink)
	local workshopTab = Theme.button(book, "Rod workshop", UDim2.new(0.5, -26, 0, 44), UDim2.new(0.5, 8, 0, 80), Theme.Soft)
	workshopTab.TextColor3 = Theme.Ink
	local function scrollFrame(name: string): ScrollingFrame
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name, scroll.Position = name, UDim2.fromOffset(18, 136)
		scroll.Size = UDim2.new(1, -36, 1, -182)
		scroll.BackgroundTransparency, scroll.BorderSizePixel = 1, 0
		scroll.ScrollBarThickness, scroll.ScrollBarImageColor3 = 3, Theme.Teal
		scroll.CanvasSize, scroll.AutomaticCanvasSize = UDim2.fromOffset(0, 0), Enum.AutomaticSize.Y
		scroll.Parent = book
		return scroll
	end
	local collection = scrollFrame("FishGallery")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize, grid.CellPadding = UDim2.new(1 / 3, -8, 0, 174), UDim2.fromOffset(10, 10)
	grid.SortOrder, grid.Parent = Enum.SortOrder.LayoutOrder, collection
	local entries: { [string]: any } = {}
	local selectedId = Catalog.Species[1].Id
	local hint = Theme.text(book, "Select a fish to explore its entry.", UDim2.new(1, -44, 0, 34), UDim2.new(0, 22, 1, -40), 12, Theme.Muted)
	local currentProfile: any = nil
	local function selectSpecies(id: string)
		selectedId = id
		for fishId, entry in entries do
			entry.stroke.Color = if fishId == id then Theme.Teal else Theme.Line
			entry.stroke.Thickness = if fishId == id then 2 else 1
		end
		local species = Catalog.get(id)
		hint.Text = species.Name .. " · " .. species.Hint
	end
	for index, species in Catalog.Species do
		local card = Theme.button(collection, "", UDim2.fromOffset(200, 174), UDim2.fromOffset(0, 0), Theme.Soft)
		card.Name, card.LayoutOrder = species.Id, index
		local stroke = Theme.stroke(card)
		local view, world = viewport(card, "Portrait", UDim2.new(1, -8, 1, -56), UDim2.fromOffset(4, 0))
		view.Active = false
		local fish = Fish.create(world, nil, species.Id)
		fish:PivotTo(CFrame.Angles(0, -0.24, 0))
		local badge = Theme.frame(card, "RarityDot", UDim2.fromOffset(7, 7), UDim2.fromOffset(12, 12), Theme.rarity(species.Rarity))
		local name = Theme.text(card, species.Name, UDim2.new(1, -20, 0, 23), UDim2.new(0, 10, 1, -51), 14, Theme.Ink, true)
		local best = Theme.text(card, "Undiscovered", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -27), 11, Theme.Muted)
		entries[species.Id] = { view = view, model = fish, status = best, name = name, badge = badge, stroke = stroke, species = species }
		card.Activated:Connect(function() selectSpecies(species.Id); audio.ui() end)
	end
	selectSpecies(selectedId)
	local workshop = scrollFrame("WorkshopPage")
	workshop.Visible = false
	local shopBody = Theme.frame(workshop, "WorkshopContent", UDim2.new(1, -6, 0, 362), UDim2.fromOffset(0, 0), Theme.Panel)
	shopBody.BackgroundTransparency = 1
	local rodStage = Theme.frame(shopBody, "RodStage", UDim2.new(0.4, -12, 0, 230), UDim2.fromOffset(0, 0), Theme.Soft)
	local rodView, rodWorld, rodCamera = viewport(rodStage, "RodPreview", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0))
	rodCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -11), Vector3.zero)
	local rod = Instance.new("Model")
	local function rodPart(name: string, size: Vector3, cf: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Anchored, p.CanCollide, p.Material, p.Parent = true, false, Enum.Material.SmoothPlastic, rod
		return p
	end
	local grip = rodPart("Grip", Vector3.new(0.28, 1.5, 0.28), CFrame.new(0, -1.7, 0), Color3.fromRGB(133, 91, 59))
	rod.PrimaryPart = grip
	rodPart("Shaft", Vector3.new(0.1, 4.6, 0.1), CFrame.new(0, 1.1, 0), Theme.Teal)
	local reelPart = rodPart("Reel", Vector3.new(0.7, 0.7, 0.34), CFrame.new(0.32, -1.4, -0.1), Theme.Gold)
	reelPart.Shape = Enum.PartType.Cylinder
	for y = -1, 3, 0.8 do rodPart("Binding", Vector3.new(0.16, 0.08, 0.16), CFrame.new(0, y, 0), Theme.Gold) end
	-- Set a central model pivot before rotating it as a unit.
	rod.PrimaryPart = nil
	rod.WorldPivot = CFrame.identity
	rod.Parent = rodWorld
	rod:PivotTo(CFrame.Angles(0, 0, -0.4))
	local equipped = centered(Theme.text(rodStage, "EQUIPPED · DRIFTWOOD", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 1, -32), 10, Theme.Teal, true))
	local shopInfo = Theme.frame(shopBody, "UpgradeDetails", UDim2.new(0.6, -8, 0, 230), UDim2.new(0.4, 8, 0, 0), Theme.Panel)
	shopInfo.BackgroundTransparency = 1
	Theme.text(shopInfo, "YOUR NEXT UPGRADE", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 8), 10, Theme.Teal, true)
	local upgradeName = Theme.text(shopInfo, "Breeze Rod", UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, 30), 27, Theme.Ink, true)
	local upgradeDesc = Theme.text(shopInfo, "Unlock more fish and earn extra coins.", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 75), 14, Theme.Muted)
	local upgradeButton = Theme.button(book, "Upgrade · 32 coins", UDim2.new(1, -36, 0, 48), UDim2.new(0, 18, 1, -62))
	upgradeButton.Visible = false
	upgradeButton.Activated:Connect(function()
		local nextRod = if currentProfile then currentProfile.nextUpgrade else nil
		if not nextRod then return end
		if currentProfile.coins < nextRod.cost then
			audio.ui(false)
			notify("Just " .. (nextRod.cost - currentProfile.coins) .. " more coins to go!")
			return
		end
		handlers.upgrade()
	end)
	local income = Theme.frame(shopBody, "OfflineIncome", UDim2.new(1, 0, 0, 100), UDim2.fromOffset(0, 248), Theme.Soft)
	Theme.text(income, "A little gift for your next visit", UDim2.new(1, -32, 0, 27), UDim2.fromOffset(16, 10), 15, Theme.Teal, true)
	local incomeText = Theme.text(income, "Discover fish to earn coins while you are away.", UDim2.new(1, -32, 0, 52), UDim2.fromOffset(16, 40), 12, Theme.Muted)
	local tab = "Collection"
	local function setTab(nextTab: string)
		tab = nextTab
		collection.Visible, workshop.Visible = tab == "Collection", tab == "Workshop"
		collectionTab.BackgroundColor3 = if collection.Visible then Theme.Ink else Theme.Soft
		collectionTab.TextColor3 = if collection.Visible then Theme.Panel else Theme.Ink
		workshopTab.BackgroundColor3 = if workshop.Visible then Theme.Ink else Theme.Soft
		workshopTab.TextColor3 = if workshop.Visible then Theme.Panel else Theme.Ink
		hint.Visible = collection.Visible
		upgradeButton.Visible = workshop.Visible
		title.Text = if collection.Visible then "The fish collection" else "Rod & Reel"
	end
	collectionTab.Activated:Connect(function() setTab("Collection"); audio.ui() end)
	workshopTab.Activated:Connect(function() setTab("Workshop"); audio.ui() end)
	local function openJournal(target: string?)
		setTab(if target == "Workshop" then "Workshop" else "Collection")
		handlers.openJournal()
		audio.ui()
		modal.Visible, panel.Visible = true, false
	end
	journalButton.Activated:Connect(function() openJournal("Collection") end)
	close.Activated:Connect(function() audio.ui(); modal.Visible, panel.Visible = false, true end)

	local reveal = Theme.frame(gui, "DiscoveryCard", UDim2.fromOffset(360, 370), UDim2.fromScale(0.5, 0.46))
	reveal.AnchorPoint, reveal.ZIndex, reveal.Visible = Vector2.new(0.5, 0.5), 5, false
	Theme.surface(reveal)
	local revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal
	local revealTitle = centered(Theme.text(reveal, "A FRESH CATCH", UDim2.new(1, -64, 0, 22), UDim2.fromOffset(32, 18), 11, Theme.Teal, true))
	local halo = Theme.frame(reveal, "PortraitHalo", UDim2.fromOffset(176, 176), UDim2.new(0.5, -88, 0, 53), Theme.Soft)
	Theme.round(halo, 100)
	local view, fishWorld = viewport(reveal, "CatchPortrait", UDim2.new(1, 0, 0, 192), UDim2.fromOffset(0, 43))
	local revealFish: Model? = nil
	local revealName = centered(Theme.text(reveal, "Pufflet", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 232), 28, Theme.Ink, true))
	local revealQuality = centered(Theme.text(reveal, "Common · Normal", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 270), 13, Theme.Muted))
	local earnings = Theme.frame(reveal, "Earnings", UDim2.new(1, -40, 0, 48), UDim2.fromOffset(20, 309), Theme.Soft)
	Theme.coin(earnings, UDim2.fromOffset(14, 10), 28)
	local revealCoins = centered(Theme.text(earnings, "+8 coins", UDim2.new(1, -58, 1, 0), UDim2.fromOffset(46, 0), 16, Theme.Ink, true))
	local closeReveal = Theme.button(reveal, "×", UDim2.fromOffset(44, 44), UDim2.new(1, -48, 0, 3), Theme.Panel)
	closeReveal.TextColor3, closeReveal.TextSize = Theme.Muted, 23
	local revealGeneration, revealBaseScale = 0, 1
	local revealTween: Tween? = nil
	local function hideResult()
		revealGeneration += 1
		if revealTween then revealTween:Cancel() end
		reveal.Visible, panel.Visible = false, not modal.Visible
	end
	closeReveal.Activated:Connect(hideResult)
	local lastPhase = ""
	local panelWidth = 360
	local panelTween: Tween? = nil
	local function setState(phase: string)
		if phase == lastPhase then return end
		lastPhase = phase
		local reeling = phase == "Reeling"
		meter.Visible, legend.Visible, marker.Visible = reeling, reeling, reeling
		button.Position = UDim2.new(0.5, 0, 0, if reeling then 104 else 46)
		sessionText.Position = UDim2.fromOffset(12, if reeling then 159 else 101)
		if panelTween then panelTween:Cancel() end
		panelTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(panelWidth, if reeling then 180 else 122) })
		panelTween:Play()
	end
	local function updateProfile(profile: any)
		if not profile then return end
		if not currentProfile or profile.coins ~= currentProfile.coins then
			if coinTween then coinTween:Cancel() end
			coinTween = TweenService:Create(coinValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = profile.coins })
			coinTween:Play()
		end
		currentProfile = profile
		journalButton.Text = "COLLECTION  " .. profile.species .. "/6"
		sessionText.Text = profile.species .. "/6 DISCOVERED  ·  " .. profile.points .. " COLLECTION POINTS"
		bookStats.Text = profile.species .. " / 6 fish found   ·   " .. profile.points .. " / 18 points"
		equipped.Text = "EQUIPPED · " .. string.upper(profile.rod)
		incomeText.Text = if profile.persistent then "Your fish earn " .. profile.offlineRate .. " coins/min while you are away. Up to 120 coins over 8 hours. Progress saves automatically."
			else "Offline earnings start in the published game. This Studio playtest uses temporary progress."
		goalTitle.Text = profile.goal.title
		goalKicker.Text = "NEXT ADVENTURE  ·  " .. profile.goal.progress .. "/" .. profile.goal.target
		goalReward.Text = "+" .. profile.goal.reward
		TweenService:Create(goalFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(math.clamp(profile.goal.progress / math.max(1, profile.goal.target), 0, 1), 1) }):Play()
		for id, entry in entries do
			local best = profile.best[id]
			entry.view.ImageColor3 = if best then Color3.new(1, 1, 1) else Color3.fromRGB(83, 112, 108)
			entry.view.ImageTransparency = if best then 0 else 0.45
			entry.name.Text = if best then entry.species.Name else "???"
			entry.status.Text = if best then entry.species.Rarity .. " · " .. ({"Normal", "Fine", "Brilliant"})[best]
				elseif entry.species.Level > profile.level then "Rod level " .. entry.species.Level else "Waiting to be found"
		end
		local nextRod = profile.nextUpgrade
		upgradeName.Text = if nextRod then nextRod.name else "Beautifully equipped"
		upgradeDesc.Text = if nextRod then nextRod.description else "Your rod is fully upgraded. Find every fish and chase Brilliant catches."
		upgradeButton.Text = if nextRod then "Upgrade · " .. nextRod.cost .. " coins" else "Fully upgraded"
		upgradeButton.BackgroundColor3 = if nextRod and profile.coins >= nextRod.cost then Theme.Teal else Theme.Muted
	end
	local function showResult(result: any)
		revealGeneration += 1
		local generation = revealGeneration
		audio.catch(result.quality, result.rarity, result.newDiscovery)
		task.delay(0.65, function()
			if generation ~= revealGeneration or modal.Visible then return end
			if revealFish then revealFish:Destroy() end
			revealFish = Fish.create(fishWorld, nil, result.speciesId)
			revealTitle.Text = if result.newDiscovery then "A NEW DISCOVERY" elseif result.improved then "YOUR NEW PERSONAL BEST" else "A FRESH CATCH"
			revealTitle.TextColor3 = Theme.rarity(result.rarity or "Common")
			halo.BackgroundColor3 = Theme.rarity(result.rarity or "Common"):Lerp(Theme.Panel, 0.86)
			revealName.Text, revealQuality.Text = result.species, (result.rarity or "Common") .. " · " .. result.quality
			revealCoins.Text = "+" .. (result.coins or 0) .. " coins" .. (if (result.goalBonus or 0) > 0 then "  +" .. result.goalBonus .. " bonus" else "")
			panel.Visible, reveal.Visible = false, true
			revealScale.Scale = revealBaseScale * 0.85
			if revealTween then revealTween:Cancel() end
			revealTween = TweenService:Create(revealScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = revealBaseScale })
			revealTween:Play()
			task.delay(2.8, function() if generation == revealGeneration then hideResult() end end)
		end)
	end
	local lastWidth, lastHeight = 0, 0
	local function animate(time: number, width: number, height: number)
		if reveal.Visible and revealFish then
			revealFish:PivotTo(CFrame.Angles(0, math.sin(time * 1.3) * 0.24, math.sin(time * 2) * 0.035))
			Fish.animate(revealFish, time)
		end
		if modal.Visible and collection.Visible then
			local entry = entries[selectedId]
			entry.model:PivotTo(CFrame.Angles(0, -0.24 + math.sin(time) * 0.18, math.sin(time * 1.5) * 0.035))
			Fish.animate(entry.model, time)
		end
		local canvas = gui.AbsoluteSize
		local safeWidth = if canvas.X > 0 then canvas.X else width
		local safeHeight = if canvas.Y > 0 then canvas.Y else height
		if safeWidth == lastWidth and safeHeight == lastHeight then return end
		lastWidth, lastHeight = safeWidth, safeHeight
		if panelTween then panelTween:Cancel() end
		if revealTween then revealTween:Cancel() end
		local layout = Layout.measure(safeWidth, safeHeight)
		location.Size = UDim2.fromOffset(math.min(208, layout.width - 218), 48)
		locationName.Text = if layout.narrow then "ANGLERS" else "CLOUD ANGLERS"
		locationName.TextSize = if layout.narrow then 11 else 14
		locationSub.Text = if layout.narrow then "SUNDRIFT" else "SUNDRIFT HARBOR"
		locationSub.TextSize = if layout.narrow then 8 else 9
		goalCard.Size, goalCard.Visible = UDim2.fromOffset(layout.goalWidth, 64), not layout.compact
		journalButton.Position = UDim2.fromOffset(16, layout.journalY)
		journalButton.Size = UDim2.fromOffset(if layout.narrow then 144 else 156, 48)
		panelWidth = layout.panelWidth
		panel.Size = UDim2.fromOffset(panelWidth, if lastPhase == "Reeling" then 180 else 122)
		panel.Position = UDim2.new(0.5, 0, 1, -layout.panelBottom)
		book.Size = UDim2.fromOffset(layout.bookWidth, layout.bookHeight)
		title.TextSize = if layout.narrow or layout.compact then 20 else 25
		bookStats.Visible = not layout.compact
		collectionTab.Position = UDim2.fromOffset(18, if layout.compact then 50 else 80)
		workshopTab.Position = UDim2.new(0.5, 8, 0, if layout.compact then 50 else 80)
		local contentY = if layout.compact then 108 else 136
		collection.Position, collection.Size = UDim2.fromOffset(18, contentY), UDim2.new(1, -36, 1, -contentY - 46)
		workshop.Position, workshop.Size = UDim2.fromOffset(18, contentY), UDim2.new(1, -36, 1, -contentY - 78)
		upgradeButton.Size = UDim2.fromOffset(if layout.narrow or layout.compact then layout.bookWidth - 36 else 244, 48)
		upgradeButton.Position = UDim2.new(1, -18, 1, -62)
		upgradeButton.AnchorPoint = Vector2.new(1, 0)
		grid.CellSize = UDim2.new(1 / layout.columns, -7, 0, layout.cardHeight)
		toast.Size = UDim2.fromOffset(math.min(340, layout.width - 32), 54)
		toast.Position = UDim2.new(0.5, 0, 0, if layout.compact then 64 else 72)
		revealBaseScale = layout.revealScale
		revealScale.Scale = revealBaseScale
		closeReveal.Size = UDim2.fromOffset(44 / revealBaseScale, 44 / revealBaseScale)
		closeReveal.Position = UDim2.new(1, -4 - 44 / revealBaseScale, 0, 3)
		upgradeName.TextSize = if layout.compact then 23 else 27
		upgradeName.Position = UDim2.fromOffset(0, if layout.compact then 22 else 30)
		upgradeDesc.Position = UDim2.fromOffset(0, if layout.compact then 62 else 75)
		upgradeDesc.TextSize = if layout.compact then 12 else 14
		local vertical = layout.workshopVertical
		rodStage.Size = if vertical then UDim2.new(1, 0, 0, 180) else UDim2.new(0.4, -12, 0, 230)
		shopInfo.Size = if vertical then UDim2.new(1, 0, 0, 148) else UDim2.new(0.6, -8, 0, 230)
		shopInfo.Position = if vertical then UDim2.fromOffset(0, 196) else UDim2.new(0.4, 8, 0, 0)
		shopBody.Size = UDim2.new(1, -6, 0, if vertical then 462 else 362)
		income.Position = UDim2.fromOffset(0, if vertical then 356 else 248)
	end
	setState("Connecting")
	return {
		button = button, status = status, marker = marker, legend = legend, buttonScale = buttonScale,
		hideResult = hideResult, showResult = showResult, updateProfile = updateProfile,
		notify = notify, setState = setState, animate = animate, openJournal = openJournal,
		closeJournal = function() modal.Visible,panel.Visible=false,true end,
		isJournalOpen = function() return modal.Visible end,
		isResultOpen = function() return reveal.Visible end,
	}
end
return Interface
