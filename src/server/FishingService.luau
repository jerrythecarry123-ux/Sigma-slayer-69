--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Config = require(Shared:WaitForChild("FishingConfig"))
local Rules = require(Shared:WaitForChild("FishingRules"))
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Engine = require(script.Parent:WaitForChild("FishingEngine"))
local Progression = require(script.Parent:WaitForChild("FishingProgression"))
local ProfileStore = require(script.Parent:WaitForChild("FishingProfileStore"))
local Locations = require(script.Parent:WaitForChild("FishingLocations"))
local World = require(script.Parent:WaitForChild("PrototypeWorld"))
local IslandTravel = require(script.Parent:WaitForChild("IslandTravel"))
local Service = {}
local started = false

function Service.start()
	assert(not started, "FishingService has already started")
	started = true
	local spot = if Config.CreatePrototypeWorld then World.create() else World.findCustom()
	local fishingSpots: { BasePart } = { spot }
	if Config.CreatePrototypeWorld then
		local world = workspace:FindFirstChild("MolnfiskarnaPrototype")
		local spots = if world then world:FindFirstChild("FishingSpots") else nil
		if spots then
			for _, child in spots:GetDescendants() do
				if child:IsA("BasePart") and child.Name == "FishingSpot" and child ~= spot then
					table.insert(fishingSpots, child)
				end
			end
		end
	end
	local locations = Locations.new()
	assert(not ReplicatedStorage:FindFirstChild("FishingRemotes"), "Install one fishing server only.")
	local remotes = Instance.new("Folder")
	remotes.Name = "FishingRemotes"
	local function remote(name: string): RemoteEvent
		local event = Instance.new("RemoteEvent")
		event.Name, event.Parent = name, remotes
		return event
	end
	local action, state, visual = remote("FishingAction"), remote("FishingState"), remote("FishingVisual")
	local random = Random.new()
	local progression = Progression.new(Catalog, function() return random:NextNumber() end)
	local engine = Engine.new(Config, Rules, progression)
	local saving = Config.EnableSaving and (not RunService:IsStudio() or Config.SaveInStudio)
	local store = if saving then ProfileStore.new(Catalog, progression, RunService:IsStudio()) else nil
	local sessions: { [Player]: any } = {}
	local loading: { [Player]: boolean } = {}
	local welcome: { [Player]: any } = {}
	local connections: { [Player]: RBXScriptConnection } = {}
	local lastVisual: { [Player]: string } = {}
	local activeAttempts: { [Player]: number } = {}
	local closing, pendingReleases = false, 0

	local function describeLocation(player: Player, fishingSpot: BasePart)
		local lane = (player.UserId % 4 - 1.5) * 2
		local target = (fishingSpot.CFrame * CFrame.new(lane, -1.2, -14)).Position
		local waterY = fishingSpot:GetAttribute("WaterY")
		if type(waterY) == "number" and waterY == waterY and math.abs(waterY) < math.huge then
			target = Vector3.new(target.X, waterY + 0.2, target.Z)
		end
		local zoneId, zoneName = fishingSpot:GetAttribute("ZoneId"), fishingSpot:GetAttribute("ZoneName")
		return {
			spot = fishingSpot, target = target,
			zoneId = if type(zoneId) == "string" then zoneId else nil,
			zoneName = if type(zoneName) == "string" then zoneName else nil,
		}
	end
	local function decorate(player: Player, packet: any)
		local location = locations:last(player.UserId) or describeLocation(player, spot)
		packet.castTarget = location.target
		packet.zoneId, packet.zoneName = location.zoneId, location.zoneName
		return packet
	end
	local function publicVisual(player: Player, packet: any)
		local result = packet.result
		return decorate(player, {
			phase = packet.phase, catches = packet.catches, attemptId = packet.attemptId,
			readyAt = packet.readyAt, chargeAt = packet.chargeAt,
			rodLevel = if packet.profile then packet.profile.level else 0,
			result = if result then {
				species = result.species, speciesId = result.speciesId, quality = result.quality,
				rarity = result.rarity, newDiscovery = result.newDiscovery,
			} else nil,
		})
	end
	local function emit(player: Player, packet: any)
		activeAttempts[player] = packet.attemptId
		decorate(player, packet)
		local profile = packet.profile
		if profile then profile.persistent = saving; profile.offlineRate = profile.species * 0.25 end
		if welcome[player] then packet.offline = welcome[player]; welcome[player] = nil end
		state:FireClient(player, packet)
		local stats = player:FindFirstChild("leaderstats")
		local score = if stats then stats:FindFirstChild("Collection") else nil
		if score and score:IsA("IntValue") and profile then score.Value = profile.points end
		local key = packet.phase .. ":" .. tostring(packet.attemptId) .. ":" .. packet.catches
			.. ":" .. (if profile then profile.level else 0)
		if lastVisual[player] ~= key then
			lastVisual[player] = key
			visual:FireAllClients(player.UserId, publicVisual(player, packet))
		end
	end
	local function fishingPosition(player: Player): Vector3?
		local character = player.Character
		if not character then return nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		return if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then root.Position else nil
	end
	local function validSpot(fishingSpot: BasePart): boolean
		return fishingSpot.Anchored and fishingSpot:IsDescendantOf(workspace)
	end
	local function nearestLocation(player: Player)
		local position = fishingPosition(player)
		if not position then return nil end
		local candidates = {}
		for _, fishingSpot in fishingSpots do
			if validSpot(fishingSpot) then
				table.insert(candidates, {
					location = describeLocation(player, fishingSpot),
					distance = (position - fishingSpot.Position).Magnitude,
				})
			end
		end
		return Locations.nearest(candidates, Config.MaxDistance)
	end
	local function canFish(player: Player, location: any): boolean
		local position = fishingPosition(player)
		return player:GetAttribute("IslandTravelBusy") ~= true
			and position ~= nil and location ~= nil and validSpot(location.spot)
			and (position - location.spot.Position).Magnitude <= Config.MaxDistance
	end
	local function release(session: any, profile: any)
		if not store or session.closed or session.releaseRequested then return end
		session.releaseRequested = true
		pendingReleases += 1
		task.spawn(function()
			local deadline = os.clock() + 20
			while session.busy and os.clock() < deadline do task.wait(0.1) end
			local ok, reason = store.save(session, profile, true)
			if not ok then warn("Cloud Anglers: final save failed: " .. tostring(reason)) end
			pendingReleases -= 1
		end)
	end
	local function addPlayer(player: Player)
		if loading[player] or connections[player] then return end
		loading[player] = true
		task.spawn(function()
			local session, reason = nil, nil
			if store then session, reason = store.load(player.UserId) end
			loading[player] = nil
			if store and not session then
				warn("Cloud Anglers: profile load blocked: " .. tostring(reason))
				if player.Parent == Players then player:Kick("Your progress could not be loaded safely. Please rejoin in a moment.") end
				return
			end
			if player.Parent ~= Players or closing then
				if session then release(session, session.profile) end
				return
			end
			if session then sessions[player] = session; welcome[player] = session.offline end
			engine:addPlayer(player.UserId, workspace:GetServerTimeNow(), if session then session.profile else nil)
			local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
			stats.Name, stats.Parent = "leaderstats", player
			if not stats:FindFirstChild("Collection") then
				local score = Instance.new("IntValue")
				score.Name, score.Parent = "Collection", stats
			end
			connections[player] = player.CharacterRemoving:Connect(function()
				local packet = engine:interrupt(player.UserId, workspace:GetServerTimeNow(), "Fishing stopped. Return to the dock after respawning.")
				if packet and player.Parent == Players then emit(player, packet) end
			end)
			-- The client asks for Sync after subscribing; it also retries while data loads.
		end)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local profile = engine:exportProfile(player.UserId)
		local session = sessions[player]
		if session and profile then release(session, profile) end
		local connection = connections[player]
		if connection then connection:Disconnect() end
		connections[player], sessions[player], welcome[player], lastVisual[player] = nil, nil, nil, nil
		activeAttempts[player] = nil
		locations:remove(player.UserId)
		engine:removePlayer(player.UserId)
	end)
	for _, player in Players:GetPlayers() do addPlayer(player) end
	if Config.CreatePrototypeWorld then
		local world=workspace:FindFirstChild("MolnfiskarnaPrototype")
		if world and world:IsA("Model") then
			IslandTravel.start(world,function(player)
				if closing or not connections[player] then return false end
				local packet=engine:interrupt(player.UserId,workspace:GetServerTimeNow(),"Ready for your next pond.")
				if packet then emit(player,packet) end
				return true
			end)
		end
	end
	action.OnServerEvent:Connect(function(player, verb, attemptId)
		if closing then return end
		local session = sessions[player]
		if session and os.time() >= session.expires then return end
		-- All state transitions emit synchronously. Keep only the active attempt ID
		-- here, avoiding a full profile snapshot before a request is rate-limited.
		local previousAttemptId = activeAttempts[player]
		local location = locations:forAttempt(player.UserId, previousAttemptId)
		if verb == "Start" and connections[player] and previousAttemptId == nil then location = nearestLocation(player) end
		local packet = engine:command(player.UserId, verb, attemptId, workspace:GetServerTimeNow(), canFish(player, location))
		if packet then
			if verb == "Start" then locations:acceptStart(player.UserId, previousAttemptId, packet, location) end
			emit(player, packet)
			if verb == "Sync" then
				for _, other in Players:GetPlayers() do
					local otherPacket = engine:snapshot(other.UserId)
					if other ~= player and otherPacket and otherPacket.phase ~= "Idle" then
						visual:FireClient(player, other.UserId, publicVisual(other, otherPacket))
					end
				end
			end
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		if closing then return end
		elapsed += deltaTime
		if elapsed < 0.1 then return end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local packet = engine:tick(player.UserId, now, canFish(player, locations:last(player.UserId)))
			if packet then emit(player, packet) end
			local session = sessions[player]
			if session and not session.releaseRequested then
				if os.time() >= session.expires then
					player:Kick("Saving connection was interrupted. Please rejoin to protect your progress.")
				elseif not session.busy and os.clock() - session.lastSave >= 30 then
					local profile = engine:exportProfile(player.UserId)
					if profile then
						task.spawn(function()
							local ok, reason = store.save(session, profile, false)
							if not ok then
								warn("Cloud Anglers: autosave failed: " .. tostring(reason))
								-- Back off; do not exhaust DataStore budgets on every heartbeat.
								session.lastSave = os.clock()
								if reason == "lost_lease" or reason == "invalid_data" then
									player:Kick("Your save session changed. Please rejoin safely.")
								end
							end
						end)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		closing = true
		for player, session in sessions do
			local profile = engine:exportProfile(player.UserId)
			if profile then release(session, profile) end
		end
		local deadline = os.clock() + 25
		while (pendingReleases > 0 or next(loading) ~= nil) and os.clock() < deadline do task.wait(0.1) end
	end)
	remotes.Parent = ReplicatedStorage
	print("Cloud Anglers: ready. Saving " .. (if saving then "enabled." else "disabled in this Studio playtest."))
end
return Service
