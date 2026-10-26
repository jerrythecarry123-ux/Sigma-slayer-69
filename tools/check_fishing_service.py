#!/usr/bin/env python3
"""Exercise the production fishing network adapter with event/geometry doubles.

This runs actual progression, rules, engine and server service together. It does
not simulate Roblox transport latency, native input, replication or DataStores.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

CHECK = r'''
local clock=0
workspace.GetServerTimeNow=function() return clock end
players.GetPlayers=function() return players:GetChildren() end
task.spawn=function(callback) callback() end
local received,public={},{}
function methods:FireClient(player,packet,latePacket)
 assert(player.Parent==players,"state sent to departed player")
 if latePacket then packet=latePacket end
 if not received[player] then received[player]={} end
 table.insert(received[player],packet)
end
function methods:FireAllClients(userId,packet)
 table.insert(public,{userId=userId,packet=packet})
end
local function makePlayer(id)
 local player=Instance.new("Player");player.UserId=id;player.Parent=players
 local character=Instance.new("Model");character.Parent=workspace
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.CFrame=CFrame.new(0,3.3,0);root.Parent=character
 local humanoid=Instance.new("Humanoid");humanoid.Health=100;humanoid.Parent=character
 player.Character=character
 players.PlayerAdded:Fire(player)
 return player,root,humanoid
end
local fishing=ReplicatedStorage:FindFirstChild("FishingRemotes")
local command=fishing:FindFirstChild("FishingAction")
local function latest(player) local list=received[player];return if list then list[#list] else nil end
local function send(player,verb,id,time)
 clock=time
 command.OnServerEvent:Fire(player,verb,id)
 return latest(player)
end
local function goldTime(packet)
 local rules=require(shared:FindFirstChild("FishingRules"))
 local distance,time=math.huge,packet.chargeAt
 for index=0,10000 do
  local candidate=packet.chargeAt+packet.duration*index/10000
  local offset=math.abs(rules.progressAt(packet,candidate)-rules.centerAt(packet,candidate))
  if offset<distance then distance,time=offset,candidate end
 end
 return time
end
local p,root,humanoid=makePlayer(11)
local first=send(p,"Sync",nil,0)
assert(first.phase=="Idle" and first.profile.catches==0 and first.profile.coins==0)
local a=send(p,"Start",nil,1)
assert(a.phase=="Waiting" and a.profile.catches==0 and a.result==nil)
assert(a.castAt==1 and a.castDuration< a.readyAt-a.castAt and a.duration==2.8)
assert(a.reservedId==nil and a.speciesId==nil and a.profile.persistent==false)
local visible=public[#public].packet
assert(visible.castAt==a.castAt and visible.castDuration==a.castDuration and visible.duration==a.duration)
assert(visible.readyAt==a.readyAt and visible.timingCenter==a.timingCenter and visible.behavior==a.behavior)
assert(visible.profile==nil and visible.reservedId==nil and visible.speciesId==nil,"private profile/selection escaped through public visual")
local held=send(p,"Hold",a.attemptId,a.readyAt)
assert(held.phase=="Reeling" and held.chargeAt>held.readyAt)
local caught=send(p,"Release",a.attemptId,goldTime(held))
assert(caught.result.quality=="Brilliant" and caught.result.speciesId and caught.profile.catches==1)
assert(caught.catches==1 and caught.result.zoneId=="forest")
assert(public[#public].packet.result.speciesId==caught.result.speciesId)
assert(public[#public].packet.profile==nil)
local coins,count=caught.profile.coins,#received[p]
send(p,"Release",a.attemptId,clock+.1)
assert(#received[p]==count,"replayed Release emitted another reward")
assert(send(p,"Sync",nil,clock+.2).profile.coins==coins)
local waiting=send(p,"Start",nil,clock+2)
root.Position=Vector3.new(100,3.3,0)
clock+=.11;runService.Heartbeat:Fire(.11)
local stopped=latest(p)
assert(stopped.phase=="Idle" and stopped.profile.catches==1 and stopped.result==nil)
assert(send(p,"Release",waiting.attemptId,clock+.2).profile.catches==1)
root.Position=Vector3.new(0,3.3,0)
waiting=send(p,"Start",nil,clock+2)
p:SetAttribute("IslandTravelBusy",true)
clock+=.11;runService.Heartbeat:Fire(.11)
assert(latest(p).phase=="Idle" and latest(p).result==nil,"travel-busy did not abort fishing")
p:SetAttribute("IslandTravelBusy",false)
waiting=send(p,"Start",nil,clock+2)
p.CharacterRemoving:Fire(p.Character)
assert(latest(p).phase=="Idle" and latest(p).result==nil,"character replacement did not abort fishing")
waiting=send(p,"Start",nil,clock+2)
humanoid.Health=0
clock+=.11;runService.Heartbeat:Fire(.11)
assert(latest(p).phase=="Idle" and latest(p).profile.catches==1)
humanoid.Health=100
waiting=send(p,"Start",nil,clock+2)
local other=makePlayer(22)
local before=#public
send(other,"Sync",nil,clock+.1)
assert(#public==before+1 and public[#public].userId==22,"Sync duplicated an existing player's global cast effects")
-- The joining client receives the existing player's active cast via FireClient.
local active=latest(other)
assert(active.castAt==waiting.castAt and active.phase=="Waiting" and active.profile==nil)
assert(active.duration and active.behavior and active.reservedId==nil and active.speciesId==nil)
players.PlayerRemoving:Fire(p);p.Parent=nil
local total=#received[p]
command.OnServerEvent:Fire(p,"Release",waiting.attemptId)
assert(#received[p]==total,"departed player retained a rewarding session")
local skilled=makePlayer(33)
local motionSeen=false
for _=1,9 do
 local waitPacket=send(skilled,"Start",nil,clock+3)
 local reelPacket=send(skilled,"Hold",waitPacket.attemptId,waitPacket.readyAt)
 if reelPacket.timingMotion then
  local broadcast=public[#public].packet
  assert(broadcast.phase=="Reeling" and broadcast.chargeAt==reelPacket.chargeAt)
  assert(broadcast.timingMotion.amplitude==reelPacket.timingMotion.amplitude)
  assert(broadcast.timingMotion.speed==reelPacket.timingMotion.speed and broadcast.timingMotion.phase==reelPacket.timingMotion.phase)
  assert(broadcast.profile==nil and broadcast.reservedId==nil and broadcast.result==nil)
  motionSeen=true
 end
 local result=send(skilled,"Release",reelPacket.attemptId,goldTime(reelPacket))
 assert(result.result.quality=="Brilliant")
 if motionSeen then break end
end
assert(motionSeen,"service integration never exercised the moving-resistance metadata")
print("PASS actual fishing service: private reservation, shared timing metadata, authoritative single reward and late-client visuals")
print("PASS movement, portal-busy, character removal, death, departure and stale Release prevent extra rewards")
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("fishing_service_startup", ROOT / "tools/check_startup.py")
    startup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(startup)
    prepare = startup.PREPARE.replace(
        'ConnectionCount=function() return #callbacks end,',
        'ConnectionCount=function() return #callbacks end,\n'
        '  Fire=function(_,...) for _,callback in table.clone(callbacks) do callback(...) end end,',
    ).replace('Heartbeat=true}', 'Heartbeat=true,CharacterRemoving=true}')
    program = (ROOT / "tools/preview_roblox.luau").read_text() + prepare
    for index, (path, relative_source) in enumerate(startup.production_sources()):
        name = path.rsplit("/", 1)[1]
        folder = "server" if path.startswith("ServerScriptService/") else "shared"
        program += (
            f'\nlocal token{index}=Instance.new("ModuleScript")\n'
            f'token{index}.Name="{name}";token{index}.Parent={folder}\n'
            f'factories[token{index}]=function()\nlocal script=token{index}\n'
            + (ROOT / relative_source).read_text() + "\nend\n"
        )
    program += startup.CUSTOM_SETUP
    program += '\ncustomSpot:SetAttribute("ZoneId","forest")\ncustomSpot:SetAttribute("ZoneName","Evergreen Reach")\n'
    program += '\nrequire(server:FindFirstChild("FishingService")).start()\n' + CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "fishing_service.luau"
        path.write_text(program)
        result = subprocess.run([luau, str(path)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        for line in result.stdout.splitlines():
            if line.startswith("PASS "):
                print(line)
    print("Event/geometry doubles only; native input, transport latency, replication and saving still need Roblox client tests.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
