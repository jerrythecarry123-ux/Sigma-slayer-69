#!/usr/bin/env python3
"""Run production server startup with geometry/event doubles, not the Roblox engine.

Checks that the generated Folder world actually starts island travel through
FishingService, rather than calling the travel adapter directly. Also verifies
custom-map startup and proves the former Model-only guard fails this check.

Run: python tools/check_startup.py --luau /path/to/luau
"""
import argparse
import importlib.util
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
   return {Disconnect=function()
    local index=table.find(callbacks,callback)
    if index then table.remove(callbacks,index) end
   end}
  end,
  ConnectionCount=function() return #callbacks end,
 }
end
local captureIndex=mt.__index
local eventNames={Triggered=true,OnServerEvent=true,PlayerAdded=true,PlayerRemoving=true,Heartbeat=true}
mt.__index=function(self,key)
 if eventNames[key] then
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
 local cursor=self.Parent
 while cursor do if cursor==ancestor then return true end; cursor=cursor.Parent end
 return false
end
local players=Instance.new("Players")
local nativeTypeof=typeof
local typeof=function(value) return if getmetatable(value)==CF then "CFrame" else nativeTypeof(value) end
players.GetPlayers=function() return {} end
local runService=Instance.new("RunService")
runService.IsStudio=function() return true end
local server=Instance.new("ServerScriptService")
local dataStoreService=Instance.new("DataStoreService")
dataStoreService.GetDataStore=function() error("startup unexpectedly accessed a DataStore",0) end
local httpService=Instance.new("HttpService")
httpService.GenerateGUID=function() error("startup unexpectedly requested a save session",0) end
local services={
 Players=players,RunService=runService,ReplicatedStorage=ReplicatedStorage,
 ServerScriptService=server,Lighting=Lighting,DataStoreService=dataStoreService,HttpService=httpService,
}
game.GetService=function(_,name) return assert(services[name],"unsupported startup service: "..name) end
local closeCallbacks={}
game.BindToClose=function(_,callback) table.insert(closeCallbacks,callback) end
local function unexpectedTask() error("empty Studio startup unexpectedly scheduled task work",0) end
local task={spawn=unexpectedTask,defer=unexpectedTask,delay=unexpectedTask,wait=unexpectedTask}
local warn=function(message) error("unexpected startup warning: "..tostring(message),0) end
local factories,loaded,loading={},{},{}
require=function(token)
 assert(token and token:IsA("ModuleScript"),"startup tried to require a missing module")
 if loaded[token]~=nil then return loaded[token] end
 assert(not loading[token],"circular module dependency: "..token.Name)
 loading[token]=true
 local factory=assert(factories[token],"module is not included in the place: "..token.Name)
 local value=factory()
 assert(value~=nil,"module returned nil: "..token.Name)
 loaded[token],loading[token]=value,nil
 return value
end
'''

COMMON_CHECK = r'''
local fishing=ReplicatedStorage:FindFirstChild("FishingRemotes")
assert(fishing and fishing:IsA("Folder"),"startup: fishing remotes were not published")
for _,name in {"FishingAction","FishingState","FishingVisual"} do
 local event=fishing:FindFirstChild(name)
 assert(event and event:IsA("RemoteEvent"),"startup: missing fishing remote "..name)
end
assert(fishing:FindFirstChild("FishingAction").OnServerEvent:ConnectionCount()==1,"startup: fishing handler was not connected exactly once")
assert(players.PlayerAdded:ConnectionCount()==1,"startup: player join handler was not connected")
assert(#closeCallbacks==1,"startup: final save handler was not registered")
'''

GENERATED_CHECK = r'''
local world=workspace:FindFirstChild("MolnfiskarnaPrototype")
assert(world and world:IsA("Folder"),"startup: expected the real generated Folder world")
local remotes=ReplicatedStorage:FindFirstChild("FishingTravelRemotes")
assert(remotes and remotes:IsA("Folder"),"startup: travel remotes were not published")
assert(runService.Heartbeat:ConnectionCount()==2,"startup: fishing and portal-entry heartbeats were not connected")
local event=remotes:FindFirstChild("Travel")
assert(event and event:IsA("RemoteEvent"),"startup: travel remote is missing")
assert(event.OnServerEvent:ConnectionCount()==1,"startup: travel remote handler was not connected")
local stations=world:FindFirstChild("IslandTravelStations")
assert(stations and #stations:GetChildren()==5,"startup: five travel stations were not created")
local expected={harbor=true,blossom=true,forest=true,cove=true,summit=true}
local connected=0
for _,station in stations:GetChildren() do
 assert(expected[station.Name],"startup: unexpected station "..station.Name)
 expected[station.Name]=nil
 local prompt=station:FindFirstChild("IslandTravelPrompt",true)
 assert(prompt and prompt:IsA("ProximityPrompt"),"startup: station has no prompt")
 assert(prompt.Triggered:ConnectionCount()==1,"startup: station prompt was not connected")
 connected+=1
end
assert(connected==5 and next(expected)==nil,"startup: incomplete destination wiring")
assert(players.PlayerRemoving:ConnectionCount()==2,"startup: travel and fishing cleanup handlers must both be connected")
local supports=world:FindFirstChild("TravelArrivalSupports")
assert(supports and supports.ModelStreamingMode==Enum.ModelStreamingMode.Persistent and #supports:GetChildren()==5,
 "startup: travel landing supports were not created")
assert(#waterWrites==5,"startup: native ponds were not generated")
local gallery=world:FindFirstChild("AquariumGallery")
assert(gallery and gallery:IsA("Folder"),"startup: aquarium gallery was not installed")
local galleryFloors=gallery:FindFirstChild("GallerySafetyFloors")
assert(galleryFloors and galleryFloors.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,
 "startup: gallery floors must persist before players arrive")
assert(#galleryFloors:GetChildren()==2,"startup: empty gallery needs access and first-row support")
for _,child in gallery:GetChildren() do
 assert(not child:GetAttribute("AquariumPlot"),"startup: empty gallery created a fake player aquarium")
end
print("PASS generated Folder-world startup: fishing, five portals, walk-in detection, aquarium gallery and persistent landing supports are connected")
'''

CUSTOM_SETUP = r'''
local configToken=shared:FindFirstChild("FishingConfig")
local customConfig=table.clone(require(configToken))
customConfig.CreatePrototypeWorld=false
loaded[configToken]=table.freeze(customConfig)
local customWorld=Instance.new("Folder");customWorld.Name="World";customWorld.Parent=workspace
local customSpot=Instance.new("Part");customSpot.Name="FishingSpot";customSpot.Anchored=true;customSpot.Parent=customWorld
'''

CUSTOM_CHECK = r'''
assert(workspace:FindFirstChild("MolnfiskarnaPrototype")==nil,"custom startup unexpectedly generated the prototype")
assert(ReplicatedStorage:FindFirstChild("FishingTravelRemotes")==nil,"custom startup unexpectedly installed island travel")
assert(runService.Heartbeat:ConnectionCount()==1,"custom startup needs only the fishing heartbeat")
assert(players.PlayerRemoving:ConnectionCount()==1,"custom startup needs only fishing cleanup")
assert(#waterWrites==0,"custom startup unexpectedly wrote native terrain")
print("PASS custom-map startup: fishing starts without generated scenery or island travel")
'''


def production_sources():
    spec = importlib.util.spec_from_file_location("startup_place_builder", ROOT / "tools/build_place.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    return [
        (path, relative_source)
        for path, (class_name, relative_source) in builder.SOURCES.items()
        if class_name == "ModuleScript"
        and path.startswith(("ReplicatedStorage/FishingShared/", "ServerScriptService/"))
    ]


def assemble(*, custom: bool = False, legacy_guard: bool = False) -> str:
    program = (ROOT / "tools/preview_roblox.luau").read_text() + PREPARE
    for index, (path, relative_source) in enumerate(production_sources()):
        name = path.rsplit("/", 1)[1]
        folder = "server" if path.startswith("ServerScriptService/") else "shared"
        source = (ROOT / relative_source).read_text()
        if legacy_guard and name == "FishingService":
            guard = "\t\tif world then\n\t\t\taquarium = Aquarium.start(world,"
            assert source.count(guard) == 1, "The legacy-guard mutation must target the production travel startup branch"
            source = source.replace(guard, "\t\tif world and world:IsA(\"Model\") then\n\t\t\taquarium = Aquarium.start(world,", 1)
        program += (
            f'\nlocal startupToken{index}=Instance.new("ModuleScript")\n'
            f'startupToken{index}.Name="{name}";startupToken{index}.Parent={folder}\n'
            f'factories[startupToken{index}]=function()\nlocal script=startupToken{index}\n'
            + source + "\nend\n"
        )
    if custom:
        program += CUSTOM_SETUP
    program += '\nrequire(server:FindFirstChild("FishingService")).start()\n'
    program += COMMON_CHECK + (CUSTOM_CHECK if custom else GENERATED_CHECK)
    return program


def check(luau: str) -> None:
    with tempfile.TemporaryDirectory() as temporary:
        for name, custom, legacy_guard in [
            ("generated", False, False),
            ("custom", True, False),
            ("legacy_guard_regression", False, True),
        ]:
            path = Path(temporary) / (name + ".luau")
            path.write_text(assemble(custom=custom, legacy_guard=legacy_guard))
            result = subprocess.run([luau, str(path)], capture_output=True, text=True)
            if legacy_guard:
                if result.returncode == 0 or "startup: travel remotes were not published" not in result.stderr:
                    raise RuntimeError("The startup check did not reject the former Model-only guard:\n" + result.stdout + result.stderr)
                print("PASS regression mutation: the former Model-only guard fails the generated-world startup check")
            else:
                if result.returncode:
                    raise RuntimeError(result.stdout + result.stderr)
                for line in result.stdout.splitlines():
                    if line.startswith("PASS "):
                        print(line)
    print("Production startup with geometry/event doubles only; Roblox replication and client rendering still require Studio.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
