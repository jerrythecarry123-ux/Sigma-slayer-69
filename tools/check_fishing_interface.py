#!/usr/bin/env python3
"""Exercise the production fishing interface with UI, tween and geometry doubles.

Uses actual catalog, progression, theme and fish modules. This verifies callbacks,
layout arithmetic and delayed reveals, not Roblox rendering or native input.
Run: python tools/check_fishing_interface.py --luau /path/to/luau
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREPARE = r'''

local originalIndex, originalNewIndex = mt.__index, mt.__newindex
local signals={Changed=true,MouseEnter=true,MouseLeave=true,Activated=true}
mt.__index=function(self,key)
 if signals[key] then self.props[key]=self.props[key] or signal(); return self.props[key] end
 return originalIndex(self,key)
end
mt.__newindex=function(self,key,value)
 originalNewIndex(self,key,value)
 if key=='Value' and self.props.Changed then self.props.Changed:Fire(value) end
end
local originalNew=Instance.new
Instance.new=function(class)
 local object=originalNew(class)
 object.AbsoluteSize=Vector2.new(1280,720);object.Visible=true
 return object
end
function methods:Destroy()
 self.Parent=nil
 for _,child in table.clone(self.children) do child:Destroy() end
end
function methods:IsDescendantOf(parent)
 local current=self.Parent
 while current do if current==parent then return true end;current=current.Parent end
 return false
end
local UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
UDim2.new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
local TweenInfo={new=function(duration)return {duration}end}
local TweenService={Create=function(_,object,info,values)
 local tween={cancelled=false}
 function tween:Play() task.delay(info[1],function()if self.cancelled then return end;for key,value in values do object[key]=value end end)end
 function tween:Cancel()self.cancelled=true end
 return tween
end}
local GuiService={SelectedObject=nil}
local UserInputService={InputBegan=signal()}
game.GetService=function(_,name)
 if name=='TweenService' then return TweenService end
 if name=='GuiService' then return GuiService end
 if name=='UserInputService' then return UserInputService end
 return ReplicatedStorage
end
'''
CHECK = r'''

local audioCalls={catch=0,ui=0}
local audio=setmetatable({}, {__index=function(_,key)return function()if audioCalls[key]~=nil then audioCalls[key]+=1 end end end})
local pgui=Instance.new('PlayerGui')
local callbacks={aquarium=0,cast=0,settings=0,preferences=nil}
local ui
ui=modules.FishingInterface.new(pgui,audio,{openJournal=function()ui.hideResult()end,upgrade=function()end,openAquarium=function()callbacks.aquarium+=1;ui.closeJournal();ui.hideResult()end,castAgain=function()callbacks.cast+=1 end,
 openSettings=function()callbacks.settings+=1 end,settingsChanged=function(value)callbacks.preferences=value end})
local progression=modules.FishingProgression.new(modules.FishCatalog,function()return .5 end)
local profile=progression.create()
local function snapshot()local data=progression.snapshot(profile);data.persistent=false;data.offlineRate=0;return data end
local gui=pgui:FindFirstChild('MolnfiskarnaFishing')
local function find(node,name)
 if node.Name==name then return node end
 for _,child in node.children do local found=find(child,name);if found then return found end end
end
local function text(node,value)
 if node.Text==value then return node end
 for _,child in node.children do local found=text(child,value);if found then return found end end
end
ui.updateProfile(snapshot())
ui.updateLocation({zoneId='forest',zoneName='Evergreen Reach'})
assert(#modules.FishCatalog.Species==17,'catalog expansion missing')
assert(text(gui,'EVERGREEN REACH') and text(gui,'0/4 LOCAL SPECIES FOUND'),'location stays stale after travel')
assert(text(gui,'JOURNAL  0/'..#modules.FishCatalog.Species),'journal total was not catalog driven')
text(gui,'MY AQUARIUM').Activated:Fire();assert(callbacks.aquarium==1)
for _,view in {{320,530},{375,625},{568,280},{844,335},{768,964},{1920,1040}} do
 gui.AbsoluteSize=Vector2.new(view[1],view[2]);ui.animate(now,view[1],view[2])
 local loc=find(gui,'Location');local wallet=find(gui,'Wallet')
 assert(loc.Position.X.Offset+loc.Size.X.Offset<=view[1]-138-8,'location overlaps wallet')
 local settings=find(gui,'SettingsButton')
 assert(settings.Size.X.Offset>=44 and settings.Size.Y.Offset>=44,'settings touch target too small')
 assert(settings.Position.X.Offset+settings.Size.X.Offset<=view[1]-16,'settings clips screen')
 if view[2]<480 then
  assert(loc.Position.X.Offset+loc.Size.X.Offset<=settings.Position.X.Offset-8,'settings overlaps location')
  assert(settings.Position.X.Offset+settings.Size.X.Offset<=view[1]-138-8,'settings overlaps wallet')
 end
 local card=find(gui,'DiscoveryCard');local scale=find(card,'UIScale').Scale
 for _,label in {'MY AQUARIUM','CAST AGAIN'} do
  local action=text(card,label)
  assert(action.Size.Y.Offset*scale>=44-1e-6,'catch action shrinks below touch size')
  assert(action.Position.Y.Offset+action.Size.Y.Offset<=card.Size.Y.Offset,'catch action leaves card')
  assert(action.TextSize*scale>=12-1e-6,'catch action text too small')
 end
 assert(find(gui,'PreferencesCard').Size.X.Offset<=view[1]-24 and find(gui,'PreferencesCard').Size.Y.Offset<=view[2]-24,'settings modal clips canvas')
end
for _,rarity in modules.FishRarity.Order do
 local expected=tostring(modules.FishRarity.get(rarity).Rank)..' / '..string.upper(rarity)
 assert(text(find(gui,'FishGallery'),expected),'journal rarity has only color or missing tier: '..rarity)
end
local fine=find(find(gui,'TimingTrack'),'Fine');local gold=find(find(gui,'TimingTrack'),'Brilliant')
for attempt=1,5 do
 local center=modules.FishingRules.centerFor(attempt)
 ui.setTimingWindow(center,.14)
 local displayedCenter=gold.Position.X.Scale+gold.Size.X.Scale/2
 assert(modules.FishingRules.qualityAt(displayedCenter,center)=='Brilliant','displayed gold target does not award Brilliant')
 assert(math.abs(fine.Position.X.Scale-(center-.2))<1e-8 and math.abs(fine.Size.X.Scale-.36)<1e-8,'fine region disagrees with server')
 assert(math.abs(gold.Position.X.Scale-(center-.07))<1e-8 and math.abs(gold.Size.X.Scale-.14)<1e-8,'gold region disagrees with server')
end
local result=progression.catch(profile,'Fine','harbor');result.variant='Golden';result.coins=18;result.comboBonus=3;result.goalBonus=10
ui.updateProfile(snapshot());ui.showResult(result);step(.651)
assert(ui.isResultOpen() and text(gui,'GOLDEN CATCH'),'special catch reveal missing')
assert(text(gui,string.format('%.2f kg  ·  NEW RECORD',result.weightKg)),'size record missing from catch reveal')
assert(text(gui,'+18 coins  +10 bonus'),'chain bonus was displayed twice')
assert(text(gui,'JOURNAL  1/'..#modules.FishCatalog.Species),'discovery count stale')
local cast=text(find(gui,'DiscoveryCard'),'CAST AGAIN');cast.Activated:Fire();assert(callbacks.cast==1 and not ui.isResultOpen())
ui.showResult(result);ui.hideResult();step(.7);assert(not ui.isResultOpen(),'cancelled reveal reopened')
ui.showResult(result);step(.651);ui.openJournal('Collection');step(3);assert(ui.isJournalOpen() and not ui.isResultOpen(),'collection competes with delayed reveal')
ui.closeJournal();ui.showResult({species='Pufflet',speciesId='pufflet',rarity='Common',quality='Fine',variant='Normal',weightKg=1.25,coins=8,combo=2})
step(.651);assert(ui.isResultOpen());step(1.401);assert(not ui.isResultOpen(),'ordinary repeat catch blocks next cast too long')

local journal=text(gui,'JOURNAL  1/'..#modules.FishCatalog.Species)
GuiService.SelectedObject=journal
ui.openJournal('Workshop')
assert(ui.isJournalOpen() and GuiService.SelectedObject.Text=='Rod workshop','journal gamepad focus missing')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(not ui.isJournalOpen() and GuiService.SelectedObject==journal,'journal cancel/focus restoration failed')
ui.showResult(result)
ui.openSettings();step(.7)
assert(ui.isSettingsOpen() and not ui.isResultOpen() and not ui.isJournalOpen(),'settings competes with delayed result')
assert(not find(gui,'CastCard').Visible and GuiService.SelectedObject.Name=='SoundToggle','settings lacks modal focus')
ui.setPreferences({reducedEffects=false,soundEnabled=true,systemReducedMotion=true})
assert(find(gui,'ReducedEffectsToggle').Text=='OFF' and string.find(find(gui,'PreferencesContent').children[3].Text,'Roblox Reduce Motion',1,true),'system motion preference confused with local preference')
find(gui,'ReducedEffectsToggle').Activated:Fire()
assert(callbacks.preferences.reducedEffects==true and callbacks.preferences.soundEnabled==true,'motion preference callback wrong')
local priorSounds=audioCalls.ui
find(gui,'SoundToggle').Activated:Fire()
assert(callbacks.preferences.soundEnabled==false and find(gui,'SoundToggle').Text=='OFF','sound preference callback wrong')
assert(audioCalls.ui==priorSounds,'muting played a confirmation sound')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.Escape},false)
assert(not ui.isSettingsOpen() and GuiService.SelectedObject==journal,'settings cancel/focus restoration failed')
ui.openSettings();ui.openJournal('Collection')
assert(ui.isJournalOpen() and not ui.isSettingsOpen(),'journal does not replace settings')
ui.closeJournal();ui.openSettings()
local external=Instance.new('TextButton');external.Parent=pgui
GuiService.SelectedObject=external
ui.closeSettings()
assert(GuiService.SelectedObject==external,'closing settings stole focus from another interface')

ui.setPreferences({reducedEffects=true,soundEnabled=true})
local priorCatches=audioCalls.catch
UserInputService.PreferredInput=Enum.PreferredInput.Gamepad
GuiService.SelectedObject=journal
ui.showResult(result,true,true);step(.001)
assert(ui.isResultOpen() and audioCalls.catch==priorCatches,'post-cinematic card delayed or duplicated sound')
assert(GuiService.SelectedObject.Text=='CAST AGAIN','result does not focus gamepad continuation')
UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.ButtonB},false)
assert(not ui.isResultOpen() and GuiService.SelectedObject==journal,'result cannot dismiss with gamepad or restore focus')
for _,rarity in {'Epic','Legendary','Mythical','Secret'} do
 ui.showResult({species='Test',speciesId='pufflet',rarity=rarity,quality='Fine',weightKg=1,coins=8},true,true);step(.001)
 assert(text(find(gui,'DiscoveryCard'),modules.UITheme.rarityLabel(rarity)..' · Fine'),'catch rarity missing word/rank')
end
ui.hideResult()
print('PASS actual fishing UI: catalog totals, region update, aquarium action and responsive layout')
print('PASS server-aligned timing zones, variant/weight reveal, accurate coin totals and cast-again action')
print('PASS cancelled/stale reveal, journal overlay and short repeat-catch dismissal')
print('PASS seven-tier labels, session preferences, system reduced motion and silent immediate result')
print('PASS journal/settings modal exclusion, gamepad focus, Escape/ButtonB and external focus ownership')
'''


def check(luau: str) -> None:
    spec = importlib.util.spec_from_file_location("portal_check", ROOT / "tools/check_portal_interface.py")
    portal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(portal)
    # Reuse only the portal check's scheduler and signals; geometry/UI objects
    # below are the shared preview doubles, not a replacement implementation.
    scheduler = portal.PREPARE.split("local methods={}")[0]
    program = (ROOT / "tools/preview_roblox.luau").read_text() + scheduler + PREPARE
    sources = (("FishRarity", "src/shared/FishRarity.luau"),
               ("FishCatalog", "src/shared/FishCatalog.luau"),
               ("FishingRules", "src/shared/FishingRules.luau"),
               ("FishModel", "src/shared/FishModel.luau"),
               ("UITheme", "src/client/UITheme.luau"),
               ("InterfaceLayout", "src/client/InterfaceLayout.luau"),
               ("FishingProgression", "src/server/FishingProgression.luau"),
               ("FishingInterface", "src/client/FishingInterface.luau"))
    for name, source in sources:
        program += f"\nmodules.{name}=(function()\n" + (ROOT / source).read_text() + "\nend)()\n"
        program += f'local token=Instance.new("ModuleScript");token.Name="{name}";token.Parent=shared\n'
    program += CHECK
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "check_fishing_interface.luau"
        path.write_text(program)
        subprocess.run([luau, str(path)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    check(parser.parse_args().luau)
