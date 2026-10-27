#!/usr/bin/env python3
"""Run the production audio controller against deterministic sound/event doubles.

Checks scheduled-note ownership, muting, voice limits, loops and ambience recovery.
This does not render native audio, establish asset availability, or judge its mix.
Run: python tools/check_fishing_audio.py --luau /path/to/luau
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local os=table.clone(os)
os.clock=function() return now end
local originalIndex=mt.__index
local function onceSignal()
 local event=signal()
 function event:Once(callback)
  local connection
  connection=self:Connect(function(...)
   connection:Disconnect()
   callback(...)
  end)
  return connection
 end
 return event
end
mt.__index=function(self,key)
 if key=='Ended' then
  self.props[key]=self.props[key] or onceSignal()
  return self.props[key]
 end
 return originalIndex(self,key)
end
local plays,stops,tweens={},0,{}
function methods:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true
 if self.IsPlaying then self.IsPlaying=false;stops+=1 end
 self.Parent=nil
 for _,child in table.clone(self.children) do child:Destroy() end
end
function methods:Play()
 assert(self:IsA('Sound') and self.Parent and not self.Destroyed,'played a dead sound')
 self.IsPlaying=true
 table.insert(plays,{sound=self,time=now,pitch=self.PlaybackSpeed,volume=self.Volume,id=self.SoundId,looped=self.Looped==true})
end
function methods:Stop() self.IsPlaying=false;stops+=1 end
function methods:Clone()
 local copy=Instance.new(self.ClassName)
 for key,value in self.props do
  if key~='Parent' and key~='Ended' and key~='Destroyed' and key~='IsPlaying' then copy.props[key]=value end
 end
 copy.IsPlaying=false
 for _,child in self.children do child:Clone().Parent=copy end
 return copy
end
local TweenInfo={new=function(duration) return {duration} end}
local TweenService={Create=function(_,object,info,values)
 local tween={cancelled=false,object=object,values=values}
 table.insert(tweens,tween)
 function tween:Play()
  task.delay(info[1],function()
   if self.cancelled or object.Destroyed then return end
   for key,value in values do object[key]=value end
  end)
 end
 function tween:Cancel() self.cancelled=true end
 return tween
end}
local SoundService=Instance.new('SoundService')
local preloadCalls,preloadCount=0,0
local ContentProvider={PreloadAsync=function(_,assets)
 preloadCalls+=1;preloadCount=#assets
 for _,asset in assets do assert(asset:IsA('Sound') and type(asset.SoundId)=='string') end
end}
local Debris={AddItem=function(_,object,lifetime) task.delay(lifetime,function() object:Destroy() end) end}
local services={SoundService=SoundService,ContentProvider=ContentProvider,TweenService=TweenService,Debris=Debris}
game.GetService=function(_,name) assert(services[name],name);return services[name] end
'''

CHECK = r'''
local passed=0
local function test(name,callback)
 local ok,err=pcall(callback)
 assert(ok,'FAIL '..name..': '..tostring(err))
 passed+=1;print('PASS '..name)
end
local audio=modules.FishingAudio.new()
local folder=assert(SoundService:FindFirstChild('CloudAnglersSounds'))
local group=assert(SoundService:FindFirstChild('CloudAnglersMix'))
local function active(loops,name)
 local result={}
 for _,object in all do
  if object:IsA('Sound') and object.Parent and object.IsPlaying
   and (object.Looped==true)==loops and (not name or object.Name==name) then table.insert(result,object) end
 end
 return result
end
local wind=assert(active(true,'Wind')[1])
local function close(a,b) return math.abs(a-b)<1e-8 end
local function reset()
 audio.setEnabled(false);audio.setReeling(false);step(.3)
 audio.setEnabled(true);step(.5)
end
local function recent(index)
 local result={}
 for i=index+1,#plays do if not plays[i].looped then table.insert(result,plays[i]) end end
 return result
end
test('six shipped clips preload once; quiet bounded mixer and one wind loop',function()
 assert(preloadCalls==1 and preloadCount==6,'preload library changed')
 local templates,ids=0,{}
 for _,object in folder:GetChildren() do
  if object:IsA('Sound') and not object.IsPlaying then
   templates+=1;ids[object.SoundId]=true
   assert(string.sub(object.SoundId,1,18)=='rbxasset://sounds/','unexpected external audio dependency')
   assert(object.SoundGroup==group and object.RollOffMaxDistance==48)
  end
 end
 local unique=0;for _ in ids do unique+=1 end
 assert(templates==6 and unique==6 and #active(true,'Wind')==1)
 assert(group.Volume==.75 and audio.isEnabled())
 step(2.01);assert(close(wind.Volume,.018),'wind fade did not settle')
end)
test('one-shot voices cap at ten, clamp gain/pitch and free finished sounds',function()
 local before=#plays
 audio.play('Unknown');assert(#plays==before,'unknown clip played')
 for i=1,30 do
  audio.play('Splash',if i%2==0 then 50 else -10,nil,500)
  assert(#active(false)<=10,'voice cap exceeded')
 end
 assert(#active(false)==10 and #plays==before+30)
 for i=before+1,#plays do
  assert(plays[i].volume<=.3 and plays[i].pitch>=.7 and plays[i].pitch<=1.45,'unbounded voice')
 end
 for i=before+1,before+20 do assert(plays[i].sound.Destroyed,'oldest voice not evicted') end
 local finished=active(false)[1];finished.Ended:Fire()
 assert(finished.Destroyed and #active(false)==9,'Ended did not dispose voice')
 audio.play('Cast');assert(#active(false)==10,'finished voice bookkeeping stayed stale')
 reset();assert(#active(false)==0,'reset retained a live one-shot')
end)
test('mute destroys one-shots and cancels scheduled notes across unmute',function()
 audio.catch('Brilliant','Epic',true);step(0)
 local first=plays[#plays].sound
 audio.setEnabled(false)
 assert(not audio.isEnabled() and group.Volume==0 and first.Destroyed and #active(false)==0)
 local mutedAt=#plays
 audio.play('Cast');audio.ui();audio.catch('Fine','Secret',false)
 step(.1);assert(#plays==mutedAt,'muted controller played')
 audio.setEnabled(true);audio.setEnabled(true)
 assert(audio.isEnabled() and group.Volume==.75)
 step(.6);assert(#plays==mutedAt,'old scheduled reward resumed after unmute')
 assert(not first.Parent and first.IsPlaying==false)
 local value=audio.toggle();assert(value==true and not audio.isEnabled())
 value=audio.toggle();assert(value==false and audio.isEnabled())
 reset()
end)
test('reeling loop has one owner and repeated state does not duplicate it',function()
 audio.setReeling(true);audio.setReeling(true);audio.setReeling(true)
 assert(#active(true,'Reel')==1,'duplicate steady reeling loops')
 local reel=active(true,'Reel')[1]
 step(.46);assert(close(reel.Volume,.055) and close(wind.Volume,.006))
 local before=#plays
 audio.setEnabled(false);audio.setReeling(true);step(.3)
 assert(group.Volume==0 and #active(true,'Reel')==1 and #plays==before,'muted state duplicated loop')
 audio.setEnabled(true);audio.setReeling(true)
 assert(group.Volume==.75 and #plays==before,'unmute restarted a duplicate loop')
 audio.setReeling(false);audio.setReeling(false);step(.221)
 assert(reel.Destroyed and #active(true,'Reel')==0,'stopped reel retained ownership')
 audio.setReeling(true);assert(#active(true,'Reel')==1 and active(true,'Reel')[1]~=reel)
 audio.setReeling(false);step(.5)
 assert(#active(true,'Reel')==0 and close(wind.Volume,.018),'normal ambience not restored')
 reset()
end)
test('reel pitch follows progress and resistance without extra voices, gain or unstable steps',function()
 audio.setReeling(true);step(.3)
 local reel=active(true,'Reel')[1]
 local count,volume=#plays,reel.Volume
 for _=1,60 do audio.updateReeling(0,0,1/60) end
 local relaxed=reel.PlaybackSpeed
 for _=1,60 do audio.updateReeling(1,.6,1/60) end
 assert(reel.PlaybackSpeed>relaxed+.15 and reel.PlaybackSpeed<=1.20,'reel pitch did not reflect resistance')
 assert(reel.PlaybackSpeed>=.98 and reel.Volume==volume and #plays==count,'pitch update changed gain or allocated a sound')
 local unchanged=reel.PlaybackSpeed
 audio.updateReeling(0/0,0/0,0/0)
 assert(reel.PlaybackSpeed==unchanged,'invalid delta changed reel state')
 for _=1,10 do audio.updateReeling(math.huge,math.huge,math.huge) end
 assert(reel.PlaybackSpeed>=.98 and reel.PlaybackSpeed<=1.20,'large clock step escaped the mix')
 audio.setEnabled(false);audio.updateReeling(.4,.2,.05)
 assert(group.Volume==0 and #plays==count,'muted pitch update created an audible or duplicate voice')
 audio.setReeling(false)
 unchanged=reel.PlaybackSpeed;audio.updateReeling(1,.6,.1)
 assert(reel.PlaybackSpeed==unchanged,'stopped loop still accepted motion ownership')
 reset()
end)
test('UI clicks debounce but allow a later success or failure response',function()
 local before=#plays
 audio.ui();audio.ui(false);audio.ui();assert(#plays==before+1)
 step(.139);audio.ui(false);assert(#plays==before+1,'UI debounce too short')
 step(.002);audio.ui(false);assert(#plays==before+2 and plays[#plays].sound.Name=='Miss')
 step(.141);audio.ui();assert(#plays==before+3 and plays[#plays].sound.Name=='Chime')
 reset()
end)
test('seven tiers use bounded motifs and recover ducked ambience',function()
 local expected={
  Common={.88,1.1},Uncommon={.88,1.1},Rare={.94,1.25},Epic={.94,1.18,1.40},
  Legendary={.88,1.11,1.32},Mythical={.82,1.03,1.38},Secret={.74,.99,1.32},
 }
 for _,rarity in {'Common','Uncommon','Rare','Epic','Legendary','Mythical','Secret'} do
  local before=#plays
  audio.catch('Fine',rarity,false);step(.46)
  local notes=recent(before)
  assert(#notes==#expected[rarity],rarity..' note count')
  for index,note in notes do
   assert(note.sound.Name=='Chime' and close(note.pitch,expected[rarity][index]),rarity..' motif')
   assert(note.volume<=.3 and note.pitch>=.7 and note.pitch<=1.45)
  end
  assert(close(wind.Volume,.005),rarity..' reward did not duck ambience')
  step(.85);assert(close(wind.Volume,.018),rarity..' left ambience ducked')
 end
 reset()
end)
test('catch phrase suppresses overlapping goals and restores reeling ambience',function()
 audio.setReeling(true);step(.46)
 local before=#plays
 audio.catch('Brilliant','Legendary',true);audio.goal();step(.45);audio.goal();step(.10)
 assert(#recent(before)==3,'goal piled onto the catch phrase')
 step(.8);assert(close(wind.Volume,.006),'reward restored wrong ambience during reeling')
 before=#plays;audio.goal();step(.4)
 assert(#recent(before)==2,'later goal never became eligible')
 step(1);audio.setReeling(false);step(.5)
 assert(close(wind.Volume,.018),'loop release did not restore idle ambience')
 reset()
end)
test('a new reward invalidates an old phrase tail without replay or stale restore',function()
 local before=#plays
 audio.upgrade();step(0);step(.05)
 audio.catch('Fine','Secret',false);step(.5)
 local notes=recent(before)
 assert(#notes==4,'replaced phrase tail continued')
 assert(close(notes[1].pitch,.82) and close(notes[2].pitch,.74)
  and close(notes[3].pitch,.99) and close(notes[4].pitch,1.32))
 step(.8);assert(close(wind.Volume,.018),'latest phrase did not restore ambience')
 reset()
end)
test('debris recovery removes unended one-shots and retains just ambient loop',function()
 audio.play('Splash');assert(#active(false)==1)
 step(5.01);assert(#active(false)==0,'never-ended voice leaked')
 assert(#active(true)==1 and active(true)[1]==wind,'unexpected retained loop')
end)
test('muted bootstrap stays silent through delayed profile loading and enables without stale notes',function()
 local boot=modules.FishingAudio.new(true)
 local bootWind=plays[#plays].sound
 local bootGroup,bootFolder=bootWind.SoundGroup,bootWind.Parent
 assert(bootWind.Name=='Wind' and bootWind.Looped and bootGroup~=group,'bootstrap did not own its mixer')
 assert(not boot.isEnabled() and bootGroup.Volume==0,'bootstrap started audibly before profile loading')
 -- The real controller may yield for remotes or PlayerGui before hydrating
 -- saved preferences. Let the constructor's complete fade elapse first.
 for _=1,40 do
  step(.1)
  assert(bootGroup.Volume*bootWind.Volume==0,'startup wind escaped mute while waiting for a profile')
 end
 assert(close(bootWind.Volume,.018),'bootstrap never ran its actual ambient fade')
 local before=#plays
 boot.play('Cast');boot.ui();boot.catch('Fine','Secret',false);step(.1)
 assert(#plays==before,'muted bootstrap queued an audible one-shot')
 boot.setEnabled(true)
 assert(boot.isEnabled() and bootGroup.Volume==.75,'saved enabled choice did not release bootstrap mute')
 step(1.1)
 assert(#plays==before and close(bootWind.Volume,.018),'enabling replayed a muted phrase or left ambience ducked')
 boot.play('Cast');assert(#plays==before+1,'new actions did not resume after hydration')
 boot.setEnabled(false);step(.1)
 assert(not boot.isEnabled() and #recent(before)==1 and plays[#plays].sound.Destroyed,'bootstrap instance lost normal mute cleanup')
 bootFolder:Destroy();bootGroup:Destroy()
end)
test('explicit early enable cancels startup fade without overriding active reeling ambience',function()
 local boot=modules.FishingAudio.new(true)
 local bootWind=plays[#plays].sound
 local bootGroup,bootFolder=bootWind.SoundGroup,bootWind.Parent
 step(.1);boot.setEnabled(true);boot.setReeling(true)
 step(2.1)
 assert(boot.isEnabled() and bootGroup.Volume==.75,'early local enable did not take effect')
 assert(close(bootWind.Volume,.006),'old startup fade overwrote reeling ambience')
 local playingReels=0
 for _,voice in bootFolder:GetChildren() do
  if voice:IsA('Sound') and voice.Name=='Reel' and voice.IsPlaying then playingReels+=1 end
 end
 assert(playingReels==1,'bootstrap duplicated or lost the owned reeling loop')
 boot.setReeling(false);step(.5)
 assert(close(bootWind.Volume,.018),'early bootstrap did not restore idle ambience')
 boot.setEnabled(false);bootFolder:Destroy();bootGroup:Destroy()
end)
print(passed..' production fishing-audio cases passed; native rendering and mix are untested')
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location(
        "portal_audio_scheduler", ROOT / "tools/check_portal_interface.py"
    )
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    scheduler = portal.PREPARE.split("local methods={}")[0]
    source = (ROOT / "src/client/FishingAudio.luau").read_text()
    program = (
        (ROOT / "tools/preview_roblox.luau").read_text()
        + scheduler
        + PREPARE
        + "\nmodules.FishingAudio=(function()\n"
        + source
        + "\nend)()\n"
        + CHECK
    )
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fishing_audio.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
