--!strict
-- Free travel inside this experience. Clients select an ID; the server owns every position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("IslandTravelRules"))
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local Travel = {}
local startedWorld: Instance? = nil
local BLUE = Color3.fromRGB(62, 128, 158)
local GOLD = Color3.fromRGB(185, 159, 83)
local CREAM = Color3.fromRGB(207, 203, 176)
local INK = Color3.fromRGB(43, 65, 78)
local STONE = Color3.fromRGB(91, 114, 125)

local function spotBasis(dock: any): CFrame
	return CFrame.new(table.unpack(dock.Spot)) * CFrame.Angles(0, dock.Yaw, 0)
end

function Travel.create(world: Instance): Folder
	local existing = world:FindFirstChild("IslandTravelStations")
	if existing and existing:IsA("Folder") then return existing end
	local stations = Instance.new("Folder")
	stations.Name = "IslandTravelStations"
	-- Persistent plates cover the whole side bay: arriving players always have a
	-- floor even while an Atomic portal and its neighboring pier finish streaming.
	local supports = Instance.new("Model")
	supports.Name, supports.ModelStreamingMode = "TravelArrivalSupports", Enum.ModelStreamingMode.Persistent
	for _, dock in Layout.Docks do
		local basis = spotBasis(dock)
		local bayX = dock.Width / 2 + 4.5
		local gate = basis * CFrame.new(bayX, 0, 8) * CFrame.Angles(0, math.pi / 2, 0)
		Kit.part(supports, dock.Id .. "ArrivalFloor", Vector3.new(13, 0.2, 12),
			basis * CFrame.new(bayX, -0.2, 8), CREAM,
			{ collidable = true, transparency = 1, shadow = false })
		local station = Instance.new("Model")
		station.Name, station.ModelStreamingMode = dock.Id, Enum.ModelStreamingMode.Atomic
		station:SetAttribute("TravelSourceId", dock.Id)
		-- The entry plane and landing are authored once and consumed by the server.
		-- The landing faces back toward the pier, clear of the entry volume.
		station:SetAttribute("PortalEntryCFrame", gate * CFrame.new(0, 3.3, 0))
		station:SetAttribute("TravelArrivalCFrame", basis * CFrame.new(dock.Width / 2 + 0.5, 3.3, 5.4)
			* CFrame.Angles(0, math.pi / 2, 0))
		local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, options: any?): Part
			return Kit.part(station, name, size, gate * CFrame.new(x, y, z), color, options)
		end
		-- Muted framing and transparent color identify a portal without a bright
		-- light source, neon surface, flash, or effects obscuring the fishing view.
		block("PortalBayDeck", Vector3.new(12, 0.16, 13), 0, -0.18, 0, CREAM, { studded = true })
		for _, side in { -1, 1 } do
			block("PortalStoneFoot", Vector3.new(1.6, 0.65, 2.1), side * 4.1, 0.225, 0, STONE, { studded = true })
			block("PortalUpright", Vector3.new(1, 8.9, 1.2), side * 4.1, 4.45, 0, STONE, { studded = true })
			block("PortalInsetStripe", Vector3.new(0.16, 7.3, 0.12), side * 3.53, 4.6, -0.67, BLUE)
			for _, height in { 1.1, 8.4 } do
				block("PortalBrassCollar", Vector3.new(1.15, 0.22, 1.34), side * 4.1, height, 0, GOLD)
			end
			block("PortalThresholdMarker", Vector3.new(0.4, 0.04, 2.4), side * 2.5, -0.075, -2.6, BLUE)
		end
		block("PortalLintel", Vector3.new(9.6, 1.1, 1.5), 0, 9.25, 0, STONE, { studded = true })
		block("PortalCrown", Vector3.new(6.2, 0.25, 1.65), 0, 9.94, 0, GOLD)
		block("PortalVeil", Vector3.new(6.8, 8.6, 0.08), 0, 4.3, 0, BLUE,
			{ transparency = 0.83, shadow = false })
		local header = block("PortalHeader", Vector3.new(6.8, 1.1, 0.16), 0, 9.27, -0.84, CREAM)
		Kit.sign(header, "POND PORTAL", "STEP IN  /  FREE TRAVEL", INK)
		-- A slow segmented orbit reuses the existing distance-limited scenery
		-- animator; it has no collision, sound, lighting, or per-frame world scan.
		local orbit = Kit.model(station, "PortalOrbit")
		local orbitOrigin = gate * CFrame.new(0, 4.6, -0.12)
		orbit.WorldPivot = orbitOrigin
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local cf = orbitOrigin * CFrame.Angles(0, 0, angle) * CFrame.new(0, 3.05, 0)
			Kit.part(orbit, "OrbitRune", Vector3.new(0.63, 0.15, 0.12), cf,
				if index % 3 == 0 then GOLD else BLUE, { transparency = 0.25, shadow = false })
		end
		orbit:SetAttribute("SpinOrigin", orbitOrigin)
		orbit:SetAttribute("SpinRate", 0.18)
		-- The pedestal is beyond the edge of the ordinary casting corridor.
		local pedestal = basis * CFrame.new(bayX, 0, 12.5) * CFrame.Angles(0, math.pi / 2, 0)
		Kit.part(station, "PortalPedestalBase", Vector3.new(1.5, 0.35, 1.5), pedestal * CFrame.new(0, 0.075, 0), STONE)
		Kit.part(station, "PortalPedestalStem", Vector3.new(0.8, 1.9, 0.8), pedestal * CFrame.new(0, 1.1, 0), STONE)
		local body = Kit.part(station, "PortalSelector", Vector3.new(1.9, 0.6, 1.3),
			pedestal * CFrame.new(0, 2.4, 0), BLUE)
		Kit.part(station, "PortalSelectorInset", Vector3.new(1.5, 0.08, 0.9), pedestal * CFrame.new(0, 2.74, 0), CREAM)
		for index = -1, 1 do
			Kit.part(station, "PortalDestinationKey", Vector3.new(0.22, 0.09, 0.35),
				pedestal * CFrame.new(index * 0.4, 2.82, 0), GOLD)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "IslandTravelPrompt", "Choose a pond", "Pond portal · Free travel"
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 5, false
		prompt.Parent, station.PrimaryPart = body, body
		station.Parent = stations
	end
	supports.Parent, stations.Parent = world, world
	return stations
end

local function livingCharacter(player: Player): (Model?, BasePart?)
	local character = player.Character
	if not character then return nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not root.Anchored then
		return character, root
	end
	return nil, nil
end

function Travel.start(world: Instance, beforeTravel: ((Player) -> boolean)?, galleryArrival: ((Player) -> CFrame?)?)
	if startedWorld == world then return end
	assert(startedWorld == nil, "Install one island travel server only")
	startedWorld = world
	local stations = Travel.create(world)
	assert(not ReplicatedStorage:FindFirstChild("FishingTravelRemotes"), "Install one island travel server only")
	local remotes = Instance.new("Folder")
	remotes.Name = "FishingTravelRemotes"
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = "Travel", remotes
	local state = Rules.new()
	local lastPacket: { [number]: number } = {}
	local lastGallery: { [number]: number } = {}
	local galleryPending: { [number]: {} } = {}
	local sources: { [string]: BasePart } = {}
	local destinations: { [string]: CFrame } = {}
	local entries: { [string]: CFrame } = {}
	local entryState: { [number]: { character: Model, source: string?, opened: boolean } } = {}
	local function distanceFrom(player: Player, source: string): number
		local _, root = livingCharacter(player)
		local stand = sources[source]
		return if root and stand and stand:IsDescendantOf(world) then (root.Position - stand.Position).Magnitude else math.huge
	end
	local function respond(player: Player, status: string, message: string?)
		if player.Parent == Players then event:FireClient(player, status, message) end
	end
	local function openPortal(player: Player, source: string): boolean
		if player.Parent == Players and player:GetAttribute("IslandTravelBusy") ~= true and world:IsDescendantOf(workspace)
			and state:open(player.UserId, source, os.clock(), distanceFrom(player, source)) then
			event:FireClient(player, "Open", source)
			return true
		end
		return false
	end
	for _, station in stations:GetChildren() do
		if not station:IsA("Model") then continue end
		local source = station:GetAttribute("TravelSourceId")
		local stand = station.PrimaryPart
		local prompt = station:FindFirstChild("IslandTravelPrompt", true)
		if type(source) ~= "string" or not stand or not prompt or not prompt:IsA("ProximityPrompt") then continue end
		local arrival, entry = station:GetAttribute("TravelArrivalCFrame"), station:GetAttribute("PortalEntryCFrame")
		if typeof(arrival) ~= "CFrame" or typeof(entry) ~= "CFrame" then continue end
		sources[source], destinations[source], entries[source] = stand, arrival, entry
		prompt.Triggered:Connect(function(player) openPortal(player, source) end)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < 0.1 then return end
		elapsed %= 0.1
		if not world:IsDescendantOf(workspace) then return end
		for _, player in Players:GetPlayers() do
			local character, root = livingCharacter(player)
			if not character or not root then entryState[player.UserId] = nil; continue end
			local inside: string? = nil
			for source, entry in entries do
				local point = entry:PointToObjectSpace(root.Position)
				if math.abs(point.X) <= 3 and math.abs(point.Y) <= 3.5 and math.abs(point.Z) <= 1.3 then
					inside = source
					break
				end
			end
			local previous = entryState[player.UserId]
			local opened = previous ~= nil and previous.character == character and previous.source == inside and previous.opened
			-- A quick return can reach the gate during the short request cooldown.
			-- Retry until its first successful open; after that, closing the menu
			-- while standing inside never reopens it. Leaving or respawning resets.
			if inside and not opened then opened = openPortal(player, inside) end
			entryState[player.UserId] = { character = character, source = inside, opened = opened }
		end
	end)
	local function performTravel(
		player: Player, character: Model, root: BasePart, target: CFrame,
		stillPending: () -> boolean, nearSource: () -> boolean, finish: () -> boolean, gallery: boolean
	)
		player:SetAttribute("IslandTravelBusy", true)
		local function complete()
			if finish() and player.Parent == Players then player:SetAttribute("IslandTravelBusy", false) end
		end
		if beforeTravel then
			local callbackOk, permitted = pcall(beforeTravel, player)
			if not callbackOk or permitted ~= true then
				complete()
				respond(player, "Rejected", "Your character is not ready to travel. Please try again in a moment.")
				return
			end
		end
		respond(player, "Loading", if gallery then "Getting your aquarium ready..." else "Getting your next pond ready...")
		task.spawn(function()
			-- Streaming may yield. A departed, replaced or dead avatar is never moved.
			local ok = pcall(function() player:RequestStreamAroundAsync(target.Position, 3) end)
			local currentCharacter, currentRoot = livingCharacter(player)
			local valid = ok and player.Parent == Players and stillPending()
				and character == currentCharacter and root == currentRoot and world:IsDescendantOf(workspace)
				and nearSource()
			if valid then
				local success = pcall(function()
					local lane = if gallery then 0 else (player.UserId % 3 - 1) * 0.8
					local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
					local clearance = math.max(3.3, humanoid.HipHeight + root.Size.Y * 0.5 + 0.3)
					local desiredRoot = target * CFrame.new(lane, clearance - 3.3, 0)
					-- Custom character pivots need not coincide with their root part.
					character:PivotTo(desiredRoot * root.CFrame:ToObjectSpace(character:GetPivot()))
					root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				end)
				if success then respond(player, "Arrived", if gallery then "Your collection is on display!" else "Ready to fish!")
				else respond(player, "Rejected", "Travel could not finish. Please try again.") end
			else respond(player, "Rejected", "Travel cancelled. Stay still and try again.") end
			complete()
		end)
	end
	event.OnServerEvent:Connect(function(player: Player, destination: any)
		local now = os.clock()
		local previous = lastPacket[player.UserId]
		if previous and now - previous < 0.15 then return end
		lastPacket[player.UserId] = now
		if player.Parent ~= Players or not world:IsDescendantOf(workspace) or player:GetAttribute("IslandTravelBusy") == true then return end
		if destination == "gallery" then
			-- An explicit gallery shortcut is allowed anywhere. Its callback owns
			-- the player's plot and landing; no client coordinates are accepted.
			local character, root = livingCharacter(player)
			local previousGallery = lastGallery[player.UserId]
			if not galleryArrival or not character or not root or (previousGallery and now - previousGallery < 1.5) then
				respond(player, "Rejected", "Your aquarium is not ready yet. Please try again in a moment.")
				return
			end
			local ok, target = pcall(galleryArrival, player)
			if not ok or typeof(target) ~= "CFrame" then
				respond(player, "Rejected", "Your aquarium is not ready yet. Please try again in a moment.")
				return
			end
			local ticket, source = {}, root.Position
			galleryPending[player.UserId], lastGallery[player.UserId] = ticket, now
			performTravel(player, character, root, target, function()
				return galleryPending[player.UserId] == ticket
			end, function()
				return (root.Position - source).Magnitude <= Rules.MaxDistance
			end, function()
				if galleryPending[player.UserId] ~= ticket then return false end
				galleryPending[player.UserId] = nil
				return true
			end, true)
			return
		end
		local source = state:source(player.UserId)
		if not source or player.Parent ~= Players or not world:IsDescendantOf(workspace) then return end
		local ticket = state:take(player.UserId, destination, now, distanceFrom(player, source))
		if not ticket then respond(player, "Rejected", "Step closer to the portal and try again."); return end
		local character, root = livingCharacter(player)
		local target = destinations[ticket.destination]
		if not character or not root or not target then state:finish(player.UserId, ticket); return end
		performTravel(player, character, root, target, function()
			return state:isPending(player.UserId, ticket)
		end, function()
			return distanceFrom(player, ticket.source) <= Rules.MaxDistance
		end, function()
			return state:finish(player.UserId, ticket)
		end, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		state:remove(player.UserId)
		lastPacket[player.UserId], entryState[player.UserId] = nil, nil
		lastGallery[player.UserId], galleryPending[player.UserId] = nil, nil
	end)
	remotes.Parent = ReplicatedStorage
end

return Travel
