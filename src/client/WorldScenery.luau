--!strict
-- Small, streamed scenery actors are independent of fishing and never own gameplay state.
-- Track arrivals once; the animation pass only visits the currently streamed actors.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fish = require(ReplicatedStorage:WaitForChild("FishingShared"):WaitForChild("FishModel"))

local ResidentPresentation = require(script.Parent:WaitForChild("ResidentPresentation"))

local Scenery = {}
local started = false
local WORLD_NAME = "MolnfiskarnaPrototype"
local STEP = 1 / 20

type Flow = { part: BasePart, origin: CFrame, phase: number, distance: number, speed: number }
type Motion = { model: Model, origin: CFrame, speed: number }
type Glint = { part: BasePart, phase: number, original: number, last: number }

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function Scenery.start()
	if started then return end
	started = true
	ResidentPresentation.start()
	local world: Instance? = nil
	local flows: { [Instance]: Flow } = {}
	local drifters: { [Instance]: Motion } = {}
	local previews: { [Instance]: Motion } = {}
	local boats: { [Instance]: Motion } = {}
	local swaying: { [Instance]: Motion } = {}
	local spinners: { [Instance]: Motion } = {}
	local glints: { [Instance]: Glint } = {}
	local surrenderedGlints: { [Instance]: boolean } = {}
	local listeners: { [Instance]: { RBXScriptConnection } } = {}
	local worldConnections: { RBXScriptConnection } = {}

	local function forget(instance: Instance)
		flows[instance], drifters[instance], previews[instance], spinners[instance] = nil, nil, nil, nil
		boats[instance],swaying[instance]=nil,nil
		local glint = glints[instance]
		if glint and glint.part.Parent and math.abs(glint.part.Transparency - glint.last) < 0.0001 then
			glint.part.Transparency = glint.original
		end
		glints[instance] = nil
		surrenderedGlints[instance] = nil
		local connections = listeners[instance]
		if connections then
			for _, connection in connections do connection:Disconnect() end
			listeners[instance] = nil
		end
	end

	local function refresh(instance: Instance)
		if not world or not instance:IsDescendantOf(world) then return end
		if instance:IsA("BasePart") then
			local origin, phase = instance:GetAttribute("FlowStart"), instance:GetAttribute("FlowPhase")
			if typeof(origin) == "CFrame" and finite(phase) then
				local distance, speed = instance:GetAttribute("FlowDistance"), instance:GetAttribute("FlowSpeed")
				flows[instance] = {
					part = instance, origin = origin, phase = phase,
					distance = if finite(distance) then math.clamp(distance, 1, 256) else 28,
					speed = if finite(speed) then math.clamp(speed, 0, 60) else 7,
				}
			else
				flows[instance] = nil
			end
			local glintPhase = instance:GetAttribute("GlintPhase")
			if finite(glintPhase) and not glints[instance] and not surrenderedGlints[instance] then
				glints[instance] = { part = instance, phase = glintPhase, original = instance.Transparency, last = instance.Transparency }
			elseif finite(glintPhase) and glints[instance] then
				glints[instance].phase = glintPhase
			elseif not finite(glintPhase) then
				local old = glints[instance]
				if old and math.abs(instance.Transparency - old.last) < 0.0001 then instance.Transparency = old.original end
				glints[instance] = nil
			end
		elseif instance:IsA("Model") then
			-- Models can replicate before their attributes and body parts. Keep their listeners
			-- until removal so either arrival order can make the actor ready.
			if not instance:FindFirstChildWhichIsA("BasePart", true) then return end
			if instance.Name == "SkySail" then
				local origin = instance:GetAttribute("DriftOrigin")
				local previous = drifters[instance]
				drifters[instance] = {
					model = instance,
					origin = if typeof(origin) == "CFrame" then origin elseif previous then previous.origin else instance:GetPivot(),
					speed = 0,
				}
			end
			if instance.Name == "PuffletPreview" then
				local origin = instance:GetAttribute("DisplayOrigin")
				if typeof(origin) == "CFrame" then previews[instance] = { model = instance, origin = origin, speed = 0 } end
			end
			local boatOrigin=instance:GetAttribute("DriftOrigin")
			if instance:GetAttribute("SceneryMotion")=="Boat" and typeof(boatOrigin)=="CFrame" then
				local previous=boats[instance]
				if not instance.PrimaryPart and (not previous or previous.origin~=boatOrigin) then instance.WorldPivot=boatOrigin end
				boats[instance]={model=instance,origin=boatOrigin,speed=0}
			else boats[instance]=nil end
			local swayOrigin=instance:GetAttribute("SwayOrigin")
			if typeof(swayOrigin)=="CFrame" then
				local amplitude=instance:GetAttribute("SwayAmplitude")
				local previous=swaying[instance]
				-- WorldPivot is NotReplicated. Establish the author-defined local pivot
				-- before the first sway; a pine canopy's bounds center is far above its base.
				if not instance.PrimaryPart and (not previous or previous.origin~=swayOrigin) then instance.WorldPivot=swayOrigin end
				swaying[instance]={model=instance,origin=swayOrigin,speed=if finite(amplitude) then math.clamp(amplitude,0,.08) else .025}
			else swaying[instance]=nil end
			local rate, origin = instance:GetAttribute("SpinRate"), instance:GetAttribute("SpinOrigin")
			if finite(rate) and typeof(origin) == "CFrame" then
				local previous=spinners[instance]
				if not instance.PrimaryPart and (not previous or previous.origin~=origin) then instance.WorldPivot=origin end
				spinners[instance] = { model = instance, origin = origin, speed = math.clamp(rate, -3, 3) }
			else
				spinners[instance] = nil
			end
		end
	end

	local function discover(instance: Instance)
		if listeners[instance] then refresh(instance); return end
		local candidate = instance:IsA("Model")
		if instance:IsA("BasePart") then
			-- Restrict readiness listeners to named effect parts, rather than every stone,
			-- plank and leaf in a large map. Attributes already present are also accepted.
			candidate = string.find(instance.Name, "FlowStreak", 1, true) ~= nil
				or string.find(instance.Name, "WaterfallStreak", 1, true) ~= nil
				or instance.Name == "PondWaterfallFoam"
				or string.find(instance.Name, "WaterGlint", 1, true) ~= nil
				or instance:GetAttribute("FlowStart") ~= nil or instance:GetAttribute("GlintPhase") ~= nil
		end
		if candidate then
			listeners[instance] = { instance.AttributeChanged:Connect(function() refresh(instance) end) }
			refresh(instance)
		end
		-- The part may have arrived after the model itself. Refresh animated ancestors,
		-- including a rotor nested inside a larger streamed neighborhood model.
		if instance:IsA("BasePart") then
			local ancestor = instance.Parent
			while ancestor and ancestor ~= world do
				if ancestor:IsA("Model") then refresh(ancestor) end
				ancestor = ancestor.Parent
			end
		end
	end

	local function unbind()
		for _, connection in worldConnections do connection:Disconnect() end
		table.clear(worldConnections)
		local tracked = {}
		for instance in listeners do table.insert(tracked, instance) end
		for _, instance in tracked do forget(instance) end
		world = nil
	end

	local function bind(candidate: Instance)
		if candidate.Name ~= WORLD_NAME or candidate.Parent ~= workspace or candidate == world then return end
		unbind()
		world = candidate
		table.insert(worldConnections, candidate.DescendantAdded:Connect(discover))
		table.insert(worldConnections, candidate.DescendantRemoving:Connect(function(instance)
			forget(instance)
			-- A whole atomic model may leave in one streaming operation.
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
		local time = workspace:GetServerTimeNow()
		local camera=workspace.CurrentCamera
		local cameraPosition=if camera then camera.CFrame.Position else Vector3.zero
		local function near(origin: CFrame,radius: number): boolean
			local delta=origin.Position-cameraPosition
			return delta:Dot(delta)<radius*radius
		end
		for _, boat in boats do
			if near(boat.origin,200) then
				boat.model:PivotTo(boat.origin*CFrame.new(0,math.sin(time*1.4)*.12,0)*CFrame.Angles(math.sin(time*.9)*.01,0,math.sin(time*1.1)*.018))
			end
		end
		for _, canopy in swaying do
			if near(canopy.origin,110) then
				local phase=canopy.origin.Position.X*.13+canopy.origin.Position.Z*.07
				canopy.model:PivotTo(canopy.origin*CFrame.Angles(math.sin(time*.9+phase)*canopy.speed*.45,0,math.sin(time*1.2+phase)*canopy.speed))
			end
		end
		for _, flow in flows do
			flow.part.CFrame = flow.origin + Vector3.new(0, flow.distance / 2 - ((time * flow.speed + flow.phase * 13) % flow.distance), 0)
		end
		for _, drift in drifters do
			drift.model:PivotTo(drift.origin * CFrame.new(math.sin(time * 0.09) * 5, math.sin(time * 0.35) * 1.1, 0)
				* CFrame.Angles(0, 0, math.sin(time * 0.23) * 0.025))
		end
		for _, preview in previews do
			preview.model:PivotTo(preview.origin * CFrame.new(0, math.sin(time * 1.8) * 0.4, 0)
				* CFrame.Angles(0, math.sin(time) * 0.3, math.sin(time * 2) * 0.08))
			Fish.animate(preview.model, time)
		end
		for _, spin in spinners do
			spin.model:PivotTo(spin.origin * CFrame.Angles(0, 0, time * spin.speed))
		end
		for instance, glint in glints do
			-- Stop touching transparency if another client system takes ownership.
			if math.abs(glint.part.Transparency - glint.last) > 0.0001 then
				glints[instance] = nil
				surrenderedGlints[instance] = true
			else
				glint.last = math.clamp(glint.original + math.sin(time * 0.8 + glint.phase) * 0.045, 0, 1)
				glint.part.Transparency = glint.last
			end
		end
	end)
end

return Scenery
