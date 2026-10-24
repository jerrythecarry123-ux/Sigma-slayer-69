--!strict
-- Public player-owned displays. Progression and saving remain in FishingService;
-- this adapter only builds the presentation of already validated selections.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("FishingShared")
local Catalog = require(Shared:WaitForChild("FishCatalog"))
local Fish = require(Shared:WaitForChild("FishModel"))
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Aquarium = {}
local C = Kit.palette
local COLUMNS, TILE_WIDTH, TILE_DEPTH = 3, 28, 24
local FIRST_X, FIRST_Z, GROUND = -92, 88, 12
local SURFACES = {
	DisplayPedestal=Enum.Material.Wood, PaintedTankBack=Enum.Material.Wood,
	AquariumSandBed=Enum.Material.Sand, OwnerPlaque=Enum.Material.Wood,
	GalleryNameboard=Enum.Material.Wood, AquariumEditor=Enum.Material.Wood,
	TinyGardenBridge=Enum.Material.Wood, GardenBridgeFoot=Enum.Material.Wood,
	SunkenObservatoryColumn=Enum.Material.Limestone, SunkenObservatoryLintel=Enum.Material.Limestone,
	StarChartTile=Enum.Material.Slate, LittleLagoonArch=Enum.Material.Slate,
	LittleLagoonArchTop=Enum.Material.Slate,
}

local function styleData(id: any): any
	for _, style in Catalog.AquariumStyles do if style.Id == id then return style end end
	return Catalog.AquariumStyles[1]
end

local function rgb(value: {number}): Color3
	return Color3.fromRGB(table.unpack(value))
end

local function variantFor(profile: any, id: string): string
	local variants = if profile.variants then profile.variants[id] else nil
	if variants and variants.Prismatic then return "Prismatic" end
	if variants and variants.Golden then return "Golden" end
	return "Normal"
end

function Aquarium.start(world: Instance, callbacks: any)
	assert(not world:FindFirstChild("AquariumGallery"), "Install one aquarium gallery only")
	local gallery = Instance.new("Folder")
	gallery.Name, gallery.Parent = "AquariumGallery", world
	-- Visible structural decks persist with their collision, so streamed decoration
	-- can never leave an invisible walkway over the harbor. Fish/cases remain Atomic.
	local floors = Instance.new("Model")
	floors.Name, floors.ModelStreamingMode, floors.Parent = "GallerySafetyFloors", Enum.ModelStreamingMode.Persistent, gallery
	local scenery = Instance.new("Folder")
	scenery.Name, scenery.Parent = "GalleryArchitecture", gallery
	local rowCount = 0
	local plots: {[number]: any} = {}
	local occupied: {[number]: number} = {}
	local function floor(name: string, size: Vector3, position: Vector3, tint: Color3?)
		-- Keep the bottom seated on its bearers while lifting the visible top
		-- clear of the meadow. Coplanar grass/deck faces shimmered at the entry.
		Kit.part(floors, name, size+Vector3.yAxis*.06, CFrame.new(position+Vector3.yAxis*.03), tint or C.Plank,
			{material=Enum.Material.WoodPlanks,collidable=true})
	end
	local timber = { material = Enum.Material.Wood }
	-- Broad level access from existing harbor ground; clear of the main fishing route.
	floor("GalleryAccessDeck",Vector3.new(30,.4,14),Vector3.new(-63,GROUND-.2,80))
	for _, side in {-1,1} do
		Kit.part(scenery,"AccessEdge",Vector3.new(36,.65,.35),CFrame.new(-66,GROUND-.3,80+side*6.8),C.Wood,timber)
		-- A support meets each fascia directly; no decorative brace hangs free.
		Kit.beam(scenery,"GalleryAccessPile",Vector3.new(-82,GROUND-5.4,80+side*6.8),
			Vector3.new(-82,GROUND-.4,80+side*6.8),.55,C.Wood,timber)
	end
	local sign = Kit.part(scenery,"GalleryWelcome",Vector3.new(15,3,.3),CFrame.new(-82,GROUND+5,71.5),C.Cream,timber)
	Kit.sign(sign,"THE AQUARIUM WALK","YOUR FISH. YOUR LITTLE WORLD.",C.Iron)
	for _, side in {-1,1} do
		Kit.beam(scenery,"GalleryWelcomePost",Vector3.new(-82+side*6.8,GROUND,71.7),
			Vector3.new(-82+side*6.8,GROUND+6.15,71.7),.3,C.Wood,timber)
	end
	gallery:SetAttribute("GalleryArrivalCFrame",CFrame.new(-82,GROUND+3.3,80)*CFrame.Angles(0,-math.pi/2,0))
	local function ensureRow(row: number)
		while rowCount <= row do
			local index = rowCount
			local centerZ = FIRST_Z + index*TILE_DEPTH
			local deck=Kit.model(scenery,"GalleryRow"..index)
			deck.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
			for column=0,COLUMNS-1 do
				local x=FIRST_X-column*TILE_WIDTH
				-- Broad native plank surfaces supply grain and seams without adding a
				-- separate Part for every board. The lighter half is the walking lane.
				floor("GalleryPromenadeDeck",Vector3.new(TILE_WIDTH,.4,TILE_DEPTH/2),
					Vector3.new(x,GROUND-.2,centerZ-TILE_DEPTH/4))
				floor("GalleryDisplayApron",Vector3.new(TILE_WIDTH,.4,TILE_DEPTH/2),
					Vector3.new(x,GROUND-.2,centerZ+TILE_DEPTH/4),C.Plank:Lerp(C.Wood,.23))
				Kit.beam(deck,"GalleryTimberPile",Vector3.new(x,GROUND-7.4,centerZ+6),
					Vector3.new(x,GROUND-.4,centerZ+6),.65,C.Wood,timber)
			end
			-- Low outer curbs mark the edge without a wall across the promenade.
			for _, x in {FIRST_X+TILE_WIDTH/2-.2,FIRST_X-(COLUMNS-.5)*TILE_WIDTH+.2} do
				Kit.part(deck,"GalleryOuterCurb",Vector3.new(.4,.3,TILE_DEPTH),CFrame.new(x,GROUND+.05,centerZ),C.Wood,timber)
			end
			for _, side in {-1,1} do
				Kit.part(deck,"GalleryRowFascia",Vector3.new(COLUMNS*TILE_WIDTH,.6,.35),
					CFrame.new(FIRST_X-TILE_WIDTH,GROUND-.28,centerZ+side*(TILE_DEPTH/2-.18)),C.Wood,timber)
			end
			Kit.part(deck,"GalleryUnderdeckBearer",Vector3.new(COLUMNS*TILE_WIDTH,.6,.7),
				CFrame.new(FIRST_X-TILE_WIDTH,GROUND-.7,centerZ+6),C.Wood,timber)
			rowCount+=1
		end
	end
	ensureRow(0)
	local function createPlot(player: Player): any
		local index=1
		while occupied[index] do index+=1 end
		occupied[index]=player.UserId
		local row=math.floor((index-1)/COLUMNS)
		local column=(index-1)%COLUMNS
		ensureRow(row)
		local origin=CFrame.new(FIRST_X-column*TILE_WIDTH,GROUND,FIRST_Z+row*TILE_DEPTH)
		local plot={index=index,origin=origin,model=nil,signature=""}
		plots[player.UserId]=plot
		return plot
	end
	local function update(player: Player, profile: any)
		if player.Parent~=Players or not profile then return end
		local plot=plots[player.UserId] or createPlot(player)
		local style=styleData(profile.equippedStyle)
		local pieces={style.Id,player.DisplayName}
		for slot=1,3 do
			local id=profile.display and profile.display[slot] or ""
			table.insert(pieces,id..":"..variantFor(profile,id)..":"..tostring(profile.records and profile.records[id] or 0))
		end
		local signature=table.concat(pieces,"|")
		if signature==plot.signature then return end
		local old=plot.model
		local model=Instance.new("Model")
		model.Name="Aquarium_"..player.UserId
		model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
		model:SetAttribute("OwnerUserId",player.UserId)
		model:SetAttribute("AquariumPlot",true)
		local base,trim,accent=rgb(style.Colors.Base),rgb(style.Colors.Trim),rgb(style.Colors.Accent)
		local cf=plot.origin
		local function part(name: string,size: Vector3,x: number,y: number,z: number,color: Color3,options: any?): Part
			local finish=table.clone(options or {})
			if not finish.material then finish.material=SURFACES[name] end
			return Kit.part(model,name,size,cf*CFrame.new(x,y,z),color,finish)
		end
		-- An elliptical-ended plinth, round mullions and an open arched crown
		-- make a glass exhibit rather than a pile of solid rectangular blocks.
		part("DisplayPedestal",Vector3.new(16.4,1.4,9),0,.7,5,base)
		for _,x in {-8.2,8.2} do
			Kit.disk(model,"RoundedPedestalEnd",2.6,9,1.4,(cf*CFrame.new(x,.7,5)).Position,base,{material=Enum.Material.Wood})
		end
		part("TankSafetyCollider",Vector3.new(19,8.6,9),0,4.3,5,base,{collidable=true,transparency=1,shadow=false})
		part("AquariumSandBed",Vector3.new(17.5,.3,7.5),0,1.55,5,C.Sand)
		part("PaintedTankBack",Vector3.new(18,7.1,.22),0,5,8.9,base)
		part("TankWater",Vector3.new(17.7,6.5,7.6),0,4.8,5,accent,{transparency=.94,shadow=false})
		for _,x in {-9,9} do
			for _,z in {1.05,8.95} do
				Kit.beam(model,"RoundTankMullion",cf*Vector3.new(x,1.35,z),cf*Vector3.new(x,8.65,z),.25,trim,{material=Enum.Material.Metal})
			end
			part("TankSideGlass",Vector3.new(.12,6.8,7.7),x,4.9,5,accent,{material=Enum.Material.Glass,transparency=.87,shadow=false})
		end
		for _,y in {1.4,8.6} do
			for _,z in {1.05,8.95} do
				Kit.beam(model,"OpenTankFrame",cf*Vector3.new(-9,y,z),cf*Vector3.new(9,y,z),.24,trim,{material=Enum.Material.Metal})
			end
			for _,x in {-9,9} do
				Kit.beam(model,"OpenTankFrame",cf*Vector3.new(x,y,1.05),cf*Vector3.new(x,y,8.95),.24,trim,{material=Enum.Material.Metal})
			end
		end
		local arch={{-9,8.6},{-5,9.18},{0,9.45},{5,9.18},{9,8.6}}
		for _,z in {1.05,8.95} do
			for index=1,#arch-1 do
				local a,b=arch[index],arch[index+1]
				Kit.beam(model,"ArchedExhibitCrown",cf*Vector3.new(a[1],a[2],z),cf*Vector3.new(b[1],b[2],z),.17,trim,{material=Enum.Material.Metal})
			end
		end
		part("TankFrontGlass",Vector3.new(17.8,6.8,.1),0,4.9,1.06,accent,{material=Enum.Material.Glass,transparency=.91,shadow=false})
		for index=-1,1 do
			local x=index*5.8
			Kit.wedge(model,"AquariumRock",Vector3.new(1.4,.65,1.3),cf*CFrame.new(x,1.95,7.3)*CFrame.Angles(0,index*.6,0),C.Stone,{material=Enum.Material.Slate})
			for branch=0,2 do
				Kit.wedge(model,"AquariumSeagrass",Vector3.new(.08,1.1+branch*.25,.38),
					cf*CFrame.new(x+.4+branch*.28,2.2+branch*.125,7.2)*CFrame.Angles(0,branch*.7,(branch-1)*.18),accent,{shadow=false})
			end
		end
		-- Themes change the little habitat as well as its frame color. All pieces
		-- remain below the swimming lane, so decorations never hide a favorite fish.
		if style.Id=="blossom" then
			Kit.beam(model,"MiniatureBonsaiTrunk",cf*Vector3.new(-3.2,1.6,7),cf*Vector3.new(-3.05,2.85,7),.24,trim,{material=Enum.Material.Wood})
			for index=-1,1 do
				local crown=cf*CFrame.new(-3.2+index*.58,2.95-math.abs(index)*.2,7)*CFrame.Angles(0,index*.5,0)
				for _,side in {-1,1} do
					Kit.wedge(model,"MiniatureBlossomLeaf",Vector3.new(1.18,.4,.62),crown*CFrame.new(0,0,side*.25)*CFrame.Angles(0,if side==1 then math.pi else 0,0),accent)
				end
			end
			part("TinyGardenBridge",Vector3.new(2.5,.2,.8),3.1,2.4,7,trim)
			for _,x in {2.1,4.1} do part("GardenBridgeFoot",Vector3.new(.28,.65,.65),x,2.02,7,base) end
		elseif style.Id=="observatory" then
			for _,x in {-3.9,-2.5} do
				part("SunkenObservatoryColumn",Vector3.new(.36,1.15,.45),x,2.2,7,trim)
			end
			part("SunkenObservatoryLintel",Vector3.new(2.2,.35,.7),-3.2,2.95,7,trim)
			for index=-1,1 do
				part("StarChartTile",Vector3.new(.55,.12,.55),3.1+index*.65,1.85,6.8+math.abs(index)*.3,trim)
			end
		elseif style.Id=="coral" then
			for index=-1,1 do
				local x=index*3.2
				Kit.beam(model,"CoralStem",cf*Vector3.new(x,1.65,6.9),cf*Vector3.new(x,2.75,6.9),.2,accent)
				for side=-1,1,2 do
					Kit.beam(model,"CoralBranch",cf*Vector3.new(x,2.1,6.9),cf*Vector3.new(x+side*.5,2.85,6.9),.15,trim)
				end
			end
		else
			for _,x in {-3.9,-2.5} do part("LittleLagoonArch",Vector3.new(.45,.85,.7),x,2,7,C.Stone) end
			part("LittleLagoonArchTop",Vector3.new(2,.35,.8),-3.2,2.65,7,C.Stone)
		end
		local plaque=part("OwnerPlaque",Vector3.new(18,1.25,.2),0,.75,.37,C.Cream)
		Kit.sign(plaque,player.DisplayName.."'s Aquarium",style.Name.."  /  COLLECTED WITH CARE",C.Iron)
		local top=part("GalleryNameboard",Vector3.new(17,1.5,.2),0,10,6.5,base)
		Kit.sign(top,player.DisplayName.."'s collection","THREE FAVORITES FROM FIVE ISLANDS",C.Cream)
		local fishCount=0
		for slot=1,3 do
			local id=profile.display and profile.display[slot]
			if type(id)=="string" and profile.best and profile.best[id] then
				local species=Catalog.get(id)
				if species.Id==id then
					fishCount+=1
					local fish=Fish.create(model,"AquariumFish_"..slot,id)
					local variant=variantFor(profile,id)
					local weight=profile.records and profile.records[id]
					if Fish.applyAppearance then Fish.applyAppearance(fish,variant,weight,.82) end
					local swim=cf*CFrame.new((slot-2)*5.5,4.5+(slot%2)*.4,5)*CFrame.Angles(0,.65+(slot-2)*.15,0)
					fish:PivotTo(swim)
					fish:SetAttribute("AquariumSwimOrigin",swim)
					fish:SetAttribute("AquariumSwimPhase",slot*2.1+plot.index)
					local label=part("FishPlaque",Vector3.new(5.4,.8,.12),(slot-2)*5.8,1.8,.8,C.Cream)
					local description=(if variant~="Normal" then variant.."  /  " else "")..(if weight then string.format("BEST %.2f kg",weight) else species.Rarity)
					Kit.sign(label,species.Name,description,C.Iron)
				end
			end
		end
		if fishCount==0 then
			local welcome=part("EmptyTankWelcome",Vector3.new(12,2,.15),0,4.7,2.5,C.Cream)
			Kit.sign(welcome,"YOUR FIRST FISH BELONGS HERE","CAST A LINE. START A COLLECTION.",C.Teal)
		end
		local promptPart=part("AquariumEditor",Vector3.new(1.4,2.7,1.2),10.6,1.35,1,trim)
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name,prompt.ActionText,prompt.ObjectText="AquariumPrompt","Edit my display","Aquarium gallery"
		prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance,prompt.HoldDuration,prompt.RequiresLineOfSight=6,0,false
		prompt.Parent=promptPart
		model.Parent=gallery
		plot.signature,plot.model=signature,model
		if old then old:Destroy() end
	end
	local function remove(player: Player)
		local plot=plots[player.UserId]
		if not plot then return end
		if plot.model then plot.model:Destroy() end
		occupied[plot.index],plots[player.UserId]=nil,nil
	end
	local function arrival(player: Player): CFrame?
		local plot=plots[player.UserId]
		return if plot then plot.origin*CFrame.new(0,3.3,-4)*CFrame.Angles(0,math.pi,0) else nil
	end
	-- FishingService calls update after each authoritative profile mutation and remove
	-- on departure. No heartbeat, duplicated economy, networking or save loop lives here.
	for _,player in Players:GetPlayers() do
		local profile=callbacks.profile(player)
		if profile then update(player,profile) end
	end
	return {update=update,remove=remove,arrival=arrival,folder=gallery}
end

return Aquarium
