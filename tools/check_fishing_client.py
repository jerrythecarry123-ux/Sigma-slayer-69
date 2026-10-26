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
function action:FireServer(...)
 assert(select('#',...)==2,'controller sent unexpected extra payload')
 local verb,argument=...
 assert(type(verb)=='string','non-string client command')
 table.insert(sends,{verb=verb,argument=argument,time=now})
 if not bootstrapResponse and verb=='Sync' then
  bootstrapResponse=true
  -- An immediate response is deliberately harsher than real network delivery:
  -- subscribing after Sync would lose it and leave the interface Connecting.
  state.OnClientEvent:Fire({phase='Idle',catches=0,nextStart=now})
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
modules.FishingAudio={new=function()return audio end}
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
local function reeling(waitPacket)
 return ack({phase='Reeling',attemptId=waitPacket.attemptId,chargeAt=now+.3,duration=2.8,
  timingCenter=.60,timingMotion={amplitude=.055,speed=2.2,phase=.8}})
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
 assert(travel.starts==1 and ui.preferences.soundEnabled and audio.enabled)
 assert(not presentation.reduced and not cinematic.reduced)
 ack({phase='Idle',location={zoneId='forest'}})
 assert(ui.phase=='Idle' and ui.profile==profile and aquarium.profile==profile and ui.location.zoneId=='forest')
 visual.OnClientEvent:Fire(42,{phase='Waiting'})
 assert(#presentation.applied==1 and presentation.applied[1][1]==42)
 frame(0);assert(ui.viewport[2]==1280 and ui.viewport[3]==720)
end)
test('Start is single while pending and Hold is forbidden before the bite',function()
 local before=#sends
 press();last('Start');press();assert(#sends==before+1,'pending Start duplicated')
 local waitPacket=waiting(1.4)
 press();assert(#sends==before+1,'Hold sent before bite')
 frame(.7);assert(ui.button.Text=='WATCH THE FLOAT','waiting anticipation phase absent')
 frame(.71);press();assert(last('Hold').argument==waitPacket.attemptId)
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
  assert(math.abs(ui.center-center)<1e-9 and ui.window==.14,'target drift differs from rules')
  assert(math.abs(ui.marker.Position.X.Scale-progress)<1e-9,'marker differs from rules')
  local quality=modules.FishingRules.qualityAt(progress,center)
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
  ack({phase='Waiting',attemptId=waitPacket.attemptId,readyAt=now})
  assert(#sends==before+1 and last('Cancel').argument==waitPacket.attemptId,'late Waiting reopened a modal cast')
  press();assert(#sends==before+1,'modal allowed another fishing input')
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
 press();assert(#sends==before+1 and last('Start'),'late Humanoid never enabled casting')
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
 local before=#sends;press();assert(#sends==before+1 and last('Start'),'replacement character could not fish')
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
 local held=key(Enum.KeyCode.ButtonR2);press(held);assert(#sends==before+1 and last('Start'))
 reset()
end)
test('touch casts through the button and authoritative purchases send IDs only',function()
 local before=#sends;local touch=key();touch.UserInputType=Enum.UserInputType.Touch
 ui.button.InputBegan:Fire(touch);assert(#sends==before+1 and last('Start'))
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
        + CHECK
    )
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fishing_client.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
