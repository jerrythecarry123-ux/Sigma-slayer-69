#!/usr/bin/env python3
"""Exercise production scenery motion with geometry/events, not the Roblox engine.

Checks boat moorings, authored pivots, quiet waterfall wraps, distance limits,
large-clock rotor angles and streamed root recovery. No rendering/FPS claim.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local function signal()
 local callbacks={}
 return {
  Connect=function(_,callback)
   table.insert(callbacks,callback)
   return {Disconnect=function() local at=table.find(callbacks,callback);if at then table.remove(callbacks,at) end end}
  end,
  Fire=function(_,...) for _,callback in table.clone(callbacks) do callback(...) end end,
  Count=function() return #callbacks end,
 }
end
local originalIndex=mt.__index
mt.__index=function(self,key)
 if key=='MaterialVariant' then return self.props.MaterialVariant or '' end
 if key=='AttributeChanged' or key=='ChildAdded' or key=='DescendantAdded' or key=='DescendantRemoving' or key=='AncestryChanged' then
  if not self.props[key] then self.props[key]=signal() end
  return self.props[key]
 end
 return originalIndex(self,key)
end
function methods:GetAttributeChangedSignal(name)
 self.props.attributeSignals=self.props.attributeSignals or {}
 self.props.attributeSignals[name]=self.props.attributeSignals[name] or signal()
 return self.props.attributeSignals[name]
end
function methods:GetPropertyChangedSignal(name)
 self.props.propertySignals=self.props.propertySignals or {}
 self.props.propertySignals[name]=self.props.propertySignals[name] or signal()
 return self.props.propertySignals[name]
end
local setAttribute=methods.SetAttribute
function methods:SetAttribute(name,value)
 local old=self:GetAttribute(name)
 setAttribute(self,name,value)
 if old~=value then
  self.AttributeChanged:Fire(name)
  local changed=self.props.attributeSignals and self.props.attributeSignals[name]
  if changed then changed:Fire() end
 end
end
local nativeNewIndex=mt.__newindex
local surfaceWrites={}
mt.__newindex=function(self,key,value)
 nativeNewIndex(self,key,value)
 if key=='MaterialVariant' then surfaceWrites[self]=(surfaceWrites[self] or 0)+1 end
 local changed=self.props.propertySignals and self.props.propertySignals[key]
 if changed then changed:Fire() end
end
local surfaceAdded,surfaceRemoved=signal(),signal()
local collection={
 GetInstanceAddedSignal=function(_,name) assert(name=='AnglersSurfaceStyle');return surfaceAdded end,
 GetInstanceRemovedSignal=function(_,name) assert(name=='AnglersSurfaceStyle');return surfaceRemoved end,
}
local addTag,removeTag=methods.AddTag,methods.RemoveTag
function methods:AddTag(name)
 local present=self:HasTag(name)
 addTag(self,name)
 if not present and name=='AnglersSurfaceStyle' then surfaceAdded:Fire(self) end
end
function methods:RemoveTag(name)
 local present=self:HasTag(name)
 removeTag(self,name)
 if present and name=='AnglersSurfaceStyle' then surfaceRemoved:Fire(self) end
end
function methods:IsDescendantOf(ancestor)
 local node=self.Parent
 while node do if node==ancestor then return true end;node=node.Parent end
 return false
end
function methods:FindFirstChildWhichIsA(class,recursive)
 for _,node in self:GetChildren() do
  if node:IsA(class) then return node end
  if recursive then
   local found=node:FindFirstChildWhichIsA(class,true)
   if found then return found end
  end
 end
 return nil
end
local nativeTypeof=typeof
typeof=function(value)
 if getmetatable(value)==CF then return 'CFrame' end
 if getmetatable(value)==V then return 'Vector3' end
 return nativeTypeof(value)
end
local nativePivot=methods.PivotTo
function methods:PivotTo(cf)
 nativePivot(self,cf)
 if self.PrimaryPart then self.PrimaryPart.CFrame=cf end
end
local now=1800000000
function methods:GetServerTimeNow() return now end
local heartbeat=signal()
local oldGetService=game.GetService
game.GetService=function(self,name)
 if name=='RunService' then return {Heartbeat=heartbeat} end
 if name=='CollectionService' then return collection end
 return oldGetService(self,name)
end
workspace.CurrentCamera={CFrame=CFrame.new(0,20,0)}
local residentStarts=0
modules.ResidentPresentation={start=function() residentStarts+=1 end}
local token=Instance.new('ModuleScript');token.Name='ResidentPresentation';token.Parent=shared
local world=Instance.new('Folder');world.Name='MolnfiskarnaPrototype';world.Parent=workspace
local regions={}
for _,id in {'harbor','blossom','forest','cove','summit'} do
 local region=Instance.new('Model');region.Name=id;region.Parent=world;regions[id]=region
end
modules.WorldLandscaping.populate(world,regions)
local function find(name)
 for _,node in world:GetDescendants() do if node.Name==name then return node end end
 error('Missing production scenery '..name,0)
end
local boat, dock, bow = find('SundriftPaintedSkiff'),find('SkiffDockMooring'),find('SkiffBowMooring')
local rope=find('SkiffMooringLine')
assert(not dock:IsDescendantOf(boat) and bow:IsDescendantOf(boat),'dock anchor moves with the boat')
assert(rope:IsA('Beam') and rope.Attachment0.Parent==dock and rope.Attachment1.Parent==bow,'mooring does not connect fixed dock to moving bow')
-- Native Beam curves follow each Attachment's local X axis. Both control
-- points must sag below their endpoints instead of bending the rope sideways.
local function controlPoint(attachment,curve)
 local axis=attachment.Axis or Vector3.xAxis
 local direction=attachment.Parent.CFrame*axis-attachment.Parent.Position
 return attachment.Parent.Position+direction*curve
end
assert(controlPoint(rope.Attachment0,rope.CurveSize0).Y<dock.Position.Y-.5,
 'mooring dock tangent bends sideways rather than sagging down')
assert(controlPoint(rope.Attachment1,-rope.CurveSize1).Y<bow.Position.Y-.5,
 'mooring boat tangent bends sideways rather than sagging down')
local boatOrigin=boat:GetAttribute('DriftOrigin')
-- Evaluate the actual authored hull and dry interior through the complete
-- conservative bob/tilt envelope, including maximum bob with no tilt.
local waterY
for _,water in modules.WorldLayout.Waters do if water.Id=='harbor' then waterY=water.Center[2] end end
assert(waterY,'harbor water is missing')
local hullPoints,dryPoints={},{}
local bowFloors=0
for _,part in boat:GetDescendants() do
 if part:IsA('BasePart') and part.Name=='PaintedHull' then
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   table.insert(hullPoints,boatOrigin:PointToObjectSpace(part.CFrame*Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2)))
  end end end
 elseif part:IsA('BasePart') and part.Name=='SkiffFloor' then
  for _,x in {-1,1} do for _,z in {-1,1} do
   table.insert(dryPoints,boatOrigin:PointToObjectSpace(part.CFrame*Vector3.new(x*part.Size.X/2,part.Size.Y/2,z*part.Size.Z/2)))
  end end
 elseif part:IsA('BasePart') and part.Name=='BowFloor' then
  bowFloors+=1
  local vertical=(part.CFrame*Vector3.xAxis-part.Position).Y
  local top=if vertical>0 then part.Size.X/2 else -part.Size.X/2
  -- Actual triangular top-face vertices of a WedgePart, rather than its box.
  for _,vertex in {Vector3.new(top,-part.Size.Y/2,-part.Size.Z/2),Vector3.new(top,-part.Size.Y/2,part.Size.Z/2),Vector3.new(top,part.Size.Y/2,part.Size.Z/2)} do
   local localPoint=boatOrigin:PointToObjectSpace(part.CFrame*vertex)
   assert(localPoint.Z>=-8.401 and localPoint.Z<=-5.899 and math.abs(localPoint.Y-.86)<.001,
    'bow floor is not a level, fitted triangle')
   table.insert(dryPoints,localPoint)
  end
 end
end
assert(#hullPoints==16 and #dryPoints==10 and bowFloors==2,'boat contact/dry-floor geometry is incomplete')
for _,bob in {-.12,0,.12} do for _,pitch in {-.01,0,.01} do for _,roll in {-.018,0,.018} do
 local frame=boatOrigin*CFrame.new(0,bob,0)*CFrame.Angles(pitch,0,roll)
 local bottom=math.huge
 for _,point in hullPoints do bottom=math.min(bottom,(frame*point).Y) end
 assert(bottom<=waterY-.045,'boat hull hovers above the water at a bob extreme')
 for _,point in dryPoints do assert((frame*point).Y>waterY+.07,'water reaches the boat interior during bob/tilt') end
end end end
local bowRest=boatOrigin:PointToObjectSpace(bow.Position)
local dockPosition=dock.Position
boat.WorldPivot=CFrame.new(2000,30,4) -- WorldPivot does not replicate from server.
local canvas=find('BreezyParasolCanvas')
local canvasOrigin=canvas:GetAttribute('SwayOrigin')
canvas.WorldPivot=CFrame.new(3000,50,12)
local sky=Instance.new('Model');sky.Name='SkySail';sky.Parent=world
local skyOrigin=CFrame.new(60,40,35)
local skyPart=modules.WorldPrimitives.part(sky,'SkyHull',Vector3.new(8,2,3),skyOrigin,Color3.new(.4,.6,.7))
sky.WorldPivot=CFrame.new(4000,80,9)
local rotor=Instance.new('Model');rotor.Name='TestRotor';rotor.Parent=world
local rotorOrigin=CFrame.new(5,15,8)
local rotorPart=modules.WorldPrimitives.part(rotor,'RotorPart',Vector3.new(.2,4,.2),rotorOrigin*CFrame.new(0,2,0),Color3.new(.4,.5,.6))
rotor:SetAttribute('SpinOrigin',rotorOrigin);rotor:SetAttribute('SpinRate',.18)
rotor.WorldPivot=CFrame.new(5000,80,9)
local flow=modules.WorldPrimitives.part(world,'WaterfallStreak',Vector3.new(.1,4.2,.1),CFrame.new(0,15,5),Color3.new(.7,.8,.8),{transparency=.3,shadow=false})
flow:SetAttribute('FlowStart',flow.CFrame);flow:SetAttribute('FlowPhase',0)
flow:SetAttribute('FlowDistance',20);flow:SetAttribute('FlowSpeed',10)
local glint=modules.WorldPrimitives.part(world,'WaterGlint',Vector3.new(2,.04,.04),CFrame.new(4,12,7),Color3.new(.7,.8,.8),{transparency=.7,shadow=false})
glint:SetAttribute('GlintPhase',.2)
-- Erase the server-side visual to exercise actual initial client assignment.
local styled=modules.WorldPrimitives.part(world,'StyledTimber',Vector3.new(3,.4,2),CFrame.new(4,12,8),Color3.new(.7,.8,.8),{material=Enum.Material.Wood})
styled.MaterialVariant=''
local maxAngle=0
local nativeAngles=CFrame.Angles
CFrame.Angles=function(x,y,z)
 maxAngle=math.max(maxAngle,math.abs(x),math.abs(y),math.abs(z))
 return nativeAngles(x,y,z)
end
'''

CHECK = r'''
scenery.start();scenery.start()
assert(heartbeat:Count()==1 and residentStarts==1,'duplicate scenery startup')
assert(surfaceAdded:Count()==1 and surfaceRemoved:Count()==1,'duplicate material tag listeners')
assert(styled.MaterialVariant=='AnglersWeatheredWood','initial streamed timber never received its surface')
assert(styled:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0 and styled:GetPropertyChangedSignal('Material'):Count()==0,
 'finished material retained per-part readiness listeners')
local function surfacePart(name,material)
 local part=modules.WorldPrimitives.part(world,name,Vector3.new(2,.4,2),CFrame.new(5,12,8),Color3.new(.7,.8,.8),{material=material})
 part:RemoveTag('AnglersSurfaceStyle');part:SetAttribute('AnglersSurfaceStyle',nil);part.MaterialVariant=''
 return part
end
for style,material in expectedSurfaces do
 local part=surfacePart('ManifestSurface',material)
 part:SetAttribute('AnglersSurfaceStyle',style);part:AddTag('AnglersSurfaceStyle')
 assert(part.MaterialVariant==style,'client surface catalog differs from the serialized material manifest: '..style)
 assert(part:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0 and part:GetPropertyChangedSignal('Material'):Count()==0,
  'ready material retained readiness listeners: '..style)
end
local lateSurface=surfacePart('LateSurface',Enum.Material.Fabric)
world.DescendantAdded:Fire(lateSurface)
lateSurface:AddTag('AnglersSurfaceStyle')
assert(lateSurface.MaterialVariant=='' and lateSurface:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==1,
 'tagged incomplete surface lacks a bounded readiness listener')
lateSurface:SetAttribute('AnglersSurfaceStyle','AnglersCanvas')
assert(lateSurface.MaterialVariant=='AnglersCanvas' and lateSurface:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0,
 'late style did not apply once and disconnect readiness')
local lateMaterial=surfacePart('LateMaterial',Enum.Material.Plastic)
lateMaterial:SetAttribute('AnglersSurfaceStyle','AnglersPlaster');lateMaterial:AddTag('AnglersSurfaceStyle')
assert(lateMaterial.MaterialVariant=='' and lateMaterial:GetPropertyChangedSignal('Material'):Count()==1,'late base material was not awaited')
lateMaterial.Material=Enum.Material.Plaster
assert(lateMaterial.MaterialVariant=='AnglersPlaster' and lateMaterial:GetPropertyChangedSignal('Material'):Count()==0,'late base material did not settle')
local tagLate=surfacePart('LateTag',Enum.Material.Sand)
tagLate:SetAttribute('AnglersSurfaceStyle','AnglersFineSand');world.DescendantAdded:Fire(tagLate)
assert(tagLate.MaterialVariant=='','untagged world part was changed')
tagLate:AddTag('AnglersSurfaceStyle');assert(tagLate.MaterialVariant=='AnglersFineSand','late collection tag was ignored')
local badSurface=surfacePart('InvalidStyle',Enum.Material.Wood)
badSurface:SetAttribute('AnglersSurfaceStyle','UnpublishedAsset');badSurface:AddTag('AnglersSurfaceStyle')
assert(badSurface.MaterialVariant=='' and badSurface:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0,'invalid surface was assigned or retained a listener')
local meshSurface=surfacePart('MeshSurface',Enum.Material.Wood)
local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=meshSurface
meshSurface:SetAttribute('AnglersSurfaceStyle','AnglersWeatheredWood');meshSurface:AddTag('AnglersSurfaceStyle')
assert(meshSurface.MaterialVariant=='','native Part maps were assigned to a SpecialMesh')
local custom=surfacePart('CustomMapTimber',Enum.Material.Wood);custom.Parent=workspace
custom:SetAttribute('AnglersSurfaceStyle','AnglersWeatheredWood');custom:AddTag('AnglersSurfaceStyle')
assert(custom.MaterialVariant=='','material presentation changed scenery outside the generated world')
local external=surfacePart('OwnedElsewhere',Enum.Material.Wood)
external.MaterialVariant='AnotherSystem';external:SetAttribute('AnglersSurfaceStyle','AnglersWeatheredWood');external:AddTag('AnglersSurfaceStyle')
assert(external.MaterialVariant=='AnotherSystem','initial application overwrote another material owner')
styled.MaterialVariant='OtherClientSurface';world.DescendantAdded:Fire(styled)
assert(styled.MaterialVariant=='OtherClientSurface','rediscovery fought a later material owner')
lateSurface:RemoveTag('AnglersSurfaceStyle')
assert(lateSurface.MaterialVariant=='','removing the style tag did not restore the original base surface')
lateSurface:AddTag('AnglersSurfaceStyle');assert(lateSurface.MaterialVariant=='AnglersCanvas','retagged surface failed to recover')
local pendingSurface=surfacePart('PendingSurface',Enum.Material.Plastic)
pendingSurface:AddTag('AnglersSurfaceStyle')
world.DescendantRemoving:Fire(pendingSurface);pendingSurface.Parent=nil
assert(pendingSurface:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0 and pendingSurface:GetPropertyChangedSignal('Material'):Count()==0,
 'streamed-out pending surface leaked readiness connections')
world.DescendantRemoving:Fire(lateMaterial);lateMaterial.Parent=nil
assert(lateMaterial.MaterialVariant=='','streamed-out material did not restore its owned surface')
lateMaterial.Parent=world;world.DescendantAdded:Fire(lateMaterial)
assert(lateMaterial.MaterialVariant=='AnglersPlaster','streamed-in material did not recover')
local materialWritesBefore=surfaceWrites[lateMaterial]
local function step(time)
 now=time;heartbeat:Fire(.05)
 for _,part in world:GetDescendants() do
  if part:IsA('BasePart') then
   local p=part.Position
   assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and p.Magnitude<10000,'nonfinite or escaped scenery')
  end
 end
end
step(1800000000)
assert((dock.Position-dockPosition).Magnitude==0,'mooring dock end drifted')
assert((boat:GetPivot().Position-boatOrigin.Position).Magnitude<.3,'boat pivot did not initialize from authored origin')
assert((boat:GetPivot():PointToObjectSpace(bow.Position)-bowRest).Magnitude<.00001,'boat geometry shifted at first pivot')
assert((canvas:GetPivot().Position-canvasOrigin.Position).Magnitude<.00001,'canvas pivot shifted from its attachment point')
assert((skyPart.Position-skyOrigin.Position).Magnitude==0,'airship animated before its author origin arrived')
sky:SetAttribute('DriftOrigin',skyOrigin);sky.AttributeChanged:Fire('DriftOrigin')
step(1800000000.2)
assert((skyPart.Position-skyOrigin.Position).Magnitude<6,'airship used the wrong streamed pivot')
assert(flow.Transparency<.31,'waterfall never becomes visible')
assert(math.abs(flow.Position.Y-15)+flow.Size.Y/2<=12.11,'waterfall streak leaves authored curtain span')
step(1800000001.999)
assert(flow.Transparency>.98,'waterfall snaps at wrap without fading out')
step(1800000002.001)
assert(flow.Transparency>.98,'waterfall snaps at wrap without fading in')
assert(maxAngle<math.pi*2+.0001,'large Unix clock passed an imprecise angle to CFrame')
for index=1,240 do step(1800000002+index*.05) end
assert(surfaceWrites[lateMaterial]==materialWritesBefore,'static materials were polled or reassigned by animation frames')
assert((dock.Position-dockPosition).Magnitude==0,'bobbing moved fixed land mooring')
assert((boat:GetPivot():PointToObjectSpace(bow.Position)-bowRest).Magnitude<.0001,'boat joints accumulated motion error')
local flowPosition,rotorFrame,boatFrame,glintAlpha=flow.Position,rotor:GetPivot(),boat:GetPivot(),glint.Transparency
workspace.CurrentCamera.CFrame=CFrame.new(10000,10000,10000)
step(1800000100)
assert((flow.Position-flowPosition).Magnitude==0,'far waterfall still animates')
assert((rotor:GetPivot().Position-rotorFrame.Position).Magnitude==0 and rotor:GetPivot().r[1][1]==rotorFrame.r[1][1],'far rotor still animates')
assert((boat:GetPivot().Position-boatFrame.Position).Magnitude==0 and glint.Transparency==glintAlpha,'far boat/glint still animates')
workspace.CurrentCamera.CFrame=CFrame.new(0,20,0)
flow.Transparency=.47;glint.Transparency=.21
step(1800000101)
assert(flow.Transparency==.47 and glint.Transparency==.21,'scenery overwrote another transparency owner')
-- A late effect attribute binds without scanning the whole world per frame.
local late=modules.WorldPrimitives.part(world,'WaterfallStreakLate',Vector3.new(.1,2,.1),CFrame.new(8,15,5),Color3.new(.6,.7,.8),{transparency=.4,shadow=false})
world.DescendantAdded:Fire(late)
late:SetAttribute('FlowStart',late.CFrame);late:SetAttribute('FlowPhase',0/0);late.AttributeChanged:Fire('FlowPhase')
local lateOrigin=late.Position;step(1800000102)
assert((late.Position-lateOrigin).Magnitude==0,'nonfinite phase entered animation')
late:SetAttribute('FlowPhase',.3);late.AttributeChanged:Fire('FlowPhase');step(1800000103)
assert((late.Position-lateOrigin).Magnitude>.01,'late attributes never started motion')
-- Streaming an animated root clears its motion while keeping model readiness.
-- Its ancestor path is nested inside a whole Atomic scene. An unrelated rotor
-- must keep animating when only this root leaves.
local atomicMotion=Instance.new('Model');atomicMotion.Name='NestedAtomicMotion';atomicMotion.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;atomicMotion.Parent=world
local intermediate=Instance.new('Model');intermediate.Name='NestedMotionGroup';intermediate.Parent=atomicMotion
rotor.Parent=intermediate
world.DescendantAdded:Fire(atomicMotion);world.DescendantAdded:Fire(intermediate);world.DescendantAdded:Fire(rotor)
local peer=Instance.new('Model');peer.Name='IndependentRotor';peer.Parent=world
local peerOrigin=CFrame.new(6,15,9)
local peerPart=modules.WorldPrimitives.part(peer,'IndependentRotorRoot',Vector3.new(.2,3,.2),peerOrigin*CFrame.new(0,1.5,0),Color3.new(.3,.4,.6))
peer:SetAttribute('SpinOrigin',peerOrigin);peer:SetAttribute('SpinRate',.31)
world.DescendantAdded:Fire(peer);world.DescendantAdded:Fire(peerPart)
local peerBefore=peerPart.CFrame
world.DescendantRemoving:Fire(rotorPart);rotorPart.Parent=nil
local removedFrame=rotor:GetPivot();step(1800000104)
assert(rotor:GetPivot().r[1][1]==removedFrame.r[1][1],'missing-root model still animates')
assert(peerPart.CFrame.r[1][1]~=peerBefore.r[1][1],'removing one root stopped another model')
rotorPart.CFrame=rotorOrigin*CFrame.new(0,2,0);rotorPart.Parent=rotor
world.DescendantAdded:Fire(rotorPart);step(1800000105)
assert(rotor:GetPivot().r[1][1]~=removedFrame.r[1][1],'returned rotor root failed to bind')
assert((rotor:GetPivot():PointToObjectSpace(rotorPart.Position)-Vector3.new(0,2,0)).Magnitude<.00001,'returned root changed its rest geometry')
-- DescendantRemoving normally precedes reparenting. An already-detached root
-- is still harmless: readiness guards stop it, and whole-model cleanup clears
-- the direct model entry even when the orphan no longer appears in descendants.
rotorPart.Parent=nil;world.DescendantRemoving:Fire(rotorPart)
local detachedFrame=rotor:GetPivot();step(1800000105.1)
assert(rotor:GetPivot().r[1][1]==detachedFrame.r[1][1],'already-detached root still animated')
world.DescendantRemoving:Fire(atomicMotion);atomicMotion.Parent=nil
step(1800000105.2)
rotorPart.CFrame=rotorOrigin*CFrame.new(0,2,0);rotorPart.Parent=rotor
atomicMotion.Parent=world;world.DescendantAdded:Fire(atomicMotion)
for _,child in atomicMotion:GetDescendants() do world.DescendantAdded:Fire(child) end
step(1800000105.3)
assert((rotor:GetPivot():PointToObjectSpace(rotorPart.Position)-Vector3.new(0,2,0)).Magnitude<.00001,
 'whole nested Atomic rebind lost authored root placement')
local frozen=boat:GetPivot().Position
world.Parent=nil;world.AncestryChanged:Fire();step(1800000106)
assert((boat:GetPivot().Position-frozen).Magnitude==0,'unbound world still animates')
assert(boat.AttributeChanged:Count()==0 and flow.AttributeChanged:Count()==0,'removed world retained readiness listeners')
assert(flow.Transparency==.47 and glint.Transparency==.21,'world cleanup overwrote external opacity')
assert(lateMaterial.MaterialVariant=='' and styled.MaterialVariant=='OtherClientSurface','world cleanup lost material ownership')
world.Parent=workspace;workspace.ChildAdded:Fire(world);step(1800000107)
assert((boat:GetPivot().Position-frozen).Magnitude>.0001,'returning world did not resume animation')
assert(lateMaterial.MaterialVariant=='AnglersPlaster','returning world did not reapply a streamed material')
print('PASS production scenery: seated boat hull/dry fitted bow, fixed moorings, authored pivots, quiet flow wraps and bounded large-clock angles')
print('PASS distance limits, late/nonfinite attributes, opacity ownership, nested root/Atomic removal, nil-parent safety and world rebind')
print('PASS event-driven materials: initial/late style/tag/base material, SpecialMesh/custom-map exclusion, ownership, streaming cleanup/rebind and zero per-frame assignment')
print('Geometry/event doubles only; native Beam appearance, Roblox replication and device FPS require client checks.')
'''

STRESS = r'''
-- The supplied capture contributes the actual style/material/native-shape rows;
-- one large Atomic group deliberately stresses the whole-model removal path.
local atomic=Instance.new('Model');atomic.Name='SurfaceStreamingStress';atomic.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
local styleParts,prefilled={},{}
for index,row in stressSurfaceRows do
 assert(expectedSurfaces[row[1]]==Enum.Material[row[2]],'capture contains a material/style mismatch')
 assert(row[3]=='Block' or row[3]=='Wedge' or row[3]=='Cylinder','capture styles a non-native mesh')
 local part=Instance.new(if row[3]=='Wedge' then 'WedgePart' else 'Part')
 part.Name='CapturedSurface'..index;part.Material=Enum.Material[row[2]]
 part.CFrame=CFrame.new(index%80,20,math.floor(index/80));part.Anchored=true
 part:SetAttribute('AnglersSurfaceStyle',row[1]);part:AddTag('AnglersSurfaceStyle')
 part.MaterialVariant=if index%2==0 then row[1] else ''
 part.Parent=atomic
 table.insert(styleParts,part);prefilled[part]=index%2==0
end
assert(#styleParts>0,'stress capture has no styled native parts')
local pending=Instance.new('Part');pending.Name='PendingAtomicSurface';pending.MaterialVariant='';pending.Material=Enum.Material.Plastic
pending:AddTag('AnglersSurfaceStyle');pending.Parent=atomic
atomic.Parent=world
local function writes()
 local count=0;for _,part in styleParts do count+=surfaceWrites[part] or 0 end;return count
end
local function waitingCount()
 local count=0
 for _,part in styleParts do
  for _,signals in {part.props.attributeSignals or {},part.props.propertySignals or {}} do
   for _,changed in signals do count+=changed:Count() end
  end
 end
 return count
end
local startWrites=writes()
world.DescendantAdded:Fire(atomic)
for _,child in atomic:GetDescendants() do world.DescendantAdded:Fire(child) end
for _,part in styleParts do assert(part.MaterialVariant==part:GetAttribute('AnglersSurfaceStyle'),'atomic initial style missed') end
assert(waitingCount()==0,'ready atomic surfaces retained per-part readiness listeners')
assert(writes()-startWrites==math.ceil(#styleParts/2),'server-preapplied material was redundantly rewritten')
assert(pending:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==1 and pending:GetPropertyChangedSignal('Material'):Count()==1,
 'incomplete atomic surface was not tracked for readiness')
local beforeFrames=writes()
for _=1,12 do heartbeat:Fire(.05) end
assert(writes()==beforeFrames,'large styled world causes per-frame material assignments')
local beforeRemoval=writes();local removalStart=os.clock()
world.DescendantRemoving:Fire(atomic);atomic.Parent=nil
local removalSeconds=os.clock()-removalStart
assert(writes()-beforeRemoval==math.ceil(#styleParts/2),'atomic cleanup rewrote an already-original surface')
for _,part in styleParts do
 assert(part.MaterialVariant==(if prefilled[part] then part:GetAttribute('AnglersSurfaceStyle') else ''),'atomic cleanup lost original material')
end
assert(waitingCount()==0 and pending:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0 and pending:GetPropertyChangedSignal('Material'):Count()==0,
 'whole Atomic removal leaked temporary readiness listeners')
pending:SetAttribute('AnglersSurfaceStyle','AnglersPlaster');pending.Material=Enum.Material.Plaster
for cycle=1,3 do
 -- Simulate missing local visual state after each stream-in. Stale ownership
 -- records would mistake the reset for another writer and fail to recover.
 for _,part in styleParts do part.MaterialVariant='' end
 atomic.Parent=world;world.DescendantAdded:Fire(atomic)
 local beforeAppearance=writes()
 for _,child in atomic:GetDescendants() do world.DescendantAdded:Fire(child) end
 assert(writes()-beforeAppearance==#styleParts,'atomic stream-in failed to bind fresh surface ownership')
 assert(waitingCount()==0,'atomic stream-in retained readiness listeners')
 for _,part in styleParts do assert(part.MaterialVariant==part:GetAttribute('AnglersSurfaceStyle'),'atomic restream style missed') end
 local beforeLeaving=writes()
 world.DescendantRemoving:Fire(atomic);atomic.Parent=nil
 assert(writes()-beforeLeaving==#styleParts,'atomic restream cleanup is incomplete')
 for _,part in styleParts do assert(part.MaterialVariant=='','atomic restream retained stale surface state') end
end
local lateMesh=surfacePart('LateSpecialMesh',Enum.Material.Fabric)
lateMesh:SetAttribute('AnglersSurfaceStyle','AnglersCanvas');lateMesh:AddTag('AnglersSurfaceStyle')
assert(lateMesh.MaterialVariant=='AnglersCanvas','late mesh fixture never acquired its original surface')
local sphere=Instance.new('SpecialMesh');sphere.MeshType=Enum.MeshType.Sphere;sphere.Parent=lateMesh
world.DescendantAdded:Fire(sphere)
assert(lateMesh.MaterialVariant=='','late SpecialMesh retained a client-owned Part surface')
local invalidLate=surfacePart('InvalidReadiness',Enum.Material.Plastic);invalidLate:AddTag('AnglersSurfaceStyle')
invalidLate:SetAttribute('AnglersSurfaceStyle','NotASupportedSurface')
assert(invalidLate.MaterialVariant=='' and invalidLate:GetAttributeChangedSignal('AnglersSurfaceStyle'):Count()==0
 and invalidLate:GetPropertyChangedSignal('Material'):Count()==0,'invalid late style leaked readiness listeners')
assert(surfaceAdded:Count()==1 and surfaceRemoved:Count()==1,'large stream cycles multiplied collection listeners')
print('PASS material streaming stress:',#styleParts,'captured native surfaces; mixed pre-applied/local state; four whole Atomic removals; zero ready-part listeners or frame writes')
print(string.format('Offline event-double Atomic cleanup %.4fs; this is not Roblox device performance.',removalSeconds))
'''


def check(luau: str, capture: Path | None = None) -> None:
    program = (ROOT / 'tools/preview_roblox.luau').read_text()
    for name, source in (
        ('WorldPrimitives', 'src/server/WorldPrimitives.luau'),
        ('WorldNature', 'src/server/WorldNature.luau'),
        ('WorldLayout', 'src/server/WorldLayout.luau'),
        ('WorldLandscaping', 'src/server/WorldLandscaping.luau'),
    ):
        program += f'\nmodules.{name}=(function()\n' + (ROOT / source).read_text() + '\nend)()\n'
        program += f'local token_{name}=Instance.new("ModuleScript");token_{name}.Name="{name}";token_{name}.Parent=shared\n'
    program += PREPARE
    styles = json.loads((ROOT / 'tools/world_materials.json').read_text())['variants']
    program += '\nlocal expectedSurfaces={' + ','.join(
        f'[{json.dumps(style["name"])}]=Enum.Material.{style["base_material"]}'
        for style in styles) + '}\n'
    program += '\nlocal scenery=(function()\n' + (ROOT / 'src/client/WorldScenery.luau').read_text() + '\nend)()\n'
    program += CHECK
    if capture:
        parts = json.loads(capture.read_text())['parts']
        rows = [(p['surfaceStyle'], p['material'], p['shape']) for p in parts
                if p.get('surfaceTagged') and p.get('surfaceStyle')]
        program += '\nlocal stressSurfaceRows={' + ','.join(
            '{' + ','.join(json.dumps(value) for value in row) + '}' for row in rows) + '}\n'
        program += STRESS
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / 'check_scenery.luau'
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True)
    parser.add_argument('--capture', type=Path, help='Optional production geometry capture for whole-Atomic material streaming stress')
    args = parser.parse_args()
    check(args.luau, args.capture)
