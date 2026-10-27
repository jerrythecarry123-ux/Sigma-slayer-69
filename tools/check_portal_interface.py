#!/usr/bin/env python3
"""Exercise the unchanged production portal interface with UI/event/tween doubles.

Checks protocol timing, cancellation, and movement recovery. These are deterministic
smoke checks; Roblox rendering, native input and PlayerModule behavior need Studio.
Run: python tools/check_portal_interface.py --luau /path/to/luau
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREPARE = r'''
local scheduled,now={},0
local task={}
local function spawn(fn,...)
 local th=coroutine.create(fn)
 local ok,err=coroutine.resume(th,...); assert(ok,err)
end
function task.spawn(fn,...) spawn(fn,...) end
function task.defer(fn) spawn(fn) end
function task.delay(dt,fn) table.insert(scheduled,{at=now+dt,fn=fn}) end
local function step(dt)
 local target=now+dt
 while true do
  local index,at=nil,math.huge
  for i,job in scheduled do if job.at<at then index,at=i,job.at end end
  if not index or at>target then break end
  now=at; local job=table.remove(scheduled,index); spawn(job.fn)
 end
 now=target
end
local function signal()
 local callbacks,waiters={},{}
 return {Connect=function(_,fn)
  table.insert(callbacks,fn)
  return {Disconnect=function() local i=table.find(callbacks,fn);if i then table.remove(callbacks,i) end end}
 end, Wait=function() table.insert(waiters,coroutine.running());return coroutine.yield() end,
 Fire=function(_,...) 
  for _,fn in table.clone(callbacks) do fn(...) end
  local prior=waiters;waiters={}
  for _,th in prior do local ok,err=coroutine.resume(th,...);assert(ok,err) end
 end}
end
local methods={}
local mt={}
function mt.__index(self,k)
 if methods[k] then return methods[k] end
 if k=='Activated' or k=='InputBegan' or k=='CharacterAdded' or k=='CharacterRemoving' or k=='OnClientEvent' or k=='Died' then
  self.props[k]=self.props[k] or signal()
 end
 return self.props[k]
end
function mt.__newindex(self,k,v)
 if k=='Parent' then
  local old=self.props.Parent
  if old then local i=table.find(old.children,self);if i then table.remove(old.children,i) end end
  if v then table.insert(v.children,self) end
 end
 self.props[k]=v
end
local Instance={new=function(class) return setmetatable({props={ClassName=class,Name=class,AbsoluteSize={X=1280,Y=720}},children={},attrs={}},mt) end}
function methods:IsA(class) return self.ClassName==class end
function methods:FindFirstChild(name)
 for _,child in self.children do if child.Name==name then return child end end
 return nil
end
function methods:WaitForChild(name,timeout) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
end
function methods:IsDescendantOf(node)
 local at=self.Parent
 while at do if at==node then return true end;at=at.Parent end
 return false
end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:GetPropertyChangedSignal(k) self.props['Changed'..k]=self.props['Changed'..k] or signal();return self.props['Changed'..k] end
function methods:Move(v) self.moves=(self.moves or 0)+1 end
local Enum=setmetatable({}, {__index=function(self,k)
 local value=setmetatable({}, {__index=function(_,v) return k..'.'..v end});rawset(self,k,value);return value
end})
local function dim(...) return {...} end
local UDim,UDim2,Vector2={new=dim},{new=dim,fromScale=dim,fromOffset=dim},{new=dim,zero={0,0}}
local Vector3={zero={0,0,0}}
local Color3={fromRGB=dim}
local TweenInfo={new=dim}
local tweenCount=0
local TweenService={Create=function(_,object,info,values)
 tweenCount+=1
 local tween={Completed=signal(),cancelled=false}
 function tween:Play()
  task.delay(info[1],function()
   if self.cancelled then return end
   for k,v in values do object[k]=v end
   self.Completed:Fire(Enum.PlaybackState.Completed)
  end)
 end
 function tween:Cancel() self.cancelled=true;self.Completed:Fire(Enum.PlaybackState.Cancelled) end
 return tween
end}
local player=Instance.new('Player')
local pgui=Instance.new('PlayerGui');pgui.Parent=player
local scripts=Instance.new('PlayerScripts');scripts.Parent=player
local pm=Instance.new('ModuleScript');pm.Name='PlayerModule';pm.Parent=scripts
local char=Instance.new('Model')
local hum=Instance.new('Humanoid');hum.Parent=char
player.Character=char
local controls={controlsEnabled=true,disableCount=0,enableCount=0}
function controls:Disable() self.controlsEnabled=false;self.disableCount+=1 end
function controls:Enable() self.controlsEnabled=true;self.enableCount+=1 end
local reps=Instance.new('ReplicatedStorage')
local shared=Instance.new('Folder');shared.Name='FishingShared';shared.Parent=reps
local rulesmodule=Instance.new('ModuleScript');rulesmodule.Name='IslandTravelRules';rulesmodule.Parent=shared
local remotes=Instance.new('Folder');remotes.Name='FishingTravelRemotes';remotes.Parent=reps
local event=Instance.new('RemoteEvent');event.Name='Travel';event.Parent=remotes
local sends={}
function event:FireServer(...)
 assert(select('#',...)==1 and type((...))=='string','client sent position or extra payload')
 if self.sendError then error('synthetic transport failure') end
 table.insert(sends,(...))
end
local GuiService={SelectedObject=nil}
local input=Instance.new('UserInputService');input.GamepadEnabled=false
local services={Players={LocalPlayer=player},ReplicatedStorage=reps,UserInputService=input,GuiService=GuiService,TweenService=TweenService}
local game={GetService=function(_,k) return services[k] end}
local Rules=productionRules
local require=function(module) if module==pm then return {GetControls=function()return controls end} end;assert(module==rulesmodule);return Rules end
'''
CHECK = r'''
assert(ui.visitGallery()==false,'gallery began before the travel interface mounted')
ui.start();ui.start()
local gui=pgui:FindFirstChild('IslandTravel')
local function find(root,name)
 if root.Name==name then return root end
 for _,child in root.children do local result=find(child,name);if result then return result end end
end
local button=find(gui,'blossom');local close=find(gui,'Close');local cover=find(gui,'PortalTransition');local banner=find(gui,'Arrival')
local card=find(gui,'DestinationCard')
assert(card.SelectionGroup==true,'portal card has no native gamepad selection boundary')
for _,direction in {'Up','Down','Left','Right'} do
 assert(card['SelectionBehavior'..direction]==Enum.SelectionBehavior.Stop,
  'portal permits directional selection outside its modal card: '..direction)
end
local function open()
 event.OnClientEvent:Fire('Open','harbor')
 assert(gui.Enabled and player:GetAttribute('IslandTravelMenuOpen') and not controls.controlsEnabled,'menu did not lock controls')
end
open();button.Activated:Fire();assert(#sends==0,'sent before cover');step(.1);assert(#sends==0)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape},false);step(.1)
assert(#sends==0 and controls.controlsEnabled and not gui.Enabled,'cancelled covering still sent or trapped controls')
open();button.Activated:Fire();step(.159)
assert(#sends==0 and not controls.controlsEnabled,'sent before the full .16-second cover')
step(.002)
assert(#sends==1 and sends[1]=='blossom' and cover.BackgroundTransparency==0,'travel sent uncovered/wrong payload')
for _,channel in cover.BackgroundColor3 do assert(channel<=22,'portal transition is a bright flash') end
close.Activated:Fire();assert(gui.Enabled and not controls.controlsEnabled,'pending closed/unlocked too soon')
event.OnClientEvent:Fire('Loading','Getting ready');step(.1)
event.OnClientEvent:Fire('Arrived','Ready');assert(not controls.controlsEnabled,'revealed before transition')
step(.199);assert(not controls.controlsEnabled,'released movement before .2-second reveal')
step(.002)
assert(controls.controlsEnabled and not player:GetAttribute('IslandTravelMenuOpen') and banner.Visible,'arrival did not restore/show name')
assert(find(gui,'PondName').Text=='Petalwind Grove','wrong arrival name')
step(1.4);assert(not gui.Enabled and not banner.Visible,'arrival banner persisted')
open();button.Activated:Fire();step(.161);event.OnClientEvent:Fire('Rejected','Not ready');step(.201)
assert(controls.controlsEnabled and gui.Enabled and not cover.Visible,'rejection trapped controls/cover')
assert(find(gui,'Status').Text=='Not ready','missing server rejection');close.Activated:Fire();assert(not gui.Enabled)
open();button.Activated:Fire();hum.Died:Fire();step(.2)
assert(#sends==2 and controls.controlsEnabled and not gui.Enabled,'death before send failed cancellation')
open();button.Activated:Fire();step(.161);player.CharacterRemoving:Fire(char);step(9)
assert(controls.controlsEnabled and not gui.Enabled,'death pending stranded controls')
open();button.Activated:Fire();step(.161);step(8.3)
assert(controls.controlsEnabled and gui.Enabled and not cover.Visible,'timeout trapped controls')
close.Activated:Fire();event.OnClientEvent:Fire('Arrived','Late');assert(not gui.Enabled,'late reply reopened closed portal')
controls.controlsEnabled=false;event.OnClientEvent:Fire('Open','harbor');close.Activated:Fire()
assert(controls.controlsEnabled==false,'portal enabled another systems disabled controls')
-- An old timeout must not terminate a later journey. A delayed arrival-banner
-- callback must not hide a newly opened menu. Both are production generations.
controls.controlsEnabled=true
open();button.Activated:Fire();step(.161);event.OnClientEvent:Fire('Arrived','Ready');step(.201)
event.OnClientEvent:Fire('Open','harbor');step(1.5)
assert(gui.Enabled and not controls.controlsEnabled,'old banner callback closed a new menu')
button.Activated:Fire();step(.161);step(6.1)
assert(cover.Visible and not controls.controlsEnabled,'old timeout interrupted later journey')
event.OnClientEvent:Fire('Arrived','Ready');step(.201);step(1.4)
-- Repeated server Opens while a request is pending cannot replace its destination.
open();button.Activated:Fire();step(.161)
event.OnClientEvent:Fire('Open','forest');event.OnClientEvent:Fire('Arrived','Ready');step(.201)
assert(find(gui,'PondName').Text=='Petalwind Grove','repeated Open replaced the pending journey')
step(1.4)
-- A new character invalidates a covered-but-unsent request.
open();button.Activated:Fire();local count=#sends
local replacement=Instance.new('Model');local newHumanoid=Instance.new('Humanoid');newHumanoid.Parent=replacement
player.Character=replacement;player.CharacterAdded:Fire(replacement);step(.3)
assert(#sends==count and controls.controlsEnabled and not gui.Enabled,'respawn leaked deferred send')
-- Death after sending also restores movement and ignores a late server reply.
open();button.Activated:Fire();step(.161);newHumanoid.Died:Fire();event.OnClientEvent:Fire('Arrived','Late');step(.3)
assert(controls.controlsEnabled and not gui.Enabled,'pending death or late arrival restored an old transition')
-- A native FireServer failure follows the same recovery path as rejection.
open();event.sendError=true;button.Activated:Fire();step(.4);event.sendError=false
assert(controls.controlsEnabled and gui.Enabled and not cover.Visible,'transport exception stranded player')
close.Activated:Fire()
-- Gamepad navigation selects a usable destination, then restores the old focus.
local oldSelection=Instance.new('TextButton');oldSelection.Parent=pgui
GuiService.SelectedObject=oldSelection;input.GamepadEnabled=true
open();assert(GuiService.SelectedObject==button,'gamepad did not select an available pond')
assert(GuiService.SelectedObject:IsDescendantOf(card),'portal selected a control outside its selection group')
input.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(GuiService.SelectedObject==oldSelection and controls.controlsEnabled and not gui.Enabled,'gamepad close lost focus or movement')
-- Direct gallery visits use the same cover, cancellation and control lifecycle,
-- without pretending that a physical portal opened a destination menu first.
input.GamepadEnabled=false
local beforeGallery=#sends
assert(ui.visitGallery() and not controls.controlsEnabled,'gallery did not start from closed phase')
assert(not find(gui,'Backdrop').Visible,'gallery flashed a destination menu before covering')
step(.1);input.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape},false);step(.2)
assert(#sends==beforeGallery and controls.controlsEnabled and not gui.Enabled,'cancelled gallery request leaked')
assert(ui.visitGallery());step(.159);assert(#sends==beforeGallery,'gallery sent before cover')
step(.002)
assert(#sends==beforeGallery+1 and sends[#sends]=='gallery' and cover.BackgroundTransparency==0,'gallery did not send a covered ID-only request')
assert(not ui.visitGallery(),'gallery replaced a pending request')
event.OnClientEvent:Fire('Open','forest');event.OnClientEvent:Fire('Arrived','Gallery ready');step(.201)
assert(controls.controlsEnabled and find(gui,'PondName').Text=='Aquarium Gallery','gallery arrival restored the wrong journey')
assert(find(gui,'Ready').Text=='YOUR COLLECTION ON DISPLAY','gallery arrival claimed the player was at a fishing pier')
step(1.4)
assert(ui.visitGallery());step(.161);newHumanoid.Died:Fire();event.OnClientEvent:Fire('Arrived','Late');step(.3)
assert(controls.controlsEnabled and not gui.Enabled,'gallery death/late arrival stranded controls')
assert(ui.visitGallery());step(.161);event.OnClientEvent:Fire('Rejected','Plot not ready');step(.201)
assert(controls.controlsEnabled and find(gui,'Status').Text=='Plot not ready','gallery rejection was not recoverable')
close.Activated:Fire()
assert(ui.visitGallery());step(.161);step(8.3)
assert(controls.controlsEnabled and not cover.Visible,'gallery timeout stranded its cover')
close.Activated:Fire()
print('PASS production portal interface: dark-cover send timing, ID-only payload, arrival reveal and movement restoration')
print('PASS cancellation before send, pending-close guard, death/respawn, rejection, transport failure and timeout recovery')
print('PASS repeated Open, late arrival, stale timeout/banner callbacks and pre-disabled controls ownership')
print('PASS native portal selection-group/Stop contract and owned gamepad focus restoration; directional engine navigation remains untested')
print('PASS direct gallery shortcut: no menu flash, covered ID-only send, pending exclusion and death/rejection/timeout recovery')
print('UI/event/tween doubles only; actual rendering, native input and PlayerModule integration still require Studio.')
'''
def check(luau: str) -> None:
    rules = (ROOT / "src/shared/IslandTravelRules.luau").read_text()
    interface = (ROOT / "src/client/IslandTravelInterface.luau").read_text()
    program = "local productionRules=(function()\n" + rules + "\nend)()\n"
    program += PREPARE
    program += "\nlocal ui=(function()\n" + interface + "\nend)()\n" + CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_portal_interface.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
