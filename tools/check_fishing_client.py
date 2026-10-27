#!/usr/bin/env python3
"""Exercise the production fishing controller's input/remote integration.

Uses actual shared timing rules with focused UI, service, cinematic and audio
doubles. Covers protocol races and interruption ownership, not native input,
rendering, actual networking or the internal behavior of the UI modules.
Run: python tools/check_fishing_client.py --luau /path/to/luau
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local originalIndex,originalNewIndex=mt.__index,mt.__newindex
local signalNames={InputBegan=true,InputEnded=true,Changed=true,OnClientEvent=true,
 CharacterRemoving=true,CharacterAdded=true,WindowFocusReleased=true,
 TextBoxFocused=true,PromptShown=true,PromptHidden=true,PromptTriggered=true,Died=true,ChildAdded=true}
mt.__index=function(self,key)
 if signalNames[key] then self.props[key]=self.props[key] or signal();return self.props[key] end
 return originalIndex(self,key)
end
mt.__newindex=function(self,key,value)
 local previous=self.props[key]
 originalNewIndex(self,key,value)
 if key=='Parent' and value and previous~=value and value.props.ChildAdded then value.props.ChildAdded:Fire(self) end
 if previous~=value then
  if self.props.Changed then self.props.Changed:Fire(key) end
  local changed=self.props['PropertySignal_'..key]
  if changed then changed:Fire() end
 end
end
function methods:GetPropertyChangedSignal(key)
 self.props['PropertySignal_'..key]=self.props['PropertySignal_'..key] or signal()
 return self.props['PropertySignal_'..key]
end
function methods:GetAttributeChangedSignal(key)
 self.props['AttributeSignal_'..key]=self.props['AttributeSignal_'..key] or signal()
 return self.props['AttributeSignal_'..key]
end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
 return nil
end
function methods:SetAttribute(key,value)
 local previous=self.attributes[key];self.attributes[key]=value
 if previous~=value and self.props['AttributeSignal_'..key] then self.props['AttributeSignal_'..key]:Fire() end
end
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local tweenCount=0
local TweenService={Create=function(_,object,info,values)
 tweenCount+=1
 return {Play=function()task.delay(info[1],function()for key,value in values do object[key]=value end end)end}
end}
local RunService={RenderStepped=signal()}
local player=Instance.new('Player')
local playerGui=Instance.new('PlayerGui');playerGui.Parent=player
local character=Instance.new('Model');character.Parent=workspace
local humanoid=Instance.new('Humanoid');humanoid.Health=100;humanoid.Parent=character
player.Character=character
local input=Instance.new('UserInputService')
input.PreferredInput=Enum.PreferredInput.KeyboardAndMouse
local focused=nil
function input:GetFocusedTextBox()return focused end
local prompts=Instance.new('ProximityPromptService')
local GuiService=Instance.new('GuiService');GuiService.ReducedMotionEnabled=false
local Players={LocalPlayer=player}
local sends={}
local remotes=Instance.new('Folder');remotes.Name='FishingRemotes';remotes.Parent=ReplicatedStorage
local action=Instance.new('RemoteEvent');action.Name='FishingAction';action.Parent=remotes
local state=Instance.new('RemoteEvent');state.Name='FishingState';state.Parent=remotes
local visual=Instance.new('RemoteEvent');visual.Name='FishingVisual';visual.Parent=remotes
local bootstrapResponse=false
local bootstrapProfile=nil -- preference-bootstrap fixture
function action:FireServer(...)
 local verb,argument,preferenceRequestId=...
 assert(select('#',...)==(if verb=='Preferences' then 3 else 2),'controller sent unexpected extra payload')
 if verb=='Preferences' then assert(type(preferenceRequestId)=='number' and preferenceRequestId%1==0 and preferenceRequestId>0 and preferenceRequestId<=2147483647) end
 assert(type(verb)=='string','non-string client command')
 table.insert(sends,{verb=verb,argument=argument,time=now,preferenceRequestId=preferenceRequestId})
 if not bootstrapResponse and verb=='Sync' then
  bootstrapResponse=true
  -- An immediate response is deliberately harsher than real network delivery:
  -- subscribing after Sync would lose it and leave the interface Connecting.
  state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now,profile=bootstrapProfile,replyTo='Sync'})
 end
end
local camera=Instance.new('Camera');camera.ViewportSize=Vector2.new(1280,720);workspace.CurrentCamera=camera
function workspace:GetServerTimeNow()return now end
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,RunService=RunService,
 TweenService=TweenService,UserInputService=input,ProximityPromptService=prompts,GuiService=GuiService}
game.GetService=function(_,name)assert(services[name],name);return services[name]end
local audio={enabled=true,reeling=false,catches=0,goals=0,upgrades=0,coinsPlayed=0,uiCalls=0}
function audio.setEnabled(value)audio.enabled=value end
function audio.setReeling(value)audio.reeling=value end
function audio.updateReeling(progress,difficulty,dt)audio.motion={progress=progress,difficulty=difficulty,dt=dt}end
function audio.catch()audio.catches+=1 end
function audio.goal()audio.goals+=1 end
function audio.upgrade()audio.upgrades+=1 end
function audio.coins()audio.coinsPlayed+=1 end
function audio.ui()audio.uiCalls+=1 end
local presentation={reduced=false,applied={}}
function presentation.setReducedEffects(value)presentation.reduced=value end
function presentation.apply(...)table.insert(presentation.applied,{...})end
local cinematic={playing=false,reduced=false,history={},stops=0}
function cinematic.play(result,complete)
 if result.rarity~='Epic' and result.rarity~='Legendary' and result.rarity~='Mythical' and result.rarity~='Secret' then return false end
 cinematic.playing=true
 table.insert(cinematic.history,{result=result,complete=complete})
 audio.catch()
 return true
end
function cinematic.stop()cinematic.playing=false;cinematic.stops+=1 end
function cinematic.isPlaying()return cinematic.playing end
function cinematic.setReducedEffects(value)cinematic.reduced=value end
local ui,aquarium,uiHandlers,aquariumHandlers
local resultCalls={}
local notifications={}
local travel={starts=0,visits=0,canVisit=true}
local function newInterface(_,_,handlers)
 uiHandlers=handlers
 ui={button=Instance.new('TextButton'),status=Instance.new('TextLabel'),marker=Instance.new('Frame'),
  legend=Instance.new('TextLabel'),buttonScale=Instance.new('UIScale'),journal=false,settings=false,result=false}
 ui.buttonScale.Scale=1
 function ui.hideResult()ui.result=false end
 function ui.showResult(result,immediate,silent)
  table.insert(resultCalls,{result=result,immediate=immediate,silent=silent})
  ui.result=true
  if not silent then audio.catch() end
 end
 function ui.closeJournal()ui.journal=false end
 function ui.openJournal()
  uiHandlers.openJournal();ui.settings=false;ui.journal=true
 end
 function ui.closeSettings()ui.settings=false end
 function ui.openSettings()
  uiHandlers.openSettings();ui.journal=false;ui.settings=true
 end
 function ui.isJournalOpen()return ui.journal end
 function ui.isSettingsOpen()return ui.settings end
 function ui.isResultOpen()return ui.result end
 function ui.setPreferences(values)ui.preferences=table.clone(values)end
 function ui.updateProfile(value)ui.profile=value end
 function ui.updateLocation(value,profile)ui.location=value;ui.locationProfile=profile end
 function ui.setTimingWindow(center,width)ui.center=center;ui.window=width end
 function ui.setCastProgress(power)ui.castProgress=power end
 function ui.setState(phase)ui.phase=phase end
 function ui.notify(message)table.insert(notifications,message)end
 function ui.animate(time,width,height)ui.viewport={time,width,height}end
 return ui
end
local function newAquarium(_,handlers)
 aquariumHandlers=handlers
 aquarium={opened=false}
 function aquarium.open()aquarium.opened=true end
 function aquarium.close()aquarium.opened=false end
 function aquarium.isOpen()return aquarium.opened end
 function aquarium.updateProfile(value)aquarium.profile=value end
 function aquarium.animate()end
 return aquarium
end
modules.FishingAudio={new=function(initiallyMuted)
 assert(initiallyMuted==true,'client created an audible mix before profile/remote readiness')
 audio.enabled=false
 return audio
end}
modules.FishingPresentation={new=function()return presentation end}
modules.FishingInterface={new=newInterface}
modules.AquariumInterface={new=newAquarium}
modules.CatchCinematic={new=function()return cinematic end}
modules.IslandTravelInterface={start=function()travel.starts+=1 end,visitGallery=function()travel.visits+=1;return travel.canVisit end}
for _,name in {'FishingRules','FishingAudio','FishingPresentation','FishingInterface','AquariumInterface','CatchCinematic','IslandTravelInterface'} do
 local token=Instance.new('ModuleScript');token.Name=name;token.Parent=shared
end
'''

CHECK = r'''
local passed,catches,sequence=0,0,0
local profile={level=1,coins=100,rod='Breeze Rod',species=3}
local function test(name,callback)
 local ok,err=pcall(callback)
 assert(ok,'FAIL '..name..': '..tostring(err))
 passed+=1;print('PASS '..name)
end
local function ack(packet)
 if packet.unsolicited then packet.unsolicited=nil
 else packet.replyTo=packet.replyTo or sends[#sends].verb end
 packet.catches=packet.catches or catches
 packet.nextStart=packet.nextStart or now
 packet.profile=profile
 state.OnClientEvent:Fire(packet)
 return packet
end
local function frame(dt)step(dt or 0);RunService.RenderStepped:Fire(dt or 0)end
local function key(code)
 local object=Instance.new('InputObject')
 object.KeyCode=code or Enum.KeyCode.E;object.UserInputType=Enum.UserInputType.Keyboard
 object.UserInputState=Enum.UserInputState.Begin
 return object
end
local function press(object,processed)input.InputBegan:Fire(object or key(),processed or false)end
local function ending(object)
 object.UserInputState=Enum.UserInputState.End
 input.InputEnded:Fire(object)
end
local function reset()
 input.WindowFocusReleased:Fire()
 ui.closeJournal();ui.closeSettings();aquarium.close();cinematic.stop()
 player:SetAttribute('IslandTravelMenuOpen',false);player:SetAttribute('IslandTravelBusy',false)
 humanoid.Health=100;player.Character=character;player.CharacterAdded:Fire(character)
 focused=nil
 ack({phase='Idle'})
end
local function waiting(delay)
 sequence+=1
 return ack({phase='Waiting',attemptId=sequence,castAt=now,castDuration=.65,readyAt=now+(delay or 0),expiresAt=now+12,timingCenter=.60})
end
local function charging()
 sequence+=1
 return ack({phase='ChargingCast',attemptId=sequence,castChargeAt=now,castChargeDuration=1,expiresAt=now+2.2,replyTo='BeginCast'})
end
local function launched(charge,verb)
 return ack({phase='Waiting',attemptId=charge.attemptId,castAt=now,castDuration=.65,readyAt=now+1.3,expiresAt=now+13.3,
  timingCenter=.60,castPower=.65,castGrade='Clean',castBonusPercent=0,replyTo=verb or 'Cast'})
end
local function reeling(waitPacket)
 return ack({phase='Reeling',attemptId=waitPacket.attemptId,chargeAt=now+.3,duration=2.8,
  timingCenter=.60,timingWidth=.172,timingMotion={amplitude=.055,speed=2.2,phase=.8}})
end
local function last(verb)
 assert(sends[#sends].verb==verb,'expected '..verb..', got '..sends[#sends].verb)
 return sends[#sends]
end
local function reward(rarity)
 catches+=1
 return ack({phase='Idle',catches=catches,result={species='Test Fish',speciesId='pufflet',rarity=rarity or 'Common',quality='Fine',weightKg=1.2,coins=10}})
end
local function finishCinematic(entry)
 cinematic.playing=false
 entry.complete()
end
test('subscribes before initial Sync and propagates approved visual packets',function()
 assert(#sends==1 and sends[1].verb=='Sync' and sends[1].argument==nil)
 assert(ui.phase=='Idle','initial immediate Sync response was lost before subscription')
 assert(travel.starts==1 and ui.preferences.soundEnabled and not audio.enabled,'audio played before saved preferences loaded')
 assert(not presentation.reduced and not cinematic.reduced)
 ack({phase='Idle',location={zoneId='forest'}})
 assert(audio.enabled,'legacy default audio did not activate after profile loading')
 assert(ui.phase=='Idle' and ui.profile==profile and aquarium.profile==profile and ui.location.zoneId=='forest')
 visual.OnClientEvent:Fire(42,{phase='Waiting'})
 assert(#presentation.applied==1 and presentation.applied[1][1]==42)
 frame(0);assert(ui.viewport[2]==1280 and ui.viewport[3]==720)
end)
test('BeginCast is single while pending and Hold is forbidden before the bite',function()
 local before=#sends
 press();last('BeginCast');press();assert(#sends==before+1,'pending BeginCast duplicated')
 local waitPacket=waiting(1.4)
 press();assert(#sends==before+1,'Hold sent before bite')
 frame(.7);assert(ui.button.Text=='WATCH THE FLOAT','waiting anticipation phase absent')
 frame(.71);press();assert(last('Hold').argument==waitPacket.attemptId)
 reset()
end)
test('quick tap queues until BeginCast acknowledgement and submits only the accepted ID',function()
 local held=key();local before=#sends
 press(held);assert(#sends==before+1 and last('BeginCast').argument==nil)
 frame(.08);ending(held)
 assert(#sends==before+1,'quick tap sent a cast before server acceptance')
 frame(.8)
 local charge=charging()
 assert(#sends==before+2 and last('QuickCast').argument==charge.attemptId,'quick tap lost across delayed acknowledgement')
 ending(held);assert(#sends==before+2,'old cast input released twice')
 launched(charge,'QuickCast');frame(.3)
 assert(ui.phase=='Waiting' and ui.button.Text=='CASTING...')
 reset()
end)
test('held cast tracks actual rules and release launches once without claiming power or reward',function()
 local held=key();press(held);local charge=charging()
 for _,dt in {.2,.3,.28} do
  frame(dt)
  local power=modules.FishingRules.castProgressAt(charge,now)
  assert(math.abs(ui.castProgress-power)<1e-9,'cast meter differs from actual shared rules')
  local grade=modules.FishingRules.castGradeAt(power)
  assert(ui.legend.Text=='CAST  '..math.floor(power*100+.5)..'%  ·  '..string.upper(grade))
 end
 local before=#sends;ending(held)
 assert(#sends==before+1 and last('Cast').argument==charge.attemptId)
 ack({phase='ChargingCast',attemptId=charge.attemptId,castChargeAt=charge.castChargeAt,castChargeDuration=1,unsolicited=true})
 assert(#sends==before+1,'an unsolicited charging snapshot canceled a pending launch')
 launched(charge);ending(held);assert(#sends==before+1,'stale charge input launched or reeled again')
 reset()
end)
test('unsolicited Idle does not erase a held cast or its queued early release',function()
 for _,quick in {true,false} do
  reset();local held=key();press(held);local before=#sends
  ack({phase='Idle',location={zoneId='forest'},unsolicited=true})
  assert(#sends==before and ui.location.zoneId=='forest')
  frame(if quick then .08 else .4);ending(held)
  ack({phase='Idle',location={zoneId='harbor'},unsolicited=true})
  assert(#sends==before,'location snapshot prematurely submitted or canceled a cast')
  local charge=charging()
  assert(#sends==before+1 and last(if quick then 'QuickCast' else 'Cast').argument==charge.attemptId,'unsolicited Idle discarded cast latch')
 end
 reset()
end)
test('rejected BeginCast clears input and does not strand a new press',function()
 local held=key();press(held)
 ack({phase='Idle',replyTo='BeginCast',message='Walk to the dock.'})
 local before=#sends;ending(held);assert(#sends==before,'rejected cast later sent a release')
 press();assert(#sends==before+1 and last('BeginCast'),'rejected cast stranded controls')
 reset()
end)
test('cancel before BeginCast acknowledgement cannot launch later',function()
 for index,cancelInput in {
  function(held)held.UserInputState=Enum.UserInputState.Cancel end,
  function()input.WindowFocusReleased:Fire()end,
  function()input.TextBoxFocused:Fire(Instance.new('TextBox'))end,
 } do
  reset();local held=key();press(held);frame(.08)
  if index>1 then ending(held) end
  cancelInput(held)
  local before=#sends;local charge=charging()
  assert(#sends==before+1 and last('Cancel').argument==charge.attemptId,'canceled pre-ack input launched instead')
 end
 reset()
end)
test('same-ID auto launch disconnects old charge press and needs a fresh reel press',function()
 local held=key();press(held);local charge=charging()
 frame(2.2);launched(charge,'Tick')
 local before=#sends;ending(held);assert(#sends==before,'auto launch retained old charge input')
 frame(1.31);local reelInput=key();press(reelInput)
 assert(#sends==before+1 and last('Hold').argument==charge.attemptId,'fresh reel input was blocked after auto launch')
 reset()
end)
test('every menu, travel and death cancels ChargingCast and stale charging acknowledgements',function()
 for _,interrupt in {
  function()ui.openJournal()end,function()ui.openSettings()end,function()uiHandlers.openAquarium()end,
  function()player:SetAttribute('IslandTravelBusy',true)end,
  function()humanoid.Health=0;humanoid.Died:Fire()end,
 } do
  reset();local held=key();press(held);local charge=charging()
  interrupt();assert(last('Cancel').argument==charge.attemptId)
  local before=#sends
  ack({phase='ChargingCast',attemptId=charge.attemptId,castChargeAt=charge.castChargeAt,castChargeDuration=1,unsolicited=true})
  assert(#sends==before and last('Cancel').argument==charge.attemptId,'stale charge escaped or duplicated a pending cancellation')
  ending(held);assert(#sends==before,'interrupted charge emitted a late launch')
 end
 reset()
end)
test('older launch/reel replies cannot reopen controls or audio while Cancel is pending',function()
 local held=key();press(held);local charge=charging()
 frame(.5);ending(held);last('Cast')
 input.WindowFocusReleased:Fire();last('Cancel')
 local before=#sends
 local waitPacket=launched(charge,'Cast');frame(1.5)
 press();assert(#sends==before,'stale launch acknowledgement re-enabled a hold before Cancel finished')
 ack({phase='Reeling',attemptId=charge.attemptId,chargeAt=now,duration=2.8,replyTo='Hold'})
 assert(not audio.reeling and #sends==before,'stale reel reply restarted audio or duplicated cancellation')
 ack({phase='Idle',replyTo='Cancel'})
 press();assert(#sends==before+1 and last('BeginCast'),'completed cancellation left controls locked')
 reset()
end)
test('release before Hold acknowledgement emits one Release with the accepted ID',function()
 local waitPacket=waiting()
 local held=key();press(held);last('Hold')
 local before=#sends
 ending(held);assert(#sends==before,'released unacknowledged attempt prematurely')
 reeling(waitPacket);assert(#sends==before+1 and last('Release').argument==waitPacket.attemptId)
 ending(held);assert(#sends==before+1,'duplicate input-end emitted another Release')
 ack({phase='Idle'});reset()
end)
test('normal and canceled holds release or cancel once and disconnect old input',function()
 local waitPacket=waiting();local held=key();press(held);reeling(waitPacket)
 local before=#sends;ending(held)
 assert(#sends==before+1 and last('Release').argument==waitPacket.attemptId)
 held.UserInputState=Enum.UserInputState.Cancel
 assert(#sends==before+1,'disconnected old input canceled a newer state')
 ack({phase='Idle'})
 waitPacket=waiting();held=key();press(held);reeling(waitPacket)
 before=#sends;held.UserInputState=Enum.UserInputState.Cancel
 assert(#sends==before+1 and last('Cancel').argument==waitPacket.attemptId)
 ending(held);assert(#sends==before+1)
 reset()
end)
test('lost acknowledgement resynchronizes at three seconds and clears a stuck hold',function()
 local waitPacket=waiting();local held=key();press(held)
 local before=#sends;frame(2.99);assert(#sends==before)
 frame(.02);assert(#sends==before+1 and last('Sync').argument==waitPacket.attemptId)
 frame(.1);assert(#sends==before+1,'Sync retried every frame')
 reeling(waitPacket);assert(last('Cancel').argument==waitPacket.attemptId,'orphan reeling hold was retained')
 reset()
end)
test('moving timing center, displayed marker and quality share actual rule functions',function()
 local waitPacket=waiting();local held=key();press(held)
 local packet=reeling(waitPacket)
 for _,dt in {.31,.36,.43,.29} do
  frame(dt)
  local center=modules.FishingRules.centerAt(packet,now)
  local progress=modules.FishingRules.progressAt(packet,now)
  assert(math.abs(ui.center-center)<1e-9 and ui.window==packet.timingWidth,'target drift/rod width differs from rules')
  assert(math.abs(ui.marker.Position.X.Scale-progress)<1e-9,'marker differs from rules')
  assert(audio.motion.progress==progress and audio.motion.dt==dt,'reel feedback differs from rendered progress')
  local quality=modules.FishingRules.qualityAt(progress,center,packet.timingWidth)
  assert(ui.legend.Text=='NOW: '..string.upper(quality or 'OUTSIDE THE ZONE'))
 end
 assert(audio.reeling and string.find(ui.status.Text,'rhythm',1,true))
 reset();assert(not audio.reeling)
end)
test('journal/settings/aquarium interrupt casts and stale Waiting cannot resume them',function()
 for _,open in {
  function()ui.openJournal()end,function()ui.openSettings()end,function()uiHandlers.openAquarium()end,
 } do
  reset();local waitPacket=waiting();local held=key();press(held);reeling(waitPacket)
  open();assert(last('Cancel').argument==waitPacket.attemptId)
  local before=#sends
  ack({phase='Waiting',attemptId=waitPacket.attemptId,readyAt=now,replyTo='Start'})
  assert(#sends==before and last('Cancel').argument==waitPacket.attemptId,'late Waiting reopened or duplicated a modal cancellation')
  press();assert(#sends==before,'modal allowed another fishing input')
 end
 reset()
end)
test('fresh rewards present once; rare completion shows a silent immediate summary',function()
 local before=#resultCalls;local motifs=audio.catches
 local packet=reward('Common')
 assert(#resultCalls==before+1 and audio.catches==motifs+1)
 ack(packet);assert(#resultCalls==before+1 and audio.catches==motifs+1,'duplicate state replayed catch')
 ui.hideResult()
 before=#resultCalls;motifs=audio.catches
 packet=reward('Legendary')
 assert(cinematic.playing and #resultCalls==before and audio.catches==motifs+1)
 local entry=cinematic.history[#cinematic.history]
 finishCinematic(entry)
 assert(#resultCalls==before+1 and resultCalls[#resultCalls].immediate==true and resultCalls[#resultCalls].silent==true)
 assert(audio.catches==motifs+1,'rare summary duplicated audio motif')
 ack(packet);assert(#resultCalls==before+1,'duplicate rare packet reopened summary')
 reset()
end)
test('stale rare completions cannot reopen after menus, travel, respawn or focus loss',function()
 local interruptions={
  function()ui.openJournal();ui.closeJournal()end,
  function()ui.openSettings();ui.closeSettings()end,
  function()uiHandlers.openAquarium();aquarium.close()end,
  function()player:SetAttribute('IslandTravelMenuOpen',true);player:SetAttribute('IslandTravelMenuOpen',false)end,
  function()player:SetAttribute('IslandTravelBusy',true);player:SetAttribute('IslandTravelBusy',false)end,
  function()player.CharacterRemoving:Fire(character)end,
  function()input.WindowFocusReleased:Fire()end,
  function()input.TextBoxFocused:Fire(Instance.new('TextBox'))end,
 }
 for index,interrupt in interruptions do
  reset();reward('Mythical');assert(cinematic.playing)
  local entry=cinematic.history[#cinematic.history];local before=#resultCalls
  interrupt();assert(not cinematic.playing,'interruption retained cinematic '..index)
  finishCinematic(entry);assert(#resultCalls==before,'stale cinematic reopened summary '..index)
 end
 reset()
end)
test('late accepted catch respects an already-open modal without replaying presentation',function()
 for _,open in {function()ui.openJournal()end,function()ui.openSettings()end,function()uiHandlers.openAquarium()end} do
  reset();open()
  local before,history=#resultCalls,#cinematic.history
  reward('Secret')
  assert(#resultCalls==before and #cinematic.history==history,'late reward obscured chosen menu')
 end
 reset()
end)
test('death cancels before CharacterRemoving and delayed rewards stay owned without reopening',function()
 reward('Legendary');assert(cinematic.playing)
 local entry=cinematic.history[#cinematic.history];local summaries=#resultCalls
 humanoid.Health=0;humanoid.Died:Fire()
 assert(not cinematic.playing,'death waited for CharacterRemoving to stop reveal')
 finishCinematic(entry);assert(#resultCalls==summaries,'death completion reopened summary')
 local before=#sends
 press();uiHandlers.castAgain();assert(#sends==before,'dead character started a new cast')
 local history=#cinematic.history
 reward('Secret')
 assert(#resultCalls==summaries and #cinematic.history==history,'delayed catch reopened after death')
 reset()
 local waitPacket=waiting();local held=key();press(held);reeling(waitPacket)
 before=#sends;humanoid.Health=0;humanoid.Died:Fire()
 assert(#sends==before+1 and last('Cancel').argument==waitPacket.attemptId,'death retained active hold')
 ending(held);assert(#sends==before+1,'dead hold later emitted Release')
 reset()
end)
test('late humanoids enable a new character and replaced-character death cannot cancel it',function()
 local lateCharacter=Instance.new('Model');lateCharacter.Parent=workspace
 player.CharacterRemoving:Fire(character)
 player.Character=lateCharacter;player.CharacterAdded:Fire(lateCharacter)
 ack({phase='Idle'})
 local before=#sends;press();assert(#sends==before,'character without Humanoid could fish')
 local lateHumanoid=Instance.new('Humanoid');lateHumanoid.Health=100;lateHumanoid.Parent=lateCharacter
 press();assert(#sends==before+1 and last('BeginCast'),'late Humanoid never enabled casting')
 reset();reward('Mythical');assert(cinematic.playing)
 local stops=cinematic.stops
 lateHumanoid.Health=0;lateHumanoid.Died:Fire()
 assert(cinematic.playing and cinematic.stops==stops,'old character death canceled new reveal')
 reset()
end)
test('character replacement cancels a reveal even without a removal callback',function()
 reward('Mythical');assert(cinematic.playing)
 local entry=cinematic.history[#cinematic.history];local summaries=#resultCalls
 local replacement=Instance.new('Model');replacement.Parent=workspace
 local replacementHumanoid=Instance.new('Humanoid');replacementHumanoid.Health=100;replacementHumanoid.Parent=replacement
 player.Character=replacement;player.CharacterAdded:Fire(replacement)
 assert(not cinematic.playing,'CharacterAdded alone retained previous reveal')
 finishCinematic(entry);assert(#resultCalls==summaries,'replacement reopened old summary')
 local before=#sends;press();assert(#sends==before+1 and last('BeginCast'),'replacement character could not fish')
 reset()
end)
test('local and Roblox reduced motion combine without disabling each other; audio settings apply',function()
 uiHandlers.settingsChanged({reducedEffects=false,soundEnabled=false})
 assert(not audio.enabled and not presentation.reduced and not cinematic.reduced)
 GuiService.ReducedMotionEnabled=true
 assert(presentation.reduced and cinematic.reduced and ui.preferences.systemReducedMotion and not ui.preferences.reducedEffects)
 uiHandlers.settingsChanged({reducedEffects=false,soundEnabled=true})
 assert(audio.enabled and presentation.reduced and cinematic.reduced,'local false overrode Roblox preference')
 local waitPacket=waiting();local held=key();local before=tweenCount;press(held)
 assert(tweenCount==before,'reduced-motion button still animated its press')
 reeling(waitPacket);ending(held);assert(tweenCount==before,'reduced-motion button still animated its release')
 reset()
 uiHandlers.settingsChanged({reducedEffects=true,soundEnabled=true});GuiService.ReducedMotionEnabled=false
 assert(presentation.reduced and cinematic.reduced and ui.preferences.reducedEffects)
 uiHandlers.settingsChanged({reducedEffects=false,soundEnabled=true})
 assert(not presentation.reduced and not cinematic.reduced and not ui.preferences.systemReducedMotion)
 reset()
end)
test('input hints follow active device and prompts/textboxes suppress keyboard conflicts',function()
 input.PreferredInput=Enum.PreferredInput.Touch;frame(0);assert(ui.button.Text=='CAST LINE')
 input.PreferredInput=Enum.PreferredInput.Gamepad;frame(0);assert(ui.button.Text=='CAST LINE  [RT]')
 input.PreferredInput=Enum.PreferredInput.KeyboardAndMouse;frame(0);assert(ui.button.Text=='CAST LINE  [E]')
 local before=#sends
 focused=Instance.new('TextBox');press();assert(#sends==before);focused=nil
 press(nil,true);assert(#sends==before,'processed input cast a line')
 local prompt=Instance.new('ProximityPrompt');prompt.Name='RodWorkshopPrompt'
 prompts.PromptShown:Fire(prompt);press();assert(#sends==before,'prompt E also cast a line')
 prompts.PromptHidden:Fire(prompt)
 local held=key(Enum.KeyCode.ButtonR2);press(held);assert(#sends==before+1 and last('BeginCast'))
 reset()
end)
test('touch casts through the button and authoritative purchases send IDs only',function()
 local before=#sends;local touch=key();touch.UserInputType=Enum.UserInputType.Touch
 ui.button.InputBegan:Fire(touch);assert(#sends==before+1 and last('BeginCast'))
 reset();before=#sends
 uiHandlers.upgrade();assert(#sends==before+1 and last('Upgrade').argument==profile.level)
 ack({phase='Idle'});aquariumHandlers.display('mintfin',2)
 local display=last('Display').argument;assert(display.id=='mintfin' and display.slot==2)
 local fields=0;for _ in display do fields+=1 end;assert(fields==2)
 ack({phase='Idle'});aquariumHandlers.style('coral');assert(last('Style').argument=='coral')
 ack({phase='Idle'});ui.openSettings();aquarium.open();aquariumHandlers.visit()
 assert(travel.visits==1 and not ui.settings and not aquarium.opened)
 reset()
end)
print(passed..' production fishing-controller integration cases passed; native input/networking remain untested')
'''

PREFERENCES_CHECK = r'''
local function frame(dt)step(dt);RunService.RenderStepped:Fire(dt)end
local function key()
 local value=Instance.new('InputObject');value.KeyCode=Enum.KeyCode.E
 value.UserInputType=Enum.UserInputType.Keyboard;value.UserInputState=Enum.UserInputState.Begin
 return value
end
local function prefsAck(sound,reduced,requestId)
 if not requestId then
  for index=#sends,1,-1 do
   if sends[index].verb=='Preferences' then requestId=sends[index].preferenceRequestId;break end
  end
 end
 local profile={level=0,coins=0,rod='Driftwood Rod',species=0,persistent=true,
  preferences={soundEnabled=sound,reducedEffects=reduced}}
 state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now,profile=profile,
  replyTo='Preferences',preferencesChanged=true,preferenceRequestId=requestId})
end
local function last()return sends[#sends]end
local function payload(sound,reduced)
 assert(last().verb=='Preferences','preference save was not dispatched')
 assert(last().argument.soundEnabled==sound and last().argument.reducedEffects==reduced)
 local count=0;for _ in last().argument do count+=1 end
 assert(count==2,'preference request included gameplay data')
end
if bootstrapProfile then
 assert(not audio.enabled and presentation.reduced and cinematic.reduced,'saved quiet preferences were not applied')
 assert(ui.preferences.persistent and not ui.preferences.savePending and not ui.preferences.soundEnabled)
 local before=#sends
 uiHandlers.settingsChanged({soundEnabled=true,reducedEffects=false})
 assert(audio.enabled and not presentation.reduced and ui.preferences.savePending,'local preference was not immediate')
 frame(.39);assert(#sends==before,'preferences were not debounced')
 frame(.02);assert(#sends==before+1);payload(true,false)
 prefsAck(true,false)
 assert(not ui.preferences.savePending and audio.enabled,'accepted preferences remained dirty')
 print('PASS controller preferences: saved mute/reduced load, immediate local choice, debounce and authoritative acceptance')

 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true});frame(.41);payload(false,true)
 uiHandlers.settingsChanged({soundEnabled=true,reducedEffects=false})
 prefsAck(false,true)
 assert(audio.enabled and not presentation.reduced and ui.preferences.savePending,'old preference response overrode a newer choice')
 frame(.41);payload(true,false);prefsAck(true,false)
 assert(not ui.preferences.savePending)
 print('PASS controller preferences: stale acceptance preserves and later saves a newer local choice')

 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true});frame(.41);payload(false,true)
 before=#sends
 local inputObject=key();input.InputBegan:Fire(inputObject,false)
 assert(#sends==before+1 and last().verb=='BeginCast','cosmetic save blocked a cast')
 frame(.08);inputObject.UserInputState=Enum.UserInputState.End;input.InputEnded:Fire(inputObject)
 prefsAck(false,true)
 assert(#sends==before+1,'preference response submitted or canceled an unrelated input')
 state.OnClientEvent:Fire({phase='ChargingCast',attemptId=500,catches=0,nextStart=now,
  castChargeAt=now,castChargeDuration=1,expiresAt=now+2.2,replyTo='BeginCast'})
 assert(last().verb=='QuickCast' and last().argument==500,'preference response lost an early cast release')
 state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now,replyTo='Cancel'})
 print('PASS controller preferences: nonblocking save and independent acknowledgement preserve cast input')

 uiHandlers.settingsChanged({soundEnabled=true,reducedEffects=false});frame(.41);payload(true,false)
 before=#sends
 frame(3.01);assert(#sends==before,'preference timeout triggered game Sync or immediate spam')
 frame(1.01);assert(#sends==before+1);payload(true,false)
 prefsAck(true,false)
 assert(not ui.preferences.savePending)
 print('PASS controller preferences: lost response retries with bounded delay without locking or resynchronizing fishing')

 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true});frame(.41);payload(false,true)
 local oppositeId=last().preferenceRequestId
 uiHandlers.settingsChanged({soundEnabled=true,reducedEffects=false})
 state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now,profile={level=0,coins=0,rod='Driftwood Rod',species=0,persistent=true,
  preferences={soundEnabled=true,reducedEffects=false}},location={zoneId='harbor'}})
 assert(ui.preferences.savePending,'read-only matching snapshot cleared intent while an opposite write was pending')
 prefsAck(false,true,oppositeId)
 assert(ui.preferences.savePending and audio.enabled,'opposite acceptance lost the latest local preference')
 frame(.41);payload(true,false);prefsAck(true,false)
 assert(not ui.preferences.savePending)
 print('PASS controller preferences: read-only matching profile cannot acknowledge an older opposite write')

 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true});frame(.41);payload(false,true)
 local oldId=last().preferenceRequestId
 frame(3.01)
 uiHandlers.settingsChanged({soundEnabled=true,reducedEffects=false});frame(.41);payload(true,false)
 local newerId=last().preferenceRequestId;assert(newerId~=oldId)
 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true})
 prefsAck(false,true,oldId)
 assert(ui.preferences.savePending,'older matching acknowledgement cleared a newer opposite write')
 local before=#sends;frame(.41)
 assert(#sends==before,'old acknowledgement released the newer in-flight request')
 prefsAck(true,false,newerId)
 assert(ui.preferences.savePending and not audio.enabled)
 frame(.41);payload(false,true);prefsAck(false,true)
 assert(not ui.preferences.savePending)
 print('PASS controller preferences: timed-out old acknowledgements cannot clear or release a newer write identity')
else
 assert(not audio.enabled,'default mix played before a returning profile was known')
 uiHandlers.settingsChanged({soundEnabled=false,reducedEffects=true})
 local before=#sends;frame(1);assert(#sends==before,'unloaded profile attempted to save')
 local profile={level=0,coins=0,rod='Driftwood Rod',species=0,persistent=true,
  preferences={soundEnabled=true,reducedEffects=false}}
 state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now,profile=profile,replyTo='Sync'})
 assert(not audio.enabled and presentation.reduced and ui.preferences.savePending,'late load replaced an explicit local choice')
 frame(.01);payload(false,true);prefsAck(false,true)
 assert(not ui.preferences.savePending)
 print('PASS controller preferences: quiet pre-load behavior and explicit local choice survive a late profile')
end
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location(
        "portal_client_scheduler", ROOT / "tools/check_portal_interface.py"
    )
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    scheduler = portal.PREPARE.split("local methods={}")[0]
    program = (
        (ROOT / "tools/preview_roblox.luau").read_text()
        + scheduler
        + PREPARE
        + "\nmodules.FishingRules=(function()\n"
        + (ROOT / "src/shared/FishingRules.luau").read_text()
        + "\nend)();\n(function()\n"
        + (ROOT / "src/client/FishingClient.client.luau").read_text()
        + "\nend)()\n"
    )
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fishing_client.luau"
        path.write_text(program + CHECK)
        subprocess.run([luau, str(path)], check=True)
        for label, fixture in (("saved", "{level=0,coins=0,rod='Driftwood Rod',species=0,persistent=true,preferences={soundEnabled=false,reducedEffects=true}}"),
                               ("before_load", "nil")):
            preference_program = program.replace('local bootstrapProfile=nil -- preference-bootstrap fixture',
                                                 'local bootstrapProfile=' + fixture + ' -- preference-bootstrap fixture')
            preference_path = Path(temporary) / f"preferences_{label}.luau"
            preference_path.write_text(preference_program + PREFERENCES_CHECK)
            subprocess.run([luau, str(preference_path)], check=True)
            if label == "saved":
                needle = 'incoming.preferenceRequestId ~= nil and incoming.preferenceRequestId == preferenceInFlightId'
                assert preference_program.count(needle) == 1
                mutation_path = Path(temporary) / "preferences_unmatched_ack.luau"
                mutation_path.write_text(preference_program.replace(needle, 'true') + PREFERENCES_CHECK)
                mutation = subprocess.run([luau, str(mutation_path)], capture_output=True, text=True)
                assert mutation.returncode != 0 and 'older matching acknowledgement' in mutation.stderr, mutation.stdout + mutation.stderr
                print('PASS controller preferences regression mutation: ignoring write identities loses the latest intent and is rejected')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
