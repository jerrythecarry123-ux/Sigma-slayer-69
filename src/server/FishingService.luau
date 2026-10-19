--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Config = require(Shared:WaitForChild("FishingConfig"))
local Rules = require(Shared:WaitForChild("FishingRules"))
local Engine = require(script.Parent:WaitForChild("FishingEngine"))
local World = require(script.Parent:WaitForChild("PrototypeWorld"))
local Service = {}
local started = false

function Service.start()
	assert(not started, "FishingService has already started")
	started = true
	local spot = if Config.CreatePrototypeWorld then World.create() else World.findCustom()
	assert(not ReplicatedStorage:FindFirstChild("FishingRemotes"), "FishingRemotes finns redan; installera bara en kopia.")
	local remotes = Instance.new("Folder")
	remotes.Name = "FishingRemotes"
	local action = Instance.new("RemoteEvent")
	action.Name = "FishingAction"
	action.Parent = remotes
	local state = Instance.new("RemoteEvent")
	state.Name = "FishingState"
	state.Parent = remotes
	local engine = Engine.new(Config, Rules)
	local characterConnections: { [Player]: RBXScriptConnection } = {}
	local function canFish(player: Player): boolean
		local character = player.Character
		if not character then return false end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		return spot:IsDescendantOf(workspace) and humanoid ~= nil and humanoid.Health > 0
			and root ~= nil and root:IsA("BasePart")
			and (root.Position - spot.Position).Magnitude <= Config.MaxDistance
	end
	local function addPlayer(player: Player)
		engine:addPlayer(player.UserId, workspace:GetServerTimeNow())
		if characterConnections[player] then return end
		characterConnections[player] = player.CharacterRemoving:Connect(function()
			-- Invalidate the old avatar's attempt even if a new avatar spawns before a tick.
			local packet = engine:interrupt(player.UserId, workspace:GetServerTimeNow(),
				"Fisket avbröts. Gå tillbaka till bryggan efter att du har återvänt.")
			if packet and player.Parent == Players then state:FireClient(player, packet) end
		end)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = characterConnections[player]
		if connection then connection:Disconnect() end
		characterConnections[player] = nil
		engine:removePlayer(player.UserId)
	end)
	for _, player in Players:GetPlayers() do addPlayer(player) end

	action.OnServerEvent:Connect(function(player, verb, attemptId)
		local packet = engine:command(player.UserId, verb, attemptId, workspace:GetServerTimeNow(), canFish(player))
		if packet then state:FireClient(player, packet) end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < 0.1 then return end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local packet = engine:tick(player.UserId, now, canFish(player))
			if packet then state:FireClient(player, packet) end
		end
	end)
	-- Publish the remotes only after listeners and sessions are ready.
	remotes.Parent = ReplicatedStorage
	print("Molnfiskarna: fiskeprototypen är startad. Framsteg sparas inte ännu.")
end

return Service
