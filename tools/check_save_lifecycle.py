#!/usr/bin/env python3
"""Run production Service + ProfileStore with a yielding DataStore transport.

Exercises departure/shutdown races that pure save rules cannot cover. Does not
claim Roblox network, request-budget or live DataStore acceptance.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local clock,guid=1000,0
local os={clock=function()return clock end,time=function()return math.floor(clock)end}
local jobs,warnings={},{}
warn=function(message)table.insert(warnings,tostring(message))end
local function resume(thread,...)
 local ok,delay=coroutine.resume(thread,...);assert(ok,delay)
 if coroutine.status(thread)~='dead' then
  assert(type(delay)=='number' and delay>=0,'unsupported scheduler yield')
  table.insert(jobs,{at=clock+delay,thread=thread})
 end
end
task={}
task.spawn=function(callback,...)resume(coroutine.create(callback),...)end
task.defer=task.spawn
task.delay=function(delay,callback)table.insert(jobs,{at=clock+delay,thread=coroutine.create(callback)})end
task.wait=function(delay)return coroutine.yield(delay or .03)end
local function stepTo(target)
 assert(target>=clock,'test clock moved backwards')
 while true do
  local selected,earliest=nil,math.huge
  for index,job in jobs do if job.at<earliest then selected,earliest=index,job.at end end
  if not selected or earliest>target then break end
  clock=earliest;local job=table.remove(jobs,selected);resume(job.thread)
 end
 clock=target
end
local function step(seconds)stepTo(clock+seconds)end
local function clone(value)
 if type(value)~='table' then return value end
 local result={};for key,item in value do result[key]=clone(item)end;return result
end
local records,requests,saveCalls,sessions={},{},{},{}
local nextDelay,nextFailures=0,0
local storeBackend={}
function storeBackend:UpdateAsync(key,transform)
 local request={key=key,start=clock};table.insert(requests,request)
 local delay=nextDelay;nextDelay=0
 if delay>0 then task.wait(delay) end
 if nextFailures>0 then nextFailures-=1;error('simulated backend outage')end
 local result=transform(clone(records[key]))
 if result~=nil then records[key]=clone(result) end
 request.finish,request.value=clock,clone(result)
 return clone(result)
end
dataStoreService.GetDataStore=function(_,name)
 assert(name=='CloudAnglers_Player_v03','lifecycle check used wrong store namespace')
 return storeBackend
end
httpService.GenerateGUID=function()
 guid+=1;return string.format('00000000-1111-2222-3333-%012x',guid)
end
runService.IsStudio=function()return false end
players.GetPlayers=function()return players:GetChildren()end
workspace.GetServerTimeNow=function()return clock end
function methods:FireClient(player,packet)
 assert(player.Parent==players,'packet sent to departed player')
 player.lastPacket=packet
end
function methods:FireAllClients()end
local simulateBusy,simulateException=false,false
local function spyProfileStore()
 local module=require(server:FindFirstChild('FishingProfileStore'))
 local original=module.new
 module.new=function(...)
  local store=original(...)
  local load,save=store.load,store.save
  store.load=function(userId)
   local session,reason=load(userId)
   if session then sessions[userId]=session end
   return session,reason
  end
  store.save=function(session,profile,release)
   table.insert(saveCalls,{key=session.key,release=release,catches=profile.catches,start=clock})
   if release and simulateBusy then simulateBusy=false;return false,'busy' end
   if release and simulateException then simulateException=false;error('simulated adapter exception')end
   return save(session,profile,release)
  end
  return store
 end
end
local function makePlayer(id)
 local player=Instance.new('Player');player.UserId=id;player.Parent=players
 local character=Instance.new('Model');character.Parent=workspace
 local root=Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=CFrame.new(0,3.3,0);root.Parent=character
 local humanoid=Instance.new('Humanoid');humanoid.Health=100;humanoid.Parent=character
 player.Character=character
 player.Kick=function(_,reason)player.kicked=reason end
 players.PlayerAdded:Fire(player)
 return player
end
local function leave(player)
 players.PlayerRemoving:Fire(player);player.Parent=nil
end
local function command(player,verb,id)
 local event=ReplicatedStorage:FindFirstChild('FishingRemotes'):FindFirstChild('FishingAction')
 event.OnServerEvent:Fire(player,verb,id)
 return player.lastPacket
end
local function catch(player)
 local rules=require(shared:FindFirstChild('FishingRules'))
 local waiting=command(player,'Start',nil)
 assert(waiting and waiting.phase=='Waiting','lifecycle test could not start a cast')
 stepTo(waiting.readyAt)
 local reel=command(player,'Hold',waiting.attemptId)
 assert(reel.phase=='Reeling')
 local closest,finish=math.huge,reel.chargeAt
 for index=0,1000 do
  local candidate=reel.chargeAt+reel.duration*index/1000
  local offset=math.abs(rules.progressAt(reel,candidate)-rules.centerAt(reel,candidate))
  if offset<closest then closest,finish=offset,candidate end
 end
 stepTo(finish)
 local result=command(player,'Release',reel.attemptId)
 assert(result.result and result.result.quality=='Brilliant')
 return result
end
local function heartbeat()runService.Heartbeat:Fire(.11)end
local function countReleaseCalls()
 local count=0;for _,entry in saveCalls do if entry.release then count+=1 end end;return count
end
local cases={}
function cases.clean_departure()
 local player=makePlayer(1);step(1);local earned=catch(player)
 leave(player)
 local saved=assert(records.player_1)
 assert(saved.lease==nil and saved.profile.catches==1 and saved.profile.coins==earned.profile.coins)
 assert(saved.releaseReceipt and sessions[1].closed and countReleaseCalls()==1 and #warnings==0)
 players.PlayerRemoving:Fire(player)
 assert(countReleaseCalls()==1,'repeat departure wrote a second final snapshot')
end
function cases.preferences_departure()
 local player=makePlayer(1);step(1)
 local changed=command(player,'Preferences',{soundEnabled=false,reducedEffects=true})
 assert(changed.preferencesChanged and changed.purchase==nil and changed.result==nil)
 leave(player)
 assert(records.player_1.lease==nil and not records.player_1.profile.preferences.soundEnabled
  and records.player_1.profile.preferences.reducedEffects)
 step(1);local returned=makePlayer(1)
 local restored=command(returned,'Sync',nil)
 assert(restored.profile and not restored.profile.preferences.soundEnabled and restored.profile.preferences.reducedEffects)
 assert(restored.profile.coins==0 and restored.profile.catches==0)
end
function cases.busy_departure()
 local player=makePlayer(1);step(1);catch(player)
 stepTo(1030);nextDelay=30;heartbeat()
 assert(sessions[1].busy,'autosave did not enter a yielding request')
 step(1);local latest=catch(player);local departedAt=clock;leave(player)
 step(21)
 assert(sessions[1].busy and countReleaseCalls()==0 and #warnings==0,
  'departure discarded its latest snapshot at the former 20-second cutoff')
 stepTo(math.max(clock,1061))
 local saved=assert(records.player_1)
 assert(saved.lease==nil and saved.profile.catches==2 and saved.profile.coins==latest.profile.coins)
 assert(sessions[1].closed and countReleaseCalls()==1 and #warnings==0)
 assert(saved.lastSeen>departedAt+20,'regression never waited beyond the old cutoff')
end
function cases.busy_retry()
 local player=makePlayer(1);step(1);local latest=catch(player)
 simulateBusy=true;leave(player);assert(countReleaseCalls()==1 and records.player_1.lease)
 step(.2)
 assert(countReleaseCalls()==2 and sessions[1].closed and records.player_1.lease==nil)
 assert(records.player_1.profile.coins==latest.profile.coins and #warnings==0)
end
function cases.failed_departure()
 local player=makePlayer(1);step(1);catch(player)
 nextFailures=3;leave(player);step(4)
 assert(#warnings==1 and string.find(warnings[1],'unavailable',1,true))
 local finished=false;task.spawn(function()closeCallbacks[1]();finished=true end)
 assert(finished,'failed release leaked pending shutdown ownership')
 assert(records.player_1.lease~=nil,'failed backend fabricated a successful release')
end
function cases.adapter_exception()
 local player=makePlayer(1);simulateException=true;leave(player)
 assert(#warnings==1 and string.find(warnings[1],'adapter exception',1,true))
 local finished=false;task.spawn(function()closeCallbacks[1]();finished=true end)
 assert(finished,'exception leaked the pending-release count')
end
function cases.shutdown_deadline()
 local player=makePlayer(1);step(1);catch(player)
 stepTo(1030);nextDelay=45;heartbeat()
 local began=clock;local finished=false
 task.spawn(function()closeCallbacks[1]();finished=true end)
 step(25.2)
 assert(finished and clock<=began+25.2,'shutdown exceeded its independent25s budget')
 assert(sessions[1].busy and records.player_1.lease~=nil)
 -- The double process is allowed to keep running after the native close budget
 -- solely to inspect whether the held departure snapshot still has an owner.
 stepTo(1076)
 assert(sessions[1].closed and records.player_1.lease==nil and records.player_1.profile.catches==1)
end
function cases.departure_while_loading()
 nextDelay=5;local player=makePlayer(1)
 assert(sessions[1]==nil);leave(player);step(6)
 assert(sessions[1].closed and records.player_1.lease==nil and records.player_1.profile.catches==0)
 assert(countReleaseCalls()==1 and #warnings==0)
end
function cases.shutdown_while_loading()
 nextDelay=5;makePlayer(1)
 local finished=false;task.spawn(function()closeCallbacks[1]();finished=true end)
 step(6)
 assert(finished and sessions[1].closed and records.player_1.lease==nil)
 assert(records.player_1.profile.catches==0 and countReleaseCalls()==1 and #warnings==0)
end
function cases.new_owner_during_stalled_save()
 local player=makePlayer(1);step(1);catch(player)
 stepTo(1030);nextDelay=150;heartbeat();step(1);catch(player);leave(player)
 stepTo(1121)
 local catalog=require(shared:FindFirstChild('FishCatalog'))
 local progression=require(server:FindFirstChild('FishingProgression')).new(catalog,function()return 0 end)
 local newStore=require(server:FindFirstChild('FishingProfileStore')).new(catalog,progression,false)
 local replacement=assert(newStore.load(1));replacement.profile.coins=777
 assert(newStore.save(replacement,replacement.profile,false))
 local newId=replacement.id;stepTo(1181)
 assert(records.player_1.lease.id==newId and records.player_1.profile.coins==777,
  'stalled old autosave or release overwrote a replacement owner')
 assert(not sessions[1].busy and not sessions[1].closed and #warnings==2)
end
'''

CASES = (
    "clean_departure", "preferences_departure", "busy_departure", "busy_retry", "failed_departure",
    "adapter_exception", "shutdown_deadline", "departure_while_loading",
    "shutdown_while_loading", "new_owner_during_stalled_save",
)


def program(case: str, *, legacy_release: bool = False) -> str:
    spec = importlib.util.spec_from_file_location("lifecycle_startup", ROOT / "tools/check_startup.py")
    startup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(startup)
    prepare = startup.PREPARE.replace(
        'ConnectionCount=function() return #callbacks end,',
        'ConnectionCount=function() return #callbacks end,\n'
        '  Fire=function(_,...) for _,callback in table.clone(callbacks) do callback(...) end end,',
    ).replace('Heartbeat=true}', 'Heartbeat=true,CharacterRemoving=true}')
    code = (ROOT / "tools/preview_roblox.luau").read_text() + prepare + PREPARE
    for index, (path, source) in enumerate(startup.production_sources()):
        name = path.rsplit("/", 1)[1]
        folder = "server" if path.startswith("ServerScriptService/") else "shared"
        production_source = (ROOT / source).read_text()
        if legacy_release and name == "FishingService":
            start = production_source.index("\tlocal function release(session: any, profile: any)")
            end = production_source.index("\tlocal function addPlayer(player: Player)", start)
            production_source = production_source[:start] + '''\tlocal function release(session: any, profile: any)
\t\tif not store or session.closed or session.releaseRequested then return end
\t\tsession.releaseRequested = true
\t\tpendingReleases += 1
\t\ttask.spawn(function()
\t\t\tlocal deadline = os.clock() + 20
\t\t\twhile session.busy and os.clock() < deadline do task.wait(0.1) end
\t\t\tlocal ok, reason = store.save(session, profile, true)
\t\t\tif not ok then warn("Cloud Anglers: final save failed: " .. tostring(reason)) end
\t\t\tpendingReleases -= 1
\t\tend)
\tend
''' + production_source[end:]
        code += (
            f'\nlocal token{index}=Instance.new("ModuleScript")\n'
            f'token{index}.Name="{name}";token{index}.Parent={folder}\n'
            f'factories[token{index}]=function()\nlocal script=token{index}\n'
            + production_source + "\nend\n"
        )
    code += startup.CUSTOM_SETUP
    code += '\ncustomSpot:SetAttribute("ZoneId","harbor")\ncustomSpot:SetAttribute("ZoneName","Sundrift Harbor")\n'
    code += '\nspyProfileStore()\nrequire(server:FindFirstChild("FishingService")).start()\n'
    code += f'cases.{case}()\nprint("PASS actual save lifecycle: {case}")\n'
    return code


def check(luau: str) -> None:
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-save-lifecycle-") as temp:
        for case in CASES:
            script = Path(temp) / f"{case}.luau"
            script.write_text(program(case))
            result = subprocess.run([luau, str(script)], capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(case + "\n" + result.stdout + result.stderr)
            for line in result.stdout.splitlines():
                if line.startswith("PASS "):
                    print(line)
        legacy = Path(temp) / "legacy_20_second_cutoff.luau"
        legacy.write_text(program("busy_departure", legacy_release=True))
        result = subprocess.run([luau, str(legacy)], capture_output=True, text=True)
        if result.returncode == 0 or "departure discarded its latest snapshot" not in result.stderr:
            raise RuntimeError("The lifecycle check did not reject the former 20-second release cutoff:\n" + result.stdout + result.stderr)
        print("PASS save lifecycle regression mutation: former 20-second busy cutoff is rejected")
    print(f"{len(CASES)} actual Service/ProfileStore lifecycle cases passed; live Roblox persistence still needs client testing")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
