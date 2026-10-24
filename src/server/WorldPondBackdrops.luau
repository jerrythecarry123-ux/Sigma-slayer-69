--!strict
-- Low, individual shorelines frame each existing pond. Visible rock owns collision;
-- there are no taller, invisible copies of the scenery to run into.
local Kit = require(script.Parent:WaitForChild("WorldPrimitives"))
local Layout = require(script.Parent:WaitForChild("WorldLayout"))
local Backdrops = {}
local C = Kit.palette
local WATER = Color3.fromRGB(56,153,181)
local FOAM = Color3.fromRGB(160,199,208)
local BASE = -5.4
local ROCK = {material=Enum.Material.Slate,collidable=true}

-- Low gaps preserve a view beyond the water. Different heights, widths and
-- setbacks give every island its own silhouette without extra land or props.
local SHORES: {[string]: any} = {
 harbor={x={-.86,-.56,-.26,.05,.36,.65,.90},h={15,23,19,11,17,26,14},
  w={.34,.37,.36,.33,.36,.34,.29},d={1,3,-1,1,0,3,-1},falls={2,6},warmth=.07},
 blossom={x={-.87,-.55,-.23,.12,.46,.78},h={14,22,16,11,24,17},
  w={.36,.37,.39,.39,.36,.35},d={0,2,0,3,-1,1},falls={2,5},warmth=.15},
 forest={x={-.88,-.57,-.24,.09,.43,.77},h={18,26,21,13,29,17},
  w={.35,.37,.39,.39,.37,.35},d={2,-1,3,0,2,0},falls={3,5},warmth=.02},
 cove={x={-.89,-.56,-.23,.13,.46,.79},h={9,18,13,8,15,10},
  w={.37,.40,.39,.39,.37,.35},d={0,2,0,3,-1,1},falls={2},warmth=.23},
 summit={x={-.84,-.43,.01,.43,.84},h={10,21,13,24,12},
  w={.42,.46,.46,.45,.41},d={1,3,0,2,0},falls={2,4},warmth=.04},
}

local function waterfall(parent: Model,frame: CFrame,x: number,z: number,width: number,top: number,phase: number)
 -- The lip overlaps its rock crown. Water crosses the ledge to its actual edge.
 Kit.part(parent,"WaterfallSourceLip",Vector3.new(width+.7,.5,5.8),
  frame*CFrame.new(x,top-.25,z+5.1),C.Stone,ROCK)
 local channel=Kit.part(parent,"WaterfallSourceChannel",Vector3.new(width,.055,5.7),
  frame*CFrame.new(x,top+.03,z+5.1),WATER,
  {material=Enum.Material.SmoothPlastic,transparency=.34,shadow=false})
 channel:SetAttribute("GlintPhase",phase)
 local height=top-.12
 local curtain=Kit.part(parent,"PondWaterfallCurtain",Vector3.new(width,height,.19),
  frame*CFrame.new(x,.12+height/2,z+8),WATER,
  {material=Enum.Material.SmoothPlastic,transparency=.42,shadow=false})
 for index=1,3 do
  local streak=Kit.part(parent,"PondWaterfallStreak",Vector3.new(.10,3.6,.07),
   curtain.CFrame*CFrame.new((index-2)*width*.29,0,.14),FOAM,
   {material=Enum.Material.SmoothPlastic,transparency=.48,shadow=false})
  streak:SetAttribute("FlowStart",streak.CFrame)
  streak:SetAttribute("FlowPhase",phase+index*.29)
  streak:SetAttribute("FlowDistance",height-streak.Size.Y)
  streak:SetAttribute("FlowSpeed",9+index*.7)
 end
 for index=1,3 do
  local foam=Kit.wedge(parent,"PondWaterfallFoam",Vector3.new(width*.45,.12,1.65),
   frame*CFrame.new(x+(index-2)*width*.3,.15,z+8.55+index%2*.6)*CFrame.Angles(0,(index-2)*.16,0),FOAM,
   {material=Enum.Material.SmoothPlastic,transparency=.45,shadow=false})
  foam:SetAttribute("GlintPhase",phase+index*.43)
 end
end

-- A low waterfront fence makes the exposed suspended-lagoon edge intentional.
-- Its stone foot reaches the basin; visible rope/wood owns any contact. No
-- hidden wall spans the water, and dock and spillway openings remain open.
local function boundary(parent: Model, water: any, dock: any)
 local center=Vector3.new(table.unpack(water.Center))
 local radiusX,radiusZ=water.Radius[1],water.Radius[2]
 local inlet=math.atan2((dock.B[3]-center.Z)/radiusZ,(dock.B[1]-center.X)/radiusX)
 local function delta(a: number,b: number): number
  return math.abs(math.atan2(math.sin(a-b),math.cos(a-b)))
 end
 local count=20
 local vertices={}
 for index=1,count do
  local angle=(index-1)*math.pi*2/count
  vertices[index]=center+Vector3.new(math.cos(angle)*(radiusX+2),0,math.sin(angle)*(radiusZ+2))
 end
 local posts={}
 local wood={material=Enum.Material.Wood,collidable=true}
 local rope={material=Enum.Material.Fabric,collidable=true}
 local rim={material=Enum.Material.Slate,collidable=true}
 local outlet=math.atan2(.89,.45)
 for index=1,count do
  local nextIndex=index%count+1
  local angle=(index-.5)*math.pi*2/count
  -- The inlet includes the side portal and mooring approach. Rock terraces
  -- frame the far bank, so a second rail behind them would only add clutter.
  if delta(angle,inlet)<.67 or delta(angle,inlet+math.pi)<.57 or delta(angle,outlet)<.24 then continue end
  local a,b=vertices[index],vertices[nextIndex]
  local tangent=b-a
  local foot=Kit.part(parent,"LagoonRetainingRim",Vector3.new(tangent.Magnitude+.18,5.45,3.2),
   CFrame.lookAt((a+b)/2-Vector3.yAxis*2.375,b-Vector3.yAxis*2.375)*CFrame.Angles(0,math.pi/2,0),
   C.Stone:Lerp(C.Limestone,.16),rim)
  foot:SetAttribute("BoundaryZoneId",water.Id)
  for _,vertex in {index,nextIndex} do
   if not posts[vertex] then
    local point=vertices[vertex]
    Kit.beam(parent,"LagoonFencePost",point+Vector3.yAxis*.25,point+Vector3.yAxis*2.25,.34,C.Bark,wood)
    posts[vertex]=true
   end
  end
  local start,finish=a+Vector3.yAxis*1.72,b+Vector3.yAxis*1.72
  local sag=(start+finish)/2-Vector3.yAxis*.23
  Kit.beam(parent,"LagoonFenceRope",start,sag,.15,C.Cream:Lerp(C.Wood,.18),rope)
  Kit.beam(parent,"LagoonFenceRope",sag,finish,.15,C.Cream:Lerp(C.Wood,.18),rope)
 end
end

function Backdrops.populate(parent: Instance)
 for _,water in Layout.Waters do
  local shore=SHORES[water.Id]
  local yaw=0
  local shorelineDock=nil
  for _,dock in Layout.Docks do if dock.Id==water.Id then yaw=dock.Yaw;shorelineDock=dock;break end end
  local model=Kit.model(parent,water.Id.."PondTerraces")
  model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  model:SetAttribute("ShoreZoneId",water.Id)
  local frame=CFrame.new(table.unpack(water.Center))*CFrame.Angles(0,yaw,0)
  local sideways=math.abs(math.sin(yaw))>.5
  local radiusX=if sideways then water.Radius[2] else water.Radius[1]
  local radiusZ=if sideways then water.Radius[1] else water.Radius[2]
  for index,offset in shore.x do
   local x=offset*radiusX
   local width,height=radiusX*shore.w[index],shore.h[index]
   local isFall=table.find(shore.falls,index)~=nil
   -- Keep the entire cascade inside the elliptical water surface, including
   -- its outer edge; a centered check alone leaves the sides falling onto land.
   local outerX=if isFall then math.min(.99,math.abs(offset)+width*.31*.55/radiusX) else math.abs(offset)
   local setback=if isFall then math.min(.4,shore.d[index]) else shore.d[index]
   local z=-(radiusZ*math.sqrt(1-outerX*outerX)+6+setback)
   local ledge=height*(.44+index%3*.045)
   local lowerTint=C.Cliff:Lerp(C.DeepStone,.08+index%3*.035)
   local upperTint=C.Stone:Lerp(C.Limestone,shore.warmth+index%3*.018)
   -- The crown is seated inside the lower face's flat top. Former upper
   -- shoulders overhung that top, leaving conspicuous dangling triangles.
   local crownWidth=width*(.44+index%3*.015)
   local crownShift=if isFall then 0 else width*math.sin(index*1.7)*.015
   local crownDepth=if isFall then 10 else 6.2+index%2*.5
   local crownFront=if isFall then 3 else -.8
   local crownZ=z+crownFront-crownDepth/2
   local crownHeight=height-ledge+.08
   local crownHalf=crownWidth/2
   local shoulderWidth=width*.13
   Kit.part(model,"LowerShoreRockFace",Vector3.new(width*.76,ledge-BASE,15.2),
    frame*CFrame.new(x,(ledge+BASE)/2,z),lowerTint,ROCK)
   Kit.part(model,"UpperShoreRockFace",Vector3.new(crownWidth,crownHeight,crownDepth),
    frame*CFrame.new(x+crownShift,(height+ledge)/2,crownZ),upperTint,ROCK)
   for _,side in {-1,1} do
    Kit.wedge(model,"TaperedShoreButtress",Vector3.new(15.2,ledge-BASE,width*.22),
     frame*CFrame.new(x+side*width*.48,(ledge+BASE)/2,z)*CFrame.Angles(0,-side*math.pi/2,0),lowerTint,ROCK)
    Kit.wedge(model,"UpperShoreRockFacet",Vector3.new(crownDepth,crownHeight,shoulderWidth),
     frame*CFrame.new(x+crownShift+side*(crownHalf+shoulderWidth*.48),(height+ledge)/2,crownZ)
      *CFrame.Angles(0,-side*math.pi/2,0),upperTint:Lerp(lowerTint,.08),ROCK)
   end
   -- A sloping, water-facing plane softens the second terrace's square front.
   -- Its full base rests on the visible lower rock; falls retain their exact lip.
   local apronDepth=if isFall then 2.5 else 3.8
   Kit.wedge(model,"WeatheredShoreApron",Vector3.new(crownWidth,crownHeight,apronDepth),
    frame*CFrame.new(x+crownShift,(height+ledge)/2,z+crownFront+apronDepth/2)
     *CFrame.Angles(0,math.pi,0),upperTint:Lerp(lowerTint,.13),ROCK)
   if index==2 or index==#shore.x-1 then
    for leaf=1,2 do
     Kit.wedge(model,"ShoreLedgeLeaf",Vector3.new(.12,.65,1.1),
      frame*CFrame.new(x+(leaf-1.5)*.65,ledge+.32,z+6.2)*CFrame.Angles(0,leaf*.8,.15),C.Leaf,{shadow=false})
    end
   end
   for _,fallIndex in shore.falls do
    if fallIndex==index then waterfall(model,frame,x,z,width*.31,height,index*.17) end
   end
  end
  assert(shorelineDock,"Lagoon boundary requires its existing dock")
  boundary(model,water,shorelineDock)
 end
end

return Backdrops
