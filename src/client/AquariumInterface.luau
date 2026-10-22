--!strict
-- Three favorite catches become a real, shared-world aquarium. This interface
-- requests IDs only; the server validates ownership, slots and coin purchases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Aquarium = {}
local animationStarted = false

-- One small local loop handles streamed tanks independently of an open menu.
local function startWorldAnimation()
	if animationStarted then return end
	animationStarted=true
	local tracked: {[Model]: any}={}
	local watching: {[Model]: {RBXScriptConnection}}={}
	local function ready(model: Model)
		local origin,phase=model:GetAttribute("AquariumSwimOrigin"),model:GetAttribute("AquariumSwimPhase")
		local body=model.PrimaryPart
		if typeof(origin)=="CFrame" and type(phase)=="number" and phase==phase and math.abs(phase)<math.huge
			and body and body:IsDescendantOf(model) then
			tracked[model]={origin=origin,phase=phase}
		else tracked[model]=nil end
	end
	local function discover(node: Instance)
		if node:IsA("Model") and string.sub(node.Name,1,13)=="AquariumFish_" and not watching[node] then
			watching[node]={
				node.AttributeChanged:Connect(function() ready(node) end),
				node.ChildAdded:Connect(function() ready(node) end),
				node.ChildRemoved:Connect(function() ready(node) end),
				node:GetPropertyChangedSignal("PrimaryPart"):Connect(function() ready(node) end),
			}
			ready(node)
		elseif node:IsA("BasePart") then
			local parent=node.Parent
			if parent and parent:IsA("Model") and watching[parent] then ready(parent) end
		end
	end
	local function forget(node: Instance)
		if not node:IsA("Model") then return end
		tracked[node]=nil
		local listeners=watching[node]
		if listeners then for _,connection in listeners do connection:Disconnect() end; watching[node]=nil end
	end
	-- Listen once for gallery models; no per-frame Workspace descendants scan.
	workspace.DescendantAdded:Connect(discover)
	workspace.DescendantRemoving:Connect(forget)
	for _,node in workspace:GetDescendants() do discover(node) end
	local elapsed=0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed<.05 then return end
		elapsed%=.05
		local camera=workspace.CurrentCamera
		if not camera then return end
		local time=workspace:GetServerTimeNow()
		for model,data in tracked do
			if not model.Parent then forget(model); continue end
			local delta=data.origin.Position-camera.CFrame.Position
			if delta:Dot(delta)>120*120 then continue end
			local phase=data.phase
			model:PivotTo(data.origin*CFrame.new(math.sin(time*.65+phase)*.55,math.sin(time*1.1+phase)*.22,math.cos(time*.55+phase)*.3)
				*CFrame.Angles(0,math.sin(time*.55+phase)*.22,math.sin(time*.9+phase)*.025))
			Fish.animate(model,time)
		end
	end)
end

local function center(label: TextLabel): TextLabel
	label.TextXAlignment=Enum.TextXAlignment.Center
	return label
end

function Aquarium.new(playerGui: Instance, handlers: any)
	startWorldAnimation()
	local player=Players.LocalPlayer
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.Enabled="MyAquarium",false,50,false
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	local backdrop=Instance.new("TextButton")
	backdrop.Name,backdrop.Text,backdrop.Size="Backdrop","",UDim2.fromScale(1,1)
	backdrop.BackgroundColor3,backdrop.BackgroundTransparency,backdrop.BorderSizePixel=Theme.Ink,.2,0
	backdrop.Parent=gui
	local card=Theme.frame(gui,"AquariumStudio",UDim2.fromOffset(640,600),UDim2.fromScale(.5,.5))
	card.AnchorPoint,card.Active=Vector2.new(.5,.5),true
	Theme.stroke(card)
	local title=Theme.text(card,"Your little ocean",UDim2.new(1,-76,0,32),UDim2.fromOffset(20,14),25,Theme.Ink,true)
	local sub=Theme.text(card,"Choose three favorites. Friends can see them in the gallery.",UDim2.new(1,-40,0,34),UDim2.fromOffset(20,47),12,Theme.Muted)
	local closeButton=Theme.button(card,"×",UDim2.fromOffset(44,44),UDim2.new(1,-54,0,10),Theme.Soft)
	closeButton.TextColor3,closeButton.TextSize=Theme.Ink,25
	local profile: any=nil
	local selectedSlot=1
	local activeTab="Fish"
	local oldSelection: GuiObject?=nil
	local slots: {any}={}
	local refresh: ()->()
	for slot=1,3 do
		local button=Theme.button(card,"",UDim2.new(1/3,-18,0,110),UDim2.new((slot-1)/3,14,0,88),Theme.Soft)
		button.Name="DisplaySlot"..slot
		local stroke=Theme.stroke(button,Theme.Line,1)
		local view=Instance.new("ViewportFrame")
		view.Name,view.Size,view.BackgroundTransparency="FishPreview",UDim2.new(1,-8,1,-26),1
		view.Position,view.Ambient,view.LightColor=UDim2.fromOffset(4,0),Color3.fromRGB(170,191,190),Color3.fromRGB(232,225,201)
		view.LightDirection,view.Parent=Vector3.new(-1,-1,-2),button
		local camera=Instance.new("Camera")
		camera.CFrame,camera.FieldOfView,camera.Parent=CFrame.lookAt(Vector3.new(3,.8,-6.7),Vector3.zero),35,view
		view.CurrentCamera=camera
		local world=Instance.new("WorldModel")
		world.Parent=view
		local name=center(Theme.text(button,"SLOT "..slot,UDim2.new(1,-12,0,22),UDim2.new(0,6,1,-24),11,Theme.Muted,true))
		name.TextTruncate=Enum.TextTruncate.AtEnd
		slots[slot]={button=button,stroke=stroke,world=world,name=name,fish=nil,signature=""}
		button.Activated:Connect(function() selectedSlot=slot; refresh() end)
	end
	local fishTab=Theme.button(card,"Choose fish",UDim2.new(.5,-22,0,42),UDim2.fromOffset(14,210),Theme.Ink)
	local stylesTab=Theme.button(card,"Tank themes",UDim2.new(.5,-22,0,42),UDim2.new(.5,8,0,210),Theme.Soft)
	stylesTab.TextColor3=Theme.Ink
	local instruction=Theme.text(card,"Choose a fish for slot 1",UDim2.new(1,-32,0,24),UDim2.fromOffset(16,261),12,Theme.Teal,true)
	local function scroll(name: string): ScrollingFrame
		local value=Instance.new("ScrollingFrame")
		value.Name,value.Position,value.Size=name,UDim2.fromOffset(14,290),UDim2.new(1,-28,1,-364)
		value.BackgroundTransparency,value.BorderSizePixel,value.ScrollBarThickness=1,0,4
		value.ScrollBarImageColor3,value.CanvasSize,value.AutomaticCanvasSize=Theme.Teal,UDim2.fromOffset(0,0),Enum.AutomaticSize.Y
		value.Parent=card
		local stack=Instance.new("UIListLayout")
		stack.Padding,stack.SortOrder,stack.Parent=UDim.new(0,7),Enum.SortOrder.LayoutOrder,value
		return value
	end
	local fishList=scroll("OwnedFish")
	local styleList=scroll("TankThemes")
	styleList.Visible=false
	local rows: {[string]: any}={}
	for index,species in Catalog.Species do
		local button=Theme.button(fishList,"",UDim2.new(1,-8,0,58),UDim2.fromOffset(0,0),Theme.Soft)
		button.Name,button.LayoutOrder=species.Id,index
		local mark=Theme.frame(button,"SpeciesColor",UDim2.fromOffset(7,34),UDim2.fromOffset(10,12),Color3.fromRGB(table.unpack(species.Body)))
		Theme.round(mark,4)
		local name=Theme.text(button,species.Name,UDim2.new(1,-98,0,24),UDim2.fromOffset(28,6),15,Theme.Ink,true)
		name.TextTruncate=Enum.TextTruncate.AtEnd
		local detail=Theme.text(button,"Catch this fish to display it",UDim2.new(1,-98,0,19),UDim2.fromOffset(28,32),10,Theme.Muted)
		local badge=Theme.text(button,"LOCKED",UDim2.fromOffset(65,30),UDim2.new(1,-75,.5,-15),10,Theme.Muted,true)
		badge.TextXAlignment=Enum.TextXAlignment.Right
		rows[species.Id]={button=button,detail=detail,badge=badge,name=name,species=species}
		button.Activated:Connect(function()
			if profile and profile.best and profile.best[species.Id] then handlers.display(species.Id,selectedSlot) end
		end)
	end
	local styleRows: {[string]: any}={}
	for index,style in Catalog.AquariumStyles do
		local button=Theme.button(styleList,"",UDim2.new(1,-8,0,62),UDim2.fromOffset(0,0),Theme.Soft)
		button.Name,button.LayoutOrder=style.Id,index
		for swatch,color in {style.Colors.Base,style.Colors.Trim,style.Colors.Accent} do
			Theme.frame(button,"ThemeSwatch",UDim2.fromOffset(12,35),UDim2.fromOffset(10+(swatch-1)*9,17),Color3.fromRGB(table.unpack(color)))
		end
		local name=Theme.text(button,style.Name,UDim2.new(1,-148,0,25),UDim2.fromOffset(49,8),16,Theme.Ink,true)
		name.TextWrapped,name.TextTruncate=false,Enum.TextTruncate.AtEnd
		local descriptions={lagoon="A tiny sunken lagoon arch",blossom="Bonsai, blossoms and a little bridge",observatory="Sunken columns and star-chart tiles",coral="Branching coral for a warm reef"}
		local detail=Theme.text(button,descriptions[style.Id] or "Permanent cosmetic theme",UDim2.new(1,-148,0,19),UDim2.fromOffset(49,39),10,Theme.Muted)
		detail.TextWrapped,detail.TextTruncate=false,Enum.TextTruncate.AtEnd
		local badge=Theme.text(button,"",UDim2.fromOffset(94,42),UDim2.new(1,-104,.5,-21),12,Theme.Teal,true)
		badge.TextXAlignment=Enum.TextXAlignment.Right
		styleRows[style.Id]={button=button,name=name,detail=detail,badge=badge,style=style}
		button.Activated:Connect(function()
			if not profile then return end
			local owned=profile.styles and profile.styles[style.Id]
			if owned or profile.coins>=style.Cost then handlers.style(style.Id) end
		end)
	end
	local visit=Theme.button(card,"VISIT MY TANK",UDim2.new(1,-28,0,48),UDim2.new(0,14,1,-62),Theme.Teal)
	local function close()
		if not gui.Enabled then return end
		gui.Enabled=false
		player:SetAttribute("AquariumMenuOpen",false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject=if oldSelection and oldSelection.Parent then oldSelection else nil
		end
		if handlers.close then handlers.close() end
	end
	closeButton.Activated:Connect(close)
	backdrop.Activated:Connect(close)
	visit.Activated:Connect(function() if profile and handlers.visit then close(); handlers.visit() end end)
	local function setTab(tab: string)
		activeTab=tab
		fishList.Visible,styleList.Visible=tab=="Fish",tab=="Styles"
		fishTab.BackgroundColor3=if tab=="Fish" then Theme.Ink else Theme.Soft
		fishTab.TextColor3=if tab=="Fish" then Theme.Panel else Theme.Ink
		stylesTab.BackgroundColor3=if tab=="Styles" then Theme.Ink else Theme.Soft
		stylesTab.TextColor3=if tab=="Styles" then Theme.Panel else Theme.Ink
		refresh()
	end
	refresh=function()
		instruction.Text=if activeTab=="Fish" then "Choose a fish for slot "..selectedSlot else "Cosmetic themes · earned coins · no fishing advantage"
		for slot,data in slots do
			local accessible=not profile or not profile.display or slot<=math.min(3,#profile.display+1)
			data.button.Active,data.button.Selectable=accessible,accessible
			data.stroke.Color=if slot==selectedSlot then Theme.Teal else Theme.Line
			data.stroke.Thickness=if slot==selectedSlot then 2 else 1
			local id=profile and profile.display and profile.display[slot]
			local variants=profile and profile.variants and id and profile.variants[id]
			local variant=if variants and variants.Prismatic then "Prismatic" elseif variants and variants.Golden then "Golden" else "Normal"
			local signature=tostring(id)..variant..tostring(profile and profile.records and id and profile.records[id] or 0)
			if signature~=data.signature then
				if data.fish then data.fish:Destroy();data.fish=nil end
				if id and profile.best[id] then
					data.fish=Fish.create(data.world,nil,id)
					if Fish.applyAppearance then Fish.applyAppearance(data.fish,variant,profile.records and profile.records[id],.82) end
				end
				data.signature=signature
			end
			data.name.Text=if id then Catalog.get(id).Name else "SLOT "..slot
		end
		for id,row in rows do
			local unlocked=profile and profile.best and profile.best[id]
			local displayed=profile and profile.display and profile.display[selectedSlot]==id
			local otherSlot=profile and profile.display and table.find(profile.display,id)
			local canMove=not otherSlot or displayed or (profile and profile.display and profile.display[selectedSlot]~=nil)
			local variants=profile and profile.variants and profile.variants[id]
			local variant=if variants and variants.Prismatic then "Prismatic · " elseif variants and variants.Golden then "Golden · " else ""
			local record=profile and profile.records and profile.records[id]
			row.name.Text=if unlocked then row.species.Name else "Undiscovered"
			row.detail.Text=if unlocked then variant..(if record then string.format("Best %.2f kg",record) else row.species.Rarity) else row.species.Hint
			row.badge.Text=if displayed then "DISPLAYED" elseif otherSlot then "SLOT "..otherSlot elseif unlocked then "SELECT" else "LOCKED"
			row.button.BackgroundColor3=if displayed then Color3.fromRGB(209,231,217) else Theme.Soft
			row.button.Active,row.button.Selectable=unlocked~=nil and unlocked~=false and canMove,unlocked~=nil and unlocked~=false and canMove
		end
		for id,row in styleRows do
			local owned=profile and profile.styles and profile.styles[id]
			local equipped=profile and profile.equippedStyle==id
			local afford=profile and profile.coins>=row.style.Cost
			row.badge.Text=if equipped then "EQUIPPED" elseif owned then "EQUIP" else tostring(row.style.Cost).." coins"
			row.badge.TextColor3=if owned or afford then Theme.Teal else Theme.Muted
			row.button.Active,row.button.Selectable=not equipped and (owned or afford)==true,not equipped and (owned or afford)==true
			row.button.BackgroundColor3=if equipped then Color3.fromRGB(209,231,217) else Theme.Soft
		end
		visit.Text=if profile then "VISIT MY TANK" else "LOADING COLLECTION..."
	end
	fishTab.Activated:Connect(function() setTab("Fish") end)
	stylesTab.Activated:Connect(function() setTab("Styles") end)
	UserInputService.InputBegan:Connect(function(input,processed)
		if gui.Enabled and not processed and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close() end
	end)
	player.CharacterAdded:Connect(close)
	player:SetAttribute("AquariumMenuOpen",false)
	gui.Parent=playerGui
	local function animate(time: number,width: number,height: number)
		local canvas=gui.AbsoluteSize
		local w=if canvas.X>0 then canvas.X else width
		local h=if canvas.Y>0 then canvas.Y else height
		local compact=h<450
		card.Size=UDim2.fromOffset(math.min(640,math.max(280,w-24)),math.min(600,math.max(228,h-(if compact then 12 else 24))))
		title.Text,title.TextSize=if compact then "Aquarium" else "Your little ocean",if compact then 16 elseif w<420 then 20 else 25
		title.Size=UDim2.new(1,if compact then -210 else -76,0,32)
		sub.Visible=not compact
		local slotY=if compact then 56 else 88
		local slotHeight=if compact then 34 else 110
		for slot,data in slots do
			data.button.Position=UDim2.new((slot-1)/3,14,0,slotY)
			data.button.Size=UDim2.new(1/3,-18,0,slotHeight)
			data.button:FindFirstChild("FishPreview").Visible=not compact
			if gui.Enabled and data.fish then
				data.fish:PivotTo(CFrame.Angles(0,math.sin(time+slot)*.2,math.sin(time*1.3+slot)*.025))
				Fish.animate(data.fish,time)
			end
		end
		local tabsY=slotY+slotHeight+12
		fishTab.Position,stylesTab.Position=UDim2.fromOffset(14,tabsY),UDim2.new(.5,8,0,tabsY)
		fishTab.Size,stylesTab.Size=UDim2.new(.5,-22,0,if compact then 32 else 42),UDim2.new(.5,-22,0,if compact then 32 else 42)
		instruction.Visible=not compact
		instruction.Position=UDim2.fromOffset(16,tabsY+49)
		local contentY=tabsY+(if compact then 38 else 80)
		fishList.Position,styleList.Position=UDim2.fromOffset(14,contentY),UDim2.fromOffset(14,contentY)
		local bottom=if compact then 12 else 74
		fishList.Size,styleList.Size=UDim2.new(1,-28,1,-contentY-bottom),UDim2.new(1,-28,1,-contentY-bottom)
		visit.Position=if compact then UDim2.new(1,-170,0,14) else UDim2.new(0,14,1,-62)
		visit.Size=if compact then UDim2.fromOffset(106,36) else UDim2.new(1,-28,0,48)
		visit.TextSize=if compact then 10 else 14
		visit.Text=if profile then (if compact then "VISIT TANK" else "VISIT MY TANK") else "LOADING..."
	end
	refresh()
	return {
		open=function()
			if not gui.Enabled then oldSelection=GuiService.SelectedObject end
			gui.Enabled=true;player:SetAttribute("AquariumMenuOpen",true);refresh()
			if UserInputService.GamepadEnabled then GuiService.SelectedObject=slots[selectedSlot].button end
		end,
		close=close,isOpen=function() return gui.Enabled end,
		updateProfile=function(value: any) profile=value;refresh() end,
		animate=animate,
	}
end

return Aquarium
