#!/usr/bin/env python3
"""Run the actual profile-store adapter against deterministic DataStore doubles.

Covers transport/callback retries and lease ownership, not Roblox availability,
request budgets or the native persistence service.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PREPARE = r'''
local clock,guidCounter,nextCalls=1000,0,0
local nativeNext=next
local next=function(value,key)nextCalls+=1;return nativeNext(value,key)end
local waits={}
local os={time=function()return math.floor(clock)end,clock=function()return clock end}
local task={wait=function(seconds)table.insert(waits,seconds);clock+=seconds;return seconds end}
local function clone(value)
 if type(value)~='table' then return value end
 local result={};for key,item in value do result[key]=clone(item) end;return result
end
local backends={}
local function backend(name)
 if backends[name] then return backends[name] end
 local store={records={},actions={},calls=0,transforms={}}
 function store:UpdateAsync(key,transform)
  self.calls+=1
  local action=table.remove(self.actions,1)
  if action=='fail_before' then error('simulated transport failure before callback') end
  if type(action)=='function' then return action(self,key,transform) end
  local function apply()
   local nextValue=transform(clone(self.records[key]))
   table.insert(self.transforms,{key=key,value=clone(nextValue)})
   return nextValue
  end
  if action=='retry_callback' then apply() end
  local nextValue=apply()
  if nextValue~=nil then self.records[key]=clone(nextValue) end
  if action=='commit_then_fail' then error('simulated lost response after commit') end
  return clone(nextValue)
 end
 backends[name]=store;return store
end
local DataStoreService={GetDataStore=function(_,name)return backend(name)end}
local HttpService={GenerateGUID=function()
 guidCounter+=1
 return string.format('00000000-1111-2222-3333-%012x',guidCounter)
end}
local game={GetService=function(_,name)
 return assert(({DataStoreService=DataStoreService,HttpService=HttpService})[name],name)
end}
local script={Parent={WaitForChild=function(_,name)return name end}}
local modules={}
local require=function(name)return assert(modules[name],name)end
'''

CHECK = r'''
local productionName,testName='CloudAnglers_Player_v03','CloudAnglers_Test_v03'
local function reset()
 clock,guidCounter,nextCalls=1000,0,0;table.clear(waits);table.clear(backends)
end
local function newStore(studio)
 local progression=modules.FishingProgression.new(modules.FishCatalog,function()return 0 end)
 return modules.FishingProfileStore.new(modules.FishCatalog,progression,studio or false),progression
end
local passed=0
local function test(name,run)
 reset();local ok,reason=pcall(run);assert(ok,name..': '..tostring(reason))
 passed+=1;print('PASS '..name)
end
test('production and Studio namespaces stay independent for the same player',function()
 local prod,progression=newStore(false);local studio=newStore(true)
 local a=assert(prod.load(17));local b=assert(studio.load(17))
 progression.catch(a.profile,'Normal','harbor')
 assert(prod.save(a,a.profile,false))
 assert(backend(productionName).records.player_17.profile.catches==1)
 assert(backend(testName).records.player_17.profile.catches==0)
 assert(a.id~=b.id and a.key=='player_17' and b.key=='player_17')
end)
test('transient load failures retry with one lease identity and bounded backoff',function()
 local store=newStore();local data=backend(productionName)
 data.actions={'fail_before','fail_before'}
 local session=assert(store.load(1))
 assert(data.calls==3 and guidCounter==1 and #waits==2 and waits[1]==1 and waits[2]==2)
 assert(session.expires==clock+120 and not session.busy and not session.closed)
end)
test('a lost load response cannot award offline coins twice',function()
 local store,progression=newStore();local data=backend(productionName)
 local p=progression.create();for _=1,3 do progression.catch(p,'Normal','harbor') end
 local rules=modules.FishingSaveRules.new(modules.FishCatalog,progression)
 local initial=assert(rules.acquire(nil,'previous',400))
 data.records.player_1=assert(rules.save(initial,p,'previous',400,true))
 data.actions={'commit_then_fail'}
 local session=assert(store.load(1))
 assert(data.calls==2 and guidCounter==1 and session.offline.coins==7 and session.offline.seconds==600)
 assert(session.profile.coins==p.coins+7 and data.records.player_1.profile.coins==p.coins+7)
end)
test('active-session retry can recover an expiring lease without stealing a live one',function()
 local store,progression=newStore();local data=backend(productionName)
 local rules=modules.FishingSaveRules.new(modules.FishCatalog,progression)
 data.records.player_1=assert(rules.acquire(nil,'previous',883)) -- expires at1003
 local session=assert(store.load(1))
 assert(data.calls==3 and clock==1004 and session.id~='previous' and guidCounter==1)
 data.records.player_2=assert(rules.acquire(nil,'still-active',1004))
 local denied,reason=store.load(2)
 assert(denied==nil and reason=='active_session' and data.calls==7 and clock==1010)
 assert(data.records.player_2.lease.id=='still-active')
end)
test('exhausted backend failures leave no busy session or replacement default profile',function()
 local store=newStore();local data=backend(productionName)
 data.actions={'fail_before','fail_before','fail_before'}
 local session,reason=store.load(1)
 assert(session==nil and reason=='unavailable' and data.calls==3 and data.records.player_1==nil)
 assert(clock==1003 and #waits==2)
end)
test('unacknowledged acquired leases block another server until safe expiration',function()
 local store=newStore();local data=backend(productionName)
 data.actions={'commit_then_fail','commit_then_fail','commit_then_fail'}
 local session,reason=store.load(1)
 assert(session==nil and reason=='unavailable' and data.records.player_1.lease)
 local owner=data.records.player_1.lease.id
 local expires=data.records.player_1.lease.expires
 session,reason=store.load(1)
 assert(session==nil and reason=='active_session' and data.records.player_1.lease.id==owner)
 clock=expires+1
 local recovered=assert(store.load(1))
 assert(recovered.id~=owner and recovered.profile.catches==0 and recovered.profile.coins==0)
 assert(data.records.player_1.lease.id==recovered.id)
end)
test('autosave takes one detached snapshot across retry and ignores later caller mutation',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local profile=progression.create()
 progression.catch(profile,'Normal','harbor');local expected=profile.coins
 data.actions={function()
  profile.coins+=500;profile.best.pufflet=3
  error('transient failure while the live profile keeps changing')
 end}
 assert(store.save(session,profile,false))
 local saved=data.records.player_1
 assert(saved.profile.coins==expected and saved.profile.best.pufflet==1)
 assert(saved.lease.id==session.id and session.expires==clock+120 and not session.busy)
 assert(guidCounter==1,'ordinary autosaves minted unnecessary operation identities')
end)
test('lost ownership between retries rejects stale writes and clears busy',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local previousSave=session.lastSave
 local profile=progression.create();progression.catch(profile,'Normal','harbor')
 data.actions={function(self,key)
  self.records[key].lease={id='replacement',expires=clock+120}
  self.records[key].profile.coins=777
  error('ownership changed during failed transport')
 end}
 local ok,reason=store.save(session,profile,false)
 assert(not ok and reason=='lost_lease' and not session.busy and not session.closed)
 assert(session.lastSave==previousSave and data.records.player_1.profile.coins==777)
end)
test('final release commits once after a lost response and retains its original activity time',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local profile=progression.create()
 progression.catch(profile,'Normal','harbor');clock=1010
 data.actions={'commit_then_fail'}
 local before=data.calls;local ok,reason=store.save(session,profile,true)
 assert(ok and reason==nil and session.closed and not session.busy and session.expires==0)
 local saved=data.records.player_1
 assert(data.calls==before+2 and guidCounter==2 and saved.lease==nil)
 assert(saved.lastSeen==1010 and saved.profile.coins==profile.coins)
 local receipt=saved.releaseReceipt
 assert(receipt.leaseId==session.id and receipt.operationId~=session.id)
 local calls=data.calls
 assert(not store.save(session,profile,true) and data.calls==calls,'closed release wrote again')
end)
test('UpdateAsync callback retries reuse one release operation identity',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local profile=progression.create()
 data.actions={'retry_callback'}
 local before=#data.transforms
 assert(store.save(session,profile,true))
 assert(#data.transforms==before+2 and guidCounter==2)
 local first,second=data.transforms[before+1].value,data.transforms[before+2].value
 assert(first.releaseReceipt.operationId==second.releaseReceipt.operationId)
 assert(first.releaseReceipt.leaseId==second.releaseReceipt.leaseId)
end)
test('failed final-write transport leaves a valid released record without replaying value',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local profile=progression.create()
 progression.catch(profile,'Normal','harbor')
 data.actions={'commit_then_fail','commit_then_fail','commit_then_fail'}
 local ok,reason=store.save(session,profile,true)
 assert(not ok and reason=='unavailable' and not session.busy)
 assert(data.records.player_1.lease==nil and data.records.player_1.profile.coins==profile.coins)
 assert(guidCounter==2 and data.records.player_1.releaseReceipt)
 -- A later player can acquire the real persisted record even when the former
 -- server never received its acknowledgement.
 local replacement=assert(store.load(1))
 assert(replacement.profile.coins==profile.coins and data.records.player_1.releaseReceipt==nil)
end)
test('corrupt release metadata blocks load rather than overwriting old progress',function()
 local store,progression=newStore();local data=backend(productionName)
 local rules=modules.FishingSaveRules.new(modules.FishCatalog,progression)
 local old=assert(rules.acquire(nil,'previous',400))
 old=assert(rules.save(old,old.profile,'previous',400,true))
 old.profile.coins=500;old.releaseReceipt={leaseId='previous',operationId='invalid'}
 data.records.player_1=old
 local session,reason=store.load(1)
 assert(session==nil and reason=='invalid_data' and data.calls==1)
 assert(data.records.player_1.profile.coins==500 and #waits==0)
end)
test('busy and closed saves perform no datastore request or snapshot work',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local count=data.calls
 session.busy=true
 local ok,reason=store.save(session,progression.create(),true)
 assert(not ok and reason=='busy' and data.calls==count and guidCounter==1)
 session.busy=false;session.closed=true
 ok,reason=store.save(session,progression.create(),false)
 assert(not ok and reason=='busy' and data.calls==count and guidCounter==1)
end)
test('snapshot preparation errors release busy ownership without touching saved data',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local count=data.calls
 local original=progression.copy
 progression.copy=function()error('simulated snapshot preparation bug')end
 local ok,reason=store.save(session,progression.create(),false)
 assert(not ok and reason=='invalid_data' and not session.busy and not session.closed)
 assert(data.calls==count and data.records.player_1.profile.catches==0)
 progression.copy=original
 assert(store.save(session,progression.create(),false),'a failed snapshot poisoned later saves')
end)
test('release identity allocation errors cannot leave the save session busy',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local count=data.calls
 local original=HttpService.GenerateGUID
 HttpService.GenerateGUID=function()error('simulated identity allocation failure')end
 local ok,reason=store.save(session,progression.create(),true)
 assert(not ok and reason=='unavailable' and not session.busy and not session.closed)
 assert(data.calls==count and data.records.player_1.lease.id==session.id)
 HttpService.GenerateGUID=original
 assert(store.save(session,progression.create(),true) and session.closed)
end)
test('load identity allocation errors report failure before touching datastore records',function()
 local store=newStore();local data=backend(productionName)
 local original=HttpService.GenerateGUID
 HttpService.GenerateGUID=function()error('simulated load identity allocation failure')end
 local session,reason=store.load(1)
 assert(session==nil and reason=='unavailable' and data.calls==0 and #waits==0)
 assert(data.records.player_1==nil,'identity failure created a default profile')
 HttpService.GenerateGUID=original
 assert(store.load(1),'identity failure poisoned the store for later loads')
end)
test('accepted preferences survive actual save release and later profile acquisition',function()
 local store,progression=newStore();local session=assert(store.load(1))
 assert(progression.setPreferences(session.profile,{soundEnabled=false,reducedEffects=true}))
 assert(store.save(session,session.profile,true))
 clock+=60
 local nextSession=assert(store.load(1))
 assert(not nextSession.profile.preferences.soundEnabled and nextSession.profile.preferences.reducedEffects)
 assert(nextSession.profile.coins==0 and nextSession.profile.catches==0)
 local snapshot=progression.snapshot(nextSession.profile)
 snapshot.preferences.soundEnabled=true
 assert(not nextSession.profile.preferences.soundEnabled)
end)
test('huge or metamethod-bearing preference requests inspect no more than three raw keys',function()
 local progression=modules.FishingProgression.new(modules.FishCatalog,function()return 0 end)
 local invalid={soundEnabled=true,reducedEffects=false}
 for index=1,10000 do invalid['unexpected'..index]=true end
 local start=nextCalls
 assert(not progression.preferencesValid(invalid) and nextCalls-start<=3)
 local rules=modules.FishingSaveRules.new(modules.FishCatalog,progression)
 local profile=progression.create();profile.preferences=invalid;start=nextCalls
 assert(not rules.validate(profile) and nextCalls-start<=3)
 local valid=setmetatable({soundEnabled=false,reducedEffects=true},{
  __iter=function()error('preference protocol invoked an unbounded custom iterator')end,
  __index=function()error('preference protocol invoked an index metamethod')end,
 })
 start=nextCalls
 assert(progression.preferencesValid(valid) and nextCalls-start==3)
 local engine=modules.FishingEngine.new(modules.FishingConfig,modules.FishingRules,progression)
 engine:addPlayer(1,clock)
 start=nextCalls;local packet=assert(engine:command(1,'Preferences',valid,clock,false))
 assert(packet.preferencesChanged and nextCalls-start==3,'Idle Preferences re-scanned the request')
 local charging=assert(engine:command(1,'BeginCast',nil,clock+1,true,'harbor'))
 start=nextCalls;packet=assert(engine:command(1,'Preferences',valid,clock+1.1,true))
 assert(packet.phase=='ChargingCast' and not packet.preferencesChanged and nextCalls-start==3)
end)
test('malformed persisted preferences reject load without replacing its stored wallet',function()
 local store,progression=newStore();local data=backend(productionName)
 local rules=modules.FishingSaveRules.new(modules.FishCatalog,progression)
 local old=assert(rules.acquire(nil,'previous',400))
 old=assert(rules.save(old,old.profile,'previous',400,true))
 old.profile.coins=500;old.profile.preferences={soundEnabled=false,reducedEffects=true,coins=999}
 data.records.player_1=old
 local session,reason=store.load(1)
 assert(session==nil and reason=='invalid_data' and data.records.player_1.profile.coins==500)
end)
test('malformed in-memory preferences are rejected before whitelist copying can hide them',function()
 local store,progression=newStore();local data=backend(productionName)
 local session=assert(store.load(1));local calls=data.calls
 for _,preferences in {false,{soundEnabled=false},{soundEnabled=false,reducedEffects=true,extra=true}} do
  local profile=progression.create();profile.coins=500;profile.preferences=preferences
  local ok,reason=store.save(session,profile,true)
  assert(not ok and reason=='invalid_data' and not session.busy and not session.closed)
  assert(data.calls==calls and data.records.player_1.profile.coins==0)
 end
 assert(guidCounter==1,'invalid settings allocated a release operation identity')
end)
print(passed..' production profile-store cases passed; native transport/budgets remain untested')
'''


def check(luau: str) -> None:
    code = PREPARE
    for name, path in (("FishCatalog", "src/shared/FishCatalog.luau"),
                       ("FishingConfig", "src/shared/FishingConfig.luau"),
                       ("FishingRules", "src/shared/FishingRules.luau"),
                       ("FishingEngine", "src/server/FishingEngine.luau"),
                       ("FishingProgression", "src/server/FishingProgression.luau"),
                       ("FishingSaveRules", "src/server/FishingSaveRules.luau"),
                       ("FishingProfileStore", "src/server/FishingProfileStore.luau")):
        code += f"\nmodules.{name}=(function()\n" + (ROOT / path).read_text() + "\nend)()\n"
    with tempfile.TemporaryDirectory(prefix="cloud-anglers-profile-") as temp:
        script = Path(temp) / "check.luau"
        script.write_text(code + CHECK)
        subprocess.run([luau, str(script)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
