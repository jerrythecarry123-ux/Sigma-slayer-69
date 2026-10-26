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
local Rarity = require(Shared:WaitForChild("FishRarity"))
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Scenery = require(script.Parent:WaitForChild("WorldScenery"))
local Presentation = {}

type Actor = {
	player: Player, character: Model?, rig: Model?, tip: Attachment?,
	bobber: Part?, line: Beam?, state: any, landed: boolean, bite: boolean,
	lastCatches: number, catchStyle: string?, castFrom: Vector3?, caughtFish: Model?, catchAt: number,
	catchFrom: Vector3, shoulder: Motor6D?, leftShoulder: Motor6D?, pitch: number, poseWeight: number,
	shoulderPose: CFrame?, leftPose: CFrame?, shoulderBase: CFrame?, leftBase: CFrame?,
	shaft: BasePart?, middle: BasePart?, lower: BasePart?, crank: BasePart?, bobberAnchor: Attachment?,
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

	local reduced = false
	local transient = Instance.new("Folder")
	transient.Name, transient.Parent = "TransientWaterEffects", folder
	local function ripple(position: Vector3)
		if reduced then return end
		local ring = Instance.new("Model")
		ring.Name, ring.Parent = "WaterRing", transient
		-- Thin fitted tangents form an open ring, rather than a bright solid disc.
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			local center = position - Vector3.yAxis * .17
			local start = center + radial * .5
			local segment = visualPart(ring, "WaterArc", Vector3.new(.055, .025, .28), CFrame.lookAt(start, start + tangent), Color3.fromRGB(208, 233, 230))
			segment.Transparency = .48
			local finish = center + radial * 2.4
			TweenService:Create(segment, TweenInfo.new(.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(finish, finish + tangent), Size = Vector3.new(.025, .02, 1.28), Transparency = 1,
			}):Play()
		end
		Debris:AddItem(ring, .7)
	end

	local function burst(position: Vector3, golden: boolean, rarity: string?)
		if reduced then return end
		local tier = Rarity.get(rarity or "Common")
		local color = if golden then Color3.fromRGB(227, 194, 112) else Color3.fromRGB(163, 212, 218)
		local crown = Instance.new("Model")
		crown.Name, crown.Parent = "WaterCrown", transient
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
		actor.shaft, actor.middle, actor.lower, actor.crank, actor.bobberAnchor = nil, nil, nil, nil, nil
		actor.shoulderPose, actor.leftPose, actor.shoulderBase, actor.leftBase = nil, nil, nil, nil
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
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			clearRig(actor)
			actor.state = { phase = "Idle", catches = actor.lastCatches }
			return nil
		end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if not hand or not hand:IsA("BasePart") then return nil end
		if not actor.rig and actor.state.phase ~= "Waiting" and actor.state.phase ~= "Reeling" and not actor.caughtFish then return hand end
		if not actor.rig then
			local rig = Instance.new("Model")
			rig.Name = "FishingRod_" .. actor.player.UserId
			local origin = visualPart(rig, "Grip", Vector3.new(0.28, 0.8, 0.28), CFrame.identity, Color3.fromRGB(101, 76, 66))
			rig.PrimaryPart = origin
			local lower = visualPart(rig, "Rod", Vector3.new(0.13, 1.55, 0.13), CFrame.new(0, 1.15, 0), Color3.fromRGB(78, 174, 188))
			local middle = visualPart(rig, "RodMiddle", Vector3.new(0.105, 1.2, 0.105), CFrame.new(0, 2.525, 0), Color3.fromRGB(78, 174, 188))
			local shaft = visualPart(rig, "RodTip", Vector3.new(0.075, 0.55, 0.075), CFrame.new(0, 3.4, 0), Color3.fromRGB(78, 174, 188))
			local reel = visualPart(rig, "Reel", Vector3.new(.22, .47, .47), CFrame.new(0, .35, -.25) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(220, 183, 109))
			reel.Shape = Enum.PartType.Cylinder
			local crank = visualPart(rig, "ReelCrank", Vector3.new(.075, .30, .075), CFrame.new(.17, .35, -.40), Color3.fromRGB(85, 103, 103))
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(0, 0.275, 0)
			tip.Parent = shaft
			rig.Parent = folder
			actor.rig, actor.tip = rig, tip
			actor.shaft, actor.middle, actor.lower, actor.crank = shaft, middle, lower, crank
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
		if changed and incoming.phase == "Waiting" then
			actor.landed, actor.bite = false, false
			if actor.caughtFish then actor.caughtFish:Destroy(); actor.caughtFish = nil end
			actor.castFrom = if hand then hand.Position + Vector3.new(0, 2, 0) else incoming.castTarget
			if actor.bobber then actor.bobber:Destroy() end
			actor.bobber, actor.line, actor.bobberAnchor = nil, nil, nil
			createBobber(actor)
			if hand then audio.play("Cast", 0.94, hand, 0.26) end
		end
		if incoming.phase == "Idle" then
			local position = if actor.bobber then actor.bobber.Position else incoming.castTarget
			if freshCatch and position then
				if actor.caughtFish then actor.caughtFish:Destroy() end
				actor.caughtFish = Fish.create(folder, "CaughtFish", incoming.result.speciesId)
				Fish.applyAppearance(actor.caughtFish, incoming.result.variant, incoming.result.weightKg)
				actor.catchStyle = Catalog.get(incoming.result.speciesId).Shape
				actor.catchAt = workspace:GetServerTimeNow()
				actor.catchFrom = position
				burst(position, incoming.result.quality == "Brilliant" or incoming.result.variant == "Golden", incoming.result.rarity)
				ripple(position)
			elseif changed and previous.phase == "Reeling" and position then
				burst(position, false)
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
			local active = actor.state.phase == "Waiting" or actor.state.phase == "Reeling" or actor.caughtFish ~= nil
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
		local camera = workspace.CurrentCamera
		for _, actor in actors do
			local character = actor.player.Character
			local candidateRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if camera and candidateRoot and candidateRoot:IsA("BasePart") and (candidateRoot.Position - camera.CFrame.Position).Magnitude > 180 then
				if actor.rig then clearRig(actor) end
				continue
			end
			local active = actor.state.phase == "Waiting" or actor.state.phase == "Reeling"
			if not active and not actor.caughtFish and actor.poseWeight == 0 then
				if actor.rig then clearRig(actor) end
				continue
			end
			local hand = ensureRig(actor)
			local root = if actor.character then actor.character:FindFirstChild("HumanoidRootPart") else nil
			if not hand or not root or not root:IsA("BasePart") or not actor.rig then continue end
			local packet = actor.state
			local target = packet.castTarget or (root.Position + root.CFrame.LookVector * 14)
			local flat = (target - root.Position) * Vector3.new(1, 0, 1)
			local rootForward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local forward = if flat.Magnitude > .1 then flat.Unit elseif rootForward.Magnitude > .1 then rootForward.Unit else Vector3.new(0, 0, -1)
			local castAt = packet.castAt or ((packet.readyAt or time) - Config.PreparationTime)
			local castT = math.clamp((time - castAt) / (packet.castDuration or .65), 0, 1)
			local difficulty = packet.difficulty or 0
			local frequency = if packet.behavior == "Dart" then 14 elseif packet.behavior == "Surge" then 7 elseif packet.behavior == "Glide" then 4 else 9
			local pitch = 0.95
			if packet.phase == "Waiting" then
				pitch = if castT < .3 then .72 + math.sin(castT / .3 * math.pi * .5) * .84 else .52 + 1.04 * (1 - math.sin((castT - .3) / .7 * math.pi * .5))
			elseif packet.phase == "Reeling" then
				pitch = .67 + (if reduced then 0 else math.sin(time * frequency) * (.035 + difficulty * .07))
			end
			actor.pitch = pitch
			local direction = forward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
			actor.rig:PivotTo(CFrame.lookAt(hand.Position, hand.Position + direction) * CFrame.Angles(-math.pi / 2, 0, 0))
			local level = packet.rodLevel or 0
			local rodColor = if level >= 3 then Color3.fromRGB(222, 181, 87)
				elseif level >= 2 then Color3.fromRGB(166, 136, 211) else Color3.fromRGB(68, 154, 167)
			local tension = if packet.phase == "Reeling" then math.clamp((time - (packet.chargeAt or time)) / (packet.duration or 1), 0, 1) else 0
			local bend = if packet.phase == "Reeling" then 0.07 + tension * (.14 + difficulty * .15) + (if reduced then 0 else math.sin(time * frequency) * .018) else .015 + math.sin(castT * math.pi) * .04
			local rodPivot = actor.rig:GetPivot()
			local middleFrame = rodPivot * CFrame.new(0, 1.925, 0) * CFrame.Angles(-bend, 0, 0) * CFrame.new(0, 0.6, 0)
			if actor.lower then actor.lower.Color = rodColor end
			if actor.middle then actor.middle.Color, actor.middle.CFrame = rodColor, middleFrame end
			if actor.shaft then actor.shaft.Color, actor.shaft.CFrame = rodColor, middleFrame * CFrame.new(0, .6, 0) * CFrame.Angles(-bend * .5, 0, 0) * CFrame.new(0, .275, 0) end
			if actor.crank then actor.crank.CFrame = rodPivot * CFrame.new(.17, .35, -.40) * CFrame.Angles(0, 0, if packet.phase == "Reeling" and not reduced then time * 9 else 0) end
			if active then
				createBobber(actor)
				local bobber = actor.bobber
				if bobber then
					local from = actor.castFrom or hand.Position
					local arc = from:Lerp(target, castT) + Vector3.new(0, 4 * castT * (1 - castT) * 4.2, 0)
					if castT >= 1 then
						local bob = math.sin(time * (if packet.phase == "Reeling" and not reduced then frequency * 1.5 else 3)) * (if reduced then .06 else .09)
						local nibble = if not actor.bite and time > (packet.readyAt or math.huge) - 0.2 then math.sin(time * 30) * 0.11 else 0
						local tug = if packet.phase == "Reeling" then math.sin(time * (if reduced then 3 else frequency)) * (.10 + difficulty * .28) * (if reduced then .5 else 1) else 0
						arc = target + Vector3.new(forward.Z * tug, bob + nibble - (if actor.bite then 0.25 else 0), -forward.X * tug)
						if not actor.landed then
							actor.landed = true
							ripple(target)
							audio.play("Splash", 0.95, bobber, 0.32)
						end
					end
					bobber.Position = arc
					if not actor.bite and time >= packet.readyAt then biteCue(actor) end
					if actor.line and actor.tip and actor.shaft and actor.bobberAnchor then
						local tipPosition = (actor.shaft.CFrame * CFrame.new(0, .275, 0)).Position
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
