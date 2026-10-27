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
local function send(player,verb,id,time,preferenceRequestId)
 clock=time
	command.OnServerEvent:Fire(player,verb,id,preferenceRequestId)
 return latest(player)
end
local function goldTime(packet, targetOffset)
 local rules=require(shared:FindFirstChild("FishingRules"))
 local distance,time=math.huge,packet.chargeAt
 for index=0,10000 do
  local candidate=packet.chargeAt+packet.duration*index/10000
  local offset=math.abs(rules.progressAt(packet,candidate)-rules.centerAt(packet,candidate)-(targetOffset or 0))
  if offset<distance then distance,time=offset,candidate end
 end
 return time
end
local p,root,humanoid=makePlayer(11)
local first=send(p,"Sync",nil,0)
assert(first.phase=="Idle" and first.profile.catches==0 and first.profile.coins==0)
assert(first.profile.preferences.soundEnabled and not first.profile.preferences.reducedEffects)
local publicBeforePreferences=#public
local changed=send(p,"Preferences",{soundEnabled=false,reducedEffects=true},.1,7)
assert(changed.preferencesChanged and changed.replyTo=="Preferences" and changed.purchase==nil and changed.result==nil)
assert(changed.preferenceRequestId==7)
assert(not changed.profile.preferences.soundEnabled and changed.profile.preferences.reducedEffects)
assert(#public==publicBeforePreferences,"private settings update broadcast a new global fishing visual")
local a=send(p,"Start",nil,1)
assert(a.phase=="Waiting" and a.profile.catches==0 and a.result==nil)
assert(a.castAt==1 and a.castDuration< a.readyAt-a.castAt and a.duration==2.8)
assert(a.reservedId==nil and a.speciesId==nil and a.profile.persistent==false)
local visible=public[#public].packet
assert(visible.castAt==a.castAt and visible.castDuration==a.castDuration and visible.duration==a.duration)
assert(visible.readyAt==a.readyAt and visible.timingCenter==a.timingCenter and visible.behavior==a.behavior)
assert(visible.profile==nil and visible.reservedId==nil and visible.speciesId==nil,"private profile/selection escaped through public visual")
assert(visible.preferences==nil and visible.preferencesChanged==nil and visible.preferenceRequestId==nil,"private preferences escaped through public visual")
local rejectedPreferences=send(p,"Preferences",{soundEnabled=true,reducedEffects=false},1.1,8)
assert(rejectedPreferences.phase=="Waiting" and rejectedPreferences.preferencesChanged==nil)
assert(rejectedPreferences.preferenceRequestId==8,"phase rejection omitted a valid private correlation nonce")
assert(not rejectedPreferences.profile.preferences.soundEnabled and rejectedPreferences.profile.preferences.reducedEffects)
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
local ownProfile=nil
for _,packet in received[other] do if packet.profile then ownProfile=packet.profile end end
assert(ownProfile and ownProfile.preferences.soundEnabled and not ownProfile.preferences.reducedEffects,
 "another player's settings changed the joining player's preferences")
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

-- Exercise the new client protocol through the real adapter, not direct Engine
-- calls. Targets, reply routing and public privacy are integration contracts.
local caster,casterRoot=makePlayer(44)
local wind=send(caster,"BeginCast",nil,clock+3)
assert(wind.phase=="ChargingCast" and wind.replyTo=="BeginCast" and wind.castAt==nil and wind.readyAt==nil)
local shown=public[#public].packet
assert(shown.phase=="ChargingCast" and shown.castChargeAt==wind.castChargeAt and shown.castChargeDuration==1)
assert(shown.replyTo==nil and shown.profile==nil and shown.reservedId==nil and shown.result==nil)
local launch=send(caster,"Cast",wind.attemptId,wind.castChargeAt+.8)
assert(launch.phase=="Waiting" and launch.replyTo=="Cast" and launch.castGrade=="Perfect" and launch.castBonusPercent==10)
assert(math.abs(launch.castPower-.8)<1e-8 and launch.castAt==wind.castChargeAt+.8)
assert(math.abs(launch.castTarget.Z+14.6)<1e-8 and launch.castTarget.X==-3)
shown=public[#public].packet
assert(shown.castGrade=="Perfect" and shown.castPower==launch.castPower and shown.replyTo==nil)
assert((shown.castTarget-launch.castTarget).Magnitude<1e-8 and shown.profile==nil)
local before=#received[caster]
send(caster,"Cast",wind.attemptId,clock+.05)
assert(#received[caster]==before,"duplicate Cast rewrote the approved target")
local reel=send(caster,"Hold",wind.attemptId,launch.readyAt)
local landed=send(caster,"Release",wind.attemptId,goldTime(reel))
assert(landed.replyTo=="Release" and landed.result.castGrade=="Perfect" and landed.result.castBonusPercent==10)
assert((landed.castTarget-launch.castTarget).Magnitude<1e-8,"finished result lost its actual water target")
local sync=send(caster,"Sync",nil,clock+.25)
assert(sync.replyTo=="Sync" and (sync.castTarget-launch.castTarget).Magnitude<1e-8,"idle Sync reset cast depth")
local quick=send(caster,"BeginCast",nil,clock+3)
quick=send(caster,"QuickCast",quick.attemptId,quick.castChargeAt+.5)
assert(quick.castPower==.65 and quick.castGrade=="Clean" and quick.castBonusPercent==0 and quick.castTarget.Z==-14)
assert(quick.replyTo=="QuickCast" and public[#public].packet.replyTo==nil)
local stopped=send(caster,"Cancel",quick.attemptId,clock+.1)
local tooFar=send(caster,"BeginCast",nil,clock+3)
casterRoot.Position=Vector3.new(100,3.3,0)
clock+=.11;runService.Heartbeat:Fire(.11)
assert(latest(caster).phase=="Idle" and latest(caster).result==nil,"charging movement did not abort")
assert(latest(caster).replyTo==nil,"passive heartbeat masqueraded as command reply")
casterRoot.Position=Vector3.new(0,3.3,0)
local timeout=send(caster,"BeginCast",nil,clock+3)
clock=timeout.expiresAt;runService.Heartbeat:Fire(.11)
assert(latest(caster).phase=="Waiting" and latest(caster).attemptId==timeout.attemptId)
assert(latest(caster).castPower==.65 and latest(caster).castBonusPercent==0 and latest(caster).replyTo==nil)

-- A surplus client argument cannot widen the starter rod's actual grade window.
local plainWait=latest(caster)
assert(plainWait.timingWidth==.14)
local plainReel=send(caster,"Hold",plainWait.attemptId,plainWait.readyAt)
clock=goldTime(plainReel,.09)
command.OnServerEvent:Fire(caster,"Release",plainReel.attemptId,.22)
assert(latest(caster).result.quality=="Fine","extra client width changed server grading")
-- Buying an earned rod changes both the public band and actual edge grading.
local bought=send(skilled,"Upgrade",0,clock+3)
assert(bought.purchase.success and bought.profile.level==1 and bought.profile.timingWidth==.156)
local wider=send(skilled,"Start",nil,clock+1)
assert(wider.timingWidth==.156 and public[#public].packet.timingWidth==.156)
local widerReel=send(skilled,"Hold",wider.attemptId,wider.readyAt)
local widthTime=goldTime(widerReel,.075)
local gradeRules=require(shared:FindFirstChild("FishingRules"))
assert(gradeRules.qualityAt(gradeRules.progressAt(widerReel,widthTime),gradeRules.centerAt(widerReel,widthTime))=="Fine")
local widerResult=send(skilled,"Release",wider.attemptId,widthTime)
assert(widerResult.result.quality=="Brilliant","earned wider band did not change the real award")
print("PASS earned rods: bound/public widths, actual expanded-edge grade and ignored client width payload")

local settingsPlayer=makePlayer(91)
send(settingsPlayer,"Sync",nil,clock+3)
for _,nonce in {1,2147483647} do
 local packet=send(settingsPlayer,"Preferences",{soundEnabled=false,reducedEffects=true},clock+.3,nonce)
 assert(packet.preferencesChanged and packet.preferenceRequestId==nonce and packet.purchase==nil and packet.result==nil)
 assert(packet.profile.coins==0 and packet.profile.catches==0)
end
for _,nonce in {0,-1,1.5,math.huge,-math.huge,0/0,2147483648,"7",{},false} do
 local packet=send(settingsPlayer,"Preferences",{soundEnabled=true,reducedEffects=false},clock+.3,nonce)
 assert(packet.preferencesChanged and packet.preferenceRequestId==nil,
  "invalid correlation data was echoed or changed preference authorization")
 assert(packet.profile.preferences.soundEnabled and not packet.profile.preferences.reducedEffects)
end
local legacyPreference=send(settingsPlayer,"Preferences",{soundEnabled=false,reducedEffects=true},clock+.3)
assert(legacyPreference.preferencesChanged and legacyPreference.preferenceRequestId==nil)
local beforeSync=#received[settingsPlayer]
send(settingsPlayer,"Sync",nil,clock+.3,17)
assert(received[settingsPlayer][beforeSync+1].preferenceRequestId==nil,
 "a nonce leaked into an unrelated command response")
local beforeMalformed=#received[settingsPlayer]
send(settingsPlayer,"Preferences",{soundEnabled=true,reducedEffects=false,coins=999999},clock+.3,18)
assert(#received[settingsPlayer]==beforeMalformed,"nonce made a malformed preference payload acceptable")
for _,entry in public do
 assert(entry.packet.preferenceRequestId==nil and entry.packet.preferencesChanged==nil and entry.packet.profile==nil,
  "private preference correlation escaped through global visual packets")
end
print("PASS private preference correlation: boundary IDs, invalid/legacy nonces, malformed payload rejection and public privacy")

print("PASS charged casts: server power, actual target depth, reply routing, public privacy, quick taps and timeout/movement recovery")

print("PASS actual fishing service: private reservation, shared timing metadata, authoritative single reward and late-client visuals")
print("PASS movement, portal-busy, character removal, death, departure and stale Release prevent extra rewards")
print("PASS private preference acknowledgement, active-cast rejection and independent player defaults")
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
