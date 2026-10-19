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
for _,part in group:GetDescendants() do
 if part:IsA("BasePart") then
  count+=1
  if part.CastShadow then shadows+=1 end
  assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"actor physics enabled")
 end
end
assert(count<=450,"resident scenery exceeds part budget")
assert(shadows>30 and shadows<100,"missing body contact shadows or excessive small shadow casters")
local residentCount, birdCount, butterflyCount, schoolCount=0,0,0,0
for _,actor in group:GetChildren() do
 local kind=actor:GetAttribute("AmbientKind")
 assert(actor.ModelStreamingMode=="Atomic" and actor.PrimaryPart,"incomplete streamed actor")
 if kind=="Resident" then residentCount+=1 end
 if kind=="Gull" then birdCount+=1 end
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
mt.__index=function(self,key)
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
local now=0
function methods:GetServerTimeNow() return now end
local heartbeat=signal()
local run={Heartbeat=heartbeat}
local previousService=game.GetService
game.GetService=function(self,name) if name=="RunService" then return run end; return previousService(self,name) end
workspace.CurrentCamera={CFrame=CFrame.new(0,20,0)}
local lateActor=group:FindFirstChild("Resident_Milo")
lateActor:SetAttribute("AmbientKind",nil)
local lateJoint=lateActor:FindFirstChild("ArmRight")
local savedRest=lateJoint:GetAttribute("AmbientRest")
lateJoint:SetAttribute("AmbientRest",nil)
'''

CHECK = r'''
animation.start()
animation.start()
assert(heartbeat:Count()==1,"duplicate animation subscriptions")
local steps=0
local function step(time)
 now=time; heartbeat:Fire(0.05); steps+=1
 for _,part in group:GetDescendants() do
  if part:IsA("BasePart") then
   local p=part.CFrame.Position
   assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<10000 and math.abs(p.Y)<10000 and math.abs(p.Z)<10000,"nonfinite pose")
  end
 end
end
local lateBefore=lateActor:GetPivot().Position
step(0.01)
assert((lateActor:GetPivot().Position-lateBefore).Magnitude==0,"actor animated before required attributes")
lateActor:SetAttribute("AmbientKind","Resident"); lateActor.AttributeChanged:Fire("AmbientKind")
lateJoint:SetAttribute("AmbientRest",savedRest); lateJoint.AttributeChanged:Fire("AmbientRest")
for i=1,600 do step(i*0.05) end
local relativeArm=lateActor:GetPivot():Inverse()*lateJoint:GetPivot()
assert(math.abs(relativeArm.r[2][3])>0.15,"late joint failed to acquire working pose")
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
world.Parent=workspace; workspace.ChildAdded:Fire(world)
step(55)
assert((lateActor:GetPivot().Position-worldFrozen).Magnitude>0.001,"returning world failed to resume")
print("Production animation:",steps,"finite steps; late attributes, joint stability, routes, ground contact, camera LOD, streaming cleanup/rebind passed")
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
