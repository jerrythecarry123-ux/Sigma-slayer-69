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

-- The coping is a real polygonal bank over the selected Terrain cells. Every
-- exposed joint is a miter, and the battered outside faces meet the same shared
-- corners. Thin, solid masonry faces enclose the visible basin foundation.
local boundaryFacet=0
local function tagged(part: BasePart,zone: string?)
 if not zone then return end
 part:SetAttribute("BoundaryZoneId",zone)
 part:SetAttribute("BoundaryFacet",boundaryFacet)
end

local function triangle(parent: Model,name: string,a: Vector3,b: Vector3,c: Vector3,
 thickness: number,color: Color3,zone: string?)
 local points={a,b,c}
 for index,corner in points do
  local p,q=points[index%3+1],points[(index+1)%3+1]
  local first,second=p-corner,q-corner
  if first.Magnitude>.001 and second.Magnitude>.001 and math.abs(first:Dot(second))<1e-5*first.Magnitude*second.Magnitude then
   local up,back=first.Unit,-second.Unit
   tagged(Kit.wedge(parent,name,Vector3.new(thickness,first.Magnitude,second.Magnitude),
    CFrame.fromMatrix((p+q)/2,up:Cross(back),up,back),color,ROCK),zone)
   return
  end
 end
 local ab,ac,bc=b-a,c-a,c-b
 local abd,acd,bcd=ab:Dot(ab),ac:Dot(ac),bc:Dot(bc)
 if abd>acd and abd>bcd then c,a=a,c
 elseif acd>bcd and acd>abd then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 if ac:Cross(ab).Magnitude<.00001 then return end
 local right=ac:Cross(ab).Unit
 local back=bc.Unit
 local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 local l1,l2=math.abs(ab:Dot(back)),math.abs(ac:Dot(back))
 if l1>.001 then tagged(Kit.wedge(parent,name,Vector3.new(thickness,height,l1),
  CFrame.fromMatrix((a+b)/2,right,up,back),color,ROCK),zone) end
 if l2>.001 then tagged(Kit.wedge(parent,name,Vector3.new(thickness,height,l2),
  CFrame.fromMatrix((a+c)/2,-right,up,-back),color,ROCK),zone) end
end

-- An uncut trapezoid takes one rectangle and two right-triangle prisms. This
-- keeps exact shared vertices without paying for four arbitrary triangle halves.
local function slab(parent: Model,name: string,polygon: {Vector3},thickness: number,color: Color3,zone: string?)
 if #polygon<3 then return end
 if #polygon==4 then
  for first=1,2 do
   local a,b,c,d=polygon[first],polygon[first%4+1],polygon[(first+1)%4+1],polygon[(first+2)%4+1]
   if (b-a).Magnitude<.001 or (c-d).Magnitude<.001 then continue end
   if (b-a):Cross(c-d).Magnitude>1e-5*(b-a).Magnitude*(c-d).Magnitude then continue end
   if (b-a).Magnitude<(c-d).Magnitude then a,b,c,d=c,d,a,b end
   local along=(b-a).Unit
   local left,right=(d-a):Dot(along),(c-a):Dot(along)
   local across=d-a-along*left
   local length=(b-a).Magnitude
   if across.Magnitude<.001 or left<-.001 or right>length+.001 or right-left<.001 then continue end
   local normal=along:Cross(across.Unit)
   tagged(Kit.part(parent,name,Vector3.new(right-left,across.Magnitude,thickness),
    CFrame.fromMatrix(a+along*((left+right)/2)+across/2,along,across.Unit,normal),color,ROCK),zone)
   triangle(parent,name,a,a+along*left,d,thickness,color,zone)
   triangle(parent,name,b,c,a+along*right,thickness,color,zone)
   return
  end
 end
 for index=2,#polygon-1 do triangle(parent,name,polygon[1],polygon[index],polygon[index+1],thickness,color,zone) end
end

local function side(a: Vector3,b: Vector3,p: Vector3): number
 return (b.X-a.X)*(p.Z-a.Z)-(b.Z-a.Z)*(p.X-a.X)
end
local function clean(polygon: {Vector3}): {Vector3}
 local points={}
 for _,point in polygon do
  if #points==0 or (point-points[#points]).Magnitude>.00001 then table.insert(points,point) end
 end
 if #points>1 and (points[1]-points[#points]).Magnitude<.00001 then table.remove(points) end
 local index=1
 while #points>=3 and index<=#points do
  local previous=points[(index-2)%#points+1]
  local point,following=points[index],points[index%#points+1]
  if (point-previous):Cross(following-point).Magnitude<.00001 then table.remove(points,index)
  else index+=1 end
 end
 return points
end
local function clip(polygon: {Vector3},a: Vector3,b: Vector3,inside: boolean): {Vector3}
 local output={}
 for index,q in polygon do
  local p=polygon[(index-2)%#polygon+1]
  local dp,dq=side(a,b,p),side(a,b,q)
  if not inside then dp,dq=-dp,-dq end
  local pin,qin=dp>=-.000001,dq>=-.000001
  if pin~=qin then table.insert(output,p+(q-p)*(dp/(dp-dq))) end
  if qin then table.insert(output,q) end
 end
 return clean(output)
end
local function subtract(polygon: {Vector3},opening: {Vector3}): {{Vector3}}
 local intersection=polygon
 for index,a in opening do
  intersection=clip(intersection,a,opening[index%#opening+1],true)
  if #intersection==0 then return {polygon} end
 end
 local output={}
 local remaining=polygon
 for index,a in opening do
  local b=opening[index%#opening+1]
  local outside=clip(remaining,a,b,false)
  if #outside>=3 then table.insert(output,outside) end
  remaining=clip(remaining,a,b,true)
  if #remaining==0 then break end
 end
 return output
end
local function trimmed(polygon: {Vector3},openings: {{Vector3}}): {{Vector3}}
 local pieces={polygon}
 for _,opening in openings do
  local nextPieces={}
  for _,piece in pieces do for _,remaining in subtract(piece,opening) do table.insert(nextPieces,remaining) end end
  pieces=nextPieces
 end
 return pieces
end
local function rectangle(frame: CFrame,width: number,depth: number,margin: number?): {Vector3}
 local x,z=width/2+(margin or 0),depth/2+(margin or 0)
 return {frame:PointToWorldSpace(Vector3.new(-x,0,-z)),frame:PointToWorldSpace(Vector3.new(x,0,-z)),
  frame:PointToWorldSpace(Vector3.new(x,0,z)),frame:PointToWorldSpace(Vector3.new(-x,0,z))}
end
local function expandedRectangle(polygon: {Vector3},distance: number): {Vector3}
 local output={}
 for index,point in polygon do
  local incoming=point-polygon[(index-2)%#polygon+1]
  local outgoing=polygon[index%#polygon+1]-point
  local first=Vector3.new(incoming.Z,0,-incoming.X).Unit
  local second=Vector3.new(outgoing.Z,0,-outgoing.X).Unit
  table.insert(output,point+(first+second)*distance)
 end
 return output
end
local function linePieces(a: Vector3,b: Vector3,openings: {{Vector3}}): {{Vector3}}
 local pieces={{a,b}}
 for _,opening in openings do
  local nextPieces={}
  for _,piece in pieces do
   local start,finish=piece[1],piece[2]
   local low,high=0,1
   for index,p in opening do
    local q=opening[index%#opening+1]
    local ds,de=side(p,q,start),side(p,q,finish)
    if ds<0 and de<0 then high=-1;break end
    if ds<0 then low=math.max(low,ds/(ds-de))
    elseif de<0 then high=math.min(high,ds/(ds-de)) end
   end
   if high<low then table.insert(nextPieces,piece)
   else
    if low>.00001 then table.insert(nextPieces,{start,start+(finish-start)*low}) end
    if high<.99999 then table.insert(nextPieces,{start+(finish-start)*high,finish}) end
   end
  end
  pieces=nextPieces
 end
 return pieces
end

local function boundary(parent: Model,water: any,dock: any,shoreOpenings: {{Vector3}})
 local center=Vector3.new(table.unpack(water.Center))
 local geometry=Layout.waterGeometry(water)
 local outside,inside,fence,bottom={},{},{},{}
 local band=geometry.InnerInset+.3
 for index,p in geometry.Outer do
  outside[index]=Vector3.new(table.unpack(p))
  inside[index]=Vector3.new(table.unpack(geometry.Inner[index]))
  fence[index]=outside[index]:Lerp(inside[index],.8/band)
  bottom[index]=outside[index]:Lerp(inside[index],.9/band)-Vector3.yAxis*5.1
 end
 local dockA,dockB=Vector3.new(table.unpack(dock.A)),Vector3.new(table.unpack(dock.B))
 local basis=CFrame.lookAt((dockA+dockB)/2,dockB)
 local portal=CFrame.new(table.unpack(dock.Spot))*CFrame.Angles(0,dock.Yaw,0)*CFrame.new(dock.Width/2+4.5,0,8)
 local spill=geometry.Spillway
 local farZ=center.Z+water.Radius[2]+16
 local pierOpenings={rectangle(basis,dock.Width,(dockB-dockA).Magnitude,.18),rectangle(portal,13,12,.18)}
 local openings={rectangle(CFrame.new((spill.MinX+spill.MaxX)/2,center.Y,(spill.MinZ+farZ)/2),
  spill.MaxX-spill.MinX,farZ-spill.MinZ,.2)}
 local railOpenings={}
 -- A post has a footprint, not just a centre point. Its complete round foot
 -- sits on coping, inset from the masonry return at each opening.
 for _,opening in openings do table.insert(railOpenings,expandedRectangle(opening,.23)) end
 for _,opening in pierOpenings do table.insert(railOpenings,expandedRectangle(opening,.23)) end
 for _,opening in shoreOpenings do table.insert(railOpenings,opening) end
 local stone=C.Stone:Lerp(C.Limestone,.11)
 local coping=C.Stone:Lerp(C.Limestone,.26)
 local wood={material=Enum.Material.Wood,collidable=true}
 local rope={material=Enum.Material.Fabric,collidable=true}
 local posts={}
 local returns={}
 local function post(point: Vector3)
  local key=string.format("%.3f:%.3f",point.X,point.Z)
  if posts[key] then return end
  posts[key]=true
  local part=Kit.beam(parent,"LagoonFencePost",point+Vector3.yAxis*.29,point+Vector3.yAxis*2.44,.34,C.Bark,wood)
  tagged(part,water.Id)
 end
 for index,a in outside do
  boundaryFacet=index
  local nextIndex=index%#outside+1
  local b=outside[nextIndex]
  local topA,topB=a-Vector3.yAxis*.22,b-Vector3.yAxis*.22
  local face={topA,topB,bottom[nextIndex],bottom[index]}
  for _,piece in trimmed(face,openings) do slab(parent,"LagoonRetainingRim",piece,.36,stone,water.Id) end
  local innerA,innerB=inside[index],inside[nextIndex]
  local innerFace={innerA-Vector3.yAxis*.22,innerB-Vector3.yAxis*.22,
   innerB-Vector3.yAxis*5.1,innerA-Vector3.yAxis*5.1}
  for _,piece in trimmed(innerFace,openings) do slab(parent,"LagoonInnerRetainingFace",piece,.38,stone,water.Id) end
  local cap={a+Vector3.yAxis*.025,b+Vector3.yAxis*.025,
   innerB+Vector3.yAxis*.025,innerA+Vector3.yAxis*.025}
  for _,piece in trimmed(cap,openings) do
   slab(parent,"LagoonCoping",piece,.65,coping,water.Id)
   -- Close every real opening with a visible masonry return. Artificial
   -- triangulation seams stay internal; only footprint edges receive returns.
   for vertex,p in piece do
    local q=piece[vertex%#piece+1]
    for _,opening in openings do
     for openingIndex,start in opening do
      local finish=opening[openingIndex%#opening+1]
      local length=(finish-start).Magnitude
      if math.abs(side(start,finish,p))/length>.0001 or math.abs(side(start,finish,q))/length>.0001 then continue end
      local keyA=string.format("%.4f:%.4f",p.X,p.Z)
      local keyB=string.format("%.4f:%.4f",q.X,q.Z)
      local key=if keyA<keyB then keyA.."/"..keyB else keyB.."/"..keyA
      if returns[key] then continue end
      returns[key]=true
      local polygon={Vector3.new(p.X,center.Y-.22,p.Z),Vector3.new(q.X,center.Y-.22,q.Z),
       Vector3.new(q.X,center.Y-5.1,q.Z),Vector3.new(p.X,center.Y-5.1,p.Z)}
      local outward=Vector3.new((b-a).Z,0,-(b-a).X).Unit
      local function distance(point: Vector3): number
       return outward:Dot(point-topA)-.9/4.88*(point.Y-topA.Y)
      end
      local clipped={}
      for edge,s in polygon do
       local r=polygon[(edge-2)%#polygon+1]
       local dr,ds=distance(r),distance(s)
       if (dr<=.000001)~=(ds<=.000001) then table.insert(clipped,r+(s-r)*(dr/(dr-ds))) end
       if ds<=.000001 then table.insert(clipped,s) end
      end
      slab(parent,"LagoonBoundaryReturn",clean(clipped),.36,stone,water.Id)
     end
    end
   end
  end
  for _,piece in linePieces(fence[index],fence[nextIndex],railOpenings) do
   local start,finish=piece[1],piece[2]
   if (finish-start).Magnitude<.7 then continue end
   post(start);post(finish)
   local upperStart,upperFinish=start+Vector3.yAxis*1.91,finish+Vector3.yAxis*1.91
   local sag=(upperStart+upperFinish)/2-Vector3.yAxis*.22
   tagged(Kit.beam(parent,"LagoonFenceRope",upperStart,sag,.15,C.Cream:Lerp(C.Wood,.18),rope),water.Id)
   tagged(Kit.beam(parent,"LagoonFenceRope",sag,upperFinish,.15,C.Cream:Lerp(C.Wood,.18),rope),water.Id)
  end
 end
end

local function fittedFallSetback(water: any,frame: CFrame,x: number,width: number,z: number): number
 local inner=Layout.waterGeometry(water).Inner
 local forward=frame:PointToWorldSpace(Vector3.zAxis)-frame.Position
 local front=z+8
 -- Endpoints suffice for a convex water hole. Require real perpendicular
 -- clearance from every inner coping edge, including the outer curtain width.
 for _,side in {-1,1} do
  local point=frame:PointToWorldSpace(Vector3.new(x+side*width*.31*.52,0,0))
  for index,p in inner do
   local a=Vector3.new(table.unpack(p))
   local b=Vector3.new(table.unpack(inner[index%#inner+1]))
   local normal=Vector3.new((b-a).Z,0,-(b-a).X).Unit
   local slope=normal:Dot(forward)
   if slope<-.00001 then front=math.max(front,(normal:Dot(a-point)-.75)/slope) end
  end
 end
 return front-8
end

-- Lower shore masses are prisms along the terrace's local Z. Subtract the
-- real spillway from their vertical sections; a painted curtain in front of a
-- whole collider would still leave an impossible source and a blocked opening.
local function sectionClip(polygon: {Vector3},axis: string,value: number,less: boolean): {Vector3}
 local output={}
 for index,b in polygon do
  local a=polygon[(index-2)%#polygon+1]
  local av=if axis=="X" then a.X else a.Y
  local bv=if axis=="X" then b.X else b.Y
  local da,db=av-value,bv-value
  if not less then da,db=-da,-db end
  if (da<=.000001)~=(db<=.000001) then table.insert(output,a+(b-a)*(da/(da-db))) end
  if db<=.000001 then table.insert(output,b) end
 end
 return clean(output)
end

local function shorePrism(parent: Model,name: string,polygon: {Vector3},z: number,depth: number,
 frame: CFrame,color: Color3,slot: any)
 local z0,z1=z-depth/2,z+depth/2
 local a,b=math.max(z0,slot.MinZ),math.min(z1,slot.MaxZ)
 local intersection=sectionClip(sectionClip(sectionClip(polygon,"X",slot.MinX,false),"X",slot.MaxX,true),"Y",1.65,true)
 local cut=b-a>.001 and #intersection>=3
 local function emit(section: {Vector3},start: number,finish: number)
  if finish-start<.001 or #section<3 then return end
  local points={}
  for _,point in section do table.insert(points,frame:PointToWorldSpace(Vector3.new(point.X,point.Y,(start+finish)/2))) end
  slab(parent,name,points,finish-start,color,nil)
 end
 if not cut then emit(polygon,z0,z1);return end
 emit(polygon,z0,a)
 emit(polygon,b,z1)
 -- Keep the continuous rock lintel; below it only the two fitted jambs remain.
 emit(sectionClip(polygon,"Y",1.65,false),a,b)
 local low=sectionClip(polygon,"Y",1.65,true)
 emit(sectionClip(low,"X",slot.MinX,true),a,b)
 emit(sectionClip(low,"X",slot.MaxX,false),a,b)
end

local function outletSlot(water: any,frame: CFrame): any
 local spill=Layout.waterGeometry(water).Spillway
 local minimumX,maximumX,minimumZ,maximumZ=math.huge,-math.huge,math.huge,-math.huge
 -- Extend through the complete rock thickness, starting in the pond rather
 -- than ending inside a back face. The bridge above the slot stays in place.
 for _,x in {spill.MinX-.24,spill.MaxX+.24} do
  for _,z in {water.Center[3],water.Center[3]+water.Radius[2]+32} do
   local point=frame:PointToObjectSpace(Vector3.new(x,water.Center[2],z))
   minimumX,maximumX=math.min(minimumX,point.X),math.max(maximumX,point.X)
   minimumZ,maximumZ=math.min(minimumZ,point.Z),math.max(maximumZ,point.Z)
  end
 end
 return {MinX=minimumX,MaxX=maximumX,MinZ=minimumZ,MaxZ=maximumZ}
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
  local shoreOpenings={}
  local slot=outletSlot(water,frame)
  for index,offset in shore.x do
   local x=offset*radiusX
   local width,height=radiusX*shore.w[index],shore.h[index]
   local isFall=table.find(shore.falls,index)~=nil
   -- Keep the entire cascade inside the elliptical water surface, including
   -- its outer edge; a centered check alone leaves the sides falling onto land.
   local outerX=if isFall then math.min(.99,math.abs(offset)+width*.31*.55/radiusX) else math.abs(offset)
   local setback=if isFall then math.min(.4,shore.d[index]) else shore.d[index]
   local z=-(radiusZ*math.sqrt(1-outerX*outerX)+6+setback)
   if isFall then z=fittedFallSetback(water,frame,x,width,z) end
   local ledge=height*(.44+index%3*.045)
   -- Trim the rail against the actual lower rocks at its post-foot height.
   -- The buttress narrows as it rises, so its full ground box is too broad.
   local footFraction=(.29-BASE)/(ledge-BASE)
   local rockHalf=width*(.59-.22*footFraction)
   table.insert(shoreOpenings,rectangle(frame*CFrame.new(x,0,z),rockHalf*2,15.2,.23))
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
   shorePrism(model,"LowerShoreRockFace",{Vector3.new(x-width*.38,BASE,0),Vector3.new(x+width*.38,BASE,0),
    Vector3.new(x+width*.38,ledge,0),Vector3.new(x-width*.38,ledge,0)},z,15.2,frame,lowerTint,slot)
   Kit.part(model,"UpperShoreRockFace",Vector3.new(crownWidth,crownHeight,crownDepth),
    frame*CFrame.new(x+crownShift,(height+ledge)/2,crownZ),upperTint,ROCK)
   for _,side in {-1,1} do
    shorePrism(model,"TaperedShoreButtress",{Vector3.new(x+side*width*.59,BASE,0),
     Vector3.new(x+side*width*.37,BASE,0),Vector3.new(x+side*width*.37,ledge,0)},z,15.2,frame,lowerTint,slot)
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
  boundary(model,water,shorelineDock,shoreOpenings)
 end
end

return Backdrops
