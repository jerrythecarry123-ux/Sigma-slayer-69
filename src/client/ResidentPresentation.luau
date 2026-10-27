--!strict
-- Cosmetic, deterministic life for the streamed islands. Discovery happens on
-- arrival; animation never searches the world or simulates NPCs on the server.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Presentation = {}
local started = false
local WORLD_NAME = "MolnfiskarnaPrototype"
local STEP, MAX_DISTANCE = 1 / 20, 180

type Joint = { model: Model, rest: CFrame }
type Eye = { part: BasePart, size: Vector3, glint: boolean }
type Actor = {
	model: Model, kind: string, style: string, origin: CFrame, phase: number,
	period: number, radius: Vector3, travel: Vector3?, width: number,
	joints: { [string]: Joint }, eyes: {Eye},
	line: BasePart?, rod: BasePart?, bobber: BasePart?, lineEnd: Vector3?,
	spout: BasePart?, drops: {BasePart}, waterTarget: Vector3?,
	near: boolean, greetingAt: number?, nextGreeting: number,
	gazeYaw: number, gazePitch: number, attention: number,
	stridePhase: number, lastTime: number?,
}

local JOINTS = { "ArmLeft", "ArmRight", "LegLeft", "LegRight", "HeadPose", "WingLeft", "WingRight" }
local ALLOWED_KINDS = { Resident = true, Gull = true, Butterfly = true, FishSchool = true }

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function finiteVector(value: any): boolean
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function bounded(value: any, low: number, high: number, fallback: number): number
	return if finite(value) then math.clamp(value, low, high) else fallback
end

local function namedActor(instance: Instance): boolean
	return instance:IsA("Model") and (string.sub(instance.Name, 1, 9) == "Resident_"
		or string.sub(instance.Name, 1, 11) == "IslandGull_"
		or string.sub(instance.Name, 1, 16) == "GardenButterfly_"
		or string.sub(instance.Name, 1, 17) == "LagoonFishSchool_"
		or instance:GetAttribute("AmbientKind") ~= nil)
end

local function namedJoint(instance: Instance): boolean
	if not instance:IsA("Model") then return false end
	for _, name in JOINTS do if instance.Name == name then return true end end
	return false
end

local function pose(actor: Actor, body: CFrame, name: string, pitch: number, yaw: number, roll: number)
	local joint = actor.joints[name]
	local root = if joint then joint.model.PrimaryPart else nil
	if joint and joint.model.Parent and joint.model:IsDescendantOf(actor.model)
		and root and root:IsDescendantOf(joint.model) then
		joint.model:PivotTo(body * joint.rest * CFrame.Angles(pitch, yaw, roll))
	end
end

local function inhabitant(actor: Actor, time: number, viewer: Vector3?)
	local t = time + actor.phase
	local dt = if actor.lastTime then math.clamp(time - actor.lastTime, 0, .1) else STEP
	actor.lastTime = time
	local body = actor.origin
	local walking = actor.style == "Walk" and actor.travel and actor.travel.Magnitude > .1
	local stride = 0
	if walking and actor.travel then
		-- The feet follow distance travelled around the oval, so the slower end
		-- turns no longer use the same fast walk cycle as its long straight sides.
		local angle = t * math.pi * 2 / actor.period
		local perpendicular = Vector3.new(actor.travel.Z, 0, -actor.travel.X).Unit
		local position = actor.origin.Position + actor.travel * ((1 - math.cos(angle)) * .5)
			+ perpendicular * math.sin(angle) * actor.width
		local tangent = actor.travel * (math.sin(angle) * .5) + perpendicular * math.cos(angle) * actor.width
		local speed = tangent.Magnitude * math.pi * 2 / actor.period
		actor.stridePhase += speed * dt * 3.35
		stride = math.sin(actor.stridePhase)
		local lift = Vector3.yAxis * math.abs(stride) * .045
		body = CFrame.lookAt(position + lift, position + tangent + lift)
	else
		body *= CFrame.new(0, math.sin(t * 1.4) * .018, 0)
			* CFrame.Angles(0, math.sin(t * .29) * .018, math.sin(t * .6) * .006)
	end
	actor.model:PivotTo(body)

	local targetYaw, targetPitch, interest = 0, 0, 0
	if viewer then
		local relative = body:PointToObjectSpace(viewer)
		local distance = Vector3.new(relative.X, 0, relative.Z).Magnitude
		local inFront = relative.Z < 1
		if distance > 17 or relative.Z > 6 then actor.near = false end
		if distance < 13 and inFront then
			interest = 1
			targetYaw = math.clamp(math.atan2(-relative.X, -relative.Z), -.5, .5)
			targetPitch = math.clamp(math.atan2(relative.Y + 1.3 - 4.16, math.max(1, distance)), -.14, .14)
			if not actor.near and time >= actor.nextGreeting then
				actor.greetingAt, actor.nextGreeting = time, time + 16 + actor.phase
			end
			actor.near = true
		end
	else actor.near = false end
	local blend = 1 - math.exp(-dt * 6)
	actor.gazeYaw += (targetYaw - actor.gazeYaw) * blend
	actor.gazePitch += (targetPitch - actor.gazePitch) * blend
	actor.attention += (interest - actor.attention) * blend
	local greeting = if actor.greetingAt then math.clamp((time - actor.greetingAt) / 1.7, 0, 1) else 1
	local wave = if greeting > 0 and greeting < 1 then math.sin(greeting * math.pi) ^ 2 else 0

	local leftPitch, rightPitch, leftRoll, rightRoll = .04, -.04, -.08, .08
	local headPitch, headYaw = math.sin(t * .7) * .018, math.sin(t * .31) * .10
	local pouring = 0
	if walking then
		leftPitch, rightPitch = stride * .35, -stride * .35
		pose(actor, body, "LegLeft", -stride * .28, 0, 0)
		pose(actor, body, "LegRight", stride * .28, 0, 0)
	else
		pose(actor, body, "LegLeft", 0, 0, -.012)
		pose(actor, body, "LegRight", 0, 0, .012)
		if actor.style == "Repair" then
			local working = (t % 7) < 4.5
			rightPitch = .045 + (if working then math.sin(t * 3.1) * .025 else 0)
			leftPitch, headPitch, headYaw = .08, -.13, -.10
		elseif actor.style == "Fish" then
			rightPitch = math.sin(t * .8) * .012
			leftPitch, leftRoll = .45 + math.sin(t * 1.1) * .045, -.18
			headPitch = -.045
		elseif actor.style == "Garden" then
			local cycle = (t % 9) / 9
			if cycle > .18 and cycle < .67 then pouring = math.sin((cycle - .18) / .49 * math.pi) ^ 2 end
			pouring *= 1 - wave
			rightPitch, rightRoll = .04 + pouring * .18, .03 + pouring * .11
			leftPitch, headPitch = .10, -.13
		elseif actor.style == "Lookout" then
			local cycle = t % 15
			local glance = if cycle > 8 and cycle < 11 then math.sin((cycle - 8) / 3 * math.pi) ^ 2 else 0
			rightPitch, headYaw = glance * 2.45, math.sin(t * .22) * .22
		elseif actor.style == "Serve" then
			-- Keep the loaded tray level; the empty hand greets actual visitors.
			rightPitch, rightRoll = 0, 0
		end
	end
	if wave > .001 then
		if actor.style == "Wave" or actor.style == "Walk" then
			rightRoll, rightPitch = wave * (2.15 + math.sin(greeting * 17) * .10), .08
		else
			leftRoll, leftPitch = -wave * (2.15 + math.sin(greeting * 17) * .10), .08
		end
	end
	headPitch = headPitch * (1 - actor.attention) + actor.gazePitch
	headYaw = headYaw * (1 - actor.attention) + actor.gazeYaw
	pose(actor, body, "ArmLeft", leftPitch, 0, leftRoll)
	pose(actor, body, "ArmRight", rightPitch, 0, rightRoll)
	pose(actor, body, "HeadPose", headPitch, headYaw, math.sin(t * .65) * .015)

	-- Eye dimensions are authored once, so a streamed or repeatedly refreshed
	-- face can never adopt an already-squashed blink as its new resting shape.
	local cycle = t % (4.6 + math.abs(actor.phase) * .13)
	local blink = if cycle < .16 then math.sin(cycle / .16 * math.pi) ^ 2 else 0
	for _, eye in actor.eyes do
		if eye.part.Parent and eye.part:IsDescendantOf(actor.model) then
			eye.part.Size = Vector3.new(eye.size.X, eye.size.Y * (1 - blink * .92), eye.size.Z)
			if eye.glint then eye.part.Transparency = blink end
		end
	end
	if actor.line and actor.rod and actor.bobber and actor.lineEnd
		and actor.line:IsDescendantOf(actor.model) and actor.rod:IsDescendantOf(actor.model)
		and actor.bobber:IsDescendantOf(actor.model) then
		local rod, endpoint = actor.rod, actor.lineEnd + Vector3.yAxis * math.sin(t * 2.2) * .025
		local tip = rod.Position + rod.CFrame.RightVector * rod.Size.X * .5
		local length = (endpoint - tip).Magnitude
		if length > .001 then
			actor.line.Size = Vector3.new(length, .025, .025)
			actor.line.CFrame = CFrame.lookAt((tip + endpoint) / 2, endpoint) * CFrame.Angles(0, math.pi / 2, 0)
			actor.bobber.Position = endpoint
		end
	end
	if actor.spout and actor.spout:IsDescendantOf(actor.model) and actor.waterTarget then
		local spout = actor.spout
		local start = spout.Position + spout.CFrame.RightVector * spout.Size.X * .5
		for index, drop in actor.drops do
			if not drop:IsDescendantOf(actor.model) then continue end
			local progress = (time * 1.5 + index / 3) % 1
			drop.Position = start:Lerp(actor.waterTarget, progress) + Vector3.yAxis * math.sin(progress * math.pi) * .06
			drop.Transparency = if pouring > .3 and progress > .08 and progress < .92 then .35 else 1
		end
	end
end

local function wildlife(actor: Actor, time: number)
	local angle = time * math.pi * 2 / actor.period + actor.phase
	local radius = actor.radius
	local offset = Vector3.new(math.cos(angle) * radius.X, math.sin(angle * 2) * radius.Y, math.sin(angle) * radius.Z)
	local tangent = Vector3.new(-math.sin(angle) * radius.X, math.cos(angle * 2) * radius.Y * 2, math.cos(angle) * radius.Z)
	local position = actor.origin.Position + offset
	local body = CFrame.lookAt(position, position + tangent)
	if actor.kind == "Butterfly" then
		body *= CFrame.Angles(0, 0, math.sin(time * 2 + actor.phase) * .12)
	elseif actor.kind == "Gull" then
		-- A shallow bank follows the turn rather than leaving birds rigidly level.
		body *= CFrame.Angles(0, 0, -.11 + math.sin(angle) * .025)
	end
	actor.model:PivotTo(body)
	if actor.kind == "Gull" then
		-- Occasional still-wing glides punctuate the flap cycle.
		local flap = math.sin(time * 8.0 + actor.phase) * 0.55
		local glide = math.clamp(math.sin(time * 0.6 + actor.phase) * 2.0, 0, 1)
		local roll = 0.06 + flap * (1 - glide)
		pose(actor, body, "WingLeft", 0, 0, -roll)
		pose(actor, body, "WingRight", 0, 0, roll)
	elseif actor.kind == "Butterfly" then
		local fold = math.sin(time * 29 + actor.phase) * 0.95
		pose(actor, body, "WingLeft", 0, fold, 0)
		pose(actor, body, "WingRight", 0, -fold, 0)
	end
end

function Presentation.start()
	if started then return end
	started = true
	local world: Instance? = nil
	local actors: { [Instance]: Actor } = {}
	local listeners: { [Instance]: { RBXScriptConnection } } = {}
	local worldConnections: { RBXScriptConnection } = {}

	local function refresh(instance: Instance)
		if not world or not instance:IsA("Model") or not instance:IsDescendantOf(world) then return end
		local kind, origin = instance:GetAttribute("AmbientKind"), instance:GetAttribute("AmbientOrigin")
		local root = instance.PrimaryPart
		if typeof(kind) ~= "string" or not ALLOWED_KINDS[kind] or typeof(origin) ~= "CFrame"
			or not root or not root:IsDescendantOf(instance) then
			actors[instance] = nil
			return
		end
		local joints: { [string]: Joint } = {}
		for _, name in JOINTS do
			local joint = instance:FindFirstChild(name)
			if joint and joint:IsA("Model") and joint.PrimaryPart then
				local rest = joint:GetAttribute("AmbientRest")
				if typeof(rest) == "CFrame" then joints[name] = { model = joint, rest = rest } end
			end
		end
		local radius, travel = instance:GetAttribute("AmbientRadius"), instance:GetAttribute("AmbientTravel")
		local validRadius = if finiteVector(radius) then radius else Vector3.new(8, 1, 6)
		local validTravel: Vector3? = nil
		if finiteVector(travel) then
			local horizontal = Vector3.new(travel.X, 0, travel.Z)
			if horizontal.Magnitude > 0.1 and horizontal.Magnitude < 80 then validTravel = horizontal end
		end
		-- Keep the velocity nonzero so lookAt never receives identical points.
		validRadius = Vector3.new(math.clamp(math.abs(validRadius.X), 0.5, 40), math.clamp(math.abs(validRadius.Y), 0, 8), math.clamp(math.abs(validRadius.Z), 0.5, 40))
		local style = instance:GetAttribute("AmbientStyle")
		local previous = actors[instance]
		local function part(container: Instance, name: string): BasePart?
			local value=container:FindFirstChild(name)
			return if value and value:IsA("BasePart") then value else nil
		end
		local eyes: {Eye} = {}
		local head=instance:FindFirstChild("HeadPose")
		if head then
			for _,value in head:GetChildren() do
				local size=value:GetAttribute("AmbientEyeSize")
				if value:IsA("BasePart") and finiteVector(size) and size.X>0 and size.Y>0 and size.Z>0 then
					table.insert(eyes,{part=value,size=size,glint=value.Name=="EyeSpark"})
				end
			end
		end
		local right=instance:FindFirstChild("ArmRight")
		local drops: {BasePart}={}
		for index=1,3 do
			local drop=part(instance,"WateringDrop"..index)
			if drop then table.insert(drops,drop) end
		end
		local lineEnd,waterTarget=instance:GetAttribute("AmbientLineEnd"),instance:GetAttribute("AmbientWaterTarget")
		actors[instance] = {
			model = instance, kind = kind, origin = origin, joints = joints,
			style = if typeof(style) == "string" then style else "Wave",
			phase = bounded(instance:GetAttribute("AmbientPhase"), -100, 100, 0),
			period = bounded(instance:GetAttribute("AmbientPeriod"), 5, 240, 24),
			radius = validRadius,
			travel = validTravel,
			width = bounded(instance:GetAttribute("AmbientRouteWidth"), 1, 8, 3.8),
			eyes=eyes,line=part(instance,"FineFishingLine"),bobber=part(instance,"ResidentBobber"),
			rod=if right then part(right,"BambooFishingRod") else nil,
			spout=if right then part(right,"WateringSpout") else nil,drops=drops,
			lineEnd=if finiteVector(lineEnd) then lineEnd else nil,
			waterTarget=if finiteVector(waterTarget) then waterTarget else nil,
			near=if previous then previous.near else false,
			greetingAt=if previous then previous.greetingAt else nil,
			nextGreeting=if previous then previous.nextGreeting else 0,
			gazeYaw=if previous then previous.gazeYaw else 0,gazePitch=if previous then previous.gazePitch else 0,
			attention=if previous then previous.attention else 0,
			stridePhase=if previous then previous.stridePhase else 0,lastTime=if previous then previous.lastTime else nil,
		}
	end

	local function actorAncestor(instance: Instance): Instance?
		local ancestor: Instance? = instance
		while ancestor and ancestor ~= world do
			if namedActor(ancestor) then return ancestor end
			ancestor = ancestor.Parent
		end
		return nil
	end

	local function refreshAncestor(instance: Instance)
		local ancestor = actorAncestor(instance)
		if ancestor then refresh(ancestor) end
	end

	local function discover(instance: Instance)
		if instance:IsA("Model") and (namedActor(instance) or namedJoint(instance)) and not listeners[instance] then
			listeners[instance] = {
				instance.AttributeChanged:Connect(function() refreshAncestor(instance) end),
				instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function() refreshAncestor(instance) end),
			}
		elseif instance:IsA("BasePart") and (instance.Name == "Eye" or instance.Name == "EyeSpark")
			and actorAncestor(instance) and not listeners[instance] then
			-- Eye Parts can arrive before their authored rest-size attribute. Only
			-- the small named eye set needs this listener, not every scenery Part.
			listeners[instance] = { instance.AttributeChanged:Connect(function(name)
				if name == "AmbientEyeSize" then refreshAncestor(instance) end
			end) }
		end
		if instance:IsA("Model") or instance:IsA("BasePart") then refreshAncestor(instance) end
	end

	local function forget(instance: Instance)
		actors[instance] = nil
		local connections = listeners[instance]
		if connections then
			for _, connection in connections do connection:Disconnect() end
			listeners[instance] = nil
		end
		-- DescendantRemoving precedes reparenting. Follow the removed object's
		-- own actor ancestry; unrelated planks must not inspect every joint in
		-- the world. Cached individual props also stop writing after removal.
		local owner = actorAncestor(instance)
		local actor = if owner then actors[owner] else nil
		if actor then
			for name, joint in actor.joints do
				if joint.model == instance or (instance:IsA("BasePart") and joint.model.PrimaryPart == instance) then
					actor.joints[name] = nil
				end
			end
			for index = #actor.eyes, 1, -1 do if actor.eyes[index].part == instance then table.remove(actor.eyes, index) end end
			for index = #actor.drops, 1, -1 do if actor.drops[index] == instance then table.remove(actor.drops, index) end end
			if actor.line == instance then actor.line = nil end
			if actor.rod == instance then actor.rod = nil end
			if actor.bobber == instance then actor.bobber = nil end
			if actor.spout == instance then actor.spout = nil end
		end
	end

	local function unbind()
		for _, connection in worldConnections do connection:Disconnect() end
		table.clear(worldConnections)
		for _, connections in listeners do for _, connection in connections do connection:Disconnect() end end
		table.clear(listeners)
		table.clear(actors)
		world = nil
	end

	local function bind(candidate: Instance)
		if candidate.Name ~= WORLD_NAME or candidate.Parent ~= workspace or candidate == world then return end
		unbind()
		world = candidate
		table.insert(worldConnections, candidate.DescendantAdded:Connect(discover))
		table.insert(worldConnections, candidate.DescendantRemoving:Connect(function(instance)
			forget(instance)
			-- Handle a whole streamed group even when the caller only observes
			-- its root removal; repeated descendant notifications are harmless.
			if instance:IsA("Model") then
				for _, child in instance:GetDescendants() do forget(child) end
			end
		end))
		table.insert(worldConnections, candidate.AncestryChanged:Connect(function()
			if candidate.Parent ~= workspace and world == candidate then unbind() end
		end))
		for _, instance in candidate:GetDescendants() do discover(instance) end
	end

	workspace.ChildAdded:Connect(bind)
	local existing = workspace:FindFirstChild(WORLD_NAME)
	if existing then bind(existing) end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < STEP then return end
		accumulator %= STEP
		local camera = workspace.CurrentCamera
		if not camera then return end
		local position, time = camera.CFrame.Position, workspace:GetServerTimeNow()
		-- Interest follows the local character, never a detached/free camera.
		local player=Players.LocalPlayer
		local character=if player then player.Character else nil
		local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
		local viewer=if root and root:IsA("BasePart") and humanoid and humanoid.Health>0 and finiteVector(root.Position) then root.Position else nil
		for _, actor in actors do
			local distance = actor.origin.Position - position
			local actorRoot = actor.model.PrimaryPart
			if actor.model.Parent and actorRoot and actorRoot:IsDescendantOf(actor.model)
				and distance:Dot(distance) <= MAX_DISTANCE * MAX_DISTANCE then
				if actor.kind == "Resident" then inhabitant(actor, time, viewer) else wildlife(actor, time) end
			end
		end
	end)
end

return Presentation
