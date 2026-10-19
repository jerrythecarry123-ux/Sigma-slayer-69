--!strict
-- Local procedural animation, driven exclusively by server-approved state.
-- Every client renders the same casts; no animation asset uploads are required.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Config = require(Shared:WaitForChild("FishingConfig"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Scenery = require(script.Parent:WaitForChild("WorldScenery"))
local Presentation = {}

type Actor = {
	player: Player, character: Model?, rig: Model?, tip: Attachment?,
	bobber: Part?, line: Beam?, state: any, landed: boolean, bite: boolean,
	lastCatches: number, castFrom: Vector3?, caughtFish: Model?, catchAt: number,
	catchFrom: Vector3, shoulder: Motor6D?, leftShoulder: Motor6D?, pitch: number, poseWeight: number,
}

local function visualPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cf
	object.Color = color
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = false
	object.Material = Enum.Material.SmoothPlastic
	object.Parent = parent
	return object
end

function Presentation.new(audio: any)
	Scenery.start()
	local folder = Instance.new("Folder")
	folder.Name = "CloudAnglersEffects"
	folder.Parent = workspace
	local actors: { [number]: Actor } = {}
	local random = Random.new()

	local function ripple(position: Vector3)
		local ring = visualPart(folder, "Ripple", Vector3.new(0.06, 0.8, 0.8),
			CFrame.new(position - Vector3.yAxis * 0.25) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(229, 251, 255))
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.45
		TweenService:Create(ring, TweenInfo.new(0.65, Enum.EasingStyle.Quad),
			{ Size = Vector3.new(0.04, 6, 6), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.7)
	end

	local function burst(position: Vector3, golden: boolean)
		for _ = 1, 12 do
			local size = random:NextNumber(0.12, 0.3)
			local bubble = visualPart(folder, "CatchSpark", Vector3.new(size, size, size), CFrame.new(position),
				if golden then Color3.fromRGB(255, 218, 120) else Color3.fromRGB(182, 239, 250))
			bubble.Shape = Enum.PartType.Ball
			bubble.Material = Enum.Material.Neon
			TweenService:Create(bubble, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = position + Vector3.new(random:NextNumber(-2, 2), random:NextNumber(1, 4), random:NextNumber(-2, 2)),
				Transparency = 1,
			}):Play()
			Debris:AddItem(bubble, 0.7)
		end
	end

	local function clearRig(actor: Actor)
		if actor.shoulder and actor.shoulder.Parent then actor.shoulder.Transform = CFrame.identity end
		if actor.leftShoulder and actor.leftShoulder.Parent then actor.leftShoulder.Transform = CFrame.identity end
		if actor.rig then actor.rig:Destroy() end
		if actor.bobber then actor.bobber:Destroy() end
		if actor.caughtFish then actor.caughtFish:Destroy() end
		actor.rig, actor.tip, actor.bobber, actor.line = nil, nil, nil, nil
		actor.shoulder, actor.leftShoulder, actor.caughtFish = nil, nil, nil
	end

	local function getActor(player: Player): Actor
		local existing = actors[player.UserId]
		if existing then return existing end
		local actor: Actor = {
			player = player, state = { phase = "Idle", catches = 0 }, landed = false, bite = false,
			lastCatches = 0, catchAt = 0, catchFrom = Vector3.zero, pitch = 0, poseWeight = 0,
		}
		actors[player.UserId] = actor
		return actor
	end

	local function ensureRig(actor: Actor): BasePart?
		local character = actor.player.Character
		if character ~= actor.character then
			clearRig(actor)
			if actor.character then actor.state = { phase = "Idle", catches = actor.lastCatches } end
			actor.character = character
		end
		if not character then return nil end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if not hand or not hand:IsA("BasePart") then return nil end
		if not actor.rig then
			local rig = Instance.new("Model")
			rig.Name = "FishingRod_" .. actor.player.UserId
			local origin = visualPart(rig, "Grip", Vector3.new(0.28, 0.8, 0.28), CFrame.identity, Color3.fromRGB(101, 76, 66))
			rig.PrimaryPart = origin
			local shaft = visualPart(rig, "Rod", Vector3.new(0.12, 3.5, 0.12), CFrame.new(0, 2, 0), Color3.fromRGB(78, 174, 188))
			visualPart(rig, "Reel", Vector3.new(0.45, 0.45, 0.32), CFrame.new(0, 0.35, -0.25), Color3.fromRGB(243, 196, 107))
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(0, 1.75, 0)
			tip.Parent = shaft
			rig.Parent = folder
			actor.rig, actor.tip = rig, tip
			local right = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
			local left = character:FindFirstChild("LeftShoulder", true) or character:FindFirstChild("Left Shoulder", true)
			actor.shoulder = if right and right:IsA("Motor6D") then right else nil
			actor.leftShoulder = if left and left:IsA("Motor6D") then left else nil
		end
		return hand
	end

	local function createBobber(actor: Actor)
		if actor.bobber or not actor.tip or not actor.rig then return end
		local bobber = visualPart(folder, "Bobber_" .. actor.player.UserId, Vector3.new(0.65, 0.65, 0.65),
			CFrame.new(actor.castFrom or Vector3.zero), Color3.fromRGB(255, 129, 111))
		bobber.Shape = Enum.PartType.Ball
		bobber.Material = Enum.Material.Neon
		local anchor = Instance.new("Attachment")
		anchor.Parent = bobber
		local beam = Instance.new("Beam")
		beam.Attachment0 = actor.tip
		beam.Attachment1 = anchor
		beam.Width0, beam.Width1 = 0.045, 0.025
		beam.FaceCamera = true
		beam.Segments = 12
		beam.Color = ColorSequence.new(Color3.fromRGB(242, 248, 235))
		beam.Transparency = NumberSequence.new(0.12)
		beam.Parent = bobber
		actor.bobber, actor.line = bobber, beam
	end

	local function biteCue(actor: Actor)
		local bobber = actor.bobber
		if not bobber then return end
		actor.bite = true
		ripple(bobber.Position)
		audio.play("Chime", 1.1, bobber, 0.34)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(60, 72)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = true
		gui.Parent = bobber
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "!"
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 52
		label.TextColor3 = Color3.fromRGB(255, 221, 115)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Back), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
		Debris:AddItem(gui, 0.85)
	end

	local function apply(userId: number, incoming: any)
		local player = Players:GetPlayerByUserId(userId)
		if not player then return end
		local actor = getActor(player)
		local previous = actor.state
		local changed = previous.phase ~= incoming.phase or previous.attemptId ~= incoming.attemptId
		local freshCatch = incoming.result ~= nil and incoming.catches > actor.lastCatches
		local hand = ensureRig(actor)
		actor.state = incoming
		actor.lastCatches = incoming.catches
		if changed and incoming.phase == "Waiting" then
			actor.landed, actor.bite = false, false
			actor.castFrom = if hand then hand.Position + Vector3.new(0, 2, 0) else incoming.castTarget
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line = nil, nil
			createBobber(actor)
			if hand then audio.play("Cast", 0.94, hand, 0.26) end
		end
		if incoming.phase == "Idle" then
			local position = if actor.bobber then actor.bobber.Position else incoming.castTarget
			if freshCatch and position then
				if actor.caughtFish then actor.caughtFish:Destroy() end
				actor.caughtFish = Fish.create(folder, "CaughtFish", incoming.result.speciesId)
				actor.catchAt = workspace:GetServerTimeNow()
				actor.catchFrom = position
				burst(position, true)
				ripple(position)
			elseif changed and previous.phase == "Reeling" and position then
				burst(position, false)
				if player == Players.LocalPlayer then audio.play("Miss", 0.8, nil, 0.16) end
			end
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line = nil, nil
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local actor = actors[player.UserId]
		if actor then clearRig(actor) end
		actors[player.UserId] = nil
	end)

	RunService.PreSimulation:Connect(function(deltaTime)
		-- Animator writes Transform before PreSimulation. This pass supplies the fishing pose.
		for _, actor in actors do
			local active = actor.state.phase == "Waiting" or actor.state.phase == "Reeling"
			local previousWeight = actor.poseWeight
			local target = if active then 1 else 0
			actor.poseWeight += (target - actor.poseWeight) * (1 - math.exp(-deltaTime * 14))
			if actor.poseWeight < 0.001 then actor.poseWeight = 0 end
			if actor.poseWeight > 0 then
				if actor.shoulder then
					actor.shoulder.Transform = CFrame.identity:Lerp(CFrame.Angles(1.05 + actor.pitch * 0.3, 0, -0.18), actor.poseWeight)
				end
				if actor.leftShoulder then
					actor.leftShoulder.Transform = CFrame.identity:Lerp(CFrame.Angles(0.7, 0.1, 0.4), actor.poseWeight)
				end
			elseif previousWeight > 0 then
				if actor.shoulder then actor.shoulder.Transform = CFrame.identity end
				if actor.leftShoulder then actor.leftShoulder.Transform = CFrame.identity end
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local time = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do getActor(player) end
		for _, actor in actors do
			local hand = ensureRig(actor)
			local root = if actor.character then actor.character:FindFirstChild("HumanoidRootPart") else nil
			if not hand or not root or not root:IsA("BasePart") or not actor.rig then continue end
			local packet = actor.state
			local active = packet.phase == "Waiting" or packet.phase == "Reeling"
			local target = packet.castTarget or (root.Position + root.CFrame.LookVector * 14)
			local flat = (target - root.Position) * Vector3.new(1, 0, 1)
			local forward = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
			local castT = if packet.readyAt then math.clamp((time - packet.readyAt + Config.PreparationTime) / 0.65, 0, 1) else 1
			local pitch = 0.95
			if packet.phase == "Waiting" then
				pitch = if castT < 0.35 then 0.6 + castT / 0.35 else 1.6 - (castT - 0.35) / 0.65 * 1.1
			elseif packet.phase == "Reeling" then
				pitch = 0.65 + math.sin(time * 18) * 0.07
			end
			actor.pitch = pitch
			local direction = forward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
			actor.rig:PivotTo(CFrame.lookAt(hand.Position, hand.Position + direction) * CFrame.Angles(-math.pi / 2, 0, 0))
			local shaft = actor.rig:FindFirstChild("Rod")
			if shaft and shaft:IsA("BasePart") then
				local level = packet.rodLevel or 0
				shaft.Color = if level >= 3 then Color3.fromRGB(255, 211, 108)
					elseif level >= 2 then Color3.fromRGB(187, 155, 243) else Color3.fromRGB(78, 174, 188)
			end
			if active then
				createBobber(actor)
				local bobber = actor.bobber
				if bobber then
					local from = actor.castFrom or hand.Position
					local arc = from:Lerp(target, castT) + Vector3.new(0, math.sin(castT * math.pi) * 5, 0)
					if castT >= 1 then
						local bob = math.sin(time * (if packet.phase == "Reeling" then 22 else 3)) * 0.16
						arc = target + Vector3.new(0, bob - (if actor.bite then 0.25 else 0), 0)
						if not actor.landed then
							actor.landed = true
							ripple(target)
							audio.play("Splash", 0.95, bobber, 0.32)
						end
					end
					bobber.Position = arc
					if not actor.bite and time >= packet.readyAt then biteCue(actor) end
					if actor.line then actor.line.CurveSize0 = if packet.phase == "Reeling" then 0 else 0.7 end
				end
			end
			if actor.caughtFish then
				local t = math.clamp((time - actor.catchAt) / 1.2, 0, 1)
				local destination = root.Position + Vector3.new(0, 3, 0)
				local position = actor.catchFrom:Lerp(destination, t) + Vector3.new(0, math.sin(t * math.pi) * 7, 0)
				actor.caughtFish:PivotTo(CFrame.new(position) * CFrame.Angles(0, t * math.pi * 4, math.sin(t * 8) * 0.25))
				Fish.animate(actor.caughtFish, time)
				if t >= 1 then
					burst(destination, true)
					actor.caughtFish:Destroy()
					actor.caughtFish = nil
				end
			end
		end
	end)

	return { apply = apply }
end

return Presentation
