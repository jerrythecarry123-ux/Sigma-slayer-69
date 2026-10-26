#!/usr/bin/env python3
"""Drive the production fishing presentation through server-approved state.

Checks cast/bite separation, cosmetic bounds, rod joints and lifecycle cleanup.
This is not a native Roblox animation, sound or input test.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SETUP = r'''
-- Native Model:PivotTo caches authored offsets; pin its primary frame exactly so
-- the simple spatial double does not amplify transpose roundoff across frames.
local originalPivot=methods.PivotTo
function methods:PivotTo(cf)
 originalPivot(self,cf)
 if self.PrimaryPart then self.PrimaryPart.CFrame=cf end
end
local originalFind=methods.FindFirstChild
function methods:FindFirstChild(name,recursive)
 local found=originalFind(self,name)
 if found or not recursive then return found end
 for _,child in self.children do local result=child:FindFirstChild(name,true);if result then return result end end
 return nil
end
humanoid.Health=100
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=CFrame.new(0,5,0);root.Parent=character
local hand=Instance.new('Part');hand.Name='RightHand';hand.CFrame=CFrame.new(1.5,5,-.3);hand.Parent=character
local right=Instance.new('Motor6D');right.Name='RightShoulder';right.Transform=CFrame.Angles(.15,.1,0);right.Parent=character
local left=Instance.new('Motor6D');left.Name='LeftShoulder';left.Transform=CFrame.Angles(.05,0,.1);left.Parent=character
local baseRight,baseLeft=right.Transform,left.Transform
local players={[101]=player}
services.Players.PlayerRemoving=signal()
services.Players.GetPlayerByUserId=function(_,id)return players[id] end
local playerScans=0
services.Players.GetPlayers=function()playerScans+=1;return {player}end
services.Debris={AddItem=function(_,object,duration)task.delay(duration,function()if not object.destroyed then object:Destroy()end end)end}
function methods:GetServerTimeNow()return now end
local playCalls={}
audio.play=function(name,pitch,parent,volume)table.insert(playCalls,{name=name,at=now,pitch=pitch,volume=volume})end
local sceneryStarts=0
modules.WorldScenery={start=function()sceneryStarts+=1 end}
local token=Instance.new('ModuleScript');token.Name='WorldScenery';token.Parent=shared
'''
CHECK = r'''
local presentation=modules.FishingPresentation.new(audio)
local effects=find(workspace,'CloudAnglersEffects')
local function rig()return find(effects,'FishingRod_101')end
local function near(a,b)return (a-b).Magnitude<.000001 end
local function validFrames()
 for _,p in effects:GetDescendants() do if p:IsA('BasePart') then
  assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch,'presentation created a gameplay obstruction')
  for _,axis in {p.CFrame.RightVector,p.CFrame.UpVector,p.CFrame.LookVector} do assert(math.abs(axis.Magnitude-1)<.00001,'presentation joint transform lost unit axis: '..p.Name..' '..axis.Magnitude)end
  assert(math.abs(p.CFrame.RightVector:Dot(p.CFrame.UpVector))<.00001,'presentation joint axes are not orthogonal')
  assert(p.Position.Magnitude<2000,'presentation geometry escaped')
 end end
end
presentation.apply(101,{phase='Idle',catches=0,rodLevel=0})
frame(.1);assert(not rig(),'idle player received a rod')
local castAt=now
local target=Vector3.new(0,1,-14)
local waiting={phase='Waiting',catches=0,rodLevel=0,attemptId=1,castAt=castAt,castDuration=.65,readyAt=castAt+2.5,castTarget=target,difficulty=.1,behavior='Drift'}
presentation.apply(101,waiting);assert(rig(),'active cast did not receive rod')
local bobber=find(effects,'Bobber_101')
local flight={}
for i=1,65 do frame(.01);table.insert(flight,bobber.Position);validFrames()end
assert(near(bobber.Position,target+Vector3.new(0,math.sin(now*3)*.09,0)),'bobber did not land at castDuration independently from bite')
assert(#playCalls==2 and playCalls[1].name=='Cast' and playCalls[2].name=='Splash','cast/landing sound timing is wrong')
local maxY=-math.huge
for _,v in flight do maxY=math.max(maxY,v.Y)end
assert(maxY>hand.Position.Y+2,'cast did not follow a raised trajectory')
for i=1,174 do frame(.01)end
assert(#playCalls==2,'bite cue fired before server readyAt')
for i=1,12 do frame(.01)end
assert(#playCalls==3 and playCalls[3].name=='Chime','server bite cue missing')
local beam=find(bobber,'Beam');assert(beam and beam.CurveSize0<0 and beam.CurveSize1>0,'waiting line did not sag downward')
local rightBefore=right.Transform
for i=1,200 do frame(.01)end
assert((right.Transform.RightVector-rightBefore.RightVector).Magnitude<.001,'pose accumulated while Animator did not write')
local chargeAt=now+.2
presentation.apply(101,{phase='Reeling',catches=0,rodLevel=3,attemptId=1,castAt=castAt,castDuration=.65,readyAt=waiting.readyAt,chargeAt=chargeAt,duration=3,castTarget=target,difficulty=.55,behavior='Surge'})
local crankBefore=find(rig(),'ReelCrank').CFrame
for i=1,100 do frame(.01);validFrames()end
assert((find(rig(),'ReelCrank').CFrame.RightVector-crankBefore.RightVector).Magnitude>.1,'reel crank remained static')
assert(math.abs(beam.CurveSize0)<.1,'reeling line did not tighten')
local middle,tip=find(rig(),'RodMiddle'),find(rig(),'RodTip')
local endpoint=(middle.CFrame*CFrame.new(0,middle.Size.Y*.5,0)).Position
local tipStart=(tip.CFrame*CFrame.new(0,-tip.Size.Y*.5,0)).Position
assert(near(endpoint,tipStart),'bending rod tip disconnected from middle')
local baselinePlays=#playCalls
presentation.apply(101,{phase='Idle',catches=1,rodLevel=3,castTarget=target,result={speciesId='crownwhale',rarity='Legendary',quality='Brilliant',variant='Normal',weightKg=28}})
assert(find(effects,'CaughtFish'),'catch fish not created')
for i=1,220 do frame(.01);validFrames()end
assert(not find(effects,'CaughtFish') and not rig(),'caught fish/idle rod was not cleaned up')
assert(right.Transform==baseRight and left.Transform==baseLeft,'fishing pose did not restore authored shoulder base')
assert(#find(effects,'TransientWaterEffects'):GetChildren()==0,'water effects outlived their lifetime')
presentation.setReducedEffects(true)
waiting.attemptId=2;waiting.castAt=now;waiting.readyAt=now+.8
presentation.apply(101,waiting)
for i=1,90 do frame(.01)end
assert(#find(effects,'TransientWaterEffects'):GetChildren()==0,'reduced effects retained rings/bursts')
presentation.apply(101,{phase='Idle',catches=2,rodLevel=0,castTarget=target,result={speciesId='pufflet',rarity='Common',quality='Fine',weightKg=1}})
frame(.1);local quietFish=find(effects,'CaughtFish');local quietPose=quietFish:GetPivot()
frame(.1);assert(near(quietFish:GetPivot().Position,quietPose.Position) and near(quietFish:GetPivot().RightVector,quietPose.RightVector),'reduced catch fish still spun/flew')
frame(1);assert(not find(effects,'CaughtFish'),'reduced catch did not clean quickly')
presentation.setReducedEffects(false)
waiting.attemptId=3;waiting.castAt=now;waiting.readyAt=now+1
presentation.apply(101,waiting);frame(.1)
local external=CFrame.Angles(.3,.6,.1);right.Transform=external
services.Players.PlayerRemoving:Fire(player)
assert(not rig() and right.Transform==external,'cleanup overwrote newer shoulder owner')
waiting.attemptId=4;waiting.castAt=now;waiting.readyAt=now+1
presentation.apply(101,waiting);frame(.1);assert(rig(),'cast did not rebind after cleanup')
humanoid.Health=0;frame(.01);assert(not rig(),'dead character kept fishing presentation before server cancellation')
presentation.apply(101,{phase='Idle',catches=3,rodLevel=3,castTarget=target,result={speciesId='crownwhale',rarity='Legendary',quality='Brilliant',weightKg=28}})
assert(not find(effects,'CaughtFish') and not find(effects,'WaterCrown'),'late reward recreated effects on a dead character')
presentation.apply(101,waiting);assert(not rig(),'late active packet recreated a dead character rod')
assert(playerScans==0,'presentation rescanned Players on the render loop')
assert(sceneryStarts==1,'scenery initialization duplicated')
print('PASS procedural fishing: independent cast landing/bite clock, raised trajectory, bounded cosmetic joints, attached bending rod and moving reel')
print('PASS waiting slack/reeling taut line, one bite cue, no accumulated pose, authored/external shoulder ownership and effect lifetimes')
print('PASS reduced effects, static quiet catch, inactive/player-removal cleanup and zero render-loop player scans')
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("cinematic_check", ROOT / "tools/check_catch_cinematic.py")
    cinematic = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cinematic)
    program = cinematic.program() + SETUP
    for name, path in (("FishingConfig", "src/shared/FishingConfig.luau"),
                       ("FishingPresentation", "src/client/FishingPresentation.luau")):
        program += cinematic.InstanceHeader(name) + (ROOT / path).read_text() + "\nend)()\n"
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-presentation-") as temp:
        path = Path(temp) / "check.luau"
        path.write_text(program + CHECK)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
