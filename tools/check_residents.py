#!/usr/bin/env python3
"""Exercise production residents with geometry/event test doubles, not Roblox.

Usage: python tools/check_residents.py --luau /path/to/luau
Checks source-generated geometry, finite poses, route bounds, late attributes,
camera LOD and streaming cleanup. Rendering, replication and Roblox engine
behavior still require Studio. The release builder does not depend on this tool.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local world=Instance.new("Folder"); world.Name="MolnfiskarnaPrototype"; world.Parent=workspace
local group=modules.WorldResidents.populate(world)
local count, shadows=0,0
for _,part in world:GetDescendants() do
 if part:IsA("BasePart") then
  count+=1
  if part.CastShadow then shadows+=1 end
  assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"actor physics enabled")
 end
end
-- Preserve the 414-part cast/job-prop allowance, with at most ten additional
-- cosmetic pieces on each of the six existing gulls.
assert(count<=414+6*10,"resident scenery exceeds the cast, job-prop and bounded gull-detail budget")
assert(shadows>30 and shadows<100,"missing body contact shadows or excessive small shadow casters")
local residentCount, birdCount, butterflyCount, schoolCount=0,0,0,0
local gullWings={}
-- Native solid geometry checks do not depend on how an offline renderer scales
-- Ball parts. For a WedgePart the solid lies below y=(height/depth)*z.
local function inSolid(part,worldPoint)
 local point=part.CFrame:PointToObjectSpace(worldPoint)
 local half=part.Size*.5
 if math.abs(point.X)>half.X+1e-5 or math.abs(point.Y)>half.Y+1e-5 or math.abs(point.Z)>half.Z+1e-5 then return false end
 return not part:IsA("WedgePart") or point.Y<=point.Z*part.Size.Y/part.Size.Z+1e-5
end
for _,actor in group:GetChildren() do
 local kind=actor:GetAttribute("AmbientKind")
 assert(actor.ModelStreamingMode=="Atomic" and actor.PrimaryPart,"incomplete streamed actor")
 if kind=="Resident" then residentCount+=1 end
 if kind=="Gull" then
  birdCount+=1
  local parts=0
  for _,part in actor:GetDescendants() do if part:IsA("BasePart") then parts+=1 end end
  assert(parts<=19,"a gull exceeds its original nine parts plus ten detail pieces")
  for _,name in {"WingLeft","WingRight"} do
   local wing=actor:FindFirstChild(name)
   assert(wing and wing.PrimaryPart,"missing gull wing pivot")
   local side=if name=="WingLeft" then -1 else 1
   local white,coverts,tip,primary=wing:FindFirstChild("SweptWing"),wing:FindFirstChild("GrayCoverts"),wing:FindFirstChild("InkWingtip"),wing:FindFirstChild("TrailingPrimary")
   assert(white:IsA("WedgePart") and tip:IsA("WedgePart"),"gull wing outline must use solid native prisms")
   assert(white.Size.X>=.18 and white.Size.Y>=1.6 and white.Size.Z>=.9,"gull wing lacks visible thickness, span or chord")
   local function at(x,y,z) return actor:GetPivot():PointToWorldSpace(Vector3.new(side*x,y,z)) end
   assert(inSolid(white,at(.26,.11,.20)),"gull wing does not overlap its shoulder")
   assert(inSolid(white,at(1.40,.11,.50)) and inSolid(tip,at(1.40,.11,.50)),"black wingtip does not join the white flight feathers")
   assert(inSolid(tip,at(1.76,.11,.68)) and inSolid(primary,at(1.76,.11,.68)),"trailing primary floats beside its wingtip")
   assert(inSolid(white,at(.85,.215,.25)) and inSolid(coverts,at(.85,.215,.25)),"gray coverts float above the white wing")
   for _,detail in {"SweptWing","GrayCoverts","InkWingtip","TrailingPrimary"} do
    local part=wing:FindFirstChild(detail)
    assert(part and part:IsA("BasePart"),"gull feather layer is detached from its wing joint")
    assert(part:IsA("WedgePart") or part.Shape==Enum.PartType.Block,"gull wing surface depends on flattened Ball rendering")
    table.insert(gullWings,{actor=actor,wing=wing,part=part,rest=wing:GetPivot():Inverse()*part.CFrame})
   end
  end
 end
 if kind=="Butterfly" then butterflyCount+=1 end
 if kind=="FishSchool" then schoolCount+=1 end
end
assert(residentCount==7 and birdCount==6 and butterflyCount==6 and schoolCount==2,"actor coverage")
print("Production resident generation:",count,"parts,",#group:GetChildren(),"atomic actors; all anchored and noncolliding")
local function signal()
 local callbacks={}
 return {Connect=function(_,callback)
   table.insert(callbacks,callback)
   return {Disconnect=function() local index=table.find(callbacks,callback); if index then table.remove(callbacks,index) end end}
  end,
  Fire=function(_,...) for _,callback in table.clone(callbacks) do callback(...) end end,
  Count=function() return #callbacks end}
end
local originalIndex=mt.__index
local primaryPartReads=0
mt.__index=function(self,key)
 if key=="PrimaryPart" then primaryPartReads+=1 end
 if key=="AttributeChanged" or key=="ChildAdded" or key=="DescendantAdded" or key=="DescendantRemoving" or key=="AncestryChanged" then
  if not self.props[key] then self.props[key]=signal() end
  return self.props[key]
 end
 return originalIndex(self,key)
end
function methods:GetPropertyChangedSignal(key)
 local name="Signal_"..key
 if not self.props[name] then self.props[name]=signal() end
 return self.props[name]
end
function methods:IsDescendantOf(ancestor)
 local node=self.Parent
 while node do if node==ancestor then return true end; node=node.Parent end
 return false
end
local realTypeof=typeof
local typeof=function(value)
 if type(value)=="table" then
  if getmetatable(value)==V then return "Vector3" end
  if getmetatable(value)==CF then return "CFrame" end
 end
 return realTypeof(value)
end
-- The simple capture shim uses a transpose for matrix inverse. Set each final
-- pivot exactly, matching PivotTo's target, to avoid numerical error multiplying
-- over hundreds of synthetic animation steps. This is not an engine emulator.
local capturePivot=methods.PivotTo
function methods:PivotTo(cf)
 capturePivot(self,cf)
 if self.PrimaryPart then self.PrimaryPart.CFrame=cf end
end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
 return nil
end
local players=Instance.new("Players")
local localPlayer=Instance.new("Player")
players.LocalPlayer=localPlayer
local character=Instance.new("Model")
local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Parent=character
local humanoid=Instance.new("Humanoid"); humanoid.Health=100; humanoid.Parent=character
local now=0
function methods:GetServerTimeNow() return now end
local heartbeat=signal()
local run={Heartbeat=heartbeat}
local previousService=game.GetService
game.GetService=function(self,name)
 if name=="RunService" then return run end
 if name=="Players" then return players end
 return previousService(self,name)
end
workspace.CurrentCamera={CFrame=CFrame.new(0,20,0)}
local lateActor=group:FindFirstChild("Resident_Milo")
lateActor:SetAttribute("AmbientKind",nil)
local lateJoint=lateActor:FindFirstChild("ArmRight")
local savedRest=lateJoint:GetAttribute("AmbientRest")
lateJoint:SetAttribute("AmbientRest",nil)
local lateEye=lateActor:FindFirstChild("HeadPose"):FindFirstChild("Eye")
local savedEyeSize=lateEye:GetAttribute("AmbientEyeSize")
lateEye:SetAttribute("AmbientEyeSize",nil)
'''

CHECK = r'''
animation.start()
animation.start()
assert(heartbeat:Count()==1,"duplicate animation subscriptions")
local steps=0
local gullMinRoll,gullMaxRoll=math.huge,-math.huge
local function step(time)
 now=time; heartbeat:Fire(0.05); steps+=1
 for _,part in group:GetDescendants() do
  if part:IsA("BasePart") then
   local p=part.CFrame.Position
   assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<10000 and math.abs(p.Y)<10000 and math.abs(p.Z)<10000,"nonfinite pose")
  end
 end
 for _,sample in gullWings do
  if not sample.wing.PrimaryPart then continue end
  local offset=sample.wing:GetPivot():Inverse()*sample.part.CFrame
  assert((offset.Position-sample.rest.Position).Magnitude<.00001,"gull feather position drifted during a flap")
  assert((offset.RightVector-sample.rest.RightVector).Magnitude<.00001 and (offset.UpVector-sample.rest.UpVector).Magnitude<.00001,"gull feather orientation drifted during a flap")
  if sample.wing.Name=="WingRight" then
   local localCf=sample.actor:GetPivot():Inverse()*sample.wing:GetPivot()
   local angle=math.atan2(localCf.r[2][1],localCf.r[1][1])
   gullMinRoll=math.min(gullMinRoll,angle);gullMaxRoll=math.max(gullMaxRoll,angle)
  end
 end
end
local lateBefore=lateActor:GetPivot().Position
step(0.01)
assert((lateActor:GetPivot().Position-lateBefore).Magnitude==0,"actor animated before required attributes")
lateActor:SetAttribute("AmbientKind","Resident"); lateActor.AttributeChanged:Fire("AmbientKind")
lateJoint:SetAttribute("AmbientRest",savedRest); lateJoint.AttributeChanged:Fire("AmbientRest")
lateEye:SetAttribute("AmbientEyeSize",savedEyeSize); lateEye.AttributeChanged:Fire("AmbientEyeSize")
local lateBlinkObserved=false
for i=1,600 do
 step(i*0.05)
 if lateEye.Size.Y<savedEyeSize.Y*.2 then lateBlinkObserved=true end
end
assert(lateBlinkObserved,"eye metadata arriving after its part never activated blinking")
local relativeArm=lateActor:GetPivot():Inverse()*lateJoint:GetPivot()
assert(math.abs(relativeArm.r[2][3])>.015,"late joint failed to acquire its restrained working pose")
local workspaces=world:FindFirstChild("ResidentWorkspaces")
local hull=workspaces:FindFirstChild("MiloWorkspace"):FindFirstChild("HalfPaintedHull")
local bristles=lateJoint:FindFirstChild("BrushBristles")
assert(math.abs(bristles.Position.Y-hull.Position.Y)<.2 and (bristles.Position-hull.Position).Magnitude<.7,"Milo paints empty air instead of his workpiece")
local juniper=group:FindFirstChild("Resident_Juniper")
assert(juniper:GetAttribute("AmbientOrigin").Position.Z>-6 and juniper:GetAttribute("AmbientOrigin").Position.Y==12.15,"server remains inside the cafe wall or below its porch")
local animatedHand=lateJoint:FindFirstChild("MittenHand")
local handOffset=animatedHand.Position-lateJoint:GetPivot().Position
assert(handOffset.Magnitude>0.9 and handOffset.Magnitude<1.1,"joint geometry drift")
local walker=group:FindFirstChild("Resident_Sunny")
local walkerMoved=walker:GetPivot().Position-walker:GetAttribute("AmbientOrigin").Position
assert(walkerMoved.Magnitude>0.5 and walkerMoved.Magnitude<30,"walking route")
workspace.CurrentCamera.CFrame=CFrame.new(10000,10000,10000)
local frozen=walker:GetPivot().Position
step(31)
assert((walker:GetPivot().Position-frozen).Magnitude==0,"far actor animated despite LOD")
workspace.CurrentCamera.CFrame=CFrame.new(-240,32,20)
for i=1,200 do step(31+i*0.05) end
workspace.CurrentCamera.CFrame=CFrame.new(-340,12,-210)
for i=1,200 do step(41+i*0.05) end
for _,actor in group:GetChildren() do
 if actor:GetAttribute("AmbientKind")=="Resident" then
  local base=actor:GetAttribute("AmbientOrigin").Position
  assert(math.abs(actor:GetPivot().Position.Y-base.Y)<0.2,"resident detached from ground")
 end
end
-- Simulate the hierarchy notifications for a complete atomic stream-out/in.
local removedPivot=lateActor:GetPivot().Position
world.DescendantRemoving:Fire(lateActor)
for _,child in lateActor:GetDescendants() do world.DescendantRemoving:Fire(child) end
lateActor.Parent=nil
workspace.CurrentCamera.CFrame=CFrame.new(45,18,-6)
step(52)
assert((lateActor:GetPivot().Position-removedPivot).Magnitude==0,"removed actor still animated")
assert(lateActor.AttributeChanged:Count()==0 and lateJoint.AttributeChanged:Count()==0,"removed actor retained listeners")
lateActor.Parent=group
world.DescendantAdded:Fire(lateActor)
for _,child in lateActor:GetDescendants() do world.DescendantAdded:Fire(child) end
step(53)
assert((lateActor:GetPivot().Position-removedPivot).Magnitude>0.001,"returning actor failed to resume")
local worldFrozen=lateActor:GetPivot().Position
world.Parent=nil; world.AncestryChanged:Fire()
step(54)
assert((lateActor:GetPivot().Position-worldFrozen).Magnitude==0,"removed world still animated")
assert(lateActor.AttributeChanged:Count()==0,"world unbind retained actor listeners")
assert(lateEye.AttributeChanged:Count()==0,"world unbind retained late-eye readiness listeners")
world.Parent=workspace; workspace.ChildAdded:Fire(world)
step(55)
assert((lateActor:GetPivot().Position-worldFrozen).Magnitude>0.001,"returning world failed to resume")
assert(lateEye.AttributeChanged:Count()==1,"returning world duplicated or lost its eye readiness listener")
-- Reactions follow a living local character, not a free camera. A short greeting
-- uses the empty hand and has both a cooldown and a leave/re-enter requirement.
local function roll(joint,actor)
 local localCf=actor:GetPivot():Inverse()*joint:GetPivot()
 return math.atan2(localCf.r[2][1],localCf.r[1][1])
end
local freeHand=lateActor:FindFirstChild("ArmLeft")
workspace.CurrentCamera.CFrame=CFrame.new(45,18,-6)
localPlayer.Character=character
root.Position=Vector3.new(1000,15,1000)
for index=1,12 do step(55+index*.05) end
assert(math.abs(roll(freeHand,lateActor))<.3,"free camera provoked a visitor greeting")
root.Position=lateActor:GetAttribute("AmbientOrigin"):PointToWorldSpace(Vector3.new(4,3,-7))
for index=1,17 do step(55.6+index*.05) end
assert(math.abs(roll(freeHand,lateActor))>1.5,"nearby visitor did not receive a brief free-hand greeting")
local head=lateActor:FindFirstChild("HeadPose")
local look=lateActor:GetPivot():Inverse()*head:GetPivot()
local yaw=math.atan2(-look.LookVector.X,-look.LookVector.Z)
assert(yaw<-.3 and yaw>-.55,"head does not smoothly turn toward the real visitor")
lateActor.AttributeChanged:Fire("AmbientPeriod")
step(56.5)
assert(math.abs(roll(freeHand,lateActor))>1.2,"a streamed refresh reset a greeting in progress")
for index=1,40 do step(56.5+index*.1) end
assert(math.abs(roll(freeHand,lateActor))<.3,"greeting never returned to the work pose")
root.Position=Vector3.new(1000,15,1000);step(60.6)
root.Position=lateActor:GetAttribute("AmbientOrigin"):PointToWorldSpace(Vector3.new(4,3,-7));step(60.7)
assert(math.abs(roll(freeHand,lateActor))<.3,"quick re-entry bypassed the greeting cooldown")
for index=1,25 do step(60.7+index*.5) end
assert(math.abs(roll(freeHand,lateActor))<.3,"standing beside a resident retriggered repeated waving")
root.Position=Vector3.new(1000,15,1000);step(74)
root.Position=lateActor:GetAttribute("AmbientOrigin"):PointToWorldSpace(Vector3.new(4,3,-7))
for index=1,17 do step(74+index*.05) end
assert(math.abs(roll(freeHand,lateActor))>1.5,"a later visit could not trigger another greeting")
humanoid.Health=0
for index=1,50 do step(75+index*.05) end
assert(math.abs(roll(freeHand,lateActor))<.3,"dead local character kept a greeting alive")
localPlayer.Character=nil
-- Blinks restore authored dimensions even if attributes arrive mid-blink.
local eye=head:FindFirstChild("Eye")
local openSize=eye:GetAttribute("AmbientEyeSize")
local blinkTime=(4.6+.2*.13)*20-.2+.08
step(blinkTime)
assert(eye.Size.Y<openSize.Y*.2,"eyes never close during a blink")
lateActor.AttributeChanged:Fire("AmbientPeriod");step(blinkTime+.02)
step(blinkTime+.2)
assert(math.abs(eye.Size.Y-openSize.Y)<1e-6,"blink refresh adopted a squashed eye as its new rest size")
-- Stream a large unrelated decoration batch. Removal must not inspect every
-- resident joint merely because a plank or leaf left the generated world.
local decorations={}
for index=1,500 do
 local part=Instance.new("Part");part.Name="UnrelatedStreamedPlank";part.Parent=world
 table.insert(decorations,part)
end
local readsBefore=primaryPartReads
for _,part in decorations do world.DescendantRemoving:Fire(part);part.Parent=nil end
local decorationRootReads=primaryPartReads-readsBefore
assert(decorationRootReads<20,"unrelated scenery removal scanned all resident joint roots: "..decorationRootReads)
-- Captain Pip's rod moves, but its line end is tied to the bobber on native water.
local captain=group:FindFirstChild("Resident_CaptainPip")
local line=captain:FindFirstChild("FineFishingLine")
local bobber=captain:FindFirstChild("ResidentBobber")
local rod=captain:FindFirstChild("ArmRight"):FindFirstChild("BambooFishingRod")
workspace.CurrentCamera.CFrame=CFrame.new(8,18,127)
for index=1,100 do
 step(100+index*.05)
 local endPoint=line.Position+line.CFrame.RightVector*line.Size.X*.5
 local startPoint=line.Position-line.CFrame.RightVector*line.Size.X*.5
 local tip=rod.Position+rod.CFrame.RightVector*rod.Size.X*.5
 assert((endPoint-bobber.Position).Magnitude<.0001 and (startPoint-tip).Magnitude<.0001,"fishing line detached from its rod or water bobber")
 assert(math.abs(bobber.Position.Y-8.2)<=.026,"resident bobber hangs above or below the lagoon")
end
-- A detached cached prop must stop driving the line even if notification arrives
-- after reparenting. The resident may continue its own work animation.
rod.Parent=workspace;world.DescendantRemoving:Fire(rod)
local orphanedLine=captain:GetPivot():Inverse()*line.CFrame
step(105.2)
local retainedLine=captain:GetPivot():Inverse()*line.CFrame
assert((retainedLine.Position-orphanedLine.Position).Magnitude<.00001
 and (retainedLine.RightVector-orphanedLine.RightVector).Magnitude<.00001,
 "cached rod outside its resident kept driving the fishing line")
rod.Parent=captain:FindFirstChild("ArmRight");world.DescendantAdded:Fire(rod)
-- Juniper's loaded tray remains level while the empty hand acknowledges a customer.
humanoid.Health=100;localPlayer.Character=character
workspace.CurrentCamera.CFrame=CFrame.new(-44,18,-3)
root.Position=juniper:GetAttribute("AmbientOrigin"):PointToWorldSpace(Vector3.new(3,3,-6))
for index=1,20 do step(106+index*.05) end
local tray=juniper:FindFirstChild("ArmRight"):FindFirstChild("LemonadeTray")
assert(math.abs(tray.CFrame.RightVector:Dot(Vector3.yAxis))>.999,"server tips the loaded tray during a greeting")
assert(math.abs(roll(juniper:FindFirstChild("ArmLeft"),juniper))>1.2,"server greeted with the tray hand or did not greet")
localPlayer.Character=nil
-- Gardener pours into the actual authored patch, and stops between tending cycles.
workspace.CurrentCamera.CFrame=CFrame.new(-229,32,30)
local gardener=group:FindFirstChild("Resident_Petal")
local visible,dry=0,0
for index=1,200 do
 step(115+index*.05)
 local drop=gardener:FindFirstChild("WateringDrop1")
 if drop.Transparency<1 then
  visible+=1
  assert(drop.Position.Y>=28.45 and drop.Position.Y<31,"watering droplets miss the planted ground")
 else dry+=1 end
end
assert(visible>10 and dry>30,"gardener waters forever or never waters its patch")
-- Client startup, death and camera replacement can temporarily remove either
-- source of attention. Neither case may crash or animate against a stale root.
local savedCamera=workspace.CurrentCamera
local still=lateActor:GetPivot().Position
workspace.CurrentCamera=nil
step(126)
assert((lateActor:GetPivot().Position-still).Magnitude==0,"missing camera did not pause resident animation")
workspace.CurrentCamera=savedCamera
players.LocalPlayer=nil
step(126.1)
players.LocalPlayer=localPlayer
workspace.CurrentCamera.CFrame=CFrame.new(45,18,-6)
-- An individual actor root may leave before the rest of an Atomic model. Its
-- readiness listener must stop movement and recover when that root returns.
local actorRoot=lateActor.PrimaryPart
world.DescendantRemoving:Fire(actorRoot)
actorRoot.Parent=nil
local rootFrozen=actorRoot.CFrame.Position
step(126.9)
assert((actorRoot.CFrame.Position-rootFrozen).Magnitude==0,"stale PrimaryPart reference moved a detached actor root")
lateActor.PrimaryPart=nil
lateActor:GetPropertyChangedSignal("PrimaryPart"):Fire()
world.DescendantRemoving:Fire(actorRoot)
actorRoot.Parent=nil
step(127)
assert((actorRoot.CFrame.Position-rootFrozen).Magnitude==0,"unloaded actor root was still moved")
actorRoot.Parent=lateActor
lateActor.PrimaryPart=actorRoot
lateActor:GetPropertyChangedSignal("PrimaryPart"):Fire()
world.DescendantAdded:Fire(actorRoot)
step(128)
assert((actorRoot.Position-rootFrozen).Magnitude>.001,"individual actor root did not resume after streaming")
-- A gull streams as one Atomic model, including both nested wing models. Its
-- complete removal must release listeners and its return must resume the flock.
local gull=group:FindFirstChild("IslandGull_1")
local leftWing,rightWing=gull:FindFirstChild("WingLeft"),gull:FindFirstChild("WingRight")
workspace.CurrentCamera.CFrame=gull:GetAttribute("AmbientOrigin")
step(129)
local gullFrozen=gull:GetPivot().Position
world.DescendantRemoving:Fire(gull)
gull.Parent=nil
step(130)
assert((gull:GetPivot().Position-gullFrozen).Magnitude==0,"streamed-out gull still moves")
assert(gull.AttributeChanged:Count()==0 and leftWing.AttributeChanged:Count()==0 and rightWing.AttributeChanged:Count()==0,"streamed-out gull retained animation listeners")
gull.Parent=group
world.DescendantAdded:Fire(gull)
for _,child in gull:GetDescendants() do world.DescendantAdded:Fire(child) end
step(131)
assert((gull:GetPivot().Position-gullFrozen).Magnitude>.001,"returning gull did not resume its flight")
-- PrimaryPart can be assigned after its descendants arrive. The opposite wing
-- and body keep moving, then both shoulders resume their authored local poses.
local shoulder=leftWing.PrimaryPart
leftWing.PrimaryPart=nil
leftWing:GetPropertyChangedSignal("PrimaryPart"):Fire()
local rightBefore=rightWing:GetPivot().Position
step(132)
assert((rightWing:GetPivot().Position-rightBefore).Magnitude>.001,"one unready wing froze the rest of its gull")
leftWing.PrimaryPart=shoulder
leftWing:GetPropertyChangedSignal("PrimaryPart"):Fire()
step(133)
for _,wing in {leftWing,rightWing} do
 local localShoulder=gull:GetPivot():PointToObjectSpace(wing:GetPivot().Position)
 assert((localShoulder-wing:GetAttribute("AmbientRest").Position).Magnitude<.00001,"gull shoulder did not recover after a late PrimaryPart")
end
assert(gullMinRoll<-.48 and gullMaxRoll>.60,"gull detail checks did not exercise both flap extremes")
print("Production animation:",steps,"finite steps; late attributes, stable jobs, real-character greetings/cooldown, blinks, water endpoints, ground contact, LOD and streaming recovery passed")
print("Native gull wing prisms remained joined and rigid through both flap extremes and gull streaming recovery:",gullMinRoll,gullMaxRoll)
print("Resident streaming audit: late eye metadata, whole-model listener cleanup, detached props/roots and 500 unrelated removals with",decorationRootReads,"joint-root reads passed")
print("These are geometry/event-double checks; Roblox rendering and engine behavior require Studio.")
'''


def check(luau: str) -> None:
    program = (ROOT / "tools/preview_roblox.luau").read_text()
    for name, source in [
        ("WorldPrimitives", "src/server/WorldPrimitives.luau"),
        ("WorldResidents", "src/server/WorldResidents.luau"),
    ]:
        program += "\nmodules." + name + "=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token_{name}=Instance.new("ModuleScript"); token_{name}.Name="{name}"; token_{name}.Parent=shared\n'
    program += PREPARE
    program += "\nlocal animation=(function()\n" + (ROOT / "src/client/ResidentPresentation.luau").read_text() + "\nend)()\n"
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_residents.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
