--!strict
-- Small, streamed scenery actors are independent of fishing and never own gameplay state.
-- Track arrivals once; the animation pass only visits the currently streamed actors.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ResidentPresentation = require(script.Parent:WaitForChild("ResidentPresentation"))

local Scenery = {}
local started = false
local WORLD_NAME = "MolnfiskarnaPrototype"
local STEP = 1 / 20
local SURFACE_TAG = "AnglersSurfaceStyle"
local SURFACE_MATERIALS: {[string]: Enum.Material} = {
	AnglersWeatheredWood=Enum.Material.Wood, AnglersCanvas=Enum.Material.Fabric,
	AnglersRoofSlate=Enum.Material.Slate, AnglersPlaster=Enum.Material.Plaster,
	AnglersCutStone=Enum.Material.Limestone, AnglersFineSand=Enum.Material.Sand,
}

type Flow = {
	part: BasePart, origin: CFrame, phase: number, distance: number, speed: number,
	original: number, last: number, alphaOwned: boolean,
}
type Motion = { model: Model, part: BasePart, origin: CFrame, speed: number }
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
	local boats: { [Instance]: Motion } = {}
	local swaying: { [Instance]: Motion } = {}
	local spinners: { [Instance]: Motion } = {}
	local glints: { [Instance]: Glint } = {}
	local surrenderedGlints: { [Instance]: boolean } = {}
	local listeners: { [Instance]: { RBXScriptConnection } } = {}
	local motionRoots: { [Instance]: RBXScriptConnection } = {}
	local worldConnections: { RBXScriptConnection } = {}
	local surfaces: {[Instance]: {original: string, last: string}} = {}
	local surfaceWaiting: {[Instance]: {RBXScriptConnection}} = {}

	local function stopWaiting(instance: Instance)
		local connections=surfaceWaiting[instance]
		if connections then
			for _,connection in connections do connection:Disconnect() end
			surfaceWaiting[instance]=nil
		end
	end
	local function forgetSurface(instance: Instance)
		stopWaiting(instance)
		local owned=surfaces[instance]
		if owned and owned.original~=owned.last and instance:IsA("BasePart") and instance.Parent and instance.MaterialVariant==owned.last then
			instance.MaterialVariant=owned.original
		end
		surfaces[instance]=nil
	end
	local applySurface: (Instance) -> ()
	applySurface=function(instance: Instance)
		if not world or not instance:IsA("BasePart") or not instance:IsDescendantOf(world)
			or not instance:HasTag(SURFACE_TAG) then return end
		-- A SpecialMesh supplies its own surface, so native Part maps cannot wrap it.
		if instance:FindFirstChildWhichIsA("SpecialMesh") then forgetSurface(instance);return end
		local style=instance:GetAttribute(SURFACE_TAG)
		local material=if typeof(style)=="string" then SURFACE_MATERIALS[style] else nil
		if style~=nil and not material then stopWaiting(instance);return end
		if not material or instance.Material~=material then
			-- Only incomplete, explicitly tagged parts need readiness listeners.
			-- Finished planks and stones keep no per-part connections or polling.
			if not surfaceWaiting[instance] then
				surfaceWaiting[instance]={
					instance:GetAttributeChangedSignal(SURFACE_TAG):Connect(function() applySurface(instance) end),
					instance:GetPropertyChangedSignal("Material"):Connect(function() applySurface(instance) end),
				}
			end
			return
		end
		stopWaiting(instance)
		local current=instance.MaterialVariant
		local owned=surfaces[instance]
		if owned then
			if current~=owned.last then return end -- Another presentation system owns it now.
		elseif current~="" and current~=style then return end
		if not owned then surfaces[instance]={original=current,last=style}
		else owned.last=style end
		if current~=style then instance.MaterialVariant=style end
	end

	local function forget(instance: Instance)
		forgetSurface(instance)
		local rootConnection = motionRoots[instance]
		if rootConnection then rootConnection:Disconnect(); motionRoots[instance] = nil end
		local flow=flows[instance]
		if flow and flow.alphaOwned and flow.part.Parent and math.abs(flow.part.Transparency-flow.last)<.0001 then
			flow.part.Transparency=flow.original
		end
		flows[instance], drifters[instance], spinners[instance] = nil, nil, nil
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
		-- DescendantRemoving runs before the parent link changes. Only animated
		-- ancestors can own this root; avoid scanning every actor for every plank.
		if instance:IsA("BasePart") then
			local ancestor=instance.Parent
			while ancestor and ancestor~=world do
				for _,motions in {drifters,boats,swaying,spinners} do
					local motion=motions[ancestor]
					if motion and motion.part==instance then motions[ancestor]=nil end
				end
				ancestor=ancestor.Parent
			end
		end
	end

	local function refresh(instance: Instance)
		if not world or not instance:IsDescendantOf(world) then return end
		if instance:IsA("BasePart") then
			local origin, phase = instance:GetAttribute("FlowStart"), instance:GetAttribute("FlowPhase")
			if typeof(origin) == "CFrame" and finite(phase) then
				local distance, speed = instance:GetAttribute("FlowDistance"), instance:GetAttribute("FlowSpeed")
				local previous=flows[instance]
				flows[instance] = {
					part = instance, origin = origin, phase = phase,
					distance = if finite(distance) then math.clamp(distance, 1, 256) else 28,
					speed = if finite(speed) then math.clamp(speed, 0, 60) else 7,
					original=if previous then previous.original else instance.Transparency,
					last=if previous then previous.last else instance.Transparency,
					alphaOwned=if previous then previous.alphaOwned else true,
				}
			else
				local old=flows[instance]
				if old and old.alphaOwned and math.abs(instance.Transparency-old.last)<.0001 then instance.Transparency=old.original end
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
			local motionExpected = instance.Name == "SkySail" or instance:GetAttribute("SceneryMotion") == "Boat"
				or instance:GetAttribute("SwayOrigin") ~= nil or instance:GetAttribute("SpinOrigin") ~= nil
			if motionExpected and not motionRoots[instance] then
				-- PrimaryPart can arrive/change after children and attributes. Only
				-- authored moving models need this extra readiness connection.
				motionRoots[instance] = instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function() refresh(instance) end)
			elseif not motionExpected and motionRoots[instance] then
				motionRoots[instance]:Disconnect(); motionRoots[instance] = nil
			end
			-- Models can replicate before their attributes and body parts. Keep their listeners
			-- until removal so either arrival order can make the actor ready.
			local root=instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart",true)
			if not root or not root:IsA("BasePart") then
				drifters[instance],boats[instance],swaying[instance],spinners[instance]=nil,nil,nil,nil
				return
			end
			if instance.Name == "SkySail" then
				local origin = instance:GetAttribute("DriftOrigin")
				local previous = drifters[instance]
				if typeof(origin)=="CFrame" then
					if not instance.PrimaryPart and (not previous or previous.origin~=origin) then instance.WorldPivot=origin end
					drifters[instance]={model=instance,part=root,origin=origin,speed=0}
				else drifters[instance]=nil end
			end
			local boatOrigin=instance:GetAttribute("DriftOrigin")
			if instance:GetAttribute("SceneryMotion")=="Boat" and typeof(boatOrigin)=="CFrame" then
				local previous=boats[instance]
				if not instance.PrimaryPart and (not previous or previous.origin~=boatOrigin) then instance.WorldPivot=boatOrigin end
				boats[instance]={model=instance,part=root,origin=boatOrigin,speed=0}
			else boats[instance]=nil end
			local swayOrigin=instance:GetAttribute("SwayOrigin")
			if typeof(swayOrigin)=="CFrame" then
				local amplitude=instance:GetAttribute("SwayAmplitude")
				local previous=swaying[instance]
				-- WorldPivot is NotReplicated. Establish the author-defined local pivot
				-- before the first sway; a pine canopy's bounds center is far above its base.
				if not instance.PrimaryPart and (not previous or previous.origin~=swayOrigin) then instance.WorldPivot=swayOrigin end
				swaying[instance]={model=instance,part=root,origin=swayOrigin,speed=if finite(amplitude) then math.clamp(amplitude,0,.08) else .025}
			else swaying[instance]=nil end
			local rate, origin = instance:GetAttribute("SpinRate"), instance:GetAttribute("SpinOrigin")
			if finite(rate) and typeof(origin) == "CFrame" then
				local previous=spinners[instance]
				if not instance.PrimaryPart and (not previous or previous.origin~=origin) then instance.WorldPivot=origin end
				spinners[instance] = { model = instance, part=root, origin = origin, speed = math.clamp(rate, -3, 3) }
			else
				spinners[instance] = nil
			end
		end
	end

	local function discover(instance: Instance)
		applySurface(instance)
		if instance:IsA("SpecialMesh") and instance.Parent then applySurface(instance.Parent) end
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
		for instance in surfaces do table.insert(tracked,instance) end
		for instance in surfaceWaiting do table.insert(tracked,instance) end
		for instance in motionRoots do table.insert(tracked,instance) end
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

	CollectionService:GetInstanceAddedSignal(SURFACE_TAG):Connect(applySurface)
	CollectionService:GetInstanceRemovedSignal(SURFACE_TAG):Connect(forgetSurface)
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
		if not camera then return end
		local cameraPosition=camera.CFrame.Position
		local function near(origin: CFrame,radius: number): boolean
			local delta=origin.Position-cameraPosition
			return delta:Dot(delta)<radius*radius
		end
		local function ready(motion: Motion): boolean
			return motion.model.Parent~=nil and motion.part.Parent~=nil and motion.part:IsDescendantOf(motion.model)
		end
		for _, boat in boats do
			if ready(boat) and near(boat.origin,200) then
				boat.model:PivotTo(boat.origin*CFrame.new(0,math.sin(time*1.4)*.12,0)*CFrame.Angles(math.sin(time*.9)*.01,0,math.sin(time*1.1)*.018))
			end
		end
		for _, canopy in swaying do
			if ready(canopy) and near(canopy.origin,110) then
				local phase=canopy.origin.Position.X*.13+canopy.origin.Position.Z*.07
				canopy.model:PivotTo(canopy.origin*CFrame.Angles(math.sin(time*.9+phase)*canopy.speed*.45,0,math.sin(time*1.2+phase)*canopy.speed))
			end
		end
		for _, flow in flows do
			if flow.part.Parent and near(flow.origin,220) then
				local cycle=((time*flow.speed+flow.phase*13)%flow.distance)/flow.distance
				flow.part.CFrame=flow.origin+Vector3.new(0,flow.distance*(.5-cycle),0)
				-- Fade before the wrap rather than teleporting a bright stripe from
				-- the bottom to the top. FlowDistance is the authored CENTER span.
				if flow.alphaOwned and math.abs(flow.part.Transparency-flow.last)>.0001 then flow.alphaOwned=false end
				if flow.alphaOwned then
					local fade=if flow.speed>0 then math.clamp(math.min(cycle,1-cycle)/.09,0,1) else 1
					flow.last=1-(1-flow.original)*fade
					flow.part.Transparency=flow.last
				end
			end
		end
		for _, drift in drifters do
			if ready(drift) and near(drift.origin,750) then
				drift.model:PivotTo(drift.origin * CFrame.new(math.sin(time * 0.09) * 5, math.sin(time * 0.35) * 1.1, 0)
					* CFrame.Angles(0, 0, math.sin(time * 0.23) * 0.025))
			end
		end
		for _, spin in spinners do
			if ready(spin) and near(spin.origin,180) then
				-- Server time is a large Unix timestamp. Reduce it before handing an
				-- angle to CFrame, avoiding large-angle precision jitters.
				spin.model:PivotTo(spin.origin*CFrame.Angles(0,0,(time*spin.speed)%(math.pi*2)))
			end
		end
		for instance, glint in glints do
			-- Stop touching transparency if another client system takes ownership.
			if math.abs(glint.part.Transparency - glint.last) > 0.0001 then
				glints[instance] = nil
				surrenderedGlints[instance] = true
			elseif near(glint.part.CFrame,160) then
				glint.last = math.clamp(glint.original + math.sin(time * 0.8 + glint.phase) * 0.045, 0, 1)
				glint.part.Transparency = glint.last
			end
		end
	end)
end

return Scenery
