--!strict
-- Free travel inside this experience. Clients select an ID; the server owns every position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Rules = require(Shared:WaitForChild("IslandTravelRules"))
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local Travel = {}
local startedWorld: Model? = nil
local BLUE = Color3.fromRGB(64, 145, 211)
local YELLOW = Color3.fromRGB(255, 211, 65)
local CREAM = Color3.fromRGB(255, 250, 226)
local INK = Color3.fromRGB(43, 71, 87)

local function spotBasis(dock: any): CFrame
	return CFrame.new(table.unpack(dock.Spot)) * CFrame.Angles(0, dock.Yaw, 0)
end

function Travel.create(world: Model): Folder
	local existing = world:FindFirstChild("IslandTravelStations")
	if existing and existing:IsA("Folder") then return existing end
	local stations = Instance.new("Folder")
	stations.Name = "IslandTravelStations"
	-- Five tiny persistent collision plates keep a streamed-out pier from becoming a fall.
	-- They exactly overlay its walking surface; island scenery still streams normally.
	local supports = Instance.new("Model")
	supports.Name, supports.ModelStreamingMode = "TravelArrivalSupports", Enum.ModelStreamingMode.Persistent
	for _, dock in Layout.Docks do
		local basis = spotBasis(dock)
		Kit.part(supports, dock.Id .. "ArrivalFloor", Vector3.new(4.4, 0.2, 7.6),
			basis * CFrame.new(0, -0.2, 5.4), CREAM,
			{ collidable = true, transparency = 1, shadow = false })
		local station = Instance.new("Model")
		station.Name, station.ModelStreamingMode = dock.Id, Enum.ModelStreamingMode.Atomic
		station:SetAttribute("TravelSourceId", dock.Id)
		local cf = basis * CFrame.new(6.3, 0, 0.5) * CFrame.Angles(0, math.pi, 0)
		local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3): Part
			return Kit.part(station, name, size, cf * CFrame.new(x, y, z), color)
		end
		block("CreamFoot", Vector3.new(3.5, 0.22, 1.8), 0, 0.05, 0, CREAM)
		local body = block("BlueTicketStand", Vector3.new(2.8, 2.7, 1.1), 0, 1.5, 0, BLUE)
		block("SunshineCounter", Vector3.new(3.3, 0.25, 1.5), 0, 2.96, 0, YELLOW)
		block("NoticePost", Vector3.new(0.24, 1.6, 0.24), 0, 3.6, 0.32, BLUE)
		local board = block("FerryBoard", Vector3.new(3.8, 1.65, 0.3), 0, 4.35, 0.24, CREAM)
		Kit.sign(board, "ISLAND HOP", "FREE  /  PICK A POND", INK)
		block("BlueSunshade", Vector3.new(4.1, 0.24, 1.75), 0, 5.3, 0.1, BLUE)
		block("SunshadeTrim", Vector3.new(4.1, 0.24, 0.15), 0, 5.1, -0.7, YELLOW)
		-- Original toy duck emblem: a clear yellow silhouette above the blue stand.
		local duckBody = Kit.ball(station, "DuckBody", Vector3.new(1.5, 0.87, 0.85), (cf * CFrame.new(0, 5.89, 0.1)).Position, YELLOW)
		duckBody.CFrame = cf * CFrame.new(0, 5.89, 0.1)
		Kit.ball(station, "DuckHead", Vector3.new(0.72, 0.72, 0.72), (cf * CFrame.new(0.48, 6.33, 0.1)).Position, YELLOW)
		block("DuckBill", Vector3.new(0.55, 0.19, 0.4), 0.92, 6.29, 0.05, Color3.fromRGB(240, 153, 56))
		for _, side in { -1, 1 } do
			Kit.ball(station, "DuckEye", Vector3.one * 0.09,
				(cf * CFrame.new(0.62, 6.45, 0.1 + side * 0.33)).Position, INK, { shadow = false })
		end
		block("TicketWindow", Vector3.new(1.95, 1.2, 0.04), 0, 1.88, -0.57, CREAM)
		block("TicketSlot", Vector3.new(1.0, 0.11, 0.05), 0, 1.55, -0.61, INK)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "IslandTravelPrompt", "Choose a pond", "Free island travel"
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

function Travel.start(world: Model, beforeTravel: ((Player) -> boolean)?)
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
	local sources: { [string]: BasePart } = {}
	local destinations: { [string]: CFrame } = {}
	for _, dock in Layout.Docks do destinations[dock.Id] = spotBasis(dock) * CFrame.new(0, 3.3, 5.4) end
	local function distanceFrom(player: Player, source: string): number
		local _, root = livingCharacter(player)
		local stand = sources[source]
		return if root and stand and stand:IsDescendantOf(world) then (root.Position - stand.Position).Magnitude else math.huge
	end
	local function respond(player: Player, status: string, message: string?)
		if player.Parent == Players then event:FireClient(player, status, message) end
	end
	for _, station in stations:GetChildren() do
		if not station:IsA("Model") then continue end
		local source = station:GetAttribute("TravelSourceId")
		local stand = station.PrimaryPart
		local prompt = station:FindFirstChild("IslandTravelPrompt", true)
		if type(source) ~= "string" or not stand or not prompt or not prompt:IsA("ProximityPrompt") then continue end
		sources[source] = stand
		prompt.Triggered:Connect(function(player)
			if world:IsDescendantOf(workspace) and state:open(player.UserId, source, os.clock(), distanceFrom(player, source)) then
				event:FireClient(player, "Open", source)
			end
		end)
	end
	event.OnServerEvent:Connect(function(player: Player, destination: any)
		local now = os.clock()
		local previous = lastPacket[player.UserId]
		if previous and now - previous < 0.15 then return end
		lastPacket[player.UserId] = now
		local source = state:source(player.UserId)
		if not source or player.Parent ~= Players or not world:IsDescendantOf(workspace) then return end
		local ticket = state:take(player.UserId, destination, now, distanceFrom(player, source))
		if not ticket then respond(player, "Rejected", "Step closer to the island stand and try again."); return end
		local character, root = livingCharacter(player)
		local target = destinations[ticket.destination]
		if not character or not root or not target then state:finish(player.UserId, ticket); return end
		player:SetAttribute("IslandTravelBusy", true)
		if beforeTravel then
			local callbackOk, permitted = pcall(beforeTravel, player)
			if not callbackOk or permitted ~= true then
				state:finish(player.UserId, ticket)
				player:SetAttribute("IslandTravelBusy", false)
				respond(player, "Rejected", "Your character is not ready to travel. Please try again in a moment.")
				return
			end
		end
		respond(player, "Loading", "Getting your next pond ready...")
		task.spawn(function()
			-- RequestStreamAroundAsync may yield. Never move a dead, replaced or departed character.
			local ok = pcall(function() player:RequestStreamAroundAsync(target.Position, 3) end)
			local currentCharacter, currentRoot = livingCharacter(player)
			local valid = ok and player.Parent == Players and state:isPending(player.UserId, ticket)
				and character == currentCharacter and root == currentRoot and world:IsDescendantOf(workspace)
				and distanceFrom(player, ticket.source) <= Rules.MaxDistance
			if valid then
				local success = pcall(function()
					local lane = (player.UserId % 3 - 1) * 0.8
					local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
					local clearance = math.max(3.3, humanoid.HipHeight + root.Size.Y * 0.5 + 0.3)
					local desiredRoot = target * CFrame.new(lane, clearance - 3.3, 0)
					-- Custom characters can have a model pivot far away from their root part.
					character:PivotTo(desiredRoot * root.CFrame:ToObjectSpace(character:GetPivot()))
					root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				end)
				if success then respond(player, "Arrived", "Ready to fish!")
				else respond(player, "Rejected", "Travel could not finish. Please try the stand again.") end
			else respond(player, "Rejected", "Travel cancelled. Stay beside the stand and try again.") end
			if state:finish(player.UserId, ticket) and player.Parent == Players then player:SetAttribute("IslandTravelBusy", false) end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player) state:remove(player.UserId); lastPacket[player.UserId] = nil end)
	remotes.Parent = ReplicatedStorage
end

return Travel
