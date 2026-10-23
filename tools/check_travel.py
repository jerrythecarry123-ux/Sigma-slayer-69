#!/usr/bin/env python3
"""Exercise unchanged production island travel with geometry and event doubles.

This checks authorization and yield races, not Roblox replication or physics.
Run: python tools/check_travel.py --luau /path/to/luau
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local function signal()
 local callbacks={}
 return {Connect=function(_,callback)
   table.insert(callbacks,callback)
   return {Disconnect=function() local i=table.find(callbacks,callback); if i then table.remove(callbacks,i) end end}
  end,
  Fire=function(_,...) for _,callback in table.clone(callbacks) do callback(...) end end}
end
local captureIndex=mt.__index
mt.__index=function(self,key)
 if key=="Triggered" or key=="OnServerEvent" or key=="PlayerRemoving" or key=="Heartbeat" then
  if not self.props[key] then self.props[key]=signal() end
  return self.props[key]
 end
 return captureIndex(self,key)
end
local simpleFind=methods.FindFirstChild
function methods:FindFirstChild(name,recursive)
 local direct=simpleFind(self,name)
 if direct or not recursive then return direct end
 for _,child in self:GetDescendants() do if child.Name==name then return child end end
 return nil
end
function methods:FindFirstChildOfClass(class)
 for _,child in self.children do if child:IsA(class) then return child end end
 return nil
end
function methods:IsDescendantOf(ancestor)
 local node=self.Parent
 while node do if node==ancestor then return true end; node=node.Parent end
 return false
end
function CF:ToObjectSpace(cf) return self:Inverse()*cf end
local clientEvents={}
local players
function methods:FireClient(player,status,message)
 assert(player.Parent==players,"message sent to departed player")
 if not clientEvents[player] then clientEvents[player]={} end
 table.insert(clientEvents[player],{status=status,message=message})
end
local pending={}
local function resume(thread)
 local ok,reason=coroutine.resume(thread)
 assert(ok,reason)
end
local task={spawn=function(callback)
 local thread=coroutine.create(callback)
 resume(thread)
 if coroutine.status(thread)=="suspended" then table.insert(pending,thread) end
end}
function methods:RequestStreamAroundAsync(position,timeout)
 assert(timeout>0 and timeout<=3,"unbounded streaming wait")
 self.streamRequest=position
 if self.streamError then error("synthetic network failure") end
 coroutine.yield()
end
players=Instance.new("Players")
players.GetPlayers=function() return players:GetChildren() end
local runService=Instance.new("RunService")
local clock=100
local os={clock=function() return clock end}
local nativeTypeof=typeof
local typeof=function(value) return if getmetatable(value)==CF then "CFrame" else nativeTypeof(value) end
local function heartbeat(dt)
 clock+=dt
 runService.Heartbeat:Fire(dt)
end
local priorService=game.GetService
game.GetService=function(self,name)
 if name=="Players" then return players end
 if name=="RunService" then return runService end
 return priorService(self,name)
end
local world=Instance.new("Model"); world.Name="TravelWorld"; world.Parent=workspace
local callbackCount=0
local function beforeTravel(player)
 assert(player:GetAttribute("IslandTravelBusy")==true,"fishing cancelled before busy guard")
 callbackCount+=1
 return not player.rejectTravel
end
local uid=100
local function makePlayer(source,offsetPivot)
 uid+=1
 local player=Instance.new("Player"); player.UserId=uid; player.Parent=players
 local character=Instance.new("Model"); character.Parent=workspace
 local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Anchored=false; root.Size=Vector3.new(2,2,1)
 root.CFrame=source.PrimaryPart.CFrame*CFrame.new(2,2,0); root.Parent=character
 local humanoid=Instance.new("Humanoid"); humanoid.Health=100; humanoid.HipHeight=2; humanoid.Parent=character
 if offsetPivot then
  local arbitrary=Instance.new("Part"); arbitrary.Name="OffsetPrimary"; arbitrary.CFrame=root.CFrame*CFrame.new(5,4,-3)
  arbitrary.Parent=character; character.PrimaryPart=arbitrary
 else character.PrimaryPart=root end
 player.Character=character
 return player,character,root,humanoid
end
local function status(player)
 local events=clientEvents[player]
 return if events and #events>0 then events[#events].status else nil
end
local function finishPending()
 local threads=pending; pending={}
 for _,thread in threads do resume(thread); assert(coroutine.status(thread)=="dead","worker failed to finish") end
end
'''

CHECK = r'''
local stations=travel.create(world)
assert(travel.create(world)==stations,"duplicate station generation")
local supports=world:FindFirstChild("TravelArrivalSupports")
assert(supports.ModelStreamingMode=="Persistent" and #supports:GetChildren()==5,"arrival support streaming")
local partCount=0
for _,node in world:GetDescendants() do
 if node:IsA("BasePart") then
  partCount+=1
  assert(node.Anchored and not node.CanTouch,"unanchored or touch-heavy travel station")
  if node.CanCollide then assert(node.Parent==supports and node.Transparency==0 and node.Material==Enum.Material.WoodPlanks,"unexpected travel obstruction") end
 end
end
assert(partCount<=350,"travel part budget exceeded")
for _,dock in modules.WorldLayout.Docks do
 local station=stations:FindFirstChild(dock.Id)
 assert(station and station.ModelStreamingMode=="Atomic","missing complete station")
 local prompt=station:FindFirstChild("IslandTravelPrompt",true)
 local castRoot=CFrame.new(table.unpack(dock.Spot))*CFrame.Angles(0,dock.Yaw,0)*CFrame.new(0,3.3,0)
 local arriveRoot=station:GetAttribute("TravelArrivalCFrame")
 assert(typeof(arriveRoot)=="CFrame" and typeof(station:GetAttribute("PortalEntryCFrame"))=="CFrame","missing server-owned portal positions")
 assert((castRoot.Position-station.PrimaryPart.Position).Magnitude>prompt.MaxActivationDistance,"prompt blocks casting")
 assert((arriveRoot.Position-station.PrimaryPart.Position).Magnitude>prompt.MaxActivationDistance,"prompt blocks arrival casting")
 local floor=supports:FindFirstChild(dock.Id.."ArrivalFloor")
 assert(math.abs(floor.Position.Y+floor.Size.Y/2-(dock.Spot[2]-.1))<.0001,"arrival plate surface mismatch")
end
local galleryTarget=CFrame.new(-72,15.3,80)
local function galleryArrival(player)
 if player.galleryFault=="missing" then return nil end
 if player.galleryFault=="invalid" then return "client-forged-position" end
 if player.galleryFault=="error" then error("plot not available") end
 return galleryTarget*CFrame.new((player.UserId%3)*8,0,0)
end
travel.start(world,beforeTravel,galleryArrival)
travel.start(world,beforeTravel)
local remote=ReplicatedStorage:FindFirstChild("FishingTravelRemotes"):FindFirstChild("Travel")
local harbor=stations:FindFirstChild("harbor")
local prompt=harbor:FindFirstChild("IslandTravelPrompt",true)
local checks=0
local function check(name,callback)
 local ok,reason=pcall(callback)
 assert(ok,name..": "..tostring(reason)); checks+=1
end
local function eventCount(player)
 return if clientEvents[player] then #clientEvents[player] else 0
end
check("walking into every portal opens its correct destination menu",function()
 for _,station in stations:GetChildren() do
  local p,_,r=makePlayer(station)
  r.CFrame=station:GetAttribute("PortalEntryCFrame")
  heartbeat(.11)
  assert(status(p)=="Open" and clientEvents[p][1].message==station.Name,"wrong portal opened")
  local count=eventCount(p)
  for _=1,8 do heartbeat(.11) end
  assert(eventCount(p)==count,"standing in a portal repeatedly reopened its menu")
 end
end)
check("ordinary fishing positions and arrivals never auto-open a portal",function()
 for _,dock in modules.WorldLayout.Docks do
  local station=stations:FindFirstChild(dock.Id)
  local p,_,r=makePlayer(station)
  local basis=CFrame.new(table.unpack(dock.Spot))*CFrame.Angles(0,dock.Yaw,0)
  for _,z in {0,3,6,9,12,18} do
   r.CFrame=basis*CFrame.new(0,3.3,z); heartbeat(.11)
   assert(eventCount(p)==0,"ordinary pier route opened a portal")
  end
  for _,lane in {-.8,0,.8} do
   r.CFrame=station:GetAttribute("TravelArrivalCFrame")*CFrame.new(lane,0,0); heartbeat(.11)
   assert(eventCount(p)==0,"arrival immediately reopened the destination menu")
  end
 end
end)
check("leaving and re-entering a portal deliberately reopens its menu",function()
 local p,_,r=makePlayer(harbor)
 local entry=harbor:GetAttribute("PortalEntryCFrame")
 r.CFrame=entry; heartbeat(.51)
 assert(eventCount(p)==1)
 r.CFrame=entry*CFrame.new(0,0,4); heartbeat(.51)
 assert(eventCount(p)==1)
 r.CFrame=entry; heartbeat(.51)
 assert(eventCount(p)==2 and status(p)=="Open")
end)
check("dead or anchored characters cannot walk into a portal",function()
 local p,_,r,h=makePlayer(harbor)
 r.CFrame=harbor:GetAttribute("PortalEntryCFrame"); h.Health=0; heartbeat(.51)
 assert(eventCount(p)==0)
 h.Health=100; r.Anchored=true; heartbeat(.51)
 assert(eventCount(p)==0)
 r.Anchored=false; heartbeat(.51)
 assert(eventCount(p)==1)
end)
check("replacement character resets an occupied portal entry",function()
 local p,_,r=makePlayer(harbor)
 local entry=harbor:GetAttribute("PortalEntryCFrame")
 r.CFrame=entry; heartbeat(.51); assert(eventCount(p)==1)
 local replacement,character,newRoot=makePlayer(harbor)
 replacement.Parent=nil; p.Character=character; newRoot.CFrame=entry
 heartbeat(.51)
 assert(eventCount(p)==2 and status(p)=="Open")
end)
check("player removal clears entry and authorization state",function()
 local p,_,r=makePlayer(harbor)
 r.CFrame=harbor:GetAttribute("PortalEntryCFrame"); heartbeat(.51)
 assert(eventCount(p)==1)
 players.PlayerRemoving:Fire(p); p.Parent=nil
 -- A reused player identifier must not inherit the departed player's menu.
 local replacement,_,newRoot=makePlayer(harbor); replacement.UserId=p.UserId
 remote.OnServerEvent:Fire(replacement,"summit")
 assert(not replacement.streamRequest and eventCount(replacement)==0)
 newRoot.CFrame=harbor:GetAttribute("PortalEntryCFrame"); heartbeat(.51)
 assert(status(replacement)=="Open")
end)
check("walk-in menu authorizes the same checked streaming travel as a prompt",function()
 local p,_,r=makePlayer(harbor)
 r.CFrame=harbor:GetAttribute("PortalEntryCFrame"); heartbeat(.51)
 remote.OnServerEvent:Fire(p,"forest")
 assert(status(p)=="Loading" and #pending==1 and p:GetAttribute("IslandTravelBusy")==true)
 finishPending()
 assert(status(p)=="Arrived" and p:GetAttribute("IslandTravelBusy")==false)
 local count=eventCount(p)
 heartbeat(2)
 assert(eventCount(p)==count,"completed arrival reopened a portal")
end)
check("entering a destination during cooldown opens once when travel is ready",function()
 local p,_,r=makePlayer(harbor)
 r.CFrame=harbor:GetAttribute("PortalEntryCFrame"); heartbeat(.51)
 remote.OnServerEvent:Fire(p,"forest"); finishPending()
 assert(status(p)=="Arrived")
 local count=eventCount(p)
 r.CFrame=stations:FindFirstChild("forest"):GetAttribute("PortalEntryCFrame")
 heartbeat(.11)
 assert(eventCount(p)==count,"cooldown was bypassed by entering the destination portal")
 for _=1,15 do heartbeat(.11) end
 assert(eventCount(p)==count+1 and status(p)=="Open","occupied portal failed to recover after cooldown")
 heartbeat(2)
 assert(eventCount(p)==count+1,"cooldown retry repeatedly reopened an occupied portal")
end)
check("unopened remote cannot move or start loading",function()
 local p,_,r=makePlayer(harbor)
 local original=r.Position
 remote.OnServerEvent:Fire(p,"summit")
 assert(not p.streamRequest and (r.Position-original).Magnitude==0 and status(p)==nil)
end)
check("forged remote positions are rejected",function()
 local p,_,r=makePlayer(harbor)
 prompt.Triggered:Fire(p)
 assert(status(p)=="Open")
 remote.OnServerEvent:Fire(p,{id="cove",position=Vector3.new(0,-900,0)})
 assert(status(p)=="Rejected" and not p.streamRequest)
end)
check("distant native trigger cannot grant a menu",function()
 local p,_,r=makePlayer(harbor); r.CFrame=CFrame.new(900,100,900)
 prompt.Triggered:Fire(p)
 assert(status(p)==nil)
end)
check("leaving source after opening prevents travel",function()
 local p,_,r=makePlayer(harbor)
 prompt.Triggered:Fire(p); r.CFrame=CFrame.new(900,100,900)
 remote.OnServerEvent:Fire(p,"cove")
 assert(status(p)=="Rejected" and not p.streamRequest)
end)
check("server cancellation occurs before streaming starts",function()
 local p,_,r=makePlayer(harbor); p.rejectTravel=true
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"forest")
 assert(status(p)=="Rejected" and not p.streamRequest and p:GetAttribute("IslandTravelBusy")==false)
end)
check("stream failure leaves the character at source and releases busy state",function()
 local p,_,r=makePlayer(harbor); p.streamError=true; local original=r.Position
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"cove")
 assert(status(p)=="Rejected" and (r.Position-original).Magnitude==0 and p:GetAttribute("IslandTravelBusy")==false)
end)
check("every destination lands within immediate fishing range",function()
 for _,dock in modules.WorldLayout.Docks do
  local source=if dock.Id=="harbor" then stations:FindFirstChild("forest") else harbor
  local p,_,r=makePlayer(source,true)
  source:FindFirstChild("IslandTravelPrompt",true).Triggered:Fire(p)
  local before=callbackCount
  remote.OnServerEvent:Fire(p,dock.Id)
  assert(callbackCount==before+1 and status(p)=="Loading" and p:GetAttribute("IslandTravelBusy")==true)
  assert(#pending==1 and p.streamRequest,"stream was not requested before move")
  remote.OnServerEvent:Fire(p,"cove")
  assert(#pending==1,"duplicate request started a second worker")
  finishPending()
  assert(status(p)=="Arrived" and p:GetAttribute("IslandTravelBusy")==false)
  local basis=CFrame.new(table.unpack(dock.Spot))*CFrame.Angles(0,dock.Yaw,0)
  local target=stations:FindFirstChild(dock.Id):GetAttribute("TravelArrivalCFrame")
  local expected=(target*CFrame.new((p.UserId%3-1)*.8,0,0)).Position
  assert((r.Position-expected).Magnitude<.0001,"model pivot offset corrupted root landing")
  assert((r.Position-basis.Position).Magnitude<16,"arrival outside casting range")
  assert(r.AssemblyLinearVelocity.Magnitude==0 and r.AssemblyAngularVelocity.Magnitude==0,"velocity survived travel")
 end
end)
check("death during stream wait cannot teleport",function()
 local p,_,r,h=makePlayer(harbor); local original=r.Position
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"summit"); h.Health=0; finishPending()
 assert(status(p)=="Rejected" and (r.Position-original).Magnitude==0 and p:GetAttribute("IslandTravelBusy")==false)
end)
check("replaced character during stream wait cannot teleport either character",function()
 local p,_,r=makePlayer(harbor); local original=r.Position
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"summit")
 local replacement,character,newRoot=makePlayer(harbor)
 p.Character=character; local newOriginal=newRoot.Position; finishPending()
 assert(status(p)=="Rejected" and (r.Position-original).Magnitude==0 and (newRoot.Position-newOriginal).Magnitude==0)
 assert(p:GetAttribute("IslandTravelBusy")==false)
end)
check("leaving during stream wait invalidates pending work",function()
 local p,_,r=makePlayer(harbor); local original=r.Position
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"summit")
 players.PlayerRemoving:Fire(p); p.Parent=nil; finishPending()
 assert((r.Position-original).Magnitude==0)
end)
check("walking away during stream wait cancels the arrival",function()
 local p,_,r=makePlayer(harbor)
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"summit")
 r.CFrame=CFrame.new(80,20,-80); local moved=r.Position; finishPending()
 assert(status(p)=="Rejected" and (r.Position-moved).Magnitude==0 and p:GetAttribute("IslandTravelBusy")==false)
end)
check("removed world during stream wait prevents arrival",function()
 local p,_,r=makePlayer(harbor); local original=r.Position
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"summit")
 world.Parent=nil; finishPending(); world.Parent=workspace
 assert(status(p)=="Rejected" and (r.Position-original).Magnitude==0)
end)
check("gallery shortcut needs no portal menu and uses only the owned server landing",function()
 local p,_,r=makePlayer(harbor,true)
 r.CFrame=CFrame.new(700,90,700); local original=r.Position
 remote.OnServerEvent:Fire(p,"gallery")
 assert(status(p)=="Loading" and p:GetAttribute("IslandTravelBusy")==true and #pending==1)
 assert((r.Position-original).Magnitude==0,"gallery moved before streaming finished")
 local target=galleryArrival(p)
 assert((p.streamRequest-target.Position).Magnitude<.0001,"client replaced the owned plot target")
 finishPending()
 assert(status(p)=="Arrived" and p:GetAttribute("IslandTravelBusy")==false)
 assert((r.Position-target.Position).Magnitude<.0001,"gallery pivot offset corrupted landing")
 assert(r.AssemblyLinearVelocity.Magnitude==0 and r.AssemblyAngularVelocity.Magnitude==0)
end)
check("gallery pending blocks competing gallery and normal-portal requests",function()
 local p=makePlayer(harbor)
 prompt.Triggered:Fire(p)
 remote.OnServerEvent:Fire(p,"gallery")
 local before=callbackCount
 clock+=.2; remote.OnServerEvent:Fire(p,"gallery")
 clock+=.2; remote.OnServerEvent:Fire(p,"forest")
 assert(#pending==1 and callbackCount==before,"concurrent request replaced gallery work")
 finishPending()
 assert(status(p)=="Arrived" and p:GetAttribute("IslandTravelBusy")==false)
 clock+=.2; remote.OnServerEvent:Fire(p,"gallery")
 assert(status(p)=="Rejected" and #pending==0,"gallery shortcut bypassed its cooldown")
end)
check("normal portal streaming blocks a competing gallery shortcut",function()
 local p=makePlayer(harbor)
 prompt.Triggered:Fire(p); remote.OnServerEvent:Fire(p,"forest")
 local before=callbackCount
 clock+=.2; remote.OnServerEvent:Fire(p,"gallery")
 assert(#pending==1 and callbackCount==before,"gallery bypassed normal pending travel")
 finishPending(); assert(status(p)=="Arrived")
end)
check("missing invalid or throwing gallery callbacks never start streaming",function()
 for _,fault in {"missing","invalid","error"} do
  local p,_,r=makePlayer(harbor); p.galleryFault=fault; local original=r.Position
  remote.OnServerEvent:Fire(p,"gallery")
  assert(status(p)=="Rejected" and not p.streamRequest and not p:GetAttribute("IslandTravelBusy"))
  assert((r.Position-original).Magnitude==0)
 end
end)
check("gallery respects server readiness and living unanchored characters",function()
 local p=makePlayer(harbor); p.rejectTravel=true
 remote.OnServerEvent:Fire(p,"gallery")
 assert(status(p)=="Rejected" and not p.streamRequest and p:GetAttribute("IslandTravelBusy")==false)
 for _,invalid in {"dead","anchored"} do
  local q,_,r,h=makePlayer(harbor)
  if invalid=="dead" then h.Health=0 else r.Anchored=true end
  remote.OnServerEvent:Fire(q,"gallery")
  assert(status(q)=="Rejected" and not q.streamRequest)
 end
end)
check("gallery stream errors keep the player in place and release controls",function()
 local p,_,r=makePlayer(harbor); p.streamError=true; local original=r.Position
 remote.OnServerEvent:Fire(p,"gallery")
 assert(status(p)=="Rejected" and not p:GetAttribute("IslandTravelBusy") and (r.Position-original).Magnitude==0)
end)
check("gallery rechecks death replacement movement departure and world after yielding",function()
 for _,change in {"dead","replacement","move","leave","world"} do
  local p,_,r,h=makePlayer(harbor); local original=r.Position
  remote.OnServerEvent:Fire(p,"gallery"); assert(#pending==1)
  if change=="dead" then h.Health=0
  elseif change=="replacement" then local _,character=makePlayer(harbor);p.Character=character
  elseif change=="move" then r.CFrame=CFrame.new(900,100,900);original=r.Position
  elseif change=="leave" then players.PlayerRemoving:Fire(p);p.Parent=nil
  elseif change=="world" then world.Parent=nil end
  finishPending();world.Parent=workspace
  assert((r.Position-original).Magnitude==0,change.." allowed a stale gallery move")
  if p.Parent==players then assert(status(p)=="Rejected" and p:GetAttribute("IslandTravelBusy")==false) end
 end
end)
check("departed gallery players cannot leave cooldown or pending state for reused IDs",function()
 local p=makePlayer(harbor)
 remote.OnServerEvent:Fire(p,"gallery")
 players.PlayerRemoving:Fire(p);p.Parent=nil;finishPending()
 local replacement=makePlayer(harbor);replacement.UserId=p.UserId
 remote.OnServerEvent:Fire(replacement,"gallery")
 assert(status(replacement)=="Loading" and #pending==1,"departed gallery ticket survived removal")
 finishPending();assert(status(replacement)=="Arrived")
end)
check("visible landing decks remain after portal decoration unloads",function()
 stations.Parent=nil
 assert(#supports:GetChildren()==5 and supports.Parent==world)
 for _,floor in supports:GetChildren() do
  assert(floor.Anchored and floor.CanCollide and floor.CanQuery and floor.Transparency==0,
   "decor unloaded into an invisible or unsupported arrival")
 end
end)
print("Production travel adapter:",checks,"scenario checks;",partCount,"parts; authorization, five destinations, streaming failures and character races passed")
print("These are event/geometry-double checks. Roblox replication, native prompt behavior and landing physics still require Studio.")
'''


def check(luau: str) -> None:
    program = (ROOT / "tools/preview_roblox.luau").read_text()
    program += PREPARE
    for name, source in [
        ("IslandTravelRules", "src/shared/IslandTravelRules.luau"),
        ("WorldPrimitives", "src/server/WorldPrimitives.luau"),
        ("WorldLayout", "src/server/WorldLayout.luau"),
        ("IslandTravel", "src/server/IslandTravel.luau"),
    ]:
        program += "\nmodules." + name + "=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token_{name}=Instance.new("ModuleScript"); token_{name}.Name="{name}"; token_{name}.Parent=shared\n'
    program += "\nlocal travel=modules.IslandTravel\n" + CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_travel.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
