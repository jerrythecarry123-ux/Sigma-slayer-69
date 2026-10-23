#!/usr/bin/env python3
"""Exercise production aquarium geometry, lifecycle and UI with deterministic doubles.

This does not run Roblox rendering, replication, input or physics.
Run: python tools/check_aquarium.py --luau /path/to/luau
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local nativeTypeof=typeof
local typeof=function(value)
 if getmetatable(value)==CF then return "CFrame" end
 if getmetatable(value)==V then return "Vector3" end
 return nativeTypeof(value)
end
local oldIndex,oldNewIndex=mt.__index,mt.__newindex
local events={AttributeChanged=true,ChildAdded=true,ChildRemoved=true,DescendantAdded=true,DescendantRemoving=true,
 MouseEnter=true,MouseLeave=true,Activated=true,CharacterAdded=true}
mt.__index=function(self,key)
 if events[key] then self.props[key]=self.props[key] or signal();return self.props[key] end
 return oldIndex(self,key)
end
local function ancestryEvent(parent,key,node)
 while parent do
  local event=parent.props[key]
  if event then event:Fire(node) end
  parent=parent.Parent
 end
end
mt.__newindex=function(self,key,value)
 local old=self.props[key]
 if key=="Parent" and old~=value and old then
  ancestryEvent(old,"DescendantRemoving",self)
  for _,node in self:GetDescendants() do ancestryEvent(old,"DescendantRemoving",node) end
 end
 oldNewIndex(self,key,value)
 if key=="Parent" and old~=value then
  if old then
   if old.PrimaryPart==self then old.PrimaryPart=nil end
   if old.props.ChildRemoved then old.props.ChildRemoved:Fire(self) end
  end
  if value then
   if value.props.ChildAdded then value.props.ChildAdded:Fire(self) end
   ancestryEvent(value,"DescendantAdded",self)
   for _,node in self:GetDescendants() do ancestryEvent(value,"DescendantAdded",node) end
  end
 end
 if old~=value and self.props["Changed_"..key] then self.props["Changed_"..key]:Fire() end
end
local oldNew=Instance.new
Instance.new=function(class)
 local object=oldNew(class)
 object.AbsoluteSize,object.Visible=Vector2.new(1280,720),true
 return object
end
function methods:Destroy()
 for _,child in table.clone(self.children) do child:Destroy() end
 self.Parent=nil
end
function methods:IsDescendantOf(ancestor)
 local node=self.Parent
 while node do if node==ancestor then return true end;node=node.Parent end
 return false
end
function methods:FindFirstChildWhichIsA(class,recursive)
 for _,child in self.children do if child:IsA(class) then return child end end
 if recursive then for _,child in self:GetDescendants() do if child:IsA(class) then return child end end end
 return nil
end
function methods:GetPropertyChangedSignal(key)
 self.props["Changed_"..key]=self.props["Changed_"..key] or signal()
 return self.props["Changed_"..key]
end
local oldSetAttribute=methods.SetAttribute
function methods:SetAttribute(key,value)
 local old=self:GetAttribute(key)
 oldSetAttribute(self,key,value)
 if old~=value and self.props.AttributeChanged then self.props.AttributeChanged:Fire(key) end
end
-- Keep the reference pivot exact; floating-point matrix multiplication is only
-- an inspection double, not Roblox's internal transform implementation.
local oldPivot=methods.PivotTo
function methods:PivotTo(cf)
 oldPivot(self,cf)
 if self.PrimaryPart then self.PrimaryPart.CFrame=cf end
end
local UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local TweenService={Create=function(_,object,info,values)
 local tween={cancelled=false}
 function tween:Play()task.delay(info[1],function()if self.cancelled then return end;for k,v in values do object[k]=v end end)end
 function tween:Cancel()self.cancelled=true end
 return tween
end}
local players=Instance.new("Players")
local members={}
players.GetPlayers=function()return members end
local heartbeat=signal()
local runService={Heartbeat=heartbeat}
local input={InputBegan=signal(),GamepadEnabled=false}
local guiService={SelectedObject=nil}
local player=Instance.new("Player");player.UserId=1;player.DisplayName="Angler One";player.Parent=players
players.LocalPlayer=player
local pgui=Instance.new("PlayerGui");pgui.Parent=player
local character=Instance.new("Model");character.Parent=workspace;player.Character=character
function methods:GetServerTimeNow()return now end
game.GetService=function(_,name)
 if name=="Players" then return players end
 if name=="RunService" then return runService end
 if name=="UserInputService" then return input end
 if name=="GuiService" then return guiService end
 if name=="TweenService" then return TweenService end
 return ReplicatedStorage
end
workspace.CurrentCamera={CFrame=CFrame.new(-92,17,80)}
local function find(node,name)
 if node.Name==name then return node end
 for _,child in node.children do local found=find(child,name);if found then return found end end
 return nil
end
local function near(a,b)return (a.Position-b.Position).Magnitude<.00001 end
'''

CHECK = r'''
local progression=modules.FishingProgression.new(modules.FishCatalog,function()return .5 end)
local profiles={}
local fresh=progression.create()
local firstCatch=progression.catch(fresh,"Normal","harbor")
profiles[1]=progression.snapshot(fresh)
local second=Instance.new("Player");second.UserId=2;second.DisplayName="<b>Plain name</b>";second.Parent=players
profiles[2]=progression.snapshot(progression.create())
members={player,second}
local world=Instance.new("Folder");world.Name="AquariumTestWorld";world.Parent=workspace
local gallery=modules.AquariumService.start(world,{profile=function(who)return profiles[who.UserId]end})
assert(gallery.arrival(player) and gallery.arrival(second),"existing players were not assigned displays")
local firstModel=gallery.folder:FindFirstChild("Aquarium_1")
assert(firstModel and find(firstModel,"AquariumFish_1"),"first catch did not become a visible aquarium fish")
assert(not find(gallery.folder:FindFirstChild("Aquarium_2"),"AquariumFish_1"),"empty account gained a fictional fish")
for _,node in gallery.folder:GetDescendants() do
 if node:IsA("TextLabel") then assert(node.RichText~=true,"player display names must remain plain text") end
end
gallery.update(player,profiles[1]);assert(gallery.folder:FindFirstChild("Aquarium_1")==firstModel,"unchanged profile rebuilt the display")
local walletOnly=table.clone(profiles[1]);walletOnly.coins+=100
gallery.update(player,walletOnly);assert(gallery.folder:FindFirstChild("Aquarium_1")==firstModel,"wallet update rebuilt unchanged fish")
local beforeArrival=gallery.arrival(second)
local themed=table.clone(profiles[1]);themed.equippedStyle="blossom"
gallery.update(player,themed)
assert(firstModel.Parent==nil and find(gallery.folder:FindFirstChild("Aquarium_1"),"MiniatureBlossomLeaf"),"theme lacks its actual habitat geometry")
assert(near(gallery.arrival(second),beforeArrival),"changing one display moved another player's plot")
local ownerList={player,second}
local full=progression.create()
full.best={pufflet=3,moonray=3,crownwhale=3};full.display={"pufflet","moonray","crownwhale"}
full.records={pufflet=2.2,moonray=9,crownwhale=28};full.variants={crownwhale={Prismatic=true}}
local fullSnapshot=progression.snapshot(full)
for id=3,10 do
 local who=Instance.new("Player");who.UserId=id;who.DisplayName="Angler "..id;who.Parent=players
 table.insert(ownerList,who);gallery.update(who,fullSnapshot)
end
local arrivals={}
for _,who in ownerList do
 local landing=assert(gallery.arrival(who),"missing player plot")
 for _,previous in arrivals do assert((previous-landing.Position).Magnitude>20,"gallery arrivals overlap") end
 table.insert(arrivals,landing.Position)
end
local rowFloors=gallery.folder:FindFirstChild("GallerySafetyFloors")
assert(rowFloors.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,"gallery walking surfaces must persist")
for _,part in rowFloors:GetChildren() do
 assert(part:IsA("BasePart") and part.CanCollide and part.CanQuery,"persistent gallery floor is not physical/queryable")
 assert(part.Transparency==0 and part.Material==Enum.Material.WoodPlanks,"streaming leaves an invisible gallery walkway")
 assert(math.abs(part.Position.Y+part.Size.Y/2-12)<.00001,"gallery floor is not flush with its walking surface")
end
gallery.remove(second);assert(gallery.arrival(second)==nil,"removed player retained a landing")
local replacement=Instance.new("Player");replacement.UserId=11;replacement.DisplayName="New angler";replacement.Parent=players
gallery.update(replacement,fullSnapshot)
assert(near(gallery.arrival(replacement),beforeArrival),"released plot was not reused")
local outsider=Instance.new("Player");outsider.UserId=50
gallery.update(outsider,fullSnapshot);assert(gallery.arrival(outsider)==nil,"departed/nonmember player was assigned a display")
local fake=table.clone(fullSnapshot);fake.display={"undiscovered-id","mintfin","crownwhale"}
gallery.update(player,fake)
local guarded=gallery.folder:FindFirstChild("Aquarium_1")
assert(not find(guarded,"AquariumFish_1") and not find(guarded,"AquariumFish_2") and find(guarded,"AquariumFish_3"),"unknown or unowned display ID rendered a fallback fish")
-- Measure the complete visible fish envelope at actual model poses. This is
-- conservative (box corners for curved parts), and does not test glass rendering.
local boundsSteps=0
for speciesIndex,species in modules.FishCatalog.Species do
 for slot=1,3 do
  local case=table.clone(fullSnapshot)
  case.best,case.display,case.records,case.variants={},{},{},{}
  local nextSpecies=speciesIndex
  for targetSlot=1,3 do
   local selected=if targetSlot==slot then species else modules.FishCatalog.Species[nextSpecies%#modules.FishCatalog.Species+1]
   if targetSlot~=slot then nextSpecies+=1 end
   case.display[targetSlot],case.best[selected.Id],case.records[selected.Id],case.variants[selected.Id]=selected.Id,3,selected.WeightMax,{Prismatic=true}
  end
  gallery.update(player,case)
  local fish=find(gallery.folder:FindFirstChild("Aquarium_1"),"AquariumFish_"..slot)
  local origin=fish:GetAttribute("AquariumSwimOrigin")
  local phase=fish:GetAttribute("AquariumSwimPhase")
  local plot=gallery.arrival(player)*CFrame.Angles(0,-math.pi,0)*CFrame.new(0,-3.3,4)
  for stepIndex=0,60 do
   local time=stepIndex*.237
   fish:PivotTo(origin*CFrame.new(math.sin(time*.65+phase)*.55,math.sin(time*1.1+phase)*.22,math.cos(time*.55+phase)*.3)
     *CFrame.Angles(0,math.sin(time*.55+phase)*.22,math.sin(time*.9+phase)*.025))
   modules.FishModel.animate(fish,time)
   for _,part in fish:GetChildren() do
    if not part:IsA("BasePart") then continue end
    for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
     local corner=plot:PointToObjectSpace(part.CFrame*(part.Size*Vector3.new(x,y,z)*.5))
     assert(math.abs(corner.X)<8.96 and corner.Y>1.55 and corner.Y<8.2 and corner.Z>1.1 and corner.Z<8.9,
      species.Id.." slot "..slot.." clips tank: "..part.Name.." at "..corner.X..","..corner.Y..","..corner.Z)
    end end end
   end
   boundsSteps+=1
  end
 end
end
print("PASS production aquarium: first-catch display, ten independent plots, unchanged-profile cache, themes, cleanup and slot reuse")
print("PASS all 15 species fit the glass at maximum weight across three slots:",boundsSteps,"animated poses")
-- Exercise real UI handlers and its local streamed-fish animator.
local calls={display=0,style=0,visit=0,close=0}
local ui=modules.AquariumInterface.new(pgui,{
 display=function(id,slot)calls.display+=1;calls.id=id;calls.slot=slot end,
 style=function(id)calls.style+=1;calls.styleId=id end,
 visit=function()calls.visit+=1 end,close=function()calls.close+=1 end,
})
local screen=pgui:FindFirstChild("MyAquarium")
local rich=table.clone(fullSnapshot);rich.coins=1000
ui.updateProfile(rich);ui.open()
assert(screen.Enabled and player:GetAttribute("AquariumMenuOpen")==true,"aquarium open did not own its menu attribute")
find(screen,"DisplaySlot3").Activated:Fire();find(find(screen,"OwnedFish"),"pufflet").Activated:Fire()
assert(calls.id=="pufflet" and calls.slot==3,"fish selection changed the wrong slot")
find(find(screen,"TankThemes"),"coral").Activated:Fire();assert(calls.styleId=="coral","theme selection did not send an ID")
for _,size in {{320,530},{568,280},{320,240},{844,335},{768,964},{1920,1040}} do
 screen.AbsoluteSize=Vector2.new(size[1],size[2]);ui.animate(now,size[1],size[2])
 local card=find(screen,"AquariumStudio");local list=find(card,"OwnedFish")
 assert(card.Size.X.Offset<=size[1] and card.Size.Y.Offset<=size[2],"aquarium card exceeds its safe canvas")
 assert(card.Size.Y.Offset+list.Size.Y.Offset>=62,"small screen cannot show a complete tap target")
end
find(screen,"Backdrop").Activated:Fire();assert(not screen.Enabled and player:GetAttribute("AquariumMenuOpen")==false,"close leaked its menu attribute")
local priorFocus=Instance.new("TextButton");priorFocus.Parent=pgui;guiService.SelectedObject=priorFocus;input.GamepadEnabled=true
ui.open();assert(guiService.SelectedObject and guiService.SelectedObject:IsDescendantOf(screen),"gamepad lacks an initial selection")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(not screen.Enabled and guiService.SelectedObject==priorFocus,"gamepad close lost prior focus")
ui.open();find(screen,"AquariumStudio"):GetChildren()
local visit
for _,node in screen:GetDescendants() do if node:IsA("TextButton") and (node.Text=="VISIT TANK" or node.Text=="VISIT MY TANK") then visit=node end end
assert(visit,"visit action missing");visit.Activated:Fire();assert(calls.visit==1 and not screen.Enabled,"visit did not close customization")
ui.open();player.CharacterAdded:Fire(character);assert(not screen.Enabled,"respawn left customization open")
local swimmer=find(gallery.folder:FindFirstChild("Aquarium_3"),"AquariumFish_1")
local swimOrigin=swimmer:GetAttribute("AquariumSwimOrigin")
workspace.CurrentCamera.CFrame=CFrame.new(swimOrigin.Position)
local before=swimmer:GetPivot();now+=.3;heartbeat:Fire(.05)
assert(not near(swimmer:GetPivot(),before),"nearby aquarium fish did not animate")
workspace.CurrentCamera.CFrame=CFrame.new(2000,20,2000);before=swimmer:GetPivot();now+=.4;heartbeat:Fire(.05)
assert(near(swimmer:GetPivot(),before),"distant aquarium fish ignored camera LOD")
-- Attributes and PrimaryPart may arrive independently on a streamed model.
local late=modules.FishModel.create(workspace,"AquariumFish_late","pufflet")
late:SetAttribute("AquariumSwimOrigin",CFrame.new(-12,15,0));late:SetAttribute("AquariumSwimPhase",.5)
workspace.CurrentCamera.CFrame=CFrame.new(-12,15,0);now+=.5;heartbeat:Fire(.05)
assert((late:GetPivot().Position-Vector3.new(-12,15,0)).Magnitude<1,"late attributes never activated a streamed fish")
local body=late.PrimaryPart;body.Parent=nil;local oldPose=late:GetPivot();now+=.3;heartbeat:Fire(.05)
assert(near(late:GetPivot(),oldPose),"fish animated without its replicated root")
body.Parent=late;late.PrimaryPart=body;now+=.4;heartbeat:Fire(.05)
assert((late:GetPivot().Position-Vector3.new(-12,15,0)).Magnitude<1,"returning root did not rebind swimming")
late:SetAttribute("AquariumSwimPhase",0/0);before=late:GetPivot();now+=.5;heartbeat:Fire(.05)
assert(near(late:GetPivot(),before),"nonfinite swim phase reached a model transform")
late:Destroy()
print("PASS production aquarium UI: IDs/slots, themes, six screen sizes, visit/close/respawn, gamepad focus and streamed animation recovery")
local function vec(v)return {v.X,v.Y,v.Z}end
local function encode(v)
 if type(v)=="string" then return string.format("%q",v) end
 if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
 local values={}
 if #v>0 then for _,item in v do table.insert(values,encode(item)) end;return "["..table.concat(values,",").."]" end
 for key,item in v do table.insert(values,encode(key)..":"..encode(item)) end;return "{"..table.concat(values,",").."}"
end
local parts={}
for _,part in gallery.folder:GetDescendants() do
 if part:IsA("BasePart") and part.CanCollide then
  table.insert(parts,{name=part.Name,size=vec(part.Size),position=vec(part.Position),rotation=part.CFrame.r,
   shape=if part:IsA("WedgePart") then "Wedge" else part.Shape,path=part.Name,
   visible=part.Transparency==0,persistent=part:IsDescendantOf(rowFloors)})
 end
end
local points={}
for _,point in arrivals do table.insert(points,vec(point))end
print("SCENE:"..encode({parts=parts,arrivals=points}))
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("portal_check", ROOT / "tools/check_portal_interface.py")
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    program = (ROOT / "tools/preview_roblox.luau").read_text()
    program += portal.PREPARE.split("local methods={}")[0]
    program += PREPARE
    for name, path in (
        ("FishCatalog", "src/shared/FishCatalog.luau"),
        ("FishModel", "src/shared/FishModel.luau"),
        ("WorldPrimitives", "src/server/WorldPrimitives.luau"),
        ("FishingProgression", "src/server/FishingProgression.luau"),
        ("AquariumService", "src/server/AquariumService.luau"),
        ("UITheme", "src/client/UITheme.luau"),
        ("AquariumInterface", "src/client/AquariumInterface.luau"),
    ):
        program += f"\nmodules.{name}=(function()\n" + (ROOT / path).read_text() + "\nend)()\n"
        program += f'local token_{name}=Instance.new("ModuleScript");token_{name}.Name="{name}";token_{name}.Parent=shared\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_aquarium.luau"
        path.write_text(program)
        result = subprocess.run([luau, str(path)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    lines = result.stdout.splitlines()
    scene = json.loads(next(line.removeprefix("SCENE:") for line in lines if line.startswith("SCENE:")))
    for line in lines:
        if not line.startswith("SCENE:"):
            print(line)
    spec = importlib.util.spec_from_file_location("world_check", ROOT / "tools/check_world.py")
    world = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(world)
    colliders = []
    for part in scene["parts"]:
        radii = [sum(abs(part["rotation"][i][j]) * part["size"][j] / 2 for j in range(3)) for i in range(3)]
        colliders.append((part, part["position"][0]-radii[0], part["position"][0]+radii[0],
                          part["position"][2]-radii[2], part["position"][2]+radii[2]))
    count = 0
    floors = [entry for entry in colliders if entry[0]["persistent"] and entry[0]["visible"]]
    assert floors, "gallery has no persistent visible deck"
    for arrival in scene["arrivals"]:
        for dx in (-1.8, -1, 0, 1, 1.8):
            for dz in (-1.8, -1, 0, 1, 1.8):
                x, z = arrival[0]+dx, arrival[2]+dz
                failure = world.walking_surface(colliders, x, 12, z, "aquarium arrival", .1)
                assert failure is None, failure
                floor_failure = world.walking_surface(floors, x, 12, z, "visible streamed aquarium arrival", .1)
                assert floor_failure is None, floor_failure
                count += 1
    routes = [((-48, 80), (-106, 80)), ((-106, 80), (-106, 156))]
    for a, b in routes:
        length = ((b[0]-a[0])**2+(b[1]-a[1])**2)**.5
        side = (-(b[1]-a[1])/length, (b[0]-a[0])/length)
        for step in range(int(length)+1):
            for offset in (-1.3, 0, 1.3):
                x = a[0]+(b[0]-a[0])*step/length+side[0]*offset
                z = a[1]+(b[1]-a[1])*step/length+side[1]*offset
                failure = world.walking_surface(colliders, x, 12, z, "gallery promenade", .1)
                assert failure is None, failure
                floor_failure = world.walking_surface(floors, x, 12, z, "visible streamed gallery promenade", .1)
                assert floor_failure is None, floor_failure
                count += 1
    print(f"PASS {count} actual-collider arrival/promenade samples with visible persistent decks and six-stud headroom")
    print("Geometry/UI/event doubles only; Roblox rendering, replication and device performance still require Studio.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
