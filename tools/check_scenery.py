#!/usr/bin/env python3
"""Exercise production scenery motion with geometry/events, not the Roblox engine.

Checks boat moorings, authored pivots, quiet waterfall wraps, distance limits,
large-clock rotor angles and streamed root recovery. No rendering/FPS claim.
"""
import argparse
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
 if key=='AttributeChanged' or key=='ChildAdded' or key=='DescendantAdded' or key=='DescendantRemoving' or key=='AncestryChanged' then
  if not self.props[key] then self.props[key]=signal() end
  return self.props[key]
 end
 return originalIndex(self,key)
end
function methods:IsDescendantOf(ancestor)
 local node=self.Parent
 while node do if node==ancestor then return true end;node=node.Parent end
 return false
end
function methods:FindFirstChildWhichIsA(class,recursive)
 for _,node in (if recursive then self:GetDescendants() else self:GetChildren()) do
  if node:IsA(class) then return node end
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
game.GetService=function(self,name) return if name=='RunService' then {Heartbeat=heartbeat} else oldGetService(self,name) end
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
world.DescendantRemoving:Fire(rotorPart);rotorPart.Parent=nil
local removedFrame=rotor:GetPivot();step(1800000104)
assert(rotor:GetPivot().r[1][1]==removedFrame.r[1][1],'missing-root model still animates')
rotorPart.CFrame=rotorOrigin*CFrame.new(0,2,0);rotorPart.Parent=rotor
world.DescendantAdded:Fire(rotorPart);step(1800000105)
assert(rotor:GetPivot().r[1][1]~=removedFrame.r[1][1],'returned rotor root failed to bind')
assert((rotor:GetPivot():PointToObjectSpace(rotorPart.Position)-Vector3.new(0,2,0)).Magnitude<.00001,'returned root changed its rest geometry')
local frozen=boat:GetPivot().Position
world.Parent=nil;world.AncestryChanged:Fire();step(1800000106)
assert((boat:GetPivot().Position-frozen).Magnitude==0,'unbound world still animates')
assert(boat.AttributeChanged:Count()==0 and flow.AttributeChanged:Count()==0,'removed world retained readiness listeners')
assert(flow.Transparency==.47 and glint.Transparency==.21,'world cleanup overwrote external opacity')
world.Parent=workspace;workspace.ChildAdded:Fire(world);step(1800000107)
assert((boat:GetPivot().Position-frozen).Magnitude>.0001,'returning world did not resume animation')
print('PASS production scenery: fixed moorings, authored pivots, quiet flow wraps and bounded large-clock angles')
print('PASS distance limits, late/nonfinite attributes, opacity ownership, streamed root and world rebind')
print('Geometry/event doubles only; native Beam appearance, Roblox replication and device FPS require client checks.')
'''


def check(luau: str) -> None:
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
    program += '\nlocal scenery=(function()\n' + (ROOT / 'src/client/WorldScenery.luau').read_text() + '\nend)()\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / 'check_scenery.luau'
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True)
    check(parser.parse_args().luau)
