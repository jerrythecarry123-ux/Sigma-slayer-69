#!/usr/bin/env python3
"""Run the real fishing server and complete client stack through queued RPCs.

Only Roblox services/Instances/transport are doubled. WorldScenery and island
travel are explicitly excluded (their dedicated checks exercise them). Fishing
rules, selection, rewards, controller, UI, fish/rod presentation, audio and catch
cinematics execute from the unchanged production sources. This is not a native
Roblox client, rendering, input, network fairness or performance test.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local nativeTypeof=typeof
local typeof=function(value)
 return if getmetatable(value)==CF then "CFrame" elseif getmetatable(value)==V then "Vector3" else nativeTypeof(value)
end
local os=table.clone(os);os.clock=function()return now end
local originalSignal=signal
signal=function()
 local event=originalSignal();event.flowSignal=true
 function event:Once(callback)
  local connection
  connection=self:Connect(function(...)connection:Disconnect();callback(...)end)
  return connection
 end
 return event
end
local originalIndex,originalNewIndex=mt.__index,mt.__newindex
local events={Changed=true,Activated=true,MouseEnter=true,MouseLeave=true,InputBegan=true,InputEnded=true,
 OnClientEvent=true,OnServerEvent=true,PlayerAdded=true,PlayerRemoving=true,CharacterAdded=true,CharacterRemoving=true,
 Died=true,ChildAdded=true,ChildRemoved=true,DescendantAdded=true,DescendantRemoving=true,AncestryChanged=true,
 AttributeChanged=true,Heartbeat=true,PreSimulation=true,RenderStepped=true,WindowFocusReleased=true,
 TextBoxFocused=true,PromptShown=true,PromptHidden=true,PromptTriggered=true,Ended=true}
mt.__index=function(self,key)
 if events[key] then self.props[key]=self.props[key] or signal();return self.props[key] end
 return originalIndex(self,key)
end
local function descendantsSignal(parent,key,node)
 while parent do
  if parent.props[key] then parent.props[key]:Fire(node) end
  parent=parent.Parent
 end
end
mt.__newindex=function(self,key,value)
 local previous=self.props[key]
 if key=='Parent' and previous~=value and previous then
  descendantsSignal(previous,'DescendantRemoving',self)
  for _,child in self:GetDescendants() do descendantsSignal(previous,'DescendantRemoving',child) end
 end
 originalNewIndex(self,key,value)
 if key=='Parent' and previous~=value then
  if previous then
   if previous.PrimaryPart==self then previous.PrimaryPart=nil end
   if previous.props.ChildRemoved then previous.props.ChildRemoved:Fire(self) end
  end
  if value then
   if value.props.ChildAdded then value.props.ChildAdded:Fire(self) end
   descendantsSignal(value,'DescendantAdded',self)
   for _,child in self:GetDescendants() do descendantsSignal(value,'DescendantAdded',child) end
  end
  if self.props.AncestryChanged then self.props.AncestryChanged:Fire(self,value) end
 end
 if previous~=value then
  if self.props.Changed then self.props.Changed:Fire(if key=='Value' then value else key) end
  if self.props['Property_'..key] then self.props['Property_'..key]:Fire() end
 end
end
local originalNew=Instance.new
Instance.new=function(class)
 local instance=originalNew(class)
 instance.AbsoluteSize,instance.Visible=Vector2.new(1280,720),true
 instance.Enabled=true
 if class=='ScreenGui' then instance.AbsoluteSize=Vector2.new(1280,720) end
 if class=='UIScale' then instance.Scale=1 end
 if class=='NumberValue' or class=='IntValue' then instance.Value=0 end
 if class=='Sound' then instance.IsPlaying=false end
 return instance
end
local simpleFind=methods.FindFirstChild
function methods:FindFirstChild(name,recursive)
 local found=simpleFind(self,name)
 if found or not recursive then return found end
 for _,child in self.children do local item=child:FindFirstChild(name,true);if item then return item end end
 return nil
end
function methods:WaitForChild(name)
 return assert(self:FindFirstChild(name),'missing required child '..self.Name..'.'..name)
end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
 return nil
end
function methods:FindFirstChildWhichIsA(class,recursive)
 local child=self:FindFirstChildOfClass(class)
 if child or not recursive then return child end
 for _,node in self:GetDescendants() do if node:IsA(class) then return node end end
 return nil
end
function methods:IsDescendantOf(parent)
 local current=self.Parent
 while current do if current==parent then return true end;current=current.Parent end
 return false
end
function methods:GetPropertyChangedSignal(key)
 self.props['Property_'..key]=self.props['Property_'..key] or signal()
 return self.props['Property_'..key]
end
function methods:GetAttributeChangedSignal(key)
 self.props['Attribute_'..key]=self.props['Attribute_'..key] or signal()
 return self.props['Attribute_'..key]
end
function methods:SetAttribute(key,value)
 local previous=self.attributes[key];self.attributes[key]=value
 if previous~=value then
  if self.props.AttributeChanged then self.props.AttributeChanged:Fire(key) end
  if self.props['Attribute_'..key] then self.props['Attribute_'..key]:Fire() end
 end
end
function methods:Destroy()
 if self.destroyed then return end
 self.destroyed=true;self.IsPlaying=false
 for _,child in table.clone(self.children) do child:Destroy() end
 self.Parent=nil
end
function methods:Clone()
 local clone=Instance.new(self.ClassName)
 for key,value in self.props do
  if key~='Parent' and key~='destroyed' and key~='IsPlaying'
   and not (type(value)=='table' and value.flowSignal) then clone.props[key]=value end
 end
 for key,value in self.attributes do clone.attributes[key]=value end
 for _,child in self.children do child:Clone().Parent=clone end
 return clone
end
function methods:GetBoundingBox()
 local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,part in self:GetDescendants() do if part:IsA('BasePart') then
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   local point=part.CFrame*(part.Size*Vector3.new(x,y,z)*.5)
   low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
   high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z))
  end end end
 end end
 return CFrame.new((low+high)/2),high-low
end
local originalPivot=methods.PivotTo
function methods:PivotTo(frame)
 originalPivot(self,frame)
 if self.PrimaryPart then self.PrimaryPart.CFrame=frame end
end
local UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local TweenService={Create=function(_,object,info,properties)
 local tween={cancelled=false,Completed=signal()}
 function tween:Play()
  task.delay(info[1],function()
   if self.cancelled or object.destroyed then return end
   for key,value in properties do object[key]=value end
   self.Completed:Fire(Enum.PlaybackState.Completed)
  end)
 end
 function tween:Cancel()self.cancelled=true;self.Completed:Fire(Enum.PlaybackState.Cancelled)end
 return tween
end}
local soundPlays={}
function methods:Play()
 assert(self:IsA('Sound') and not self.destroyed and self.Parent,'played an unavailable sound')
 self.IsPlaying=true
 table.insert(soundPlays,{instance=self,at=now,volume=self.Volume,pitch=self.PlaybackSpeed})
 if not self.Looped then task.delay(.5,function()
  if self.IsPlaying and not self.destroyed then self.IsPlaying=false;self.Ended:Fire() end
 end) end
end
function methods:Stop()self.IsPlaying=false end
local Players=Instance.new('Players')
local player=Instance.new('Player');player.UserId=101;player.Name='FlowTester';player.DisplayName='Flow Tester';player.Parent=Players
Players.LocalPlayer=player
Players.GetPlayers=function()return {player}end
Players.GetPlayerByUserId=function(_,id)return if id==player.UserId and player.Parent==Players then player else nil end
local playerGui=Instance.new('PlayerGui');playerGui.Parent=player
local clientScripts=Instance.new('PlayerScripts');clientScripts.Parent=player
local server=Instance.new('ServerScriptService')
local function makeCharacter()
 local character=Instance.new('Model');character.Parent=workspace
 local root=Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=CFrame.new(0,3.3,0);root.Parent=character
 local hand=Instance.new('Part');hand.Name='RightHand';hand.CFrame=CFrame.new(1.5,5,-.3);hand.Parent=character
 local hum=Instance.new('Humanoid');hum.Health=100;hum.Parent=character
 for _,name in {'RightShoulder','LeftShoulder'} do
  local joint=Instance.new('Motor6D');joint.Name=name;joint.Transform=CFrame.identity;joint.Parent=character
 end
 return character,root,hum
end
local character,characterRoot,humanoid=makeCharacter();player.Character=character
local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(Vector3.new(0,9,21),Vector3.new(0,3,-10))
camera.ViewportSize,camera.FieldOfView,camera.CameraType=Vector2.new(1280,720),70,Enum.CameraType.Custom
workspace.CurrentCamera=camera
local worldCameraFrame=camera.CFrame
workspace.GetServerTimeNow=function()return now end
local RunService=Instance.new('RunService');RunService.IsStudio=function()return true end
local UserInputService=Instance.new('UserInputService')
UserInputService.PreferredInput=Enum.PreferredInput.KeyboardAndMouse
UserInputService.GamepadEnabled=false;UserInputService.TouchEnabled=false
UserInputService.GetFocusedTextBox=function()return nil end
local GuiService=Instance.new('GuiService');GuiService.ReducedMotionEnabled=false
local SoundService=Instance.new('SoundService')
local ProximityPromptService=Instance.new('ProximityPromptService')
local Debris={AddItem=function(_,object,lifetime)task.delay(lifetime,function()object:Destroy()end)end}
local ContentProvider={PreloadAsync=function()end}
local DataStoreService={GetDataStore=function()error('flow test unexpectedly accessed persistence')end}
local HttpService={GenerateGUID=function()error('flow test unexpectedly requested a profile lease')end}
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,RunService=RunService,TweenService=TweenService,
 UserInputService=UserInputService,GuiService=GuiService,SoundService=SoundService,Debris=Debris,
 ContentProvider=ContentProvider,ProximityPromptService=ProximityPromptService,Lighting=Lighting,
 DataStoreService=DataStoreService,HttpService=HttpService}
game.GetService=function(_,name)return assert(services[name],'unsupported native service '..name)end
local closeCallbacks={}
game.BindToClose=function(_,callback)table.insert(closeCallbacks,callback)end
local warn=function(message)error('unexpected production warning: '..tostring(message))end
local factories,loaded,loading,tokens={},{},{},{}
require=function(token)
 assert(token and token:IsA('ModuleScript'),'required a missing/non-module production dependency')
 if loaded[token]~=nil then return loaded[token] end
 assert(not loading[token],'circular dependency '..token.Name)
 loading[token]=true
 local result=assert(factories[token],'unregistered module '..token.Name)()
 assert(result~=nil,'production module returned nil '..token.Name)
 loading[token],loaded[token]=nil,result
 return result
end
local function networkCopy(value)
 if type(value)~='table' or getmetatable(value)~=nil then return value end
 local copy={};for key,item in value do copy[key]=networkCopy(item)end;return copy
end
local clientDelay,serverDelay=.025,.025
local requests,sentStates,receivedStates,visuals={},{},{},{}
function methods:FireServer(...)
 assert(self.Name=='FishingAction','unexpected remote '..self.Name)
 local args=networkCopy(table.pack(...))
 assert(type(args[1])=='string' and args.n==(if args[1]=='Preferences' then 3 else 2),'controller sent an unexpected payload shape')
 if args[1]=='Preferences' then
  assert(type(args[3])=='number' and args[3]%1==0 and args[3]>0 and args[3]<=2147483647,'invalid private preference correlation ID')
 end
 table.insert(requests,{verb=args[1],argument=networkCopy(args[2]),preferenceRequestId=args[3],at=now})
 task.delay(clientDelay,function()self.OnServerEvent:Fire(player,table.unpack(args,1,args.n))end)
end
function methods:FireClient(who,...)
 assert(who==player,'state was sent to an unknown client')
 local args=networkCopy(table.pack(...))
 if self.Name=='FishingState' then table.insert(sentStates,{packet=networkCopy(args[1]),at=now}) end
 task.delay(serverDelay,function()
  if self.Name=='FishingState' then table.insert(receivedStates,{packet=networkCopy(args[1]),at=now}) end
  self.OnClientEvent:Fire(table.unpack(args,1,args.n))
 end)
end
function methods:FireAllClients(...)
 assert(self.Name=='FishingVisual','unexpected broadcast '..self.Name)
 local args=networkCopy(table.pack(...))
 table.insert(visuals,{packet=networkCopy(args[2]),at=now})
 task.delay(serverDelay,function()self.OnClientEvent:Fire(table.unpack(args,1,args.n))end)
end
local function frame(duration)
 step(duration)
 RunService.PreSimulation:Fire(duration)
 RunService.Heartbeat:Fire(duration)
 RunService.RenderStepped:Fire(duration)
 step(0)
end
local function advance(duration)
 local target=now+duration
 while now<target-.0000001 do frame(math.min(.02,target-now))end
end
local function untilTrue(predicate,timeout,label)
 local finish=now+(timeout or 5)
 while not predicate() and now<finish do frame(.01)end
 assert(predicate(),'timed out: '..tostring(label))
end
local function find(node,name)
 if node.Name==name then return node end
 for _,child in node.children do local item=find(child,name);if item then return item end end
 return nil
end
local function text(node,value)
 if node.Text==value then return node end
 for _,child in node.children do local item=text(child,value);if item then return item end end
 return nil
end
local function countNamed(node,name)
 local count=if node.Name==name then 1 else 0
 for _,child in node.children do count+=countNamed(child,name)end
 return count
end
local world=Instance.new('Folder');world.Name='World';world.Parent=workspace
local spot=Instance.new('Part');spot.Name='FishingSpot';spot.Anchored=true;spot.Parent=world
spot:SetAttribute('ZoneId','harbor');spot:SetAttribute('ZoneName','Sundrift Harbor');spot:SetAttribute('WaterY',0)
local actual={}
'''

BOOT = r'''
local config=table.clone(require(tokens.FishingConfig))
config.CreatePrototypeWorld,config.EnableSaving=false,false
loaded[tokens.FishingConfig]=table.freeze(config)
local excluded={}
loaded[tokens.WorldScenery]={start=function()excluded.scenery=true end}
loaded[tokens.IslandTravelInterface]={start=function()excluded.travel=true end,visitGallery=function()return false end}
-- Observe constructors and the controller's public preference-view inputs.
-- Calls still execute unchanged real methods; rewards/profiles are untouched.
for _,name in {'FishingInterface','AquariumInterface','FishingAudio','FishingPresentation','CatchCinematic'} do
 local module=require(tokens[name]);local original=module.new
 module.new=function(...)
  local instance=original(...);actual[name]=instance
  if name=='FishingInterface' then
   local set=instance.setPreferences
   instance.setPreferences=function(value)actual.preferenceView=networkCopy(value);return set(value)end
  end
  return instance
 end
end
require(tokens.FishingService).start()
'''

CHECK = r'''
local passed=0
local function test(name,callback)
 local ok,reason=pcall(callback)
 assert(ok,'FAIL '..name..': '..tostring(reason))
 passed+=1;print('PASS '..name)
end
local gui=assert(playerGui:FindFirstChild('MolnfiskarnaFishing'))
local aquariumGui=assert(playerGui:FindFirstChild('MyAquarium'))
local cineGui=assert(playerGui:FindFirstChild('CatchCinematic'))
local remote=ReplicatedStorage:FindFirstChild('FishingRemotes')
local function state()return receivedStates[#receivedStates] and receivedStates[#receivedStates].packet end
local function serverState()return sentStates[#sentStates] and sentStates[#sentStates].packet end
local function key(code,touch)
 local input=Instance.new('InputObject')
 input.KeyCode,input.UserInputType,input.UserInputState=code or Enum.KeyCode.E,
  if touch then Enum.UserInputType.Touch else Enum.UserInputType.Keyboard,Enum.UserInputState.Begin
 return input
end
local function press(input,touch)
 input=input or key()
 if touch then actual.FishingInterface.button.InputBegan:Fire(input)
 else UserInputService.InputBegan:Fire(input,false)end
 return input
end
local function release(input)
 input.UserInputState=Enum.UserInputState.End
 UserInputService.InputEnded:Fire(input)
end
local function escape()UserInputService.InputBegan:Fire(key(Enum.KeyCode.Escape),false);frame(0)end
local function dismiss()
 if actual.CatchCinematic.isPlaying() then find(cineGui,'SkipCatch').Activated:Fire();frame(0)end
 if actual.FishingInterface.isResultOpen() then
  local close=text(find(gui,'DiscoveryCard'),'×');assert(close);close.Activated:Fire()
 end
 if actual.FishingInterface.isJournalOpen() or actual.FishingInterface.isSettingsOpen() or actual.AquariumInterface.isOpen() then escape()end
 advance(.7)
end
local function beginQuick(touch)
 dismiss()
 local input=key(nil,touch);press(input,touch);advance(.04);release(input)
 untilTrue(function()return state() and state().phase=='Waiting'end,5,'quick cast launch')
 return state()
end
local function beginCharged()
 dismiss()
 local input=press()
 untilTrue(function()return state() and state().phase=='ChargingCast'end,3,'wind-up acknowledgement')
 untilTrue(function()return find(gui,'CastPowerNeedle').Position.X.Scale>=.77 end,2,'power needle')
 release(input)
 untilTrue(function()return state().phase=='Waiting'end,3,'charged cast launch')
 return state()
end
local function reelCatch(waiting)
 untilTrue(function()return now>=waiting.readyAt and state().phase=='Waiting'end,4,'bite')
 local input=press()
 untilTrue(function()return state().phase=='Reeling'end,3,'reeling acknowledgement')
 untilTrue(function()
  local marker=find(gui,'Needle').Position.X.Scale
  local gold=find(find(gui,'TimingTrack'),'Brilliant')
  return marker>=gold.Position.X.Scale+gold.Size.X.Scale*.40
 end,4,'gold release input')
 release(input)
 untilTrue(function()return state().phase=='Idle' and state().result~=nil end,3,'successful real server catch')
 return state()
end
local function wallet()
 for _,child in gui:GetChildren()do if child:IsA('NumberValue') then return child.Value end end
 error('actual wallet counter missing')
end
untilTrue(function()return state() and state().phase=='Idle'end,3,'initial Sync')
test('actual server and complete client subscribe, load profiles and mount real interfaces',function()
 assert(state().replyTo=='Sync' and state().profile.catches==0)
 assert(actual.FishingInterface and actual.AquariumInterface and actual.FishingAudio and actual.FishingPresentation and actual.CatchCinematic)
 for _,name in {'FishingService','FishingEngine','FishingProgression','FishingLocations','FishingRules','FishCatalog','FishModel','UITheme'} do
  assert(loaded[tokens[name]],'complete flow did not load the production '..name)
 end
 assert(excluded.scenery and excluded.travel and wallet()==0)
 assert(text(gui,'JOURNAL  0/17') and find(gui,'CastTrack') and find(gui,'TimingTrack'))
 assert(SoundService:FindFirstChild('CloudAnglersMix') and SoundService:FindFirstChild('CloudAnglersSounds'))
 assert(requests[1].verb=='Sync' and not actual.FishingInterface.isResultOpen())
end)
test('a quick tap crosses real RPCs, catches a fish and updates actual profile, wallet and models',function()
 local waiting=beginQuick()
 assert(waiting.castPower==.65 and waiting.castGrade=='Clean' and waiting.castBonusPercent==0)
 local result=reelCatch(waiting)
 assert(result.result.quality=='Brilliant' and result.result.speciesId=='pufflet' and result.profile.catches==1)
 advance(.7)
 assert(wallet()==result.profile.coins and actual.FishingInterface.isResultOpen())
 assert(text(gui,'JOURNAL  1/17') and find(find(gui,'pufflet'),'Portrait'))
 local fish=find(find(gui,'CatchPortrait'),'Pufflet')
 assert(fish and fish:GetAttribute('SpeciesId')=='pufflet','actual catch portrait was not built')
 assert(result.result.coins+result.result.goalBonus==result.profile.coins)
end)
test('charged input drives the real power meter, bounded target, bonus and coin display once',function()
 local before=state().profile.coins
 local waiting=beginCharged()
 assert(waiting.castGrade=='Perfect' and waiting.castPower>=.72 and waiting.castPower<=.88)
 assert(waiting.castTarget.Z<-14 and waiting.castTarget.Z>=-15.4)
 local result=reelCatch(waiting)
 assert(result.result.castGrade=='Perfect' and result.result.castBonusPercent==10)
 assert(result.profile.coins-before==result.result.coins+result.result.goalBonus)
 advance(.7)
 assert(wallet()==result.profile.coins)
 local earnings='+'..result.result.coins..' coins'..(if result.result.goalBonus>0 then '  +'..result.result.goalBonus..' bonus' else '')
 if result.result.castBonus>0 then earnings..='\nIncludes +'..result.result.castBonus..' cast bonus' end
 assert(text(find(gui,'DiscoveryCard'),earnings),'actual card double-counted cast bonus')
end)
test('touch release before the wind-up reply remains a single convenient cast',function()
 clientDelay,serverDelay=.12,.12
 local before=#requests
 local waiting=beginQuick(true)
 assert(waiting.castGrade=='Clean' and waiting.castPower==.65 and waiting.castBonusPercent==0)
 local starts,launches=0,0
 for index=before+1,#requests do
  if requests[index].verb=='BeginCast' then starts+=1 end
  if requests[index].verb=='QuickCast' then launches+=1 end
 end
 assert(starts==1 and launches==1,'early touch release duplicated a cast request')
 clientDelay,serverDelay=.025,.025
 local result=reelCatch(waiting)
 assert(result.profile.catches==3)
end)
test('actual aquarium handlers change a collected display through the real progression server',function()
 dismiss();text(gui,'MY AQUARIUM').Activated:Fire();frame(0)
 assert(actual.AquariumInterface.isOpen() and player:GetAttribute('AquariumMenuOpen')==true)
 find(aquariumGui,'DisplaySlot1').Activated:Fire()
 find(aquariumGui,'mintfin').Activated:Fire()
 untilTrue(function()return state().profile.display[1]=='mintfin'end,3,'aquarium display acknowledgement')
 local slot=find(aquariumGui,'DisplaySlot1')
 local fish=find(slot,'Mintfin')
 assert(fish and fish:GetAttribute('SpeciesId')=='mintfin','actual aquarium preview did not change')
 escape();assert(not actual.AquariumInterface.isOpen())
end)
test('earned workshop purchase changes the actual gold band and preserves displayed profile',function()
 dismiss()
 text(gui,'JOURNAL  '..state().profile.species..'/17').Activated:Fire()
 text(gui,'Rod workshop').Activated:Fire();frame(0)
 local buy=text(gui,'Upgrade · 32 coins');assert(buy)
 buy.Activated:Fire()
 untilTrue(function()return state().profile.level==1 end,3,'earned rod purchase')
 assert(state().profile.timingWidth==.156 and text(gui,'EQUIPPED · BREEZE ROD'))
 assert(string.find(string.lower(find(gui,'RodTimingBenefit').Text),'gold',1,true),'workshop omits rod control benefit')
 escape()
 local wait=beginQuick()
 assert(wait.timingWidth==.156)
 untilTrue(function()return now>=wait.readyAt end,4,'bite')
 local input=press();untilTrue(function()return state().phase=='Reeling'end,3,'wide reel')
 local gold=find(find(gui,'TimingTrack'),'Brilliant')
 assert(math.abs(gold.Size.X.Scale-.156)<1e-8,'actual UI width disagrees with equipped rod')
 untilTrue(function()return find(gui,'Needle').Position.X.Scale>=gold.Position.X.Scale+gold.Size.X.Scale*.4 end,4,'gold')
 release(input);untilTrue(function()return state().result~=nil and state().phase=='Idle'end,3,'wide rod catch')
end)
test('opening a real menu before a delayed BeginCast reply cancels without a reward or stale overlay',function()
 dismiss();clientDelay,serverDelay=.08,.08
 local catches,coins=state().profile.catches,state().profile.coins
 local input=press()
 find(gui,'SettingsButton').Activated:Fire()
 advance(.7);release(input);advance(.3)
 assert(serverState().phase=='Idle' and serverState().profile.catches==catches and serverState().profile.coins==coins)
 assert(actual.FishingInterface.isSettingsOpen() and not actual.FishingInterface.isResultOpen() and not actual.CatchCinematic.isPlaying())
 escape();clientDelay,serverDelay=.025,.025
end)
test('focus cancellation survives an older delayed cast reply whose bite is already ready',function()
 dismiss();clientDelay,serverDelay=.05,1.45
 local catches,coins=state().profile.catches,state().profile.coins
 local held=press()
 untilTrue(function()return state().phase=='ChargingCast'end,3,'delayed wind-up acknowledgement')
 release(held)
 -- Let Cast reach the server, then lose focus while its Waiting response is
 -- in flight. Cancel is newer, but the older reliable reply arrives first.
 advance(.065)
 UserInputService.WindowFocusReleased:Fire()
 untilTrue(function()return state().phase=='Waiting'end,3,'old Waiting response')
 assert(now>=state().readyAt,'fixture did not cross the stale bite time')
 local before=#requests
 local resumed=press();release(resumed);frame(0)
 assert(#requests==before,'old Waiting discarded the cancellation latch and sent Hold')
 untilTrue(function()return state().phase=='Idle' and state().replyTo=='Cancel'end,3,'cancellation acknowledgement')
 assert(state().profile.catches==catches and state().profile.coins==coins)
 assert(not actual.FishingInterface.isResultOpen() and not actual.CatchCinematic.isPlaying())
 clientDelay,serverDelay=.025,.025
end)
test('actual settings mute existing audio and combine local and Roblox reduced motion',function()
 local catches,coins=state().profile.catches,state().profile.coins
 find(gui,'SettingsButton').Activated:Fire();frame(0)
 find(gui,'SoundToggle').Activated:Fire();find(gui,'ReducedEffectsToggle').Activated:Fire();frame(0)
 assert(not actual.FishingAudio.isEnabled() and SoundService:FindFirstChild('CloudAnglersMix').Volume==0)
 local theme=require(tokens.UITheme);assert(theme.effectsReduced())
 GuiService.ReducedMotionEnabled=true
 find(gui,'ReducedEffectsToggle').Activated:Fire();frame(0)
 assert(theme.effectsReduced(),'local setting disabled Roblox Reduce Motion')
 GuiService.ReducedMotionEnabled=false;frame(0);assert(not theme.effectsReduced())
 find(gui,'ReducedEffectsToggle').Activated:Fire();frame(0);assert(theme.effectsReduced())
 find(gui,'SoundToggle').Activated:Fire();assert(actual.FishingAudio.isEnabled())
 escape()
 untilTrue(function()return state().replyTo=='Preferences' and state().preferencesChanged end,2,'private settings acknowledgement')
 assert(state().profile.preferences.soundEnabled and state().profile.preferences.reducedEffects)
 assert(state().profile.coins==coins and state().profile.catches==catches and not state().result and not state().purchased)
 assert(find(gui,'PreferencesStatus').Text=='Applies to this Studio visit.','settings imply persistence in a saving-disabled Studio session')
 for _,entry in visuals do
  assert(entry.packet.preferences==nil and entry.packet.profile==nil and entry.packet.preferencesChanged==nil and entry.packet.preferenceRequestId==nil,'preferences escaped the private response')
 end
end)
test('a real private preferences reply preserves an early cast release while both responses are in flight',function()
 dismiss();clientDelay,serverDelay=.025,.35
 local catches,coins=state().profile.catches,state().profile.coins
 local beforePreferences=#requests
 find(gui,'SettingsButton').Activated:Fire()
 find(gui,'SoundToggle').Activated:Fire();frame(0)
 assert(not actual.FishingAudio.isEnabled(),'real local mute waited for its server response')
 escape()
 untilTrue(function()return #requests>beforePreferences and requests[#requests].verb=='Preferences'end,1,'debounced preference request')
 local preferenceRequest=requests[#requests]
 assert(preferenceRequest.argument.soundEnabled==false and preferenceRequest.argument.reducedEffects==true)
 assert(type(preferenceRequest.preferenceRequestId)=='number')
 local fields=0;for _ in preferenceRequest.argument do fields+=1 end
 assert(fields==2,'preferences request carried gameplay or save data')
 advance(.03) -- The server accepts Preferences while its Idle response is in flight.
 assert(serverState().replyTo=='Preferences' and serverState().preferencesChanged and serverState().preferenceRequestId==preferenceRequest.preferenceRequestId)
 local before=#requests
 local held=press();advance(.04);release(held)
 assert(#requests==before+1 and requests[#requests].verb=='BeginCast','saving preferences blocked a new cast')
 untilTrue(function()return state().replyTo=='Preferences' and state().profile.preferences.soundEnabled==false end,1,'delayed private settings response')
 assert(#requests==before+1,'settings acknowledgement launched or cancelled an unrelated held input')
 assert(not actual.FishingAudio.isEnabled() and state().profile.catches==catches and state().profile.coins==coins)
 untilTrue(function()return state().phase=='Waiting'end,2,'early release surviving private response')
 assert(requests[#requests].verb=='QuickCast' and state().castPower==.65 and state().castBonusPercent==0)
 assert(state().profile.preferences.soundEnabled==false and state().profile.preferences.reducedEffects==true)
 clientDelay,serverDelay=.025,.025
 local result=reelCatch(state())
 assert(result.profile.catches==catches+1,'preferences acknowledgement lost or duplicated the real catch')
end)
test('a real passive profile cannot mark preferences settled while the opposite write is in flight',function()
 dismiss()
 assert(not actual.FishingAudio.isEnabled() and state().profile.preferences.soundEnabled==false)
 local catches,coins=state().profile.catches,state().profile.coins
 local before=#requests
 -- A genuine server location update captures the current quiet choice before
 -- the next preference write. Its delayed response then crosses local edits.
 serverDelay=.8
 spot:SetAttribute('ZoneId','cove');spot:SetAttribute('ZoneName','Petal Cove')
 untilTrue(function()return serverState().location and serverState().location.zoneId=='cove'end,1,'passive location snapshot')
 local passive=serverState()
 assert(passive.replyTo==nil and passive.profile.preferences.soundEnabled==false)
 find(gui,'SettingsButton').Activated:Fire();find(gui,'SoundToggle').Activated:Fire();frame(0)
 untilTrue(function()return #requests>before and requests[#requests].verb=='Preferences'end,1,'opposite preference write')
 local opposite=requests[#requests]
 assert(opposite.argument.soundEnabled==true)
 find(gui,'SoundToggle').Activated:Fire();frame(0)
 untilTrue(function()return state().location and state().location.zoneId=='cove' and state().replyTo==nil end,1,'older passive profile delivered')
 assert(not actual.FishingAudio.isEnabled(),'passive profile overrode the immediate local choice')
 assert(actual.preferenceView.savePending==true,'ordinary profile equality prematurely cleared the pending write')
 untilTrue(function()return state().replyTo=='Preferences' and state().preferenceRequestId~=opposite.preferenceRequestId and state().profile.preferences.soundEnabled==false end,3,'corrective settings acknowledgement')
 assert(not actual.FishingAudio.isEnabled() and serverState().profile.preferences.soundEnabled==false)
 assert(state().profile.catches==catches and state().profile.coins==coins)
 escape();serverDelay=.025
 spot:SetAttribute('ZoneId','harbor');spot:SetAttribute('ZoneName','Sundrift Harbor');advance(.3)
end)
test('a timed-out older acknowledgement cannot release a newer opposite preference write',function()
 dismiss()
 assert(not actual.FishingAudio.isEnabled() and state().profile.preferences.soundEnabled==false)
 local catches,coins=state().profile.catches,state().profile.coins
 find(gui,'SettingsButton').Activated:Fire()
 local before=#requests
 serverDelay=5
 find(gui,'SoundToggle').Activated:Fire();frame(0)
 untilTrue(function()return #requests>before and requests[#requests].verb=='Preferences'end,1,'first slow settings write')
 local first=requests[#requests]
 advance(.03) -- The first acknowledgement is now queued for five seconds.
 assert(serverState().preferenceRequestId==first.preferenceRequestId and serverState().profile.preferences.soundEnabled==true)
 serverDelay=2.4
 find(gui,'SoundToggle').Activated:Fire();frame(0)
 untilTrue(function()return #requests>before+1 and requests[#requests].verb=='Preferences'end,4.5,'timeout retry with the opposite choice')
 local opposite=requests[#requests]
 assert(opposite.preferenceRequestId~=first.preferenceRequestId and opposite.argument.soundEnabled==false)
 advance(.03) -- Keep response order: first true, then this false, then final true.
 assert(serverState().preferenceRequestId==opposite.preferenceRequestId and serverState().profile.preferences.soundEnabled==false)
 serverDelay=.025
 find(gui,'SoundToggle').Activated:Fire();frame(0)
 untilTrue(function()return state().replyTo=='Preferences' and state().preferenceRequestId==first.preferenceRequestId end,2,'old matching acknowledgement')
 assert(actual.FishingAudio.isEnabled(),'old response overrode the latest local sound choice')
 assert(actual.preferenceView.savePending==true,'old matching acknowledgement falsely settled the newer opposite write')
 local pendingCount=#requests
 advance(.6)
 assert(#requests==pendingCount,'old acknowledgement released the newer write and sent another request before its response')
 untilTrue(function()return state().replyTo=='Preferences' and state().preferenceRequestId~=first.preferenceRequestId and state().preferenceRequestId~=opposite.preferenceRequestId and state().profile.preferences.soundEnabled==true end,3,'final current choice accepted')
 assert(serverState().profile.preferences.soundEnabled==true and actual.FishingAudio.isEnabled())
 assert(state().profile.catches==catches and state().profile.coins==coins)
 assert(find(gui,'PreferencesStatus').Text=='Applies to this Studio visit.')
 escape()
end)
test('death before character removal cancels real fishing and a replacement can fish again',function()
 local waiting=beginQuick();untilTrue(function()return now>=waiting.readyAt end,4,'bite')
 local held=press();untilTrue(function()return state().phase=='Reeling'end,3,'death reel')
 local catches,coins=state().profile.catches,state().profile.coins
 humanoid.Health=0;humanoid.Died:Fire();release(held);advance(.5)
 assert(serverState().phase=='Idle' and serverState().profile.catches==catches and serverState().profile.coins==coins)
 assert(not actual.FishingInterface.isResultOpen() and not actual.CatchCinematic.isPlaying())
 player.CharacterRemoving:Fire(character);character:Destroy()
 character,characterRoot,humanoid=makeCharacter();player.Character=character;player.CharacterAdded:Fire(character)
 advance(.8)
 local result=reelCatch(beginQuick())
 assert(result.profile.catches==catches+1,'replacement character could not resume')
end)
-- Earn the next rod by actual catches, then change the authored custom pond's
-- habitat. Selection, rarity and rewards still come from actual server code.
local function buyNextRod()
 dismiss()
 text(gui,'JOURNAL  '..state().profile.species..'/17').Activated:Fire()
 text(gui,'Rod workshop').Activated:Fire();frame(0)
 local cost=state().profile.nextUpgrade.cost
 local buy=text(gui,'Upgrade · '..cost..' coins');assert(buy)
 buy.Activated:Fire()
 local level=state().profile.level
 untilTrue(function()return state().profile.level==level+1 end,3,'next rod')
 escape()
end
test('a genuine earned Epic catch runs actual reduced cinematic and skip without duplicate rewards',function()
 while state().profile.coins<90 do reelCatch(beginQuick())end
 buyNextRod();assert(state().profile.level==2)
 spot:SetAttribute('ZoneId','summit');spot:SetAttribute('ZoneName','Starfall Lookout');advance(.2)
 local result
 for _=1,6 do
  result=reelCatch(beginQuick())
  if result.result.rarity=='Epic' then break end
 end
 assert(result.result.rarity=='Epic' and result.result.speciesId=='aurorafin','actual protected discovery did not produce the eligible Epic')
 assert(actual.CatchCinematic.isPlaying() and cineGui.Enabled and not actual.FishingInterface.isResultOpen())
 local world=find(cineGui,'PortraitWorld');local model=world:GetChildren()[1]
 assert(model and model:GetAttribute('SpeciesId')==result.result.speciesId)
 local pose=model:GetPivot();advance(.1)
 assert((model:GetPivot().Position-pose.Position).Magnitude<1e-8,'reduced stage still flew')
 local count,coins,catches=#requests,state().profile.coins,state().profile.catches
 find(cineGui,'SkipCatch').Activated:Fire();frame(0);advance(.05)
 assert(not actual.CatchCinematic.isPlaying() and actual.FishingInterface.isResultOpen())
 assert(#requests==count and state().profile.coins==coins and state().profile.catches==catches)
 -- Replay the exact accepted state as a duplicate delivery, not a fake reward.
 remote:FindFirstChild('FishingState').OnClientEvent:Fire(networkCopy(result));frame(0)
 assert(not actual.CatchCinematic.isPlaying() and wallet()==coins)
 assert(workspace.CurrentCamera==camera and camera.CFrame==worldCameraFrame and camera.CameraType==Enum.CameraType.Custom)
end)
print(string.format('%d complete production fishing-flow scenarios passed; %d real RPC requests and %d delivered state packets',passed,#requests,#receivedStates))
print('Native services/transport are doubles; world scenery and travel are explicitly excluded. Roblox rendering, input, audio and network fairness remain untested.')
'''


def assemble() -> str:
    spec = importlib.util.spec_from_file_location("flow_portal_scheduler", ROOT / "tools/check_portal_interface.py")
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    spec = importlib.util.spec_from_file_location("flow_place_builder", ROOT / "tools/build_place.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    code = (ROOT / "tools/preview_roblox.luau").read_text()
    code += portal.PREPARE.split("local methods={}")[0] + PREPARE
    client_source = None
    for index, (path, (kind, source)) in enumerate(builder.SOURCES.items()):
        name = path.rsplit("/", 1)[1]
        if kind == "LocalScript":
            client_source = source
            continue
        if kind != "ModuleScript":
            continue
        parent = "server" if path.startswith("ServerScriptService/") else "clientScripts" if path.startswith("StarterPlayer/") else "shared"
        code += (
            f'\nlocal token{index}=Instance.new("ModuleScript");token{index}.Name="{name}";token{index}.Parent={parent}\n'
            f'tokens.{name}=token{index}\nfactories[token{index}]=function()\nlocal script=token{index}\n'
            + (ROOT / source).read_text() + "\nend\n"
        )
    assert client_source is not None
    code += BOOT + '\n;(function()\nlocal script={Parent=clientScripts}\n'
    code += (ROOT / client_source).read_text() + "\nend)()\n" + CHECK
    return code


def check(luau: str, keep_program: Path | None = None) -> None:
    code = assemble()
    if keep_program:
        keep_program.write_text(code)
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-flow-") as temp:
        path = Path(temp) / "check.luau"
        path.write_text(code)
        result = subprocess.run([luau, str(path)], text=True, capture_output=True, timeout=90)
        if result.returncode == 0:
            # A value-only match can mistake an old true acknowledgement for
            # completion while a newer false write still owns the response.
            # Verify the integrated race catches that original data-loss bug.
            nonce_guard = "incoming.preferenceRequestId ~= nil and incoming.preferenceRequestId == preferenceInFlightId"
            assert code.count(nonce_guard) == 1
            mutation_path = Path(temp) / "unmatched_preference_ack.luau"
            mutation_path.write_text(code.replace(nonce_guard, "true"))
            mutation = subprocess.run([luau, str(mutation_path)], text=True, capture_output=True, timeout=90)
            assert mutation.returncode != 0 and "old matching acknowledgement falsely settled" in mutation.stderr, mutation.stdout + mutation.stderr
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    print(result.stdout, end="")
    print("PASS integrated regression mutation: treating an older preference response as the current write is rejected")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    parser.add_argument("--keep-program", type=Path)
    args = parser.parse_args()
    check(args.luau, args.keep_program)
