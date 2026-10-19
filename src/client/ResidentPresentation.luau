--!strict
-- Cosmetic, deterministic life for the streamed islands. Discovery happens on
-- arrival; animation never searches the world or simulates NPCs on the server.
local RunService = game:GetService("RunService")
local Presentation = {}
local started = false
local WORLD_NAME = "MolnfiskarnaPrototype"
local STEP, MAX_DISTANCE = 1 / 20, 180

type Joint = { model: Model, rest: CFrame }
type Actor = {
	model: Model, kind: string, style: string, origin: CFrame, phase: number,
	period: number, radius: Vector3, travel: Vector3?, width: number,
	joints: { [string]: Joint },
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
	if joint and joint.model.Parent and joint.model.PrimaryPart then
		joint.model:PivotTo(body * joint.rest * CFrame.Angles(pitch, yaw, roll))
	end
end

local function inhabitant(actor: Actor, time: number)
	local t = time + actor.phase
	local body = actor.origin
	local walking = actor.style == "Walk" and actor.travel and actor.travel.Magnitude > 0.1
	local breath = math.sin(t * 1.7) * 0.025
	local stride = math.sin(t * 3.8)
	if walking and actor.travel then
		-- A continuous oval in a clear patch of grass: no abrupt endpoint turns,
		-- navigation requests, replicated movement or collision with players.
		local angle = t * math.pi * 2 / actor.period
		local perpendicular = Vector3.new(actor.travel.Z, 0, -actor.travel.X).Unit
		local position = actor.origin.Position + actor.travel * ((1 - math.cos(angle)) * 0.5)
			+ perpendicular * math.sin(angle) * actor.width
		local tangent = actor.travel * (math.sin(angle) * 0.5) + perpendicular * math.cos(angle) * actor.width
		body = CFrame.lookAt(position + Vector3.yAxis * (math.abs(stride) * 0.065), position + tangent + Vector3.yAxis * (math.abs(stride) * 0.065))
	else
		body *= CFrame.new(0, breath, 0) * CFrame.Angles(0, math.sin(t * 0.37) * 0.035, math.sin(t * 0.7) * 0.012)
	end
	actor.model:PivotTo(body)
	local leftPitch, rightPitch, leftRoll, rightRoll = 0.04, -0.04, -0.08, 0.08
	local headPitch, headYaw = math.sin(t * 0.8) * 0.025, math.sin(t * 0.45) * 0.15
	if walking then
		leftPitch, rightPitch = stride * 0.42, -stride * 0.42
		pose(actor, body, "LegLeft", -stride * 0.31, 0, 0)
		pose(actor, body, "LegRight", stride * 0.31, 0, 0)
	else
		pose(actor, body, "LegLeft", 0, 0, -0.018)
		pose(actor, body, "LegRight", 0, 0, 0.018)
		if actor.style == "Repair" then
			rightPitch = 0.55 + math.sin(t * 2.7) * 0.16
			leftPitch, headPitch, headYaw = 0.45, 0.10, -0.15
		elseif actor.style == "Fish" then
			-- Keep the line at the surface while the free hand tends the reel.
			rightPitch, leftPitch = math.sin(t * 1.1) * 0.012, 0.66 + math.sin(t * 1.7) * 0.09
			leftRoll, headPitch = -0.27, math.sin(t * 0.7) * 0.07
		elseif actor.style == "Garden" then
			rightPitch, rightRoll = 0.24 + math.sin(t * 0.9) * 0.11, 0.23
			leftPitch, headPitch = 0.30, 0.10
		elseif actor.style == "Lookout" then
			local glance = math.max(0, math.sin(t * 0.27))
			rightPitch, headYaw = glance * 2.65, math.sin(t * 0.32) * 0.28
		else
			local lift = math.clamp(math.sin(t * 0.43) * 2.2, 0, 1)
			lift = lift * lift * (3 - 2 * lift)
			if actor.style == "Serve" then
				leftRoll, leftPitch, rightPitch = -lift * (2.25 + math.sin(t * 4.8) * 0.12), 0.10, 0.04
			else
				rightRoll, rightPitch = lift * (2.25 + math.sin(t * 4.8) * 0.12), 0.10
			end
		end
	end
	pose(actor, body, "ArmLeft", leftPitch, 0, leftRoll)
	pose(actor, body, "ArmRight", rightPitch, 0, rightRoll)
	pose(actor, body, "HeadPose", headPitch, headYaw, math.sin(t * 0.7) * 0.025)
end

local function wildlife(actor: Actor, time: number)
	local angle = time * math.pi * 2 / actor.period + actor.phase
	local radius = actor.radius
	local offset = Vector3.new(math.cos(angle) * radius.X, math.sin(angle * 2) * radius.Y, math.sin(angle) * radius.Z)
	local tangent = Vector3.new(-math.sin(angle) * radius.X, math.cos(angle * 2) * radius.Y * 2, math.cos(angle) * radius.Z)
	local position = actor.origin.Position + offset
	local body = CFrame.lookAt(position, position + tangent)
	if actor.kind == "Butterfly" then
		body *= CFrame.Angles(0, 0, math.sin(time * 2 + actor.phase) * 0.16)
	end
	actor.model:PivotTo(body)
	if actor.kind == "Gull" then
		-- Occasional still-wing glides punctuate the flap cycle.
		local flap = math.sin(time * 8.0 + actor.phase) * 0.35
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
		if typeof(kind) ~= "string" or not ALLOWED_KINDS[kind] or typeof(origin) ~= "CFrame" or not instance.PrimaryPart then
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
		actors[instance] = {
			model = instance, kind = kind, origin = origin, joints = joints,
			style = if typeof(style) == "string" then style else "Wave",
			phase = bounded(instance:GetAttribute("AmbientPhase"), -100, 100, 0),
			period = bounded(instance:GetAttribute("AmbientPeriod"), 5, 240, 24),
			radius = validRadius,
			travel = validTravel,
			width = bounded(instance:GetAttribute("AmbientRouteWidth"), 1, 8, 3.8),
		}
	end

	local function refreshAncestor(instance: Instance)
		local ancestor: Instance? = instance
		while ancestor and ancestor ~= world do
			if namedActor(ancestor) then refresh(ancestor); return end
			ancestor = ancestor.Parent
		end
	end

	local function discover(instance: Instance)
		if instance:IsA("Model") and (namedActor(instance) or namedJoint(instance)) and not listeners[instance] then
			listeners[instance] = {
				instance.AttributeChanged:Connect(function() refreshAncestor(instance) end),
				instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function() refreshAncestor(instance) end),
			}
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
		-- A missing animated joint cannot be reused after an individual part unload.
		for _, actor in actors do
			for name, joint in actor.joints do
				if joint.model == instance or joint.model.PrimaryPart == instance then actor.joints[name] = nil end
			end
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
		table.insert(worldConnections, candidate.DescendantRemoving:Connect(forget))
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
		for _, actor in actors do
			local distance = actor.origin.Position - position
			if actor.model.Parent and actor.model.PrimaryPart and distance:Dot(distance) <= MAX_DISTANCE * MAX_DISTANCE then
				if actor.kind == "Resident" then inhabitant(actor, time) else wildlife(actor, time) end
			end
		end
	end)
end

return Presentation
