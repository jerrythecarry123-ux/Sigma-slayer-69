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
local Rules = require(Shared:WaitForChild("FishingRules"))
local Rarity = require(Shared:WaitForChild("FishRarity"))
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Scenery = require(script.Parent:WaitForChild("WorldScenery"))
local Presentation = {}
local VIEW_DISTANCE = 180
local EFFECT_GROUP_LIMIT = 8 -- At most 96 transient Parts, shared by all anglers.
local LANDING_CUE_GRACE = .25
local BITE_CUE_GRACE = .6

type Actor = {
	player: Player, character: Model?, rig: Model?, tip: Attachment?,
	bobber: Part?, line: Beam?, state: any, landed: boolean, bite: boolean,
	lastCatches: number, catchStyle: string?, castFrom: Vector3?, caughtFish: Model?, catchAt: number,
	catchFrom: Vector3, shoulder: Motor6D?, leftShoulder: Motor6D?, pitch: number, poseWeight: number,
	shoulderPose: CFrame?, leftPose: CFrame?, shoulderBase: CFrame?, leftBase: CFrame?,
	shaft: BasePart?, middle: BasePart?, lower: BasePart?, crank: BasePart?, crankKnob: BasePart?, bobberAnchor: Attachment?,
	finishLevel: number?,
}

local ROD_FINISH_ROLES = {
	Grip = "Grip", Rod = "Shaft", RodMiddle = "Shaft", RodTip = "Shaft",
	Reel = "Reel", ReelHub = "Hardware", ReelCrank = "Hardware", ReelGrip = "Grip",
}
-- Native cylinders run along local X. Animation frames retain the authored
-- Y-up centerline; this fixed basis gives the three visible sections round
-- cross-sections without changing their lengths, centers or joint positions.
local SHAFT_CYLINDER_FRAME = CFrame.Angles(0, 0, math.pi / 2)

local function forwardFor(root: BasePart, target: Vector3): Vector3
	local flat = (target - root.Position) * Vector3.new(1, 0, 1)
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if flat.Magnitude > .1 then flat.Unit elseif facing.Magnitude > .1 then facing.Unit else Vector3.new(0, 0, -1)
end

local function releasePitch(packet: any, reduced: boolean): number
	return .82 + math.clamp(packet.castPower or .65, 0, 1) * (if reduced then .38 else .62)
end

local function rodFrames(position: Vector3, forward: Vector3, pitch: number, bend: number): (CFrame, CFrame, CFrame)
	local direction = forward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	local grip = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	local middle = grip * CFrame.new(0, 1.925, 0) * CFrame.Angles(-bend, 0, 0) * CFrame.new(0, .6, 0)
	local tip = middle * CFrame.new(0, .6, 0) * CFrame.Angles(-bend * .5, 0, 0) * CFrame.new(0, .275, 0)
	return grip, middle, tip
end

local function poseRod(actor: Actor, grip: CFrame, middle: CFrame, tip: CFrame)
	if actor.rig then actor.rig:PivotTo(grip) end
	if actor.middle then actor.middle.CFrame = middle * SHAFT_CYLINDER_FRAME end
	if actor.shaft then
		actor.shaft.CFrame = tip * SHAFT_CYLINDER_FRAME
		-- Restore the exact native end after world-oriented line frames, avoiding
		-- cumulative local-position roundoff when composing inverse transforms.
		if actor.tip then actor.tip.Position = Vector3.new(actor.shaft.Size.X * .5, 0, 0) end
	end
end

local function nearCamera(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return not camera or (position - camera.CFrame.Position).Magnitude <= VIEW_DISTANCE
end

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

	local reduced = false
	local transient = Instance.new("Folder")
	transient.Name, transient.Parent = "TransientWaterEffects", folder
	local effectGroups: { { model: Model, ownerId: number } } = {}
	local function beginEffect(name: string, ownerId: number): Model?
		-- Prune only when an effect is requested, rather than scanning effects
		-- every frame. Debris still owns the short native lifetime.
		for index = #effectGroups, 1, -1 do
			if not effectGroups[index].model.Parent then table.remove(effectGroups, index) end
		end
		if #effectGroups >= EFFECT_GROUP_LIMIT then
			if ownerId ~= Players.LocalPlayer.UserId then return nil end
			local oldest = 1
			for index, group in effectGroups do
				if group.ownerId ~= ownerId then oldest = index; break end
			end
			table.remove(effectGroups, oldest).model:Destroy()
		end
		local model = Instance.new("Model")
		model.Name, model.Parent = name, transient
		model:SetAttribute("AnglerUserId", ownerId)
		table.insert(effectGroups, { model = model, ownerId = ownerId })
		return model
	end
	local function ripple(position: Vector3, ownerId: number, precise: boolean?)
		if reduced or not nearCamera(position) then return end
		local ring = beginEffect("WaterRing", ownerId)
		if not ring then return end
		local color = if precise then Color3.fromRGB(229, 220, 180) else Color3.fromRGB(208, 233, 230)
		-- Thin fitted tangents form an open ring, rather than a bright solid disc.
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			local center = position - Vector3.yAxis * .17
			local start = center + radial * .5
			local segment = visualPart(ring, "WaterArc", Vector3.new(.055, .025, .28), CFrame.lookAt(start, start + tangent), color)
			segment.Transparency = .48
			local finish = center + radial * 2.4
			TweenService:Create(segment, TweenInfo.new(.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(finish, finish + tangent), Size = Vector3.new(.025, .02, 1.28), Transparency = 1,
			}):Play()
		end
		Debris:AddItem(ring, .7)
	end

	local function burst(position: Vector3, golden: boolean, rarity: string?, ownerId: number)
		if reduced or not nearCamera(position) then return end
		local tier = Rarity.get(rarity or "Common")
		local color = if golden then Color3.fromRGB(227, 194, 112) else Color3.fromRGB(163, 212, 218)
		local crown = beginEffect("WaterCrown", ownerId)
		if not crown then return end
		for index = 1, 6 do
			local angle = index * math.pi / 3 + random:NextNumber(-.10, .10)
			local radius = random:NextNumber(.8, 1.8)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local droplet = visualPart(crown, "WaterDrop", Vector3.new(.09, .22, .09), CFrame.new(position + direction * .15), color)
			droplet.Shape = Enum.PartType.Ball
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, droplet
			droplet.Transparency = .25
			TweenService:Create(droplet, TweenInfo.new(.46, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(position + direction * radius + Vector3.yAxis * random:NextNumber(.5, 1.3)),
				Size = Vector3.new(.035, .07, .035), Transparency = 1,
			}):Play()
		end
		-- Exceptional catches use six precise accents, not an unbounded particle storm.
		if tier.Rank >= 4 then
			for index = 1, 6 do
				local angle = index * math.pi / 3
				local accent = visualPart(crown, "RarityAccent", Vector3.new(.07, .07, .07), CFrame.new(position), Color3.fromRGB(table.unpack(tier.Color)))
				TweenService:Create(accent, TweenInfo.new(.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = position + Vector3.new(math.cos(angle) * 1.8, 1 + index % 2 * .6, math.sin(angle) * 1.8), Transparency = 1,
				}):Play()
			end
		end
		Debris:AddItem(crown, .7)
	end

	local function clearRig(actor: Actor)
		if actor.shoulder and actor.shoulder.Parent and actor.shoulder.Transform == actor.shoulderPose then actor.shoulder.Transform = actor.shoulderBase or CFrame.identity end
		if actor.leftShoulder and actor.leftShoulder.Parent and actor.leftShoulder.Transform == actor.leftPose then actor.leftShoulder.Transform = actor.leftBase or CFrame.identity end
		if actor.rig then actor.rig:Destroy() end
		if actor.bobber then actor.bobber:Destroy() end
		if actor.caughtFish then actor.caughtFish:Destroy() end
		actor.rig, actor.tip, actor.bobber, actor.line = nil, nil, nil, nil
		actor.shoulder, actor.leftShoulder, actor.caughtFish = nil, nil, nil
		actor.shaft, actor.middle, actor.lower, actor.crank, actor.crankKnob, actor.bobberAnchor = nil, nil, nil, nil, nil, nil
		actor.shoulderPose, actor.leftPose, actor.shoulderBase, actor.leftBase = nil, nil, nil, nil
		actor.finishLevel = nil
	end

	local function finishRig(actor: Actor)
		local requested = actor.state.rodLevel
		local level = if type(requested) == "number" and requested == requested and requested % 1 == 0
			and requested >= 0 and requested < #Catalog.Rods then requested else 0
		if actor.finishLevel == level then return end
		local rig = actor.rig
		if not rig then return end
		local rod = Catalog.Rods[level + 1]
		for name, role in ROD_FINISH_ROLES do
			local part = rig:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local finish = rod.Finish[role]
				part.Color = Color3.fromRGB(table.unpack(finish.Color))
				part.Material = Enum.Material[finish.Material]
			end
		end
		rig:SetAttribute("RodLevel", level)
		rig:SetAttribute("RodName", rod.Name)
		actor.finishLevel = level
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
	local function visible(actor: Actor): boolean
		if actor.player:GetAttribute("IslandTravelBusy") == true or actor.player:GetAttribute("IslandTravelMenuOpen") == true then return false end
		local character = actor.player.Character
		if not character or not character:IsDescendantOf(workspace) then return false end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return false end
		return nearCamera(root.Position)
	end

	local function ensureRig(actor: Actor): BasePart?
		local character = actor.player.Character
		if character ~= actor.character then
			clearRig(actor)
			if actor.character then actor.state = { phase = "Idle", catches = actor.lastCatches } end
			actor.character = character
		end
		if not character or not character:IsDescendantOf(workspace) then clearRig(actor); return nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			clearRig(actor)
			actor.state = { phase = "Idle", catches = actor.lastCatches }
			return nil
		end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if not hand or not hand:IsA("BasePart") then clearRig(actor); return nil end
		if not actor.rig and actor.state.phase ~= "ChargingCast" and actor.state.phase ~= "Waiting" and actor.state.phase ~= "Reeling" and not actor.caughtFish then return hand end
		if not actor.rig then
			local rig = Instance.new("Model")
			rig.Name = "FishingRod_" .. actor.player.UserId
			local origin = visualPart(rig, "Grip", Vector3.new(0.28, 0.8, 0.28), CFrame.identity, Color3.fromRGB(101, 76, 66))
			rig.PrimaryPart = origin
			local lower = visualPart(rig, "Rod", Vector3.new(1.55, 0.13, 0.13), CFrame.new(0, 1.15, 0) * SHAFT_CYLINDER_FRAME, Color3.fromRGB(78, 174, 188))
			local middle = visualPart(rig, "RodMiddle", Vector3.new(1.2, 0.105, 0.105), CFrame.new(0, 2.525, 0) * SHAFT_CYLINDER_FRAME, Color3.fromRGB(78, 174, 188))
			local shaft = visualPart(rig, "RodTip", Vector3.new(0.55, 0.075, 0.075), CFrame.new(0, 3.4, 0) * SHAFT_CYLINDER_FRAME, Color3.fromRGB(78, 174, 188))
			lower.Shape, middle.Shape, shaft.Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder, Enum.PartType.Cylinder
			local reel = visualPart(rig, "Reel", Vector3.new(.22, .47, .47), CFrame.new(0, .35, -.25) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(220, 183, 109))
			reel.Shape = Enum.PartType.Cylinder
			local hub = visualPart(rig, "ReelHub", Vector3.new(.11, .14, .14), CFrame.new(0, .35, -.385) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(158, 166, 155))
			hub.Shape, hub.Material = Enum.PartType.Cylinder, Enum.Material.Metal
			local crank = visualPart(rig, "ReelCrank", Vector3.new(.075, .30, .075), CFrame.new(0, .50, -.43), Color3.fromRGB(85, 103, 103))
			local knob = visualPart(rig, "ReelGrip", Vector3.new(.12, .12, .12), CFrame.new(0, .67, -.49), Color3.fromRGB(93, 78, 65))
			knob.Shape = Enum.PartType.Ball
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(shaft.Size.X * .5, 0, 0)
			tip.Parent = shaft
			rig.Parent = folder
			actor.rig, actor.tip = rig, tip
			actor.shaft, actor.middle, actor.lower, actor.crank, actor.crankKnob = shaft, middle, lower, crank, knob
			local right = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
			local left = character:FindFirstChild("LeftShoulder", true) or character:FindFirstChild("Left Shoulder", true)
			actor.shoulder = if right and right:IsA("Motor6D") then right else nil
			actor.leftShoulder = if left and left:IsA("Motor6D") then left else nil
		end
		finishRig(actor)
		return hand
	end

	local function createBobber(actor: Actor)
		if actor.bobber or not actor.tip or not actor.rig then return end
		local time, packet = workspace:GetServerTimeNow(), actor.state
		-- Streaming/distance recovery displays the current cast without replaying
		-- its old splash or bite audio as though it had just happened.
		if packet.castAt and time > packet.castAt + (packet.castDuration or .65) + LANDING_CUE_GRACE then actor.landed = true end
		if packet.readyAt and time > packet.readyAt + BITE_CUE_GRACE then actor.bite = true end
		local bobber = visualPart(folder, "Bobber_" .. actor.player.UserId, Vector3.new(0.65, 0.65, 0.65),
			CFrame.new(actor.castFrom or Vector3.zero), Color3.fromRGB(255, 129, 111))
		bobber.Shape = Enum.PartType.Ball
		bobber.Material = Enum.Material.SmoothPlastic
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
		actor.bobber, actor.line, actor.bobberAnchor = bobber, beam, anchor
	end

	local function biteCue(actor: Actor)
		local bobber = actor.bobber
		if not bobber then return end
		actor.bite = true
		ripple(bobber.Position, actor.player.UserId)
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
		if not reduced then TweenService:Create(gui, TweenInfo.new(.3, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 2.7, 0) }):Play() end
		Debris:AddItem(gui, 0.85)
	end

	local function apply(userId: number, incoming: any)
		local player = Players:GetPlayerByUserId(userId)
		if not player then return end
		local actor = getActor(player)
		local previous = actor.state
		local changed = previous.phase ~= incoming.phase or previous.attemptId ~= incoming.attemptId
		local freshCatch = incoming.result ~= nil and incoming.catches > actor.lastCatches
		actor.state = incoming
		if changed and (incoming.phase == "ChargingCast" or incoming.phase == "Waiting") then actor.landed, actor.bite = false, false end
		if not visible(actor) then
			clearRig(actor)
			actor.lastCatches = incoming.catches
			return
		end
		local hand = ensureRig(actor)
		local humanoid = if actor.character then actor.character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health <= 0 then
			-- A transport callback can arrive after Died and before the server's
			-- next cancellation heartbeat. Retain its catch count, but never
			-- recreate a fish/burst on the dead character in that interval.
			actor.lastCatches = incoming.catches
			actor.state = { phase = "Idle", catches = incoming.catches }
			return
		end
		actor.state = incoming
		actor.lastCatches = incoming.catches
		if changed and incoming.phase == "ChargingCast" then
			if actor.caughtFish then actor.caughtFish:Destroy(); actor.caughtFish = nil end
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line, actor.bobberAnchor = nil, nil, nil
		end
		if changed and incoming.phase == "Waiting" then
			if actor.caughtFish then actor.caughtFish:Destroy(); actor.caughtFish = nil end
			local root = if actor.character then actor.character:FindFirstChild("HumanoidRootPart") else nil
			if hand and root and root:IsA("BasePart") and actor.tip then
				local target = incoming.castTarget or (root.Position + root.CFrame.LookVector * 14)
				local pitch = if incoming.castChargeAt then releasePitch(incoming, reduced) else .72
				local gripFrame, middleFrame, tipFrame = rodFrames(hand.Position, forwardFor(root, target), pitch, .015)
				poseRod(actor, gripFrame, middleFrame, tipFrame)
				actor.castFrom = actor.tip.WorldPosition
			else actor.castFrom = incoming.castTarget end
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line, actor.bobberAnchor = nil, nil, nil
			createBobber(actor)
			if hand and workspace:GetServerTimeNow() <= (incoming.castAt or workspace:GetServerTimeNow()) + LANDING_CUE_GRACE then
				audio.play("Cast", .92 + (incoming.castPower or .65) * .04, hand, .26)
			end
		end
		if incoming.phase == "Idle" then
			local position = if actor.bobber then actor.bobber.Position else incoming.castTarget
			if freshCatch and position and hand and nearCamera(position) then
				if actor.caughtFish then actor.caughtFish:Destroy() end
				actor.caughtFish = Fish.create(folder, "CaughtFish", incoming.result.speciesId)
				Fish.applyAppearance(actor.caughtFish, incoming.result.variant, incoming.result.weightKg)
				actor.catchStyle = Catalog.get(incoming.result.speciesId).Shape
				actor.catchAt = workspace:GetServerTimeNow()
				actor.catchFrom = position
				burst(position, incoming.result.quality == "Brilliant" or incoming.result.variant == "Golden", incoming.result.rarity, userId)
				ripple(position, userId)
			elseif not freshCatch and incoming.outcome == "Missed" and changed and previous.phase == "Reeling" and position then
				burst(position, false, nil, userId)
				if player == Players.LocalPlayer then audio.play("Miss", 0.8, nil, 0.16) end
			end
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line, actor.bobberAnchor = nil, nil, nil
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
			local active = actor.state.phase == "ChargingCast" or actor.state.phase == "Waiting" or actor.state.phase == "Reeling" or actor.caughtFish ~= nil
			local previousWeight = actor.poseWeight
			local target = if active then 1 else 0
			actor.poseWeight += (target - actor.poseWeight) * (1 - math.exp(-deltaTime * 14))
			if actor.poseWeight < 0.001 then actor.poseWeight = 0 end
			if actor.poseWeight > 0 then
				if actor.shoulder then
					local authored = actor.shoulder.Transform
					if authored ~= actor.shoulderPose then actor.shoulderBase = authored end
					local base = actor.shoulderBase or CFrame.identity
					actor.shoulderPose = base * CFrame.Angles((1.05 + actor.pitch * .3) * actor.poseWeight, 0, -.18 * actor.poseWeight)
					actor.shoulder.Transform = actor.shoulderPose
				end
				if actor.leftShoulder then
					local authored = actor.leftShoulder.Transform
					if authored ~= actor.leftPose then actor.leftBase = authored end
					local base = actor.leftBase or CFrame.identity
					actor.leftPose = base * CFrame.Angles(.7 * actor.poseWeight, .1 * actor.poseWeight, .4 * actor.poseWeight)
					actor.leftShoulder.Transform = actor.leftPose
				end
			elseif previousWeight > 0 then
				if actor.shoulder and actor.shoulder.Transform == actor.shoulderPose then actor.shoulder.Transform = actor.shoulderBase or CFrame.identity end
				if actor.leftShoulder and actor.leftShoulder.Transform == actor.leftPose then actor.leftShoulder.Transform = actor.leftBase or CFrame.identity end
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local time = workspace:GetServerTimeNow()
		for _, actor in actors do
			if not visible(actor) then
				if actor.rig or actor.caughtFish or actor.bobber then clearRig(actor) end
				continue
			end
			local charging = actor.state.phase == "ChargingCast"
			local active = actor.state.phase == "Waiting" or actor.state.phase == "Reeling"
			if not charging and not active and not actor.caughtFish and actor.poseWeight == 0 then
				if actor.rig then clearRig(actor) end
				continue
			end
			local hand = ensureRig(actor)
			local root = if actor.character then actor.character:FindFirstChild("HumanoidRootPart") else nil
			if not hand or not root or not root:IsA("BasePart") or not actor.rig then continue end
			local packet = actor.state
			local target = packet.castTarget or (root.Position + root.CFrame.LookVector * 14)
			local forward = forwardFor(root, target)
			local castAt = packet.castAt or ((packet.readyAt or time) - Config.PreparationTime)
			local castT = math.clamp((time - castAt) / (packet.castDuration or .65), 0, 1)
			local difficulty = packet.difficulty or 0
			local frequency = if packet.behavior == "Dart" then 14 elseif packet.behavior == "Surge" then 7 elseif packet.behavior == "Glide" then 4 else 9
			local pitch = 0.95
			local windup = if charging then Rules.castProgressAt(packet, time) else 0
			if charging then
				pitch = .82 + windup * (if reduced then .38 else .62)
			elseif packet.phase == "Waiting" then
				if packet.castChargeAt then
					local release = math.clamp(castT / .62, 0, 1)
					pitch = .52 + (releasePitch(packet, reduced) - .52) * (1 - release * release * (3 - 2 * release))
				else
					pitch = if castT < .3 then .72 + math.sin(castT / .3 * math.pi * .5) * .84 else .52 + 1.04 * (1 - math.sin((castT - .3) / .7 * math.pi * .5))
				end
			elseif packet.phase == "Reeling" then
				pitch = .67 + (if reduced then 0 else math.sin(time * frequency) * (.035 + difficulty * .07))
			end
			actor.pitch = pitch
			local tension = if packet.phase == "Reeling" then math.clamp((time - (packet.chargeAt or time)) / (packet.duration or 1), 0, 1) else 0
			local bend = if charging then .015 + windup * windup * .045
				elseif packet.phase == "Reeling" then 0.07 + tension * (.14 + difficulty * .15) + (if reduced then 0 else math.sin(time * frequency) * .018)
				else .015 + math.sin(castT * math.pi) * .04
			local rodPivot, middleFrame, tipFrame = rodFrames(hand.Position, forward, pitch, bend)
			poseRod(actor, rodPivot, middleFrame, tipFrame)
			local crankPivot = rodPivot * CFrame.new(0, .35, -.43) * CFrame.Angles(0, 0, if packet.phase == "Reeling" and not reduced then time * 9 else 0)
			if actor.crank then actor.crank.CFrame = crankPivot * CFrame.new(0, .15, 0) end
			if actor.crankKnob then actor.crankKnob.CFrame = crankPivot * CFrame.new(0, .32, -.06) end
			if active then
				createBobber(actor)
				local bobber = actor.bobber
				if bobber then
					local from = actor.castFrom or hand.Position
					local height = 3.4 + (packet.castPower or .65) * 1.2
					local arc = from:Lerp(target, castT) + Vector3.new(0, 4 * castT * (1 - castT) * height, 0)
					if castT >= 1 then
						local bob = math.sin(time * (if packet.phase == "Reeling" and not reduced then frequency * 1.5 else 3)) * (if reduced then .06 else .09)
						local nibble = if not actor.bite and time > (packet.readyAt or math.huge) - 0.2 then math.sin(time * 30) * 0.11 else 0
						local tug = if packet.phase == "Reeling" then math.sin(time * (if reduced then 3 else frequency)) * (.10 + difficulty * .28) * (if reduced then .5 else 1) else 0
						arc = target + Vector3.new(forward.Z * tug, bob + nibble - (if actor.bite then 0.25 else 0), -forward.X * tug)
						if not actor.landed then
							actor.landed = true
							ripple(target, actor.player.UserId, packet.castGrade == "Perfect")
							audio.play("Splash", 0.95, bobber, 0.32)
						end
					end
					bobber.Position = arc
					if not actor.bite and time >= packet.readyAt then biteCue(actor) end
					if actor.line and actor.tip and actor.shaft and actor.bobberAnchor then
						local tipPosition = actor.tip.WorldPosition
						local lineFrame = CFrame.fromMatrix(tipPosition, Vector3.yAxis, forward, Vector3.yAxis:Cross(forward))
						actor.tip.CFrame = actor.shaft.CFrame:Inverse() * lineFrame
						actor.bobberAnchor.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, forward, Vector3.yAxis:Cross(forward))
						local sag = if packet.phase == "Reeling" then .04 else .65
						actor.line.CurveSize0, actor.line.CurveSize1 = -sag, sag
					end
				end
			end
			if actor.caughtFish then
				local elapsed = time - actor.catchAt
				local t = math.clamp(elapsed / 0.95, 0, 1)
				local destination = root.Position + Vector3.new(0, 3.5, 0) + root.CFrame.LookVector * 1.6
				local flight = t * t * (3 - 2 * t)
				local broad = actor.catchStyle == "Whale" or actor.catchStyle == "Eclipse" or actor.catchStyle == "Ray"
				local position = if reduced then destination else actor.catchFrom:Lerp(destination, flight) + Vector3.new(0, math.sin(t * math.pi) * (if broad then 3.1 else 4.2), 0)
				local roll = if reduced then 0 else math.sin(t * math.pi * (if broad then 1 else 2)) * (if broad then .13 else .24)
				actor.caughtFish:PivotTo(CFrame.new(position) * CFrame.Angles(0, if reduced then .2 else .2 + math.sin(t * math.pi) * .65, roll))
				if not reduced then Fish.animate(actor.caughtFish, time) end
				if elapsed >= (if reduced then .7 else 1.3) then
					-- The flight resolves cleanly into the portrait without a second burst.
					actor.caughtFish:Destroy()
					actor.caughtFish = nil
				end
			end
		end
	end)

	return {
		apply = apply,
		setReducedEffects = function(value: boolean)
			reduced = value == true
			if reduced then for _, effect in transient:GetChildren() do effect:Destroy() end end
		end,
	}
end

return Presentation
