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
character.Parent=workspace
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
-- The geometry shim models an Attachment's local frame independently of its
-- parent and derives native world coordinates, including rotated/nested cases.
local attachmentParent=Instance.new('Part');attachmentParent.CFrame=CFrame.new(11,7,-4)*CFrame.Angles(.3,-.6,.8)
local attachment=Instance.new('Attachment');attachment.Parent=attachmentParent
attachment.Position=Vector3.new(.7,-.4,1.2)
assert((attachment.CFrame.Position-attachment.Position).Magnitude<1e-8,'attachment Position did not update its local CFrame')
assert((attachment.WorldPosition-attachmentParent.CFrame*attachment.Position).Magnitude<1e-8,'rotated attachment world position lost local offset')
attachment.CFrame=CFrame.new(-.8,.5,.2)*CFrame.Angles(.7,.4,-.2)
assert((attachment.Position-Vector3.new(-.8,.5,.2)).Magnitude<1e-8,'attachment CFrame did not update its local Position')
local expectedAttachment=attachmentParent.CFrame*attachment.CFrame
assert((attachment.WorldCFrame.RightVector-expectedAttachment.RightVector).Magnitude<1e-8,'attachment world frame lost local orientation')
local nestedAttachment=Instance.new('Attachment');nestedAttachment.Parent=attachment
nestedAttachment.CFrame=CFrame.new(.3,-.1,.6)*CFrame.Angles(.2,0,.1)
local expectedNested=expectedAttachment*nestedAttachment.CFrame
assert((nestedAttachment.WorldPosition-expectedNested.Position).Magnitude<1e-8
 and (nestedAttachment.WorldCFrame.UpVector-expectedNested.UpVector).Magnitude<1e-8,'nested attachment world frame lost parent composition')
attachmentParent:Destroy()
local presentation=modules.FishingPresentation.new(audio)
local effects=find(workspace,'CloudAnglersEffects')
local function rig()return find(effects,'FishingRod_101')end
local function near(a,b)return (a-b).Magnitude<.000001 end
local reelJoinSamples,shaftJoinSamples=0,0
local function cylinderEnds(part)
 assert(part.Shape==Enum.PartType.Cylinder and part.Size.X>part.Size.Y and math.abs(part.Size.Y-part.Size.Z)<1e-8,'rod shaft is not a round native cylinder')
 return part.CFrame*Vector3.new(-part.Size.X*.5,0,0),part.CFrame*Vector3.new(part.Size.X*.5,0,0)
end
local function rodContacts()
 local rod=rig()
 if not rod then return end
 local lower,middle,tip=find(rod,'Rod'),find(rod,'RodMiddle'),find(rod,'RodTip')
 local base,lowerEnd=cylinderEnds(lower)
 local middleStart,middleEnd=cylinderEnds(middle)
 local tipStart,tipEnd=cylinderEnds(tip)
 assert(near(lower.CFrame.RightVector,rod:GetPivot().UpVector),'native rod axis no longer follows authored centerline')
 assert(near(lowerEnd,middleStart) and near(middleEnd,tipStart),'round rod sections separated at a bending joint')
 local grip=find(rod,'Grip');local root=grip.CFrame:PointToObjectSpace(base)
 assert(math.abs(root.X)<grip.Size.X*.5 and math.abs(root.Y)<grip.Size.Y*.5 and math.abs(root.Z)<grip.Size.Z*.5,'round rod root no longer embeds in its grip')
 local tipAttachment=assert(find(tip,'Attachment'),'round rod lacks its line attachment')
 assert(near(tipAttachment.WorldPosition,tipEnd),'line attachment left actual native cylinder end')
 for _,pair in {{lower,middle,lowerEnd},{middle,tip,middleEnd}} do
  for index=1,2 do
   local section=pair[index];local point=section.CFrame:PointToObjectSpace(pair[3])
   assert(math.abs(point.X)<=section.Size.X*.5+1e-6 and (point.Y/(section.Size.Y*.5))^2+(point.Z/(section.Size.Z*.5))^2<=1+1e-6,'rod joint contact is outside a real cylinder cap')
  end
  shaftJoinSamples+=1
 end
end
local function reelContacts()
 local rod=rig();local hub=find(rod,'ReelHub');local arm=find(rod,'ReelCrank');local knob=find(rod,'ReelGrip');local reel=find(rod,'Reel')
 assert(hub and arm and knob and reel,'reel lacks a complete hub/arm/grip')
 local rootPoint=hub.CFrame:PointToObjectSpace(arm.CFrame*Vector3.new(0,-.15,0))
 assert(math.abs(rootPoint.X)<hub.Size.X*.5 and (rootPoint.Y/(hub.Size.Y*.5))^2+(rootPoint.Z/(hub.Size.Z*.5))^2<1,'rotating crank detached from actual cylinder hub')
 local shared=arm.CFrame*Vector3.new(0,.14,-.03)
 local knobLocal=knob.CFrame:PointToObjectSpace(shared)
 local knobPoint=Vector3.new(knobLocal.X/(knob.Size.X*.5),knobLocal.Y/(knob.Size.Y*.5),knobLocal.Z/(knob.Size.Z*.5))
 assert(knobPoint:Dot(knobPoint)<1,'rotating grip detached from arm end')
 local hubPoint=rod:GetPivot()*Vector3.new(0,.35,-.345)
 for _,part in {hub,reel} do
  local point=part.CFrame:PointToObjectSpace(hubPoint)
  assert(math.abs(point.X)<part.Size.X*.5 and (point.Y/(part.Size.Y*.5))^2+(point.Z/(part.Size.Z*.5))^2<1,'reel hub does not seat in spool body')
 end
 reelJoinSamples+=1
end
local function validFrames()
 for _,p in effects:GetDescendants() do if p:IsA('BasePart') then
  assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch,'presentation created a gameplay obstruction')
  for _,axis in {p.CFrame.RightVector,p.CFrame.UpVector,p.CFrame.LookVector} do assert(math.abs(axis.Magnitude-1)<.00001,'presentation joint transform lost unit axis: '..p.Name..' '..axis.Magnitude)end
  assert(math.abs(p.CFrame.RightVector:Dot(p.CFrame.UpVector))<.00001,'presentation joint axes are not orthogonal')
  assert(p.Position.Magnitude<2000,'presentation geometry escaped')
 end end
 rodContacts()
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
for i=1,100 do frame(.01);validFrames();reelContacts()end
assert((find(rig(),'ReelCrank').CFrame.RightVector-crankBefore.RightVector).Magnitude>.1,'reel crank remained static')
assert(math.abs(beam.CurveSize0)<.1,'reeling line did not tighten')
local middle,tip=find(rig(),'RodMiddle'),find(rig(),'RodTip')
local _,endpoint=cylinderEnds(middle)
local tipStart=cylinderEnds(tip)
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

-- Charge is an anticipation pose, not a prematurely launched float or sound.
humanoid.Health=100
local chargeStart=now
presentation.apply(101,{phase='ChargingCast',catches=3,rodLevel=2,attemptId=5,castChargeAt=chargeStart,castChargeDuration=1,castTarget=target})
assert(rig() and not find(effects,'Bobber_101'),'charge allocated a float before release')
local beforeChargeSounds=#playCalls
frame(.05);local windupLow=rig():GetPivot().UpVector
for i=1,70 do frame(.01);validFrames()end
local windupHigh=rig():GetPivot().UpVector
assert(windupHigh.Y>windupLow.Y+.10,'charge did not smoothly draw the rod back')
assert(#playCalls==beforeChargeSounds,'charge played a premature cast/splash')
local launched={phase='Waiting',catches=3,rodLevel=2,attemptId=5,castChargeAt=chargeStart,castChargeDuration=1,
 castPower=.8,castGrade='Perfect',castAt=now,castDuration=.65,readyAt=now+1.4,castTarget=target+Vector3.new(0,0,-.6),difficulty=.2,behavior='Glide'}
presentation.apply(101,launched)
local chargedBobber=find(effects,'Bobber_101');assert(chargedBobber,'launch did not create float')
frame(0)
local launchTip=find(rig(),'RodTip')
assert(near(chargedBobber.Position,find(launchTip,'Attachment').WorldPosition),'launched float did not originate at the actual bent rod tip')
local releaseStart=rig():GetPivot().UpVector
for i=1,66 do frame(.01);validFrames()end
assert(near(chargedBobber.Position,launched.castTarget+Vector3.new(0,math.sin(now*3)*.09,0)),'powered cast missed server target')
assert(rig():GetPivot().UpVector.Y<releaseStart.Y-.10,'charged rod never followed through')
presentation.apply(101,{phase='Idle',catches=3,rodLevel=2})
frame(2)

for index,outcome in {'Cancelled','Interrupted','Missed'} do
 local id=60+index
 presentation.apply(101,{phase='Waiting',catches=3,attemptId=id,castAt=now-2,castDuration=.65,readyAt=now-1,castTarget=target})
 presentation.apply(101,{phase='Reeling',catches=3,attemptId=id,castAt=now-2,castDuration=.65,readyAt=now-1,chargeAt=now,duration=2.8,castTarget=target})
 frame(.01)
 local previousPlays=#playCalls
 presentation.apply(101,{phase='Idle',catches=3,outcome=outcome,castTarget=target})
 if outcome=='Missed' then
  assert(#playCalls==previousPlays+1 and playCalls[#playCalls].name=='Miss' and find(effects,'WaterCrown'),'genuine missed release lost its feedback')
 else
  assert(#playCalls==previousPlays and not find(effects,'WaterCrown'),'intentional cancellation or interruption played failure feedback')
 end
 assert(not find(effects,'Bobber_101'),'ending outcome retained a float')
 frame(1)
 assert(not rig(),'ending outcome retained an inactive rod')
end

local previousArc=0
for index,power in {0,.35,.65,.8,1} do
 local chargeAt=now
 presentation.apply(101,{phase='ChargingCast',catches=3,rodLevel=2,attemptId=20+index,castChargeAt=chargeAt,castChargeDuration=1,castTarget=target})
 frame(power)
 local destination=target+Vector3.new(0,0,-(power-.65)*4)
 presentation.apply(101,{phase='Waiting',catches=3,rodLevel=2,attemptId=20+index,castChargeAt=chargeAt,castPower=power,castAt=now,castDuration=.65,readyAt=now+1.3,castTarget=destination})
 frame(0)
 local float=find(effects,'Bobber_101');local from=float.Position;local tip=find(rig(),'RodTip')
 assert(near(from,find(tip,'Attachment').WorldPosition),'power-specific release broke rod-tip contact')
 local began=now;local peak=0
 for sample=1,66 do
  frame(.01);validFrames();reelContacts()
  local t=math.clamp((now-began)/.65,0,1)
  if t<1 then peak=math.max(peak,float.Position.Y-from:Lerp(destination,t).Y)end
 end
 assert(peak>(3.4+power*1.2)*.99 and peak>previousArc,'cast strength did not produce the bounded ascending arc heights')
 assert(near(float.Position,destination+Vector3.new(0,math.sin(now*3)*.09,0)),'power-specific cast missed server water endpoint')
 previousArc=peak
 presentation.apply(101,{phase='Idle',catches=3,rodLevel=2})
end
frame(2)

local function makePeer(id,x)
 local peer=Instance.new('Player');peer.UserId=id
 local model=Instance.new('Model');model.Parent=workspace;peer.Character=model
 local peerRoot=Instance.new('Part');peerRoot.Name='HumanoidRootPart';peerRoot.Position=Vector3.new(x,5,0);peerRoot.Parent=model
 local peerHand=Instance.new('Part');peerHand.Name='RightHand';peerHand.Position=Vector3.new(x+1.5,5,-.3);peerHand.Parent=model
 local peerHum=Instance.new('Humanoid');peerHum.Health=100;peerHum.Parent=model
 players[id]=peer
 return peer,peerRoot,peerHand
end
local distant,farRoot,farHand=makePeer(202,500)
local farSounds=#playCalls
local farWait={phase='Waiting',catches=0,attemptId=7,castAt=now,castDuration=.65,readyAt=now+1.2,castTarget=Vector3.new(500,1,-14)}
presentation.apply(202,farWait)
assert(not find(effects,'FishingRod_202') and not find(effects,'Bobber_202'),'distant packet allocated a rig before render culling')
presentation.apply(202,{phase='Idle',catches=1,castTarget=farWait.castTarget,result={speciesId='crownwhale',rarity='Legendary',quality='Brilliant',weightKg=28}})
assert(not find(effects,'CaughtFish') and #find(effects,'TransientWaterEffects'):GetChildren()==0 and #playCalls==farSounds,'distant catch allocated effects/audio')
farRoot.Position=Vector3.new(0,5,0);farHand.Position=Vector3.new(1.5,5,-.3);frame(.01)
assert(not find(effects,'CaughtFish'),'returning to view replayed an old catch')
farRoot.Position=Vector3.new(500,5,0);farHand.Position=Vector3.new(501.5,5,-.3)
farWait.attemptId=8;farWait.castAt=now-5;farWait.readyAt=now-3
presentation.apply(202,farWait)
farRoot.Position=Vector3.new(0,5,0);farHand.Position=Vector3.new(1.5,5,-.3);frame(.01)
assert(find(effects,'FishingRod_202') and find(effects,'Bobber_202'),'active distant cast did not recover in view')
assert(#playCalls==farSounds and #find(effects,'TransientWaterEffects'):GetChildren()==0,'LOD recovery replayed old splash/bite effects')
farHand.Parent=nil;frame(.01);assert(not find(effects,'FishingRod_202'),'streamed-out hand left a ghost rod')
farHand.Parent=distant.Character;frame(.01)
assert(find(effects,'FishingRod_202') and #playCalls==farSounds,'hand recovery lost current cast or replayed old sound')
distant.Character.Parent=nil;frame(.01)
assert(not find(effects,'FishingRod_202'),'detached character left a floating fishing rig')
distant.Character.Parent=workspace;frame(.01)
assert(find(effects,'FishingRod_202') and #playCalls==farSounds,'character rebind did not quietly restore current cast')
presentation.apply(202,{phase='Idle',catches=1})
frame(1)

-- Successful server results arriving during partial character streaming are
-- still successful; a missing hand must not turn them into a false miss cue.
farWait.attemptId=9;farWait.castAt=now-2;farWait.readyAt=now-1
presentation.apply(202,farWait)
presentation.apply(202,{phase='Reeling',catches=1,attemptId=9,castAt=farWait.castAt,readyAt=farWait.readyAt,chargeAt=now,duration=2.8,castTarget=target})
farHand.Parent=nil
local beforeMissingHand=#playCalls
presentation.apply(202,{phase='Idle',catches=2,castTarget=target,result={speciesId='pufflet',rarity='Common',quality='Fine',weightKg=1}})
assert(not find(effects,'CaughtFish') and #playCalls==beforeMissingHand and #find(effects,'TransientWaterEffects'):GetChildren()==0,'successful streamed-hand catch emitted a false miss or ghost fish')
farHand.Parent=distant.Character
frame(1)

local lateObserver,observerRoot,observerHand=makePeer(203,0)
presentation.apply(203,{phase='Idle',catches=1,castTarget=target,result={speciesId='pufflet',rarity='Common',quality='Fine',weightKg=1}})
assert(find(effects,'CaughtFish') and not find(effects,'FishingRod_203'),'fresh observer result did not exercise fish-before-rig lifecycle')
observerRoot.Position=Vector3.new(500,5,0);observerHand.Position=Vector3.new(501.5,5,-.3)
frame(.01);assert(not find(effects,'CaughtFish'),'out-of-view fresh catch leaked before its first rig allocation')
frame(1)

for _,attribute in {'IslandTravelMenuOpen','IslandTravelBusy'} do
 player:SetAttribute(attribute,true)
 local beforeTravel=#playCalls
 presentation.apply(101,{phase='Waiting',catches=3,attemptId=40,castAt=now,castDuration=.65,readyAt=now+1,castTarget=target})
 frame(.01)
 assert(not rig() and not find(effects,'Bobber_101') and #playCalls==beforeTravel,'travel interruption displayed a late fishing state')
 presentation.apply(101,{phase='Idle',catches=3})
 player:SetAttribute(attribute,false)
end

-- A crowd shares one strict transient budget. Local feedback can replace old
-- remote accents, but it cannot cause the budget itself to grow.
for id=210,231 do
 makePeer(id,20+(id-210)*.2)
 presentation.apply(id,{phase='Idle',catches=1,castTarget=Vector3.new(20,1,-14),result={speciesId='crownwhale',rarity='Legendary',quality='Brilliant',weightKg=28}})
end
local groups=find(effects,'TransientWaterEffects')
assert(#groups:GetChildren()<=8,'crowd water effects exceeded shared group budget')
presentation.apply(101,{phase='Idle',catches=4,castTarget=target,result={speciesId='pufflet',rarity='Common',quality='Fine',weightKg=1}})
local localGroups,partCount=0,0
for _,group in groups:GetChildren() do
 if group:GetAttribute('AnglerUserId')==101 then localGroups+=1 end
 for _,p in group:GetDescendants() do if p:IsA('BasePart') then partCount+=1 end end
end
assert(localGroups==2 and #groups:GetChildren()<=8 and partCount<=96,'local feedback lost priority or broke transient Part budget')
frame(2);assert(#groups:GetChildren()==0,'crowded transient effects did not expire')
-- Earned equipment must be visible using the same fitted rig. Styling is
-- independent of phase/attempt changes, and stable frames perform no writes.
local finishRig,finishWrites=nil,0
local finishWriter=mt.__newindex
mt.__newindex=function(self,key,value)
 if finishRig and self.Parent==finishRig and (key=='Color' or key=='Material') then finishWrites+=1 end
 finishWriter(self,key,value)
end
local function applyFinish(level)
 presentation.apply(101,{phase='ChargingCast',catches=4,rodLevel=level,attemptId=900,
  castChargeAt=now,castChargeDuration=1,castTarget=target})
end
local finishRoles={Grip='Grip',Rod='Shaft',RodMiddle='Shaft',RodTip='Shaft',
 Reel='Reel',ReelHub='Hardware',ReelCrank='Hardware',ReelGrip='Grip'}
local function matchesFinish(level)
 local definition=modules.FishCatalog.Rods[level+1]
 assert(rig():GetAttribute('RodLevel')==level and rig():GetAttribute('RodName')==definition.Name,'earned rod finish ignored server-approved equipment')
 local count=0
 for _,part in rig():GetChildren() do
  if part:IsA('BasePart') then
   count+=1
   local finish=definition.Finish[assert(finishRoles[part.Name],'finish added unexpected rod geometry')]
   assert(math.abs(part.Color.R-finish.Color[1]/255)<1e-8 and math.abs(part.Color.G-finish.Color[2]/255)<1e-8
    and math.abs(part.Color.B-finish.Color[3]/255)<1e-8 and part.Material==Enum.Material[finish.Material],
    'earned rod finish ignored server-approved equipment')
  end
 end
 assert(count==8,'rod finish added Parts')
end
applyFinish(0);finishRig=rig()
local finishTip=assert(find(find(finishRig,'RodTip'),'Attachment'),'active rod lost its tip attachment')
local finishSignatures={}
for level=0,3 do
 local frames={}
 for _,part in finishRig:GetChildren() do if part:IsA('BasePart') then frames[part]={frame=part.CFrame,size=part.Size}end end
 applyFinish(level);matchesFinish(level)
 assert(rig()==finishRig and finishTip.Parent==find(finishRig,'RodTip'),'finish recreated the active rod or its attachment')
 for part,before in frames do assert(part.CFrame==before.frame and part.Size==before.size,'finish changed fitted geometry or interrupted animation')end
 local signature=table.concat(modules.FishCatalog.Rods[level+1].Finish.Shaft.Color,',')
 assert(not finishSignatures[signature],'earned rods have identical shaft finishes');finishSignatures[signature]=true
 frame(.01);reelContacts();rodContacts()
 finishWrites=0
 for _=1,120 do frame(.001)end
 assert(finishWrites==0,'stable rod finish rewrote colors/materials every render frame')
end
for _,invalid in {false,true,-1,.5,4,999,'3',{},math.huge,-math.huge,0/0} do
 applyFinish(3);applyFinish(invalid);matchesFinish(0)
end
applyFinish(3);applyFinish(nil);matchesFinish(0)
presentation.apply(101,{phase='Idle',catches=4,rodLevel=0})
for _=1,60 do frame(.01)end -- let the existing authored-pose settle complete
assert(not rig(),'finish retained an inactive rig')
mt.__newindex=finishWriter
print('PASS procedural fishing: independent cast landing/bite clock, raised trajectory, bounded cosmetic joints, attached bending rod and moving reel')
print('PASS waiting slack/reeling taut line, one bite cue, no accumulated pose, authored/external shoulder ownership and effect lifetimes')
print('PASS reduced effects, static quiet catch, inactive/player-removal cleanup and zero render-loop player scans')
print('PASS charge windup without premature float/audio, powered server target and release follow-through')
print('PASS',reelJoinSamples,'real spool/hub/arm/grip joins through full turns and five tip-seated strength trajectories')
print('PASS',shaftJoinSamples,'actual native cylinder-cap contacts through bent poses; line/cast origins follow the attached end')
print('PASS distance-before-allocation, quiet late/LOD recovery, streamed hand/character cleanup and 96-Part shared effect ceiling with local priority')
print('PASS successful partial-stream catches never become misses; pre-rig catches and late travel states clean up without ghost fish')
print('PASS server Missed outcome alone plays failure feedback; Cancelled/Interrupted resolve quietly with complete cleanup')
print('PASS four earned finishes on the same eight-Part rig; rooted geometry, unchanged live attachments, malformed-level fallback and zero stable-frame finish writes')
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("cinematic_check", ROOT / "tools/check_catch_cinematic.py")
    cinematic = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cinematic)
    program = cinematic.program() + SETUP
    for name, path in (("FishingConfig", "src/shared/FishingConfig.luau"),
                       ("FishingRules", "src/shared/FishingRules.luau"),
                       ("FishingPresentation", "src/client/FishingPresentation.luau")):
        program += cinematic.InstanceHeader(name) + (ROOT / path).read_text() + "\nend)()\n"
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-presentation-") as temp:
        path = Path(temp) / "check.luau"
        path.write_text(program + CHECK)
        subprocess.run([luau, str(path)], check=True)
        mutations = (
            ("distance allocation", "if not visible(actor) then", "if false then", "distant packet allocated a rig before render culling"),
            ("shared effect ceiling", "local EFFECT_GROUP_LIMIT = 8", "local EFFECT_GROUP_LIMIT = 800", "crowd water effects exceeded shared group budget"),
            ("reel pivot", "local crankPivot = rodPivot * CFrame.new(0, .35, -.43)", "local crankPivot = rodPivot * CFrame.new(.17, .35, -.40)", "rotating crank detached from actual cylinder hub"),
            ("release origin", "actor.castFrom = actor.tip.WorldPosition", "actor.castFrom = hand.Position + Vector3.new(0, 2, 0)", "launched float did not originate at the actual bent rod tip"),
            ("pre-rig cleanup", "if actor.rig or actor.caughtFish or actor.bobber then clearRig(actor) end", "if actor.rig then clearRig(actor) end", "out-of-view fresh catch leaked before its first rig allocation"),
            ("earned rod finish", "local requested = actor.state.rodLevel", "local requested = 0", "earned rod finish ignored server-approved equipment"),
            ("native shaft axis", "local SHAFT_CYLINDER_FRAME = CFrame.Angles(0, 0, math.pi / 2)", "local SHAFT_CYLINDER_FRAME = CFrame.identity", "native rod axis no longer follows authored centerline"),
        )
        for name, before, after, expected in mutations:
            assert before in program, name + " mutation no longer targets production source"
            path.write_text(program.replace(before, after, 1) + CHECK)
            result = subprocess.run([luau, str(path)], text=True, capture_output=True)
            assert result.returncode and expected in result.stderr, name + " mutation escaped its regression check: " + result.stderr
        print("PASS seven deliberate allocation/budget, reel-pivot, tip-origin, pre-rig cleanup, earned-finish and cylinder-axis regressions are rejected")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
